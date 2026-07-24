# Logic Bricks Documentation Website

This static website is ready for GitHub Pages.

## Publish

1. Upload the contents of this folder to a GitHub repository.
2. Open **Settings → Pages**.
3. Choose **Deploy from a branch** and select the repository root.

## Replace screenshots

Screenshot placeholders are in `assets/images/screenshots/`. Replace a placeholder while keeping the same filename, or update the matching `<img src>` path in the page.

## Audit details

See `AUDIT_REPORT.md` for the source comparison and major corrections.

## Actuator page organization

The 3D and 2D actuator pages mirror the addon right-click menu. Each submenu has an in-page anchor, so links can point directly to sections such as `actuators-3d.html#motion` or `actuators-2d.html#camera`. The UI actuator page remains flat because the addon intentionally shows UI actuators in a flat menu. Each domain page also begins with its own setup workflow.

## Phase 2 visual system

The site includes a shared visual presentation layer in `assets/css/site.css`.

- Page accents identify Sensors, Controllers, Actuators, UI, debugging, and interface content.
- Brick cards use a consistent title, metadata, options, and screenshot layout.
- Screenshot placeholders are stored in `assets/images/screenshots/` at 1600 x 900. Replace a placeholder while keeping its filename to update the site.
- All images use lazy loading to improve long-page performance.


## Phase 3 content improvements

The reference pages now include chapter introductions, typical uses, example chains, tips, common mistakes, related bricks, and cross-links to related topics. These additions are generated from the audited brick inventory and preserve the existing menu structure.

## Phase 4 homepage portal

The homepage has been redesigned as a documentation portal with:

- A prominent beginner entry path.
- Documentation-wide search across pages, sections, and brick names.
- Dedicated 3D, 2D, and UI workflow cards.
- Popular-topic shortcuts.
- A right-click-menu-oriented Brick Reference introduction.
- A summary of the manual's learning and reference features.

The search index is stored in `assets/js/search-index.js` and is loaded only by the homepage.

Image fallback support:
- Screenshot references may remain .svg.
- If the SVG is missing, the site tries the same exact filename with .png, .jpg, then .jpeg.
- Filenames are case-sensitive on GitHub Pages and most web servers.

## Code organization

The site is intentionally dependency-free and can be opened directly or hosted as static files.

- `assets/css/site.css` contains the shared visual styles.
- `assets/js/site-shell.js` owns the shared header, sidebar navigation, footer, and keyboard-shortcut dialog.
- `assets/js/site.js` contains page behavior, organized into named initialization functions.
- `assets/js/search-index.js` contains the homepage search data.
- Each HTML file contains only its page-specific content, table of contents, and previous/next links.

### Editing shared navigation

Change the navigation once in `assets/js/site-shell.js`. Do not copy navigation markup into individual HTML pages.

### Editing page behavior

Add new behavior as a focused `initialize...()` function in `assets/js/site.js`, then call it at the bottom of the file. Avoid adding phase-specific script blocks or inline event handlers.
