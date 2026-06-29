# Powder Physics Incremental: Design Research

A design reference for an incremental game built around a **Powder Toy–style falling-sand physics simulation**. The player starts with one element and a short simulation timer, then unlocks longer runs, more elements, larger placement budgets, and eventually **emergent life** from disparate chemistry.

Companion doc: [Incremental 2D Game Loop Research](incremental-2d-game-loop-research.md) | [Element Interaction Map](element-interaction-map.md)

---

## Table of Contents

1. [Concept & Design Pillars](#1-concept--design-pillars)
2. [Similar Games & Lessons](#2-similar-games--lessons)
3. [Core Loop for This Game](#3-core-loop-for-this-game)
4. [Progression Trees](#4-progression-trees)
5. [Currency & Upgrade Models](#5-currency--upgrade-models)
6. [Element Tier List & Unlock Order](#6-element-tier-list--unlock-order)
7. [Element Interaction Tables](#7-element-interaction-tables)
8. [Life & Emergence Progression](#8-life--emergence-progression)
9. [Simulation Architecture](#9-simulation-architecture)
10. [Godot Implementation Resources](#10-godot-implementation-resources)
11. [Academic & Technical Papers](#11-academic--technical-papers)
12. [Reference Implementations](#12-reference-implementations)
13. [MVP Scope Recommendation](#13-mvp-scope-recommendation)
14. [Full Link Index](#14-full-link-index)

---

## 1. Concept & Design Pillars

### Elevator pitch

You are a **cosmic alchemist** with a tiny pocket universe. Each run is a timed experiment: place limited particles, watch physics unfold, and earn **Insight** from interesting outcomes (reactions, stable structures, life milestones). Spend Insight to extend simulation time, unlock elements, increase placement caps, and research biochemistry — until disparate powders become living systems.

### Design pillars

| Pillar | Meaning |
|--------|---------|
| **Constraint → release** | Short early timers create tension; upgrades feel like expanding laboratory capacity |
| **Emergence as reward** | Progression currency comes from *what the sim discovers*, not just clicking |
| **Readable science ladder** | Earth → water → fire → chemistry → organics → life (teachable order) |
| **Sandbox within budget** | Player creativity is bounded by particle budget per run (incremental unlock expands budget) |
| **Watchable spectacle** | 2D particle drama (fire, convection, growth) is the "number go up" visual |

### Mapping to incremental growth models

From [incremental game research](incremental-2d-game-loop-research.md):

| Incremental pattern | This game's expression |
|--------------------|------------------------|
| **Generator chain** | Element tiers unlock in dependency order (sand → water → … → DNA) |
| **Timer / wall** | Simulation timer runs out → earn currency → buy longer runs |
| **Milestone bonuses** | Discovering reaction combos unlocks permanent multipliers |
| **Research tree** | Biochemistry branch gates life elements |
| **Prestige ("Big Bang")** | Reset universe for **Cosmic Insight** — permanent element efficiency |
| **Active interrupts** | Random "anomaly" events during run (meteor heat, lightning spark) |
| **Derivative chain** | Higher tiers *produce* lower tiers (seed → root → plant → oxygen) |

---

## 2. Similar Games & Lessons

### Direct precedents

| Game | Relationship | Key lesson |
|------|--------------|------------|
| [The Powder Toy](https://powdertoy.co.uk/) | Primary physics reference | Pressure, heat, 180+ elements, electronics — too much for v1 |
| [Falling Sand Idle](https://www.incrementaldb.com/game/falling-sand-idle) | **Closest incremental + sand hybrid** | Godot engine; hourglass → forest evolution; currency per particle event |
| [Sandboxels](https://sandboxels.wiki.gg/wiki/Sandboxels) | Browser sand sim, 500+ elements | Excellent reaction data model (`reactions` object per element) |
| [Sandspiel](https://sandspiel.club/) | Minimal 20-element CA | Best reference for *readable* life/chemistry in few elements |
| [powder-lab](https://github.com/thatmike1/powder-lab) | 14-element browser sim | Dirty-chunk scheduling, data-driven materials — ideal MVP scope |
| [Noita](https://store.steampowered.com/app/881100/Noita/) | Action roguelite + full sim | Chunked CA, bottom-up updates, rigid-body integration |
| [Falling Sand Game (2005)](https://en.wikipedia.org/wiki/Falling-sand_game) | Genre origin | Simple rules → emergent play |

### Falling Sand Idle — critical reference

Built in **Godot**, currently on Steam Early Access ([IncrementalDB entry](https://www.incrementaldb.com/game/falling-sand-idle)):

- **Level 1 (Hourglass):** Each grain hitting bottom refunds the grain + grants tiny **time currency** for upgrades. Thousands of grains on screen.
- **Level 2 (Forest):** Place leaves for free; gain **evolution points** per particle created; leaves die → dead leaves → bugs eat dead leaves.
- Progression *is* the simulation changing behavior (size, heat, predation).

**Takeaway for our game:** Tie currency to **simulation events** (collisions, phase changes, sustained reactions, life ticks) rather than only manual clicks.

### The Powder Toy — scope warning

TPT simulates pressure, velocity, heat, gravity, electricity, radioactivity, optics, and Lua scripting ([GitHub](https://github.com/The-Powder-Toy/The-Powder-Toy)). TV Tropes notes ["artistic license chemistry"](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/ThePowderToy) — fine for spectacle, but our incremental ladder should use **simplified, teachable rules** early, with TPT-accurate complexity as late-game optional "realistic physics" upgrade.

### Noita — engineering reference

- World split into **512×512 chunks**; only active chunks update.
- **Bottom-up row processing** so falling materials work correctly ([80.lv article](https://80.lv/articles/noita-a-game-based-on-falling-sand-simulation)).
- **4-pass checkerboard chunk updates** for thread safety.
- Rigid bodies via marching squares + Box2D ([GDC talk](https://www.youtube.com/watch?v=prXuyMCgbTc)).
- **Caution:** Purho notes emergent entropy makes designed progression hard — our game contains the sim in a **small petri dish** with explicit goals per tier.

### Academic case study

Tomáš Pagáč's thesis [*Simulating Game Worlds Using Cellular Automata*](https://is.muni.cz/th/w12aw/SimulatingWorldsCA.pdf) documents classic falling-sand rules:

- Water pools, sinks in oil, extinguishes fire, dissolves salt
- Plant grows when touching water; destroyed by fire
- Sand piles, sinks in water
- Wax burns with reusable byproduct
- Oil pools; fire can burn through walls

---

## 3. Core Loop for This Game

### Macro loop

```
┌──────────────┐    ┌───────────────┐    ┌────────────────┐
│ START RUN    │───►│ PLACE ELEMENTS│───►│ SIMULATE       │
│ (timer starts)│    │ (budget limit) │    │ (physics tick) │
└──────────────┘    └───────────────┘    └───────┬────────┘
       ▲                                         │
       │         ┌───────────────┐    ┌──────────▼────────┐
       │         │ BUY UPGRADES  │◄───│ RUN ENDS          │
       └─────────│ time/elements │    │ (timer or stable) │
                 │ /budget/life  │    │ → earn Insight    │
                 └───────────────┘    └───────────────────┘
```

### Micro loop (during simulation)

1. Player paints elements within **placement budget** (e.g. 200 grains of unlocked types).
2. Simulation ticks; reactions fire; **event bus** awards Insight for milestones.
3. Optional active play: click to add **spark** (limited), tilt gravity, pause-step.
4. Timer expires OR player ends run early OR achieves **tier goal** (bonus multiplier).
5. Summary screen: reactions discovered, max complexity score, life forms sustained.

### Insight earning events (examples)

| Event | Insight | Notes |
|-------|---------|-------|
| First sustained fire (3s) | +5 | Teaches phase change |
| Water + fire → steam cloud | +3 | Reaction discovery |
| Plant survives 10s | +10 | Life milestone |
| Stable 3-element cycle (e.g. water→plant→O₂) | +25 | "Ecosystem" achievement |
| First cell division (GOL rule) | +100 | Major prestige gate |
| Run duration per second (idle) | +0.1 × tier | Baseline passive earn |

### Anti-patterns to avoid

- **Pure idle with no spectacle** — player must *watch* interesting physics.
- **Unlimited placement from start** — removes incremental tension.
- **180 elements at launch** — analysis paralysis; gate behind tiers.
- **Exact TPT port** — pressure/velocity/electronics is a multi-year project.

---

## 4. Progression Trees

### Tree A: Simulation Capacity (Generator-style)

Exponential cost scaling; extends "how much universe you get per run."

| Upgrade | Effect | Tier | Cost curve |
|---------|--------|------|------------|
| **Chronometer I–X** | +5s → +50s simulation time | 1–10 | `base × 1.12^n` |
| **Particle Budget I–X** | 100 → 10,000 max placed per run | 1–10 | `base × 1.15^n` |
| **Brush Size I–V** | 1×1 → 9×9 placement radius | 2–6 | Linear |
| **Canvas Size I–V** | 64² → 256² grid cells | 3–7 | Milestone unlocks |
| **Sim Speed I–III** | 1× → 3× tick rate (visual fast-forward) | 4–6 | Flat |
| **Pause Steps** | +3 manual single-step per run | 2 | Flat |
| **Offline Lab** | Earn 25% Insight from last config while away (capped 4h) | 5 | Prestige-gated |

### Tree B: Physics Modules (Research-style)

Unlocks simulation *capabilities*, not just elements. Branching tree with prerequisites.

```
                    [Heat Transfer]
                          │
              ┌───────────┼───────────┐
              ▼           ▼           ▼
        [Gravity]    [Density]    [Phase Change]
              │           │           │
              └─────┬─────┴─────┬─────┘
                    ▼           ▼
              [Convection]  [Combustion]
                    │           │
                    └─────┬─────┘
                          ▼
                   [Pressure Basic]
                          │
                          ▼
              [Electrolysis] (water split)
                          │
                          ▼
                 [Biochemistry Lab]
```

| Node | Unlocks | Prerequisite |
|------|---------|--------------|
| Heat Transfer | Temp diffusion between cells | Chronometer II |
| Gravity | Powders/liquids fall | — (start) |
| Density | Oil floats on water | Gravity + Water element |
| Phase Change | Melt/freeze/boil tables | Heat Transfer |
| Combustion | Fire spread rules | Phase Change + Fire element |
| Convection | Rising hot gas/steam | Phase Change |
| Pressure Basic | Simple 1D pressure equalization | 50 total runs |
| Electrolysis | Water → H₂ + O₂ (simplified) | Pressure Basic |
| Biochemistry Lab | Organic elements | Plant tier discovered |

### Tree C: Element Unlocks (Collection / completion)

Elements are **generators** that produce interactions. Unlock order follows chemistry curriculum (see [Section 6](#6-element-tier-list--unlock-order)).

**Milestone pattern:** Owning 5 runs with an element active unlocks its **Mastery bonus** (+10% Insight from that element's reactions).

### Tree D: Life Evolution (Derivative chain)

Polynomial/derivative model from [Math of Idle Games Part II](https://www.gamedeveloper.com/game-platforms/the-math-of-idle-games-part-ii): higher tiers produce lower tiers.

```
SAND (inert base)
  └── WATER (solvent)
        └── MINERAL (dissolved salts)
              └── CLAY (sediment)
                    └── ORGANIC SOUP (catalyzed reactions)
                          └── AMINO ACID (simplified)
                                └── RNA (GOL-like replicator)
                                      └── CELL (membrane + metabolism)
                                            └── MULTICELL (colony growth)
```

Each tier requires **sustained conditions** for N seconds during a run to unlock the next (not just purchase).

### Tree E: Prestige — "Big Bang"

| Prestige layer | Reset | Permanent gain |
|----------------|-------|----------------|
| **Spark** (early) | Current run only | None — tutorial |
| **Nova** (first real prestige) | All elements, budget, timer upgrades | **Cosmic Insight** → +5% all Insight per point |
| **Singularity** (late) | Nova upgrades too | Unlock **parallel universes** (run 2 petri dishes) |

Prestige formula (sub-linear): `Cosmic Insight = floor(sqrt(lifetime_insight / 1000))`

Reference: [Idle Game Design — prestige section](https://solana.garden/guides/game-idle-game-design-explained/)

### Tree F: Achievements → Permanent modifiers

| Achievement | Bonus |
|-------------|-------|
| "First Flame" | Fire spreads 10% faster |
| "Primordial Soup" | Organic reactions +15% Insight |
| "Steady State" | +2s base timer |
| "Frankenstein" | First life form gives 2× Insight |

---

## 5. Currency & Upgrade Models

### Currencies

| Currency | Earned from | Spent on | Persists? |
|----------|-------------|----------|-----------|
| **Insight** | Run events, reactions, duration | Timer, budget, elements, physics nodes | Yes |
| **Discovery Points** | First-time reaction/element combo | Research tree only | Yes |
| **Cosmic Insight** | Prestige (Nova) | Meta multipliers, parallel runs | Yes |
| **Placement Budget** | Per-run resource (refills each run) | Placing particles | Per run |

### Balancing targets

From incremental research benchmarks:

| Milestone | Target |
|-----------|--------|
| First upgrade | 2–5 minutes |
| First new element (Water) | ~10 minutes |
| First prestige (Nova) | 45–90 minutes |
| First life (Cell) | 3–8 hours total |
| Post-prestige run speed | 40–60% faster to Water tier |

Use [Idle Game Generator](https://idlegamegenerator.toolpile.dev/) and [Pecorella spreadsheets](http://kon.gg/idle-math-spreadsheets) to tune costs.

---

## 6. Element Tier List & Unlock Order

### Design scope: 40 elements for full vision, 14 for MVP

MVP aligns with [powder-lab](https://github.com/thatmike1/powder-lab) (14 materials). Full game expands toward Sandspiel (~20) then curated TPT subset (~40).

### Tier 0 — Start (1 element)

| ID | Name | Behavior | Unlock |
|----|------|----------|--------|
| `SAND` | Sand | Falls, piles, diagonal slide | Default |

### Tier 1 — Geology (runs 1–5)

| ID | Name | Behavior | Cost |
|----|------|----------|------|
| `WALL` | Boundary | Static obstacle | 50 Insight |
| `WATR` | Water | Flows, pools, extinguishes | 100 Insight |
| `STONE` | Stone | Static, eroded by acid later | 150 Insight |

### Tier 2 — States of matter (runs 5–15)

| ID | Name | Behavior | Requires |
|----|------|----------|----------|
| `ICE` | Ice | Frozen water; melts to water | Phase Change node |
| `STEAM` | Steam | Rises, condenses to water | Phase Change |
| `FIRE` | Fire | Spreads via flammables; killed by water | Combustion node |
| `SMOK` | Smoke | Rises, dissipates | Fire |
| `OIL` | Oil | Floats on water; flammable | Density node |

### Tier 3 — Chemistry (runs 15–30)

| ID | Name | Behavior | Requires |
|----|------|----------|----------|
| `LAVA` | Lava | Hot, falls, ignites | Phase Change + Fire |
| `ACID` | Acid | Dissolves stone/sand slowly | 500 Insight |
| `SALT` | Salt | Dissolves in water → brine | Water + discovery |
| `ASH` | Ash | Fire residue; plant nutrient later | Fire |
| `COAL` | Coal | Slow burn fuel | Fire + Plant |

### Tier 4 — Organics (runs 30–50)

| ID | Name | Behavior | Requires |
|----|------|----------|----------|
| `SEED` | Seed | Grows root in sand near water | Biochemistry Lab |
| `ROOT` | Root | Searches sand/water; spawns plant | SEED discovery |
| `PLNT` | Plant | Grows, dies without water; flammable | ROOT |
| `WOOD` | Wood | Static organic; burns slowly | PLNT |
| `MUD` | Mud | Water + dirt analog; slows flow | WATR + SAND reaction |
| `FUNG` | Fungus | Spreads on wood/plant | PLNT |

### Tier 5 — Atmosphere (runs 50–80)

| ID | Name | Behavior | Requires |
|----|------|----------|----------|
| `OXYG` | Oxygen | Supports fire; produced by plants | PLNT sustained 30s |
| `CO2` | Carbon Dioxide | Sinks; absorbed by plants | PLNT |
| `HYGN` | Hydrogen | Rises; flammable | Electrolysis |
| `NITR` | Nitrogen | Inert filler gas | Atmosphere pack |

### Tier 6 — Life (runs 80+)

| ID | Name | Behavior | Requires |
|----|------|----------|----------|
| `SOUP` | Primordial soup | Catalyzes organic reactions when heated | MUD + amino milestone |
| `GOL` | Life cell | Conway-like rules in subset | SOUP + electricity spark |
| `BACT` | Bacteria | Crawls, eats organic | GOL stable 60s |
| `CELL` | Membrane cell | Maintains interior chemistry | BACT + OXYG |
| `ALGA` | Algae | Photosynthesis: CO2 → OXYG in light | CELL + water |

### Tier 7 — Powder Toy advanced (post-prestige)

Subset of real TPT elements for veterans:

| TPT ID | Name | Why include |
|--------|------|-------------|
| `DUST` | Dust | TNT chain, spark effects |
| `GUN` | Gunpowder | Explosion gameplay |
| `TNT` | TNT | NITR + CLST milestone |
| `NEUT` | Neutrons | Transmutation fantasy |
| `PLUT` | Plutonium | Radioactive heat |
| `EXOT` | Exotic matter | Prestige spectacle |
| `VIBR` | Vibranium | Energy transfer toy |
| `CLON` | Clone | Sandspiel-style copier |

Full TPT element reference: [Official Wiki — Elements](https://powdertoy.co.uk/Wiki/W/Elements.html) | [Fandom Wiki](https://tpt.fandom.com/wiki/Powder_Toy_Wiki) | [Sortable element table (forum)](https://powdertoy.co.uk/Discussions/Thread/View.html?Thread=21694)

### TPT category map (for future expansion)

| TPT Category | Examples | Incremental gate |
|--------------|----------|------------------|
| Powders | DUST, SAND, SNOW | Early |
| Liquids | WATR, OIL, ACID, LAVA | Tier 1–3 |
| Gases | OXYG, HYGN, CO2, SMOK | Tier 5 |
| Solids | STNE, WOOD, GLAS, METL | Tier 1–4 |
| Explosives | GUN, TNT, C4, FWRK | Tier 7 |
| Radioactive | URAN, PLUT, NEUT | Post-prestige |
| Electronics | WIRE, SWCH, ARAY | Optional DLC tree |
| Special | CLON, LIFE, VIBR | Late game |
| Game of Life | GOL, LIFe variants | Life tier |

---

## 7. Element Interaction Tables

### 7.1 MVP interactions (14 elements — implement first)

Based on [powder-lab](https://github.com/thatmike1/powder-lab), [Sandspiel species.rs](https://github.com/MaxBittker/sandspiel/blob/master/crate/src/species.rs), and [Pagáč thesis rules](https://is.muni.cz/th/w12aw/SimulatingWorldsCA.pdf).

| Element A | Element B | Result A | Result B | Condition |
|-----------|-----------|----------|----------|-----------|
| LAVA | WATR | STONE | STEAM | contact |
| FIRE | WOOD | FIRE | FIRE | spread (chance) |
| FIRE | OIL | FIRE | FIRE | spread |
| FIRE | PLNT | FIRE | ASH | spread |
| WATR | FIRE | STEAM | — | extinguishes |
| WATR | LAVA | — | STEAM | quench |
| ACID | STONE | — | — | acid dissolves stone |
| ACID | SAND | — | — | acid dissolves sand |
| ICE | FIRE | WATR | — | melts |
| WATR | ICE | ICE | — | adjacent freeze (cold) |
| SEED | SAND+WATR | ROOT | — | seed in wet sand |
| ROOT | WATR | PLNT | — | sustained contact |
| PLNT | FIRE | FIRE | ASH | burn |
| GUNPOWDER | FIRE | FIRE | — | chain explosion |
| OIL | WATR | — | — | oil floats (density swap) |
| SAND | WATR | — | — | sand sinks (density) |
| LAVA | — | — | — | sinks through all |

### 7.2 Sandspiel element behaviors (reference)

From [Sandspiel Fandom](https://gamicus.fandom.com/wiki/Sandspiel) and [species.rs](https://github.com/MaxBittker/sandspiel/blob/master/crate/src/species.rs):

| Element | Key interactions |
|---------|------------------|
| Sand | Sinks in water |
| Water | Puts out fire; freezes to ice |
| Stone | Forms arches; folds under pressure |
| Ice | Freezes water; slippery |
| Gas | Highly flammable |
| Cap (Cloner) | Copies first element touched |
| Mite | Eats wood/plant; loves dust |
| Wood | Sturdy, biodegradable |
| Plant | Thrives in wet environments |
| Fungus | Spreads over everything |
| Seed | Grows in sand |
| Fire | Hot; spreads |
| Lava | Heavy, flammable |
| Acid | Corrodes elements |
| Dust | Explosive |
| Oil | Produces smoke when burning |
| Rocket | Explodes into copies of first touched element |

### 7.3 Sandboxels reaction model (data format reference)

Sandboxels defines reactions as objects per element ([Modding/Reactions](https://sandboxels.wiki.gg/wiki/Modding/Reactions)):

```javascript
reactions: {
  "dirt":  { elem1: null, elem2: "mud" },
  "sand":  { elem1: null, elem2: "wet_sand" },
  "salt":  { elem1: "salt_water", elem2: null },
}
```

Supported constraints: `chance`, `tempMin`, `tempMax`, `burning1/2`, `charged`, `y` (height), `setting`.

**558 elements** documented at [Sandboxels Element list](https://sandboxels.wiki.gg/wiki/Element) — use as inspiration mine, not port target.

Common Sandboxels chains:

| Chain | Steps |
|-------|-------|
| Mud → soil | dirt + water → mud |
| Plant growth | mud + water + light |
| Rust | iron + oxygen + water |
| Cement | limestone + heat |

### 7.4 The Powder Toy — notable reactions

From [community reaction threads](https://powdertoy.co.uk/Discussions/Thread/View.html?Thread=20074) and wiki lore:

| Reactants | Products | Notes |
|-----------|----------|-------|
| NITR + CLST | TNT | Classic explosive craft |
| WATR + ELEC | H₂ + O₂ | Electrolysis (simplified) |
| WATR + NEUT | DSTW | Destabilized water |
| GUN + NEUT | DUST | Transmutation |
| DUST + NEUT | FWRK | Fireworks |
| EXOT + NEUT | clones touched element | Exotic matter |
| EXOT + PROT | CFLM explosion | Matter-antimatter analog |
| OIL + pressure | not INSL | Common misconception |
| PLNT + NEUT | WOOD (sometimes) | Life manipulation |
| BRAY (high P,T) + spark | EXOT | Extreme conditions |

Full interaction discovery UI requested in [forum thread 27454](https://powdertoy.co.uk/Discussions/Thread/View.html?Thread=27454) — our game should ship an **in-game reaction journal** (incremental collection mechanic).

### 7.5 Density table (MVP)

Higher number = denser = sinks. Used for swap decisions each tick.

| Element | Density rank |
|---------|--------------|
| STEAM, SMOK, OXYG, HYGN | 1 (rise) |
| FIRE | 2 |
| OIL | 3 |
| WATR | 4 |
| SAND | 5 |
| LAVA | 6 |
| STONE | 7 (static) |
| WALL | 8 (static) |

### 7.6 Temperature thresholds (MVP)

| Element | Freeze | Boil | Ignite |
|---------|--------|------|--------|
| WATR | 0°C → ICE | 100°C → STEAM | — |
| OIL | — | — | 200°C |
| WOOD/PLNT | — | — | 300°C |
| SAND | — | — | — (inert) |
| LAVA | — | — | always hot |

---

## 8. Life & Emergence Progression

### Goal: "Create life from disparate elements"

Staged emergence mirrors real abiogenesis **simplified for gameplay**:

### Stage 1 — Geology (Tier 0–1)
Player learns: particles fall, water flows, boundaries contain.

**Win condition:** Maintain water pool 30s.

### Stage 2 — Energy cycles (Tier 2)
Fire, steam convection, ice/water cycle.

**Win condition:** Trigger 5 phase changes in one run.

### Stage 3 — Chemistry (Tier 3)
Acid erosion, ash, salt dissolution.

**Win condition:** Create ASH + WATR + SALT coexistence 20s.

### Stage 4 — Organics (Tier 4)
Seed → root → plant in wet sand ([GopherSand model](https://github.com/DonBattery/gophersand)).

**Win condition:** Grow 10 connected plant cells.

### Stage 5 — Atmosphere (Tier 5)
Plants emit OXYG; fire consumes OXYG; CO2 feedback.

**Win condition:** Closed loop: plant + fire + water stable 60s.

### Stage 6 — Protocell (Tier 6)
Introduce Game-of-Life rules in isolated `GOL` element ([TPT LIFE category](https://tpt.fandom.com/wiki/Game_Of_Life)):

- B3/S23 on organic substrate
- "Nutrient" cells from SOUP feed growth

**Win condition:** GOL pattern survives 100 generations.

### Stage 7 — Living ecosystem
Algae + bacteria + plants in shared sim ([ClancyWalters falling sand](https://github.com/ClancyWalters/falling_sand_game) models CO2/O2 exchange).

**Win condition:** "Biodiversity score" ≥ 50 (3+ life element types coexisting 120s).

### Falling Sand Idle life lesson

Level 2's leaf → dead leaf → bug cycle shows **death as resource** — consider a **decomposer** element unlocked after first plant extinction event.

---

## 9. Simulation Architecture

### Recommended approach for Godot 4

**Phase 1 (MVP):** CPU grid + dirty chunks — matches [powder-lab](https://github.com/thatmike1/powder-lab) and [Noita's](https://80.lv/articles/noita-a-game-based-on-falling-sand-simulation) chunk skipping.

**Phase 2 (scale):** GPU compute with Margolus neighborhood — matches [GPU-Falling-Sand-CA](https://github.com/GelamiSalami/GPU-Falling-Sand-CA) and [Powder-Sim](https://github.com/DeckardGer/Powder-Sim).

### Cell data model

```gdscript
# Per cell (packed for cache efficiency)
class Cell:
    var element: int      # uint8 element ID
    var temp: int         # int16 fixed-point (e.g. ×100)
    var flags: int        # burning, charged, life_age, etc.
    var aux: int          # element-specific state (GOL age, plant growth)
```

### Update order (critical)

1. Process **active chunks** only (16×16 or 32×32).
2. Within chunk: iterate **bottom row to top** for gravity materials.
3. Randomize horizontal scan direction per row (reduces bias).
4. For multi-thread: use **4-pass checkerboard** (Noita method).

### Chunk activation

Mark chunk active when:
- Player places material in chunk
- Any cell changes state in chunk
- Neighbor chunk had activity (1-chunk halo)

Settled chunks cost **zero** CPU — essential for incremental game with long timers.

### Separation from incremental layer

```
┌─────────────────────────────────────────┐
│  IncrementalManager (autoload)          │
│  - currencies, upgrades, unlocks          │
│  - listens to SimEventBus               │
├─────────────────────────────────────────┤
│  SimEventBus (autoload)                   │
│  - reaction_discovered(a,b,result)      │
│  - life_milestone(type)                   │
│  - run_tick(elapsed)                      │
├─────────────────────────────────────────┤
│  PowderSimulation (Node)                │
│  - grid[], chunks[], tick(), no UI      │
├─────────────────────────────────────────┤
│  PowderRenderer (CanvasItem)            │
│  - ImageTexture / shader display        │
└─────────────────────────────────────────┘
```

---

## 10. Godot Implementation Resources

### Tier 1 — Start here (GDScript CPU sim)

| Resource | URL | Notes |
|----------|-----|-------|
| **Godot Falling Sand (mobile)** | [stereoa/Godot-Falling-Sand](https://github.com/stereoa/Godot-Falling-Sand) | Sand + water, touch draw, GDScript grid |
| **Zylann fluid2d_demo** | [Zylann/fluid2d_demo](https://github.com/Zylann/fluid2d_demo) | Canonical 2D CA fluid in Godot |
| **Godot fluid forum thread** | [forum.godotengine.org](https://forum.godotengine.org/t/best-way-to-implement-2d-fluid-simulation/23901) | Zylann's advice: custom grid, not TileMap |
| **Idle/Physics Processing** | [Godot docs](https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html) | `_process(delta)` for sim |
| **Falling Sand Idle** | [IncrementalDB](https://www.incrementaldb.com/game/falling-sand-idle) | Same engine target; Godot incremental + sim |

### Tier 2 — GPU acceleration (Godot 4 Forward+)

| Resource | URL | Notes |
|----------|-----|-------|
| **Compute Shaders tutorial** | [Godot docs](https://docs.godotengine.org/en/stable/tutorials/shaders/compute_shaders.html) | RenderingDevice, dispatch |
| **CellularAutomataStudio** | [pascal-ballet/CellularAutomataStudio](https://github.com/pascal-ballet/CellularAutomataStudio) | Godot plugin; GLSL compute CA |
| **GPU Cellular Automata** | [Asset Library](https://godotassetlibrary.com/asset/pZ1fXj/gpu-cellular-automata) | Ping-pong viewport shader |
| **godot-boids (compute)** | [DevPoodle/godot-boids](https://github.com/DevPoodle/godot-boids) | RenderingDevice render + compute |
| **Compute Shader Plus** | [DevPoodle/compute-shader-plus](https://github.com/DevPoodle/compute-shader-plus) | Plugin used by boids demo |
| **Texture2DRD sharing** | [Godot Forum](https://forum.godotengine.org/t/how-to-draw-texture-rid-from-local-renderingdevice-on-screen/116655) | Display compute output |

### Tier 3 — External algorithms to port

| Resource | URL | Technique |
|----------|-----|-----------|
| **GPU-Falling-Sand-CA** | [GelamiSalami/GPU-Falling-Sand-CA](https://github.com/GelamiSalami/GPU-Falling-Sand-CA) | Margolus block CA, WebGL |
| **Powder-Sim (WebGPU)** | [DeckardGer/Powder-Sim](https://github.com/DeckardGer/Powder-Sim) | 512² grid, 24 Margolus passes |
| **cellular DSL** | [werk/cellular](https://github.com/werk/cellular) | GPU CA rule language |
| **Falling Turnip** | [tranma/falling-sand-game](https://github.com/tranma/falling-sand-game) | Parallel Haskell CA |
| **powder-lab** | [thatmike1/powder-lab](https://github.com/thatmike1/powder-lab) | Dirty chunks, 14 materials, TS |
| **sandspiel** | [MaxBittker/sandspiel](https://github.com/MaxBittker/sandspiel) | Rust/WASM species update fns |
| **gophersand** | [DonBattery/gophersand](https://github.com/DonBattery/gophersand) | Active tile bitfield, Go |
| **clicker-engine** | [blixxurd/clicker-engine](https://github.com/blixxurd/clicker-engine) | Incremental architecture (TS) |

### Tier 4 — The Powder Toy source (C++ reference)

| Path | Content |
|------|---------|
| [The-Powder-Toy/The-Powder-Toy](https://github.com/The-Powder-Toy/The-Powder-Toy) | Full pressure/heat/velocity sim |
| `src/simulation/` | Element update functions |
| [Lua API: Elements](https://powdertoy.co.uk/Wiki/W/Lua_API:Elements.html) | Element type/property constants |
| [Element properties wiki](https://powdertoy.co.uk/Wiki/W/Element_Properties.html) | PROP_* flags |

### Godot project settings note

This template uses **GL Compatibility** renderer. Compute shaders require **Forward+** or **Mobile** renderer ([docs](https://docs.godotengine.org/en/stable/tutorials/shaders/compute_shaders.html)). Plan renderer switch before GPU sim phase.

---

## 11. Academic & Technical Papers

| Title | Author | URL | Relevance |
|-------|--------|-----|-----------|
| **Simulating Game Worlds Using Cellular Automata** | Tomáš Pagáč, 2022 | [MU Brno thesis PDF](https://is.muni.cz/th/w12aw/SimulatingWorldsCA.pdf) | Falling-sand rules, block CA, chunking, visual rule editor |
| **Noita: Sand System** (student analysis) | Lukas Tamayo | [PDF](https://www.lukastamayo.com/uploads/1/3/3/8/133827693/noitasandsystem_clararipardminisini_lukastamayo.pdf) | Unity CA prototype; density swap |
| **Exploring the Tech and Design of Noita** | Petri Purho, GDC 2019 | [YouTube](https://www.youtube.com/watch?v=prXuyMCgbTc) / [GDC Vault](https://www.gdcvault.com/play/1025695/Exploring-the-Tech-and-Design) | Chunking, rigid bodies, scaling |
| **Noita dev notes** | Ben Lau | [Blog](https://benlau6.github.io/notes/noita/) | ECS vs sim separation |
| **Making Sandspiel** | Max Bittker | [Blog](https://maxbittker.github.io/making-sandspiel/) | Species update functions, WASM+WebGL |
| **Calculus in Incremental Game Mechanics** | Howard | [Site](https://howard-2718.github.io/section-1.html) | Replicanti growth math (AD) |
| **The Math of Idle Games I–III** | Anthony Pecorella | [Part I](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-i) | Progression tuning |
| **Falling-sand game (Wikipedia)** | — | [Wikipedia](https://en.wikipedia.org/wiki/Falling-sand_game) | Genre history |
| **Technology Trees and Tools** | Lukkarinen, 2021 | [Theseus PDF](https://www.theseus.fi/bitstream/handle/10024/919668/Lukkarinen_Lila.pdf) | UI for research trees |
| **Block cellular automata (Margolus)** | — | [GPU-Falling-Sand-CA README](https://github.com/GelamiSalami/GPU-Falling-Sand-CA) | Parallel-safe CA |
| **80.lv Noita article** | — | [80.lv](https://80.lv/articles/noita-a-game-based-on-falling-sand-simulation) | Bottom-up update explanation |

### Key algorithms to study

1. **Margolus neighborhood** — 2×2 block CA; avoids race conditions on GPU ([GelamiSalami](https://gelamisalami.github.io/GPU-Falling-Sand-CA/)).
2. **Dirty rectangle / chunk scheduling** — Only simulate active regions ([powder-lab](https://github.com/thatmike1/powder-lab), [Noita](https://80.lv/articles/noita-a-game-based-on-falling-sand-simulation)).
3. **Bottom-up gravity pass** — Required for stable falling ([Noita](https://80.lv/articles/noita-a-game-based-on-falling-sand-simulation)).
4. **Ping-pong buffers** — GPU double-buffering ([Powder-Sim](https://github.com/DeckardGer/Powder-Sim)).
5. **Data-driven reactions** — Sandboxels `reactions` object pattern ([wiki](https://sandboxels.wiki.gg/wiki/Modding/Reactions)).

---

## 12. Reference Implementations

### By complexity (ascending)

| Project | Elements | Stack | Best for |
|---------|----------|-------|----------|
| [Godot-Falling-Sand](https://github.com/stereoa/Godot-Falling-Sand) | 2 | Godot GDScript | Godot grid basics |
| [powder-lab](https://github.com/thatmike1/powder-lab) | 14 | React/TS | MVP material design |
| [gophersand](https://github.com/DonBattery/gophersand) | ~10 | Go/Ebiten | Active tile optimization |
| [sandspiel](https://github.com/MaxBittker/sandspiel) | 20 | Rust/WASM | Species function architecture |
| [ClancyWalters/falling_sand_game](https://github.com/ClancyWalters/falling_sand_game) | ~15 | Custom | Life + CO2/O2 |
| [Sandboxels](https://sandboxels.wiki.gg/) | 558 | JavaScript | Reaction data mining |
| [The Powder Toy](https://github.com/The-Powder-Toy/The-Powder-Toy) | 180+ | C++/SDL | Full physics target |

### Incremental + simulation

| Project | URL |
|---------|-----|
| Falling Sand Idle | [Steam](https://store.steampowered.com/app/3714750/Falling_Sand_Idle/) / [IncrementalDB](https://www.incrementaldb.com/game/falling-sand-idle) |
| clicker-engine (architecture) | [GitHub](https://github.com/blixxurd/clicker-engine) |
| Idle Game Generator (balance) | [toolpile.dev](https://idlegamegenerator.toolpile.dev/) |

---

## 13. MVP Scope Recommendation

### Build order

1. **Week-equivalent 1:** 64×64 grid, SAND + WALL + WATR, timer, Insight currency, 3 timer upgrades.
2. **Phase 2:** FIRE, STEAM, density, reaction journal, 8 elements total.
3. **Phase 3:** SEED/PLNT growth, first life milestone, prestige layer.
4. **Phase 4:** GPU chunks, 256×256, 14+ elements.

### MVP element set (14)

`SAND, WALL, WATR, STONE, FIRE, STEAM, ICE, OIL, LAVA, ACID, WOOD, PLNT, SEED, GUNPOWDER`

### MVP upgrade set (12)

- Timer ×4
- Budget ×4
- Brush size ×2
- Unlock: Water, Fire, Plant, Acid

### Success metrics

| Metric | Target |
|--------|--------|
| Sim tick (64², active ~30%) | <2ms CPU |
| First reaction discovery | <8 minutes |
| Players reaching Plant tier | >60% at 2hr |
| Session length | 5–15 min per run |

---

## 14. Full Link Index

### Games & wikis
- [The Powder Toy](https://powdertoy.co.uk/)
- [TPT GitHub](https://github.com/The-Powder-Toy/The-Powder-Toy)
- [TPT Fandom Wiki](https://tpt.fandom.com/wiki/Powder_Toy_Wiki)
- [TPT Elements (official wiki)](https://powdertoy.co.uk/Wiki/W/Elements.html)
- [TPT element reference table](https://powdertoy.co.uk/Discussions/Thread/View.html?Thread=21694)
- [TPT reaction thread](https://powdertoy.co.uk/Discussions/Thread/View.html?Thread=20074)
- [Sandboxels Wiki](https://sandboxels.wiki.gg/)
- [Sandboxels elements](https://sandboxels.wiki.gg/wiki/Element)
- [Sandboxels reactions modding](https://sandboxels.wiki.gg/wiki/Modding/Reactions)
- [Sandspiel](https://sandspiel.club/)
- [Sandspiel GitHub](https://github.com/MaxBittker/sandspiel)
- [Making Sandspiel](https://maxbittker.github.io/making-sandspiel/)
- [Falling Sand Idle](https://www.incrementaldb.com/game/falling-sand-idle)
- [Noita Steam](https://store.steampowered.com/app/881100/Noita/)
- [Falling-sand game (Wikipedia)](https://en.wikipedia.org/wiki/Falling-sand_game)

### Godot & code
- [stereoa/Godot-Falling-Sand](https://github.com/stereoa/Godot-Falling-Sand)
- [Zylann/fluid2d_demo](https://github.com/Zylann/fluid2d_demo)
- [CellularAutomataStudio](https://github.com/pascal-ballet/CellularAutomataStudio)
- [GPU Cellular Automata (asset)](https://godotassetlibrary.com/asset/pZ1fXj/gpu-cellular-automata)
- [DevPoodle/godot-boids](https://github.com/DevPoodle/godot-boids)
- [Godot compute shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/compute_shaders.html)
- [powder-lab](https://github.com/thatmike1/powder-lab)
- [gophersand](https://github.com/DonBattery/gophersand)
- [ClancyWalters/falling_sand_game](https://github.com/ClancyWalters/falling_sand_game)
- [GPU-Falling-Sand-CA](https://github.com/GelamiSalami/GPU-Falling-Sand-CA)
- [Powder-Sim WebGPU](https://github.com/DeckardGer/Powder-Sim)
- [tranma/falling-sand-game](https://github.com/tranma/falling-sand-game)
- [werk/cellular](https://github.com/werk/cellular)
- [blixxurd/clicker-engine](https://github.com/blixxurd/clicker-engine)

### Papers & talks
- [Pagáč CA thesis PDF](https://is.muni.cz/th/w12aw/SimulatingWorldsCA.pdf)
- [Noita GDC YouTube](https://www.youtube.com/watch?v=prXuyMCgbTc)
- [Noita 80.lv article](https://80.lv/articles/noita-a-game-based-on-falling-sand-simulation)
- [Noita sand system PDF](https://www.lukastamayo.com/uploads/1/3/3/8/133827693/noitasandsystem_clararipardminisini_lukastamayo.pdf)
- [Ben Lau Noita notes](https://benlau6.github.io/notes/noita/)

### Incremental design
- [Incremental 2D research (this repo)](incremental-2d-game-loop-research.md)
- [Idle Game Generator](https://idlegamegenerator.toolpile.dev/)
- [Pecorella spreadsheets](http://kon.gg/idle-math-spreadsheets)
- [Solana Garden idle design](https://solana.garden/guides/game-idle-game-design-explained/)

---

*Document for the Godot 4 2D Game Template project. Last updated: June 2026.*
