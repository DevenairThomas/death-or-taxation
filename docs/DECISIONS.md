# DECISIONS — DEATH OR TAXATION (gray-box prototype)

Log of spec-silent technical decisions. Each entry: the choice, and why it does not contradict the locked spec. `⚠ TODO` marks items that still need work or expansion.

---

## Data & architecture

### D1 — JSON for all data
All game data (units, terrain, damage table, generals, abilities, maps, scenes, economy) lives in JSON files under `/data`, loaded by a single `DataLoader`. Chosen over Godot `Resource`/`.tres` so `/sim` stays free of `ResourceLoader`/editor coupling and is headless-test friendly. One format everywhere — no mixing.
Note (G29, 2026-08-12): cutscene *content* stays DoT JSON under this rule; Dialogic (the adopted VN presentation layer, design_doc §10) is driven by the runner and never becomes an authoring format.
Note (G43, 2026-08-13): battle maps are the ruled exception to the *schema* half — `data/maps/*.tmj` are JSON in **Tiled's documented format** (authored in Tiled, parsed directly by DataLoader); the one-format rule narrows to one *encoding* (JSON everywhere), with every other domain remaining DoT-schema JSON under G34 §0.

### D2 — Sim purity
`/sim` classes extend `RefCounted` only. No `Node`, `SceneTree`, or `get_node`. `AStarGrid2D` is a `RefCounted` `Object` (not a `Node`), so it is legal inside sim. Enforced by keeping the view in `/scenes` + `/ui`.

### D3 — Forecast/resolution identity
`Skirmish.forecast(...)` returns a `SkirmishResult`; `Skirmish.resolve(...)` calls `forecast()` then applies it. The forecast popup and the resolved skirmish call the same function, so they cannot diverge (quality-bar requirement).

### D4 — No RNG in sim
No `randi`/`randf` anywhere in `/sim`. A test greps `/sim` sources for RNG usage and fails if found. Enforces the deterministic-combat rule mechanically.

### D5 — Sim→View via signals
A single `BattleSim` `RefCounted` defines the signal surface; the view connects and the sim never references the view. Signal contract below.

### D6 — Tests via headless runner
Plain headless runner (`tests/run_tests.gd`) executed with `godot --headless --path . -s res://tests/run_tests.gd` (canonical spelling — ruled G23, 2026-08-11; conventions §8 and CLAUDE.md match). No GUT dependency ("no plugins"), one command, zero setup.

---

## Combat math

### D7 — Damage formula (single source of truth)
Canonical statement: `design_doc.md` §3 (per ruling G1 below). Mirror:
```
base  = damage_table[attacker.type][defender.type]   # `type` = the §3.3 field name
base *= armament_triangle[attacker.armament][defender.armament]  # design_doc §3.1; three classes, no arcane
base *= attacker.power_mult            # general level package; 1.0 for units
base *= ability modifiers              # e.g. command_aura x1.20, multiplicative, pre-floor
base *= attacker.counter_mult          # counter resolutions only (G35); 1.0 when the attack is initiated
terr  = 1.0 - terrain[defender.tile].defense
defn  = 1.0 - defender.defense         # per-unit stat, 0.0 neutral (G16)
dmg   = floor(base * terr * defn)
dmg   = max(dmg, MIN_DAMAGE)           # MIN_DAMAGE = 1; initiated attacks only (G35) — a counter skips this line and may deal 0
```
Verified vs. the eight canonical worked examples (design_doc §3.2, the G35 set): `6×1.0×0.8=4.8 → 4`; min-1 `2×0.5×0.6=0.6 → 0 → 1`; advantage `6×1.5=9`; disadvantage `6×0.5×0.8=2.4 → 2`. Defence examples (G16 term): `6×0.75=4.5 → 4`; `6×0.8×0.75=3.6 → 3`. Counter examples (G35): `4×0.5=2`; `1×0.5×0.8=0.4 → 0` (exempt from MIN_DAMAGE).

Update 2026-08-02 (ruling G2): a per-unit `defense` stat was ruled into existence (issue 02, Q2=B); its pipeline term was pending grilling issue 16.
Update 2026-08-10 (ruling G16): the defence term landed — multiplicative `(1 − defender.defense)`, stacking independently with terrain, uncapped. Canonical examples then numbered seven (design_doc §3.2), examples 6–7 exercising defence.
Update 2026-08-12 (ruling G35): degradation abolished — the `hp_f` line deleted (no unit's damage scales with HP); counters multiply in the countering unit's `counter_mult` and skip the MIN_DAMAGE floor (a counter may deal 0); the canonical set re-derived as eight examples (design_doc §3.2).

### D8 — Squad degradation uses current/max HP
HP-degradation factor is `current_hp / max_hp`, exactly as the worked examples imply. Only `tier == squad` degrades; singles and generals use `1.0`.
Update 2026-08-12 (ruling G35): **superseded** — degradation was abolished project-wide with the squad/single merge; no unit's damage scales with HP. This entry stands as historical record only.

### D9 — Counterattack uses post-damage HP
The counter fires only if the defender survives the initial hit, the attacker's tile range is within the defender's `counter_ranges`, and the counter's degradation factor uses the defender's HP *after* taking damage.
Update 2026-08-12 (ruling G35): **amended** — the survive-then-counter and `counter_ranges` conditions stand; the degradation-factor clause is void (no degradation exists). A counter now multiplies in the countering unit's `counter_mult` (§3.3) and is exempt from MIN_DAMAGE — a counter may deal 0.

### D10 — Ability damage modifiers
Multiplicative, applied to `base` pre-floor, in data-declared order. Keeps the formula a single ordered pipeline.

### D11 — Cannon Crew "no counter at range 1"
Modeled generically as `counter_ranges` on the unit def. Cannon Crew = `[2,3]`; melee = `[1]`. No special-case code.
Update 2026-08-12 (ruling G36): Cannon Crew renamed **Cannoneer** (individual-unit roster renames); the rule is unchanged.

---

## Generals & progression

### D12 — `power_mult` is the level stat package
Levels 1/2/4 grant a `power_mult` (and small `hp_bonus`) that multiplies the table value pre-floor — the spec's "+15–20% effective power." Levels 3/5 grant an ability instead of a stat bump, and set a character-scene flag.
Update 2026-08-10 (ruling G16, Q4=B): level packages may additionally grant a `defense` bump (design_doc §5).
Update 2026-08-12 (ruling G33, Q7): heal-ability amounts scale through this same package — heal = base × `power_mult`; no separate heal curve exists.

### D13 — Generals do not degrade
Generals use `tier:"general"` => no HP-degradation multiplier ("static per level, grows via EXP"), side-agnostic (G8 Q6). **Resolved** (ruling G19, 2026-08-10, grilling issue 21): the ruled distinctions are the complete intended General presence — unique damage-table row/column (G18), per-General base HP/stats (G2), defense incl. level bumps (G16), `power_mult` levels (D12), abilities at L3/L5 (§5), seize/escape roles (G4), the mission-loss exemption (G5 Q6), the `general` slot category (G9), and revival/cutscene persistence (§6). No further General-specific battlefield mechanic exists; adding one requires a new ruling. Canonical closure statement: design_doc §3.
Update 2026-08-02 (ruling G2): Generals are no longer stat-identical to singles — each General sets a per-General base HP and stats in its own data file (issue 02, Q1b=C).
Update 2026-08-12 (ruling G35): the tier vocabulary collapsed to `unit | general` (squads/singles merged) and degradation was abolished — "no HP-degradation" ceased to be a General distinction because nothing degrades. The G19 closure list stands with that item struck (design_doc §3).

### D14 — Per-General damage-table rows (archetype sharing rejected)
The original recommendation — Generals sharing archetype rows/columns (Washington→`heavy_melee`, Franklin→`arcane_ranged`, Lafayette→`cavalry`, a ~7x7 matrix) — was **rejected** (ruling G18, 2026-08-10, grilling issue 20 decisions-reconciliation). Every General, player and enemy alike, carries a unique `type`: its own row and column in the damage table. The matrix grows with the roster (full campaign ≈ 8–10 unit types + ~11–12 Generals ≈ 19–22 rows); adding a General means authoring its row and column as data — the zero-code-changes rule holds (G18 Q4). `power_mult`, per-General stats, and abilities (D12/G2/G16) individuate on top of the unique row.
Note (G8, 2026-08-03): enemy Generals are on the player scale (level + `power_mult`), so they also need damage-table rows — covered: each enemy General has its own row/column (G18).

---

## Turn & unit rules

### D15 — One action per unit per turn
Each unit may move+attack, move only, or attack only — one activation per turn (FE standard). Spec is silent.
Note (G7, 2026-08-03): Ride Through's move-again-after-attack is a whitelisted ability exemption to this rule (design_doc §5).
Note (G15, 2026-08-06): confirmed by owner and canonicalized as design_doc §3.7; wait is a distinct action.

### D16 — Phase-based turn order
All player units act, then all enemy units (AW/FE phase model), not per-unit initiative. Spec is silent.
Note (G15, 2026-08-06): confirmed by owner and canonicalized as design_doc §3.7.

---

## Terrain

### D17 — `bridge` terrain type added
Spec says "River (impassable except bridges)" but lists no bridge tile. Added a `bridge` type (passable, cost 1, def 0) so river crossings can exist. River itself is `passable:false`.

### D18 — `infantry_only` via `move_class`
Mountain is `infantry_only`. Units carry a `move_class` (`infantry|mounted|siege|construct`); only `infantry` may enter `infantry_only` terrain. ⚠ TODO — confirm which prototype units count as "infantry-type" for mountain access (Cavalry, Cannon, Death Knight, constructs presumably excluded).
Update 2026-08-03 (ruling G3): **superseded** — there is no `infantry_only` terrain flag. Each terrain type's data carries a per-`move_class` movement restriction (design_doc §3.4). Mountain's prototype data restricts entry to `infantry`. The ⚠ above becomes data-authoring: assign each unit's `move_class` and each terrain's allowed classes.
Update 2026-08-10 (ruling G20, grilling issue 22): the authoring landed and the model changed — per-class **costs**, not allow/deny; the `construct` class was removed (vocabulary: infantry/mounted/siege); Mountain's entry ban became severe non-infantry cost. Full assignments and starting costs: G20; canonical: design_doc §3.3/§3.4.

---

## Signal contract (BattleSim)

```
battle_started(state_snapshot)
turn_changed(faction, turn_number)     # turn = player phase then enemy phase, one shared number; increments at player-phase start (G27 Q2 simplest reading)
unit_spawned(unit_id)
unit_moved(unit_id, path)
unit_damaged(unit_id, amount, new_hp, source_unit_id)
unit_healed(unit_id, amount, new_hp, source)     # added G24 Q2; emitters ruled G26 (2026-08-12): consumable item heals + rare level-scaled heal abilities; heal tiles remain nonexistent (G24 Q1)
unit_destroyed(unit_id, faction, was_general)
skirmish_resolved(result)              # same payload as forecast; "defender cannot counter" = the counter section is absent/null (G26 Q2, 2026-08-12); full schema still an implementation-time entry
ability_triggered(unit_id, ability_id, affected_ids)
unit_activated(unit_id)                # AI dormancy broken
unit_exited(unit_id)                   # escape objective — left via exit tile alive (G4)
unit_retreated(unit_id)                # scripted boss retreat — alive, excluded from rout (G8)
unit_revealed(unit_id)                 # fog — entered player vision, incl. ambush reveal (G12)
unit_hidden(unit_id)                   # fog — left player vision, marker vanishes (G12)
objective_progress(text)
mission_complete(victory, summary)     # turns, units_lost, champion_killed (renamed from squads_lost — G35; units_lost = total non-General losses, while preservation secondaries evaluate via their chapter-authored slot-category scope — G36 Q3)
```
Attack emission order: `unit_moved` -> `unit_damaged`(defender) -> [`unit_destroyed`] -> [`unit_damaged`(attacker counter)] -> [`unit_destroyed`] -> `skirmish_resolved`.
Truncated move (fog ambush, G12): `unit_moved`(truncated path) -> `unit_revealed`(ambusher); no attack signals fire; the command returns a distinct truncation outcome — legal-but-cut-short, not invalid (ruled G25 Q2a/Q2b, 2026-08-11).

View→Sim is method calls returning a validity result (never asserts on bad input): `get_reachable`, `get_attackable`, `get_threat`, `forecast`, `command_move_attack`, `command_wait`, `command_ability`, `end_turn`. (`get_threat` added G31, 2026-08-12 — feeds the danger-zone overlay; visible-enemies-only under fog; provisional-name convention.) Ruled semantics (G25, 2026-08-11): `command_move_attack(unit_id, path, target)` — the caller's full tile path is authoritative; the sim validates (contiguity, G20 budget, G3 legality) and never substitutes its own path; the AI submits planned paths through the same call. `get_reachable` includes the unit's origin tile — attack-only/wait are zero-length moves through the uniform pipeline (whether a zero-length `unit_moved` fires is delegated to an implementation-time entry per this file's protocol).

Update 2026-08-10 (audit F4, issue 19): `unit_exited` / `unit_retreated` / `unit_revealed` / `unit_hidden` added for mechanics ruled after the contract was written (G4 escape exits, G8 boss retreat, G12 fog visibility). Names are provisional until implementation — re-log here if they change.
Update 2026-08-11 (ruling G24 Q2): `unit_healed` added proactively — no mechanic emits it yet (heal tiles ruled out, G24 Q1; healing as an ability effect remains unruled — flags live on reference-mining issues 28/31/36). Same provisional-name convention.

---

## Open items to resolve before/during implementation

- ~~⚠ **D14** — confirm archetype-shared vs. per-general damage rows (recommended: shared)~~ — **resolved** (ruling G18, 2026-08-10, grilling issue 20): rejected — per-General unique rows for both factions.
- ~~⚠ **D13** — confirm whether Generals need mechanical presence beyond what G2/G16/G4 already give them~~ — **resolved** (ruling G19, 2026-08-10, grilling issue 21): the ruled inventory is complete; General presence is closed.
- ~~⚠ **D18** — *data authoring, not a design question (G3):* assign each unit's `move_class` and each terrain's allowed classes~~ — **resolved** (ruling G20, 2026-08-10, grilling issue 22): per-class cost model; construct removed; all prototype assignments authored.
- ~~⚠ Ability trigger taxonomy~~ — **resolved** (ruling G7, 2026-08-03): the four-trigger vocabulary is locked and all six abilities map; Lightning Rod was ruled once-per-mission to fit `active_once`. Canonical: design_doc §5 "The ability framework".
- ⚠ Map JSON `legend`/`tiles` ASCII-grid format is provisional — *Milestone 1 implementation work, not an open decision (owner, decisions-reconciliation charting, 2026-08-10):* validate it round-trips through `DataLoader` on the first real map.
- ~~⚠ AI tie-break chain (G11 Q6)~~ — **resolved** (ruling G21, 2026-08-10, grilling issue 23): the full chain is ruled and canonical at design_doc §3.5; the exact-choice test asserts through it.

---

## Owner rulings (grilling issues)

### G1 — Canonical damage pipeline (grilling issue 01)
Ruled by owner, 2026-08-02. Issue: `.scratch/design-doc-gap-sweep/issues/01-canonical-damage-pipeline.md`.
- **Q1 = A:** `design_doc.md` is authoritative on design rules. `CLAUDE.md` and `docs/pre_prompt.md` are derived summaries — where they disagree with `design_doc.md` on a design rule, `design_doc.md` wins. (`conventions.md` still wins on repo structure, per its own preamble.)
- **Q2 = A:** the armament triangle is in the damage pipeline. D7 amended to match `design_doc.md` §3.
- **Q3 = B:** there is no `arcane` armament class. Every unit type has exactly one of rifle/melee/musket; "arcane" survives only as a damage-table role/row name for non-General types (e.g. the Arcane Sentinel's row; D14's `arcane_ranged` General-archetype example was later rejected — G18, per-General rows).
- **Q4 = B:** the three original worked examples are canonically armament-neutral (×1.00) and hold unchanged; two triangle examples (advantage ×1.5, disadvantage ×0.5) added as canonical in `design_doc.md` §3.2.

### G2 — The unit stat block (grilling issue 02)
Ruled by owner, 2026-08-02. Issue: `.scratch/design-doc-gap-sweep/issues/02-unit-stat-block.md`. Canonical statement: `design_doc.md` §3.3.
- **Q1a = B:** max HP is a per-unit data field, not a tier constant. Owner's rationale: "We will need to give certain units more hp depending on class and level. This makes units more unique." Prototype values (squads 10, singles 25) are starting data. *(Framing updated 2026-08-12, G35 Q5: the ruling stands; the per-tier framing of the values is historical — docs no longer quote them, values live in unit data files.)*
- **Q1b = C:** Generals set per-General base HP and stats in their own data files. Owner's rationale: "Units will have per unit hp and stats."
- **Q2 = B:** a per-unit `defense` stat exists. Owner's rationale: "Units will have a defense stat." This knowingly reopens the pipeline shape ruled in G1; the term's mathematical form, terrain composition, and revised worked examples are spawned as grilling issue 16 — the G1 pipeline stays canonical until 16 is ruled.
- **Q3 = C:** per-unit matchup bonuses cut — Cavalry Squad's "bonus vs. Riflemen" removed from the roster.
- **Q4 = A:** `attack_ranges` and `counter_ranges` are explicit fields on every unit (D9/D11 semantics kept).
- **Q5 = A:** `move` (points vs. terrain costs) and `move_class` (D18) are standard fields on every unit.

### G3 — Movement and occupancy (grilling issue 03)
Ruled by owner, 2026-08-03. Issue: `.scratch/design-doc-gap-sweep/issues/03-movement-and-occupancy.md`. Canonical statement: `design_doc.md` §3.4.
- **Q1 = A:** allies pass-through; enemies block movement.
- **Q2 = A:** a unit may never end its move on an occupied tile.
- **Q3 = A:** no zone of control; threat range stays movement + attack range.
- **Q4 = other (owner's words):** "No infantry only terrain. Terrain will have a value that restricts movement depending on the class of unit." D18 superseded. Data shape (simplest reading, logged per this file's protocol): each terrain type declares which `move_class` values may enter; a per-class *cost* table was not ruled — correct this entry if that was the intent. **Corrected 2026-08-10 (ruling G20, grilling issue 22): the per-class cost table WAS the intent** — terrain authors a movement cost per move_class, impassable being a legal cost value; the allow/deny reading is superseded.
- **Q5 = B:** Road's −0.1 defence was a typo; Road defence is 0. No negative-defence terrain exists.
- **Q6 = A:** attack range is a pure distance check; units never block line of fire. Owner note (verbatim): "Terrain might effect range however" — terrain-based range effects are reserved as a possible future mechanic, not currently in the sim.

### G4 — Objective semantics (grilling issue 04)
Ruled by owner, 2026-08-03. Issue: `.scratch/design-doc-gap-sweep/issues/04-objective-semantics.md`. Canonical statement: `design_doc.md` §8.2 "Objective semantics".
- **Q6 = A:** exactly one primary objective per chapter. Owner's words: "One primary + several secondaries." §8.3 schema gains the `objective` field (type + parameters).
  Amended 2026-08-12 (ruling G29 Q4): "exactly one" now means exactly one **at a time** — scripted chapter events may replace the primary (or move the champion designation) mid-mission; never two primaries at once.
- **Q1 = B:** only a General satisfies seize; wins instantly on arrival. Owner's words: "Only a general satisfies the seize."
- **Q2 = A:** defend wins at end of turn N; an enemy ending its turn in the zone = immediate loss; player occupation of the zone is not required.
- **Q3 = C:** escape requires all Generals to exit. Owner's words: "All generals must exit." Simplest readings logged per this file's protocol: "all Generals" = all *surviving deployed* Generals; the mission completes when the last of them exits; non-General units left behind count as lost for secondary bonuses (no soul cost) — correct this entry if a different reading was intended.
- **Q4 = A:** survive-X = the mission is not lost by end of turn X; loss conditions defer to issue 05.
- **Q5 = A:** rout counts every enemy that appears, reinforcements included (whether reinforcements exist at all: issue 14); enemy Generals included; no flee mechanic (amended G8 Q3: chapter-scripted boss-retreat is the single exception; a retreated General does not count toward rout).
- The chapter table's "siege" / "retreat" / "turn-limit" descriptors remain unmapped onto the five types — deferred to issue 14.

### G5 — Defeat, failure, retry, and the save model (grilling issue 05)
Ruled by owner, 2026-08-03. Issue: `.scratch/design-doc-gap-sweep/issues/05-defeat-failure-retry.md`. Canonical statement: `design_doc.md` §6 "Defeat, retry, and saves".
- **Q1 = C:** mission loss = all player units destroyed, objective instant-loss triggers (§8.2), plus optional chapter-declared loss conditions (§8.3 `loss` field).
- **Q2 = A:** defeat returns to the pre-battle flow to retry; a voluntary restart behaves identically.
- **Q3 = A:** retry is a full rollback — deaths from a failed attempt are undone; deaths become permanent only on mission completion.
- **Q4 = B:** one mid-mission suspend slot, written on quit, deleted on resume; no save-scumming. Resolves conventions §7's "if built" hedge to built; supersedes pre_prompt's "single JSON save file".
  Amended 2026-08-12 (ruling G30): the slot is additionally autosaved at every phase boundary; an enemy-phase quit stores the enemy-phase-start snapshot (deterministic replay on resume); deletion fires on the first player command after resume. The no-scum rule narrows to its residue — see G30.
- **Q5 = A:** a failed mission awards nothing; souls stay completion-only.
- **Q6 = other (owner's words):** "Mission can end without a general. As long as their are units on the map. Generals can be brought back after the battle." General deaths never lose a mission; play continues while player units remain. **Derived composition (flag if wrong):** "brought back after the battle" = normal-mode revival — No-Revive permadeath (locked rule) stands; and since failed attempts roll back (Q3), No-Revive's "losing all Generals = game over" is evaluated when a mission *completes* with zero living Generals.

### G6 — The lich on the battlefield (grilling issue 06)
Ruled by owner, 2026-08-03 (first submission had Q4 contradictory — A and B both given; re-ruled Q4 = A). Issue: `.scratch/design-doc-gap-sweep/issues/06-the-lich-on-the-battlefield.md`. Canonical statement: `design_doc.md` §7 "The lich on the battlefield".
- **Q1 = C:** the lich is purely narrative — a voice in cutscenes, never a unit, tile, or commander presence. The three unit tiers remain exhaustive (annotation added at §3).
- **Q2, Q3:** moot — only applicable had Q1 = A (deployable).
- **Q4 = A:** HQ tiles are purely geographic; no connection to the lich.
- **Q5 = A:** the lich delivers briefing/banter/debrief scenes regardless of any battlefield presence.

### G7 — The ability framework (grilling issue 08)
Ruled by owner, 2026-08-03. Issue: `.scratch/design-doc-gap-sweep/issues/08-ability-framework.md`. Canonical statement: `design_doc.md` §5 "The ability framework".
- **Q1 = A:** the four-trigger vocabulary is locked (`passive_aura | turn_start | on_attack | active_once`) and the six abilities force-map. Accepted consequence: Lightning Rod is now once-per-mission (`active_once`); Ride Through and Vive la Liberté map to `on_attack`.
- **Q2 = B:** targeting-shape grammar is open, not closed at three. Implemented now: single / line / radius; future named shapes (cone, cross, mask) may be added as abilities need them. No specific extra shapes were ruled.
- **Q3 = B, other (owner's words):** "Other conditions may effect charges. Enemies killed, friendly units killed, etc." — `uses_per_mission` baseline plus data-declared charge-affecting conditions. Cooldowns were not mentioned and are not ruled in. Simplest reading logged: charges reset fresh each mission, farming replays included — correct if wrong.
- **Q4 = A:** closed exemption whitelist: `no_counter`, move-again-after-attack (see D15 note). Never suspendable: no-RNG, minimum-1 damage, forecast=resolution.
- **Q5 = A:** per-turn flags (e.g. engaged-this-turn) are sim state reset at turn boundaries; the forecast includes every applicable ability modifier.
- **Q6 = A:** one symmetric framework; ch10's "mirroring" is the enemy-ability content schedule. §3.3 stat block gained the `abilities` field.

### G8 — Enemy Generals (grilling issue 07)
Ruled by owner, 2026-08-03. Issue: `.scratch/design-doc-gap-sweep/issues/07-enemy-generals.md`. Canonical statement: `design_doc.md` §7 "Enemy Generals, mechanically".
- **Q1 = A:** player-scale stats — level 1–5 + D12 packages; level authored per chapter appearance. Extends D14's row question to enemy Generals (note added there).
- **Q2 — letter/word mismatch, words applied:** owner wrote "B" but described "Keep them as identical for now. Update after MVP." — G7's identical framework confirmed, flagged for post-MVP revisit.
- **Q3 = A + C (owner's words: "Boss will retreat in certain events."):** recurring characters, no campaign death-tracking; plus chapter-scripted boss-retreat events. This amends G4's flat "there is no flee mechanic" (§8.2 updated). Simplest reading logged: a General removed by a scripted retreat does not count toward rout — correct if wrong.
- **Q4 = A:** fixed authored escalation curve; never dynamic scaling. §6 "never stat inflation" upheld.
- **Q5 = B:** one concept — the champion is the chapter's enemy General. Simplest reading logged: chapters without an enemy General have no champion; Trenton's Bound Golem keeps its kill secondary as a named target without the label — correct if wrong.
- **Q6 = A:** tier rules side-agnostic; enemy Generals never degrade (§3, D13).

### G9 — Deployment rules; battle budget abolished (grilling issue 09)
Ruled by owner, 2026-08-06 (initial apply gate-failed on Q4/Q6 ambiguity; owner clarified conversationally and pivoted). Issue: `.scratch/design-doc-gap-sweep/issues/09-deployment-rules.md`. Canonical statement: `design_doc.md` §4 "Deployment Slots".
- **The pivot (owner's words):** "I am moving away from a starting currency in lieu of this instead." The battle-budget currency is **abolished**. Deployment is constrained by per-chapter, per-category slot caps — `general` / `tank` / `infantry` — shown as placed/max (owner's example: "0/1 general, 2/5 tank, 1/7 infantry"). New stat-block field `slot_category` (§3.3). Owner's category mapping: infantry = versatile squads (Line Infantry, Riflemen); tank = Death Knights, mages, cannons, cavalry; general = Generals. Tank spans tiers — it is a data field, not a tier alias.
- **Q1 = A (rescoped):** the caps are the unit-count constraint; start tiles are placement. Simplest reading logged: a map provides at least as many start tiles as its total slot cap.
- **Q2 = moot:** no deployment prices exist. §12.3's "deployment costs" open item superseded.
- **Q3 = A (rescoped):** force-deployed Generals are free and extra — no general slot consumed.
- **Q4 = B (owner's words):** "keep the ability to not fill up all the slots which will increase exp earned at the end of the level." **Interpretation logged (flag if wrong):** "exp" = the end-of-mission soul award (the doc's own tier table uses "EXP" loosely for soul progression). "No per-kill EXP" and souls-only progression stand; squads/singles do not level. If a separate EXP resource leveling units was intended, that is a new system requiring its own issue.
- **Q5 = A:** no minimums; deployment warns (does not block) on seize/escape compositions with zero Generals.
- **Q6 (owner's words):** "Slot limit is battle/chapter driven." General-category schedule: 2 from ch3, 3 from ch9; tank/infantry caps authored per chapter.
- **Q7 = A:** start tiles authored per map; the player assigns which unit stands where.

### G10 — Economy exactness (grilling issue 10)
Ruled by owner, 2026-08-06. Issue: `.scratch/design-doc-gap-sweep/issues/10-economy-exactness.md`. Canonical statements: `design_doc.md` §6 (farming payout) and §11 (constants & statuses).
- **Q1 = A:** farming yield — design latitude 30–50%, starting constant 40% (tunable data).
- **Q2 = A:** revival — design latitude 15–20× level, starting constant 18×.
- **Q3 = A:** secondary bonuses are per-chapter data (§8.3); +25/+15/+10 is an example palette; +50 is an authoring guideline, not an engine cap.
- **Q4 = B:** farming replays pay base award AND secondary bonuses, both scaled by the yield.
- **Q5:** pre-ruled by G5 — failed missions pay nothing.
- **Q6 = B:** already-earned secondaries re-pay on every replay (scaled).
- **Q7 = A:** every economy constant lives only in `data/economy.json`; §11 and CLAUDE.md are annotated as quoting it (conventions R5 / D1 applied).
- Optional under-fill slot bonus (G9): not ruled — left to data authoring; §11 carries a placeholder line.

### G11 — Enemy AI: spec home, flags, and the coordinated-AI direction (grilling issue 11)
Ruled by owner, 2026-08-06 (first submission gate-failed on missing Q6 and undefined Q1/Q3 content; owner reaffirmed Q1/Q3 verbatim and added Q6 — treated as their decision). Issue: `.scratch/design-doc-gap-sweep/issues/11-ai-spec-home-and-gaps.md`. Canonical statement: `design_doc.md` §3.5 "Enemy AI".
- **Q1 = B:** full flag vocabulary canonical — `guard | aggressive | balanced` + competence axis `simple | medium | smart`. Only guard/aggressive had defined behaviors at ruling time; the rest were deferred to issue 17 — since ruled (G17 Q4).
- **Q2 = B (owner's words):** "Score is created to how important a particular target is to the AI. If a target is alone with a high likelihood of non death after a target is destroyed it gets a higher score. If a target can be destroyed it has a higher score." Importance-based scoring on the real pipeline; weights are named tuning constants; baseline implementation is `expected_damage − 0.5 × expected_counter + kill_bonus` (kill_bonus a named tuning constant, value at AI milestone).
- **Q3 (owner's words, reaffirmed):** "I prefer the AI to choose a good strategy for all units depending on how the AI perceives the field… come up with a strategy to move all units in accordance with one another and not each unit have there own AI." The coordinated army-AI is the ruled direction; pre_prompt's "do not build anything smarter than this" cap is **superseded**. Specification spawned as grilling issue 17; §3.5's per-unit model is the buildable baseline until then. (The §10 "3–5 weeks" AI estimate predates this scope growth.)
- **Q4 = B:** map data may declare activation groups that wake together.
- **Q5 = A:** sleepy defend/survive maps are resolved by mission design; no engine auto-activation (amended G17 Q5: mission design is the *primary* lever; the coordinator may strategically wake dormant groups).
- **Q6 = A ("for now"):** deterministic tie-break chain delegated to a future DECISIONS entry; must exist and be asserted by the exact-choice AI test — since ruled (G21, 2026-08-10).
- Optional (AI use of active abilities): not ruled — parked in issue 17 sub-question 6.

### G12 — Fog of war (grilling issue 12)
Ruled by owner, 2026-08-06. Issue: `.scratch/design-doc-gap-sweep/issues/12-fog-of-war.md`. Canonical statement: `design_doc.md` §3.6 "Fog of War".
- **Q5 = A:** fog is specified as a real mechanic; per-chapter flag, introduced ch8 (Germantown).
- **Q1 = B:** per-unit `sight` radius (new §3.3 field) plus terrain vision effects — concealment (occupants visible only from adjacent tiles) and sight modifiers. Mechanisms canonical; per-terrain values are data authoring.
- **Q2 = A:** map/terrain always known; fog hides units only; enemy markers vanish outside combined vision, no ghosts.
- **Q3 = B:** the AI is fogged too — each side perceives only its own vision. Feeds issue 17 sub-question 7 — since ruled (G17 Q7: fogged planning is visible-only).
- **Q4 = A:** ambush-stop — a move crossing a hidden enemy stops on the last legal tile and reveals it. Simplest reading logged (correct if wrong): the stopped unit's action is spent. Forecast promise unaffected (visible targets only; committed attacks resolve exactly).

### G13 — Naval missions are coastal flavour (grilling issue 13)
Ruled by owner, 2026-08-06 (submitted under "12" — applied to 13, whose template the rulings match). Issue: `.scratch/design-doc-gap-sweep/issues/13-naval-missions.md`. Canonical statement: `design_doc.md` §3.4 (Sea terrain + naval-flavour note).
- **Q5 = A:** naval is flavour, not a system — no water movement, no naval `move_class`, no ship units, no transport. Charleston (ch11) is a land battle on a coastal map; `sea` terrain is impassable scenery.
- **Q1/Q2:** collapsed by Q5 = A — nothing added to the move_class vocabulary or the tier roster.
- **Q3 = A:** the five objective types suffice; sink/blockade goals map onto rout/defend/named kill-targets. G4's vocabulary unamended.
- **Q4 = A:** John Paul Jones's kit (if he joins — roster remains §12 item 1) must stay meaningful on land; no General's design may require naval maps.

### G14 — Chapter schema completeness (grilling issue 14)
Ruled by owner, 2026-08-06. Issue: `.scratch/design-doc-gap-sweep/issues/14-chapter-schema-completeness.md`. Canonical statement: `design_doc.md` §8.3 (fully consolidated field list).
- **Q1 = A:** reinforcements exist — turn-triggered spawn events (tiles/edges + unit list) in chapter data; spawned units enter under normal dormancy unless marked active; rout counts them (resolves G4's conditional).
- **Q2 = B:** mid-mission scenes fire on event triggers: turn number, unit-enters-region, named unit's death or retreat.
- **Q3, Q6:** pre-collapsed by G4/G5/G9/G11 — objective field, loss conditions, slot caps (chapter data), start tiles + activation groups (map data).
- **Q4 = A:** the campaign is strictly linear; §8.3's "prerequisite chapter ids" corrected to a singular prerequisite.
- **Q5 = A:** unlocks fire on first story clear only; farming replays pay souls only.
- **Q7 = A:** descriptor mapping — "siege" = seize, "retreat/survive" = escape, "turn-limit" = survive-X-turns (chapter table annotated).
- Simplest reading logged (correct if wrong): on chapters with multiple enemy Generals, chapter data marks which one is the champion (G8's designation now has a schema home).

### G15 — Doc housekeeping (grilling issue 15)
Ruled by owner, 2026-08-06. Issue: `.scratch/design-doc-gap-sweep/issues/15-doc-housekeeping.md`.
- **Q1 = B:** "EXP" is defined once as the colloquial name for soul progression (design_doc §3 vocabulary note). One progression currency; no per-kill EXP; no separate EXP resource. The tier table's "grows via EXP" and G9's "exp" bonus now share the definition.
- **Q2 = A:** locale target is English-only; Latin + Latin Extended font stack; the phantom "§12 item 12" reference replaced (design_doc §14, conventions §6 note). `tr()` keys remain mandatory.
- **Q3 = B:** no hard map dimension bounds; camera pans; the "16 tiles wide without scrolling" claim struck. No minimum was ruled; the prototype's 12×12–16×16 envelope is authoring practice.
- **Q4 = A:** turn model confirmed and canonicalized as design_doc §3.7 — phase-based order (D16); one activation per unit with wait as a distinct action (D15, matching the existing `command_wait` contract); attack-then-move impossible bar Ride Through's exemption (G7).

### G16 — The defence term (grilling issue 16)
Ruled by owner, 2026-08-10. Issue: `.scratch/design-doc-gap-sweep/issues/16-defence-term.md`. Canonical statement: `design_doc.md` §3 pipeline block + §3.2 examples 6–7 + §3.3 defense field. Completes the pipeline G1 canonicalized and G2 left open.
- **Q1 = A:** multiplicative, terrain-symmetric — `defn = 1.0 − defender_defense`, one new pipeline line, single floor preserved.
- **Q2 = A:** terrain and unit defense stack as independent multipliers, uncapped; min-1 is the only floor.
- **Q3 = A:** neutral value 0.0 (terrain's convention); per-unit values are data authoring ("weak defense" = below baseline).
- **Q4 = B:** all three tiers carry defense; General level packages may also grant defense bumps (D12 amended; design_doc §5 wording updated).
- **Q5 = B:** examples 1–5 annotated defense = 0 and hold unchanged; examples 6–7 added exercising defence alone (6 × 0.75 = 4.5 → 4) and stacked with degradation + terrain (6 × 0.7 × 0.8 × 0.75 = 2.52 → 2). The 0.25 defense values are authored starting numbers — correct if wanted.
- **Q6 = B:** the forecast popup shows the defender's defense stat alongside matchup state (§3.1 readability paragraph updated).

### G17 — The coordinated army AI (grilling issue 17)
Ruled by owner, 2026-08-10. Issue: `.scratch/design-doc-gap-sweep/issues/17-coordinated-ai.md`. Canonical statement: `design_doc.md` §3.5 (now complete). Closes the specification G11 opened; the sweep's last issue.
- **Q1 = C:** both coordination shapes, staged as competence tiers — `simple` = per-unit baseline, `medium` = greedy shared-state sequencing (deterministic unit order — since ruled: chapter-data declaration order, G21 Q1; projected board, emergent focus-fire), `smart` = assignment-based planning (focus-fire packages, chokepoint holders, screens). (The tier packaging was the investigator's synthesis, chosen by the owner.)
- **Q2 = A:** one enemy phase planned at a time, re-planned from the current board; no persisted plan state (suspend-safe by construction).
- **Q3 = A:** the exact-choice test asserts the full ordered enemy-phase plan for a fixed board + vision state. Depends on the tie-break chain and stable iteration order — both since ruled (G21, 2026-08-10).
- **Q4 = A:** flags are posture (guard = never moves/attacks in range/excluded from coordinated movement; aggressive = active turn 1; balanced = default), competence tiers select coordination depth.
- **Q5 = B:** the coordinator may strategically wake dormant groups — a ruled exception to the threat-range-only dormancy contract; mission design remains the primary pressure tool (G11 Q5 stands as "primary", amended from "only").
- **Q6 = A:** actives valued in planning when they beat the best normal action; once-per-mission charges held until named-constant thresholds (targets ≥ N, or secures a kill).
- **Q7 = A:** fogged planning is visible-only — hidden player units do not exist to the evaluation; vision state is part of the test fixture.

### G18 — Per-General damage-table rows (grilling issue 20, decisions-reconciliation)
Ruled by owner, 2026-08-10 (first submission paired Q1 = B with answers to Q2a/Q2b/Q3, which exist only under Q1 = A; owner confirmed B conversationally — the conditional answers are moot). Issue: `.scratch/decisions-reconciliation/issues/20-damage-table-rows.md`. Canonical statement: design_doc.md §3.3 (`type` field).
- **Q1 = B:** every General, player and enemy alike, has a unique `type` — its own row and column in the damage table. D14's archetype-sharing recommendation is rejected; the matrix grows with the roster (full campaign ≈ 19–22 rows). Ruled by owner, no rationale stated.
- **Q2a / Q2b / Q3:** moot — they described the shared-archetype mechanics and apply only under Q1 = A.
- **Q4 = A:** the zero-code-changes invariant holds — adding a General adds its data file plus a damage-table row and column, never code.

### G19 — General presence is closed (grilling issue 21, decisions-reconciliation)
Ruled by owner, 2026-08-10. Issue: `.scratch/decisions-reconciliation/issues/21-generals-distinct-presence.md`. Canonical statement: design_doc.md §3 (tier annotations).
- **Q1 = A:** the ruled inventory is the complete intended General presence — no further General-specific battlefield mechanic exists or is planned; adding one requires a new ruling. Ruled by owner, no rationale stated.
- **Q2:** moot — applicable only under Q1 = B (extend).
- **Q3 = A:** D13 rewritten to state the resolved position; its ⚠ dropped.

### G20 — move_class assignments and per-class terrain costs (grilling issue 22, decisions-reconciliation)
Ruled by owner, 2026-08-10 (submission misfiled under "21" — applied to 22, whose template the rulings match; Q2b's first answer "tank" was invalid vocabulary — tank is a `slot_category` — and Q3's comment contradicted its letter; both clarified conversationally). Issue: `.scratch/decisions-reconciliation/issues/22-move-class-authoring.md`. Canonical statements: design_doc.md §3.3 (vocabulary) and §3.4 (cost model + terrain table).
- **Q1 = B (via Q3 clarification, overriding the lettered A):** each terrain authors a movement **cost per move_class**; impassable is a legal cost value, so a ban is a special case of cost. G3 Q4's correct-if-wrong flag fired as intended.
- **Q2 — vocabulary shrunk (owner's words: "Siege - remove construct class"):** move_class is now `infantry | mounted | siege`; "construct" survives as unit flavor only. Assignments: Line Infantry, Riflemen, Washington, Franklin = `infantry`; Cavalry Squad, Lafayette = `mounted`; Cannon Crew, Death Knight, Bound Golem, Arcane Sentinel = `siege`.
- **Q3 (owner's words: "In most cases mountains will just severely reduce movement"):** Mountain's infantry-only entry ban is removed — mountains gate by severe per-class cost. Starting numbers delegated to this protocol and authored as: Mountain 3/6/6 (infantry/mounted/siege); all other passable terrain uniform (Plains 1/1/1, Forest 2/2/2, Road 1/1/1, Bridge 1/1/1, HQ 1/1/1); River/Sea impassable to all. Tunable starting data — correct if wanted. Noted consequence: at move 3, siege units cannot cross Mountain in practice (cost 6 exceeds their budget) — consistent with "in most cases," and expressible per-class if a future unit should differ.
- **Q4 = A:** prototype scope — future unit types (final roster: design_doc §12 item 2) get `move_class` assigned as data under the same pattern; no per-unit ruling needed.

### G21 — The AI tie-break chain (grilling issue 23, decisions-reconciliation)
Ruled by owner, 2026-08-10. Issue: `.scratch/decisions-reconciliation/issues/23-ai-tie-break-chain.md`. Canonical statement: design_doc.md §3.5 (Determinism bullet). Closes G11 Q6's delegation; the exact-choice test (conventions §8, G17 Q3) asserts through this chain. The chain fires only on exact score equality — it never overrides a strictly better score.
- **Q1 = A:** units act in chapter-data declaration order; reinforcements append in spawn order. Mission-stable, authorable, satisfies G17's "deterministic unit order."
- **Q2 = A:** target ties break killable-first → higher `expected_damage` → lower defender current HP → defender board position.
- **Q3 = B:** destination-tile ties break lowest per-class path cost (G20 costs) → highest terrain defense → board position.
- **Q4 = A:** under `smart`, an active must strictly beat the best normal action — an exact tie keeps the normal action and holds the charge.
- **Q5 = B:** the universal final key is board position — (row, col), lowest row then lowest column — for units and tiles alike; total order guaranteed by the occupancy rule (§3.4), computed from sim state, no RNG. **Amended 2026-08-12 (ruling G34 Q6a, schema-forge issue 39): the key is now (x, y) — lowest x, then lowest y — and data files author all tile coordinates as `[x, y]`; design_doc §3.5 carries the canonical statement.** Simplest reading logged per this file's protocol (correct if wrong): under `medium`/`smart` sequencing, "current position" means position on the projected board at the moment the acting unit is evaluated.
- All rulings by owner, no rationale stated.

### G22 — The reference clone leaves the tracked repo (grilling issue 24, conventions stress-test)
Ruled by owner, 2026-08-11 (Q5's first submission was "C" against an A/B option set; the apply gate held with no edits, owner re-ruled B). Issue: `.scratch/conventions-stress-test/issues/24-reference-clone-quarantine.md`. Canonical statement: conventions.md §4 (v1.1). Resolves stress-test findings F1/F2/F3/F8 (`.scratch/conventions-stress-test/findings/00-stress-test-findings.md`).
- **Q1 = C (owner's words):** "Untracked Local folder — We add the folder to gitignore and remove the reference to a /reference directory." The FE clone leaves git tracking entirely and stays on disk as a gitignored local folder; conventions §4's `/reference` tree entry is removed and a one-line pointer bullet replaces the folder rule. Q1a (runnable vs. inert) is moot — it applied only to the in-repo `/reference` move option. Simplest readings logged per this file's protocol (correct if wrong): the clone's tracked root folders (`scenes/`, `assets/`, `engine/`, `save/`, ~1,200 files) consolidate into a single local folder named `fe_reference/` (name unruled; snake_case per conventions §1; the `.gitignore` line and §4 bullet use it); the agent never commits, so the untracking/move is owner-executed from the checklist in the issue's Answer.
- **Q2 = A:** the DoT `project.godot` is authored fresh at Milestone 0 (pre_prompt: "Include a project.godot"), registering conventions §3's five permitted autoloads only as each is actually built. Until then the tracked `project.godot` remains the clone's — known-wrong, replaced at Milestone 0, not before.
- **Q3 = C:** the four tracked `save/` files relocate with the clone (leave tracking with it).
- **Q4 = A:** amended §4 stays a pure picture of the DoT build plus the one-line clone pointer; repo-tooling folders (`.scratch/`, `.agents/`, `file_synopsis/`) stay undocumented in §4.
- **Q5 = B:** no automated enforcement test; "never referenced from game code" remains a doc-level rule enforced by review.
- Noted, not ruled (execution consequence): once the clone untracks, `reference_project`'s tracked tree reduces to ≈ `main` + docs/tooling, so a normal merge to `main` becomes possible; branch fate is an execution decision. Rationale beyond Q1's stated words: none given — ruled by owner, 2026-08-11.

### G23 — Wording-only conventions amendments (grilling issue 25, conventions stress-test)
Ruled by owner, 2026-08-11. Issue: `.scratch/conventions-stress-test/issues/25-wording-amendments.md` (a task ticket run through /grill — the rulings settle presentation choices the ticket's author had embedded without a ruling). Reason: stress-test findings F4/F5/F6, wording-only; no design or structure rule changed. Canonical: conventions.md v1.2.
- **Q1 = A:** the version bump is an inline parenthetical on the header line (the style 1.1 established); 1.2 retroactively rolls up the already-logged §7 suspend-slot (G5) and §6 English-only (G15) notes — no G16 note exists in conventions to cite (verified during /grill). §11's malformed plain-text heading fixed to a proper `## 11.` heading.
- **Q2 = A:** §8's required-test list fully refreshed — the stale "exact choice" line becomes the enemy-phase-plan test (full ordered plan for a fixed board and vision state, G17 Q3, asserting through the G21 tie-break chain); fog visibility (G12) and per-class terrain movement costs (G20) added to the permanent list.
- **Q3 = B:** the runner command's canonical spelling is CLAUDE.md's `godot --headless --path . -s res://tests/run_tests.gd`; conventions §8 and D6 reconciled to it (CLAUDE.md unchanged).
- All rulings by owner, no rationale stated.

### G24 — Terrain HP effects and reinforcement spawn semantics (reference-mining issue 26)
Ruled by owner, 2026-08-11. Issue: `.scratch/reference-mining/issues/26-grid-board.md` (a resolved research ticket whose "Flags for /grill" were run through /grill — the G23 precedent). Canonical statements: design_doc.md §3.4 (terrain-never-modifies-HP bullet) and §8.3 (reinforcement spawn-event line).
- **Q1 = A:** no heal or damage terrain exists — a terrain record carries defense, per-class movement cost, and fog vision data only. The reference clone's Fortress/Heal/Throne/Lava/Poison tile effects map to nothing; a per-turn terrain HP step must not be built without a new ruling. (Q1b — can environment kill — is moot under A.)
- **Q2 = A:** `unit_healed(unit_id, amount, new_hp, source)` added to the D5 signal contract now, ahead of any emitting mechanic (provisional-name convention applies). Healing as an *ability* effect remains unruled — the convergent flags on reference-mining issues 28/31/36 stay live for capstone triage.
- **Q3 = A:** a reinforcement appears **on its spawn tile** — no off-map entry concept in the sim; it is targetable and visible (fog rules permitting) from the moment `unit_spawned` fires; spawn "edges" are authored border tiles.
- **Q4 = C:** an occupied spawn tile shifts the spawn to a deterministic alternate tile. Shift chain not specified in the ruling — simplest reading logged per this file's protocol (correct if wrong): nearest legal tile (unoccupied, terrain not impassable for the unit's move_class, G20) by Manhattan distance from the authored spawn tile, ties broken by the G21 universal board-position key (lowest row, then lowest column — since amended to (x, y), lowest x then lowest y, G34 Q6a, 2026-08-12; the shift chain follows the amended key); if no legal tile exists on the map (pathological under the occupancy rule), the spawn defers to the next turn and retries — deferral is the fallback, not the mechanic. The enemy-phase exact-choice test should cover a plugged-spawn board once the sim exists.
- All rulings by owner, no rationale stated.

### G25 — Path authority, ambush truncation, and reachability semantics (reference-mining issue 27)
Ruled by owner, 2026-08-11 (submitted under "26" — applied to 27, whose template the rulings match exactly; 26 was already closed under G24 and had no Q2a/Q2b — the G13/G20 misfiling precedent). Issue: `.scratch/reference-mining/issues/27-movement-pathfinding.md` (research-ticket flags run through /grill, per the G23 precedent). Canonical statements: design_doc.md §3.4 (path authority + reachability bullets) and §3.6 (ambush truncation contract); contract details in this file's Signal contract block.
- **Q1 = B:** the mover's plotted path is authoritative — `command_move_attack(unit_id, path, target)`; the sim validates (contiguity, G20 movement budget, G3 occupancy legality) and never substitutes a path. Under fog the player chooses which tiles they risk; the AI submits its planned paths symmetrically (fits G17's planner, which already plans moves).
- **Q2a = A:** ambush-truncation emission order is `unit_moved`(truncated path) → `unit_revealed`(ambusher); no attack signals fire (the attack never happens; action spent per G12).
- **Q2b = A:** the command's return value reports truncation as a distinct outcome — a legal command cut short, distinct from the invalid-input rejection D5 already defines.
- **Q3 = A:** `get_reachable` includes the unit's origin tile; attack-only and wait are zero-length moves through the uniform activation pipeline (§3.7). Whether a zero-length move emits `unit_moved` is an implementation detail delegated to an implementation-time DECISIONS entry.
- All rulings by owner, no rationale stated.

### G26 — Items, the camp shop, and healing; SkirmishResult cannot-counter (reference-mining issue 28)
Ruled by owner, 2026-08-12 (submitted under "26" — applied to 28, whose template the rulings match; the G13/G20/G25 misfiling precedent. First submission gate-failed on §9 conflict and under-specification; owner clarified in full — treated as their decision). Issue: `.scratch/reference-mining/issues/28-combat-forecast.md`. Canonical statements: design_doc.md §4 "Items & the camp shop", §3.3 `throwing` field, §5 HP-restoration bullet, §9 (partial-reversal paragraph).
- **Q1 = other (owner's words):** "Items will heal. Will add an item shop. Items will be thrown if used to heal other units. Inventory will be shared across units. Souls will be used to buy items. Some units will also be able to heal. Throwing an item will count as an action. The unit will have a throwing stat making some units better at healing than others. Healing as a mage or similar type will be rare and limited to a select few units or characters. Heal values are fixed if potions or the like are used. If there is a mage healer using magic (if we go that far) then it will scale with level."
- **This knowingly and partially reverses §9's item cut** (the G9-pivot precedent). Lifted: consumables (healing), a shop, an army inventory. Standing (not mentioned, so not lifted): weapons-as-items, durability/uses, equipping, per-unit inventory (pool is shared), trading (a thrown consumable is consumed, not transferred), weapon-level stats.
- **Simplest readings logged per this file's protocol (correct if wrong):** the shop is at camp and sells **between missions only, for souls** — the sole reading preserving the locked "souls spent between missions only" rule, which stands; the `throwing` stat governs **throw range/delivery, not heal amount** — the sole reading reconciling "better at healing" with "heal values are fixed"; self-use of an item also consumes the activation (D15's one-action rule, wait-style); any deployed unit may draw from the shared pool.
- **Determinism untouched:** consumable heal values are fixed data amounts; mage-type ability healing scales with level deterministically; heals are not attacks — the §3 pipeline, min-1 floor, and forecast=resolution identity are unaffected.
- **Q2 = A:** `SkirmishResult` represents "defender cannot counter" as an absent/null counter section; the full payload schema remains delegated to an implementation-time entry (constrained by D3/D5/G16 Q6).
- Sibling flags closed by Q1: issue 31 flag 1 (healing exists — via items + rare abilities) and issue 36 flags 1/3 (heal ability now ruled; consumables as between-mission purchases now ruled). Issue 36 flag 2 (equippable loadouts) stays resolved-as-banned: equipping was not lifted.
- Open parameters spawned as **grilling issue 38** (`.scratch/reference-mining/issues/38-item-system-parameters.md`): item data schema/file, shop stock authoring, shared-pool capacity, throw-range formula and `throwing`-stat values, offensive/utility items or heal-only, enemy/AI item symmetry, mage-heal scaling formula, and the deployment/UI surface for the pool.

### G27 — Phase end, turn boundary, and win/loss precedence (reference-mining issue 29)
Ruled by owner, 2026-08-12. Issue: `.scratch/reference-mining/issues/29-turn-victory.md` (research-ticket flags run through /grill, per the G23 precedent). Canonical statements: design_doc.md §3.7 (phase-end + turn-boundary bullets) and §8.2 (checkpoint-precedence bullet + defend/survive annotations).
- **Q1 = A:** the player phase ends automatically when every player unit has acted (the reference clone's behavior); explicit `end_turn` ends the phase early and forfeits unacted units' activations. End-of-phase confirmation dialogs are view-side presentation, outside the sim rule.
- **Q2 = A:** turn N = player phase N followed by enemy phase N; the defend/survive "end of turn N" checkpoint falls after the **enemy** phase of N. Simplest reading logged per this file's protocol (correct if wrong): the shared `turn_number` increments when a new player phase begins, both phases of turn N carry N in `turn_changed` — the reference's separate player/enemy counters are rejected by the contract's single number.
- **Q3 = B:** at a shared checkpoint, the win evaluates first — a simultaneous win+loss is a win. Mid-phase instant triggers stay unordered because they cannot coincide; the /grill session verified D9 (no counter from a destroyed defender) precludes the intra-skirmish win/loss collision.
- All rulings by owner, no rationale stated.

### G28 — No enemy-intent display; no flying units (reference-mining issue 30)
Ruled by owner, 2026-08-12. Issue: `.scratch/reference-mining/issues/30-enemy-ai.md` (research-ticket flags run through /grill, per the G23 precedent). Canonical statements: design_doc.md §3.5 (no-intent-display bullet) and §3.3 (move_class closure).
- **Q1 = A:** no enemy-intent display ships. The reference's attacker→target telegraph widget survives only as a gray-box **debug toggle** — dev affordance, not UI, no D5 contract impact, removable without a ruling. The player's forecast popup (§3.1/G16) is unrelated and unchanged.
- **Q2 = A:** no flying units — a standing rule, not a deferral. move_class stays closed at `infantry | mounted | siege`; airborne concepts are flavor only (§7's constructs line licenses exotic *ground* units). The G20 cost model could express flight as data, so this is deliberately a vocabulary ruling: adding flight later requires a new ruling plus a fourth per-terrain cost column.
- Housekeeping (this apply, G23 wording-fix precedent): removed a duplicated "Stretch goal" line in §5 introduced by the G26 apply (found during this issue's /grill verification).
- All rulings by owner, no rationale stated.

### G29 — Dialogic adopted; cutscene schema, event timing, and objective mutation (reference-mining issue 32)
Ruled by owner, 2026-08-12. Issue: `.scratch/reference-mining/issues/32-events-cutscenes.md` (research-ticket flags run through /grill, per the G23 precedent). Canonical statements: design_doc.md §10 (Dialogic adoption + boundaries), §7 (cutscene data schema), §8.2 (one-primary-at-a-time), §8.3 (event timing/order + mutation events).
- **Q1 = other (owner's words):** "Dialogic is a go. No need to reinvent the wheel." Dialogic is adopted as the VN/cutscene presentation layer — the single ruled exception to the no-plugins convention (CLAUDE.md and pre_prompt reconciled; conventions §8's plugin-free *test* stance is untouched). Boundaries: never in `/sim`; headless tests stay plugin-free. **Derived compositions logged (correct if wrong):** (1) because Q2=B was ruled in the same stroke, scene content is authored in DoT's JSON schema and the runner *drives* Dialogic — D1's one-format rule holds and Dialogic's timeline format is never an authoring format; (2) pre_prompt's stub-textbox-for-the-prototype stands as build-order latitude — Dialogic arrives when the VN layer is built. Execution consequence (not ruled here): installing Dialogic adds its autoload; conventions §3's permitted-autoload list will need that noted at adoption time.
- **Q2 = B:** the cutscene step-type vocabulary is reserved up front — `line` implemented first; `camera` / `actor` / `wait` named now, implemented when a chapter needs them.
- **Q3a = C:** turn-number triggers author their boundary in data — `at: start` (player-phase start) or `at: end` (after the enemy phase, G27's boundary). A turn-end trigger coincides with §8.2 checkpoints, where G27's win-first precedence governs.
- **Q3b = A:** when a scene and spawns share a trigger, the scene resolves first, then the spawns (the reference's pause → beat → spawn → resume envelope, made data-driven).
- **Q4 = B:** narrow scripted mutation — chapter data may declare events (same trigger vocabulary) replacing the primary objective or moving the champion designation mid-mission; exactly one primary at a time (G4 Q6 amended, wording not intent); evaluation always uses the current primary; `objective_progress` announces changes. Simplest reading logged (correct if wrong): the kill-champion secondary follows the current designation at the moment of the kill.
- Rationale stated only for Q1 (quoted above); Q2/Q3a/Q3b/Q4 ruled by owner, no rationale stated.

### G30 — Suspend cadence, enemy-phase quits, and slot consumption (reference-mining issue 33)
Ruled by owner, 2026-08-12 (submitted under "32" — applied to 33, whose template the rulings match; 32 closed under G29 with a different sub-question set. The standing misfiling precedent). Issue: `.scratch/reference-mining/issues/33-save-suspend.md` (research-ticket flags run through /grill, per the G23 precedent). Canonical statement: design_doc.md §6 (saves paragraph); conventions §7 defers to it.
- **Q1 = C:** the suspend slot is written on mid-mission quit and autosaved at every phase boundary (player-phase start and enemy-phase start, the G27 boundaries). Crash recovery restores the last boundary snapshot; a session without the slot falls back to the pre-battle retry flow (G5 Q2, only the attempt lost).
- **Q2 = B:** quitting during the enemy phase stores the enemy-phase-start snapshot; resume replays the phase from its start. The AI is deterministic and no player input intervenes, so the replayed phase is identical to the uninterrupted one — no plan state is ever serialized (G17 Q2 upheld) and no `smart`-tier divergence can occur. The view may fast-forward the replay (presentation).
- **Q3 = B:** "deleted on resume" fires on the first player command after resume. Loading and inspecting the board is crash-safe (slot intact); acting consumes the slot; reloading without acting changes nothing.
- **Derived composition, logged per this file's protocol (correct if wrong):** the G5 "no save-scumming" rule narrows to its factual residue under C+B+B — voluntary quit/resume can never rewind; a deliberate crash rewinds at most to the current player-phase start (undoing only the player's own uncommitted phase); enemy-phase outcomes are un-scummable by determinism. Accepted as the cost of crash resilience.
- All rulings by owner, no rationale stated.

### G31 — Danger-zone overlay and inspection disclosure (reference-mining issue 34)
Ruled by owner, 2026-08-12. Issue: `.scratch/reference-mining/issues/34-battle-ui.md` (research-ticket flags run through /grill, per the G23 precedent). Canonical statement: design_doc.md §3.1 (threat-display-and-inspection paragraph); §14 gray-box inventory and pre_prompt reconciled.
- **Q1 = D:** the enemy threat-range overlay exists in both forms — per-enemy highlight (the reference's `highlight_enemy` pattern) and a global union toggle. It paints results of the new `get_threat` sim query (added to the D5 View→Sim surface, provisional name); the view computes nothing. Distinct from and unaffected by G28's no-intent-display ruling — range, not intent.
- **Q2 = A:** on fog chapters the overlay is computed from visible enemies only; hidden enemies contribute nothing (G12's no-ghosts rule upheld — an overlay must not reveal hidden units through their ranges); the overlay under-reports honestly and ambush risk stays real.
- **Q3 = A:** unit inspection discloses the §3.3 stat block only; raw damage-table rows/columns are never player-facing. Concrete damage numbers exist solely in the forecast popup against a real attacker/defender pair — G16 Q6's popup boundary is now also the disclosure boundary.
- All rulings by owner, no rationale stated.

### G32 — Farming-replay entry, "rescaled enemies" struck, and the between-mission loop (reference-mining issue 35)
Ruled by owner, 2026-08-12 (submitted under "34" — applied to 35, whose template the rulings match; the standing misfiling precedent. A first submission carried a stray Q4 against a three-question template and gate-failed with no edits; this resubmission — including Q3 changed from A to B — is the authoritative set). Issue: `.scratch/reference-mining/issues/35-campaign-flow.md`. Canonical statements: design_doc.md §8.1 (replay entry + the loop) and §6 (farming wording + save writes).
- **Q1 = A:** farming replays launch from cleared campaign-map nodes — the node is the only entry point; pre_prompt's camp farming option is reconciled away (no camp farming menu exists).
- **Q2 = C:** "rescaled enemies" struck from §6 — a replay is the story battle unchanged; the reduced yield (G10) is the only difference; §7's never-dynamic-scaling rule stands untouched and the chapter schema gains no replay-variant field.
- **Q3 = B:** the between-mission loop is map-centric — completion → debrief → campaign map; camp is optional, entered from the map at will, freely re-enterable. The campaign save is written on mission completion *and* on every camp exit (§6 amended from camp-exit-only), so skipping camp never loses progress.
- All rulings by owner, no rationale stated.

### G33 — Item-system parameters (grilling issue 38)
Ruled by owner, 2026-08-12. Issue: `.scratch/reference-mining/issues/38-item-system-parameters.md` (the follow-through spawned by G26). Canonical statements: design_doc.md §4 (parameters bullet in the Items block); §3.3, §3.5, §5, §8.3 carry the per-topic statements.
- **Q1 = B:** each item is its own data file under `data/items/` — the per-General pattern; adding an item is adding a file, zero code.
- **Q2 = C:** the shop catalog is unlock-based — items enter on first story clears via §8.3's `unlocks` field (the G14 Q5 pattern; farming replays never re-fire) and stay purchasable thereafter.
- **Q3 = A:** the shared pool is unlimited and fully available in every battle; no deployment loadout step. Upgrades G26's any-unit-draws simplest reading to ruled.
- **Q4 = A:** throw range = the thrower's `throwing` stat in tiles, directly; self-use is range 0. Upgrades G26's stat-is-range-not-amount simplest reading to ruled (§3.3 annotation updated).
- **Q5 = B:** effect-type vocabulary reserved up front (the G29 Q2 pattern): `heal` implemented; `cure` and `buff` named now, unimplemented. The two reserved names come from the option's example set — correct if different names are wanted.
- **Q6 = A:** items are side-symmetric — chapter data may grant the enemy an item pool (§8.3 field added); the coordinator values item use through the G17 Q6 active-valuation mechanism (§3.5 annotated); the exact-choice enemy-phase test fixture includes items when present.
- **Q7 = A:** mage-heal scaling reuses the D12 level package — heal = base × `power_mult`; no separate heal curve (D12 annotated).
- **Q8 = A:** UI surface is minimal — a camp-shop submenu and an "Item" entry in the battle action menu (pool list → target selection over throw range); the deployment screen is untouched. Gray-box ColorRect lists; the issue-36 salvage shapes are the rebuild references.
- Propagation note: conventions.md §4's `data/` tree gained `items/` (one file per item) under §11's amendment protocol — conventions → v1.3, reason: G33 Q1.
- All rulings by owner, no rationale stated.

### G34 — Schema meta-conventions (schema-forge issue 39)
Ruled by owner, 2026-08-12. Issue: `.scratch/schema-forge/issues/39-schema-meta-conventions.md`. Canonical statements: this entry (shape rulings) and design_doc.md §3.5 (the amended board-position key); `docs/data_schemas.md` §0 is the derived consolidation (per Q1).
- **Q1 = B:** `docs/data_schemas.md` is a **derived document** — every schema shape traces to a ruling or a DECISIONS-logged shape choice; where it disagrees with design_doc.md or DECISIONS.md, they win. The conventions.md two-authority preamble is unchanged; no third authority exists.
- **Q2 = A:** `/data` files carry **no `schema_version`** — repo data ships in lockstep with the code that reads it; conventions §7's version key remains a save-file (user://) rule only.
- **Q3 = A:** every field a schema defines is **required-explicit** in authored files — no loader-supplied defaults; design-optional features are authored as explicit empty/off values (e.g. `"abilities": []`, `"fog": false`). A missing key is a load error (composes with Q7). Design_doc's "optional" wording (§3.3 abilities, §8.3 loss/enemy-item-pool) describes design optionality, not key absence.
- **Q4 = B:** **underscore-prefixed annotation keys** (e.g. `"_placeholder"`, `"_note"`) are legal in any data file, carry no game meaning, and are skipped by the loader — the mechanism for marking unruled placeholder values in example files (schema-forge placeholder policy).
- **Q5 = A:** in one-file-per-entity folders, the file carries `"id"` and the loader **validates `id` == filename** (sans `.json`); mismatch is a load error naming both.
- **Q6a = C (owner's words: "Revert G21 ruled (row, col) order"):** all tile/board coordinates in data are **`[x, y]` arrays**, and G21 Q5's universal board-position key is **amended to (x, y) — lowest x, then lowest y** — one coordinate order project-wide, matching Godot's `Vector2i`. Derived reading logged per this file's protocol (correct if wrong): "revert" = reverse — the comparison order itself flips to x-first; not a notation-only restatement of the old row-major order.
- **Q6b = A:** confirmed — localization keys use the singular-domain dot-scoped scheme (conventions §6: `general.washington.name`, `unit.line_infantry.name`), and every displayable entity's field is named `name_key`.
- **Q7 = A:** **unknown keys are load errors** (strict validation). Derived composition logged per this file's protocol (correct if wrong): Q4 = B requires the underscore prefix as the whitelisted exception — strict applies to every non-underscore key; this composition is materially Q7's option C and was applied as the only reading coherent with Q4 = B.
- All rulings by owner, no rationale stated beyond Q6a's quoted directive.

### G35 — The single-unit paradigm: squads/singles merged, degradation abolished, counter stat added (wayfinder single-unit-shift, ticket 50)
Ruled by owner, 2026-08-12. Issue: `.scratch/single-unit-shift/issues/50-unified-unit-ruling.md` (charter rulings: `.scratch/single-unit-shift/map.md`; the line-referenced contradiction inventory: ticket 49 findings). Canonical statements: design_doc.md §3 (tiers, pipeline, counter rule, degradation door-closed), §3.2 (the eight-example set), §3.3 (`counter_mult`, max_hp framing).
- **Charter (owner, wayfinder charting session, 2026-08-12):** squads and singles merge into one tier; no HP-degradation anywhere; individual-unit fiction — squad vocabulary purged (roster renames and content beats: ticket 51).
- **Q1 = B (word: "unit"):** the two tiers are **unit | general** — `enum Tier { UNIT, GENERAL }` (conventions §1). The mantra ("Squads degrade. Singles endure. Generals grow.") is dropped with no replacement slogan; §2's pillar reads "Two unit tiers, each defined by one rule" (units: per-battle; Generals: persistent growth).
- **Q2 = A:** the pipeline change is the pure deletion of the `hp_f` term; armament, power_mult, ability modifiers, terrain, defense, floor all stand unchanged.
- **Q7 = B (owner's words: "Add a stat for counter attacking. Some units should be better at counter-attacking than others"):** counters are governed by a **per-unit counter stat**, not a global constant. Simplest reading, logged per this file's protocol (correct if wrong): field `counter_mult`, a multiplier folded into the counter's run of the standard pipeline, 1.0 = neutral, values are data authoring. **Counters are exempt from the minimum-1 rule and may deal 0** (owner-ruled consequence); the min-1 lock narrows to *initiated* attacks. D9 amended accordingly.
- **Q3 = A:** the canonical example set is a minimal-edit derivation — old examples 1/5/7 promoted to full strength (now 1/4/6), old 2 rebuilt as the stacked min-1 case (disadvantage × mountain), old 3 deleted (it demonstrated only the dead squads-degrade/singles-don't asymmetry), old 4/6 kept (now 3/5), plus two new counter examples (7: `counter_mult` applied; 8: a zero-damage counter is legal). Eight examples, design_doc §3.2; CLAUDE.md and pre_prompt mirror them.
- **Q4 = C:** the Advance Wars citation is dropped from the high concept (design_doc §1, CLAUDE.md, pre_prompt) — Fire Emblem is the sole named lineage; §10's risk line reworded to two tiers.
- **Q5 = B:** §3.3's max_hp framing no longer quotes values (the "(squads 10, singles 25)" parenthetical dropped); starting values live in unit data files. G2 Q1a annotated — its ruling stands, its per-tier framing is historical.
- **Q6 = A:** the door is closed — design_doc §3 + §9 and CLAUDE.md's never-implement list now state that no mechanic may scale damage with either side's remaining HP without a new ruling.
- Propagation: design_doc → v1.7; conventions → v1.4 (§1 enum, §2 inheritance example, §4 `units/` tree note pending schema-forge ticket 40's file-layout decision, §8 test list) under §11's protocol; D7 mirror updated; D8 superseded; D9 amended; D13 annotated; signal contract `squads_lost` → `units_lost` (provisional-name convention; loss scope follows ticket 51's secondary-objective ruling).
- **Deliberately NOT propagated here** (content re-authoring parked to wayfinder ticket 51, not vocabulary): the prototype roster names (Line Infantry, Riflemen, Cavalry Squad, Cannon Crew), ch1 "squads only" / ch2 "introduce singles" chapter beats (design_doc §8.2 table, pre_prompt maps), Washington's Command Aura "adjacent friendly squads" scope (design_doc §5 aura example + pre_prompt), the exact loss-scope of the preservation secondary, §7's "redcoat squads" narrative framing, §13 sprite counts.
- Rationale stated only where quoted (Q7); all other rulings by owner without stated rationale.

### G36 — Individual-unit roster renames & content beats (wayfinder single-unit-shift, ticket 51)
Ruled by owner, 2026-08-12. Issue: `.scratch/single-unit-shift/issues/51-roster-renames-and-content-beats.md` (the G35 follow-through; charter: individual-unit fiction). Canonical statements: design_doc.md §4 (renamed slot mapping), §5 (target-filter mechanism), §7 ("redcoats"), §8.2 (chapter roles), §8.3 (preservation-secondary scope), §12 item 2, §13.
- **Q1 = B (owner's words):** Cavalry Squad → **Cavalryman**; Cannon Crew → **Cannoneer**; Riflemen → **Rifleman**; **Line Infantry kept**. Death Knight, Bound Golem, Arcane Sentinel confirmed unchanged. The redcoat-recolor pattern (same data, faction tint) is untouched. *(Update 2026-08-13, G40 Q2: superseded on the data side — redcoat variants now carry their own ids/entries and damage-table rows; the visual recolor stands.)* No data ids exist yet, so the renames are doc-only — ids will be authored fresh at schema time (`line_infantry` examples in conventions §5 / data_schemas §0 remain valid).
- **Q2 = C:** chapter composition beats are dropped — beats are objective-only. Ch1 "Tutorial — rout objective"; ch2 "Defend objective" (design_doc §8.2 table); pre_prompt's Lexington/Bunker Hill sketches reworded (Bunker Hill keeps its prototype "one deployable General" pacing).
- **Q3 = C:** the preservation secondary's loss scope is **per-chapter authored** — the secondary's chapter data declares which slot categories count as losses. `units_lost` in the mission summary reports total non-General losses regardless; evaluation reads the authored filter. Exact field shape: schema-forge ticket 44 (via reconciliation ticket 54).
- **Q4 = C:** abilities declare a **target filter** in data — an aura's affected set is authored, never hardcoded (design_doc §5 targeting bullet). Washington's Command Aura wording updated in pre_prompt; its actual filter contents are authored when /data lands. Exact filter vocabulary: schema-forge ticket 42 (via ticket 54).
- **Q5 = confirm:** the §12 item-2 wording from the G35 apply stands; its pointer now records the G36 renames.
- **Q6 = B:** §13's sprite estimate reworded to "~8–10 generic types" matching §12's target.
- **Q8 = B (owner's choice: "redcoats"):** §7's "redcoat squads plus his summoned constructs" → "redcoats plus his summoned constructs" — the prose-level purge is complete.
- Deliberate survivals (historical citations, not renamed): "Cavalry Squad's 'bonus vs. Riflemen' was cut" (design_doc §3.3, G2 Q3), DECISIONS G20/G22 assignment lists as originally ruled, design_doc §7's lowercase "riflemen/skirmishers" Daniel Morgan flavor.
- design_doc → v1.8. All rulings by owner, no rationale stated.

### G37 — Supersession-annotation depth & single-unit-shift verification close-out (wayfinder single-unit-shift, ticket 52)
Ruled by owner, 2026-08-12. Issue: `.scratch/single-unit-shift/issues/52-propagate-design-doc.md`.
- **Q1 = A:** the existing annotation set suffices — the directly-affected D-entries (D7, D8, D9, D11, D13) and G2 Q1a carry Update lines; historical G-entries (G6, G8, G9, G11, G16, G17, G19, G20, G22) stand unannotated as append-only history, per the G34/G21 precedent. No blanket back-annotation policy is adopted; readers reach current truth via design_doc v1.8 and G35/G36.
- **Q2 = B:** the derived-doc verification ticket (single-unit-shift 53) stays separate; not folded into 52.
- Verification record: the five-doc residual sweep (2026-08-12) found **zero live superseded statements** across design_doc.md, CLAUDE.md, pre_prompt.md, conventions.md, data_schemas.md; every remaining old-paradigm string is a G35/G36 supersession note, a ruled survival (findings-49 appendix + the G36 survivals list), or this file's historical record.
- All rulings by owner, no rationale stated.

### G38 — Derived-doc verification close-out; pre_prompt formula summary completed (wayfinder single-unit-shift, ticket 53)
Ruled by owner, 2026-08-12. Issue: `.scratch/single-unit-shift/issues/53-propagate-derived-docs.md`.
- **Q1 = A:** the independent derived-doc sweep closes the ticket. Result: zero live superseded statements in CLAUDE.md / pre_prompt.md / conventions.md / data_schemas.md — every hit is a G35/G36 supersession note, a ruled survival, or generic-English "single". The three derivation-sensitive canonical examples (1, 2, 8) verified character-identical across design_doc §3.2, CLAUDE.md, and pre_prompt.
- **Q2 = B:** a pre-existing variance surfaced by the sweep is fixed — pre_prompt's damage-formula summary line had always omitted the power/ability multiplier term that design_doc §3 and CLAUDE.md carry; the term is restored, making all three formula statements structurally identical (pre_prompt's deferral note to design_doc §3 as canonical stands unchanged).
- All rulings by owner, no rationale stated.

### G39 — Schema-forge reconciled to the single-unit paradigm; effort complete (wayfinder single-unit-shift, ticket 54)
Ruled by owner, 2026-08-13. Issue: `.scratch/single-unit-shift/issues/54-reconcile-schema-forge.md`. Tracker-artifact reconciliation only — no design-doc content changed.
- **Q1 = A:** the five-item reconciliation applied — schema-forge map (destination wording; the secondaries fog note updated, its G-ruling half now answered by G36 Q3), ticket 40 (one-tier file-layout question; **`counter_mult` added to its ruled stat-block list** — it predated G35; renamed roster; recolor wording), ticket 42 (filter-based effect examples; the G36 Q4 target-filter vocabulary added as question 2b), ticket 44 (Q5 reduced to field grammar; "squads only" dropped from the deliverable per G36 Q2), reference-mining 37 (paradigm warning against re-importing squad-era vocabulary). No schema-forge decision was answered — questions reworded, options left open.
- **Q2 = A:** the single-unit-shift wayfinder map is **complete** — destination reached 2026-08-13; all six tickets closed; audit trail G35–G39.
- All rulings by owner, no rationale stated.

### G40 — Unit types & the combat tables (schema-forge issue 40)
Ruled by owner, 2026-08-13. Issue: `.scratch/schema-forge/issues/40-unit-types-and-combat-tables.md`. Canonical statements: this entry (shapes); `docs/data_schemas.md` §1–§2 is the derived consolidation; example files landed under `data/units/` and `data/combat/`.
- **Q1 = other (owner's words: "Removed squads. Adjust documents as necessary"):** the unit domain is one per-domain file, `data/units/units.json` — the G35 merge reaches the file layout; conventions §4's pending note finalized (conventions → v1.5 under §11's protocol, reason: this ruling). Derived simplest readings logged per this file's protocol (correct if wrong): unit records carry **no `tier` field** — tier derives from home (`units.json` → unit; `generals/<id>.json` → general; the loader assigns the §1 `Tier` enum); the file is one object keyed by unit-type id (key uniqueness is structural).
- **Q2 = B:** redcoat variants are **separate ids/entries** (`redcoat_line_infantry`, …), each with its own damage-table row and column. This supersedes the "same data, different faction tint" reading (pre_prompt annotated; G36 Q1's recolor survival note updated) — the *visual* recolor stands; the data does not mirror. Derived reading logged (correct if wrong): unit-type records carry **no `faction` field** — which side fields a type stays instance-level in chapter rosters (§8.3); the ids differentiate the variants.
- **Q3a = B:** `damage_table.json` is a **flat record list** — `{"matchups": [{"attacker": <type>, "defender": <type>, "value": n}, …]}` (container key `matchups`: shape detail logged with this entry). The D7/§3 pseudocode's 2-D indexing remains descriptive of the lookup, not the storage.
- **Q3b = A:** the matrix must be **complete at load** over every declared `type` — units and Generals alike (G18's growth included); a missing pair (or a duplicate pair) is a load error naming both types.
- **Q4 = A:** `armament_triangle.json` holds the **three named multipliers** (`advantage` / `neutral` / `disadvantage` — ruled values 1.5 / 1.0 / 0.5, §3.1); the rifle→melee→musket→rifle cycle is expressed in sim code, which maps an armament pair onto one of the three constants. The locked cycle is not expressible — and therefore not corruptible — in data.
- **Q5a = C:** impassable terrain cost is the **numeric sentinel `-1`**. Derived reading logged (correct if wrong): −1 exactly (not a "huge cost"), tested as impassable and never used arithmetically — a ban remains absolute regardless of movement budget (G20's "ban is a special case of cost" holds at the schema level).
- **Q5b = A:** terrain fog-vision data is **two flat fields on every terrain record**: `"concealment"` (bool — occupants visible only from adjacent tiles, §3.6) and `"sight_modifier"` (int — tiles added to the occupant's sight radius; negative legal); neutral values `false` / `0` are authored explicitly per G34 Q3. Field names are authoring — correct if different names are wanted.
- Example-file authoring notes (placeholder policy, G34 Q4): `units.json` carries the G36 roster (Line Infantry, Rifleman, Cavalryman, Cannoneer, Death Knight, Bound Golem, Arcane Sentinel) plus the four redcoat variants — stat values are placeholder authoring except ruled content (G20 move_class assignments, D11's Cannoneer `[2,3]` counter_ranges); the damage-table example is uniform placeholder values; `armament_triangle.json` quotes the ruled constants exactly; `terrain.json` quotes the §3.4/G20 table exactly, with forest concealment and mountain sight as the §3.6 examples authored.
- Rationale stated only where quoted (Q1); all other rulings by owner without stated rationale.

### G41 — General files (schema-forge issue 41)
Ruled by owner, 2026-08-13 (first submission gate-failed on missing Q4; resubmitted complete). Issue: `.scratch/schema-forge/issues/41-general-files.md`. Canonical statements: this entry (shapes); `docs/data_schemas.md` §3 is the derived consolidation; examples: `data/generals/washington.json`, `data/enemy_generals/cornwallis.json`.
- **Q1 = A:** level packages are **per-General** — each General's file authors its own curve: `"level_packages"` keyed `"1"/"2"/"4"` (all three required), each with `power_mult`, `hp_bonus`, `defense_bonus` explicit (G16 Q4's bump included as a field, 0 when ungranted — G34 Q3). No shared curve file exists; D12's "the level packages" now names the *mechanism*, and G8's enemy-General "reuse" means reusing the mechanism through their own files. Derived readings logged per this file's protocol (correct if wrong): package values are **absolute in-effect values at that level** — the sim reads the highest package level ≤ the General's current level; no runtime stacking of increments.
- **Q2 = A:** `"level_abilities"` is a level-keyed map, keys ⊆ `"3"/"5"`, values ability ids; the empty object is legal (no abilities authored yet). The §3.3 `abilities` field remains on General files for innate abilities (`[]` on the prototype roster). Character-scene ids are **derived, not stored** — derivation rule logged as shape detail (correct if wrong): scene id = `<general_id>_l<level>` (e.g. `washington_l3`; locale keys `scene.washington_l3.*`), validated against `data/scenes/` once the scene schema lands (ticket 45).
- **Q3 = C:** enemy Generals live in their **own folder with the identical schema**. Derived reading logged (correct if wrong; flagged at the gate-fail and unobjected): the folder is `data/enemy_generals/`, one file per enemy General; G34 Q5's id==filename validation applies. Conventions §4 amended under §11's protocol (→ v1.6, reason: this ruling). Neither folder's schema carries a side/faction field — the folder is the side statement.
- **Q4 = confirm (owner's words: "Campaign Save"):** the boundary is stated in the spec section — current level, alive/dead, and revival state live in the **campaign save**; per-appearance enemy-General levels and retreat events live in **chapter data** (G8); none of it ever appears in `generals/` or `enemy_generals/` files.
- Example-file authoring notes (placeholder policy, G34 Q4): Washington's base stats, armament (melee), and package values are placeholders (move_class `infantry` is ruled — G20); Cornwallis (§7's named British command) is the `enemy_generals/` example — stats, armament, and move_class all placeholder, `level_abilities` empty. Both `type`s (= id) joined the damage table, regenerated complete at 13×13 (G40 Q3b).
- All rulings by owner, no rationale stated.

### G42 — Ability & item effect grammar (schema-forge issue 42)
Ruled by owner, 2026-08-13 (two gate-fails on a missing Q1b; the complete resubmission — including Q2 changed from A to B — is the authoritative set, per the G32 precedent). Issue: `.scratch/schema-forge/issues/42-ability-item-effect-grammar.md`. Canonical statements: this entry (shapes); `docs/data_schemas.md` §4–§5 is the derived consolidation; examples: `data/abilities/abilities.json` (all six ruled abilities), `data/items/healing_poultice.json`.
- **Q1 = A:** an ability's `effects` is an **ordered list of typed records** — list order is D10's "data-declared order". The effect-type vocabulary is reserved up front (the G29/G33 pattern): `damage_mult` (value = multiplier), `move_bonus` (value = tiles), `table_damage` (value-less — each target resolves through the §3 pipeline), `heal` (see Q4). Adding a type is a ruling + sim work, not a data-only add.
- **Q1b = A:** rule exemptions live in an ability-level `"exemptions"` list, distinct from effects (G7 Q4's whitelist-of-flags language). Derived flag names logged (correct if wrong): `"no_counter"`, `"move_again"`.
- **Q2 = B:** effect conditions are **structured predicate records** — `"condition": {"subject": "target", "state": "engaged_this_turn"}` (Vive la Liberté's case). The axes are closed and enumerable (no logic in data): subjects `self | target`; states implemented: `engaged_this_turn` (§5 per-turn state). Derived reading logged (correct if wrong): `"condition": null` = unconditional (consistent with Q3a's null), and every effect record carries the key (G34 Q3). New subjects/states are spec additions with sim support, never free-form data.
- **Q2b = A:** `target_filter` is a fixed-axes object, every axis explicit: `side` (`friendly | enemy | any` — **relative to the ability's owner**, G7 Q6 symmetry), `tier` (`unit | general | any`), `slot_category` (`general | tank | infantry | any`). Adjacency/range remains the targeting shape's job (G36 Q4 framing). Derived semantics logged (correct if wrong): `on_attack` abilities are **owner-scoped** — their effects govern the owner's own attack; shape and filter are authored neutral (`single`/0, all-`any`) and inert for them.
- **Q3a = C:** `uses_per_mission: null` = unlimited (the explicit-field encoding G34 Q3 demands; Key & Kite and Lightning Rod author `1`).
- **Q3b = A:** `charge_conditions` is reserved now — present as `[]` on every ability; record shape spec'd unimplemented: `{"event": "enemy_killed" | "friendly_killed", "effect": "restore" | "grant", "amount": n}` (events from G7 Q3's owner's words). No authored ability uses one yet.
- **Q4 = A:** the ability heal record is `{"type": "heal", "base": n, …}` — `base` × the General's `power_mult` (G33 Q7); item heals use `amount` (fixed, G26). The field name carries the fixed-vs-scaled distinction.
- **Q5 = A:** item files share the typed-record effect shape — `"effect": {"type": "heal", "amount": n}`; item-side legal types: `heal` implemented, `cure`/`buff` reserved (G33 Q5). Item fields: `id`, `name_key`, `price` (souls), `effect`.
- Example-file authoring notes (placeholder policy, G34 Q4): ability ids authored as `command_aura`, `crossing` (already referenced by `washington.json` — G41), `lightning_rod`, `key_and_kite`, `ride_through`, `vive_la_liberte` (ascii id, accent dropped per conventions §1); kit numbers quote pre_prompt exactly (×1.2 aura, +2 move, line 2, radius 3 + no_counter, move_again, ×1.3 vs engaged); the poultice's price/amount are placeholders.
- All rulings by owner, no rationale stated.

### G43 — Map authoring pipeline: Tiled, .tmj-as-canonical (map-authoring ticket 58)
Ruled by owner, 2026-08-13 (first submission paired Q1=A with Q2=C — flagged incoherent at the gate, the G18 precedent; the resubmission changed Q1 to C, making the set coherent). Issue: `.scratch/map-authoring/issues/58-pipeline-ruling.md`; evidence: findings 55/56/57 (`.scratch/map-authoring/findings/`). Canonical statements: this entry; design_doc §8.3 (map-file bullet); conventions §3 (authoring-tools clause) + §4 (`maps/` line).
- **Q1 = C:** battle maps are authored in **Tiled** (mapeditor.org; actively maintained, 1.12.2 as of 2026-05). Terrain = one tile layer over a tileset whose 8 tiles carry a `terrain` custom property (enum-guarded at author time); start/spawn tiles = point objects; named regions and activation areas = named rectangle objects (finding 57's native mapping).
- **Q2 = C:** **Tiled's JSON is the canonical map format** — `data/maps/<id>.tmj`, checked in, no conversion step, no exporter, no derived artifact; DataLoader parses `.tmj` directly (masks GID flip bits `0xF0000000`, resolves the single `firstgid`, converts object pixel coords → tile coords) and hands /sim plain dictionaries — /sim purity (R1) untouched. **Knowing exceptions, ruled with this:** D1 annotated — maps are JSON but follow Tiled's documented schema, not DoT's (the one-format rule narrows to one *encoding*; every other domain stays DoT-schema JSON); **G34 §0's meta-conventions and Q5's in-file `id` do not apply to `data/maps/`** — a `.tmj` has no `id` key, so map id = filename stem (chapters reference it as such), and Tiled's own key vocabulary/versioning governs the file. The repo inherits Tiled's documented deprecation cycle as a loader-maintenance obligation (worst historical break: the `type`→`class`→`type` rename, 1.9/1.10 — finding 57).
- **Q3 = A (recomposed, logged correct-if-wrong):** with no derived artifact there is nothing to drift — A's substance lands as **manual workflow plus a headless validation test**: no editor hooks, no pre-commit machinery; the `godot --headless` suite validates every `.tmj` against the DoT authoring profile — `orientation: orthogonal`, `infinite: false`, `encoding: csv`, no flipped/rotated terrain tiles, exactly one terrain tile layer, single **embedded** tileset (derived reading — no external `.tsx`/`.tsj`), every tile's `terrain` property in `terrain.json`'s id set, all objects grid-aligned (reject at x=13.5px), object types from the profile vocabulary. The profile's full spec is schema-forge ticket 43's resumed deliverable.
- **Q4 = B:** conventions gains an explicit **authoring-time tools clause** (v1.7, §11 protocol): tools that exist only at edit time — external editors like Tiled, first-party `@tool`/EditorScript code — are outside the no-plugins rule, which governs runtime/plugin code; Dialogic (G29) remains the sole runtime-plugin exception. CLAUDE.md's derived summary annotated to match.
- Downstream: map-authoring ticket 59 now authors Lexington Green as a real `.tmj` and reacts; schema-forge ticket 43 resumes after 59 to spec the `.tmj` authoring profile + validation as the map schema section (its map-vs-chapter geometry questions carry over into object-layer vocabulary).
- All rulings by owner, no rationale stated.

### G44 — Map scale: per-archetype bands, battle-feel levers, zoom+minimap, movement retune (map-authoring ticket 62)
Ruled by owner, 2026-08-14. Issue: `.scratch/map-authoring/issues/62-map-scale-ruling.md`; evidence: findings 60 (measured genre benchmarks) and 61 (internal ripple analysis). Spawned by the owner's directive (2026-08-13): "Maps should feel larger like you are actually fighting a battle." Canonical statements: design_doc §8 (map-scale paragraph) and §14 (amended camera spec).
- **Q1 = B:** map sizes follow **per-archetype bands** — skirmish/tutorial **16×12–20×16**, standard battle **24×20–32×24**, set-piece **32×24–40×30**. Band assignment is per-chapter authoring; G15 Q3's no-hard-bounds ruling stands (bands are ruled authoring practice, not engine limits). The measured canon anchors the bands (mid-campaign 20×20–32×32 across 25 years of the genre; finding 60).
- **Q2 = A + C (combined):** the battle feel comes from **both** levers — per-chapter slot caps scale with the envelope toward genre density (~1 enemy per 20–35 tiles; held-density bands per finding 61 §5), **and** standard/set-piece chapters carry a **multi-front composition mandate**: simultaneous objectives/fronts and reinforcement-wave pressure (the documented FE6-Ch11A/Gronder pattern), staged through the existing levers (activation groups, spawn events, strategic wake). Dead-space maps are the documented failure mode this mandate exists to prevent.
- **Q3 = D:** the presentation spec gains **a zoom-out toggle and a minimap/overview** — §14 amended under this ruling (design_doc → v2.0); gray-box implementations are ColorRect-grade (scaled canvas + schematic overview). Pan-only was viable only to ~2 screens (finding 61 §2); standard-band maps run 2.1–3.4 screens.
- **Q4 = B:** movement stats retune **upward** with the envelope — the intent ruling. Magnitude protocol-authored per this file's protocol (correct if wanted): **+1 to every unit type** — `data/units/units.json` moves 3/4/6 → **4/5/7** (values remain placeholder data). Sight (3–4) deliberately untouched — it feeds fog feel and threat ranges; retuning it is future authoring against the ruled bands.
- **Q5 = A:** the envelope statement is **canonical in design_doc §8**, with pre_prompt's "~12×12 to 16×16" prototype line reconciled to it. Q5(b) — Lexington Green's exact dimensions — was not named by the owner; protocol-authored (correct if wanted): **20×16**, the top of the tutorial band (the rejected 12×12 now sits below every ruled band); map-authoring ticket 59 re-sketches at 20×16 and is the owner's reaction point.
- Consequences recorded, not separately ruled: defend/survive clocks and enemy staging must be co-authored with march distance at standard+ bands (finding 61 §1 — the 8/10-turn prototype clocks are tutorial-band numbers); exact-choice AI test fixtures stay on deliberately small boards (nothing requires envelope-sized fixtures — G17 unaffected); the §10 content estimate (2–3 months, 14 maps) predates this scope growth (the G35-precedent note); the deployment screen inherits the multi-screen camera at scaled caps.
- All rulings by owner, no rationale stated beyond the quoted directive.

---

## Reference-project engine migration (Godot 3.x → 4.6.1)

Applied to the imported Fire Emblem reference clone under `engine/scenes/assets` on branch `reference_project`. Not game-design decisions — recorded here as the audit trail for the conversion. Date: 2026-07-26/27.

Update 2026-08-11 (ruling G22, grilling issue 24): the clone was ruled out of the tracked repo — it relocates to `fe_reference/`, an untracked gitignored local folder (owner-executed). These M-entries stand unchanged as the audit trail of the conversion as it happened; the location they describe is historical.

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

### M11 — Viewport size, RichTextLabel + JSON API, shader params
- **Small resolution / misaligned assets:** there was no `[display]` section, so the game ran at the default ~1152×648 while the camera and world are authored for **240×160** (`main_camera.gd` `CAMERA_WIDTH=240`, `CAMERA_HEIGTH=160`; the title `Fog` sits at (120,80), the 240×160 centre). Added `[display]` with `viewport_width/height=240/160`, a 960×640 (4×) window override, and `stretch/mode="viewport"`, `aspect="keep"`. This restores the intended pixel-perfect view and realigns sprites with the map (the camera math now matches the viewport).
- **`RichTextLabel.percent_visible` removed in Godot 4** → `visible_ratio` (29 sites across Message System + Shop UI, `.gd` and `.tscn` animation tracks/props). This was the cutscene-text crash.
- **`JSON.new().stringify()` is static in Godot 4** → `JSON.stringify()` (7 sites in save system).
- **`shader_param/` → `shader_parameter/`** (26 sites) — the deprecated-material warning; the title's procedural "fog" (a cyan fbm-noise `canvas_item` shader on a Sprite2D) now applies its params correctly. Note: that fog is an intentional atmospheric effect, not a stray asset — remove the `Fog` node from `Intro Screen.tscn` if it isn't wanted.

### M12 — GDScript warning cleanup (batch 3)
Unused `_input(event)`/`_process(delta)` params underscore-prefixed (Cell, battlefield_info, Status Screen, Intro Screen); unused item `special_ability` params (Iron Lance, Unarmed) and `allow_selection(anim_name)`, `unit_movement_system_cinematic` `h` prefixed; shadowed params renamed (`Cell.init(...)` → `p_*`, `combat.start_combat(current_combat_state)` → `initial_combat_state`); dead `signal scene_loaded` removed.

### M13 — Title menu regression (fog wash-out + Label alignment)
Diagnosed by capturing an in-engine screenshot (`get_viewport().get_texture().get_image()` via a temporary autoload). The New Game/Load Game/Options menu was rendering fine, but the `Fog` node (the procedural cyan-noise Sprite2D, the last child of `Intro Screen` so it draws on top) sat centred over the menu and washed it out — once M9 disabled the world-map camera and M11 set the 240×160 viewport, the fog was no longer offset off-screen. Hidden it (`visible = false` on the `Fog` node); re-enable it earlier in the child order if the atmosphere is wanted.
- **`Label.align` / `valign` removed in Godot 4** → `horizontal_alignment` / `vertical_alignment` (same int values). The converter missed all of them: **165 + 168 across 43 scenes**. Fixed project-wide; this also corrects mispositioned text elsewhere in the UI.
- Intro menu input moved from `Input.is_action_just_pressed(...)` inside `_input(event)` to the correct `event.is_action_pressed(...)`.

### M14 — GDScript warning cleanup (batch 4)
`special_ability` unused params (`Iron Sword`, `Rapier`, `Silver Lance`, `Steel Sword`) underscore-prefixed.

### M15 — Reverted the align/valign "fix" (it regressed the UI)
M13 converted `align`/`valign` to `horizontal_alignment`/`vertical_alignment` preserving the authored (mostly centre) values. That was wrong for this project: 153 Labels across 31 scenes use oversized rects scaled to ~0.2, and these layouts were authored/tested against Godot 4 *ignoring* the old `align` (i.e. rendering left/top). Centering pushed text out of place — most visibly the title menu vanished (confirmed by comparing to the user's working commit `8fc0340`). Reset all `horizontal_alignment`/`vertical_alignment` to `0` (left/top) across every scene: valid Godot 4, no load warnings, and byte-equivalent to how `8fc0340` rendered. Proper per-screen alignment is a later UI-tuning task, out of scope for "make it run". The title `Fog` stays hidden (M13).

### M16 — Title menu readability (dark backing panel)
Diagnosed with an in-engine screenshot: the option Labels render fine, but they are white text positioned over the brightest part of the title art (the lit statue), so they wash out. At `8fc0340` the (disliked) `Fog` overlay darkened the background enough to read them; hiding the fog (M13) removed that. Added a semi-opaque black `ColorRect` ("Menu BG", alpha 0.9) behind the option Labels inside the `Options` control — it restores local contrast without the fog's noise. Cursor/text sizes are unchanged (`hand.png` is 15×12; option Labels are scale 0.2 as authored). If preferred, alternatives are: repositioning the menu into the dark right/lower area, or re-enabling the fog.

### M17 — Title "no input" was window focus; reverted debug/contrast experiments
The title menu "not responding / not visible" turned out to be the F5-launched game window not having keyboard focus (the keypress that reveals the options never registered) — not a code issue. Reverted the experiments made while chasing it: removed the temporary on-screen input-debug overlay, the `Menu BG` dark panel, and the Label outline overrides; reverted the intro input back to `Input.is_action_just_pressed`. Kept: the `Fog` hidden (M13, user preference) and the Label `horizontal/vertical_alignment = 0` baseline (M15). If the white menu text is hard to read against the bright art, re-adding a contrast aid or the fog is a quick change.

### M18 — chapter_background camera enable ordering + unused param
`chapter_background.gd` did `BattlefieldInfo.main_game_camera.enabled = true` before instancing the level, but the game camera registers itself (`main_game_camera`) in its own `_ready` — so on chapter 1 the reference was null (crash). Moved the enable to after the level is added and guarded it with `is_instance_valid`. Also prefixed the unused `delay` param → `_delay`.

### M19 — Battle maps are Tiled .tmx (Godot-3 pipeline); crash made graceful
Reaching a battle crashes because the 4 battle maps (`assets/levels/level{2..5}/*.tmx`, with external `.tsx` tilesets) are **Tiled maps**. Godot 3 imported them via a Tiled importer plugin into `.import/*.scn`; Godot 4 has no built-in Tiled importer and that cache is gone, so `Level*.tscn` (which instance the `.tmx` as a PackedScene) fail to load. Worse, `Level*.gd` reads the *exact node structure* the Godot-3 importer produced — a `Background` tile layer plus `CellInfo`/`Allies`/`Enemies` object groups whose children carry per-object `get_meta(...)` (aiType, Identifier, terrain, etc.) — so even a third-party Godot-4 Tiled importer (different output) wouldn't satisfy the game logic without rewriting the level scripts. There is also a missing `/root/Level` container the chapter flow adds levels to.

Made `chapter_background.gd` fail loudly (guarded `load()==null` and `/root/Level` missing with `push_error`, no crash) instead of hard-crashing. Fixed the batch's warnings (Level3.gd `cell` iterator → `grid_cell`; removed dead signals `mapInformationLoaded`, `move_camera_done`, `move_actor_done`, `enable_text_done`, `enable_combat_done`).

**Open decision:** fully converting the Tiled pipeline to Godot 4 is a large milestone (custom `.tmx`→`.tscn` converter reproducing the expected structure + the level container + whatever surfaces after). Since the real game (per design_doc) uses its own data-driven maps, this may be reference-only work — pending the user's direction.

### M19 (resolved) — Reference-only; build the real map/battle system fresh
Decision (user, 2026-07-27): do NOT convert the Tiled pipeline. The reference FE clone now runs Godot 4.6 up to the battle boundary (title → mode select → world map → cutscene → chapter intro → clean logged stop where a `.tmx` battle map would load). It stays as **read-only reference** for combat math, AI, unit/inventory, and UI patterns. Death or Taxation's map/battle system will be built fresh per `docs/design_doc.md` (data-driven maps, `/sim` + `/data` + `/scenes` + `/ui` + `/tests`), starting from the pre_prompt's Milestone 0 (plan/file-tree/schemas/signal-contract) when the user is ready.

### M20 — Clean battle boundary (no Tiled load attempt)
The reference-build error wall on reaching Chapter 1 came from `chapter_background.gd` calling `load()` on `chapter_2.tscn` → `Level3.tscn` → `level3.tmx` (the Tiled chain), which Godot's loader prints many parse errors for before returning null. Since battles are reference-only (M19), removed the level-load entirely: after the chapter title, it now shows a "[ reference build ] battle maps are built fresh in Death or Taxation" note and stops. Verified by driving New Game → world map → cutscene → Chapter 1: zero resource-load/parse/.tmx errors, clean chapter screen. (`next_chapter_path` is now intentionally unused → `_next_chapter_path`.)
