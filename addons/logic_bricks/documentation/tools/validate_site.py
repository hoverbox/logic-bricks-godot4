#!/usr/bin/env python3
"""Validate local links, assets, duplicate IDs, and stylesheet syntax."""
from __future__ import annotations

from pathlib import Path
from urllib.parse import unquote, urlsplit
import re
import sys

from bs4 import BeautifulSoup
import tinycss2

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def local_target(value: str, source: Path) -> Path | None:
    value = value.strip()
    if not value or value.startswith(("#", "mailto:", "tel:", "javascript:", "data:")):
        return None
    parsed = urlsplit(value)
    if parsed.scheme or parsed.netloc:
        return None
    path = unquote(parsed.path)
    if not path:
        return None
    return (source.parent / path).resolve()


html_files = sorted(ROOT.glob("*.html"))
soups = {path.resolve(): BeautifulSoup(path.read_text(encoding="utf-8"), "html.parser") for path in html_files}
for html_file in html_files:
    soup = soups[html_file.resolve()]

    ids = [tag.get("id") for tag in soup.find_all(attrs={"id": True})]
    duplicates = sorted({item for item in ids if ids.count(item) > 1})
    if duplicates:
        errors.append(f"{html_file.name}: duplicate IDs: {', '.join(duplicates)}")

    for tag, attribute in (("a", "href"), ("link", "href"), ("script", "src"), ("img", "src")):
        for node in soup.find_all(tag):
            value = node.get(attribute)
            if not value:
                continue
            target = local_target(value, html_file)
            if target and not target.exists():
                errors.append(f"{html_file.name}: missing {attribute} target {value}")

            fragment = urlsplit(value).fragment
            if tag == "a" and fragment and target and target.suffix == ".html" and target.exists():
                target_soup = soups.get(target.resolve())
                if target_soup is not None and not target_soup.find(id=fragment):
                    errors.append(f"{html_file.name}: missing fragment #{fragment} in {target.name}")

for css_file in sorted((ROOT / "assets/css").glob("*.css")):
    rules = tinycss2.parse_stylesheet(css_file.read_text(encoding="utf-8"), skip_comments=False, skip_whitespace=False)
    for rule in rules:
        if rule.type == "error":
            errors.append(f"{css_file.relative_to(ROOT)}: CSS parse error: {rule.message}")

for js_file in sorted((ROOT / "assets/js").glob("*.js")):
    text = js_file.read_text(encoding="utf-8")
    if re.search(r"\bTODO\b|\bFIXME\b", text):
        errors.append(f"{js_file.relative_to(ROOT)}: contains TODO or FIXME")

if errors:
    print("Validation failed:")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print(f"Validation passed: {len(html_files)} HTML pages, local links/assets, IDs, and CSS syntax checked.")
