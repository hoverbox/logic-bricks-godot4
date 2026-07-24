# Maintaining the Logic Bricks documentation

## Where to edit

- `assets/css/foundation.css` — design tokens, global styles, header, layout, and sidebar.
- `assets/css/components.css` — cards, navigation aids, tables, callouts, and reusable content components.
- `assets/css/home.css` — homepage-only layout and workflow cards.
- `assets/css/enhancements.css` — filters, shortcuts, glossary, screenshots, and advanced controls.
- `assets/js/site-shell.js` — the shared header, sidebar, footer, and shortcut dialog.
- `assets/js/site.js` — behavior such as navigation, search, filters, keyboard shortcuts, and image fallbacks.
- `assets/js/search-index.js` — homepage search data.

`assets/css/site.css` only imports the four stylesheet modules. Keep the import order unchanged because later files intentionally build on earlier rules.

## Common edits

### Change the navigation
Edit `NAVIGATION_HTML` in `assets/js/site-shell.js`. The change appears on every page.

### Change homepage workflow cards
Edit the `workflow-card` elements in `index.html`. The colored number is `.workflow-number`; title text is not part of the colored square.

### Add a documentation page
1. Copy an existing small page.
2. Change the `<title>`, description, `data-page`, breadcrumb, and main content.
3. Add its navigation link in `assets/js/site-shell.js`.
4. Add search entries to `assets/js/search-index.js` when appropriate.
5. Run `python tools/validate_site.py`.

## Local preview
Serve the folder over HTTP rather than opening files directly. Dreamweaver Live View, VS Code Live Server, or `python -m http.server` all work.
