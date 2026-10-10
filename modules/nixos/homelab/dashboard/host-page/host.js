// A host page: the host's generations, what changed between them and whether
// it runs what master builds, from hostctl (hosts.nix). The switch button and
// its state are svcctl's, the same as on the host's dashboard tile
// (controls.js).
(() => {
  const host = new URLSearchParams(location.search).get("host") || "";
  const repo = document.body.dataset.repo;
  const svcHeaders = { "X-Svcctl": "1" };
  let data = null;
  let loadTimer = null;
  // "idle"/"switching"/"failed"/"unknown", from svcctl's status.
  let switchState = null;
  // Generation number -> {diff} or {error} once fetched, for expanded rows.
  const diffs = {};
  const expanded = new Set();

  const el = (tag, attrs = {}, ...children) => {
    const node = document.createElement(tag);
    for (const [key, value] of Object.entries(attrs)) {
      if (value == null || value === false) continue;
      if (key.startsWith("on")) node.addEventListener(key.slice(2), value);
      else node.setAttribute(key, value);
    }
    node.append(...children.flat().filter((child) => child != null && child !== false));
    return node;
  };

  const ago = (seconds) => {
    if (seconds == null) return "never";
    const elapsed = Math.max(0, Date.now() / 1000 - seconds);
    if (elapsed < 60) return "just now";
    if (elapsed < 3600) return `${Math.floor(elapsed / 60)} min ago`;
    if (elapsed < 86400) return `${Math.floor(elapsed / 3600)} h ago`;
    return `${Math.floor(elapsed / 86400)} d ago`;
  };

  const date = (seconds) =>
    new Date(seconds * 1000).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" });

  // Recorded as "<rev>" or "<rev>-dirty" (services/dotfiles-switch.nix). A
  // commit made and switched to here but not pushed yet has no page on
  // GitHub until it is.
  const splitRevision = (revision) => {
    const [rev, dirty] = (revision || "").split("-");
    return { rev, dirty: dirty === "dirty" };
  };

  const commit = (revision) => {
    if (!revision)
      return el(
        "span",
        { class: "commit muted", title: "Switched before commits were recorded" },
        "—",
      );
    const { rev, dirty } = splitRevision(revision);
    return el(
      "span",
      { class: "commit" },
      el("a", { href: `${repo}/commit/${rev}`, target: "_blank", rel: "noopener" }, rev.slice(0, 7)),
      dirty && el("span", { class: "tag dirty", title: "Built with uncommitted changes" }, "dirty"),
    );
  };

  const generations = () => data?.report?.generations ?? [];
  const byPath = (path) => generations().find((generation) => generation.path === path);

  // --------------------------------------------------------------- loading

  const load = (refresh = false) => {
    clearTimeout(loadTimer);
    fetch(`/api/hosts/${encodeURIComponent(host)}${refresh ? "?refresh=1" : ""}`)
      .then((response) => (response.ok ? response.json() : Promise.reject(response.status)))
      .then((next) => {
        const first = data === null;
        data = next;
        render();
        if (first && data.switch) pollSwitch();
      })
      .catch((status) => {
        if (status === 404) return renderMissing();
      })
      .finally(() => {
        if (data === null && document.body.dataset.missing) return;
        // Quickly while hostctl is fetching a report, so it shows as soon as
        // it lands.
        loadTimer = setTimeout(load, data?.refreshing ? 2000 : 60000);
      });
  };

  const pollSwitch = () => {
    fetch("/api/svc/status", { headers: svcHeaders })
      .then((response) => (response.ok ? response.json() : Promise.reject(response.status)))
      .then((status) => {
        const next = status.switch[data.tile] ?? "unknown";
        // A finished switch made a new generation; fetch it now rather than
        // at the next background refresh.
        if (switchState === "switching" && next !== "switching") load(true);
        switchState = next;
        renderSwitch();
      })
      .catch(() => {})
      .finally(() => setTimeout(pollSwitch, switchState === "switching" ? 3000 : 15000));
  };

  const doSwitch = () => {
    if (!confirm(`Pull origin/master on ${data.tile} and switch to it?`)) return;
    fetch(`/api/svc/switch/${encodeURIComponent(data.tile)}`, {
      method: "POST",
      headers: svcHeaders,
    }).then((response) => {
      if (response.status === 401) {
        // svcctl's login page (controls.nix), as on the dashboard.
        if (confirm("Log in to use the dashboard controls?")) location.href = "/api/svc/login";
        return;
      }
      if (!response.ok) return alert(`Switch ${data.tile} failed (${response.status})`);
      switchState = "switching";
      renderSwitch();
    });
  };

  const toggle = (number) => {
    if (expanded.has(number)) expanded.delete(number);
    else expanded.add(number);
    if (expanded.has(number) && !diffs[number]) {
      fetch(`/api/hosts/${encodeURIComponent(host)}/diff/${number}`)
        .then((response) =>
          response.json().then((body) => (response.ok ? body : Promise.reject(body.error))),
        )
        .then((diff) => (diffs[number] = { diff }))
        .catch((error) => (diffs[number] = { error: String(error || "unavailable") }))
        .finally(render);
    }
    render();
  };

  // ------------------------------------------------------------- rendering

  const statusLabels = {
    current: "Up to date with master",
    pending: "Master's system is built, not running",
    differs: "Differs from master",
    unknown: "Deploy status unknown",
  };

  const switchLabels = {
    idle: "Switch",
    switching: "Switching",
    failed: "Switch failed",
    unknown: "Switch",
  };

  const renderSwitch = () => {
    const button = document.getElementById("switch");
    if (!button) return;
    const state = switchState ?? "unknown";
    button.dataset.state = state;
    button.disabled = state === "switching";
    button.textContent = switchLabels[state];
    button.title =
      state === "failed"
        ? "The last switch failed; see journalctl -u dotfiles-switch on the host. Click to retry."
        : "Pull origin/master and switch to it";
  };

  const generationSummary = (generation) =>
    [
      `Generation ${generation.number}`,
      generation.nixos && `NixOS ${generation.nixos}`,
      generation.kernel && `Linux ${generation.kernel}`,
    ]
      .filter(Boolean)
      .join(" · ");

  const renderSummary = () => {
    const { report, master, status } = data;
    const current = report && byPath(report.current);
    const booted = report && byPath(report.booted);

    const runningRow = current
      ? [generationSummary(current), " · ", commit(current.revision)]
      : report
        ? "Not a kept generation (a test switch?)"
        : "No report yet";

    let bootedRow = null;
    if (report && report.booted === report.current) bootedRow = "Same as running";
    else if (report) {
      bootedRow = [booted ? generationSummary(booted) : "Not a kept generation"];
      if (current && booted && current.kernel !== booted.kernel)
        bootedRow.push(el("span", { class: "tag warn" }, "reboot for new kernel"));
    }

    let masterRow;
    if (!master) masterRow = el("span", { class: "muted" }, "Not evaluated yet");
    else
      masterRow = [
        commit(master.rev),
        status.generation != null && ` · generation ${status.generation}`,
        ` · checked ${ago(master.checked_at)}`,
        master.error && el("pre", { class: "error" }, master.error),
      ];

    const unreachable = data.error && (data.attempted_at ?? 0) >= (data.fetched_at ?? 0);
    const reportRow = [
      report ? `As of ${ago(data.fetched_at)}` : "Never fetched",
      data.refreshing && el("span", { class: "muted" }, " · refreshing…"),
      unreachable && el("span", { class: "tag warn", title: data.error }, "unreachable"),
    ];

    const summary = document.getElementById("summary");
    summary.replaceChildren(
      el(
        "div",
        { class: "status-line" },
        el("span", { class: "status", "data-state": status.state }, statusLabels[status.state]),
        data.switch && el("button", { type: "button", id: "switch", onclick: doSwitch }),
      ),
      el(
        "dl",
        {},
        el("dt", {}, "Running"),
        el("dd", {}, runningRow),
        bootedRow && el("dt", {}, "Booted"),
        bootedRow && el("dd", {}, bootedRow),
        el("dt", {}, "Master"),
        el("dd", {}, masterRow),
        el("dt", {}, "Report"),
        el("dd", {}, reportRow),
      ),
    );
    renderSwitch();
  };

  const change = (line) => {
    const split = line.indexOf(": ");
    const name = split < 0 ? line : line.slice(0, split);
    const rest = split < 0 ? "" : line.slice(split + 2);
    const kind = rest.startsWith("∅ →") ? "added" : rest.includes("→ ∅") ? "removed" : "changed";
    return el("li", { class: kind }, el("span", { class: "name" }, name), el("span", {}, rest));
  };

  const details = (generation, previous) => {
    const fetched = diffs[generation.number];
    if (!fetched) return el("div", { class: "details muted" }, "Loading changes…");
    if (fetched.error) return el("div", { class: "details error" }, fetched.error);
    const { diff } = fetched;
    if (diff.base == null) return el("div", { class: "details muted" }, "Oldest kept generation.");
    const base = generations().find((other) => other.number === diff.base) ?? previous;
    const from = splitRevision(base?.revision);
    const to = splitRevision(generation.revision);
    const compare =
      from.rev && to.rev && from.rev !== to.rev && !from.dirty && !to.dirty
        ? el(
            "a",
            { href: `${repo}/compare/${from.rev}...${to.rev}`, target: "_blank", rel: "noopener" },
            "config changes",
          )
        : null;
    const lines = diff.changes.split("\n").filter(Boolean);
    return el(
      "div",
      { class: "details" },
      el("p", {}, `Changes from generation ${diff.base}`, compare && [" · ", compare]),
      lines.length
        ? el("ul", { class: "changes" }, lines.map(change))
        : el("p", { class: "muted" }, "No version changes; configuration only."),
    );
  };

  const renderGenerations = () => {
    const list = document.getElementById("generations");
    const report = data.report;
    if (!report) {
      list.replaceChildren(el("li", { class: "muted" }, "No report yet."));
      return;
    }
    const masterPath = data.master?.path;
    const all = generations();
    list.replaceChildren(
      ...all
        .map((generation, index) => {
          const open = expanded.has(generation.number);
          const onToggle = (event) => {
            if (event.target.closest("a")) return;
            if (event.type === "keydown" && event.key !== "Enter" && event.key !== " ") return;
            event.preventDefault();
            toggle(generation.number);
          };
          return el(
            "li",
            { class: open ? "generation open" : "generation" },
            el(
              "div",
              {
                class: "row",
                role: "button",
                tabindex: "0",
                "aria-expanded": String(open),
                onclick: onToggle,
                onkeydown: onToggle,
              },
              el("span", { class: "number" }, `#${generation.number}`),
              el("span", { class: "date" }, date(generation.date)),
              el(
                "span",
                { class: "tags" },
                generation.path === report.current && el("span", { class: "tag current" }, "running"),
                generation.path === report.booted && el("span", { class: "tag" }, "booted"),
                generation.path === masterPath && el("span", { class: "tag master" }, "master"),
              ),
              el(
                "span",
                { class: "meta" },
                [generation.nixos, generation.kernel && `Linux ${generation.kernel}`]
                  .filter(Boolean)
                  .join(" · "),
              ),
              commit(generation.revision),
            ),
            open && details(generation, all[index - 1]),
          );
        })
        .reverse(),
    );
  };

  const render = () => {
    const name = data.tile || host;
    document.title = `${name} · Aperture Science`;
    document.getElementById("title").textContent = name;
    renderSummary();
    renderGenerations();
  };

  const renderMissing = () => {
    document.body.dataset.missing = "true";
    document.getElementById("title").textContent = host || "No host";
    document
      .getElementById("summary")
      .replaceChildren(el("p", { class: "muted" }, `No host page for "${host}".`));
  };

  document.getElementById("title").textContent = host;
  load(true);
})();
