(() => {
  "use strict";

  const SELECTORS = {
    sidebar: ".sidebar",
    menuButton: ".menu-btn",
    closeSidebarButton: ".sidebar-close",
    backToTopButton: ".back-to-top",
    shortcutDialog: "#shortcutDialog",
  };

  function isTyping() {
    const active = document.activeElement;
    return Boolean(
      active &&
      (/INPUT|TEXTAREA|SELECT/.test(active.tagName) || active.isContentEditable)
    );
  }

  function initializeSidebar() {
    const sidebar = document.querySelector(SELECTORS.sidebar);
    const menuButton = document.querySelector(SELECTORS.menuButton);
    const closeButton = document.querySelector(SELECTORS.closeSidebarButton);

    if (!sidebar) return;

    const setOpen = (open) => {
      sidebar.classList.toggle("open", open);
      menuButton?.setAttribute("aria-expanded", String(open));
    };

    menuButton?.addEventListener("click", () => {
      setOpen(!sidebar.classList.contains("open"));
    });

    closeButton?.addEventListener("click", () => setOpen(false));

    sidebar.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => {
        if (window.matchMedia("(max-width: 900px)").matches) {
          setOpen(false);
        }
      });
    });

    document.querySelectorAll(".nav-toggle").forEach((button) => {
      button.addEventListener("click", () => {
        const group = button.closest(".nav-group");
        if (!group) return;

        const open = !group.classList.contains("open");
        group.classList.toggle("open", open);
        button.setAttribute("aria-expanded", String(open));
        button.textContent = open ? "▾" : "▸";
      });
    });
  }

  function initializeBrickSearch() {
    const search = document.querySelector("#docSearch");
    if (!search) return;

    search.addEventListener("input", () => {
      const query = search.value.toLowerCase().trim();

      document.querySelectorAll(".brick").forEach((brick) => {
        brick.hidden = !brick.innerText.toLowerCase().includes(query);
      });

      document.querySelectorAll(".reference-table tbody tr").forEach((row) => {
        row.hidden = !row.innerText.toLowerCase().includes(query);
      });
    });
  }

  function initializeTableOfContents() {
    const links = [...document.querySelectorAll("[data-toc-target]")];
    if (!links.length) return;

    const page = document.body.dataset.page || location.pathname.split("/").pop();
    const sidebarLinks = [
      ...document.querySelectorAll(`.nav-submenu a[href^="${page}#"]`),
    ];
    const targets = links
      .map((link) => document.getElementById(link.dataset.tocTarget))
      .filter(Boolean);

    const markActive = (id) => {
      links.forEach((link) => {
        link.classList.toggle("active", link.dataset.tocTarget === id);
      });
      sidebarLinks.forEach((link) => {
        link.classList.toggle("active-section", link.hash === `#${id}`);
      });
    };

    const observer = new IntersectionObserver(
      (entries) => {
        const firstVisible = entries
          .filter((entry) => entry.isIntersecting)
          .sort(
            (first, second) =>
              first.boundingClientRect.top - second.boundingClientRect.top
          )[0];

        if (firstVisible) markActive(firstVisible.target.id);
      },
      { rootMargin: "-20% 0px -65% 0px", threshold: [0, 1] }
    );

    targets.forEach((target) => observer.observe(target));
    markActive(location.hash.slice(1) || targets[0]?.id);
  }

  function initializeBackToTop() {
    const button = document.querySelector(SELECTORS.backToTopButton);
    if (!button) return;

    const updateVisibility = () => {
      button.classList.toggle("visible", window.scrollY > 500);
    };

    window.addEventListener("scroll", updateVisibility, { passive: true });
    button.addEventListener("click", () => {
      window.scrollTo({ top: 0, behavior: "smooth" });
    });
    updateVisibility();
  }

  function initializeHomeSearch() {
    const input = document.querySelector("#homeDocSearch");
    const results = document.querySelector("#homeSearchResults");
    if (!input || !results) return;

    const index = Array.isArray(window.LOGIC_BRICKS_SEARCH_INDEX)
      ? window.LOGIC_BRICKS_SEARCH_INDEX
      : [];

    const render = (value) => {
      const query = value.trim().toLowerCase();
      if (!query) {
        results.classList.remove("visible");
        results.replaceChildren();
        return;
      }

      const terms = query.split(/\s+/).filter(Boolean);
      const matches = index
        .map((item) => {
          const title = item.title.toLowerCase();
          const searchableText = `${item.title} ${item.label} ${item.description}`.toLowerCase();
          const score = terms.reduce(
            (total, term) =>
              total +
              (title.includes(term) ? 4 : 0) +
              (searchableText.includes(term) ? 1 : 0),
            0
          );
          return { item, score };
        })
        .filter(({ score }) => score > 0)
        .sort(
          (first, second) =>
            second.score - first.score ||
            first.item.title.localeCompare(second.item.title)
        )
        .slice(0, 10);

      results.classList.add("visible");
      results.replaceChildren();

      if (!matches.length) {
        const empty = document.createElement("div");
        empty.className = "home-search-empty";
        empty.textContent =
          "No matching documentation found. Try a brick name, menu category, or workflow.";
        results.append(empty);
        return;
      }

      matches.forEach(({ item }) => {
        const link = document.createElement("a");
        link.className = "home-search-result";
        link.href = item.url;

        const title = document.createElement("strong");
        title.textContent = item.title;

        const description = document.createElement("span");
        description.textContent = `${item.label}${
          item.description ? ` · ${item.description}` : ""
        }`;

        link.append(title, description);
        results.append(link);
      });
    };

    input.addEventListener("input", () => render(input.value));
  }

  function initializeGuidanceControls() {
    document.querySelectorAll("[data-guidance-action]").forEach((button) => {
      button.addEventListener("click", () => {
        const open = button.dataset.guidanceAction === "expand";
        document
          .querySelectorAll("details.collapsible-guidance")
          .forEach((details) => {
            details.open = open;
          });
      });
    });
  }

  function initializeReferenceFilters() {
    const rows = [...document.querySelectorAll(".reference-table tbody tr")];
    const search = document.querySelector("#docSearch");
    const typeFilter = document.querySelector("#typeFilter");
    const domainFilter = document.querySelector("#domainFilter");
    const menuFilter = document.querySelector("#menuFilter");
    const resultCount = document.querySelector("#referenceResultCount");

    if (!rows.length || !menuFilter || !typeFilter || !domainFilter) return;

    const menus = [...new Set(rows.map((row) => row.dataset.menu).filter(Boolean))];
    menus.sort().forEach((menu) => {
      const option = document.createElement("option");
      option.value = menu;
      option.textContent = menu.replace(/\b\w/g, (character) =>
        character.toUpperCase()
      );
      menuFilter.append(option);
    });

    const applyFilters = () => {
      const query = (search?.value || "").trim().toLowerCase();
      let visible = 0;

      rows.forEach((row) => {
        const matches =
          (!query || row.innerText.toLowerCase().includes(query)) &&
          (!typeFilter.value || row.dataset.type === typeFilter.value.toLowerCase()) &&
          (!domainFilter.value || row.dataset.domain === domainFilter.value) &&
          (!menuFilter.value || row.dataset.menu === menuFilter.value);

        row.hidden = !matches;
        if (matches) visible += 1;
      });

      if (resultCount) {
        resultCount.textContent = `${visible} of ${rows.length} brick entries shown`;
      }
    };

    search?.addEventListener("input", applyFilters);
    [typeFilter, domainFilter, menuFilter].forEach((filter) => {
      filter.addEventListener("change", applyFilters);
    });
    applyFilters();
  }

  function initializeKeyboardShortcuts() {
    const dialog = document.querySelector(SELECTORS.shortcutDialog);
    const shortcutButton = document.querySelector(".shortcut-help-btn");
    const closeButton = document.querySelector("[data-close-shortcuts]");
    let goKeyPressedAt = 0;

    const openDialog = () => {
      if (!dialog) return;
      if (typeof dialog.showModal === "function") dialog.showModal();
      else dialog.setAttribute("open", "");
    };

    const closeDialog = () => {
      if (!dialog) return;
      if (typeof dialog.close === "function") dialog.close();
      else dialog.removeAttribute("open");
    };

    shortcutButton?.addEventListener("click", openDialog);
    closeButton?.addEventListener("click", closeDialog);
    dialog?.addEventListener("click", (event) => {
      if (event.target === dialog) closeDialog();
    });

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape") {
        closeDialog();
        document.querySelector(SELECTORS.sidebar)?.classList.remove("open");
        return;
      }

      if (isTyping()) return;

      if (event.key === "?") {
        event.preventDefault();
        openDialog();
        return;
      }

      if (event.key === "/") {
        const target = document.querySelector("#homeDocSearch, #docSearch");
        if (target) {
          event.preventDefault();
          target.focus();
        }
        return;
      }

      if (event.key.toLowerCase() === "g") {
        goKeyPressedAt = Date.now();
        return;
      }

      if (
        event.key.toLowerCase() === "h" &&
        Date.now() - goKeyPressedAt < 1200
      ) {
        location.href = "index.html";
        return;
      }

      const pageLink =
        event.key === "ArrowLeft"
          ? document.querySelector(".page-nav-card.previous")
          : event.key === "ArrowRight"
            ? document.querySelector(".page-nav-card.next")
            : null;

      if (pageLink) {
        event.preventDefault();
        location.href = pageLink.href;
      }
    });
  }

  function initializeImageFallbacks() {
    const fallbackExtensions = ["png", "jpg", "jpeg"];

    document.querySelectorAll("img[src]").forEach((image) => {
      const originalSource = image.getAttribute("src");
      if (!originalSource || !/\.svg(?:[?#].*)?$/i.test(originalSource)) return;

      const suffix = originalSource.match(/([?#].*)$/)?.[1] || "";
      const baseSource = originalSource.replace(/\.svg(?:[?#].*)?$/i, "");
      let nextExtension = 0;

      const tryNextFormat = () => {
        if (nextExtension >= fallbackExtensions.length) return;
        image.src = `${baseSource}.${fallbackExtensions[nextExtension]}${suffix}`;
        nextExtension += 1;
      };

      image.addEventListener("error", tryNextFormat);
      if (image.complete && image.naturalWidth === 0) tryNextFormat();
    });
  }

  initializeSidebar();
  initializeBrickSearch();
  initializeTableOfContents();
  initializeBackToTop();
  initializeHomeSearch();
  initializeGuidanceControls();
  initializeReferenceFilters();
  initializeKeyboardShortcuts();
  initializeImageFallbacks();
})();
