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
- **13 Sensors** — input (keyboard, gamepad, joystick axis), collision, raycast, proximity, movement, timers, variables, messages, and more
- **5 Controller Modes** — AND, OR, NAND, NOR, XOR logic gates
- **30+ Actuators** — organised into categorised submenus: Animation, Movement, Physics, Object, Environment, Camera, Audio, Game Feel, UI, Logic, and Game
- **Variables Panel** — declare typed variables, export to the inspector, or mark as global (shared across scenes via autoload)
- **Expression Support** — type `speed * 2` or `horizontal * move_speed` directly in Motion and Animation fields
- **Joystick Axis Input** — analog stick support with configurable deadzone and variable storage
- **Collapsible Property Groups** — brick properties organised into labelled, collapsible sections
- **Frames** — visually group and label brick chains
- **Tooltips** — every field has built-in documentation
- **State System** — up to 30 states per node for complex behaviors (idle, walking, attacking, etc.)
- **Message System** — inter-node communication without code, with optional response delay
- **Instanced Scene Support** — choose to open the original scene or edit the instance directly

## Quick Start

1. Install the plugin and enable it in Project Settings → Plugins
2. Select a **CharacterBody3D**, **RigidBody3D**, or **Node3D** in your scene
3. Open the **Logic Bricks** panel at the bottom of the editor
4. Right-click the graph → add an **InputMap Sensor**, a **Controller**, and a **Motion Actuator**
5. Connect them left to right
6. Press Play — your character moves

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

### Example: Third-Person Character Controller

```
Always Sensor → Controller [AND] → Character Actuator [gravity + jump]

InputMap [Axis | negative: move_forward, positive: move_back, Store In: vertical]
  → Controller [AND] → Motion [Z: vertical * speed, Method: Velocity]

Always Sensor → Controller [AND] → 3rd Person Camera
  [Pivot: CameraPivot, Input: Mouse, Rotate Character: On]
```

## Brick Reference

### Sensors
Always, Animation Tree, Collision, Compare Variable, Delay, InputMap (button + axis), Message, Mouse, Movement, Proximity, Random, Raycast

### Controllers
AND, OR, NAND, NOR, XOR

### Actuators

| Category | Actuators |
|---|---|
| **Animation** | Animation, Animation Tree |
| **Movement** | Motion, Character (gravity + jump), Look At Movement, Move Towards (seek/flee/pathfind with obstacle avoidance), Teleport, Mouse |
| **Physics** | Physics, Impulse, Collision |
| **Object** | Edit Object, Object Pool, Parent, Property, Visibility |
| **Environment** | Environment, Light (with FX presets: Flicker, Strobe, Pulse, Fade) |
| **Camera** | Camera, Camera Zoom, Screen Shake, 3rd Person Camera |
| **Audio** | Audio 3D, Audio 2D, Music |
| **Game Feel** | Screen Flash, Rumble |
| **UI** | Text, Modulate, Progress Bar, Tween |
| **Logic** | State, Random, Message, Modify Variable |
| **Game** | Game, Scene, Save Game |

## What's New

### Actuator Menu Reorganised
Actuators are now grouped into categorised submenus rather than a single flat list, making it much faster to find the right brick.

### New Actuators
- **Light** — control `OmniLight3D`, `SpotLight3D`, and `DirectionalLight3D` properties with animated FX presets: Flicker (with configurable idle time and burst duration), Strobe, Pulse, and Fade In/Out
- **3rd Person Camera** — orbit camera for third-person games driven by mouse and/or joystick. Supports configurable sensitivity, invert axes, pitch clamping, and a `Rotate Character` toggle for third-person shooter vs. isometric-style control. Sensitivity and invert values can be exported to the Inspector for use in a settings menu

### Sensor Improvements
- **Delay Sensor** — duration is now fully implemented. The sensor waits for the delay, stays active for the duration, then either repeats the full cycle or stops. Uses a phase state machine (`waiting → active → done`)
- **Message Sensor** — added a **Response Delay** field. Set to `0` for immediate activation (default), or a value in seconds to wait before the sensor fires after receiving a message
- **Collision Sensor** — fixed: overlapping mode no longer emits an unused class-scope member variable, resolving `UNUSED_PRIVATE_CLASS_VARIABLE` and `SHADOWED_VARIABLE` editor warnings

### Actuator Improvements
- **Motion Actuator** — local-space velocity mode now only sets `velocity.x` and `velocity.z`, preserving `velocity.y` so the Character Actuator's gravity and jump are not cancelled out during horizontal movement
- **Move Towards (Path Follow)** — added obstacle avoidance via forward raycast. When the path ahead is blocked by something that isn't the target, the agent picks a lateral offset and reroutes around it. The offset is held until the agent reaches the detour point, then clears automatically, preventing enemies from stacking on the same nav path

### UI Improvements
- **Collapsible property groups** — brick properties can be organised into labelled sections that expand and collapse, keeping graph nodes compact
- **Color picker support** — `TYPE_COLOR` properties now render a `ColorPickerButton`
- **Dynamic array lists** — `TYPE_ARRAY` properties render an add/remove list with optional file picker support per item
- **Float spinboxes** now respect `PROPERTY_HINT_RANGE` hint strings for min, max, and step values
- **Animation dropdown** — scans the entire scene subtree for all `AnimationPlayer` nodes automatically, with a **↻ Refresh** button to rescan on demand
- **Instanced scene panel** — selecting an instanced node now shows a panel with options to open the original scene or edit the instance directly, replacing the previous static warning message

### Bug Fixes
- `variable_sensor.gd` — fixed parse error caused by `else:` blocks indented one level too deep inside a `match` statement
- Export var null-checks in `_ready()` now skip primitive types (`float`, `int`, `bool`, `String`, `Vector2`, `Vector3`, `Color`) that can never be null, eliminating false inspector warnings

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
