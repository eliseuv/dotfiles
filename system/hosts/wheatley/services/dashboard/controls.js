// Start/stop/restart buttons on tiles backed by a systemd unit (controls.nix).
// `svcctlTiles` (tile names) is defined ahead of this file by default.nix.
(() => {
  const api = "/api/svc";
  const headers = { "X-Svcctl": "1" };
  let states = {};

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

  const act = (name, action) => {
    if (action === "stop" && !confirm(`Stop ${name}?`)) return;
    call("POST", `/${action}/${encodeURIComponent(name)}`)
      .then(settle)
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

  const build = (name) => {
    const bar = document.createElement("div");
    bar.className = "svcctl";
    const state = document.createElement("span");
    state.className = "svcctl-state";
    bar.append(
      state,
      button(name, "start", "▶"),
      button(name, "stop", "■"),
      button(name, "restart", "↻"),
    );
    return bar;
  };

  // Only touches the DOM when something changed: the page's MutationObserver
  // calls this again on every mutation.
  const render = () => {
    for (const tile of document.querySelectorAll("li.service[data-name]")) {
      const name = tile.dataset.name;
      if (!svcctlTiles.includes(name)) continue;
      const card = tile.firstElementChild;
      if (!card) continue;
      let bar = card.querySelector(":scope > .svcctl");
      if (!bar) {
        bar = build(name);
        card.append(bar);
      }
      const state = states[name] || "unknown";
      if (bar.dataset.state !== state) {
        bar.dataset.state = state;
        bar.querySelector(".svcctl-state").textContent = state;
        const active = state === "active" || state === "activating" || state === "reloading";
        bar.querySelector(".svcctl-start").disabled = active;
        bar.querySelector(".svcctl-stop").disabled = !active;
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
