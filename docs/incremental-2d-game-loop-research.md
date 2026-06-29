# Incremental 2D Games: Game Loop, Upgrade Paths & Design Research

A research reference for building 2D incremental / idle / clicker games — with emphasis on the **game loop**, **upgrade path design**, and **progression math**. Curated for this Godot 4 project template.

---

## Table of Contents

1. [Genre Overview](#1-genre-overview)
2. [The Core Game Loop](#2-the-core-game-loop)
3. [Technical Game Loop Architecture](#3-technical-game-loop-architecture)
4. [Common Upgrade Path Patterns](#4-common-upgrade-path-patterns)
5. [Progression Math & Balancing](#5-progression-math--balancing)
6. [Prestige & Reset Systems](#6-prestige--reset-systems)
7. [Active vs Passive Mechanics](#7-active-vs-passive-mechanics)
8. [Offline Progress & Persistence](#8-offline-progress--persistence)
9. [Big Numbers & Notation](#9-big-numbers--notation)
10. [2D Presentation & Feel](#10-2d-presentation--feel)
11. [Case Studies](#11-case-studies)
12. [Tools, Spreadsheets & Libraries](#12-tools-spreadsheets--libraries)
13. [Godot-Specific Notes](#13-godot-specific-notes)
14. [Design Checklist](#14-design-checklist)
15. [Full Link Index](#15-full-link-index)

---

## 1. Genre Overview

Incremental games (also called idle games, clicker games, or number-go-up games) are defined by:

- **Continuous or semi-continuous progress** — numbers grow even when the player is not actively playing.
- **Player choices that modify growth rates** — which upgrade to buy, when to prestige, which generator to prioritize.
- **No hard "end"** — the experience is a ladder of escalating power, often punctuated by voluntary resets.

### Terminology

| Term | Meaning |
|------|---------|
| **Incremental** | Broad genre: any game where progress compounds over time |
| **Idle** | Subset where passive income is expected and central |
| **Clicker** | Subset where manual clicking is a primary early income source |
| **Generator** | A building/unit that produces currency per second |
| **Wall** | A pacing slowdown where the next purchase takes noticeably longer |
| **Prestige / Ascension** | Voluntary reset granting permanent meta-currency or multipliers |
| **Milestone** | Threshold bonus (e.g. double output at 25 owned) |

### Key design articles

- [Numbers Getting Bigger: The Design and Math of Incremental Games](https://code.tutsplus.com/numbers-getting-bigger-the-design-and-math-of-incremental-games--cms-24023a) — Envato Tuts+ foundational overview of active vs passive mechanics, exponential costs, and design principles.
- [How to design idle games](https://machinations.io/articles/idle-games-and-how-to-design-them) — Machinations.io on core loops, economy design, and offline mode.
- [Idle Game Design Explained: Prestige, Offline Progress and Incremental Loops](https://solana.garden/guides/game-idle-game-design-explained/) — Modern breakdown of earn → spend → accelerate → wall cycle.
- [Quest for Progress: Numbers Behind Idle Games](https://www.kongregate.com/pages/quest-for-progress-the-math-of-idle-games) — Anthony Pecorella's GDC companion page with spreadsheet links.
- [Clicker Games: A Technical Exploration of Incremental System Architecture](https://medium.com/@tommcfly2025/clicker-games-a-technical-exploration-of-incremental-system-architecture-b6d842e6963e) — Architecture-focused Medium article.

### Player motivation profile (from Pecorella's GDC talk)

Idle players typically want:

1. **Power growth** — they must *feel* numbers accelerating.
2. **Collection / completion** — achievements, unlocks, filling bars.
3. **Optimization puzzles** — figuring out the best purchase order.

Source: [Quest for Progress GDC PDF](https://media.gdcvault.com/gdceurope2016/presentations/Pecorella_Anthony_Quest%20for%20Progress.pdf)

---

## 2. The Core Game Loop

Nearly every successful incremental game repeats a four-step macro loop:

```
┌─────────┐     ┌─────────┐     ┌────────────┐     ┌──────────┐
│  EARN   │ ──► │  SPEND  │ ──► │ ACCELERATE │ ──► │ HIT WALL │
│ tap/idle│     │ upgrades│     │ income spike│     │ wait/opt │
└─────────┘     └─────────┘     └────────────┘     └────┬─────┘
     ▲                                                    │
     └──────────────── prestige / milestones ─────────────┘
```

### Earn

Income sources stack multiplicatively:

- **Manual clicks** — `coins += click_power` per tap.
- **Passive generators** — `coins += total_cps * delta` per tick.
- **Offline catch-up** — computed on load from elapsed time.
- **Event buffs** — golden cookies, timed boosts, combo multipliers.

### Spend

Player converts currency into:

- More generators (exponential cost scaling).
- One-time upgrades (flat or multiplicative bonuses).
- Automation (auto-buyers, managers).
- Meta-progression (prestige currency, research points).

### Accelerate

Purchases create **super-linear windows** — milestone doubles, new generator tiers, synergy unlocks. The player experiences a burst of speed before the next wall.

### Hit a Wall

Costs outpace income. The player:

- Waits (idle accumulation).
- Optimizes (switches generator priority).
- Resets (prestige for permanent boost).
- Engages actively (clicks events, manages buff combos).

### Micro loop (per session)

1. Open game → see offline earnings summary.
2. Spend accumulated currency on best ROI upgrade.
3. Optionally click / chase events for burst income.
4. Reach next milestone or wall → leave or prestige.

---

## 3. Technical Game Loop Architecture

### Separation of concerns

Best practice: split the game into modules that never entangle rendering with economy logic.

| Module | Responsibility |
|--------|----------------|
| **State** | Resources, generator counts, upgrade flags, timestamps |
| **Logic** | Cost formulas, purchase validation, prestige calculations |
| **Tick / Loop** | Fixed-timestep updates, offline catch-up |
| **UI / Render** | Display numbers, buttons, particles — reads state only |
| **Persistence** | Serialize state, versioned saves, load + migrate |

References:

- [Learn App Architecture Through Clicker & Idle Games](https://www.zapcode.dev/learn/clicker-idle-games-with-app-architecture) — State / logic / UI / persistence modules, event bus pattern.
- [blixxurd/clicker-engine](https://github.com/blixxurd/clicker-engine) — TypeScript reference implementation with `TickRunner`, `Economy`, `PersistenceManager`.
- [vardst/cookieclicker](https://github.com/vardst/cookieclicker) — Cookie Clicker reimplementation showing modular file structure (`cps.js`, `prestige.js`, `save.js`, `main.js`).

### Fixed timestep vs variable delta

**Variable delta** (simple, common in idle games):

```gdscript
func _process(delta: float) -> void:
    currency += production_rate * delta
```

**Fixed timestep** (recommended when simulation must be deterministic — combos, physics-like particles, anti-cheat):

```javascript
const DT = 1.0 / 60.0;
let accumulator = 0;

function loop(now) {
  accumulator += (now - lastTime) / 1000;
  while (accumulator >= DT) {
    simulate(DT);   // economy tick
    accumulator -= DT;
  }
  render();         // interpolate visuals if needed
  requestAnimationFrame(loop);
}
```

References:

- [How to make a game loop for your idle game](https://gist.github.com/HipHopHuman/3e9b4a94b30ac9387d9a99ef2d29eb1a) — Excellent walkthrough of delta time, fixed timestep, interpolation, and spiral-of-death prevention.
- [Idler Game Loop — Sam Hogarth](https://samhogy.co.uk/2025/06/idler-game-loop/) — Practical fixed-timestep implementation with `GameLoop` and `GameArea` classes.
- [Taming Time in Game Engines — Fixed Timestep](https://andreleite.com/posts/2025/game-loop/fixed-timestep-game-loop/) — Accumulator pattern explained clearly.
- [Gaffer on Games — Fix Your Timestep!](http://gafferongames.com/game-physics/fix-your-timestep/) — Canonical reference (also mirrored at [vodacek.zvb.cz](http://vodacek.zvb.cz/archiv/681.html)).

### Event-driven UI updates

Publish state changes (`coins:changed`, `generator:purchased`) so UI, achievements, and analytics react without tight coupling. See [Zap Code architecture guide](https://www.zapcode.dev/learn/clicker-idle-games-with-app-architecture).

### Tick rate guidance

| Tick interval | Use case |
|---------------|----------|
| Every frame (`_process`) | Smooth currency display, click feedback |
| 1 second | Autosave, achievement checks, coarse UI refresh |
| On purchase only | Recalculate total production rate (not every frame) |

**Performance tip:** Cache `total_cps` and recalculate only when upgrades change — do not sum all generators every frame.

---

## 4. Common Upgrade Path Patterns

### Pattern A: Linear generator chain (Cookie Clicker model)

Multiple generators with exponential individual costs. Each generator has a higher base output and higher growth rate.

```
Cursor → Grandma → Farm → Mine → Factory → ...
```

- **Unlock gating:** Generator N+1 unlocks after owning X of generator N.
- **Milestone bonuses:** Output doubles at 25, 50, 100, etc. owned.
- **Synergy upgrades:** "Grandmas boost farms by +1% per grandma owned."

Example cost/production stacking from [vardst/cookieclicker](https://github.com/vardst/cookieclicker):

```
total_cps = base_cps
          × tier_multipliers
          × finger_upgrades
          × synergies
          × flavored_cookies
          × prestige_multiplier
          × kitten_upgrades
          × active_buffs
```

### Pattern B: Derivative / polynomial chain (Antimatter Dimensions model)

Generator tier N produces tier N−1, creating polynomial growth that *approaches* exponential behavior.

```
Dimension 8 → produces Dimension 7 → ... → Dimension 1 → produces Antimatter
```

- Lower tiers become huge in absolute terms.
- Different tiers take priority at different progression stages.
- Keeps early generators relevant via milestone boosts.

References:

- [The Math of Idle Games, Part II](https://www.gamedeveloper.com/game-platforms/the-math-of-idle-games-part-ii) — Derivative-based growth deep dive.
- [Derivative Clicker](https://www.kongregate.com/games/orevolos/derivative-clicker) — Kongregate game that inspired AD's polynomial model.
- [Calculus in Incremental Game Mechanics](https://howard-2718.github.io/section-1.html) — Mathematical modeling of Replicanti growth in AD.

### Pattern C: Factory / tycoon incremental

Generators consume or depend on other resources. Production chains add strategic depth.

- Multiple currencies (ore → ingots → products).
- Timer-based production (AdVenture Capitalist style progress bars).
- Manager auto-collection.

Reference: [Simple Idle Forge docs](https://livingfailure93.github.io/Simple-IDLE-Forge-Docs/) — Generator forge, milestone bonuses, prestige layers, achievement conditions.

### Pattern D: Faction / alignment branching (Realm Grinder model)

Player aligns with factions that unlock exclusive upgrade trees. Spells replace or supplement clicking.

- Upgrades must be *discovered* through gameplay actions.
- Prestige allows experimentation without permanent punishment.
- Risk: analysis paralysis from too many mutually exclusive choices.

Reference: [Research on Incremental Games (Fortune Fountain G wiki)](https://github-wiki-see.page/m/brandoncimino/fortune-fountain-g/wiki/Research-on-Incremental-Games)

### Pattern E: Research / tech trees

Spend research currency to unlock nodes in a directed graph.

Design principles:

- **Never unlock dead-end recipes** — every research node should immediately enable something useful. See [Emergence technology design](https://leafwing-studios.github.io/Emergence/research/technology.html).
- **Gate complexity over time** — few choices early, more branches later. See [What makes a good tech tree?](https://gamedev.stackexchange.com/questions/164987/what-makes-a-good-tech-tree)
- **Visual clarity** — use icons, connecting lines, progressive reveal. See [Lukkarinen thesis on technology trees](https://www.theseus.fi/bitstream/handle/10024/919668/Lukkarinen_Lila.pdf).
- **Academic reference:** [Technology Trees and Tools (Tampere thesis)](https://trepo.tuni.fi/handle/10024/113957)

### Pattern F: Multi-layer prestige ladder

Stack reset layers, each with its own currency:

```
Run → Infinity → Eternity → Reality → Celestial (Antimatter Dimensions)
Run → Reincarnation → Research (Realm Grinder)
Run → Ascension → Heavenly Chips (Cookie Clicker)
```

Each layer:

- Resets some or all previous progress.
- Grants currency with diminishing-returns formula.
- Unlocks new mechanics, not just multipliers.

### Pattern G: Challenges & achievements as upgrades

Optional constraints that reward permanent bonuses:

- "Reach 1M cookies without buying farms."
- "Beat level 50 with only manual clicks."

Inspired by Idle Wizard challenges; used extensively in AD. See [Hevipelle interview](https://www.incrementaldb.com/community/interview/31).

### Typical upgrade categories

| Category | Effect | Resets on prestige? |
|----------|--------|---------------------|
| Generators | +base production | Usually yes |
| Global multipliers | ×total output | Usually yes |
| Click power | +per-tap income | Usually yes |
| Automation | Auto-buy, auto-collect | Varies |
| Milestone bonuses | Threshold-triggered | Usually yes |
| Achievements | Permanent small bonuses | Often no |
| Prestige upgrades | Meta-progression | No |
| Cosmetics | Visual only | No |

### Bonus stacking order

Transparent pipeline (from [Simple Idle Forge](https://livingfailure93.github.io/Simple-IDLE-Forge-Docs/)):

```
final_rate = (base + flat_bonuses) × (1 + sum_of_percent_bonuses) × product_of_multipliers
```

Document your order of operations. Hidden stacking rules cause balance bugs and player distrust.

---

## 5. Progression Math & Balancing

### Exponential cost formula (industry standard)

```
cost(n) = base_cost × growth_rate^n
```

Where:

- `n` = quantity currently owned
- `growth_rate` typically **1.07 – 1.15** (Cookie Clicker uses ~1.15 for buildings)

Source: [Envato Tuts+ incremental games article](https://code.tutsplus.com/numbers-getting-bigger-the-design-and-math-of-incremental-games--cms-24023a)

### Why exponential costs work

Exponential costs (`r^n`) eventually dominate polynomial production (`n^k`), creating natural walls. This also auto-balances multiple upgrade paths — even a "better" generator cannot be spammed forever.

Source: [The Math of Idle Games, Part I](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-i)

### Bulk-buy formulas

**Cost of buying n generators at once:**

```
cost = b × (r^k × (r^n − 1)) / (r − 1)
```

**Max affordable generators:**

```
max = floor(log_r( c(r−1) / (b × r^k) + 1 ))
```

Variables: `b` = base price, `r` = growth rate, `k` = owned count, `c` = currency, `n` = buy count.

Source: [Math of Idle Games Part I](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-i) | [Kongregate mirror](https://www.kongregate.com/pages/the-math-of-idle-games-part-i)

### Milestone multiplier design

Set generator-specific multipliers at ownership thresholds to shift optimal strategy:

| Owned | Multiplier |
|-------|------------|
| 25 | ×2 |
| 50 | ×2 (×4 total) |
| 100 | ×2 (×8 total) |

This creates "bumps" on the income chart and short-term goals between walls. Tune with [Pecorella's spreadsheet Sheet 1e](https://www.kongregate.com/pages/quest-for-progress-the-math-of-idle-games) (models optimal generator choice over time).

### Growth rate tiers reference

[Eclipse1agg's True Exponential — tiers of fast-growing functions](https://www.reddit.com/r/incremental_games/comments/8s1agg/true_exponential_released_my_new_incremental_game/) — Referenced in Part I for understanding how exponential overtakes polynomial growth.

### Balancing workflow

1. Define formulas in a spreadsheet.
2. Simulate 10+ prestige cycles.
3. Target **first prestige in 30–120 minutes**.
4. Verify second run is **40–60% faster**.
5. Playtest 1-hour and 24-hour offline returns.

Sources: [Solana Garden idle design guide](https://solana.garden/guides/game-idle-game-design-explained/) | [Idle Game Generator tool](https://idlegamegenerator.toolpile.dev/)

### Balancing calculators

- [Idle Game Generator](https://idlegamegenerator.toolpile.dev/) — Generates balance models; exports JSON, Excel, Unity, Godot.
- [Game Incremental Growth Calculator](https://randomgamegenerator.com/game-incremental-growth-calculator/) — Compound growth simulator.
- [Game Prestige Calculator](https://randomgamegenerator.com/game-prestige-calculator/) — Prestige bonus estimator.
- [Game Reset Bonus Calculator](https://randomgamegenerator.com/game-reset-bonus-calculator/) — Reset bonus from progress.

---

## 6. Prestige & Reset Systems

### Purpose of prestige

1. **Ladder climbing** — reset → huge boost → power fantasy.
2. **Number compression** — rein exponential growth into manageable range.
3. **Content gating** — unlock new mechanics at each layer.

Source: [Math of Idle Games, Part III](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-iii)

### Prestige currency formulas

Use sub-linear scaling so returns diminish but never fully plateau:

| Formula | Example | Feel |
|---------|---------|------|
| Square root | `prestige = √(lifetime_currency)` | Gentle, frequent resets |
| Cube root | `prestige = ∛(lifetime_currency / 1e12)` | Cookie Clicker ascension |
| Logarithm | `prestige = log10(lifetime_currency)` | Very diminishing |
| Polynomial | `prestige = lifetime^0.5` | Tunable via exponent (0.4–0.6) |

### Cookie Clicker ascension (canonical example)

- **Prestige levels** = `⌊∛(total cookies baked all-time / 10^12)⌋`
- Each prestige level = **+1% CpS** (additive stack).
- **Heavenly Chips** = same magnitude as prestige; spent on permanent heavenly upgrades.

References:

- [Ascension — Cookie Clicker Wiki](https://cookieclicker.wiki.gg/wiki/Ascension)
- [Heavenly Chips — Cookie Clicker Wiki](https://cookieclicker.fandom.com/wiki/Heavenly_Chips)
- [When to ascend in Cookie Clicker](https://www.radiotimes.com/technology/gaming/cookie-clicker-when-to-ascend/)
- [How does prestige work? — Arqade](https://gaming.stackexchange.com/questions/130939/how-does-the-prestige-system-work-when-soft-resetting)

### When do players prestige?

Common heuristic: players reset when prestige currency gain is **+50% to +200%** over current holdings.

Simulate with [Pecorella's spreadsheet sheet 3a](https://www.kongregate.com/en/pages/the-math-of-idle-games-part-iii).

### What resets vs persists

| Typically reset | Typically persists |
|-----------------|------------------|
| Currency | Achievements |
| Generators | Prestige currency |
| Non-permanent upgrades | Heavenly / meta upgrades |
| Active buffs | Statistics (all-time baked) |
| Run-specific automation | Cosmetic unlocks |

### Multi-prestige design tips

- Vary pacing *between* prestiges (not just within a run).
- Unlock **new mechanics** at higher layers, not only multipliers.
- Consider sub-prestige loops (Egg Inc.'s ~5× earnings multiplier tiers — see [Part III](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-iii)).

---

## 7. Active vs Passive Mechanics

### The anti-idle paradox

Total automation kills engagement. Successful games alternate:

- **Passive accumulation** (satisfying return visits).
- **Short active bursts** (events, combos, click challenges).

Source: [Solana Garden idle design guide](https://solana.garden/guides/game-idle-game-design-explained/)

### Golden Cookie model (Cookie Clicker)

Random spawns on screen grant temporary buffs:

| Effect | Typical value |
|--------|---------------|
| Frenzy | ×7 CpS for 77s |
| Lucky | Lump sum of cookies |
| Click Frenzy | ×777 click power for 13s |
| Cookie Chain | Escalating rewards until break |

**Spawn timing:** Random interval between min/max; probability increases over time (not memoryless). See [Spawning mechanism wiki](https://cookieclicker.wiki.gg/wiki/Spawning_mechanism).

**Combo stacking:** Multiple buffs multiply together — can yield days of production in seconds. See [Golden Cookie wiki](https://cookieclicker.wiki.gg/wiki/Golden_Cookie).

**Implementation notes:**

- Weighted random effect pool.
- 80% chance to exclude most recent effect (prevents streaks).
- On-screen duration ~13s; upgrades extend duration and reduce spawn interval.
- [How do Golden Cookies work? — Arqade](https://gaming.stackexchange.com/questions/130256/how-do-golden-cookies-work)

### Active mechanic design guidelines

- **1 active interrupt per session** minimum (timed event, boss, clickable bonus).
- Reward attention without punishing idle play.
- Make buffs *visible* and *exciting* (screen flash, particles, sound).
- Cap combo multipliers if they trivialize hours of design.

---

## 8. Offline Progress & Persistence

### Basic offline formula

```
offline_gain = min(elapsed_seconds, cap) × income_per_second × offline_efficiency
```

### Implementation pattern

1. Save `last_timestamp` on every save / app pause.
2. On load: `elapsed = now - last_timestamp`.
3. Apply capped earnings.
4. Show "Welcome back" summary screen.

References:

- [Rebuilding the Welcome Back mechanic](https://edvins.io/rebuilding-the-welcome-back-mechanic-from-idle-games-in-react) — Timestamp-based calculation with localStorage; discusses server-side anti-cheat.
- [IdleKit Offline Activity docs](https://docs.idlekit.io/2.1.1/manual/concepts/activitytrackingservice/) — Chronological simulation of expired timers and boosts.
- [clicker-engine `applyOfflineProgress`](https://github.com/blixxurd/clicker-engine) — Versioned save schema with offline catch-up.

### Offline design parameters

| Parameter | Typical value | Purpose |
|-----------|---------------|---------|
| Cap | 4–24 hours | Prevent skipping weeks of content |
| Efficiency | 50–100% | Discourage pure offline optimization |
| Boost option | Rewarded ad / IAP | Monetize without mandatory pay |

### Save system requirements

- **Versioned schema** with migration path for old saves.
- **Serialize primitives only** — no scene node references.
- **Autosave** every 30–60 seconds and on pause/close.
- **Export/import** for player trust (Cookie Clicker save strings).
- Server authoritative timestamps for anti-cheat in multiplayer or competitive idle games.

---

## 9. Big Numbers & Notation

JavaScript `Number` maxes around **1.79 × 10^308**. Incremental games routinely exceed this.

### Libraries

| Library | Max magnitude | Use |
|---------|---------------|-----|
| [decimal.js](https://github.com/MikeMcl/decimal.js/) | ~1e308 | High precision, slower |
| [break_infinity.js](https://github.com/Patashu/break_infinity.js/) | ~1e9e15 | Fast; used by Antimatter Dimensions |
| [break_eternity.js](https://github.com/Patashu/break_eternity.js/) | 10^^(1e308) | Tetration; sequel to break_infinity |
| [BreakInfinity.cs](https://github.com/Razenpok/BreakInfinity.cs/) | C# port | Unity games |
| [Eternal Notations](https://github.com/MathCookie17/Eternal-Notations) | Display layer | Abbreviates break_eternity numbers |
| [AD Notations](https://github.com/antimatter-dimensions/notations) | Display layer | For break_infinity.js |

### Notation systems

- [Eternal Notations demo](https://mathcookie17.github.io/Eternal-Notations/index.html) — Interactive notation preview.
- Standard abbreviations: K, M, B, T, then scientific notation, then layer notation (e.g. 1e3000 → "e3000" → "F1" → "e1e3000").

### Godot note

GDScript uses 64-bit floats (~1.7e308 max). For extreme incrementals in Godot:

- Store `log10(value)` internally for comparisons.
- Use a custom `BigNumber` class or string-backed decimal.
- Display formatted strings; never show raw floats above ~1e15 to players.

---

## 10. 2D Presentation & Feel

Incremental 2D games succeed on **feedback quality**, not graphics complexity.

### Click feedback checklist

| Effect | Target timing | Implementation |
|--------|---------------|----------------|
| Scale pulse on click | 50–150ms | Tween scale 1.0 → 1.1 → 1.0 |
| Number increment | <50ms | Update label immediately |
| Floating "+X" text | ~800ms | Drift up + fade out |
| Particle burst | Instant | 5–10 particles at click point |
| Sound | <30ms latency | Preloaded AudioStreamPlayer |

References:

- [How We Build Clicker Game UI — SEELE](https://www.seeles.ai/resources/blogs/scratch-clicker-game-ui) — Timing table, progressive disclosure, object pooling.
- [Phaser Idle Game Tutorial](https://generalistprogrammer.com/tutorials/phaser-idle-clicker-tutorial) — Orb pulse, floating text, ambient particles, scroll masks.
- [Telegram Clicker Game UI patterns](https://vp0.com/blogs/telegram-clicker-game-ui-clone) — Tap feel, energy bars, upgrade sheets.

### UI layout patterns

- **Central click target** — minimum 100×100px (120×120px mobile).
- **HUD strip** — currency, per-second rate, prestige multiplier.
- **Bottom/side panel** — generator shop with bulk-buy buttons.
- **Progressive disclosure** — reveal tabs (upgrades, achievements, prestige) as player progresses.
- **Number formatting** — always abbreviate; animate digit changes.

### Ambient life (screen never feels dead)

- Breathing scale animation on main target.
- Slow background parallax or particle drift.
- Periodic shimmer / glow on affordable upgrades.
- News ticker or flavor text (Cookie Clicker's `Ticker`).

### Performance for 2D effects

- **Object pooling** for particles and floating text.
- **Typed arrays** for large particle counts. See [Elliott Programmer particle optimizations](https://blog.elliottprogrammer.com/4-performance-optimizations-that-made-my-canvas-particle-animation-butter-smooth/).
- **GPU-friendly transforms** — scale/position tweens, not layout reflows.
- Throttle UI updates — only re-render labels when values change.

Particle tutorials:

- [Particle Systems — Lumitree Blog](https://lumitree.art/blog/particle-system) — Vanilla JS canvas patterns.
- Godot: `CPUParticles2D` / `GPUParticles2D` with one-shot bursts on click.

---

## 11. Case Studies

### Cookie Clicker (Orteil, 2013)

**Genre-defining clicker.** Exponential building costs, milestone tier upgrades, golden cookies, ascension/heavenly chips.

| Aspect | Detail |
|--------|--------|
| Core loop | Click → buy buildings → unlock tiers → ascend |
| Growth model | Exponential costs, multiplicative stacking |
| Prestige | Cube root of all-time cookies → heavenly chips |
| Active play | Golden cookies, combos, seasonal events |
| Open reference | [vardst/cookieclicker](https://github.com/vardst/cookieclicker) |

Further reading: [Cookie Clicker Wiki](https://cookieclicker.wiki.gg/) | [Orteil's site](https://orteil.dashnet.org/)

### AdVenture Capitalist (Hyper Hippo)

**Factory incremental with managers.** Timer-based businesses, angel investors as prestige currency.

- Pecorella was lead producer on mobile version.
- Milestone multipliers at 10, 25, 50, 100, etc. per business.
- Reference for "which generator is optimal" shifting over time.

### Antimatter Dimensions (Hevipelle)

**Polynomial generator chain with deep prestige layers.**

| Layer | Reset trigger |
|-------|---------------|
| Big Crunch | Infinity points |
| Eternity | Eternity points |
| Reality | Reality machines |
| Celestial | Endgame content |

Design inspirations (from [interview](https://www.incrementaldb.com/community/interview/31)):

- Polynomial growth from Derivative Clicker.
- Multi-layer prestige from Realm Grinder.
- Automation from Transport Defender.
- Challenges from Idle Wizard.

Reviews: [Jérémie Tessier](http://www.jeremietessier.com/reviews/2023/2/8/i-look-at-antimatter-dimensions) | [Grokipedia](https://grokipedia.com/page/Antimatter_Dimensions)

### Realm Grinder (Divine Games)

**Faction-aligned strategy incremental.**

- Spells as active mechanic.
- Research system with analysis-paralysis risk.
- Long "dead zones" between major unlocks.

Analysis: [Fortune Fountain G research wiki](https://github-wiki-see.page/m/brandoncimino/fortune-fountain-g/wiki/Research-on-Incremental-Games)

### Egg Inc.

**3D but relevant for offline-cap design.**

- Hard offline cap (2 hours) — forces active engagement.
- Sub-prestige loop with ~5× multiplier tiers.
- Discussed in [Math of Idle Games Part III](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-iii).

---

## 12. Tools, Spreadsheets & Libraries

### Spreadsheets & talks

| Resource | URL |
|----------|-----|
| Pecorella idle math spreadsheets | [kon.gg/idle-math-spreadsheets](http://kon.gg/idle-math-spreadsheets) |
| GDC Quest for Progress slides (PDF) | [GDC Vault PDF](https://media.gdcvault.com/gdceurope2016/presentations/Pecorella_Anthony_Quest%20for%20Progress.pdf) |
| Math of Idle Games Part I | [Game Developer](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-i) |
| Math of Idle Games Part II | [Game Developer](https://www.gamedeveloper.com/game-platforms/the-math-of-idle-games-part-ii) |
| Math of Idle Games Part III | [Game Developer](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-iii) |

### Balance & prototyping tools

- [Idle Game Generator](https://idlegamegenerator.toolpile.dev/) — Full balance model with Godot export.
- [Game Incremental Growth Calculator](https://randomgamegenerator.com/game-incremental-growth-calculator/)
- [Simple Idle Forge](https://livingfailure93.github.io/Simple-IDLE-Forge-Docs/) — Unity toolkit documenting generator/prestige/achievement pipelines.

### Code libraries & engines

- [clicker-engine (TypeScript)](https://github.com/blixxurd/clicker-engine)
- [break_infinity.js](https://github.com/Patashu/break_infinity.js/)
- [break_eternity.js](https://github.com/Patashu/break_eternity.js/)
- [Eternal Notations](https://github.com/MathCookie17/Eternal-Notations)
- [IdleKit (Unity)](http://docs.idlekit.io/) — Offline activity, activity tracking service.

### Community & databases

- [r/incremental_games](https://www.reddit.com/r/incremental_games/)
- [IncrementalDB](https://www.incrementaldb.com/) — Game database and developer interviews.
- [Kongregate idle games tag](https://www.kongregate.com/idle-games)

---

## 13. Godot-Specific Notes

This project is a [Godot 4 2D template](../README.md). Key integration points:

### Game loop in Godot

Use `_process(delta)` for economy ticks:

```gdscript
func _process(delta: float) -> void:
    if not paused:
        currency += production_rate * delta
        tick_accumulator += delta
        if tick_accumulator >= 1.0:
            _on_second_tick()
            tick_accumulator -= 1.0
```

References:

- [Idle and Physics Processing — Godot docs](https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html)
- [Idle Game Tutorial in Godot — Part 2: Automation (YouTube)](https://www.youtube.com/watch?v=a5wN-41NgqY)

### `_process` vs `_physics_process`

| Callback | Rate | Use for |
|----------|------|---------|
| `_process(delta)` | Variable (frame rate) | Economy, UI, click detection |
| `_physics_process(delta)` | Fixed 60 Hz | Physics bodies, deterministic simulation |

For strict deterministic idle sim, implement accumulator pattern inside `_process` or use a dedicated `Timer` node with `process_callback = PROCESS_MODE_PHYSICS`.

### Architecture suggestions for Godot

```
res://
├── autoload/
│   ├── GameState.gd      # Resources, generators, flags (single source of truth)
│   ├── SaveManager.gd    # Serialize / deserialize / offline catch-up
│   └── EventBus.gd       # Signals: currency_changed, upgrade_purchased
├── scripts/
│   ├── economy/
│   │   ├── Generator.gd
│   │   ├── Upgrade.gd
│   │   └── Prestige.gd
│   └── util/
│       └── BigNumber.gd
└── scenes/
    ├── Main.tscn
    ├── ui/HUD.tscn
    └── ui/ShopPanel.tscn
```

### Godot docs & tutorials

- [Godot 4 documentation](https://docs.godotengine.org/en/stable/)
- [GDScript reference](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)
- [2D game tutorials](https://docs.godotengine.org/en/stable/tutorials/2d/index.html)
- [CPUParticles2D](https://docs.godotengine.org/en/stable/classes/class_cpuparticles2d.html) — Click burst effects.
- [Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html) — Scale pulse, floating text.

### Precision warning

Avoid `float` for accumulated currency. Use `int` for core counts or a custom big-number type. See [gd-agentic-skills game loop harvest reference](https://github.com/thedivergentai/gd-agentic-skills/blob/HEAD/skills/godot-master/references/game-loop-harvest.md).

---

## 14. Design Checklist

### Pre-production

- [ ] Define core fantasy and theme.
- [ ] Choose growth model (exponential chain vs derivative chain).
- [ ] Sketch 3–5 generator tiers with base costs and growth rates.
- [ ] Plan prestige layer(s) and reset rules.
- [ ] Build spreadsheet simulation (10+ prestiges).

### Core loop

- [ ] Currency earns passively via `_process` or fixed tick.
- [ ] Manual click source exists for early game.
- [ ] At least 3 milestone bonus tiers per generator.
- [ ] Bulk-buy supported with correct cost formula.
- [ ] Production rate cached; recalculated on change only.

### Pacing targets

- [ ] First meaningful upgrade: 2–5 minutes.
- [ ] Three feedback loops unlocked within 10 minutes.
- [ ] First prestige: 30–120 minutes.
- [ ] Second run 40–60% faster than first.

### Retention

- [ ] Offline progress with cap and welcome-back screen.
- [ ] At least one active mechanic per session.
- [ ] Achievements with small permanent rewards.
- [ ] Visible per-second rate counter.

### 2D polish

- [ ] Click feedback < 100ms (scale + particles + sound).
- [ ] Number abbreviation for large values.
- [ ] Affordable upgrades visually highlighted.
- [ ] Ambient animation so screen feels alive.

### Technical

- [ ] Versioned save format with migration.
- [ ] Autosave on interval and pause.
- [ ] Export/import save option.
- [ ] Big-number strategy decided before 1e15.

---

## 15. Full Link Index

### Design & theory

- [Numbers Getting Bigger (Envato Tuts+)](https://code.tutsplus.com/numbers-getting-bigger-the-design-and-math-of-incremental-games--cms-24023a)
- [How to design idle games (Machinations)](https://machinations.io/articles/idle-games-and-how-to-design-them)
- [Idle Game Design Explained (Solana Garden)](https://solana.garden/guides/game-idle-game-design-explained/)
- [Quest for Progress (Kongregate)](https://www.kongregate.com/pages/quest-for-progress-the-math-of-idle-games)
- [Quest for Progress GDC PDF](https://media.gdcvault.com/gdceurope2016/presentations/Pecorella_Anthony_Quest%20for%20Progress.pdf)
- [Clicker Games Architecture (Medium)](https://medium.com/@tommcfly2025/clicker-games-a-technical-exploration-of-incremental-system-architecture-b6d842e6963e)
- [Learn App Architecture Through Clicker Games (Zap Code)](https://www.zapcode.dev/learn/clicker-idle-games-with-app-architecture)
- [Research on Incremental Games (GitHub Wiki)](https://github-wiki-see.page/m/brandoncimino/fortune-fountain-g/wiki/Research-on-Incremental-Games)
- [Calculus in Incremental Game Mechanics](https://howard-2718.github.io/section-1.html)
- [What makes a good tech tree? (GameDev SE)](https://gamedev.stackexchange.com/questions/164987/what-makes-a-good-tech-tree)
- [Technology design for Emergence](https://leafwing-studios.github.io/Emergence/research/technology.html)
- [Technology Trees thesis (Tampere)](https://trepo.tuni.fi/handle/10024/113957)
- [Tech Tree (TV Tropes)](https://tvtropes.org/pmwiki/pmwiki.php/Main/TechTree)
- [Hevipelle interview (IncrementalDB)](https://www.incrementaldb.com/community/interview/31)

### Math series (Anthony Pecorella)

- [Part I — Growth, cost, prestige, generators](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-i)
- [Part II — Derivative-based growth](https://www.gamedeveloper.com/game-platforms/the-math-of-idle-games-part-ii)
- [Part III — Prestige loops](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-iii)
- [Kongregate mirror Part I](https://www.kongregate.com/pages/the-math-of-idle-games-part-i)
- [Kongregate mirror Part III](https://www.kongregate.com/en/pages/the-math-of-idle-games-part-iii)
- [Idle math spreadsheets](http://kon.gg/idle-math-spreadsheets)

### Game loop & architecture

- [Idle game loop gist (HipHopHuman)](https://gist.github.com/HipHopHuman/3e9b4a94b30ac9387d9a99ef2d29eb1a)
- [Idler Game Loop (Sam Hogarth)](https://samhogy.co.uk/2025/06/idler-game-loop/)
- [Fixed Timestep (André Leite)](https://andreleite.com/posts/2025/game-loop/fixed-timestep-game-loop/)
- [Fix Your Timestep (Gaffer on Games)](http://gafferongames.com/game-physics/fix-your-timestep/)
- [clicker-engine (GitHub)](https://github.com/blixxurd/clicker-engine)
- [cookieclicker reimplementation (GitHub)](https://github.com/vardst/cookieclicker)
- [IdleKit docs](http://docs.idlekit.io/)
- [Simple Idle Forge docs](https://livingfailure93.github.io/Simple-IDLE-Forge-Docs/)

### Cookie Clicker

- [Cookie Clicker Wiki](https://cookieclicker.wiki.gg/)
- [Ascension wiki](https://cookieclicker.wiki.gg/wiki/Ascension)
- [Golden Cookie wiki](https://cookieclicker.wiki.gg/wiki/Golden_Cookie)
- [Spawning mechanism wiki](https://cookieclicker.wiki.gg/wiki/Spawning_mechanism)
- [Heavenly Chips (Fandom)](https://cookieclicker.fandom.com/wiki/Heavenly_Chips)
- [When to ascend (Radio Times)](https://www.radiotimes.com/technology/gaming/cookie-clicker-when-to-ascend/)
- [Prestige mechanics (Arqade)](https://gaming.stackexchange.com/questions/130939/how-does-the-prestige-system-work-when-soft-resetting)
- [Golden Cookie mechanics (Arqade)](https://gaming.stackexchange.com/questions/130256/how-do-golden-cookies-work)
- [Orteil's site](https://orteil.dashnet.org/)

### Case studies & reviews

- [Antimatter Dimensions review (Jérémie Tessier)](http://www.jeremietessier.com/reviews/2023/2/8/i-look-at-antimatter-dimensions)
- [Antimatter Dimensions (Grokipedia)](https://grokipedia.com/page/Antimatter_Dimensions)
- [Derivative Clicker (Kongregate)](https://www.kongregate.com/games/orevolos/derivative-clicker)

### Balancing tools

- [Idle Game Generator](https://idlegamegenerator.toolpile.dev/)
- [Incremental Growth Calculator](https://randomgamegenerator.com/game-incremental-growth-calculator/)
- [Game Prestige Calculator](https://randomgamegenerator.com/game-prestige-calculator/)
- [Game Reset Bonus Calculator](https://randomgamegenerator.com/game-reset-bonus-calculator/)

### Big numbers

- [break_infinity.js](https://github.com/Patashu/break_infinity.js/)
- [break_eternity.js](https://github.com/Patashu/break_eternity.js/)
- [BreakInfinity.cs](https://github.com/Razenpok/BreakInfinity.cs/)
- [decimal.js](https://github.com/MikeMcl/decimal.js/)
- [Eternal Notations (GitHub)](https://github.com/MathCookie17/Eternal-Notations)
- [Eternal Notations demo](https://mathcookie17.github.io/Eternal-Notations/index.html)
- [AD Notations](https://github.com/antimatter-dimensions/notations)

### 2D UI & feel

- [Clicker Game UI (SEELE)](https://www.seeles.ai/resources/blogs/scratch-clicker-game-ui)
- [Phaser Idle Clicker Tutorial](https://generalistprogrammer.com/tutorials/phaser-idle-clicker-tutorial)
- [Telegram Clicker UI patterns](https://vp0.com/blogs/telegram-clicker-game-ui-clone)
- [Canvas particle optimizations (Elliott Programmer)](https://blog.elliottprogrammer.com/4-performance-optimizations-that-made-my-canvas-particle-animation-butter-smooth/)
- [Particle Systems tutorial (Lumitree)](https://lumitree.art/blog/particle-system)

### Offline progress

- [Welcome Back mechanic (Edvins Antonovs)](https://edvins.io/rebuilding-the-welcome-back-mechanic-from-idle-games-in-react)
- [IdleKit Offline Activity](https://docs.idlekit.io/2.1.1/manual/concepts/activitytrackingservice/)

### Godot

- [Godot 4 docs](https://docs.godotengine.org/en/stable/)
- [Idle and Physics Processing](https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html)
- [GDScript tutorials](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)
- [2D tutorials](https://docs.godotengine.org/en/stable/tutorials/2d/index.html)
- [CPUParticles2D](https://docs.godotengine.org/en/stable/classes/class_cpuparticles2d.html)
- [Tween class](https://docs.godotengine.org/en/stable/classes/class_tween.html)
- [Godot idle tutorial YouTube](https://www.youtube.com/watch?v=a5wN-41NgqY)
- [GD Agentic Skills — game loop](https://github.com/thedivergentai/gd-agentic-skills/blob/HEAD/skills/godot-master/references/game-loop-harvest.md)

### Community

- [r/incremental_games](https://www.reddit.com/r/incremental_games/)
- [IncrementalDB](https://www.incrementaldb.com/)
- [Kongregate idle games](https://www.kongregate.com/idle-games)

---

*Document compiled for the 2D Game Template (Godot 4) project. Last updated: June 2026.*
