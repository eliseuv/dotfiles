// Restart and start-or-stop (one button, last, like on/off below) buttons on
// tiles backed by a systemd unit; host tiles get, in this order and as
// configured: terminal, switch (pull the dotfiles and switch to them),
// tailscale (on/off), restart, and on/off, one button that wakes the host
// while it's down and powers it off while it's up (controls.nix).
// `svcctlTiles`, `svcctlWakeTiles`, `svcctlPoweroffTiles`, `svcctlSwitchTiles`,
// `svcctlTailscaleTiles` (tile names), `svcctlRebootTiles` (tile name -> whether it's this host) and
// `svcctlTerminals` (tile name -> URL) are defined ahead of this file by
// default.nix.
(() => {
  const api = "/api/svc";
  const headers = { "X-Svcctl": "1" };
  let states = {};
  // Tile name -> "idle"/"switching"/"failed" for switch tiles.
  let switchStates = {};
  // Tile name -> "on"/"off"/"unknown" for tailscale tiles.
  let tailscaleStates = {};
  // Tile name -> round-trip ms of the host's last answered ping, or null.
  let pings = {};
  // Tile name -> when its wake was sent; shown as "waking" until the host
  // answers pings or the window lapses (a cold boot takes a while).
  const wakeSent = {};
  const wakeWindow = 120 * 1000;
  // Likewise "shutting down" until pings stop.
  const poweroffSent = {};
  const poweroffWindow = 120 * 1000;
  // Tile name -> {at, sawDown}: "rebooting" until the host has gone away and
  // come back, or the window lapses. Another host's pings show that; this
  // host serves the page, so for it the API going away and answering again.
  const rebootSent = {};
  const rebootWindow = 300 * 1000;
  let apiWentDown = false;

  const call = (method, path) =>
    fetch(api + path, { method, headers }).then((response) =>
      response.ok ? response.json() : Promise.reject(response.status),
    );

  const refresh = () =>
    call("GET", "/status")
      .then((next) => {
        states = next.tiles;
        switchStates = next.switch;
        tailscaleStates = next.tailscale;
        pings = next.ping;
        if (apiWentDown) {
          for (const name in rebootSent) if (svcctlRebootTiles[name]) delete rebootSent[name];
        }
        apiWentDown = false;
        render();
      })
      .catch(() => {
        apiWentDown = true;
      });

  // Several quick polls after an action, since systemctl returns before the
  // unit has actually changed state.
  const settle = () => [1, 3, 6, 12].forEach((s) => setTimeout(refresh, s * 1000));
  const settleWake = () => [5, 15, 30, 45, 60, 90, 120].forEach((s) => setTimeout(refresh, s * 1000));
  const settlePoweroff = () =>
    [5, 15, 30, 45, 60, 90, 120].forEach((s) => setTimeout(refresh, s * 1000));

  const unitActive = (state) =>
    state === "active" || state === "activating" || state === "reloading";

  const act = (name, action) => {
    if (action === "power") action = displayState(name) === "up" ? "poweroff" : "wake";
    if (action === "run") action = unitActive(displayState(name)) ? "stop" : "start";
    if (action === "stop" && !confirm(`Stop ${name}?`)) return;
    if (action === "poweroff" && !confirm(`Power off ${name} now?`)) return;
    if (
      action === "reboot" &&
      !confirm(
        svcctlRebootTiles[name]
          ? `Reboot ${name}? The dashboard goes down with it.`
          : `Reboot ${name} now?`,
      )
    )
      return;
    if (action === "tailscale") {
      const turnOff = tailscaleStates[name] === "on";
      if (turnOff && !confirm(`Turn Tailscale off on ${name}? Only the LAN can turn it back on.`))
        return;
      action = turnOff ? "tailscale-off" : "tailscale-on";
    }
    if (action === "switch" && !confirm(`Pull origin/master on ${name} and switch to it?`)) return;
    call("POST", `/${action}/${encodeURIComponent(name)}`)
      .then(() => {
        if (action === "wake") {
          wakeSent[name] = Date.now();
          render();
          return settleWake();
        }
        if (action === "poweroff") {
          poweroffSent[name] = Date.now();
          render();
          return settlePoweroff();
        }
        if (action === "reboot") {
          rebootSent[name] = { at: Date.now(), sawDown: false };
          if (svcctlRebootTiles[name]) apiWentDown = false;
          return render();
        }
        if (action.startsWith("tailscale-")) {
          tailscaleStates[name] = action === "tailscale-on" ? "on" : "off";
          return render();
        }
        settle();
      })
      .catch((status) => {
        if (status !== 401) return alert(`${action} ${name} failed (${status})`);
        // The login page; see /api/svc/login in controls.nix.
        if (confirm("Log in to use the dashboard controls?")) location.href = `${api}/login`;
      });
  };

  // Drawn rather than typed: phone fonts lack ⏻ and ⤓ and turn ⛓ and ▶ into
  // colour emoji. Stroked in currentColor so controls.css and theme.css
  // still colour them.
  const icons = {
    play: '<path fill="currentColor" stroke="none" d="M7 4l13 8-13 8z"/>',
    stop: '<rect fill="currentColor" stroke="none" x="6" y="6" width="12" height="12"/>',
    restart: '<path d="M21 12a9 9 0 1 1-2.64-6.36"/><path d="M21 3v6h-6"/>',
    download: '<path d="M12 3v12M7 10l5 5 5-5M5 20h14"/>',
    link:
      '<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/>' +
      '<path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>',
    power: '<path d="M18.36 6.64a9 9 0 1 1-12.73 0M12 2v10"/>',
  };

  const iconSvg = (icon) =>
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" ' +
    `stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[icon]}</svg>`;

  const button = (name, action, icon) => {
    const element = document.createElement("button");
    element.type = "button";
    element.className = `svcctl-${action}`;
    element.title = `${action[0].toUpperCase()}${action.slice(1)} ${name}`;
    element.innerHTML = iconSvg(icon);
    element.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      act(name, action);
    });
    return element;
  };

  // A link rather than a button so it opens like one (new tab, middle click);
  // links can't be disabled, so render() toggles aria-disabled, which
  // controls.css makes inert to the pointer and this guards for the keyboard.
  const terminalLink = (name) => {
    const element = document.createElement("a");
    element.className = "svcctl-terminal";
    element.href = svcctlTerminals[name];
    element.target = "_blank";
    element.rel = "noopener";
    element.title = `Terminal on ${name}`;
    element.textContent = ">_";
    element.addEventListener("click", (event) => {
      event.stopPropagation();
      if (element.getAttribute("aria-disabled") === "true") event.preventDefault();
    });
    return element;
  };

  const build = (name, kinds) => {
    const bar = document.createElement("div");
    bar.className = "svcctl";
    const state = document.createElement("span");
    state.className = "svcctl-state";
    bar.append(state);
    if (kinds.unit) {
      bar.append(button(name, "restart", "restart"), button(name, "run", "play"));
    }
    if (kinds.terminal) bar.append(terminalLink(name));
    if (kinds.switch) bar.append(button(name, "switch", "download"));
    if (kinds.tailscale) bar.append(button(name, "tailscale", "link"));
    if (kinds.reboot) bar.append(button(name, "reboot", "restart"));
    if (kinds.wake) bar.append(button(name, "power", "power"));
    return bar;
  };

  const displayState = (name) => {
    const state = states[name] || "unknown";
    const reboot = rebootSent[name];
    if (reboot && Date.now() - reboot.at < rebootWindow) {
      if (state === "down") reboot.sawDown = true;
      if (!(reboot.sawDown && state === "up")) return "rebooting";
    }
    delete rebootSent[name];
    if (state === "up") delete wakeSent[name];
    else if (Date.now() - wakeSent[name] < wakeWindow) return "waking";
    if (state === "down") delete poweroffSent[name];
    else if (Date.now() - poweroffSent[name] < poweroffWindow) return "shutting-down";
    return state;
  };

  // Only touches the DOM when something changed: the page's MutationObserver
  // calls this again on every mutation.
  const render = () => {
    for (const tile of document.querySelectorAll("li.service[data-name]")) {
      const name = tile.dataset.name;
      const kinds = {
        unit: svcctlTiles.includes(name),
        wake: svcctlWakeTiles.includes(name),
        reboot: name in svcctlRebootTiles,
        switch: svcctlSwitchTiles.includes(name),
        terminal: name in svcctlTerminals,
        tailscale: svcctlTailscaleTiles.includes(name),
      };
      if (!Object.values(kinds).some(Boolean)) continue;
      const card = tile.firstElementChild;
      if (!card) continue;
      let bar = card.querySelector(":scope > .svcctl");
      if (!bar) {
        bar = build(name, kinds);
        card.append(bar);
      }
      const state = displayState(name);
      const switchState = kinds.switch ? switchStates[name] || "unknown" : "";
      const tailscaleState = kinds.tailscale ? tailscaleStates[name] || "unknown" : "";
      const ping = state === "up" && pings[name] != null ? ` · ${Math.round(pings[name])} ms` : "";
      if (
        bar.dataset.ping === ping &&
        bar.dataset.state === state &&
        (bar.dataset.switch || "") === switchState &&
        (bar.dataset.tailscale || "") === tailscaleState
      )
        continue;
      bar.dataset.state = state;
      bar.dataset.ping = ping;
      // Hosts read on/off, units their systemd state; anything in between
      // shows as is. controls.css uppercases it.
      const words = kinds.unit ? {} : { up: "on", down: "off" };
      bar.querySelector(".svcctl-state").textContent = (words[state] || state) + ping;
      if (kinds.unit) {
        const run = bar.querySelector(".svcctl-run");
        const active = unitActive(state);
        run.innerHTML = iconSvg(active ? "stop" : "play");
        run.title = active ? `Stop ${name}` : `Start ${name}`;
      }
      if (kinds.terminal) {
        bar.querySelector(".svcctl-terminal").setAttribute("aria-disabled", String(state !== "up"));
      }
      if (kinds.wake) {
        const power = bar.querySelector(".svcctl-power");
        const up = state === "up";
        power.disabled =
          (up && !svcctlPoweroffTiles.includes(name)) ||
          state === "waking" ||
          state === "shutting-down" ||
          state === "rebooting";
        power.title = up ? `Power off ${name}` : `Wake ${name}`;
      }
      if (kinds.tailscale) {
        bar.dataset.tailscale = tailscaleState;
        const element = bar.querySelector(".svcctl-tailscale");
        element.disabled = state !== "up" || tailscaleState === "unknown";
        element.title =
          tailscaleState === "on" ? `Turn Tailscale off on ${name}` : `Turn Tailscale on on ${name}`;
      }
      if (kinds.reboot) bar.querySelector(".svcctl-reboot").disabled = state !== "up";
      if (kinds.switch) {
        bar.dataset.switch = switchState;
        const element = bar.querySelector(".svcctl-switch");
        element.disabled = state !== "up" || switchState === "switching";
        element.title =
          switchState === "switching"
            ? `Switching ${name}\u2026`
            : switchState === "failed"
              ? `Last switch of ${name} failed; see \`journalctl -u dotfiles-switch\` there`
              : `Pull origin/master on ${name} and switch to it`;
      }
    }
  };

  new MutationObserver(render).observe(document.documentElement, {
    childList: true,
    subtree: true,
  });
  refresh();
  setInterval(refresh, 10000);
})();
