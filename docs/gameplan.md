# Cosmic Crucible — Implementation Gameplan

Godot 4 implementation plan for the powder physics incremental game.

**References:** [Element Interaction Map](element-interaction-map.md) · [Powder Design](powder-incremental-game-design.md) · [Incremental Loop Research](incremental-2d-game-loop-research.md)

---

## 1. Product Summary

**Cosmic Crucible** — timed petri-dish runs on a cellular-automata powder grid. Earn **Insight** for seismic upgrades (elements, timer, budget). Earn **Element Mastery XP** per element for granular upgrades. Catalog everything in the **Element Encyclopedia**.

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Main (Control)                                               │
│  ├─ SimViewport (PowderSimulation + SimRenderer)            │
│  ├─ HUD (timer, insight, run budget)                        │
│  ├─ PaletteBar (unlocked elements)                          │
│  ├─ SeismicShopPanel (Insight upgrades)                     │
│  ├─ MasteryPanel (Element XP upgrades)                    │
│  └─ EncyclopediaPanel (discovery journal)                   │
└─────────────────────────────────────────────────────────────┘
         ▲ reads/writes          ▲ signals
┌────────┴──────────────────────┴───────────────────────────┐
│ Autoloads: EventBus · ElementDB · ReactionDB · GameState    │
│            MasteryManager · Encyclopedia · SaveManager    │
└─────────────────────────────────────────────────────────────┘
         ▲
┌────────┴──────────┐
│ data/*.json       │
└───────────────────┘
```

### Separation of concerns (from incremental research)

| Layer | Responsibility |
|-------|----------------|
| `PowderSimulation` | Grid, ticks, reactions — no UI, no currency |
| `GameState` | Insight, seismic levels, run timer, placement budget |
| `MasteryManager` | Per-element XP/levels/upgrades |
| `Encyclopedia` | Discovery flags, hint tiers |
| `EventBus` | Decouples sim events from economy/UI |

---

## 3. Implementation Phases

### Phase 0 — Foundation (this commit) ✅

- [x] Project autoloads + JSON data (Act I elements/reactions)
- [x] 96×96 powder sim: SAND, WALL, WATR, STONE, FIRE, STEAM, OIL, LAVA, ACID, MUD
- [x] Dirty chunk scheduler (16×16)
- [x] Run loop: timer, placement budget, insight earn
- [x] Seismic shop: timer + budget + element unlocks
- [x] Mastery XP + per-element upgrades
- [x] Encyclopedia with ? / ??? states
- [x] Save/load JSON

### Phase 1 — Act I complete ✅

- [x] Remaining Act I elements (ICE, SMOK, ASH, SALT, CLAY, SPARK)
- [x] 15-reaction milestone detection
- [x] Steam cycle detector
- [x] Reaction journal polish
- [x] Petri-dish run setup with wall border
- [x] Run summary panel + first-run tutorial
- [x] HUD Act I progress bar

### Phase 2 — Act II protocell

- [ ] LIFE class behaviors + GOL overlay
- [ ] SOUP → CELL chain
- [ ] Milestone gate to Act III

### Phase 3 — Scale

- [ ] 256×256 grid option (seismic unlock)
- [ ] Forward+ renderer + compute shader path
- [ ] Offline insight (capped)

### Phase 4 — Acts III–VII

- [ ] Organism AI state machines
- [ ] Society structures
- [ ] Singularity ending

---

## 4. File Map

| Path | Purpose |
|------|---------|
| `autoload/event_bus.gd` | Global signals |
| `autoload/element_db.gd` | Element definitions |
| `autoload/reaction_db.gd` | Reaction rules |
| `autoload/game_state.gd` | Insight, seismic, run state |
| `autoload/mastery_manager.gd` | Element XP + upgrades |
| `autoload/encyclopedia.gd` | Discovery + hint logic |
| `autoload/milestone_tracker.gd` | Act milestones + steam cycle |
| `autoload/save_manager.gd` | Persistence |
| `scripts/ui/run_summary_panel.gd` | End-of-run summary |
| `scripts/ui/tutorial_panel.gd` | First-run tutorial |
| `scripts/simulation/material_id.gd` | ID constants |
| `scripts/simulation/powder_simulation.gd` | CA engine |
| `scripts/simulation/sim_renderer.gd` | ImageTexture display |
| `scripts/ui/*.gd` | Panel controllers |
| `scenes/Main.tscn` | Root scene |
| `data/elements.json` | Element catalog |
| `data/reactions.json` | Reaction registry |
| `data/seismic_upgrades.json` | Insight shop |
| `data/element_upgrades.json` | Mastery shop |

---

## 5. Simulation Rules (Phase 0)

- **Update order:** bottom → top rows; random L/R scan direction
- **Chunk activation:** 16×16 dirty flags; neighbor halo wakes on change
- **Tick rate:** `_process(delta)` accumulator at 60 Hz sim steps
- **Placement:** only during run; counts against budget; awards mastery XP

### Material classes implemented

| Class | Materials |
|-------|-----------|
| POWDER | SAND, MUD |
| LIQUID | WATR, OIL, LAVA, ACID |
| GAS | STEAM |
| SOLID | WALL, STONE |
| ENERGY | FIRE |

---

## 6. Economy Tuning (initial)

| Parameter | Start | Max (Phase 0) |
|-----------|-------|---------------|
| Run timer | 15s | 120s (seismic) |
| Placement budget | 80 | 800 (seismic) |
| Insight per reaction (first time) | 10 | — |
| Insight per second (run) | 0.2 | — |
| Mastery XP per pixel | 1 | — |

---

## 7. Encyclopedia UX Spec

- **Hotkey:** `E` toggles encyclopedia overlay
- **Tabs:** Elements | Reactions | Milestones | Mastery
- **Grey rules:**
  - Same-act next element: `?` + silhouette color
  - Future act: `???` + act name subtitle
  - Unknown reaction with known elems: `Water + ? → ?`
- **Ping:** New discovery triggers toast + encyclopedia badge

---

## 8. Testing Checklist

- [ ] Place sand → water → mud reaction discovers + insight + encyclopedia
- [ ] Mastery XP increases when placing water; upgrade purchasable
- [ ] Seismic timer upgrade extends run
- [ ] Save/load preserves discoveries and mastery levels
- [ ] Locked elements show ? in encyclopedia and palette
- [ ] Run ends at timer; summary shows earnings

---

## 9. Success Criteria for Phase 0

1. Playable 5-minute loop: run → earn → seismic upgrade → longer run
2. Encyclopedia documents at least 10 elements with hint states
3. At least 2 mastery upgrade paths functional
4. Simulation holds 60 FPS at 96×96 on typical hardware

---

*Gameplan v1 — June 2026*
