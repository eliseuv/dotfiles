// Start/stop/restart buttons on tiles backed by a systemd unit, and a wake
// button on tiles for another machine, plus power-off and terminal buttons on
// some of those, and a reboot button on the tile for this host (controls.nix).
// `svcctlTiles`, `svcctlWakeTiles`, `svcctlPoweroffTiles`,
// `svcctlRebootTiles` (tile names) and `svcctlTerminals` (tile name -> URL)
// are defined ahead of this file by default.nix.
(() => {
  const api = "/api/svc";
  const headers = { "X-Svcctl": "1" };
  let states = {};
  // Tile name -> when its wake was sent; shown as "waking" until the host
  // answers pings or the window lapses (a cold boot takes a while).
  const wakeSent = {};
  const wakeWindow = 120 * 1000;
  // Likewise "shutting down" until pings stop; the host waits a minute
  // (`shutdown +1`) before it even starts.
  const poweroffSent = {};
  const poweroffWindow = 180 * 1000;
  // This host serves the page, so "rebooting" lasts until the API has gone
  // away and answered again, or the window lapses.
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
        states = next;
        if (apiWentDown) for (const name in rebootSent) delete rebootSent[name];
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
    [60, 75, 90, 120, 150, 180].forEach((s) => setTimeout(refresh, s * 1000));

  const act = (name, action) => {
    if (action === "stop" && !confirm(`Stop ${name}?`)) return;
    if (
      action === "poweroff" &&
      !confirm(`Power off ${name}? It shuts down in a minute; \`shutdown -c\` there cancels.`)
    )
      return;
    if (action === "reboot" && !confirm(`Reboot ${name}? The dashboard goes down with it.`)) return;
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
          rebootSent[name] = Date.now();
          apiWentDown = false;
          return render();
        }
        settle();
      })
      .catch((status) => alert(`${action} ${name} failed (${status})`));
  };

  const button = (name, action, glyph) => {
    const element = document.createElement("button");
    element.type = "button";
    element.className = `svcctl-${action}`;
    element.title = `${action[0].toUpperCase()}${action.slice(1)} ${name}`;
    element.textContent = glyph;
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

  const build = (name, wakeable, rebootable) => {
    const bar = document.createElement("div");
    bar.className = "svcctl";
    const state = document.createElement("span");
    state.className = "svcctl-state";
    if (rebootable) {
      bar.append(state, button(name, "reboot", "↻"));
    } else if (wakeable) {
      bar.append(state);
      if (name in svcctlTerminals) bar.append(terminalLink(name));
      bar.append(button(name, "wake", "⏻"));
      if (svcctlPoweroffTiles.includes(name)) bar.append(button(name, "poweroff", "■"));
    } else {
      bar.append(
        state,
        button(name, "start", "▶"),
        button(name, "stop", "■"),
        button(name, "restart", "↻"),
      );
    }
    return bar;
  };

  const displayState = (name) => {
    if (Date.now() - rebootSent[name] < rebootWindow) return "rebooting";
    const state = states[name] || "unknown";
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
      const wakeable = svcctlWakeTiles.includes(name);
      const rebootable = svcctlRebootTiles.includes(name);
      if (!wakeable && !rebootable && !svcctlTiles.includes(name)) continue;
      const card = tile.firstElementChild;
      if (!card) continue;
      let bar = card.querySelector(":scope > .svcctl");
      if (!bar) {
        bar = build(name, wakeable, rebootable);
        card.append(bar);
      }
      const state = displayState(name);
      if (bar.dataset.state !== state) {
        bar.dataset.state = state;
        bar.querySelector(".svcctl-state").textContent = state;
        if (rebootable) {
          bar.querySelector(".svcctl-reboot").disabled = state !== "up";
        } else if (wakeable) {
          bar.querySelector(".svcctl-wake").disabled =
            state === "up" || state === "waking" || state === "shutting-down";
          const poweroff = bar.querySelector(".svcctl-poweroff");
          if (poweroff) poweroff.disabled = state !== "up";
          const terminal = bar.querySelector(".svcctl-terminal");
          if (terminal) terminal.setAttribute("aria-disabled", String(state !== "up"));
        } else {
          const active = state === "active" || state === "activating" || state === "reloading";
          bar.querySelector(".svcctl-start").disabled = active;
          bar.querySelector(".svcctl-stop").disabled = !active;
        }
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
