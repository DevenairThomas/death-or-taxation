# DECISIONS — DEATH OR TAXATION (gray-box prototype)

Log of spec-silent technical decisions. Each entry: the choice, and why it does not contradict the locked spec. `⚠ TODO` marks items that still need work or expansion.

---

## Data & architecture

### D1 — JSON for all data
All game data (units, terrain, damage table, generals, abilities, maps, scenes, economy) lives in JSON files under `/data`, loaded by a single `DataLoader`. Chosen over Godot `Resource`/`.tres` so `/sim` stays free of `ResourceLoader`/editor coupling and is headless-test friendly. One format everywhere — no mixing.

### D2 — Sim purity
`/sim` classes extend `RefCounted` only. No `Node`, `SceneTree`, or `get_node`. `AStarGrid2D` is a `RefCounted` `Object` (not a `Node`), so it is legal inside sim. Enforced by keeping the view in `/scenes` + `/ui`.

### D3 — Forecast/resolution identity
`Skirmish.forecast(...)` returns a `SkirmishResult`; `Skirmish.resolve(...)` calls `forecast()` then applies it. The forecast popup and the resolved skirmish call the same function, so they cannot diverge (quality-bar requirement).

### D4 — No RNG in sim
No `randi`/`randf` anywhere in `/sim`. A test greps `/sim` sources for RNG usage and fails if found. Enforces the deterministic-combat rule mechanically.

### D5 — Sim→View via signals
A single `BattleSim` `RefCounted` defines the signal surface; the view connects and the sim never references the view. Signal contract below.

### D6 — Tests via headless runner
Plain headless runner (`tests/run_tests.gd`) executed with `godot --headless --script`. No GUT dependency ("no plugins"), one command, zero setup.

---

## Combat math

### D7 — Damage formula (single source of truth)
```
base  = damage_table[attacker.damage_type][defender.damage_type]
base *= attacker.power_mult            # general level package; 1.0 for squads/singles
base *= ability modifiers              # e.g. command_aura x1.20, multiplicative, pre-floor
hp_f  = attacker.hp / attacker.max_hp  if tier == squad else 1.0
terr  = 1.0 - terrain[defender.tile].defense
dmg   = floor(base * hp_f * terr)
dmg   = max(dmg, MIN_DAMAGE)           # MIN_DAMAGE = 1
```
Verified vs. the three locked worked examples: `6x0.7x0.8=3.36 -> 3`; `2x0.1x0.6=0.12 -> 0 -> 1`; `8x1.0x1.0=8`.

### D8 — Squad degradation uses current/max HP
HP-degradation factor is `current_hp / max_hp`, exactly as the worked examples imply. Only `tier == squad` degrades; singles and generals use `1.0`.

### D9 — Counterattack uses post-damage HP
The counter fires only if the defender survives the initial hit, the attacker's tile range is within the defender's `counter_ranges`, and the counter's degradation factor uses the defender's HP *after* taking damage.

### D10 — Ability damage modifiers
Multiplicative, applied to `base` pre-floor, in data-declared order. Keeps the formula a single ordered pipeline.

### D11 — Cannon Crew "no counter at range 1"
Modeled generically as `counter_ranges` on the unit def. Cannon Crew = `[2,3]`; melee = `[1]`. No special-case code.

---

## Generals & progression

### D12 — `power_mult` is the level stat package
Levels 1/2/4 grant a `power_mult` (and small `hp_bonus`) that multiplies the table value pre-floor — the spec's "+15–20% effective power." Levels 3/5 grant an ability instead of a stat bump, and set a character-scene flag.

### D13 — Generals do not degrade
Generals use `tier:"general"` => no HP-degradation multiplier ("static per level, grows via EXP"). ⚠ TODO — confirm generals need any mechanical presence distinct from singles beyond damage type + `power_mult` + abilities; currently identical to a single otherwise.

### D14 — General damage types share archetype rows
**RECOMMENDED, NEEDS CONFIRMATION.** Generals share archetype rows/columns in the damage table (Washington→`heavy_melee`, Franklin→`arcane_ranged`, Lafayette→`cavalry`) rather than each having a unique row. Yields a ~7x7 matrix instead of 10x10; `power_mult` does per-general individuation; adding General #4 stays data-only. ⚠ TODO — decision pending; if rejected, each general needs its own row/column and the matrix grows.

---

## Turn & unit rules

### D15 — One action per unit per turn
Each unit may move+attack, move only, or attack only — one activation per turn (FE standard). Spec is silent.

### D16 — Phase-based turn order
All player units act, then all enemy units (AW/FE phase model), not per-unit initiative. Spec is silent.

---

## Terrain

### D17 — `bridge` terrain type added
Spec says "River (impassable except bridges)" but lists no bridge tile. Added a `bridge` type (passable, cost 1, def 0) so river crossings can exist. River itself is `passable:false`.

### D18 — `infantry_only` via `move_class`
Mountain is `infantry_only`. Units carry a `move_class` (`infantry|mounted|siege|construct`); only `infantry` may enter `infantry_only` terrain. ⚠ TODO — confirm which prototype units count as "infantry-type" for mountain access (Cavalry, Cannon, Death Knight, constructs presumably excluded).

---

## Signal contract (BattleSim)

```
battle_started(state_snapshot)
turn_changed(faction, turn_number)
unit_spawned(unit_id)
unit_moved(unit_id, path)
unit_damaged(unit_id, amount, new_hp, source_unit_id)
unit_destroyed(unit_id, faction, was_general)
skirmish_resolved(result)              # same payload as forecast
ability_triggered(unit_id, ability_id, affected_ids)
unit_activated(unit_id)                # AI dormancy broken
objective_progress(text)
mission_complete(victory, summary)     # turns, squads_lost, champion_killed
```
Attack emission order: `unit_moved` -> `unit_damaged`(defender) -> [`unit_destroyed`] -> [`unit_damaged`(attacker counter)] -> [`unit_destroyed`] -> `skirmish_resolved`.

View→Sim is method calls returning a validity result (never asserts on bad input): `get_reachable`, `get_attackable`, `forecast`, `command_move_attack`, `command_wait`, `command_ability`, `end_turn`.

---

## Open items to resolve before/during implementation

- ⚠ **D14** — confirm archetype-shared vs. per-general damage rows (recommended: shared).
- ⚠ **D13** — confirm generals need any presence distinct from singles beyond damage type.
- ⚠ **D18** — confirm mountain-access unit list.
- ⚠ Ability trigger taxonomy (`passive_aura | turn_start | on_attack | active_once`) must cover all 6 prototype abilities; verify each maps cleanly before coding the ability system (Milestone 5/6).
- ⚠ Map JSON `legend`/`tiles` ASCII-grid format is provisional; validate it round-trips through `DataLoader` on the first real map (Milestone 1).
