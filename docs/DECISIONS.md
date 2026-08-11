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
Canonical statement: `design_doc.md` §3 (per ruling G1 below). Mirror:
```
base  = damage_table[attacker.type][defender.type]   # `type` = the §3.3 field name
base *= armament_triangle[attacker.armament][defender.armament]  # design_doc §3.1; three classes, no arcane
base *= attacker.power_mult            # general level package; 1.0 for squads/singles
base *= ability modifiers              # e.g. command_aura x1.20, multiplicative, pre-floor
hp_f  = attacker.hp / attacker.max_hp  if tier == squad else 1.0
terr  = 1.0 - terrain[defender.tile].defense
defn  = 1.0 - defender.defense         # per-unit stat, 0.0 neutral (G16)
dmg   = floor(base * hp_f * terr * defn)
dmg   = max(dmg, MIN_DAMAGE)           # MIN_DAMAGE = 1
```
Verified vs. the seven canonical worked examples (design_doc §3.2). The original three are armament-neutral (×1.0): `6×0.7×0.8=3.36 → 3`; `2×0.1×0.6=0.12 → 0 → 1`; `8×1.0×1.0=8`. Triangle examples: advantage `6×1.5=9`; disadvantage `6×0.5×0.7×0.8=1.68 → 1`. Defence examples (G16): `6×0.75=4.5 → 4`; `6×0.7×0.8×0.75=2.52 → 2`.

Update 2026-08-02 (ruling G2): a per-unit `defense` stat was ruled into existence (issue 02, Q2=B); its pipeline term was pending grilling issue 16.
Update 2026-08-10 (ruling G16): the defence term landed — multiplicative `(1 − defender.defense)`, stacking independently with terrain, uncapped. Canonical examples now number seven (design_doc §3.2), examples 6–7 exercising defence.

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
Update 2026-08-10 (ruling G16, Q4=B): level packages may additionally grant a `defense` bump (design_doc §5).

### D13 — Generals do not degrade
Generals use `tier:"general"` => no HP-degradation multiplier ("static per level, grows via EXP"), side-agnostic (G8 Q6). **Resolved** (ruling G19, 2026-08-10, grilling issue 21): the ruled distinctions are the complete intended General presence — unique damage-table row/column (G18), per-General base HP/stats (G2), defense incl. level bumps (G16), `power_mult` levels (D12), abilities at L3/L5 (§5), seize/escape roles (G4), the mission-loss exemption (G5 Q6), the `general` slot category (G9), and revival/cutscene persistence (§6). No further General-specific battlefield mechanic exists; adding one requires a new ruling. Canonical closure statement: design_doc §3.
Update 2026-08-02 (ruling G2): Generals are no longer stat-identical to singles — each General sets a per-General base HP and stats in its own data file (issue 02, Q1b=C).

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
turn_changed(faction, turn_number)
unit_spawned(unit_id)
unit_moved(unit_id, path)
unit_damaged(unit_id, amount, new_hp, source_unit_id)
unit_destroyed(unit_id, faction, was_general)
skirmish_resolved(result)              # same payload as forecast
ability_triggered(unit_id, ability_id, affected_ids)
unit_activated(unit_id)                # AI dormancy broken
unit_exited(unit_id)                   # escape objective — left via exit tile alive (G4)
unit_retreated(unit_id)                # scripted boss retreat — alive, excluded from rout (G8)
unit_revealed(unit_id)                 # fog — entered player vision, incl. ambush reveal (G12)
unit_hidden(unit_id)                   # fog — left player vision, marker vanishes (G12)
objective_progress(text)
mission_complete(victory, summary)     # turns, squads_lost, champion_killed
```
Attack emission order: `unit_moved` -> `unit_damaged`(defender) -> [`unit_destroyed`] -> [`unit_damaged`(attacker counter)] -> [`unit_destroyed`] -> `skirmish_resolved`.

View→Sim is method calls returning a validity result (never asserts on bad input): `get_reachable`, `get_attackable`, `forecast`, `command_move_attack`, `command_wait`, `command_ability`, `end_turn`.

Update 2026-08-10 (audit F4, issue 19): `unit_exited` / `unit_retreated` / `unit_revealed` / `unit_hidden` added for mechanics ruled after the contract was written (G4 escape exits, G8 boss retreat, G12 fog visibility). Names are provisional until implementation — re-log here if they change.

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
- **Q1a = B:** max HP is a per-unit data field, not a tier constant. Owner's rationale: "We will need to give certain units more hp depending on class and level. This makes units more unique." Prototype values (squads 10, singles 25) are starting data.
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
- **Q5 = B:** the universal final key is board position — (row, col), lowest row then lowest column — for units and tiles alike; total order guaranteed by the occupancy rule (§3.4), computed from sim state, no RNG. Simplest reading logged per this file's protocol (correct if wrong): under `medium`/`smart` sequencing, "current position" means position on the projected board at the moment the acting unit is evaluated.
- All rulings by owner, no rationale stated.

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
