// Add navigation and search around Homepage's existing cards. React retains
// ownership of every service, widget, icon and control inside its root.
(() => {
  const hostPage = document.body.hasAttribute("data-repo");
  const groups = ["Hosts", "Tools", "Media", "Games"];
  const slug = (name) => `facility-${name.toLowerCase()}`;
  const element = (tag, className, content) => {
    const node = document.createElement(tag);
    node.className = className;
    if (content) node.textContent = content;
    return node;
  };
  document.body.classList.add("facility-layout");

  const sidebar = element("aside", "facility-sidebar");
  sidebar.setAttribute("aria-label", "Facility navigation");
  const brand = element("a", "facility-brand");
  brand.href = "/";
  brand.append(element("span", "facility-mark"), element("span", "", "Aperture Science"));
  const subtitle = element("p", "facility-subtitle", "Enrichment Center");
  const nav = element("nav", "facility-nav");
  for (const [index, name] of ["Overview", ...groups].entries()) {
    const link = element("a", "facility-nav-link");
    link.href = name === "Overview" ? "/" : `${hostPage ? "/" : ""}#${slug(name)}`;
    link.dataset.section = name;
    if (name === (hostPage ? "Hosts" : "Overview")) link.setAttribute("aria-current", "page");
    link.append(element("span", "facility-nav-number", String(index).padStart(2, "0")), element("span", "", name));
    nav.append(link);
  }
  const tasks = element(hostPage ? "a" : "button", "facility-nav-link");
  tasks.append(element("span", "facility-nav-number", "05"), element("span", "", "Tasks"));
  if (hostPage) tasks.href = "/?tasks=1";
  else {
    tasks.type = "button";
    tasks.setAttribute("aria-controls", "tasks-panel");
    tasks.addEventListener("click", () => {
      const toggle = document.getElementById("tasks-toggle");
      toggle?.click();
      tasks.setAttribute("aria-expanded", toggle?.getAttribute("aria-expanded") || "false");
    });
  }
  nav.append(tasks);
  const sign = element("div", "facility-placard");
  sign.append(element("strong", "", hostPage ? "01" : "00"), element("span", "", hostPage ? "Host configuration" : "Facility overview"));
  sidebar.append(brand, subtitle, nav, sign, element("p", "facility-subtitle", "Aperture Laboratories"));
  document.body.prepend(sidebar);

  if (hostPage) {
    const preference = matchMedia("(prefers-color-scheme: dark)");
    const sync = () => document.documentElement.classList.toggle("dark", preference.matches);
    sync();
    preference.addEventListener("change", sync);
    return;
  }
  const toolbar = element("div", "facility-toolbar");
  toolbar.append(element("p", "facility-eyebrow", "Aperture Science / Facility Control"));
  const searchLabel = element("label", "facility-search");
  searchLabel.append(element("span", "facility-visually-hidden", "Search hosts and services"));
  const search = element("input", "");
  search.type = "search";
  search.placeholder = "Search hosts or services /";
  search.autocomplete = "off";
  searchLabel.append(search);
  const result = element("span", "facility-search-result");
  result.setAttribute("role", "status");
  toolbar.append(searchLabel, result);
  document.body.insertBefore(toolbar, document.getElementById("__next"));

  const groupsInPage = () => [...document.querySelectorAll(".services-group")];
  const markGroups = () => {
    for (const group of groupsInPage()) {
      const name = group.querySelector(".service-group-name")?.textContent.trim();
      if (!groups.includes(name)) continue;
      const id = slug(name);
      if (group.id !== id) group.id = id;
      if (group.dataset.facilityGroup !== name) group.dataset.facilityGroup = name;
    }
  };
  let query = "";
  const filter = () => {
    const cards = [...document.querySelectorAll("li.service[data-name]")];
    let matches = 0;
    for (const card of cards) {
      const description = card.querySelector(".service-description")?.textContent || "";
      const visible = `${card.dataset.name} ${description}`.toLowerCase().includes(query);
      matches += Number(visible);
      if (card.dataset.facilityFiltered !== String(!visible)) card.dataset.facilityFiltered = String(!visible);
    }
    const message = query ? `${matches} of ${cards.length} hosts and services` : "";
    if (result.textContent !== message) result.textContent = message;
  };
  search.addEventListener("input", () => {
    query = search.value.trim().toLowerCase();
    filter();
  });
  document.addEventListener("keydown", (event) => {
    if (event.target.closest?.("input, textarea, select, [contenteditable]")) return;
    if (event.key === "/" && !event.ctrlKey && !event.metaKey && !event.altKey) {
      event.preventDefault();
      search.focus();
    }
  });
  nav.addEventListener("click", (event) => {
    const link = event.target.closest("a[data-section]");
    if (!link) return;
    for (const item of nav.querySelectorAll("a[data-section]")) item.removeAttribute("aria-current");
    link.setAttribute("aria-current", "page");
  });

  let openedTasks = false;
  const update = () => {
    markGroups();
    filter();
    const toggle = document.getElementById("tasks-toggle");
    const expanded = toggle?.getAttribute("aria-expanded") || "false";
    if (tasks.getAttribute("aria-expanded") !== expanded) tasks.setAttribute("aria-expanded", expanded);
    if (!openedTasks && toggle && new URLSearchParams(location.search).get("tasks") === "1") {
      openedTasks = true;
      toggle.click();
    }
  };
  new MutationObserver(update).observe(document.documentElement, { childList: true, subtree: true });
  update();
})();
