# Logic Bricks Getting Started Tutorial

The tutorial is built into the Logic Bricks editor panel.

1. Enable the Logic Bricks plugin.
2. Open the **Logic Bricks** bottom panel.
3. Click **Tutorial** in the panel header.

The tutorial viewer is implemented in:

- `addons/logic_bricks/ui/tutorial_window.gd`

Replace a temporary PNG with either a final screenshot or a short looping Ogg Theora video using the same base filename. For example, `02_attach_script.ogv` automatically replaces `02_attach_script.png` in the tutorial. The viewer prefers `.ogv`, then `.webm` when a compatible importer exists, and finally falls back to PNG, WebP, or JPEG. Videos autoplay, loop, and remain muted.

The controller images must demonstrate the five controller gates actually supported by the addon:

- AND
- OR
- NAND
- NOR
- XOR
