# Logic Bricks changelog

After updating, close any add-on scripts open in the Script editor, restart
the project (or use Project > Tools > Reload Logic Bricks), and press
**Apply Code** on every node with bricks. **Options > Find Outdated Scripts**
lists the scripts that still need it.

## 3.7.7

- **3rd Person Camera:** the camera's code moved out of the student's script
  into `addons/logic_bricks/runtime/third_person_camera.gd`. Apply Code now adds
  about 8 lines (create the camera, set the settings you changed, call
  `update()` every frame) instead of 145 (290 with Avoid Walls). The camera
  behaves exactly as before: old and new were run side by side through orbit,
  pitch limits, invert, exported sensitivity, walls, pillars and a variable
  distance, and matched on every frame. Press Apply Code on nodes that use it.

## 3.7.6

- **Every number field takes variables and math.** The number spinners are now
  text boxes like the other number fields: type a number, a variable name, or
  math such as `speed * 2`, with the same variable suggestions. This covers all
  376 number fields (Proximity Distance, Light Energy, Sound Volume, Teleport,
  Set Transforms, Random ranges, camera settings, ...). The value is worked out
  each time the brick runs, so changing the variable during the game changes
  the brick. Plain numbers are still kept within each field's range, and
  generate exactly the same code as before.
- **Math stays one value** wherever the brick uses it. Before, `speed + 1` could be read as
  `x * speed + 1` (Camera Zoom, Color / Transparency, Progress Bar and World
  Environment transition speeds, Force/Torque limits), and Camera Zoom's Zoom
  or a Force limit with math did not compile.
- **Edit Object (Add Object):** Velocity X/Y/Z accept math; before, anything
  other than a number or a single variable name became 0.
- **Object Pool:** Spawn Amount with a variable or math spawns that many each
  time it fires. Before, a variable spawned one object per frame and counted
  the variable down to 0, and math did not compile.
- **Modify Variable:** Remove At Index / Set Item At Index accept a variable or
  math for Index (before, only a whole number).
- **3rd Person Camera:** turning off Release Mouse on Escape no longer
  produces code that does not compile.
- **Random Chance (Range mode)** is described as what it is: a dice roll. It
  picks a whole number from Min to Max and fires every time; turn on Store
  Value to use the number. (It already fired every time, because it checked
  whether the roll was between Min and Max, which it always is; that check is
  gone.) The docs show a loot table built from one shared roll plus Compare
  Variable triggers.
- **3rd Person Camera:** with Export Sensitivity on, a sensitivity set to a
  variable is not exported (the variable sets it); a configuration warning says so.
- New tests: `test_numeric_expressions.gd` checks all 376 number fields (and
  fails if a new one is added without a test), including runtime checks that a
  variable changed during the game is followed; `test_number_fields_ui.gd`
  checks the editor's number boxes.

## 3.7.5

- **Readable chain names:** generated functions are named after what the chain
  does, such as `_logic_brick_proximity_then_modify_variable`, instead of
  `_logic_brick_and_12`. A name typed on the Controller brick is used as-is
  (`_logic_brick_open_the_door`); a name typed on a trigger or action replaces
  that brick's title. View Code still jumps to the right function.
- **Field names match the code:** Signal Send/Receive **Signal** is now
  **Signal Name** (`signal_name` in code, which also replaces `subject` in the
  generated handlers), and the Physics trigger's landing field is stored as
  `minimum_landing_speed`. Saved scenes are updated automatically.
- **Proximity Store Object** now stores the nearest object in range, as its
  tooltip says (it used to store the first one in the group).
- **Proximity 2D:** a cone (Angle under 360) now works; before, it produced a
  script with an error. The +Z/-Z axis choices, which mean nothing in 2D, were
  removed.
- **Particles** start/stop actions now run (the generated code used to end up
  inside a comment).
- **Node lookup caching** no longer changes text inside strings or comments.
- **Sync Bricks from Script** keeps backslashes in strings (such as
  `C:\new\test`) and keeps nested arrays as arrays.

## 3.7.4

- **3rd Person Camera:** Narrow Obstacle Width now works with any collider,
  including one mesh collider for a whole room with its pillars (such as the
  space kit rooms). The camera checks whether it can see around an obstacle
  to the left and right instead of measuring the collider's size.
- **Documentation:** every brick section rebuilt from the add-on (options,
  menu paths, descriptions, guidance, screenshots); sections added for
  Particles, Group, Surface Attachment, Physics, Soft Body Point Force/Impulse
  and the shared bricks in the UI menu. View Documentation now opens the right
  section for every brick.
- **Check Interval** on Proximity (3D and 2D) and on Mouse's hover modes:
  check every N seconds instead of every frame, keeping the last result in
  between. Defaults to 0 (every frame), so existing scripts don't change.
- **Physics (3D action):** the Soft Body fields are hidden unless a Soft Body
  action is chosen.
- **Tooltips:** Camera Zoom, World Environment, Teleport and Smooth Follow
  Camera no longer mention Inspector slots; Random Chance tooltips no longer
  show a literal `\n`.

## 3.7.3

- **3rd Person Camera:** new **Narrow Obstacle Width** (Avoid Walls). Pillars,
  posts and trees narrower than this no longer pull the camera in toward the
  player. The camera never comes to rest inside one.

## 3.7.2

- **3rd Person Camera:** **Rotate Character**, **Align Mode**, **Turn Speed**
  and **Move Actions** were removed. For third-person movement, use Position
  with Camera Relative plus Look At Input with Camera Relative.
- **3rd Person Camera:** new **Probe Radius** (a small sphere instead of a
  thin line, so fences and railings no longer make the camera pop in and out)
  and **Return Smoothing** (ease back out when the view clears).

## 3.7.0 and 3.7.1

- **3rd Person Camera:** new **Avoid Walls** group: Camera Distance,
  Collision Mask (layer numbers or names), Collision Margin.
- **3rd Person Camera:** new **Smooth Physics Motion**; mouse orbit input was
  reworked to remove jitter.
- **Mouse (Mouse Look):** smoother turning. Each physics tick uses only the
  mouse motion from its own slice of time.
- **Physics interpolation** is now turned on in Project Settings by Apply
  Code instead of at runtime. This fixes scenery being drawn at the world
  origin in some scenes.
- **Save / Load:** the Target field is split into **Target Node Name**
  (Target Node scope) and **Target Group** (Group scope, with a group picker).
  Older graphs keep working.
- **Graph backup:** Apply Code stores a compressed copy of the graph in the
  generated script. Options > Sync Bricks from Script restores a lost graph
  exactly. Turn off with Project Settings > Logic Bricks > Backup.
- **Version stamp:** generated code records the add-on version. A notice next
  to Apply Code and **Options > Find Outdated Scripts** show code from other
  versions.
- **Renaming nodes** updates bricks that refer to them, including bricks in
  scenes that instance the renamed scene (applied when those scenes open).
- **Project > Tools > Reload Logic Bricks**, plus an automatic reload when the
  add-on is replaced while the editor is open.
- Node lookups in generated code are cached (much less work per frame).
- Fields that only matter for certain choices now show and hide based on
  the brick's own rules.
- Automated tests: `tests/run_all_tests_in_editor.gd` (File > Run) or
  `tests/run_all_tests.gd` from a terminal.
