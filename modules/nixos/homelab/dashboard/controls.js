// Restart and start-or-stop (one button, last, like on/off below) buttons on
// tiles backed by a systemd unit; host tiles get, in this order and as
// configured: ports (a menu of its dev servers, each open or closed, some
// with their own start-or-stop),
// switch (pull the dotfiles and switch to them; a config page button instead
// where the host has a page, which switches from there), tailscale
// (on/off), restart, and on/off, one button that wakes the host while it's
// down and powers it off while it's up (controls.nix).
// `svcctlTiles`, `svcctlWakeTiles`, `svcctlPoweroffTiles`, `svcctlSwitchTiles`,
// `svcctlTailscaleTiles` (tile names), `svcctlRebootTiles` (tile name -> whether it's this host),
// `svcctlTerminals` (tile name -> URL, what the tile itself opens),
// `svcctlPages` (tile name -> host whose page the config button opens),
// `svcctlUptimes` (tile name -> hostctl's name for the host whose uptime it shows), `svcctlPorts` (tile name ->
// {host, ports: [{name, port, href, unit}]}) and `svcctlTailnet` ({domain,
// address}) are defined ahead of this file by default.nix.
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
  // Tile name -> {seconds, at}: uptime of a page host as of performance.now()
  // `at`, counted on from there. hostctl fetches it over SSH only every
  // few minutes; pings say when it has gone stale.
  const uptimes = {};
  // Tile name -> performance.now() when its host was last seen down. An
  // uptime fetched before then is from the previous boot.
  const downSeen = {};
  const uptimeResync = 60 * 1000;
  const lastUptimeFetch = {};
  // Tile name -> {port: open?} for ports tiles.
  let portStates = {};
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
        portStates = next.ports;
        syncUptimes();
        if (apiWentDown) {
          for (const name in rebootSent) if (svcctlRebootTiles[name]) delete rebootSent[name];
        }
        apiWentDown = false;
        render();
      })
      .catch(() => {
        apiWentDown = true;
      });

  const fetchUptime = (name, poke) => {
    lastUptimeFetch[name] = performance.now();
    const query = poke ? "?refresh=1" : "";
    fetch(`/api/hosts/${encodeURIComponent(svcctlUptimes[name])}${query}`)
      .then((response) => (response.ok ? response.json() : Promise.reject(response.status)))
      .then(({ uptime, uptime_age: age }) => {
        if (uptime == null) return;
        // The age is on hostctl's clock and the wait on ours; both are durations.
        if (name in downSeen && age * 1000 > performance.now() - downSeen[name]) return;
        delete downSeen[name];
        uptimes[name] = { seconds: uptime, at: performance.now() };
        render();
      })
      .catch(() => {});
  };

  const syncUptimes = () => {
    for (const name in svcctlUptimes) {
      if (states[name] !== "up") {
        delete uptimes[name];
        downSeen[name] = performance.now();
      } else if (name in downSeen || !(name in uptimes)) {
        // Back up: ask hostctl to refetch until it has a post-boot value.
        fetchUptime(name, true);
      } else if (performance.now() - lastUptimeFetch[name] >= uptimeResync) {
        fetchUptime(name, false);
      }
    }
  };

  const formatUptime = (seconds) => {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return days ? `${days}d ${hours}h` : hours ? `${hours}h ${minutes}m` : `${minutes}m`;
  };

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
        if (action === "switch") {
          switchStates[name] = "switching";
          render();
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
    config: '<path d="M10.2 4.6L10.4 1.6L13.6 1.6L13.8 4.6L15.9 5.5L18.2 3.6L20.4 5.8L18.5 8.1L19.4 10.2L22.4 10.4L22.4 13.6L19.4 13.8L18.5 15.9L20.4 18.2L18.2 20.4L15.9 18.5L13.8 19.4L13.6 22.4L10.4 22.4L10.2 19.4L8.1 18.5L5.8 20.4L3.6 18.2L5.5 15.9L4.6 13.8L1.6 13.6L1.6 10.4L4.6 10.2L5.5 8.1L3.6 5.8L5.8 3.6L8.1 5.5z"/><circle cx="12" cy="12" r="3"/>',
    socket: '<rect x="3" y="3" width="18" height="18" rx="3"/><path d="M9 8v4M15 8v4M9 17h6"/>',
  };

  const iconSvg = (icon) =>
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" ' +
    `stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[icon]}</svg>`;

  const button = (name, action, icon) => {
    const element = document.createElement("button");
    element.type = "button";
    element.className = `svcctl-${action}`;
    element.dataset.label = {
      run: "Start",
      reboot: "Restart",
      power: "Wake",
      switch: "Switch",
      tailscale: "Tailnet",
      restart: "Restart",
    }[action] || action;
    element.title = `${action[0].toUpperCase()}${action.slice(1)} ${name}`;
    element.innerHTML = iconSvg(icon);
    element.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      act(name, action);
    });
    return element;
  };

  // A link rather than a button so it opens like one (middle click); in
  // place, as the page leads back here.
  const configLink = (name) => {
    const element = document.createElement("a");
    element.className = "svcctl-config";
    element.dataset.label = "Config";
    element.href = `/hosts/?host=${encodeURIComponent(svcctlPages[name])}`;
    element.title = `Config page of ${name}`;
    element.innerHTML = iconSvg("config");
    element.addEventListener("click", (event) => event.stopPropagation());
    return element;
  };

  // The tile's own link opens the terminal, which only answers while the
  // host is up.
  document.addEventListener(
    "click",
    (event) => {
      const tile = event.target.closest?.("li.service[data-name]");
      if (!tile || !(tile.dataset.name in svcctlTerminals)) return;
      const link = event.target.closest("a");
      if (!link || link.closest(".svcctl")) return;
      if (displayState(tile.dataset.name) !== "up") event.preventDefault();
    },
    true,
  );

  // Another host by the name the dashboard was reached with: its MagicDNS
  // name over the tailnet, its mDNS one on the LAN; this host as the page is.
  const portsHost = (host) => {
    if (!host) return location.hostname;
    const here = location.hostname;
    const tailnet = here.endsWith(`.${svcctlTailnet.domain}`) || here === svcctlTailnet.address;
    return `${host.toLowerCase()}.${tailnet ? svcctlTailnet.domain : "local"}`;
  };

  // Below the bar rather than over the tiles next to it, and outside it so
  // its links don't take the bar's button styles. A row is its link, plus a
  // start-or-stop button for entries with a unit, which svcctl knows by the
  // entry's `unit` name.
  const portsMenu = (name) => {
    const { host, ports } = svcctlPorts[name];
    const menu = document.createElement("div");
    menu.className = "svcctl-ports-menu";
    menu.hidden = true;
    for (const { name: label, port, href, unit } of ports) {
      const row = document.createElement("div");
      row.className = "svcctl-ports-row";
      row.dataset.port = port;
      const link = document.createElement("a");
      link.href = href || `http://${portsHost(host)}:${port}`;
      link.target = "_blank";
      link.rel = "noopener";
      link.innerHTML = '<span class="svcctl-ports-dot"></span><span></span><span></span>';
      link.children[1].textContent = label;
      link.children[2].textContent = href || `:${port}`;
      row.append(link);
      if (unit) {
        const run = button(unit, "run", "play");
        run.dataset.unit = unit;
        row.append(run);
      }
      menu.append(row);
    }
    menu.addEventListener("click", (event) => event.stopPropagation());
    return menu;
  };

  const portsButton = (name, menu) => {
    const element = document.createElement("button");
    element.type = "button";
    element.className = "svcctl-ports";
    element.dataset.label = "Ports";
    element.title = `Ports on ${name}`;
    element.setAttribute("aria-expanded", "false");
    element.innerHTML = iconSvg("socket");
    element.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      const open = menu.hidden;
      closePorts();
      menu.hidden = !open;
      element.setAttribute("aria-expanded", String(open));
    });
    return element;
  };

  const closePorts = () => {
    for (const menu of document.querySelectorAll(".svcctl-ports-menu")) menu.hidden = true;
    for (const element of document.querySelectorAll(".svcctl-ports")) {
      element.setAttribute("aria-expanded", "false");
    }
  };
  document.addEventListener("click", closePorts);
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") closePorts();
  });

  const build = (name, kinds, menu) => {
    const bar = document.createElement("div");
    bar.className = "svcctl";
    const state = document.createElement("span");
    state.className = "svcctl-state";
    bar.append(state);
    const switching = document.createElement("span");
    switching.className = "svcctl-switch-status";
    switching.hidden = true;
    switching.setAttribute("role", "status");
    bar.append(switching);
    if (kinds.unit) {
      bar.append(button(name, "restart", "restart"), button(name, "run", "play"));
    }
    if (kinds.ports) bar.append(portsButton(name, menu));
    if (kinds.config) bar.append(configLink(name));
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
        config: name in svcctlPages,
        tailscale: svcctlTailscaleTiles.includes(name),
        ports: name in svcctlPorts,
      };
      if (!Object.values(kinds).some(Boolean)) continue;
      const card = tile.firstElementChild;
      if (!card) continue;
      let bar = card.querySelector(":scope > .svcctl");
      if (!bar) {
        const menu = kinds.ports ? portsMenu(name) : null;
        bar = build(name, kinds, menu);
        card.append(bar);
        if (menu) card.append(menu);
      }
      const state = displayState(name);
      const switchState = kinds.switch || kinds.config ? switchStates[name] || "unknown" : "";
      const tailscaleState = kinds.tailscale ? tailscaleStates[name] || "unknown" : "";
      let ping = state === "up" && pings[name] != null ? ` · ${Math.round(pings[name])} ms` : "";
      if (state === "up" && uptimes[name]) {
        const { seconds, at } = uptimes[name];
        ping += ` · ${formatUptime(seconds + (performance.now() - at) / 1000)}`;
      }
      // Its ports, and its entries' units.
      const portState = kinds.ports
        ? JSON.stringify([
            portStates[name] || {},
            svcctlPorts[name].ports.map(({ unit }) => unit && displayState(unit)),
          ])
        : "";
      if (
        (bar.dataset.ports || "") === portState &&
        bar.dataset.ping === ping &&
        bar.dataset.state === state &&
        (bar.dataset.switch || "") === switchState &&
        (bar.dataset.tailscale || "") === tailscaleState
      )
        continue;
      bar.dataset.state = state;
      bar.dataset.switch = switchState;
      bar.dataset.ping = ping;
      // Hosts read off, or the ping and uptime alone when up (the readings
      // already say so); units their systemd state; anything in between shows
      // as is. controls.css uppercases it.
      const words = kinds.unit ? {} : { up: "on", down: "off" };
      bar.querySelector(".svcctl-state").textContent =
        !kinds.unit && state === "up" && ping
          ? ping.slice(" · ".length)
          : (words[state] || state) + ping;
      const switching = bar.querySelector(".svcctl-switch-status");
      switching.hidden = switchState !== "switching" && switchState !== "failed";
      switching.textContent =
        switchState === "switching" ? "Switching\u2026" : switchState === "failed" ? "Switch failed" : "";
      if (kinds.unit) {
        const run = bar.querySelector(".svcctl-run");
        const active = unitActive(state);
        run.innerHTML = iconSvg(active ? "stop" : "play");
        run.title = active ? `Stop ${name}` : `Start ${name}`;
        run.dataset.label = active ? "Stop" : "Start";
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
        power.dataset.label = up && svcctlPoweroffTiles.includes(name) ? "Off" : "Wake";
      }
      if (kinds.tailscale) {
        bar.dataset.tailscale = tailscaleState;
        const element = bar.querySelector(".svcctl-tailscale");
        element.disabled = state !== "up" || tailscaleState === "unknown";
        element.dataset.label = `Tail ${tailscaleState === "unknown" ? "?" : tailscaleState}`;
        element.title =
          tailscaleState === "on" ? `Turn Tailscale off on ${name}` : `Turn Tailscale on on ${name}`;
      }
      if (kinds.ports) {
        bar.dataset.ports = portState;
        const open = portStates[name] || {};
        const menu = card.querySelector(":scope > .svcctl-ports-menu");
        for (const row of menu.children) {
          row.dataset.open = String(!!open[row.dataset.port]);
          const run = row.querySelector("button");
          if (!run) continue;
          const unit = run.dataset.unit;
          const active = unitActive(displayState(unit));
          run.innerHTML = iconSvg(active ? "stop" : "play");
          run.title = active ? `Stop ${unit}` : `Start ${unit}`;
          run.dataset.label = active ? "Stop" : "Start";
        }
        const element = bar.querySelector(".svcctl-ports");
        element.disabled = state !== "up";
        if (element.disabled) {
          menu.hidden = true;
          element.setAttribute("aria-expanded", "false");
        }
      }
      if (kinds.reboot) bar.querySelector(".svcctl-reboot").disabled = state !== "up";
      if (kinds.switch) {
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
  // Uptime counts up between fetches; render() skips unchanged tiles.
  setInterval(render, 30000);
})();
