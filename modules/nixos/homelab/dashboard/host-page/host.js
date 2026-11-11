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
  let loading = false;
  let requestingSwitch = false;
  let switchError = "";
  let comparison = null;
  let comparisonRequest = 0;
  let logLoading = false;
  let logTimer = null;
  let lastHistory = "";
  // "idle"/"switching"/"failed"/"unknown", from svcctl's status.
  let switchState = null;
  let switchTimer = null;
  let switchPollRequest = 0;
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
    if (loading) return;
    loading = true;
    document.getElementById("refresh").disabled = true;
    document.getElementById("load-status").textContent = "Fetching host report…";
    clearTimeout(loadTimer);
    fetch(`/api/hosts/${encodeURIComponent(host)}${refresh ? "?refresh=1" : ""}`)
      .then((response) => (response.ok ? response.json() : Promise.reject(response.status)))
      .then((next) => {
        const first = data === null;
        data = next;
        render();
        document.getElementById("load-status").textContent = data.refreshing
          ? "Refreshing host report…" : `Report updated ${ago(data.fetched_at)}`;
        if (first && data.switch) pollSwitch();
      })
      .catch((status) => {
        if (status === 404) return renderMissing();
        document.getElementById("load-status").textContent = "Connection failed. Showing the last available report; retry with Refresh.";
      })
      .finally(() => {
        loading = false;
        document.getElementById("refresh").disabled = false;
        if (data === null && document.body.dataset.missing) return;
        // Quickly while hostctl is fetching a report, so it shows as soon as
        // it lands.
        loadTimer = setTimeout(load, data?.refreshing ? 2000 : 60000);
      });
  };

  const pollSwitch = () => {
    clearTimeout(switchTimer);
    const request = ++switchPollRequest;
    fetch("/api/svc/status", { headers: svcHeaders })
      .then((response) => (response.ok ? response.json() : Promise.reject(response.status)))
      .then((status) => {
        if (request !== switchPollRequest) return;
        const next = status.switch[data.tile] ?? "unknown";
        // A finished switch made a new generation; fetch it now rather than
        // at the next background refresh.
        if (switchState === "switching" && next !== "switching") {
          load(true);
          if (document.getElementById("switch-output").open) loadLog();
        }
        switchState = next;
        renderSwitch();
      })
      .catch(() => {
        if (request !== switchPollRequest) return;
        switchState = "unknown";
        renderSwitch();
      })
      .finally(() => {
        if (request === switchPollRequest)
          switchTimer = setTimeout(pollSwitch, switchState === "switching" ? 3000 : 15000);
      });
  };

  const doSwitch = async () => {
    if (requestingSwitch || switchState === "switching") return;
    if (!confirm(`Rebase local commits onto origin/master on ${data.tile}, build and switch?`)) return;
    requestingSwitch = true;
    switchError = "";
    renderSwitch();
    try {
      const response = await fetch(`/api/svc/switch/${encodeURIComponent(data.tile)}`, {
        method: "POST", headers: svcHeaders,
      });
      if (response.status === 401) {
        switchError = "Login required to switch this host.";
        if (confirm("Log in to use the dashboard controls?")) location.href = "/api/svc/login";
        return;
      }
      if (!response.ok) throw new Error(`Switch request failed (${response.status})`);
      switchState = "switching";
      clearTimeout(switchTimer);
      switchPollRequest++;
      switchTimer = setTimeout(pollSwitch, 3000);
    } catch (error) {
      switchError = `${error.message}. Refresh status before retrying if the connection was lost.`;
    } finally {
      requestingSwitch = false;
      renderSwitch();
    }
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
    button.disabled = requestingSwitch || state === "switching";
    button.textContent = requestingSwitch ? "Requesting…" : switchLabels[state];
    document.getElementById("switch-panel").hidden = !data.switch;
    document.getElementById("switch-status").textContent = switchError || (requestingSwitch
      ? "Submitting switch request…" : {
        idle: "Switch service is idle. Deployment status is shown above.",
        switching: "Switch in progress. Open recent output for build and activation messages.",
        failed: "Last switch failed. Inspect recent output before retrying.",
        unknown: "Switch status unavailable. Refresh before starting another switch.",
      }[state]);
    scheduleLog();
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
        master.evaluated_at && ` · evaluated ${date(master.evaluated_at)}`,
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
        bootedRow && el("dd", {}, bootedRow, booted && [" · ", commit(booted.revision)]),
        el("dt", {}, "Master"),
        el("dd", {}, masterRow),
        el("dt", {}, "Report"),
        el("dd", {}, reportRow),
        unreachable && el("dt", {}, "Report error"),
        unreachable && el("dd", { class: "error" }, data.error),
      ),
    );
    renderSwitch();
  };

  // One `nix store diff-closures` line: "<name>: <old> → <new>, <size>",
  // either part optional. Versions are comma-separated lists, "∅" for not in
  // the closure and "ε" for a path without a version (config files and the
  // like). The size is coloured even through a pipe or with NO_COLOR, and
  // only signed when it shrinks, so the escapes are stripped here, which
  // also covers diffs hostctl cached before this.
  const change = (line) => {
    line = line.replace(/\x1b\[[0-9;]*m/g, "");
    const split = line.indexOf(": ");
    const name = split < 0 ? line : line.slice(0, split);
    let rest = split < 0 ? "" : line.slice(split + 2);
    let size = null;
    const sized = rest.match(/(?:^|, )(-?[\d.]+ [KMGTP]?i?B)$/);
    if (sized) {
      size = sized[1];
      rest = rest.slice(0, sized.index);
    }
    let kind = "resized";
    let detail = "";
    if (rest.includes(" → ")) {
      const [from, to] = rest.split(" → ");
      const versions = (list) =>
        list
          .split(", ")
          .filter((version) => version !== "ε")
          .join(", ");
      if (from === "∅") [kind, detail] = ["added", versions(to)];
      else if (to === "∅") [kind, detail] = ["removed", versions(from)];
      else {
        kind = "updated";
        detail = `${versions(from) || "unversioned"} → ${versions(to) || "unversioned"}`;
      }
    }
    return { name, kind, detail, size };
  };

  const changeRow = ({ name, kind, detail, size }) => {
    const shrunk = size?.startsWith("-");
    return el(
      "li",
      { class: kind },
      el("span", { class: "kind" }, kind),
      el("span", { class: "name" }, name),
      el("span", { class: "detail" }, detail),
      size &&
        el("span", { class: shrunk ? "size shrunk" : "size grown" }, shrunk ? `−${size.slice(1)}` : `+${size}`),
    );
  };

  const details = (generation, previous) => {
    const fetched = diffs[generation.number];
    if (!fetched) return el("div", { class: "details muted" }, "Loading changes…");
    if (fetched.error) return el("div", { class: "details error" }, fetched.error, " ",
      el("button", { type: "button", onclick: () => {
        delete diffs[generation.number];
        expanded.delete(generation.number);
        toggle(generation.number);
      } }, "Retry changes"));
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
        ? el("ul", { class: "changes" }, lines.map(change).map(changeRow))
        : el("p", { class: "muted" }, "No version changes; configuration only."),
    );
  };

  const renderGenerations = () => {
    const list = document.getElementById("generations");
    const report = data.report;
    if (!report) {
      lastHistory = "";
      list.replaceChildren(el("li", { class: "muted" }, "No report yet."));
      filterHistory();
      return;
    }
    const historyKey = JSON.stringify([data.report, data.master?.path, [...expanded], diffs]);
    if (lastHistory === historyKey) { filterHistory(); return; }
    lastHistory = historyKey;
    const focused = document.activeElement?.closest("[data-generation]")?.dataset.generation;
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
                "data-generation": generation.number,
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
    if (focused) list.querySelector(`[data-generation="${focused}"]`)?.focus({ preventScroll: true });
    if (!all.length) list.replaceChildren(el("li", { class: "muted" }, "No kept generations."));
    filterHistory();
  };

  const render = () => {
    const name = data.tile || host;
    document.title = `${name} · Aperture Science`;
    document.getElementById("title").textContent = name;
    const focused = document.activeElement?.id;
    renderSummary();
    if (focused === "switch") document.getElementById("switch")?.focus({ preventScroll: true });
    renderGenerations();
    updateSelectors();
  };

  const renderMissing = () => {
    document.body.dataset.missing = "true";
    document.getElementById("load-status").textContent = "Host unavailable.";
    document.getElementById("title").textContent = host || "No host";
    document
      .getElementById("summary")
      .replaceChildren(el("p", { class: "muted" }, `No host page for "${host}".`));
  };

  const filterHistory = () => {
    const query = document.getElementById("history-search").value.trim().toLowerCase();
    const rows = [...document.querySelectorAll("#generations > .generation")];
    for (const row of rows) row.hidden = !row.querySelector(".row").textContent.toLowerCase().includes(query);
    document.getElementById("history-count").textContent = `${rows.filter(row => !row.hidden).length} of ${rows.length} generations`;
  };

  const updateSelectors = () => {
    const all = generations();
    const target = byPath(data.report?.current) || all.at(-1);
    const previous = all[all.indexOf(target) - 1] || all.at(-2) || target;
    for (const [id, fallback] of [["compare-from", previous], ["compare-to", target]]) {
      const select = document.getElementById(id);
      const key = JSON.stringify(all.map(g => [g.number, g.revision, g.path]));
      if (select.dataset.key !== key) {
        const selected = select.value;
        select.replaceChildren(...all.map(g => el("option", { value: g.number }, `#${g.number} · ${g.revision?.slice(0, 7) || "unknown revision"}`)));
        select.value = all.some(g => String(g.number) === selected) ? selected : String(fallback?.number || "");
        select.dataset.key = key;
        if (selected && select.value !== selected) invalidateComparison();
      }
      select.disabled = !all.length;
    }
    document.getElementById("compare").disabled = !all.length;
    document.getElementById("swap").disabled = !all.length;
  };

  const renderComparison = () => {
    const panel = document.getElementById("comparison");
    if (!comparison) return;
    const { diff, from, to } = comparison;
    const changes = diff.changes.split("\n").filter(Boolean).map(change);
    const query = document.getElementById("package-search").value.toLowerCase().trim();
    const kind = document.getElementById("change-kind").value;
    const visible = changes.filter(c => (!kind || c.kind === kind) && `${c.name} ${c.detail}`.toLowerCase().includes(query));
    const counts = ["added", "removed", "updated", "resized"].map(k => `${changes.filter(c => c.kind === k).length} ${k}`).join(" · ");
    const a = splitRevision(from?.revision), b = splitRevision(to?.revision);
    const link = a.rev && b.rev && a.rev !== b.rev && !a.dirty && !b.dirty
      ? el("a", { href: `${repo}/compare/${a.rev}...${b.rev}`, target: "_blank", rel: "noopener" }, "Configuration changes") : null;
    panel.replaceChildren(
      el("p", {}, `Generation ${diff.base} → ${diff.number}`, link && [" · ", link]),
      el("p", { class: "muted" }, counts),
      changes.length ? el("p", { class: "muted" }, `${visible.length} of ${changes.length} changes`) : el("p", {}, "No closure version or size changes reported."),
      el("ul", { class: "changes" }, visible.map(changeRow)),
      changes.length && !visible.length && el("p", {}, "No changes match these filters."),
    );
  };

  const invalidateComparison = () => {
    comparisonRequest++;
    comparison = null;
    document.getElementById("comparison").textContent = "Selection changed. Choose Compare to load changes.";
  };

  const doCompare = async () => {
    const request = ++comparisonRequest;
    const base = document.getElementById("compare-from").value;
    const number = document.getElementById("compare-to").value;
    const panel = document.getElementById("comparison");
    comparison = null;
    panel.textContent = "Comparing closures…";
    try {
      const response = await fetch(`/api/hosts/${encodeURIComponent(host)}/compare/${base}/${number}`);
      if (!response.ok) throw new Error(response.status === 404 ? "Comparison unavailable on this dashboard" : (await response.json()).error || "Comparison unavailable");
      const diff = await response.json();
      if (request !== comparisonRequest) return;
      comparison = { diff, from: generations().find(g => g.number === Number(base)), to: generations().find(g => g.number === Number(number)) };
      renderComparison();
    } catch (error) {
      if (request === comparisonRequest) panel.textContent = `${error.message}. Refresh the host report or retry; remote hosts may need updating.`;
    }
  };

  const scheduleLog = () => {
    if (!document.getElementById("switch-output").open || switchState !== "switching") {
      clearTimeout(logTimer);
      logTimer = null;
    } else if (logTimer === null && !logLoading) {
      logTimer = setTimeout(() => { logTimer = null; loadLog(); }, 3000);
    }
  };

  const loadLog = async () => {
    if (logLoading || !data?.switch) return;
    logLoading = true;
    const status = document.getElementById("log-status");
    status.textContent = "Fetching output…";
    document.getElementById("refresh-log").disabled = true;
    try {
      const response = await fetch(`/api/svc/switch-log/${encodeURIComponent(data.tile)}`, { headers: svcHeaders });
      if (!response.ok) throw new Error(response.status === 404 ? "Switch output unavailable on this host" : (await response.json()).error || "Switch output unavailable");
      const result = await response.json();
      const output = document.getElementById("log-output");
      const atBottom = output.scrollHeight - output.scrollTop - output.clientHeight < 24;
      const position = output.scrollTop;
      output.textContent = result.output || "No switch output recorded in this boot.";
      output.scrollTop = atBottom ? output.scrollHeight : position;
      status.textContent = `Fetched ${date(result.fetched_at)}${result.truncated ? " · output truncated" : ""}`;
    } catch (error) {
      status.textContent = `${error.message}. Previous output retained.`;
    } finally {
      logLoading = false;
      document.getElementById("refresh-log").disabled = false;
      scheduleLog();
    }
  };

  document.getElementById("refresh").addEventListener("click", () => load(true));
  document.getElementById("history-search").addEventListener("input", filterHistory);
  document.getElementById("compare").addEventListener("click", doCompare);
  for (const id of ["compare-from", "compare-to"]) document.getElementById(id).addEventListener("change", invalidateComparison);
  document.getElementById("swap").addEventListener("click", () => {
    const from = document.getElementById("compare-from"), to = document.getElementById("compare-to");
    [from.value, to.value] = [to.value, from.value];
    invalidateComparison();
  });
  document.getElementById("package-search").addEventListener("input", renderComparison);
  document.getElementById("change-kind").addEventListener("change", renderComparison);
  document.getElementById("refresh-log").addEventListener("click", loadLog);
  document.getElementById("switch-output").addEventListener("toggle", () => {
    if (document.getElementById("switch-output").open) loadLog();
    else { clearTimeout(logTimer); logTimer = null; }
  });
  document.getElementById("title").textContent = host;
  load(true);
})();
