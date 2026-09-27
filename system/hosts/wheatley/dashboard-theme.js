// Follow the OS light/dark preference. Homepage only reads it on first load
// and then pins its own choice in localStorage, so clear that and drive
// Homepage's (hidden) theme toggle instead of editing classes directly - that
// keeps its React state as the single source of truth.
{
  const prefersDark = matchMedia("(prefers-color-scheme: dark)");
  localStorage.removeItem("theme-mode");

  const syncTheme = () => {
    const toggle = document.querySelector("#theme svg:nth-of-type(2)");
    if (!toggle) return false;
    if (document.documentElement.classList.contains("dark") !== prefersDark.matches) {
      toggle.dispatchEvent(new MouseEvent("click", { bubbles: true }));
    }
    return true;
  };

  if (!syncTheme()) {
    const waitForToggle = new MutationObserver(() => {
      if (syncTheme()) waitForToggle.disconnect();
    });
    waitForToggle.observe(document.documentElement, { childList: true, subtree: true });
  }
  prefersDark.addEventListener("change", syncTheme);
}
