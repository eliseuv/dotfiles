// Task manager: a floating button that opens a panel of per-service CPU,
// memory, task and disk usage from svcctl's /usage (svcctl.py). It lives
// directly under <body>, outside Homepage's React root, so re-renders can't
// remove it. Polls only while open.
(() => {
  const interval = 3000;
  const columns = [
    { key: "label", title: "Service", text: true },
    { key: "cpu", title: "CPU", format: (v) => `${v.toFixed(1)}%` },
    { key: "memory", title: "Memory", format: (v) => bytes(v) },
    { key: "tasks", title: "Tasks", format: (v) => String(v) },
    { key: "read", title: "Read", format: (v) => `${bytes(v)}/s` },
    { key: "write", title: "Write", format: (v) => `${bytes(v)}/s` },
  ];
  let sortKey = "cpu";
  let showAll = false;
  let data = null;
  let timer = null;

  function bytes(value) {
    const units = ["B", "KiB", "MiB", "GiB", "TiB"];
    let unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return `${value >= 100 || unit === 0 ? Math.round(value) : value.toFixed(1)} ${units[unit]}`;
  }

  // The tile name where there is one, else the unit without its suffix.
  const displayName = (row) => row.label || row.unit.replace(/\.service$/, "");

  const toggle = document.createElement("button");
  toggle.type = "button";
  toggle.id = "tasks-toggle";
  toggle.textContent = "Tasks";
  toggle.title = "Resource usage per service";

  const panel = document.createElement("section");
  panel.id = "tasks-panel";
  panel.hidden = true;

  const summary = document.createElement("div");
  summary.className = "tasks-summary";
  const more = document.createElement("button");
  more.type = "button";
  more.className = "tasks-more";
  const table = document.createElement("table");
  panel.append(summary, table, more);

  const sortValue = (row, key) => (key === "label" ? displayName(row).toLowerCase() : row[key]);

  const render = () => {
    if (!data) return;
    const rows = [...data.services].sort((a, b) => {
      const [x, y] = [sortValue(a, sortKey), sortValue(b, sortKey)];
      if (sortKey === "label") return x < y ? -1 : x > y ? 1 : 0;
      return y - x;
    });
    const cpuTotal = rows.reduce((sum, row) => sum + row.cpu, 0);
    const memoryTotal = rows.reduce((sum, row) => sum + row.memory, 0);
    summary.textContent =
      `CPU ${cpuTotal.toFixed(0)}% of ${data.cores * 100}%` +
      ` · Memory ${bytes(memoryTotal)} of ${bytes(data.memory_total)}` +
      ` · ${rows.length} services`;

    const shown = showAll ? rows : rows.slice(0, 12);
    const maxCpu = data.cores * 100;
    table.replaceChildren();
    const head = table.createTHead().insertRow();
    for (const column of columns) {
      const cell = document.createElement("th");
      cell.textContent = column.title;
      cell.dataset.sorted = String(column.key === sortKey);
      cell.addEventListener("click", () => {
        sortKey = column.key;
        render();
      });
      head.append(cell);
    }
    const body = table.createTBody();
    for (const row of shown) {
      const tr = body.insertRow();
      tr.title = row.unit;
      if (row.label) tr.className = "tasks-tile";
      for (const column of columns) {
        const cell = tr.insertCell();
        cell.textContent = column.text ? displayName(row) : column.format(row[column.key]);
        if (column.key === "cpu") cell.style.setProperty("--fill", `${Math.min(row.cpu / maxCpu, 1) * 100}%`);
        if (column.key === "memory")
          cell.style.setProperty("--fill", `${Math.min(row.memory / data.memory_total, 1) * 100}%`);
      }
    }
    more.hidden = rows.length <= 12;
    more.textContent = showAll ? "Show top 12" : `Show all ${rows.length}`;
  };

  const poll = () =>
    fetch("/api/svc/usage", { headers: { "X-Svcctl": "1" } })
      .then((response) => (response.ok ? response.json() : Promise.reject(response.status)))
      .then((next) => {
        data = next;
        render();
      })
      .catch(() => {
        summary.textContent = "Usage unavailable";
      });

  const setOpen = (open) => {
    panel.hidden = !open;
    toggle.setAttribute("aria-expanded", String(open));
    clearInterval(timer);
    if (open) {
      poll();
      timer = setInterval(poll, interval);
    }
  };

  toggle.addEventListener("click", () => setOpen(panel.hidden));
  more.addEventListener("click", () => {
    showAll = !showAll;
    render();
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !panel.hidden) setOpen(false);
  });
  document.body.append(toggle, panel);
})();
