# Code Cleanup Notes

This cleanup keeps the documentation content and visual behavior intact while making the source easier to maintain.

## Main changes

- Removed duplicated header, sidebar, footer, and shortcut-dialog markup from every full documentation page.
- Added `assets/js/site-shell.js` as the single source of truth for shared site chrome and navigation.
- Reorganized `assets/js/site.js` into small, named initialization functions.
- Replaced homepage search result HTML strings with DOM creation for safer, clearer code.
- Formatted all full HTML pages into readable, indented markup.
- Formatted the three legacy redirect pages consistently.
- Removed empty class attributes left by previous generated revisions.
- Added code-organization and editing guidance to `README.md`.

## Validation performed

- JavaScript syntax checked with Node.js.
- All 22 HTML files parsed successfully.
- Shared shell placeholders and scripts verified on every full page.
- Internal page links checked for missing targets.
- Screenshot references checked, including PNG/JPG fallbacks for legacy SVG references.

## Publication cleanup pass

- Split the stylesheet into four readable modules while preserving cascade order.
- Replaced generic workflow-card `span` styling with the dedicated `.workflow-number` class, eliminating the unwanted second rounded-square effect around titles.
- Removed 38 duplicate brick sections that created duplicate HTML IDs.
- Repaired retired common-page links in the A-Z reference and redirected cross-references to the current 3D, 2D, or UI pages.
- Replaced missing SVG screenshot references with the existing PNG/JPG files so browsers no longer generate avoidable 404 requests.
- Added an SVG favicon and browser theme color.
- Added `MAINTENANCE.md` and `tools/validate_site.py` for future edits.
- Validated all 22 HTML pages, local links, fragments, assets, duplicate IDs, CSS syntax, and JavaScript syntax.
