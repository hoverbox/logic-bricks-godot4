# Logic Bricks Documentation Audit

- Sensors documented: 26
- Controllers documented: 2
- Common actuators documented: 20
- 3D actuators documented: 36
- 2D actuators documented: 14
- UI actuators documented: 14

## Major corrections
- Removed the nonexistent Print Actuator and documented per-brick debugging instead.
- Removed invented standalone AND, OR, NOT, Branch, Compare, Probability, Sequence, and similar controller pages. The current Controller brick exposes logic modes as an option.
- Removed obsolete or unsupported actuator entries such as Enable, Disable, Wait, Spawn, Math, Find Node, Call Function, and other entries not present in the addon registry.
- Corrected Transforms naming to Get Transforms and Set Transforms.
- Rebuilt all brick reference pages from actual source files and property definitions.
- Added dedicated Debugging and Graph Export pages.
- Added an A-Z reference generated from the addon inventory.

## Maintenance
Re-run an equivalent source audit after adding, renaming, or removing bricks. Screenshot placeholders are stored in `assets/images/screenshots/`.

## Exact right-click actuator submenu audit

### 3D Actuators
- **Animation:** Animation, Animation State, Sprite Frames
- **Audio:** 3D Audio, 2D Audio, Music
- **Camera:** 3rd Person Camera, Camera Zoom, Set Camera, Smooth Follow Camera, Split Screen
- **Environment:** Environment, Light
- **Game:** Game, Preload, Save / Load, Scene
- **Game Feel:** Hit Stop, Object Flash, Object Shake, Rumble, Screen Flash, Screen Shake
- **Logic:** Get Variable, Modify Variable, Random, Signal, State
- **Motion:** Character Jump, Character Physics, Look At Input, Look At Movement, Motion, Mouse, Move Towards, Rotate Towards, Teleport, Waypoint Path
- **Object:** Get Transforms, Set Transforms, Edit Object, Object Pool, Parent, Property, Visibility
- **Physics:** Collision, Force, Gravity, Impulse, Linear Velocity, Physics, Torque
- **UI:** Modulate, Progress Bar, Text, Tween

### 2D Actuators
- **Animation:** Sprite Animation, Tween Animation
- **Audio:** 2D Audio, Music
- **Camera:** Set Camera, Camera Zoom, Smooth Follow Camera
- **Game:** Game, Preload, Scene
- **Game Feel:** Object Flash, Hit Stop, Rumble, Screen Flash
- **Logic:** Get Variable, Modify Variable, Random, Signal, State
- **Motion:** Motion 2D, Character 2D Physics, Character Jump 2D, Teleport 2D, Mouse
- **Object:** Get Transforms, Set Transforms, Property, Visibility
- **Physics:** Force 2D, Impulse 2D, Linear Velocity 2D
- **UI:** Modulate
