# Runtime Debugger

The Logic Bricks runtime debugger is implemented as the separate
`LogicBricksDebugger` autoload. It does not add debugging statements or extra
lines to generated gameplay scripts.

- Click the bug button beside a local/global variable to watch its live value.
- Click the bug button beside a state to watch that node's current state.
- Run the project. Watched information appears in the upper-left corner.
- Press F8 while playing to hide or show the overlay.
- If a watched item says `not found; apply code`, press **Apply Code** so the
  script property or state runtime has been generated.

Watch choices are stored in scene metadata and are inspected by the standalone
debugger at runtime.
