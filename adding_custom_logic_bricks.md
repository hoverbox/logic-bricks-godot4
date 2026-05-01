# Adding Custom Logic Bricks — Developer Guide

This guide walks you through every step needed to add a new Sensor, Controller, or Actuator to the Logic Bricks addon. The system is designed so that each brick is a self-contained `.gd` file; the main work is writing that file and then registering it in two places.

---

## How the System Works (Quick Overview)

Every brick — sensor, controller, or actuator — is a class that extends the base `LogicBrick` (`core/logic_brick.gd`). Each brick is responsible for:

1. Declaring its type and display name
2. Defining its editable properties and their defaults
3. Generating the GDScript code that gets injected into the node's script at runtime

The panel reads your brick's `get_property_definitions()` to build the UI automatically, and calls `generate_code()` when the user hits **Apply Code**. You do not need to touch the UI or the code generator beyond what's described below.

---

## Step 1 — Create the Brick Script

Place your new `.gd` file in the appropriate subfolder:

| Brick type  | Folder |
|-------------|--------|
| Sensor      | `addons/logic_bricks/bricks/sensors/3d/` |
| Actuator    | `addons/logic_bricks/bricks/actuators/3d/` |
| Controller  | `addons/logic_bricks/bricks/controllers/` |

Name the file in `snake_case`, e.g. `health_sensor.gd` or `inventory_actuator.gd`.

### Minimal Sensor Template

```gdscript
@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Brief description of what this sensor detects.

func _init() -> void:
    super._init()
    brick_type = BrickType.SENSOR
    brick_name = "My Sensor"  # Display name shown in the panel


func _initialize_properties() -> void:
    properties = {
        "my_value": 1.0,
        "my_flag": false,
    }


func get_property_definitions() -> Array:
    return [
        {
            "name": "my_value",
            "type": TYPE_FLOAT,
            "default": 1.0
        },
        {
            "name": "my_flag",
            "type": TYPE_BOOL,
            "default": false
        },
    ]


func get_tooltip_definitions() -> Dictionary:
    return {
        "_description": "One-line description shown on hover.",
        "my_value": "Tooltip for my_value.",
        "my_flag": "Tooltip for my_flag.",
    }


func generate_code(node: Node, chain_name: String) -> Dictionary:
    var value = properties.get("my_value", 1.0)
    var flag  = properties.get("my_flag", false)

    var code = "var sensor_active = (%s > %.2f)" % ["some_node_property", value]

    return {
        "sensor_code": code
    }
```

### Minimal Actuator Template

```gdscript
@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Brief description of what this actuator does.

func _init() -> void:
    super._init()
    brick_type = BrickType.ACTUATOR
    brick_name = "My Actuator"


func _initialize_properties() -> void:
    properties = {
        "target_value": 0.0,
    }


func get_property_definitions() -> Array:
    return [
        {
            "name": "target_value",
            "type": TYPE_FLOAT,
            "default": 0.0
        },
    ]


func get_tooltip_definitions() -> Dictionary:
    return {
        "_description": "Does something useful when triggered.",
        "target_value": "The value to apply.",
    }


func generate_code(node: Node, chain_name: String) -> Dictionary:
    var value = properties.get("target_value", 0.0)

    var code_lines: Array[String] = []
    code_lines.append("# My Actuator")
    code_lines.append("some_property = %.2f" % value)

    return {
        "actuator_code": "\n".join(code_lines)
    }
```

---

## Step 2 — Understand `generate_code()` Return Values

The dictionary you return from `generate_code()` can contain these keys:

| Key | Used by | Purpose |
|-----|---------|---------|
| `"sensor_code"` | Sensors | Sets `var sensor_active = ...` used by the controller logic |
| `"actuator_code"` | Actuators | Code that runs when `controller_active` is true |
| `"controller_code"` | Controllers | Rarely needed; controller logic is handled by the manager |
| `"member_vars"` | Any | `Array[String]` of variable declarations injected at class scope |
| `"ready_code"` | Any | `Array[String]` of lines injected into `_ready()` |

**`sensor_code` must set `sensor_active`** — that's the variable the controller reads. Example:

```gdscript
return {
    "sensor_code": "var sensor_active = health < 10.0"
}
```

**`actuator_code`** runs inside the controller's `if controller_active:` block. No indentation needed from your side.

**`member_vars`** is for state that must persist across frames (timers, flags, cached references). Each string is a complete `var` declaration, e.g.:

```gdscript
var member_vars: Array[String] = []
member_vars.append("var _my_timer_%s: float = 0.0" % chain_name)
# Always suffix with chain_name to avoid collisions between chains
return {
    "sensor_code": code,
    "member_vars": member_vars
}
```

**`ready_code`** works the same way — an array of plain lines injected into `_ready()`.

---

## Step 3 — Property Definitions (UI Auto-Generation)

`get_property_definitions()` returns an array of dictionaries. Each dictionary describes one editable field. The panel builds the UI from this array automatically.

Supported keys per property entry:

| Key | Required | Notes |
|-----|----------|-------|
| `"name"` | Yes | Must match the key in `properties` |
| `"type"` | Yes | A Godot `TYPE_*` constant (`TYPE_FLOAT`, `TYPE_INT`, `TYPE_BOOL`, `TYPE_STRING`, `TYPE_VECTOR3`, etc.) |
| `"default"` | Yes | Shown and used if no saved value exists |
| `"hint"` | No | A `PROPERTY_HINT_*` constant for special widgets |
| `"hint_string"` | No | Depends on hint — see examples below |

### Common hint examples

**Dropdown enum:**
```gdscript
{
    "name": "mode",
    "type": TYPE_STRING,
    "hint": PROPERTY_HINT_ENUM,
    "hint_string": "Option A,Option B,Option C",
    "default": "option_a"
}
```
The panel stores the selected value as a lowercase underscore string (e.g. `"option_a"`). Normalize it in `generate_code()` with `.to_lower().replace(" ", "_")`.

**File picker:**
```gdscript
{
    "name": "scene_path",
    "type": TYPE_STRING,
    "hint": PROPERTY_HINT_FILE,
    "hint_string": "*.tscn,*.scn",
    "default": ""
}
```

**Integer range:**
```gdscript
{
    "name": "count",
    "type": TYPE_INT,
    "hint": PROPERTY_HINT_RANGE,
    "hint_string": "1,100,1",
    "default": 5
}
```

---

## Step 4 — Register in `BRICK_SCRIPT_REGISTRY`

Open `addons/logic_bricks/core/logic_brick_manager.gd` and find the `BRICK_SCRIPT_REGISTRY` constant (around line 1082). Add one line for your brick in the appropriate section:

```gdscript
const BRICK_SCRIPT_REGISTRY: Dictionary = {
    # ── Sensors ──────────────────────────────────────────────────────────────
    ...
    "MySensor": "res://addons/logic_bricks/bricks/sensors/3d/my_sensor.gd",
    
    # ── Actuators ─────────────────────────────────────────────────────────────
    ...
    "MyActuator": "res://addons/logic_bricks/bricks/actuators/3d/my_actuator.gd",
}
```

**The key must be PascalCase and match the filename converted to PascalCase** — this is how serialization identifies your brick type when saving/loading scenes. For example, `my_health_sensor.gd` → `"MyHealthSensor"`.

---

## Step 5 — Register in the Panel Menus

There are two places in `addons/logic_bricks/ui/logic_brick_panel.gd` where you need to add your brick.

### 5a — Add to `_create_add_menu()`

Find the block that builds the `sensors_menu` or `actuators_menu` (around line 220). Add your entry in alphabetical order:

```gdscript
# For a sensor:
sensors_menu.add_item("My Sensor", 200)  # Use a unique integer ID not already taken
sensors_menu.set_item_metadata(INDEX, {"type": "sensor", "class": "MySensor"})
sensors_menu.set_item_tooltip(INDEX, "Short description for the hover tooltip.")

# For an actuator:
actuators_menu.add_item("My Actuator", 201)
actuators_menu.set_item_metadata(INDEX, {"type": "actuator", "class": "MyActuator"})
actuators_menu.set_item_tooltip(INDEX, "Short description for the hover tooltip.")
```

`INDEX` is the zero-based position of the item in the menu list — count the existing `add_item` calls in that block and use the next number. The integer ID passed to `add_item()` just needs to be unique within the submenu; pick something unused.

### 5b — Add to `_create_brick_instance()`

Find the `match brick_class:` block inside `_create_brick_instance()` (around line 1456). Add a case for your class name:

```gdscript
"MySensor":
    script_path = "res://addons/logic_bricks/bricks/sensors/3d/my_sensor.gd"

"MyActuator":
    script_path = "res://addons/logic_bricks/bricks/actuators/3d/my_actuator.gd"
```

---

## Step 6 — (Optional) Add Tooltips to `brick_tooltips.gd`

`core/brick_tooltips.gd` contains a large dictionary of inline property tooltips used by the search panel and some UI elements. If you want your brick to show up well there, add an entry matching your `brick_name`:

```gdscript
"My Sensor": {
    "_description": "Fires when some condition is true.",
    "my_value": "Threshold value.",
    "my_flag": "Enables extra behavior.",
},
```

This is cosmetic — your brick works without it.

---

## Checklist Summary

- [ ] Create `my_brick.gd` in the correct `bricks/` subfolder
- [ ] Extend `"res://addons/logic_bricks/core/logic_brick.gd"`
- [ ] Set `brick_type` and `brick_name` in `_init()`
- [ ] Define all properties in `_initialize_properties()`
- [ ] Implement `get_property_definitions()` with matching entries
- [ ] Implement `generate_code()` returning the correct key (`sensor_code` / `actuator_code`)
- [ ] Add entry to `BRICK_SCRIPT_REGISTRY` in `logic_brick_manager.gd`
- [ ] Add `add_item` + `set_item_metadata` in `_create_add_menu()` in `logic_brick_panel.gd`
- [ ] Add a case to `_create_brick_instance()` in `logic_brick_panel.gd`
- [ ] (Optional) Add tooltips to `brick_tooltips.gd`

---

## Tips and Gotchas

**Always suffix member variable names with `chain_name`.** Multiple chains can run on the same node, so `var _timer_elapsed` without the suffix will collide. Use `var _timer_elapsed_%s: float = 0.0" % chain_name` instead.

**Normalize enum/string properties before using them.** The panel may store values as display-style strings (e.g. `"Option A"`). Call `.to_lower().replace(" ", "_")` at the top of `generate_code()` before your `match` block.

**Don't use `@export` in brick scripts.** Bricks are `RefCounted` objects, not nodes, so the Inspector won't see them. All user-facing data goes through `properties`.

**Keep `_initialize_properties()` and `get_property_definitions()` in sync.** Every key in `properties` should have a matching entry in `get_property_definitions()`, and vice versa. Missing entries will cause UI glitches or silent data loss on save/load.

**Deserialize defensively.** `generate_code()` should always call `properties.get("key", default_value)` rather than `properties["key"]`, so old saved scenes with missing keys don't crash.
