# Logic Bricks for Godot 4



➡️ **[📖 Click for Full Documentation](https://hoverbox.github.io/logic-bricks-godot4/)**

________________________________________________________________________

A visual logic system for Godot 4 inspired by the Blender Game Engine
(UPBGE). Build game logic with a node-graph editor using **Sensors**,
**Controllers**, and **Actuators**---no coding required.

Logic Bricks generates clean, readable GDScript behind the scenes, so
your projects stay lightweight and inspectable. Build gameplay for **3D
games, 2D games, and UI** without writing code. It's ideal for beginners
learning game development, educators teaching game logic, and
experienced developers who want to prototype rapidly.

![Godot 4.3+](https://img.shields.io/badge/Godot-4.3%2B-blue) ![License:
MIT](https://img.shields.io/badge/License-MIT-green)

## How It Works

Select any **3D, 2D, or UI node**, open the Logic Bricks panel, and
connect bricks visually:

    Sensor → Controller → Actuator

## Features

-   **3D, 2D & UI Support**
-   **Visual Node Graph Editor**
-   **Auto-generated GDScript**
-   **14 Sensors**
-   **5 Controller Modes**
-   **25+ Actuators**
-   **Variables Panel**
-   **Expression Support**
-   **Joystick Axis Input**
-   **Split Screen**
-   **Frames**
-   **Tooltips**
-   **State System**
-   **Signal System**

## Supported Node Types

### 3D

-   Node3D
-   CharacterBody3D
-   RigidBody3D
-   StaticBody3D
-   Area3D
-   Camera3D

### 2D

-   Node2D
-   CharacterBody2D
-   RigidBody2D
-   StaticBody2D
-   Area2D
-   Camera2D

### UI

-   Control
-   Button
-   Label
-   Containers
-   Other Control-derived nodes

## Quick Start

1.  Install and enable the plugin.
2.  Select a supported **3D, 2D, or UI node**.
3.  Attach a script.
4.  Open the **Logic Bricks** panel.
5.  Add an InputMap Sensor, Controller, and Motion Actuator.
6.  Connect them.
7.  Click **Apply Code**.
8.  Press Play.

### Example: 3D Character Movement

    InputMap (Axis)
        →
    Controller
        →
    Motion (X/Z)

### Example: 2D Character Movement

    InputMap (Left/Right)
        →
    Controller
        →
    Motion (X)

    InputMap (Jump)
        →
    Controller
        →
    Character 2D Physics (Jump)

### Example: Coin Collection

    Collision Sensor (Area2D or Area3D)
        →
    Controller
        →
    Modify Variable

## Brick Reference

### Sensors

Always, Animation Tree, Collision, Compare Variable, Delay, InputMap,
Signal, Mouse, Movement, Proximity, Random, Raycast, Timer

### Controllers

AND, OR, NAND, NOR, XOR

### Common Actuators

Animation, Animation Tree, Collision, Edit Object, Game, Modify
Variable, Motion, Mouse, Parent, Physics, Property, Random, Save Game,
Scene, Signal, Sound, Split Screen, State, Teleport, Text

### 3D Actuators

Character Physics, Look At Movement, Set Camera, Smooth Follow Camera,
Camera Zoom

### 2D Actuators

Character 2D Physics, Set Camera 2D, Smooth Follow Camera 2D, Camera
Zoom 2D

## Camera Actuators

### 3D

-   Set Camera
-   Smooth Follow Camera
-   Camera Zoom

### 2D

-   Set Camera 2D
-   Smooth Follow Camera 2D
-   Camera Zoom 2D

## Mouse Sensor

Supports button, wheel, movement, and hover detection for both **2D and
3D** objects.

## Installation

### Asset Library

1.  Search **Logic Bricks** in the Godot Asset Library.
2.  Download and enable the plugin.

### Manual

Copy `addons/logic_bricks` into your project's `addons` folder and
enable the plugin.

## Requirements

-   Godot 4.3+
-   GDScript only

## License

MIT --- see LICENSE.
