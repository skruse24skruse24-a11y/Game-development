# 2D Game Template – Godot 4

A simple jumping-off point for 2D game development using [Godot 4](https://godotengine.org/).

## Features

- **Player character** with configurable horizontal movement, gravity, and jumping
- **Main menu** with Start and Quit buttons
- **Game world** scene with a ground plane and a sample platform
- **Camera** that smoothly follows the player
- **GameManager** autoload singleton for tracking score and lives
- Pre-configured input actions: `move_left`, `move_right`, `jump`

## Project Structure

```
.
├── project.godot          # Godot project configuration
├── icon.svg               # Project icon
├── scenes/
│   ├── MainMenu.tscn      # Title screen (start scene)
│   ├── Main.tscn          # Game world with ground, platform, and player
│   └── Player.tscn        # Player character (CharacterBody2D)
└── scripts/
    ├── Player.gd          # Movement, gravity, and jump logic
    ├── MainMenu.gd        # Button wiring and scene transitions
    └── GameManager.gd     # Autoload: score, lives, and game-over handling
```

## Getting Started

1. **Install Godot 4** – download from <https://godotengine.org/download>.
2. **Open the project** – launch Godot, click *Import*, and select the
   `project.godot` file in this folder.
3. **Press F5** (or click the Play button) to run the game.
4. Use **A / D** or the **arrow keys** to move, and **Space / Up arrow** to jump.

## Extending the Template

| What you want to do | Where to start |
|---|---|
| Tweak player speed or jump height | `scripts/Player.gd` – `@export` variables at the top |
| Add enemies | Create a new scene extending `CharacterBody2D` or `Area2D` |
| Build new levels | Duplicate `scenes/Main.tscn` and design with the tilemap or `StaticBody2D` nodes |
| Track score / lives | Call `GameManager.add_score(n)` or `GameManager.lose_life()` from any script |
| Show UI in-game | Add a `CanvasLayer` with `Label` nodes and connect to `GameManager` signals |

## Input Actions

| Action | Default keys |
|---|---|
| `move_left` | A, Left arrow |
| `move_right` | D, Right arrow |
| `jump` | Space, Up arrow |

Additional actions can be added in **Project → Project Settings → Input Map**.

## License

This template is released into the public domain – use it however you like.