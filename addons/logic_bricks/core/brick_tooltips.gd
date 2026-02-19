@tool
extends RefCounted

## Centralized tooltip definitions for all Logic Bricks.
## Maps brick class names to dictionaries of property tooltips.
## "_description" key provides the overall brick description shown on the GraphNode.

const TOOLTIPS = {
	# =========================================================================
	# SENSORS
	# =========================================================================
	"AlwaysSensor": {
		"_description": "Always active sensor. Fires every frame.\nUseful for continuous actions like gravity or idle animations.",
	},
	
	"AnimationTreeSensor": {
		"_description": "Detects animation tree state changes and conditions.",
		"check_type": "What to check: current state name, a condition value, or a parameter value.",
		"state_machine_path": "Path to the AnimationNodeStateMachinePlayback parameter in the AnimationTree.",
		"state_name": "Name of the animation state to check for (e.g. 'idle', 'run').",
		"condition_name": "Name of the boolean condition parameter in the AnimationTree.",
		"parameter_name": "Name of the parameter to compare in the AnimationTree.",
		"compare_value": "Value to compare against the parameter.",
		"compare_mode": "How to compare: equal, not equal, greater than, less than, etc.",
	},
	
	"CollisionSensor": {
		"_description": "Detects collisions using an Area3D node.\nRequires an Area3D child or reference to detect overlapping bodies.",
		"collision_area": "The Area3D node used for collision detection. Drag from the scene tree.",
		"filter_group": "Only detect bodies in this group. Leave empty to detect all bodies.",
	},
	
	"DelaySensor": {
		"_description": "Adds a delay before activating. Stays active for a set duration.\nUseful for timed sequences or delayed triggers.",
		"delay_frames": "Number of frames to wait before activating.",
		"duration_frames": "Number of frames to stay active after the delay.",
		"repeat": "If true, the sensor repeats after completing its cycle.",
	},
	
	"InputMapSensor": {
		"_description": "Detects input actions defined in Project > Input Map.\nDevice-agnostic: works with keyboard, gamepad, etc.",
		"action_name": "The Input Map action name (e.g. 'move_left', 'jump').\nMust match an action defined in Project > Input Map.",
		"input_type": "When to activate: Pressed (held down), Just Pressed (single frame), or Just Released.",
	},
	
	"MessageSensor": {
		"_description": "Listens for messages sent by a Message Actuator.\nThe sending node must target a group that this node belongs to.",
		"subject": "The message subject to listen for. Must match what the Message Actuator sends.",
		"match_mode": "How to match: Exact (full match), Contains (substring), or Starts With (prefix).",
	},
	
	"MouseSensor": {
		"_description": "Detects mouse button presses and releases.",
		"button": "Which mouse button to detect: Left, Right, or Middle.",
		"input_type": "When to activate: Pressed (held), Just Pressed (single frame), or Just Released.",
	},
	
	"MovementSensor": {
		"_description": "Detects if the node is moving or stationary.\nCompares position between frames.",
		"detection_mode": "Is Moving: active when node moves. Is Stationary: active when node is still.",
		"threshold": "Minimum distance per frame to count as movement. Increase if jitter causes false positives.",
	},
	
	"ProximitySensor": {
		"_description": "Detects nodes within a certain distance.\nChecks against nodes in a specified group.",
		"distance": "Detection radius in units. Nodes closer than this distance will trigger the sensor.",
		"target_group": "Only detect nodes in this group. The group must be assigned in the Godot editor.",
		"detection_mode": "Nearest: only detect the closest node. Any: detect if any node is in range.",
	},
	
	"RandomSensor": {
		"_description": "Activates randomly based on a probability.\nUseful for random behaviors, particle effects, or AI variation.",
		"probability": "Chance of activating each frame (0.0 = never, 1.0 = always, 0.5 = 50% chance).",
		"seed_value": "Random seed for reproducible results. 0 = truly random.",
	},
	
	"RaycastSensor": {
		"_description": "Casts a ray to detect objects in a direction.\nUseful for line-of-sight, ground detection, or wall checks.",
		"direction": "Direction to cast the ray: Forward, Back, Up, Down, Left, Right.",
		"distance": "How far the ray extends in units.",
		"filter_group": "Only detect nodes in this group. Leave empty to detect everything.",
		"use_collision_mask": "If true, respect the node's collision mask for ray filtering.",
	},
	
	"TimerSensor": {
		"_description": "Activates after a set time duration.\nCan repeat for periodic triggers.",
		"duration": "Time in seconds before the sensor activates.",
		"repeat": "If true, the timer resets and repeats after firing.",
	},
	
	"VariableSensor": {
		"_description": "Compares a logic brick variable against a value.\nUse to trigger actions when variables change.",
		"variable_name": "Name of the logic brick variable to check (defined in the Variables tab).",
		"compare_mode": "Comparison operator: equal, not equal, greater than, less than, etc.",
		"compare_value": "Value to compare the variable against.",
	},
	
	# =========================================================================
	# CONTROLLERS
	# =========================================================================
	"Controller": {
		"_description": "Logic gate that combines sensor inputs.\nAND: all sensors must be active. OR: any sensor active.\nNAND/NOR/XOR: inverted and exclusive logic.",
		"logic_mode": "Logic gate type:\n• AND: All connected sensors must be active\n• OR: At least one sensor must be active\n• NAND: NOT AND — active when not all sensors are active\n• NOR: NOT OR — active only when no sensors are active\n• XOR: Exclusive OR — active when exactly one sensor is active",
		"state": "Which state this chain runs in (1-30). Use State Actuator to change states.",
	},
	
	# =========================================================================
	# ACTUATORS
	# =========================================================================
	"AnimationActuator": {
		"_description": "Plays, stops, or queues animations via AnimationPlayer.\nRequires an @export Node reference to the node containing the AnimationPlayer.",
		"mode": "Action to perform: Play, Stop, Pause, or Queue an animation.",
		"animation_name": "Name of the animation to play (from the AnimationPlayer's library).",
		"speed": "Playback speed multiplier. 1.0 = normal, 2.0 = double speed, 0.5 = half speed.",
		"blend_time": "Cross-fade time in seconds when transitioning. -1 = use AnimationPlayer default.",
		"play_backwards": "If true, play the animation in reverse.",
		"from_end": "If true, start playback from the last frame.",
	},
	
	"AnimationTreeActuator": {
		"_description": "Controls an AnimationTree node.\nCan travel to states, set parameters, or toggle conditions.",
		"action": "What to do: Travel to a state, Set a parameter value, or Set a condition boolean.",
		"animation_tree_path": "Path to the AnimationTree node relative to this node.",
		"state_machine_path": "Path to the state machine playback parameter.",
		"target_state": "Name of the state to travel to in the state machine.",
		"parameter_name": "Name of the AnimationTree parameter to set.",
		"parameter_value": "Value to assign to the parameter.",
		"condition_name": "Name of the boolean condition to set.",
		"condition_value": "Whether to set the condition to true or false.",
	},
	
	"CameraActuator": {
		"_description": "Controls camera behavior: follow target, orbit, or set position.\nCreates smooth camera movement with configurable offsets.",
		"camera_path": "Path to the Camera3D node to control.",
		"mode": "Camera behavior: Follow (track target), Orbit (circle around), or Set Position.",
		"target_path": "Path to the node the camera should follow or look at.",
		"offset_x": "Camera offset on X axis (left/right of target).",
		"offset_y": "Camera offset on Y axis (above/below target).",
		"offset_z": "Camera offset on Z axis (in front/behind target).",
		"smooth_speed": "How quickly the camera catches up (higher = faster, 0 = instant).",
	},
	
	"CharacterActuator": {
		"_description": "All-in-one character controller: gravity, jumping, and ground detection.\nDesigned for CharacterBody3D nodes.",
		"gravity_strength": "Downward force applied per second. Default 9.8 matches Earth gravity.",
		"jump_force": "Upward velocity applied when jumping. Higher = higher jumps.",
		"max_jumps": "Maximum jumps before landing. 1 = normal, 2 = double jump, etc.",
		"ground_group": "Group name for ground detection. Nodes in this group count as ground.",
		"coyote_time": "Seconds after leaving a ledge where jumping is still allowed.",
	},
	
	"CollisionActuator": {
		"_description": "Modifies collision properties at runtime.\nCan enable/disable shapes, change layers/masks, or toggle Area3D monitoring.",
		"action": "What to change:\n• Disable/Enable Shape: toggle a CollisionShape3D\n• Set Layer/Mask Bit: change collision filtering\n• Enable/Disable Monitoring: toggle Area3D detection",
		"target_node": "Name or path of the child node to modify (e.g. 'CollisionShape3D').",
		"layer_value": "Collision layer/mask bit number (1-32). Only used with Set Layer/Mask Bit.",
		"bit_enabled": "Whether to enable or disable the layer/mask bit.",
	},
	
	"EditObjectActuator": {
		"_description": "Add, remove, or replace objects in the scene at runtime.\nUseful for spawning enemies, projectiles, or swapping meshes.",
		"edit_type": "Action: Add Object (instance scene), End Object (remove), or Replace Mesh.",
		"scene_path": "Path to the .tscn file to instance (for Add Object).",
		"end_mode": "How to end the object: Queue Free (deferred) or Free (immediate).",
		"mesh_path": "Path to the mesh resource to swap in (for Replace Mesh).",
	},
	
	"GameActuator": {
		"_description": "Game-level actions: quit, restart, or pause the game.",
		"action": "What to do: Quit Game, Restart Scene, Pause, or Unpause.",
	},
	
	"LookAtMovementActuator": {
		"_description": "Rotates the node to face a target or direction.\nSmooth rotation with configurable speed.",
		"target_path": "Path to the node to look at. Leave empty to use a direction vector.",
		"look_axis": "Which axis to align: Y (horizontal), X (vertical), or All.",
		"speed": "Rotation speed. Higher = faster turning. 0 = instant.",
	},
	
	"MessageActuator": {
		"_description": "Sends a message to all nodes in a target group.\nReceivers need a Message Sensor listening for the same subject.",
		"target_group": "Group name to send the message to. Receiving nodes must be in this group.",
		"subject": "Message subject/identifier. The Message Sensor filters by this.",
		"body": "Optional message body/data. Can carry extra information.",
	},
	
	"MotionActuator": {
		"_description": "Moves or rotates the node. Supports translation, velocity, position,\nrotation, force, torque, and linear velocity modes.",
		"motion_type": "Type of motion:\n• Location: move by offset or set position\n• Rotation: rotate by degrees\n• Force/Torque: physics forces (RigidBody3D only)\n• Linear Velocity: set velocity directly (RigidBody3D only)",
		"movement_method": "How to apply location:\n• Translate: move by offset each frame\n• Velocity: set velocity on active axes (CharacterBody3D)\n• Position: set absolute position",
		"velocity_mode": "How to apply velocity: Set (replace), Add (accumulate), or Average.",
		"x": "Value for X axis. Enter a number (e.g. 5.0) or a variable name (e.g. speed).",
		"y": "Value for Y axis. Enter a number or variable name.",
		"z": "Value for Z axis. Enter a number or variable name.",
		"space": "Coordinate space: Local (relative to node's rotation) or Global (world axes).",
		"call_move_and_slide": "If true, call move_and_slide() after setting velocity. Enable if no other actuator does this.",
	},
	
	"MouseActuator": {
		"_description": "Controls mouse-based camera rotation.\nApplies mouse movement to rotate the node or a camera.",
		"sensitivity_x": "Horizontal mouse sensitivity. Higher = faster turning.",
		"sensitivity_y": "Vertical mouse sensitivity. Higher = faster looking up/down.",
		"x_threshold": "Minimum horizontal mouse movement to register.",
		"y_threshold": "Minimum vertical mouse movement to register.",
		"invert_x": "Invert horizontal mouse direction.",
		"invert_y": "Invert vertical mouse direction.",
		"clamp_y_min": "Minimum vertical angle in degrees (looking down limit).",
		"clamp_y_max": "Maximum vertical angle in degrees (looking up limit).",
		"camera_node": "Path to the camera node for vertical rotation (pitch).",
	},
	
	"MoveTowardsActuator": {
		"_description": "Moves toward a target node using seek, flee, or path following.\nCan use NavigationAgent3D for pathfinding.",
		"behavior": "Movement type: Seek (approach), Flee (move away), or Path Follow (navigation).",
		"target_path": "Path to the target node to move toward or away from.",
		"speed": "Movement speed in units per second.",
		"arrive_distance": "Distance at which the node is considered 'arrived' and stops.",
		"nav_agent_name": "Name of the NavigationAgent3D child (for Path Follow mode).",
	},
	
	"ParentActuator": {
		"_description": "Changes the node's parent in the scene tree.\nUseful for attaching objects to characters or vehicles.",
		"action": "Set Parent: reparent this node. Remove Parent: move to scene root.",
		"target_path": "Path to the new parent node.",
	},
	
	"PhysicsActuator": {
		"_description": "Modifies physics properties at runtime.\nChange gravity scale, mass, friction, or bounce.",
		"property": "Which physics property to modify.",
		"value": "New value for the property.",
	},
	
	"PropertyActuator": {
		"_description": "Sets any property on a target node.\nCan assign, add, copy, or toggle property values.",
		"target_node": "The node whose property will be modified. Must be set explicitly.",
		"property_name": "Name of the property to modify (e.g. 'visible', 'modulate').",
		"operation": "How to modify: Assign (set), Add (increment), Toggle (flip bool), Copy (from another).",
		"value": "Value to assign or add to the property.",
	},
	
	"RandomActuator": {
		"_description": "Sets a variable to a random value within a range.\nUseful for randomized behavior, damage variation, etc.",
		"variable_name": "Logic brick variable to store the random value in.",
		"min_value": "Minimum random value (inclusive).",
		"max_value": "Maximum random value (inclusive).",
		"integer_only": "If true, only generate whole numbers.",
	},
	
	"SaveGameActuator": {
		"_description": "Saves or loads game data to/from a JSON file.\nCan save position, rotation, and logic brick variables.",
		"action": "Save: write data to file. Load: read data from file.",
		"save_path": "File path for the save file (e.g. 'user://savegame.json').",
		"save_position": "Include the node's position in the save data.",
		"save_rotation": "Include the node's rotation in the save data.",
		"save_variables": "Include logic brick variables in the save data.",
	},
	
	"SceneActuator": {
		"_description": "Changes or manages scenes.\nCan switch to a new scene or reload the current one.",
		"action": "Change Scene: load a different scene. Reload: restart current scene.",
		"scene_path": "Path to the .tscn file to load (for Change Scene).",
	},
	
	"SoundActuator": {
		"_description": "Plays audio with advanced options.\nSupports random pitch, audio buses, and multiple play modes.",
		"sound_path": "Path to the audio file (.wav, .ogg, .mp3).",
		"play_mode": "Restart: always restart. Overlap: play on top. Ignore: skip if already playing.",
		"volume_db": "Volume in decibels. 0 = full volume, -10 = quieter, -80 = near silent.",
		"pitch_scale": "Base pitch multiplier. 1.0 = normal, 2.0 = octave up, 0.5 = octave down.",
		"random_pitch_range": "Random pitch variation (+/-). 0 = no variation, 0.1 = slight variation.",
		"audio_bus": "Audio bus name (e.g. 'Master', 'SFX', 'Music'). Must exist in the Audio Bus Layout.",
		"fade_in_time": "Fade in duration in seconds. 0 = instant.",
		"fade_out_time": "Fade out duration in seconds. 0 = instant.",
	},
	
	"StateActuator": {
		"_description": "Changes the logic brick state (1-30).\nOnly chains assigned to the active state will run.",
		"target_state": "State number to switch to (1-30).\nControllers have a 'state' property that determines which state they run in.",
	},
	
	"TeleportActuator": {
		"_description": "Instantly moves the node to a target position.\nCan teleport to a node's position or specific coordinates.",
		"mode": "Target Node: teleport to another node's position. Coordinates: teleport to X/Y/Z.",
		"target_path": "Path to the node to teleport to (for Target Node mode).",
		"x": "X coordinate (for Coordinates mode).",
		"y": "Y coordinate (for Coordinates mode).",
		"z": "Z coordinate (for Coordinates mode).",
		"copy_rotation": "If true, also copy the target node's rotation.",
	},
	
	"TextActuator": {
		"_description": "Displays text on a UI Label node.\nCan set static text or show variable values.",
		"label_path": "Path to the Label or RichTextLabel node to display text on.",
		"text_mode": "Static: set fixed text. Variable: display a logic brick variable's value.",
		"text_value": "The text to display (for Static mode).",
		"variable_name": "Logic brick variable whose value to display (for Variable mode).",
		"prefix": "Text shown before the value (e.g. 'Score: ').",
		"suffix": "Text shown after the value (e.g. ' points').",
	},
	
	"VariableActuator": {
		"_description": "Modifies a logic brick variable.\nCan assign, add, subtract, multiply, divide, or toggle.",
		"variable_name": "Name of the logic brick variable to modify (from the Variables tab).",
		"operation": "How to modify:\n• Assign: set to value\n• Add/Subtract/Multiply/Divide: math operation\n• Toggle: flip boolean",
		"value": "Value to use in the operation.",
	},
}


## Get tooltips for a specific brick class.
## Returns a dictionary of property_name -> tooltip_string.
static func get_tooltips(brick_class: String) -> Dictionary:
	return TOOLTIPS.get(brick_class, {})
