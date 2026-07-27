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

---

## Reference-project engine migration (Godot 3.x → 4.6.1)

Applied to the imported Fire Emblem reference clone under `engine/scenes/assets` on branch `reference_project`. Not game-design decisions — recorded here as the audit trail for the conversion. Date: 2026-07-26/27.

### M1 — Converted via Godot's built-in `--convert-3to4`, then hand-fixed residuals
Ran `Godot_v4.6.1 --convert-3to4` (683 files) for the mechanical bulk (scene format, `Sprite→Sprite2D`, `KinematicBody2D→CharacterBody2D`, `yield→await`, `connect()` signatures, `instance()→instantiate()`, `Texture→Texture2D`). Everything the converter could not do was fixed by hand.

### M2 — Reconstructed `project.godot` from code analysis
The original Godot-3 `project.godot` (autoloads/main-scene/input map) was gone from git history. Reconstructed by static analysis of bare-name global usage:
- **Autoloads:** `Calculators`, `Combat_Calculator` (scripts); `BattlefieldInfo`→`game_system.tscn`, `SceneTransition`, `Convoy`→`convoy_canvas_layer.tscn`, `WorldMapScreen`, `StatusScreen` (scenes). Detected as identifiers used project-wide with no `class_name`/local declaration.
- **Main scene:** `scenes/intro_screen/Intro Screen.tscn` (entry title screen; transitions to WorldMapScreen).
- **Input actions:** `start_battle`, `exit_game`, `L button`, `R button`, `highlight_enemy`, `debug`, `show_coord_debug`. Original key bindings were lost, so sensible defaults were assigned (Enter/Escape/Q/E/Tab/F1/F2); rebind in-editor as needed.

### M3 — Missing `FE Icon.jpg` / `icon.png` → `icon.svg`
Referenced by ~11 scenes as a placeholder texture but never existed on disk (not in git history). Pointed at the existing `res://icon.svg`.

### M4 — Godot-4 API fixes the converter missed
`File.new()/File.READ|WRITE` → `FileAccess` (save/load, event parser); `ItemList.get_v_scroll()` → `get_v_scroll_bar()`; float `%` (play-time display) → `int()` first; `match` pattern `"A" \|\| "B"` → `"A", "B"`; `const all_items` → `static var` (Godot-4 const collections are immutable but the dict is mutated at runtime).

### M5 — Converter mis-conversions reverted
The regex converter corrupted several string literals: `.start("1","title",lvl,2)` was reshaped into a bogus `Callable(...).bind(...)` (4 world-map event files); `.format(...)` on a line-continued string became `super.format(...)` (Cell.gd); and asset filenames inside resource paths were renamed (`Light Foot Steps`→`Light3D Foot Steps`, `Miss Sprite`→`Miss Sprite2D`, `Rain Noise Texture`→`Rain Noise Texture2D`). All reverted to originals.

### M6 — Tween node → `TweenCompat` shim (`engine/systems/tween_compat.gd`)
Godot 4 removed the `Tween` scene node; cutscene/world-map code drives sequencing off its `interpolate_property`/`start`/`tween_completed`/`tween_all_completed` API across 15+ callers. Rather than refactor every caller, a small `Node` shim reproduces exactly that API on top of `create_tween()`. The 5 old `Tween` nodes (camera, music player, world map) were retyped to `Node` + this script; callers are unchanged.

### M7 — Unit subclasses now call `super._ready()` (FIXED)
Unit subclasses (e.g. `Eirika.gd`) overrode `_ready()` without `super._ready()`, so `Battlefield_Unit`'s init (which creates `UnitStats`/`UnitInventory`/`UnitMovementStats`/`UnitActionStatus`) never ran — `UnitStats` was null in the unit's own `_ready` (startup errors via Unit Picker Solo's test block). Added `super._ready()` as the first line of `_ready()` in all 15 `Battlefield_Unit` subclasses (6 enemy + 9 ally). This is the pattern the code intended: subclass `_ready` bodies use the stat objects the base creates.

### M8 — GDScript warning cleanup + one latent bug
Cleared the reported warnings without behaviour change: shadowed params renamed (`text_queue`→`new_text_queue`, `battlefield`→`p_battlefield`, `Unit_Movement` param→`move_stats`); unused params/vars underscore-prefixed (`_anim_name`, `_unit`/`_tile`, `_AllTiles`, `_h`); dead `signal unit_became_done` and a no-effect `$EnemyLevel.volume_db` line removed. One real latent bug fixed in `unit_movement_system.gd:86`: `current_animation == "Idle"` (comparison, no effect) → `= "Idle"` (the intended assignment).

### M9 — Title screen made playable
Three issues stopped the game past the title:
- **Stray "water" texture, offset lower-right:** the `WorldMapScreen` autoload (a `Node2D` full of sea/terrain sprites) defaulted to `visible = true` and its `World Map Cam` (`Camera2D`) defaulted to enabled, so at startup the world map rendered and its camera scrolled the viewport (displacing the title's `Fog` particles toward a corner). Fix: `WorldMapScreen._ready()` now sets `visible = false` and `$"World Map Cam".enabled = false`; `start()` still turns both on when the map is actually shown.
- **Couldn't get past the title:** "New Game" called `SceneTransition.change_scene_to_packed(WorldMapScreen, ...)`, but `WorldMapScreen` is a persistent autoload node, not a `PackedScene`, so the underlying `get_tree().change_scene_to_packed(node)` failed. Rewrote that method to retire the outgoing scene (`current_scene.queue_free()`, `current_scene = null`) and emit `scene_changed`, which drives `WorldMapScreen.start()` — the intended "show the persistent world map" behaviour. Verified via a temporary headless input-injection harness: title → keypress → GAME_SELECT → New Game → world map shown, intro freed.
- **`Camera2D.current` removed in Godot 4:** 12 `<camera>.current = true/false` sites (converter missed them — dynamic `$node`/`BattlefieldInfo.main_game_camera` accesses) → `.enabled`.

### M10 — GDScript warning cleanup (batch 2)
Unused `_input(event)` params → `_event` (convoy, Unit Picker Solo, Unit Inventory Display, Yes No Box, Yes No Box Generic); unused tween-callback params `object`/`key` → `_object`/`_key` (`set_eirika_idle`, `after_camera_move`, `after_eirika_move`); shadowed params renamed (`next_list`→`to_activate`, `convoy`→`p_convoy`); `Status Screen._process(delta)`→`_delta`; intended integer division annotated with `@warning_ignore("integer_division")`.
