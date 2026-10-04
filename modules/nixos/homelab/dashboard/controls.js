// Start/stop/restart buttons on tiles backed by a systemd unit, and a wake
// button on tiles for another machine (controls.nix). `svcctlTiles` and
// `svcctlWakeTiles` (tile names) are defined ahead of this file by default.nix.
(() => {
  const api = "/api/svc";
  const headers = { "X-Svcctl": "1" };
  let states = {};
  // Tile name -> when its wake was sent; shown as "waking" until the host
  // answers pings or the window lapses (a cold boot takes a while).
  const wakeSent = {};
  const wakeWindow = 120 * 1000;

  const call = (method, path) =>
    fetch(api + path, { method, headers }).then((response) =>
      response.ok ? response.json() : Promise.reject(response.status),
    );

  const refresh = () =>
    call("GET", "/status")
      .then((next) => {
        states = next;
        render();
      })
      .catch(() => {});

  // Several quick polls after an action, since systemctl returns before the
  // unit has actually changed state.
  const settle = () => [1, 3, 6, 12].forEach((s) => setTimeout(refresh, s * 1000));
  const settleWake = () => [5, 15, 30, 45, 60, 90, 120].forEach((s) => setTimeout(refresh, s * 1000));

  const act = (name, action) => {
    if (action === "stop" && !confirm(`Stop ${name}?`)) return;
    call("POST", `/${action}/${encodeURIComponent(name)}`)
      .then(() => {
        if (action !== "wake") return settle();
        wakeSent[name] = Date.now();
        render();
        settleWake();
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

  const build = (name, wakeable) => {
    const bar = document.createElement("div");
    bar.className = "svcctl";
    const state = document.createElement("span");
    state.className = "svcctl-state";
    if (wakeable) {
      bar.append(state, button(name, "wake", "⏻"));
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
    const state = states[name] || "unknown";
    if (state === "up") delete wakeSent[name];
    else if (Date.now() - wakeSent[name] < wakeWindow) return "waking";
    return state;
  };

  // Only touches the DOM when something changed: the page's MutationObserver
  // calls this again on every mutation.
  const render = () => {
    for (const tile of document.querySelectorAll("li.service[data-name]")) {
      const name = tile.dataset.name;
      const wakeable = svcctlWakeTiles.includes(name);
      if (!wakeable && !svcctlTiles.includes(name)) continue;
      const card = tile.firstElementChild;
      if (!card) continue;
      let bar = card.querySelector(":scope > .svcctl");
      if (!bar) {
        bar = build(name, wakeable);
        card.append(bar);
      }
      const state = displayState(name);
      if (bar.dataset.state !== state) {
        bar.dataset.state = state;
        bar.querySelector(".svcctl-state").textContent = state;
        if (wakeable) {
          bar.querySelector(".svcctl-wake").disabled = state === "up" || state === "waking";
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
