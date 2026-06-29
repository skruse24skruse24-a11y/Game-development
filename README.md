# Cosmic Crucible – Godot 4

An incremental falling-sand physics game. Run timed experiments, discover reactions, and evolve matter from **sand** to the **singularity**.

## Getting Started

1. **Install Godot 4.2+** – download from <https://godotengine.org/download>.
2. **Open the project** – import `project.godot`.
3. Press **F5** to play.
4. Press **R** to start a run, **LMB** to paint, **E** for encyclopedia.

## Controls

| Key | Action |
|-----|--------|
| R / Start Run | Begin timed simulation |
| LMB | Paint selected element |
| RMB | Paint wall (when unlocked) |
| E | Element Encyclopedia |
| U | Seismic shop (Insight upgrades) |
| M | Mastery shop (Element XP upgrades) |

## Project Structure

```
.
├── autoload/           # Global state, economy, encyclopedia
├── data/               # elements.json, reactions.json, upgrades
├── docs/               # Design research & gameplan
├── scenes/Main.tscn    # Root scene
└── scripts/
    ├── simulation/     # Powder CA engine
    └── ui/             # HUD, shops, encyclopedia
```

## Design Docs

- [Gameplan](docs/gameplan.md)
- [Element interaction map](docs/element-interaction-map.md)
- [Powder incremental design](docs/powder-incremental-game-design.md)
- [Incremental loop research](docs/incremental-2d-game-loop-research.md)

## Resources

- [Element interaction map & unlock route](docs/element-interaction-map.md) — 75 elements, 92 reactions, 7-act milestone ladder to Singularity
- [Powder physics incremental game design](docs/powder-incremental-game-design.md) — Powder Toy–style sim + incremental progression research
- [Incremental 2D game loop & upgrade path research](docs/incremental-2d-game-loop-research.md) — design patterns, math, and curated links for idle/clicker games
- [Godot 4 documentation](https://docs.godotengine.org/en/stable/)
- [GDScript reference](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)
- [2D game tutorials](https://docs.godotengine.org/en/stable/tutorials/2d/index.html)
