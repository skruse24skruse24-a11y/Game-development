# AGENTS.md

## Cursor Cloud specific instructions

This repo is a **Godot 4 (GDScript) 2D game template** — a single standalone desktop game project. There is no backend, database, package manager, or web service. The only dependency is the **Godot 4.2+ engine binary** (`godot`), installed to `/usr/local/bin/godot` by the startup update script.

### Running / testing the game
- A desktop display is available at `DISPLAY=:1`; the editor and game windows render there.
- Open the editor: `godot -e --path /workspace` (use `DISPLAY=:1` when launching from a non-GUI shell).
- Run the game directly: `godot --path /workspace` (launches `res://scenes/Main.tscn`, the configured main scene).
- Headless sanity check (no display, good for CI): `godot --headless --quit-after 120 --path /workspace` (exit code 0 = scene loaded and ran cleanly).
- The template's `Main` scene is intentionally **empty**, so a successful run shows a blank window — this is expected, not a bug.

### Non-obvious notes
- First run after a clean checkout must (re)build the import cache: `godot --headless --import` regenerates the gitignored `.godot/` directory. The editor does this automatically on open; the update script does not run it, so run it manually if launching the game before opening the editor.
- Harmless warnings on headless import ("Custom cursor shape not supported", "Blend file import ... no Blender path") can be ignored.
- There are no lint/build/test toolchains beyond the engine itself; "build" for distribution means exporting via the editor, which requires separately installed export templates (not needed for local dev/run).
