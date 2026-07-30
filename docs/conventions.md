# CONVENTIONS — DEATH OR TAXATION

**Version 1.0 · Locked**

This document is the mechanical rulebook for the codebase. `design_doc.md` says *what the game is*; this says *how the repo is written*. Where the two disagree, `design_doc.md` wins on design and this document wins on structure.

The purpose of freezing these rules now is that every one of them is expensive to retrofit. A naming rule applied on day one costs nothing; applied in month six it is a repo-wide rename. Treat every rule here as non-negotiable unless it is amended here first.

---

## 1. Naming

Godot's own style guide is followed, with no local deviations. The single guiding sentence: **PascalCase for types and scene nodes, snake_case for everything else, SCREAMING_SNAKE_CASE for constants.**

| Thing | Case | Example |
| --- | --- | --- |
| Folders | snake_case | `sim/`, `ui/forecast_popup/` |
| Script files | snake_case | `skirmish_resolver.gd` |
| Scene files | snake_case | `battle_view.tscn` |
| Data files | snake_case | `damage_table.json` |
| `class_name` | PascalCase | `class_name SkirmishResolver` |
| Node names inside a scene | PascalCase | `BattleView`, `ForecastPopup`, `HpLabel` |
| Functions | snake_case | `func get_reachable_tiles()` |
| Variables | snake_case | `var current_hp` |
| Private members (functions and vars) | `_snake_case` | `var _dirty_tiles`, `func _rebuild_cache()` |
| Constants | SCREAMING_SNAKE_CASE | `const MIN_DAMAGE := 1` |
| Enum type | PascalCase | `enum Tier` |
| Enum values | SCREAMING_SNAKE_CASE | `enum Tier { SQUAD, SINGLE, GENERAL }` |
| Signals | snake_case, past tense | `signal unit_destroyed(unit_id)` |
| Data keys (JSON) | snake_case | `"move_class": "infantry"` |
| Localization keys | snake_case, dot-scoped | `ui.battle.end_turn` |
| Test files | `test_` prefix | `test_skirmish_damage.gd` |

Additional naming rules:

- **A script file's name matches its `class_name` in snake_case.** `class_name SkirmishResolver` lives in `skirmish_resolver.gd`. This is the only reliable way to find a class by filename.
- **A scene's root node name matches the scene filename in PascalCase**, and its script matches in snake_case. `battle_view.tscn` → root node `BattleView` → script `battle_view.gd`.
- **Signals are past-tense statements of fact, never handler names.** `unit_destroyed`, not `on_unit_death` or `destroy_unit`. The handler that receives it is `_on_unit_destroyed`.
- **Booleans read as assertions.** `is_active`, `has_moved`, `can_counter` — not `active`, `moved`, `counter`.
- **No abbreviations** except the universally understood ones: `id`, `hp`, `ui`, `ai`, `vn`, `hq`. Write `damage`, not `dmg`; `position`, not `pos`.
- **Never name a variable the same as a type.** With PascalCase types this is automatic; do not defeat it by writing `var Unit`.

---

## 2. GDScript style

**Static typing is mandatory.** Every variable, parameter, and return type is annotated. Use `:=` for inferred locals where the type is obvious from the right-hand side, explicit `: Type` everywhere else. Untyped code does not pass review.

```gdscript
func forecast(attacker: SimUnit, defender: SimUnit, from_tile: Vector2i) -> SkirmishResult:
```

**Declaration order inside every script**, top to bottom, no exceptions:

1. `class_name`
2. `extends`
3. File docstring (`##` comment block explaining what this class is for)
4. `signal` declarations
5. `enum` declarations
6. `const` declarations
7. `@export` variables
8. Public variables
9. Private variables (`_`-prefixed)
10. `@onready` variables
11. `_init()`
12. `_ready()`, then other Godot virtuals (`_process`, `_input`, …)
13. Public methods
14. Private methods (`_`-prefixed)

**Docstrings.** Every class and every public function carries a `##` docstring. One line is enough if one line is honest. Private helpers need one only when the name does not fully explain them.

**No magic numbers.** Every literal that is not `0`, `1`, or a loop bound is either a named `const` or a field in a `/data` file. If a number affects game balance, it belongs in `/data`, not in a `const`. If it affects layout or engine behaviour, a `const` is fine.

**No dead code.** No commented-out blocks, no unreachable branches, no functions that only `pass`. A stub that is not yet implemented is either absent or raises loudly — never a silent no-op presented as working. If a menu option is not implemented, the option is not in the menu.

**Node access.** Inside a scene, use typed `@onready var` references with `%UniqueName` or a short `$Path`. Never reach outside your own scene with `get_parent()`, and never chain more than one `get_parent()`. Cross-scene communication is by signal upward and method call downward, never by tree walking.

**Prefer composition over inheritance.** Inheritance is for genuine engine specialization (`extends Control`, `extends RefCounted`) and for a small number of deliberate base classes. It is never used to express content differences. There will be no `LineInfantry extends Squad` — a Line Infantry squad is a row in `units.json`.

---

## 3. Architecture rules

These five rules are the whole architecture. They exist because the reference project violated all five and became untestable.

**R1 — `/sim` is pure.** Everything in `/sim` extends `RefCounted` (or `Object`) and nothing else. No `Node`, no `SceneTree`, no `get_node`, no `await get_tree()`, no `load()`, no `print` to signal state. `AStarGrid2D` is permitted because it is a `RefCounted`, not a `Node`. The test suite must be able to run the entire battle simulation headlessly with no scene tree in existence.

**R2 — no RNG in `/sim`, ever.** No `randi`, `randf`, `randomize`, `shuffle`, `pick_random`. Combat and progression are deterministic by design. A test greps `/sim` for these tokens and fails the build if any appear.

**R3 — the view holds no rules.** `/scenes` and `/ui` render sim state and forward player intent. They do not compute damage, decide legality, mutate campaign state, or own authoritative numbers. If a widget needs to know something, it asks the sim; if it needs to change something, it calls a sim command. A view file containing arithmetic on game numbers is a bug.

**R4 — sim → view by signal, view → sim by method call.** The sim never holds a reference to a view object and never emits into a specific listener. The view connects to sim signals. Commands return a validity result; they never assert or crash on bad input, because input comes from a player.

**R5 — one source of truth per rule.** The most important instance: a single function computes a skirmish, and both the damage forecast and the resolved combat call it. They cannot diverge because there is only one of them. This generalizes — no rule is implemented twice anywhere in the codebase, and no number is stored in two places.

Supporting rules:

- **No god objects and no service locators.** There is no `GameInfo` autoload holding sixty references. Dependencies are passed in constructors or exported in the editor.
- **Autoloads are a short, deliberate, documented list.** Permitted: `data_loader`, `save_manager`, `settings_manager`, `audio_manager`, `scene_router`. Adding a sixth requires a written justification in `DECISIONS.md`. Autoloads hold no gameplay rules.
- **Content is data, never code.** Adding a unit type, map, General, ability, chapter, or cutscene must require zero new `.gd` files and zero edits to existing ones. If adding content means writing code, the system is wrong.
- **Everything is loaded through one loader.** `/sim` never touches the filesystem. `data_loader` reads `/data` and hands plain dictionaries or typed sim objects to whoever asks.

---

## 4. Folder layout

The organizing principle is **co-location**: a feature's scene, its script, and its feature-local assets live in one folder, so working on a feature means opening one directory. Shared assets live in `/assets`. The layout below is optimized for a human opening the repo cold and finding things.

```
res://
├─ sim/                      pure logic — RefCounted only, headless-testable
│  ├─ grid/                  tiles, terrain lookup, pathfinding, range queries
│  ├─ combat/                skirmish resolver, damage pipeline, forecast
│  ├─ units/                 sim unit state, tiers, armament, abilities
│  ├─ ai/                    dormancy, target scoring, decision output
│  ├─ mission/              objectives, win/lose evaluation, turn order
│  ├─ campaign/              souls, general roster, chapter unlocks, budget
│  └─ battle_sim.gd          the single signal surface + command surface
│
├─ data/                     JSON only — no code, no logic
│  ├─ combat/                damage_table.json, armament_triangle.json, terrain.json
│  ├─ units/                 squads.json, singles.json
│  ├─ generals/              one file per General
│  ├─ abilities/             abilities.json
│  ├─ maps/                  one file per battle map
│  ├─ chapters/              campaign graph + per-chapter definitions
│  ├─ scenes/                VN cutscene timelines
│  └─ economy.json           budgets, level costs, revival rate, soul awards
│
├─ scenes/                   the view — renders sim, forwards input
│  ├─ battle/                battle_view.tscn + camera, cursor, overlays, unit views
│  ├─ vn/                    vn_player.tscn — the one cutscene player
│  ├─ campaign_map/          chapter select over the colonies map
│  ├─ camp/                  between-mission hub
│  └─ boot/                  title, mode select, scene_router entry
│
├─ ui/                       reusable widgets, no game rules
│  ├─ list_menu/             the one list picker used by every menu
│  ├─ forecast_popup/
│  ├─ hud/
│  ├─ deployment/
│  ├─ roster/
│  └─ settings/
│
├─ systems/                  autoloads
│  ├─ data_loader.gd
│  ├─ save_manager.gd
│  ├─ settings_manager.gd
│  ├─ audio_manager.gd
│  └─ scene_router.gd
│
├─ assets/                   shared art, audio, fonts
│  ├─ art/{portraits,units,terrain,ui,backgrounds}
│  ├─ audio/{music,sfx}
│  └─ fonts/
│
├─ locale/                   translation CSVs + generated .translation
├─ tests/                    run_tests.gd + test_*.gd
├─ docs/                     design_doc.md, conventions.md, DECISIONS.md
└─ reference/                READ-ONLY. The Fire Emblem reference clone. Never imported.
```

Folder rules:

- **`/reference` is read-only and never referenced from game code.** No `res://reference/...` path appears anywhere outside `/reference`. It is documentation that happens to compile.
- **Nothing in `/data` contains logic.** No expressions, no script paths that get executed, no conditionals. Data describes; code decides.
- **No folder exceeds roughly fifteen files.** Past that, it wants a subfolder. This is a human-navigability rule, not a technical one.
- **Feature-local assets live with the feature.** A placeholder texture used only by the forecast popup lives in `ui/forecast_popup/`. Anything used by two features moves to `/assets`.

---

## 5. Data conventions

**Format: JSON, everywhere, no exceptions.** Chosen over `.tres` so `/sim` never touches `ResourceLoader` and stays headless. Mixing formats is worse than either format.

- Every entity has a stable string `id` in snake_case (`line_infantry`, `washington`, `bunker_hill`). Ids are permanent — renaming one breaks saves.
- Cross-references are by `id`, never by array index, filename, or display name.
- **No display text in data files.** Data holds a localization key; `/locale` holds the words. `"name_key": "unit.line_infantry.name"`.
- Numbers are numbers. `0.2`, not `"0.2"`. Percentages are stored as multipliers (`0.8`), not integers (`80`).
- One file per entity where entities are large and hand-authored (Generals, maps, cutscenes). One file per domain where entries are short and compared side by side (units, terrain, abilities, economy). Tables that must be read as a grid (the damage table, the armament triangle) are single files.
- Every data file the loader reads is validated on load: required keys present, ids unique, cross-references resolve. Validation failure is a loud error naming the file and the key, not a silent default.

---

## 6. Localization

Every user-visible string goes through `tr()` from the first line of UI written. Retrofitting this is a full pass over every scene.

- Key scheme: `domain.subject.field` — `ui.settings.fullscreen`, `general.washington.name`, `chapter.saratoga.title`, `scene.l1_intro.line_03`.
- **Never concatenate translated strings.** Use `tr("ui.souls_count").format({"count": n})` with named placeholders. Word order differs between languages.
- **Never position UI with pixel offsets.** Containers and anchors only. German runs ~40% longer than English and will break any hand-placed layout. The reference project's `+= 18` cursor arithmetic is the exact anti-pattern.
- Every `Label` and `Button` must survive a string three times its English length without clipping the layout. Test this with a pseudo-locale before shipping any screen.
- Font choice must cover the target locale set. Latin + Latin Extended + Cyrillic is one font stack; CJK is a separate decision with separate metrics, made deliberately or not at all.

---

## 7. Saves and user files

- **All writes go to `user://`. Never `res://`.** `res://` is read-only in an exported build; a save system that writes there works in the editor and silently fails for every player. The reference project has this bug.
- Two files, separate concerns: campaign meta save, and settings. A mid-mission suspend, if built, is a third.
- Every save file's first key is `schema_version` (integer). A migration function exists from version 1 onward, even when it is a no-op, because writing it later means guessing at old formats.
- Saves are serialized from `/sim` data structures directly. Never by walking the scene tree, never by asking nodes to serialize themselves.
- A corrupt or unreadable save produces a clear message and a safe state, never a crash.

---

## 8. Testing

- Runner: `godot --headless --script res://tests/run_tests.gd`. Plain GDScript, no plugin dependency, one command, zero setup.
- **New logic in `/sim` requires new tests in the same commit.** This is the only hard gate.
- Tests are assertion-based. A script that prints output for a human to eyeball is not a test.
- Required permanent tests: the worked damage examples from `design_doc.md` §3, the minimum-damage rule, the armament triangle at every matchup, squad HP degradation, singles and Generals not degrading, counterattack conditions, objective evaluation for each objective type, AI target selection on a fixed board with an asserted exact choice, the soul level-cost table, revival pricing, and the RNG grep of `/sim`.
- A test names what it asserts: `test_min_damage_applies_when_formula_floors_to_zero`, not `test_damage_2`.
- The suite passes before every commit. A red suite is fixed or reverted, never left.

---

## 9. Definition of done

A change is done when all of the following are true:

- [ ] Naming follows §1 throughout.
- [ ] All new code is statically typed; declaration order follows §2.
- [ ] Public classes and functions have docstrings.
- [ ] No magic numbers; balance numbers are in `/data`.
- [ ] `/sim` additions are `RefCounted`, node-free, and RNG-free.
- [ ] No game rules were added to `/scenes` or `/ui`.
- [ ] New content required no new code.
- [ ] New user-visible text goes through `tr()` with a key in `/locale`.
- [ ] New sim logic has tests; the full suite passes headlessly.
- [ ] No dead code, no commented-out blocks, no silent stubs.
- [ ] Any decision the design doc did not cover is logged in `DECISIONS.md`.

---

## 10. Named anti-patterns

Each of these is a specific, identified failure in the reference project. They are listed so they can be recognized rather than re-derived.

1. **Content as code.** One `.gd` file per weapon, per unit, per map, per cutscene beat, each one assigning literals in `_ready()`. Hundreds of near-identical files that drift apart. → Data.
2. **The god-object autoload.** A single global holding every subsystem reference and all mutable battle state, reached into from everywhere. State flow becomes unknowable and untestable. → Injected dependencies and a typed state object.
3. **Split forecast and resolution.** Two separate code paths computing the same combat, guaranteeing that the number shown differs from the number applied. → One function, two callers.
4. **Data stored on view nodes.** Terrain values living on tile `Node2D`s, so terrain cannot be read without a scene tree. → Sim-side data model; the view reads it.
5. **Stringly-typed everything.** Signals connected by string name, prices recovered by parsing label text, terrain matched by hardcoded name. → Declared signals, typed data.
6. **Tree-walking coupling.** `get_parent().get_parent().get_node("Damage Preview")`. Moving a node breaks unrelated code. → Signals up, injection down.
7. **Writing saves to `res://`.** Works in the editor, fails in every export.
8. **Stubs presented as features.** A menu entry that prints to console; a parser that opens a file and does nothing; a `tests/` folder with no assertions.
9. **Copy-paste metadata.** A level-4 file whose name field says "Level 3", because metadata was hand-typed per file. → Derive it or data-drive it.
10. **Hardcoded protagonist names in systems.** `if unit.name == "Eirika"` inside the save system and the status screen. → Roles and ids from data.

---

11. Amending this document

Changing a rule here means changing the codebase to match. Amendments are made by editing this file, bumping its version, and logging the reason in `DECISIONS.md`. Rules are not suspended for a single file, and "just this once" is not a category that exists.
