# DATA SCHEMAS — DEATH OR TAXATION

**Derived document** (ruled 2026-08-12, DECISIONS G34 Q1): this file consolidates the `/data` schemas for the schema-forge effort; every shape here traces to a DECISIONS ruling or a DECISIONS-logged shape choice. Where this document disagrees with `design_doc.md` (design) or `DECISIONS.md` (rulings), **they win**. `conventions.md` §4 governs the data tree, §5 the base data rules, §6 the localization key scheme.

Per-domain sections land as schema-forge tickets close (`.scratch/schema-forge/map.md`): unit types & combat tables (ticket 40), Generals (41), abilities & items (42), maps (43), chapters (44), VN scenes (45), economy (47); final assembly and cross-reference audit is ticket 48.

---

## 0. Meta-conventions (G34, schema-forge issue 39)

These apply to every file under `/data`, on top of conventions §5 (JSON only; stable snake_case `id`s; cross-references by id, never index/filename/display name; no display text — locale keys only; numbers as numbers, percentages as multipliers; loud validation).

**Scope exception — `data/maps/` (G43):** battle maps are Tiled JSON (`.tmj`), authored in Tiled and parsed directly; Tiled's documented format governs those files, so this section's meta-rules and the id==filename validation do not apply there (map id = filename stem). The DoT authoring profile and its validation rules are the map schema section (schema-forge ticket 43, pending).

- **No `schema_version` in data files** (G34 Q2). Repo data ships in lockstep with the code that reads it; the version key remains a save-file (`user://`) rule (conventions §7).
- **Every field is required-explicit** (G34 Q3). No loader-supplied defaults. Design-optional features are authored as explicit empty/off values — `"abilities": []`, `"fog": false` — never as absent keys. A missing key is a load error.
- **Unknown keys are load errors** (G34 Q7). Strict validation catches typos (`"defence"` for `"defense"` fails loudly instead of silently no-opping). The single exception:
- **Underscore annotation keys are legal and meaningless** (G34 Q4). Any key starting with `_` (e.g. `"_placeholder"`, `"_note"`) is skipped by the loader and carries no game meaning. Example files use them to mark values that are placeholders rather than ruled numbers; ruled starting constants (§11 economy, G20 terrain costs, §3.1 triangle) are quoted exactly and carry no marker.
- **`id` equals filename** (G34 Q5). In one-file-per-entity folders (`generals/`, `enemy_generals/` — added G41, `items/`, `maps/`, `chapters/`, `scenes/`), the file carries `"id"` and the loader validates it equals the filename sans `.json`; mismatch is a load error naming both.
- **Tile coordinates are `[x, y]` arrays** (G34 Q6a). One coordinate order project-wide, matching Godot's `Vector2i`; the G21 universal board-position tie-break key is amended to match — (x, y), lowest x then lowest y (canonical: design_doc §3.5).
- **Displayable entities carry `name_key`** (G34 Q6b). Localization keys use the singular-domain dot-scoped scheme of conventions §6: `general.washington.name`, `unit.line_infantry.name`, `chapter.saratoga.title`, `scene.l1_intro.line_03`.
- **Enum values are snake_case strings** (conventions §1, confirmed at issue 39): `"infantry"`, `"active_once"`, `"start"`.

---

## 1. Unit types — `data/units/units.json` (G40, schema-forge issue 40)

One per-domain file for the whole unit tier (G40 Q1 — the squads/singles split was superseded, G35). The file is **one object keyed by unit-type id**; key uniqueness is structural. Example: [data/units/units.json](../data/units/units.json).

- **No `tier` field** (G40 Q1 derived reading): tier derives from home — `units.json` entries are tier `unit`; `generals/<id>.json` files are tier `general`. The loader assigns the conventions §1 `Tier` enum.
- **No `faction` field** (G40 Q2 derived reading): which side fields a type is instance-level chapter data (§8.3). Redcoat variants are **separate entries with their own ids** and their own damage-table rows (G40 Q2) — the visual recolor is a view concern.

Fields, per record (all required-explicit — G34 Q3; stat semantics: design_doc §3.3):

| Field | Type | Notes |
| --- | --- | --- |
| `name_key` | string | conventions §6 scheme: `unit.<id>.name` |
| `max_hp` | int | per-unit value (G35 Q5 — no tier constants) |
| `defense` | number | 0.0 neutral; `(1 − defense)` in the pipeline (G16) |
| `armament` | enum | `rifle \| melee \| musket` (§3.1, exhaustive) |
| `type` | string | damage-table row/column id; must be fully covered there (G40 Q3b) |
| `attack_ranges` | int[] | explicit distances, e.g. `[2, 3]` |
| `counter_ranges` | int[] | D9/D11 semantics; empty list = never counters |
| `counter_mult` | number | counter-damage multiplier, 1.0 neutral (G35 Q7) |
| `move` | int | movement points vs per-class terrain costs |
| `move_class` | enum | `infantry \| mounted \| siege` (G20; closed — no flying, G28) |
| `abilities` | string[] | ability ids (ticket 42); `[]` when none |
| `sight` | int | fog vision radius (G12) |
| `slot_category` | enum | `general \| tank \| infantry` (G9) |
| `throwing` | int | throw range in tiles; 0 = self-use only (G33 Q4) |

Validation (DataLoader, conventions §5): every field present and typed as above; enum membership; `type` covered by the complete damage table (G40 Q3b); every `abilities` id resolves; unknown non-underscore keys are errors (G34 Q7).

## 2. Combat tables — `data/combat/` (G40, schema-forge issue 40)

**`damage_table.json`** (G40 Q3a/Q3b) — flat record list under one container key:

```json
{ "matchups": [ { "attacker": "<type>", "defender": "<type>", "value": 6 }, … ] }
```

Validation: **complete** over every declared `type` (units *and* Generals — G18's matrix grows as `generals/` files land); a missing or duplicate (attacker, defender) pair is a load error naming both types. Values are positive numbers (the min-1 rule lives in the pipeline, not the table). Example: [data/combat/damage_table.json](../data/combat/damage_table.json) — uniform placeholder values (`_note` marks them; balance is out of scope).

**`armament_triangle.json`** (G40 Q4) — the three named multipliers, ruled values quoted exactly (§3.1):

```json
{ "advantage": 1.5, "neutral": 1.0, "disadvantage": 0.5 }
```

The rifle→melee→musket→rifle cycle is sim code: the locked cycle is not expressible — and therefore not corruptible — in data. Example: [data/combat/armament_triangle.json](../data/combat/armament_triangle.json).

**`terrain.json`** (G40 Q5a/Q5b) — one object keyed by terrain id. Fields, per record: `name_key` (`terrain.<id>.name`), `defense` (number — §3.4 values), `move_cost` (object with **all three** move_class keys; **`-1` is the impassable sentinel** — tested, never used arithmetically), `concealment` (bool) and `sight_modifier` (int) — the §3.6 fog-vision pair, authored explicitly on every record (neutral `false`/`0`). Validation: all eight §3.4 terrain ids present is *not* required (the list may grow), but every record carries every field, `move_cost` covers exactly the three classes, and `-1` is the only legal negative cost. Example: [data/combat/terrain.json](../data/combat/terrain.json) — defense and costs quote the ruled §3.4/G20 table; concealment/sight values are the §3.6 authoring examples.

## 3. Generals — `data/generals/` & `data/enemy_generals/` (G41, schema-forge issue 41)

One file per General; **identical schema in both folders** (G41 Q3) — the folder is the side statement; no side/faction field exists. `id` == filename (G34 Q5). Examples: [data/generals/washington.json](../data/generals/washington.json), [data/enemy_generals/cornwallis.json](../data/enemy_generals/cornwallis.json).

A General file carries the **full §1 unit stat block** (every field, same types — Generals are tier `general` by home, G40 Q1) plus:

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | == filename (G34 Q5) |
| `level_packages` | object | keys exactly `"1"`, `"2"`, `"4"` (all required — G41 Q1); each `{ "power_mult": number, "hp_bonus": int, "defense_bonus": number }`, all three fields explicit (0-valued when ungranted). Values are **absolute in-effect values at that level**: the sim reads the highest package level ≤ the General's current level (G41 Q1 derived reading). |
| `level_abilities` | object | keys ⊆ `"3"`, `"5"` (G41 Q2); values are ability ids resolving against `abilities.json`; `{}` legal (none authored yet) |

- **Scene ids derive** (G41 Q2): the level-3/5 character scene for `<id>` is `<id>_l3` / `<id>_l5` (locale keys `scene.<id>_l3.*`) — no scene field in the file; validated against `data/scenes/` once ticket 45 lands.
- **Never in these files** (G41 Q4): current level, alive/dead, revival state (**campaign save**); per-appearance enemy-General levels and retreat events (**chapter data** — G8). The files are level-agnostic character definitions.
- Validation: full §1 field set + the two tables above; `type` covered by the complete damage table (G40 Q3b — a new General file obliges its row *and* column); `level_abilities` ids resolve; unknown non-underscore keys are errors (G34 Q7).

## 4. Abilities — `data/abilities/abilities.json` (G42, schema-forge issue 42)

One per-domain file, an object keyed by ability id. Framework semantics are design_doc §5 (G7); this section is the data shape. Example: [data/abilities/abilities.json](../data/abilities/abilities.json) — all six ruled abilities.

Fields, per record (all required-explicit — G34 Q3):

| Field | Type | Notes |
| --- | --- | --- |
| `name_key` | string | `ability.<id>.name` |
| `trigger` | enum | `passive_aura \| turn_start \| on_attack \| active_once` (locked — G7 Q1) |
| `shape` | object | `{ "type": "single" \| "line" \| "radius", "size": int }` (open vocabulary — new shapes are sim work, G7 Q2) |
| `target_filter` | object | fixed axes, each explicit (G42 Q2b): `side` (`friendly`/`enemy`/`any` — **owner-relative**), `tier` (`unit`/`general`/`any`), `slot_category` (`general`/`tank`/`infantry`/`any`). Adjacency/range belongs to `shape`. |
| `effects` | array | **ordered** typed records (order = D10's data-declared order). Types (reserved — G42 Q1): `damage_mult` (`value`: multiplier), `move_bonus` (`value`: tiles), `table_damage` (value-less), `heal` (`base`: number — × `power_mult`, G33 Q7). Every record carries `condition`: `null` (unconditional) or `{ "subject": "self" \| "target", "state": "engaged_this_turn" }` (G42 Q2 — closed axes, extended only by ruling). |
| `exemptions` | array | flags from the closed G7 Q4 whitelist: `"no_counter"`, `"move_again"`; `[]` when none (G42 Q1b) |
| `uses_per_mission` | int \| null | `null` = unlimited (G42 Q3a); charges reset every mission (G7 Q3) |
| `charge_conditions` | array | **reserved, unimplemented** (G42 Q3b): `{ "event": "enemy_killed" \| "friendly_killed", "effect": "restore" \| "grant", "amount": int }`; author `[]` |

- **`on_attack` abilities are owner-scoped** (G42 Q2b derived semantics): their effects govern the owner's own attack; `shape` and `target_filter` are authored neutral (`{"type": "single", "size": 0}`, all-`any`) and are inert.
- Validation: enum/axis membership everywhere; effect types and condition axes from the reserved vocabularies only; exemption flags from the whitelist only; ids referenced by `abilities` lists and `level_abilities` maps (units §1, Generals §3) must exist here.

## 5. Items — `data/items/<id>.json` (G42, schema-forge issue 42)

One file per item (G33 Q1); `id` == filename (G34 Q5). Example: [data/items/healing_poultice.json](../data/items/healing_poultice.json).

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | == filename |
| `name_key` | string | `item.<id>.name` |
| `price` | int | souls, camp-shop price (G26/G33; catalog entry is unlock-driven — chapter `unlocks`, G33 Q2) |
| `effect` | object | shared typed-record shape (G42 Q5): `{ "type": "heal", "amount": int }` — `amount` is **fixed** (never scaled — the `base` field name is ability-side only, G42 Q4). Types: `heal` implemented; `cure`, `buff` reserved (G33 Q5). |

Delivery is not item data: throw range = the user's `throwing` stat (G33 Q4); the pool is shared and unlimited (G33 Q3). Validation: effect type from the reserved item vocabulary; unknown non-underscore keys are errors.
