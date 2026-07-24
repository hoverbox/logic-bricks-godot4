(() => {
  "use strict";

  const NAVIGATION_HTML = `<aside class="sidebar" id="site-sidebar">
  <div class="sidebar-head">
    <h3>Documentation</h3>
    <button aria-label="Close navigation" class="sidebar-close" type="button">×</button>
  </div>
  <nav>
    <a data-page="index.html" href="index.html">Home</a>
    <a data-page="getting-started.html" href="getting-started.html">Getting Started</a>
    <a data-page="first-chain.html" href="first-chain.html">Your First Logic Chain</a>
    <a data-page="interface.html" href="interface.html">Interface &amp; Organization</a>
    <a data-page="variables-states.html" href="variables-states.html">Variables, States &amp; Frames</a>
    <div class="nav-group" data-nav-group="3d">
      <div class="nav-group-header">
        <a href="sensors-3d.html">3D Bricks</a>
        <button aria-expanded="false" aria-label="Toggle 3D Bricks submenu" class="nav-toggle" type="button">▸</button>
      </div>
      <div class="nav-submenu">
        <a data-page="sensors-3d.html" href="sensors-3d.html">Sensors</a>
        <a data-page="controllers-3d.html" href="controllers-3d.html">Controllers</a>
        <a data-page="actuators-3d.html" href="actuators-3d.html">Actuators</a>
      </div>
    </div>
    <div class="nav-group" data-nav-group="2d">
      <div class="nav-group-header">
        <a href="sensors-2d.html">2D Bricks</a>
        <button aria-expanded="false" aria-label="Toggle 2D Bricks submenu" class="nav-toggle" type="button">▸</button>
      </div>
      <div class="nav-submenu">
        <a data-page="sensors-2d.html" href="sensors-2d.html">Sensors</a>
        <a data-page="controllers-2d.html" href="controllers-2d.html">Controllers</a>
        <a data-page="actuators-2d.html" href="actuators-2d.html">Actuators</a>
      </div>
    </div>
    <div class="nav-group" data-nav-group="ui">
      <div class="nav-group-header">
        <a href="sensors-ui.html">UI Bricks</a>
        <button aria-expanded="false" aria-label="Toggle UI Bricks submenu" class="nav-toggle" type="button">▸</button>
      </div>
      <div class="nav-submenu">
        <a data-page="sensors-ui.html" href="sensors-ui.html">Sensors</a>
        <a data-page="controllers-ui.html" href="controllers-ui.html">Controllers</a>
        <a data-page="actuators-ui.html" href="actuators-ui.html">Actuators</a>
      </div>
    </div>
    <a data-page="advanced.html" href="advanced.html">Advanced</a>
    <a data-page="debugging.html" href="debugging.html">Debugging</a>
    <a data-page="graph-export.html" href="graph-export.html">Graph Export</a>
    <a data-page="troubleshooting.html" href="troubleshooting.html">Troubleshooting</a>
    <a data-page="brick-reference.html" href="brick-reference.html">Brick Reference A-Z</a>
  </nav>
</aside>`;

  const HEADER_HTML = `
    <header class="site-header">
      <div class="header-inner">
        <a class="brand" href="index.html">
          <span class="brand-mark">LB</span>
          <span>Logic Bricks<small>Documentation</small></span>
        </a>
        <button aria-label="Show keyboard shortcuts" class="shortcut-help-btn" title="Keyboard shortcuts (?)" type="button">⌨</button>
        <button aria-controls="site-sidebar" aria-expanded="false" aria-label="Toggle navigation" class="menu-btn" type="button">Menu</button>
      </div>
    </header>`;

  const FOOTER_HTML = `
    <footer class="footer">Logic Bricks documentation • Generated from the current addon structure</footer>`;

  const SHORTCUT_DIALOG_HTML = `
    <dialog class="shortcut-dialog" id="shortcutDialog">
      <div class="shortcut-dialog-head">
        <h2>Keyboard shortcuts</h2>
        <button aria-label="Close keyboard shortcuts" data-close-shortcuts type="button">×</button>
      </div>
      <div class="shortcut-grid">
        <div><kbd>/</kbd><span>Focus search</span></div>
        <div><kbd>?</kbd><span>Open this shortcut guide</span></div>
        <div><kbd>←</kbd><span>Previous documentation page</span></div>
        <div><kbd>→</kbd><span>Next documentation page</span></div>
        <div><kbd>G</kbd> then <kbd>H</kbd><span>Go to Home</span></div>
        <div><kbd>Esc</kbd><span>Close menus or dialogs</span></div>
      </div>
    </dialog>`;

  function render(selector, html) {
    const target = document.querySelector(selector);
    if (target) target.outerHTML = html;
  }

  render("[data-site-header]", HEADER_HTML);
  render("[data-site-sidebar]", NAVIGATION_HTML);
  render("[data-site-footer]", FOOTER_HTML);
  render("[data-shortcut-dialog]", SHORTCUT_DIALOG_HTML);

  const currentPage = document.body.dataset.page || "index.html";
  document.querySelectorAll(".sidebar [data-page]").forEach((link) => {
    link.classList.toggle("active", link.dataset.page === currentPage);
  });

  const activeGroup = document.querySelector(`.nav-submenu [data-page="${currentPage}"]`)?.closest(".nav-group");
  if (activeGroup) {
    activeGroup.classList.add("open");
    const toggle = activeGroup.querySelector(".nav-toggle");
    if (toggle) {
      toggle.setAttribute("aria-expanded", "true");
      toggle.textContent = "▾";
    }
  }
})();
