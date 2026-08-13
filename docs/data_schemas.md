# DATA SCHEMAS — DEATH OR TAXATION

**Derived document** (ruled 2026-08-12, DECISIONS G34 Q1): this file consolidates the `/data` schemas for the schema-forge effort; every shape here traces to a DECISIONS ruling or a DECISIONS-logged shape choice. Where this document disagrees with `design_doc.md` (design) or `DECISIONS.md` (rulings), **they win**. `conventions.md` §4 governs the data tree, §5 the base data rules, §6 the localization key scheme.

Per-domain sections land as schema-forge tickets close (`.scratch/schema-forge/map.md`): unit types & combat tables (ticket 40), Generals (41), abilities & items (42), maps (43), chapters (44), VN scenes (45), economy (47); final assembly and cross-reference audit is ticket 48.

---

## 0. Meta-conventions (G34, schema-forge issue 39)

These apply to every file under `/data`, on top of conventions §5 (JSON only; stable snake_case `id`s; cross-references by id, never index/filename/display name; no display text — locale keys only; numbers as numbers, percentages as multipliers; loud validation).

- **No `schema_version` in data files** (G34 Q2). Repo data ships in lockstep with the code that reads it; the version key remains a save-file (`user://`) rule (conventions §7).
- **Every field is required-explicit** (G34 Q3). No loader-supplied defaults. Design-optional features are authored as explicit empty/off values — `"abilities": []`, `"fog": false` — never as absent keys. A missing key is a load error.
- **Unknown keys are load errors** (G34 Q7). Strict validation catches typos (`"defence"` for `"defense"` fails loudly instead of silently no-opping). The single exception:
- **Underscore annotation keys are legal and meaningless** (G34 Q4). Any key starting with `_` (e.g. `"_placeholder"`, `"_note"`) is skipped by the loader and carries no game meaning. Example files use them to mark values that are placeholders rather than ruled numbers; ruled starting constants (§11 economy, G20 terrain costs, §3.1 triangle) are quoted exactly and carry no marker.
- **`id` equals filename** (G34 Q5). In one-file-per-entity folders (`generals/`, `items/`, `maps/`, `chapters/`, `scenes/`), the file carries `"id"` and the loader validates it equals the filename sans `.json`; mismatch is a load error naming both.
- **Tile coordinates are `[x, y]` arrays** (G34 Q6a). One coordinate order project-wide, matching Godot's `Vector2i`; the G21 universal board-position tie-break key is amended to match — (x, y), lowest x then lowest y (canonical: design_doc §3.5).
- **Displayable entities carry `name_key`** (G34 Q6b). Localization keys use the singular-domain dot-scoped scheme of conventions §6: `general.washington.name`, `unit.line_infantry.name`, `chapter.saratoga.title`, `scene.l1_intro.line_03`.
- **Enum values are snake_case strings** (conventions §1, confirmed at issue 39): `"infantry"`, `"active_once"`, `"start"`.
