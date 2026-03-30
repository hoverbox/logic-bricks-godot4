# Logic Bricks for Godot 4

A visual logic system for Godot 4 inspired by the Blender Game Engine (UPBGE). Build game logic with a node-graph editor using **Sensors**, **Controllers**, and **Actuators** — no coding required.

Logic Bricks generates clean, readable GDScript behind the scenes, so your projects stay lightweight and inspectable. Ideal for beginners learning game development, educators teaching game logic, or anyone who wants to prototype gameplay without writing code.

![Godot 4.3+](https://img.shields.io/badge/Godot-4.3%2B-blue) ![License: MIT](https://img.shields.io/badge/License-MIT-green)

## How It Works

Select any 3D node, open the Logic Bricks panel, and connect bricks visually:

```
Sensor  →  Controller  →  Actuator
(input)    (logic)        (action)
```

**Sensors** detect events (input, collisions, timers, variable changes). **Controllers** evaluate conditions (AND, OR, NAND, NOR, XOR). **Actuators** perform actions (move, animate, play sounds, change scenes). Chain them together to build complete game behaviors.

## Features

- **Visual Node Graph Editor** in Godot's bottom panel — right-click to add bricks, drag to connect
- **Auto-generated GDScript** — readable code that students can learn from
- **14 Sensors** — input (keyboard, gamepad, joystick axis), collision, raycast, proximity, movement, mouse (buttons, wheel, hover), timers, variables, messages, and more
- **5 Controller Modes** — AND, OR, NAND, NOR, XOR logic gates
- **25 Actuators** — motion, animation, camera, sound, physics, scene management, save/load, text display, split screen, and more
- **Variables Panel** — declare typed variables with optional min/max clamps, export to the inspector as a range slider, or mark as global (shared across scenes via autoload)
- **Expression Support** — type `speed * 2` or `horizontal * move_speed` directly in Motion and Animation fields
- **Joystick Axis Input** — analog stick support with configurable deadzone and variable storage
- **Split Screen** — 1–4 player split screen with per-count independent layouts, runtime player count switching, and automatic camera adoption
- **Frames** — visually group and label brick chains
- **Tooltips** — every field has built-in documentation
- **State System** — up to 30 states per node for complex behaviors (idle, walking, attacking, etc.)
- **Message System** — inter-node communication without code

## Quick Start

1. Install the plugin and enable it in Project Settings → Plugins
2. Select a **CharacterBody3D**, **RigidBody3D**, or **Node3D** in your scene
3. Add a script to the node
4. Open the **Logic Bricks** panel at the bottom of the editor
5. Right-click the graph → add an **InputMap Sensor**, a **Controller**, and a **Motion Actuator**
6. Connect them left to right
7. Click Apply **Code**
8. Press Play — your character moves

### Example: Joystick Character Movement

```
InputMap [Axis | negative: move_left, positive: move_right, Store In: horizontal]
  → Controller [AND] → Motion [X: horizontal * speed]

InputMap [Axis | negative: move_forward, positive: move_back, Store In: vertical]
  → Controller [AND] → Motion [Z: vertical * speed]
```

### Example: Coin Collection with Global Score

```
Collision Sensor [Area3D: coin_area]
  → Controller [AND] → Modify Variable [coin, Add, 1]
                      → Sound [coin_sfx]

Compare Variable [coin == 5]
  → Controller [AND] → Game [Change Scene: win_screen.tscn]
```

The `coin` variable marked as Global persists across scenes — display it on your win screen with a Text Actuator.

### Example: 2–4 Player Split Screen

```
Always Sensor → Controller [AND] → Split Screen [player_count: num_players, layout_2: Vertical, layout_4: 2x2 Grid]
```

Apply Code once — all 4 SubViewportContainers are created and cameras are adopted automatically. At runtime, set `split_screen_players = 1` for single-player fullscreen, `2` for split, `3` or `4` for multi-player. Each player count uses its own independent layout.

## Brick Reference

### Sensors
Always, Animation Tree, Collision, Compare Variable, Delay, InputMap (button + axis), Message, Mouse (button, wheel, movement, hover), Movement, Proximity, Random, Raycast, Timer

### Controllers
AND, OR, NAND, NOR, XOR

### Actuators
Animation, Animation Tree, Set Camera, Smooth Follow Camera, Camera Zoom, Character (gravity + jump), Collision, Edit Object, Game, Look At Movement, Message, Modify Variable, Motion, Mouse, Move Towards, Parent, Physics, Property, Random, Save Game, Scene, Sound, Split Screen, State, Teleport, Text

## Variables Panel

Variables can be declared with optional **min and max clamps**:

- Check **Min** to set a lower bound — the variable will never go below it
- Check **Max** to set an upper bound — the variable will never go above it
- Enable both for a fully clamped range

For `int` and `float` variables that are also **exported**, Logic Bricks generates `@export_range(min, max)` so the Inspector shows a slider. For non-exported clamped variables, a GDScript property with a setter is generated automatically.

## Split Screen

The Split Screen actuator supports **1–4 players** with fully independent layouts per player count:

| Players | Default Layout | Configurable |
|---------|---------------|--------------|
| 1       | Fullscreen (no split) | — |
| 2       | Vertical | Yes |
| 3       | Top Wide | Yes |
| 4       | 2×2 Grid | Yes |

**Setup:**
1. Name your cameras `Camera3D_P1`, `Camera3D_P2`, `Camera3D_P3`, `Camera3D_P4` in the scene
2. Apply Code — cameras are moved into their SubViewports automatically
3. Set `split_screen_players` at runtime to switch between counts

The `player_count` field accepts either a literal number (`2`) or a variable name (`num_players`) so the count can be driven by game logic.

**Available layouts:** Vertical, Horizontal, 2×2 Grid, Top Wide, Bottom Wide

## Camera Actuators

The original Camera actuator has been split into two focused bricks:

**Set Camera** — makes the assigned Camera3D the active camera. Use with a one-shot sensor (Delay, state transition) rather than Always to avoid calling `make_current()` every frame.

**Smooth Follow Camera** — camera smoothly follows the node while maintaining its initial offset. Supports:
- Per-axis position follow (X, Y, Z independently)
- Per-axis rotation follow (orbits the camera around the target)
- Dead zones per axis — camera only moves once the target exceeds the threshold
- Independent position and rotation interpolation speeds

## Mouse Sensor

The Mouse sensor supports four detection modes:

- **Button** — left, right, or middle click; detect pressed (single frame), released (single frame), or held
- **Wheel** — scroll up or scroll down, fires for one frame per scroll tick. Multiple wheel sensors on the same node work correctly — they share a single `_input` handler generated automatically
- **Movement** — triggers when the mouse moves beyond a configurable threshold
- **Hover Object / Hover Any** — raycasts from the camera to detect mouse-over on 3D objects

## Installation

### Asset Library
1. In Godot, go to **AssetLib** → search **"Logic Bricks"** → Download → Install
2. **Project → Project Settings → Plugins → Logic Bricks → Enable**

### Manual
1. Copy the `addons/logic_bricks` folder into your project's `addons/` directory
2. **Project → Project Settings → Plugins → Logic Bricks → Enable**

## Requirements

- Godot 4.3+
- GDScript only (no C# dependency, no GDExtension)

## License

MIT — see [LICENSE](LICENSE)
