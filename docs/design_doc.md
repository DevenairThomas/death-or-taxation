PROJECT: DEATH OR TAXATION
Backlog Design Document — v2.0

This document is authoritative on design rules (ruled 2026-08-02, grilling issue 01). `conventions.md` is authoritative on repo structure. `CLAUDE.md` and `docs/pre_prompt.md` are derived summaries — where they disagree with this document on a design rule, this document wins.

1. High Concept

An HD 2D tactics game in the Fire Emblem lineage — unique persistent characters, VN-style story scenes — over army-scale, deterministic, table-driven skirmish combat (the Advance Wars citation was dropped with the degradation mechanic — ruled 2026-08-12, G35). An outlandish retelling of the American Revolution: an isekai'd mage seized control of the Crown and assassinated America's founding fathers to strangle the revolution in its crib. The player is an isekai'd lich, sent to this world to rescue America from the horrors of Taxation without Representation — by raising the murdered founders as undead Generals and fighting the Revolutionary War, battle by historical battle, as the Continentals.

Genre: Turn-based tactics / SRPG
Presentation: HD 2D, VN-style text cutscenes, no voice acting
Campaign length: ~5 hours (14 missions)
Platform target: PC first
Team: Solo, part-time
Engine: Godot (see §10)


2. Design Pillars

Simple systems, felt choices. Two unit tiers, each defined by one rule (units are per-battle; Generals persist and grow — ruled 2026-08-12, G35). One currency (souls) and per-battle deployment slots, each with one job. (The battle-budget currency was abolished — ruled 2026-08-06, grilling issue 09.)
Player freedom over balance purity. Farming is allowed; overpowered players are a feature, not a bug. Tune one moderate difficulty well instead of three poorly.
Mechanics are the story. The lich fantasy justifies revival, death-agnostic cutscenes, and soul-currency diegetically. No game-isms that need excuses.
Ship it. Every decision favors the version that a solo dev can finish. Descope toward the FE chassis whenever in doubt.


3. The Two Unit Tiers

The two tiers — units and Generals — are exhaustive (squads and singles merged; degradation abolished — ruled 2026-08-12, G35) — the lich (the player character) is purely narrative and never appears as a unit (§7; ruled 2026-08-03, grilling issue 06).

Generals' mechanical presence is likewise closed (ruled 2026-08-10, grilling issue 21): a General differs from a unit by exactly the ruled set — unique damage-table row/column (§3.3, issue 20), per-General base stats and defense (§3.3), level packages and abilities (§5), objective roles (seize/escape, §8.2), the mission-loss exemption (§6), and the campaign layer (general slots, revival, cutscene persistence). No further General-specific battlefield mechanic exists; adding one requires a new ruling. (The list's former first item — the tier rule, no degradation on either side — ceased to be a distinction when degradation was abolished project-wide: ruled 2026-08-12, G35.)

Vocabulary note (ruled 2026-08-06, grilling issue 15): "EXP" is the colloquial name for soul progression — the tier table's "grows via EXP" and §4's "exp" bonus both mean souls. There is exactly one progression currency; no per-kill EXP and no separate EXP resource exists.

UnitsGenerals (Named)FantasySoldiers, monsters, war-engines (e.g., death knight)The founding fathers, raisedCombat mathStatic stats — full damage at any HPStatic per level, grows via EXPPersistenceDisposable, per-battlePermanent rosterFielded viaDeployment slots (slot_category)General slots (§4)On deathGoneRevivable with souls (unless No-Revive mode)

Combat resolution: When two units interact, a skirmish resolves — the attacker strikes first; if the defender survives and the attacker stands within its counter_ranges, it counters. A counter runs the same pipeline with one extra factor — the countering unit's `counter_mult` stat (§3.3) — and is exempt from the minimum-damage rule: a counter may deal 0 (ruled 2026-08-12, G35). Deterministic: guaranteed hits, no hit/crit RNG. Damage = lookup table (attacker type × defender type) × armament triangle (§3.1) × terrain modifier, rounded down, minimum 1 damage on any legal initiated attack (no zero-damage initiated hits). Damage never scales with remaining HP — there is no degradation mechanic (G35). The pipeline block below is the exact canonical order.

The damage pipeline: (single source of truth; the forecast shown to the player and the damage applied are the same computation):

```
base  = damage_table[attacker_type][defender_type]     # role matchup
base *= armament_triangle[attacker_arm][defender_arm]  # §3.1
base *= attacker_power_mult                            # General level package; 1.0 otherwise
base *= ability modifiers                              # multiplicative, in data-declared order
base *= attacker_counter_mult                          # counter resolutions only (§3.3; ruled G35); 1.0 when the attack is initiated
terr  = 1.0 - terrain_defense[defender_tile]
defn  = 1.0 - defender_defense                         # per-unit defense stat (§3.3); 0.0 = neutral (ruled 2026-08-10, issue 16)
damage = floor(base * terr * defn)                     # armament/power/abilities/counter already folded into base above
damage = max(damage, 1)                                # initiated attacks only (G35): a counter skips this line and may deal 0
```
Rounded down; minimum 1 damage on any legal initiated attack — zero-damage initiated attacks are impossible; counters skip the floor and may deal 0 (ruled 2026-08-12, G35). Terrain and unit defense stack as independent multipliers, uncapped (ruled 2026-08-10, grilling issue 16). Damage never scales with either side's remaining HP: the degradation mechanic was abolished (G35), and adding any HP-scaling damage mechanic requires a new ruling.

3.1 The Armament Triangle
```
        RIFLE ──strong vs──▶ MELEE
          ▲                    │
          │                strong vs
      strong vs                │
          │                    ▼
        MUSKET ◀───────────────┘
```

Rifle — rifles and handguns. Skirmishers, marksmen, riflemen. Strong against melee.
Melee — swords, axes, sabers, bayonet charges, and melee monsters. Strong against musket.
Musket — muskets and cannon. Massed line infantry and artillery. Strong against rifle.

Multipliers (data, in `armament_triangle.json`; starting values, tunable):

| Attacker vs. defender | Multiplier |
| --- | --- |
| Advantage | ×1.50 |
| Neutral | ×1.00 |
| Disadvantage | ×0.50 |

These three classes are exhaustive — there is no fourth armament class (ruled 2026-08-02, grilling issue 01). Every unit type, casters and constructs included, is assigned exactly one of rifle, melee, or musket. "Arcane" appears in this project only as a damage-table archetype name (a role, e.g. `arcane_ranged`), never as an armament.

Player-facing readability. The forecast popup must show the matchup state — advantage, neutral, disadvantage — alongside the exact damage numbers, and the defender's defense stat (ruled 2026-08-10, grilling issue 16). Because combat is deterministic, the forecast is a promise, and the triangle is only a meaningful decision if the player can see it before committing.

Enemy threat display and inspection (ruled 2026-08-12, reference-mining issue 34 — DECISIONS G31): a danger-zone overlay exists in both forms — selecting/hovering an enemy paints that enemy's threat range (movement + attack range, §3.4), and a global toggle paints the union of all enemy threat ranges. On fog chapters the overlay is computed from **visible enemies only** — it honestly under-reports, hidden threats stay hidden (§3.6/G12), and ambush risk stays real. Inspecting any unit discloses its §3.3 stat block only (HP, defense, armament, tier, move, ranges, abilities); raw damage-table rows are never player-facing — concrete damage numbers appear only in the forecast popup against a real attacker/defender pair. The overlay paints sim query results (`get_threat`); the view computes nothing.

3.2 Canonical Worked Examples

Mirrored in /tests — if these fail, the formula is wrong. The set was re-derived when degradation was abolished (ruled 2026-08-12, G35): examples 1–6 descend from the pre-G35 set with attackers at full strength (the old singles-never-degrade example was deleted — it demonstrated only the dead asymmetry); examples 7–8 are new, exercising the counter stat and its min-1 exemption. Examples 1–4 have defender defense 0 (neutral); 5–6 exercise the defence term (their defense values are authored starting numbers, correctable — issue 16); the counter examples' counter_mult 0.5 is example data, not a canonical constant.

1. Unit, table 6, neutral armament, defense 0, vs. forest (def 0.2): 6 × 1.0 × 0.8 = 4.8 → 4
2. Unit, table 2, disadvantage (×0.5), defense 0, vs. mountain (def 0.4): 2 × 0.5 × 0.6 = 0.6 → 0 → min rule → 1
3. Unit, table 6, advantage (×1.5), defense 0, vs. plains (def 0): 6 × 1.5 × 1.0 × 1.0 = 9
4. Unit, table 6, disadvantage (×0.5), defense 0, vs. forest (def 0.2): 6 × 0.5 × 0.8 = 2.4 → 2
5. Unit, table 6, neutral armament, defender defense 0.25, vs. plains (def 0): 6 × 1.0 × 1.0 × 0.75 = 4.5 → 4
6. Unit, table 6, neutral armament, defender defense 0.25, vs. forest (def 0.2): 6 × 0.8 × 0.75 = 3.6 → 3
7. Counter — surviving defender with counter_mult 0.5 counters, table 4, neutral armament, target on plains (def 0), defense 0: 4 × 0.5 = 2
8. Counter — counter_mult 0.5, table 1, neutral armament, target on forest (def 0.2), defense 0: 1 × 0.5 × 0.8 = 0.4 → 0 (counters are exempt from the min rule — a zero-damage counter is legal, G35)

3.3 The Unit Stat Block

Every unit type is defined entirely in data by the following fields (ruled 2026-08-02, grilling issue 02). Adding or tuning a unit touches data only, never code.

- max_hp — per-unit value. HP is not a tier constant; certain units get more HP by class and level to make units more unique. Starting values are data authoring and live only in the unit data files (the formerly quoted per-tier prototype values were dropped — ruled 2026-08-12, G35). Generals set a per-General base HP (and stats) in their own data files; the level packages' hp_bonus (DECISIONS D12) stacks on that base.
- defense — per-unit defensive stat, multiplied into the pipeline as (1 − defense); 0.0 = neutral, stacking independently with terrain (§3; ruled 2026-08-10, grilling issue 16). Values are data authoring ("weak defense" = below baseline). Both tiers carry it; General level packages may grant defense bumps (§5, DECISIONS D12).
- armament — exactly one of rifle / melee / musket (§3.1).
- type — the unit's row/column id in the damage table (§3). Every General, player and enemy alike, carries a unique `type` — its own row and column; Generals do not share archetype rows, and the matrix grows with the roster (ruled 2026-08-10, grilling issue 20; DECISIONS G18).
- attack_ranges — explicit list of attack distances (e.g. [1], [2], [2,3]).
- counter_ranges — explicit list of distances the unit counterattacks at (DECISIONS D9/D11 semantics; e.g. Cannoneer [2,3], melee [1]).
- counter_mult — per-unit multiplier folded into this unit's counterattack damage (§3 pipeline; ruled 2026-08-12, G35 — owner: "Some units should be better at counter-attacking than others"). 1.0 = neutral; values are data authoring. Counters are exempt from the minimum-damage rule and may deal 0 (G35). Simplest reading, logged G35 (correct if wrong): the field name and the 1.0-neutral multiplier form.
- move — movement points, spent against terrain movement costs.
- move_class — one of infantry / mounted / siege (the former `construct` class was removed — ruled 2026-08-10, grilling issue 22; "construct" survives as flavor only); each terrain type's data declares a movement cost per class, with impassable as a legal cost value (§3.4; supersedes issue 03's allow/deny reading). The vocabulary is closed: **no flying class exists** (ruled 2026-08-12, reference-mining issue 30 — DECISIONS G28) — airborne concepts are flavor only, and adding flight would require a new ruling plus a fourth per-terrain cost column.
- abilities — optional list of ability ids. One shared framework for both sides (§5; ruled 2026-08-03, grilling issue 08): player Generals gain theirs at levels 3/5; any unit, enemy Generals included, may carry abilities in data.
- sight — vision radius in tiles, used on fog-of-war chapters (§3.6; ruled 2026-08-06, grilling issue 12).
- slot_category — one of general / tank / infantry; the deployment slot pool this unit occupies (§4 — battle budget and deploy costs were abolished, ruled 2026-08-06, grilling issue 09).
- throwing — per-unit stat governing item delivery when using consumables on other units (§4 Items; ruled 2026-08-12, reference-mining issue 28 — DECISIONS G26). Ruled (G33 Q4, 2026-08-12, upgrading the G26 simplest reading): throw range = the stat's value in tiles, directly; self-use is range 0; the stat never affects the heal amount — heal values are fixed item data.

Per-unit matchup bonuses do not exist — the prototype's "bonus vs. Riflemen" on Cavalry Squad was cut (ruled 2026-08-02, grilling issue 02). Unit-vs-unit differentiation lives in the damage table, the armament triangle, and the stats above.

3.4 Movement, Occupancy, and Terrain

Ruled 2026-08-03, grilling issue 03. These are the canonical grid rules:

- Pass-through: a unit may move through tiles occupied by allies. Tiles occupied by enemies block movement.
- Occupancy: a unit may never end its move on an occupied tile.
- No zone of control: moving adjacent to an enemy never halts or restricts movement. Threat range is always movement + attack range.
- Terrain movement cost per class: there is no dedicated "infantry-only" terrain flag. Each terrain type's data carries a movement **cost keyed by unit move_class** (§3.3); impassable is a legal per-class cost value, so a ban is a special case of cost. (Ruled 2026-08-10, grilling issue 22 — this corrects G3's logged allow/deny simplest reading exactly as its correct-if-wrong flag anticipated: the per-class cost table was the intent.)
- Line of fire: attack range is a pure distance check — units never block ranged attacks. Terrain does not currently affect range; terrain-based range effects are reserved as a possible future mechanic (owner note, G3) and are not in the sim.
- Path authority (ruled 2026-08-11, reference-mining issue 27 — DECISIONS G25): the mover's plotted path is authoritative. A move command carries the full tile path; the sim validates it (contiguity, movement budget under the per-class costs above, legality under the occupancy rules) and never substitutes a path of its own. Under fog this is gameplay-visible: the player chooses which tiles they risk (§3.6 ambush). The AI submits its planned paths through the same contract.
- Reachability includes staying put (G25): a unit's reachable set includes its own tile — attack-only and wait are zero-length moves through the same activation pipeline (§3.7), not special cases that bypass movement.

Terrain types (data, in `terrain.json`; starting values, tunable):

| Terrain | Defense | Move cost (infantry / mounted / siege) | Notes |
| --- | --- | --- | --- |
| Plains | 0 | 1 / 1 / 1 | |
| Forest | 0.2 | 2 / 2 / 2 | |
| Mountain | 0.4 | 3 / 6 / 6 | severe cost for non-infantry replaces the former infantry-only entry ban (ruled 2026-08-10, grilling issue 22); non-infantry costs are protocol-authored starting data (DECISIONS G20) — correct if wanted |
| Road | 0 | 1 / 1 / 1 | the original −0.1 defence was ruled a typo → 0 (issue 03, Q5); no negative-defence terrain exists |
| River | — | impassable (all classes) | crossable only via Bridge (DECISIONS D17) |
| Bridge | 0 | 1 / 1 / 1 | added by DECISIONS D17 |
| Sea | — | impassable (all classes) | coastal scenery; no unit traverses it (ruled 2026-08-06, grilling issue 13) |
| HQ/Zone | 0.3 | 1 / 1 / 1 | |

On fog-of-war chapters, terrain additionally carries vision data — concealment and sight modifiers (§3.6; values are data authoring).

Terrain never modifies HP: there are no heal tiles and no damage tiles (ruled 2026-08-11, reference-mining issue 26, Q1 — DECISIONS G24). A terrain record carries defense, per-class movement cost, and fog vision data only; per-turn terrain HP effects are not in the sim and must not be built without a new ruling.

Naval is flavour, not a system (ruled 2026-08-06, grilling issue 13): there is no water movement, no naval move_class, no ship units, and no transport subsystem. "Naval" chapters (ch11 Charleston) are land battles on coastal maps; sink-the-fleet or blockade-style goals are expressed through the five objective types (§8.2) and named kill-targets — no new objective types.

3.5 Enemy AI

Ruled 2026-08-06, grilling issue 11. This is the canonical AI spec; other documents' AI statements defer here.

- Direction (owner's ruling): the AI plays its army as one strategist — it perceives the field and plans coordinated moves for all its units in accordance with one another, not each unit running its own isolated AI. This supersedes pre_prompt's "do not build anything smarter than this" cap. The coordinator is specified below (ruled 2026-08-10, grilling issue 17); the per-unit model is its `simple` tier and ships first.
- The coordinator (issue 17): coordination depth is staged as the competence tiers — `simple` = the per-unit model below, no shared state; `medium` = greedy shared-state sequencing — units act in a deterministic order, each picking its best action against a projected board where damage already assigned this phase counts, so focus-fire emerges; `smart` = assignment-based planning — explicit focus-fire packages, chokepoint holders (§3.4 terrain), screens for weakened units — plus active-ability valuation. Planning is one enemy phase at a time, re-planned from the current board; no plan state persists (trivially suspend-safe, §6).
- Active abilities in planning (issue 17): under `smart`, an active is chosen when it beats the unit's best normal action — strictly: an exact value tie keeps the normal action and holds the charge (ruled 2026-08-10, grilling issue 23); once-per-mission charges are held until a threshold — targets hit ≥ N, or it secures a kill — with thresholds as named tuning constants. Item use from an enemy item pool (§4, G33 Q6) is valued through this same mechanism.
- Fog (issue 17): on fog chapters the coordinator plans over visible player units and the known map only (§3.6) — hidden units do not exist to its evaluation. The vision state is part of any test fixture.
- Dormancy: enemy units start dormant and activate permanently when a player unit enters their threat range (movement + attack range, §3.4). Map data may declare activation groups that wake together. Reinforcement spawns (§8.3) enter under normal dormancy unless their spawn event marks them active. Ruled exception (2026-08-10, grilling issue 17): the coordinator may strategically wake dormant groups as a deterministic planned action.
- Target scoring is importance-based, computed with the real damage pipeline (§3, counter_mult included — G35): a target scores higher when it can be destroyed, when the attacker is likely to survive the aftermath, and when it is isolated. Component weights are named tuning constants in data. The baseline implementation is score = expected_damage − 0.5 × expected_counter + kill_bonus (kill_bonus: named tuning constant, value set at the AI milestone).
- Per-unit AI flags (behaviors ruled 2026-08-10, grilling issue 17): posture — guard = never moves, attacks in range, excluded from coordinated movement; aggressive = active from turn 1; balanced = the default — dormant until threat range, coordinated normally once active. Competence — simple | medium | smart select the coordination tier defined above. Chapters tune difficulty by assigning flags in data.
- Sleepy objectives: on defend/survive maps the player may never approach — this is resolved primarily by mission design (aggressive flags, activation groups, scripted reinforcements), not by an engine auto-activation rule; the coordinator's strategic waking (above) is an additional AI-side lever, not a replacement.
- Determinism: no RNG anywhere in the AI. Equal-scoring choices break by the documented deterministic tie-break chain (ruled 2026-08-10, grilling issue 23; DECISIONS G21): **units act in chapter-data declaration order** (reinforcements append in spawn order); **target ties** break killable-first → higher expected_damage → lower defender current HP → defender board position; **destination-tile ties** break lowest per-class path cost (§3.4) → highest terrain defense → board position. Board position = (x, y), lowest x then lowest y (amended from the original (row, col) row-major order — ruled 2026-08-12, schema-forge issue 39, DECISIONS G34 Q6a; data files author all tile coordinates as `[x, y]`, matching Godot's `Vector2i`) — a total order guaranteed by the occupancy rule (§3.4); every key is computed from sim state. The exact-choice test asserts the full plan (ruled 2026-08-10, grilling issue 17): for a fixed board and vision state, the complete ordered move/attack set of the enemy phase (conventions §8, generalized to army level; stable iteration order is satisfied by the chain above).
- No production, no economy, no strategic-layer resource AI (§9 cuts stand).
- No enemy-intent display ships (ruled 2026-08-12, reference-mining issue 30 — DECISIONS G28): the view animates enemy actions without telegraphing targets in advance. A simple attacker→target telegraph may exist in gray-box builds as a **debug toggle only** — a dev affordance, not UI, removable without a ruling. (The player-facing forecast popup, §3.1, is unrelated and unchanged.)

3.6 Fog of War

Ruled 2026-08-06, grilling issue 12. Fog is a per-chapter flag in chapter data; introduced at chapter 8 (Germantown).

- Vision: every unit has a `sight` radius (§3.3). Terrain interacts with vision (ruled Q1 = B): terrain data may declare concealment — occupants of concealing terrain (e.g. forest) are visible only from adjacent tiles — and sight modifiers (e.g. high ground extends sight). The mechanisms are canonical; per-terrain values are data authoring in terrain.json.
- Memory: the map and terrain are always known — fog hides units only. Enemy units are visible inside the player's combined vision and their markers vanish when they leave it; there are no last-known-position ghosts.
- The AI is fogged too: each side perceives only what its own units' vision covers, under the same rules. Dormancy (§3.5) is unchanged. Under the coordinated-AI direction, the coordinator plans from its side's vision — see grilling issue 17.
- Ambush: enemies block movement (§3.4), hidden or not. A move whose path crosses a hidden enemy stops the unit on the last legal tile and reveals that enemy. Simplest reading, logged G12 (correct if wrong): the stopped unit's action is spent. Truncation contract (ruled 2026-08-11, reference-mining issue 27 — DECISIONS G25): truncation runs along the player's plotted path (§3.4 path authority); the sim emits the movement first, then the reveal, fires no attack signals, and the command's return value reports truncation as a distinct outcome — a legal command cut short, not an invalid one.
- The forecast promise is unaffected: forecasts are offered only against visible targets, and a committed attack resolves exactly as forecast.

3.7 Turn Structure

Confirmed and canonicalized from DECISIONS D15/D16 (ruled 2026-08-06, grilling issue 15):

- Phases: all player units act, then all enemy units (no per-unit initiative).
- One activation per unit per turn: move-then-attack, move only, attack only, or wait. Wait is a distinct action — ending the unit's activation without moving or attacking.
- Attack-then-move is impossible. The sole exemption is Ride Through's whitelisted move-again-after-attack (§5).
- Phase end (ruled 2026-08-12, reference-mining issue 29 — DECISIONS G27): the player phase ends automatically the moment every player unit has acted; the explicit `end_turn` command ends it early, forfeiting the activations of units that have not acted. (Any end-of-phase confirmation dialog is view-side presentation, not a sim rule.)
- Turn boundary (G27): turn N is player phase N followed by enemy phase N; "end of turn N" — the defend/survive checkpoints of §8.2 — falls **after the enemy phase** of turn N. Simplest reading, logged G27 (correct if wrong): the shared turn number increments when a new player phase begins, and both phases of turn N carry N in `turn_changed`.

4. The Economy: Souls & Deployment Slots (formerly "The Two Currencies" — battle budget abolished, ruled 2026-08-06, grilling issue 09)

Deployment Slots (per-mission; replaced the battle-budget currency — ruled 2026-08-06, grilling issue 09): Each chapter authors per-category slot caps that constrain what the player can field. Composition is still the pre-battle puzzle: heroes + chaff vs. balanced army, chosen against the caps instead of a wallet.

- Categories: `general`, `tank`, `infantry` — a per-unit-type data field (`slot_category`, §3.3), not a tier alias. Prototype mapping (owner's): infantry = the versatile units (Line Infantry, Rifleman); tank = the specialist/heavy units (Death Knight, mages, Cannoneer, Cavalryman); general = Generals. (Roster renamed to individual-unit names — ruled 2026-08-12, G36.)
- The deployment screen shows placed/max per category (e.g. "0/1 general · 2/5 tank · 1/7 infantry"). Filling every slot is allowed; so is fielding less.
- Under-filled slots increase the end-of-mission soul award (the "exp" challenge bonus — ruled issue 09; souls remain the only progression currency, awarded on completion only; there is no per-kill EXP and units do not level).
- No minimums: zero Generals is always legal; on seize/escape chapters the screen warns that the primary objective needs a living General (§6) but does not block.
- Force-deployed Generals (§5) are free and extra — they consume no general slot.
- Start tiles are authored per map and the player chooses which selected unit stands on which tile. A map provides at least as many start tiles as its total slot cap.
- There are no deployment prices. Nothing is bought; leftover slots are simply unfilled (and feed the soul bonus above).

Souls (persistent, campaign-wide, shared pool): Awarded on mission completion only — base award + secondary objective bonuses (turn count, unit preservation, kill the enemy champion). Spent between missions on three things:

Leveling Generals (escalating cost per level)
Reviving dead Generals (flat cost × the character's current level)
Buying items at the camp shop (ruled 2026-08-12, reference-mining issue 28 — DECISIONS G26; see below)


No mid-mission spending. Shared pool means benched Generals never fall behind and rotation is free.

Items & the camp shop (ruled 2026-08-12, reference-mining issue 28 — DECISIONS G26; partially reverses §9's cut):

- Consumable healing items exist, bought with souls. Simplest reading, logged G26 (correct if wrong): the shop lives at camp and sells between missions only — preserving the no-mid-mission-spending rule above; souls remain the only currency.
- Inventory is one shared army pool — there is no per-unit inventory. Simplest reading, logged G26 (correct if wrong): any deployed unit may use an item from the shared pool during battle.
- Using an item is the unit's action: using one on another unit means **throwing** it, and a throw consumes the thrower's activation (§3.7). Simplest reading, logged G26: self-use consumes the activation too.
- The `throwing` stat (§3.3) makes some units better at healing others. Simplest reading, logged G26 (correct if wrong): it governs throw range/delivery, not the heal amount — consumable heal values are **fixed data amounts** (deterministic; no RNG; heals are not attacks, so the §3 damage pipeline and min-1 rule are untouched). A thrown item is consumed on use — throwing is not trading.
- Rare magical healing: a select few units/characters may heal as an ability effect, scaling with level (§5). Optional content — permitted by this ruling, not committed.
- The sim emits `unit_healed` for every item or ability heal (DECISIONS signal contract, added G24).
- Parameters (ruled 2026-08-12, grilling issue 38 — DECISIONS G33): each item is its own data file under `data/items/` (the per-General pattern — adding an item is adding a file, zero code). The shop catalog is **unlock-based**: items enter it on story clears (via §8.3's `unlocks` field, the G14 Q5 pattern) and stay purchasable thereafter. The shared pool is **unlimited and fully available in every battle** — no deployment loadout step (upgrades G26's simplest reading to ruled). **Throw range = the thrower's `throwing` stat in tiles, directly**; self-use is range 0 (upgrades §3.3's simplest reading to ruled). The consumable effect-type vocabulary is reserved up front (the G29 pattern): `heal` implemented; `cure` and `buff` named now, unimplemented (names taken from the ruling's example set — correct if wanted). Items are **side-symmetric**: chapter data may grant the enemy an item pool, the coordinator values item use like active abilities (§3.5), and the exact-choice test fixture includes items when present. UI surface: a camp-shop submenu plus an "Item" entry in the battle action menu (pool list → target selection over throw range); the deployment screen is untouched.

5. General Progression

Roster: 7–8 Generals. Deployment: the general-category slot cap is chapter-driven — 2 from chapter 3, growing to 3 at chapter 9 (§8.2); tank and infantry caps are authored per chapter (§4; ruled 2026-08-06, grilling issue 09). Story missions may force-deploy specific Generals (free and extra — no slot consumed).
Levels: 5 per character, hard cap. Significant cost, significant gain.

Levels 1, 2, 4: chunky stat packages (+15–20% effective power each, visibly changes skirmish math; packages may also grant defense bumps — ruled 2026-08-10, grilling issue 16)
Levels 3, 5: unlock an ability (active skill, aura affecting adjacent units per the ability's data-declared target filter — G36, movement upgrade) and trigger a character cutscene

Ability budget: 2 abilities × ~7 Generals = ~14 abilities total.
Level-gated scenes: One VN scene at level 3 and level 5 per General (~14 scenes, 300–500 words each). The scene is the story of the ability. FE-support-style favor content, fused to the economy.

The ability framework (ruled 2026-08-03, grilling issue 08):

- Triggers — the locked vocabulary is `passive_aura | turn_start | on_attack | active_once`. The six prototype abilities map: Command Aura → passive_aura; Crossing → turn_start; Lightning Rod → active_once (ruled change: now once per mission — its original text stated no limit); Key & Kite → active_once; Ride Through → on_attack (grants the post-attack move); Vive la Liberté → on_attack (conditional damage modifier).
- Targeting shapes — declared in data as shape + size. Implemented now: `single`, `line` (target tile + N behind), `radius` (all units within N). The vocabulary is open: future abilities may add named shapes (cone, cross, mask); each new shape is sim work plus data, not a code-free add. Every unit hit by an AoE resolves through the standard damage pipeline (§3) individually. Abilities additionally declare a **target filter** in data — which units qualify (e.g. by tier or slot category); an aura's affected set is authored this way, never hardcoded (ruled 2026-08-12, G36 Q4; the exact filter vocabulary is schema work — schema-forge ticket 42).
- Uses — abilities carry `uses_per_mission` (default unlimited; Key & Kite and Lightning Rod = 1). Abilities may additionally declare data-driven charge-affecting conditions (e.g. enemies killed, friendly units killed, granting or restoring charges). There is no cooldown mechanic. Charges reset fresh every mission, farming replays included. (Ability charges are unrelated to the banned item/weapon "uses" of §9.)
- Rule exemptions — a closed whitelist of flags, currently: `no_counter` (Key & Kite) and move-again-after-attack (Ride Through, an exemption to one-action-per-turn). Never suspendable by any ability: deterministic no-RNG combat, minimum-1 damage, and forecast=resolution identity. Adding a new exemption requires a new ruling.
- Per-turn state — the sim tracks per-turn flags (e.g. engaged-this-turn, reset at turn boundaries) as queryable state, and the forecast includes every ability modifier that applies to the hypothetical attack — auras, conditionals, and exemptions. The forecast remains a promise.
- Symmetry — there is one ability framework for both sides. Enemy Generals (and any enemy unit granted abilities in data) use identical mechanics through the same sim path and signals; §8.2's chapter 10 "begin mirroring player abilities" is the content schedule for enemy ability data, not a separate system.
- HP restoration (ruled 2026-08-12, reference-mining issue 28 — DECISIONS G26) — a legal ability effect, deliberately rare: limited to a select few units/characters ("mage-type healers"), with the healed amount scaling with level. Scaling formula ruled (G33 Q7): heal = the ability's base amount × the General's `power_mult` from the D12 level package — level growth reuses the existing package, no separate heal curve. Deterministic like everything else; emits `unit_healed`. Optional content — the ruling permits it, the roster decides it (§12 item 1). Distinct from consumable item heals (§4), whose values are fixed data.
Stretch goal (not scope): one secret scene or bonus mission for maxing the full roster.


6. Death, Revival & Difficulty

Standard mode (default, single moderate difficulty):


A downed General is out for the rest of the mission, revivable between missions for souls (flat cost × level — invested carries are expensive to lose).
Dead-but-not-revived Generals still appear in cutscenes (their spirit attends the war council — one line of flavor text justifies this forever). They simply can't deploy.
Difficulty curve comes from mission design — enemy compositions that counter learned habits, terrain, objectives, enemy Generals — never stat inflation.
Farming is the easy mode. Replayable skirmish battles on reused campaign maps — the story battle unchanged (the former "rescaled enemies" wording was struck: ruled 2026-08-12, reference-mining issue 35, DECISIONS G32; the reduced yield is the only difference, and §7's never-dynamic-scaling rule stands) — souls at the farming yield (design latitude 30–50%; starting constant 40% in economy.json — ruled 2026-08-06, grilling issue 10). Replays pay the base award and secondary bonuses, both scaled by the yield, and already-earned secondaries re-pay on every replay (ruled issue 10, Q4/Q6). Level cap of 5 is the farming ceiling: overpowered-by-breadth allowed, overpowered-by-depth impossible.


No-Revive mode (the hard mode):
Chosen at campaign start, locked in for the run.
General death = campaign permadeath (still appears in cutscenes, never battles again).
Losing all Generals = game over. Player is warned of this when selecting the mode. You better be ready.

Defeat, retry, and saves (ruled 2026-08-03, grilling issue 05):

- What loses a mission: all player units destroyed; an objective's instant-loss trigger (§8.2 — e.g. an enemy ending its turn in a defend zone); or an optional chapter-declared loss condition (§8.3 — e.g. a named unit dies, a turn limit expires).
- General deaths never lose a mission by themselves. The mission continues as long as player units remain on the map; downed Generals sit out and can be brought back after the battle (normal mode: revival for souls; No-Revive: permadeath stands). Note: on seize/escape chapters the primary objective is unsatisfiable without a living General (§8.2) — such a mission can then only end in loss or restart.
- Defeat returns the player to the pre-battle flow (briefing/deployment) to retry. A voluntary mid-mission restart is available and behaves identically to defeat.
- Retry is a full rollback: all mission state, including General deaths in the failed attempt, is undone. Deaths become permanent record only when a mission completes.
- No-Revive game over (composed from the rulings above — since failed attempts roll back, the check can only bite at completion): the campaign ends when a mission completes with zero living Generals.
- A failed mission awards nothing. Souls remain completion-only (§4), secondaries included.
- Saves: the campaign save is written on mission completion and on camp-screen exit (completion-write added — ruled 2026-08-12, reference-mining issue 35, DECISIONS G32: camp is optional, so completion itself must persist). One mid-mission suspend slot exists — written when quitting mid-mission **and autosaved at every phase boundary** (player-phase start and enemy-phase start — ruled 2026-08-12, reference-mining issue 33, DECISIONS G30). Quitting during the enemy phase stores the enemy-phase-start snapshot; resume replays the phase, which is deterministic, so the outcome is identical to never having quit (the view may fast-forward). Resume consumes the slot on the first player command — loading and looking around is crash-safe; acting deletes. Save-scum residue under this model (logged G30): voluntary quit/resume can never rewind; a deliberate crash rewinds at most to the current player-phase start, and enemy phases are un-scummable by determinism — accepted as the cost of crash resilience. File layout per conventions.md §7.


7. Narrative

Sides: The player fights as the Continentals. The Crown (redcoats) are the bad guys. A revised, outlandish retelling of American history.
Protagonist: An isekai'd lich, sent to this world to rescue America from the horrors of Taxation without Representation. Villain-protagonist as liberator — still a lich doing lich things, but the Crown's master is worse. Play the tax-policy grievance completely straight-faced; earnestness is the joke.

The lich on the battlefield (ruled 2026-08-03, grilling issue 06): the lich is purely narrative — a voice in cutscenes, never a unit, tile, or commander presence in any tier. HQ tiles are purely geographic and have no connection to the lich. The lich delivers briefing, mid-mission banter, and debrief scenes regardless of any battlefield presence, consistent with all scenes proceeding regardless of who is dead.
The Big Bad: An isekai'd mage who arrived first, embedded himself behind the Crown, and assassinated the founding fathers to strangle the revolution in its crib — which is why they are dead and raisable, and why the lich was sent. Mirror antagonist: two otherworlders waging a proxy war over the continent. Final confrontation at Yorktown.
Generals: The murdered founding fathers and great Revolutionary generals, raised as undead — heavily stylized as anime girls (character design pass is a separate future conversation). Powers riff on the historical figures — e.g., Benjamin Franklin: electricity. Others TBD (suggestions: Washington — command auras; Hamilton — artillery/economy flavor; Lafayette — cavalry mobility; Knox — siege; Greene — attrition/retreat tactics; John Paul Jones — naval-flavoured (his kit must stay meaningful on land — naval is not a system, ruled 2026-08-06, grilling issue 13); Daniel Morgan — riflemen/skirmishers).
Roster growth as mission rewards: Generals can join as liberation prizes — free the region, recover the remains, raise the General, cutscene. Fuses roster pacing with mission structure.
Enemy faction: The mage's forces — redcoats plus his summoned constructs / bound magic (justifies non-historical enemy unit types), led by corrupted mortal enemy Generals drawn from British command (Cornwallis, Howe, Clinton, Tarleton), escalating in power alongside the player's roster.

Enemy Generals, mechanically (ruled 2026-08-03, grilling issue 07):

- Stats on the player's scale: an enemy General carries a level (1–5) and reuses the level packages (`power_mult`, `hp_bonus` — DECISIONS D12); each chapter appearance authors the level in chapter data. Each enemy General also has its own damage-table row/column (unique `type`, §3.3 — ruled 2026-08-10, grilling issue 20).
- Abilities: identical to the player framework (§5, ruled G7) — kept identical for now, revisit after MVP (owner note).
- Persistence: recurring characters declared per chapter in data, with no campaign death-tracking — killing an enemy General wins that battle's fight only; the same General may appear in a later chapter.
- Boss retreat: chapter data may script retreat events — on a declared trigger, an enemy General withdraws from the field alive. This is the only exception to "no flee mechanic" (§8.2, amended); a General removed by a scripted retreat does not count toward rout.
- Escalation is a fixed authored curve across the campaign — never dynamic scaling to the player's actual levels. §6's "never stat inflation" stands.
- The champion is the chapter's enemy General — one concept, not two. Chapters without an enemy General have no champion; they may still author named-unit kill secondaries (the prototype's Trenton Bound Golem is such a target, no longer labeled champion).
- Tier rules are side-agnostic: enemy Generals are tier general with the full §3 General presence (DECISIONS D13; the former "never degrade" clause became vacuous when degradation was abolished — G35).
Benedict Arnold (recommended): the mage's living American lieutenant — corrupted rather than killed — serving as recurring mid-boss and the mage's human face through the first two acts. (Much cheaper to build than a defecting-player-General version of the arc.)
Tone: Stylized, irreverent, "clearly inspired by but renamed/reimagined" wherever safer or funnier.
Cutscenes: VN-style text with character portraits (2–3 expressions each), no VA. Budget 2–4 scenes per mission (briefing / optional mid-mission banter / debrief) + 14 level-gated character scenes. All scenes proceed regardless of who is dead. No death-variant writing, ever.

Cutscene data (ruled 2026-08-12, reference-mining issue 32 — DECISIONS G29): a scene file is an ordered step list in DoT's JSON schema (/data, D1 — adding a scene is a data edit, zero code). The step-type vocabulary is **reserved up front** (Q2=B): `line` ({speaker, portrait_ref, text} + box-position flag) is implemented first; `camera`, `actor` (move/spawn on the battle view), and `wait` are named now and implemented when a chapter needs them. Presentation is rendered through Dialogic (§10 — the runner drives it; content never lives in Dialogic's own formats).


8. Campaign — Major Battles of the Revolutionary War

Mission list drawn from the war's major engagements (~14 missions). Roughly 20–25 min/mission ≈ 5+ hours.
The thirteen colonies are the canvas those chapters sit on, not the selector itself.

Map scale (ruled 2026-08-14, DECISIONS G44 — owner: maps should "feel larger like you are actually fighting a battle"): map sizes follow **per-archetype bands** — skirmish/tutorial **16×12–20×16**, standard battle **24×20–32×24**, set-piece **32×24–40×30**; band assignment is per-chapter authoring (G15's no-hard-bounds stands). The battle feel is delivered by both ruled levers: per-chapter slot caps scale with the envelope toward genre density (~1 enemy per 20–35 tiles), and standard/set-piece chapters carry a **multi-front composition mandate** — simultaneous objectives and reinforcement-wave pressure staged via activation groups, spawn events, and strategic wakes; dead space is the documented failure this mandate prevents. Defend/survive turn clocks and enemy staging must be co-authored with march distance at standard+ bands. Movement stats retune upward with the envelope (G44 Q4; current +1 authoring in unit data).

8.1 The campaign map

A single illustrated map of the eastern seaboard with the thirteen colonies drawn and labeled as visible geography. This is the between-mission navigation screen, in the Fire Emblem world-map idiom.

Battle nodes sit at their historical locations on that map — one node per chapter, connected along the campaign route so the war's progress reads as a line moving down the coast.
Colonies are context, not buttons. They give the player a sense of place, of how far the war has spread, and of which region a mission is fought over. They are not individually selectable and they are not chapters.
-Node states are visible:** cleared, current, and locked-but-visible future chapters, so the player can see the shape of the war ahead. Selecting a node opens its briefing (objective, slot caps, known enemy composition), then deployment, then battle.
Cleared story nodes become replayable as farming skirmishes at reduced soul yield — the node is the replay's only entry point (ruled 2026-08-12, reference-mining issue 35, DECISIONS G32; there is no camp farming menu).

The between-mission loop (ruled G32, Q3=B — map-centric): mission completion → debrief → the campaign map. The camp screen is optional, entered from the map at will and re-enterable freely; each camp exit writes the campaign save, and mission completion writes it too (§6), so skipping camp never loses progress. Choosing a node runs briefing → deployment → battle as always.
Optional flavor, cheap to build: each colony carries a liberation state that tints as its battles are cleared, turning the map into a progress readout. Purely visual — no mechanical effect.

8.2 Chapter list

Drawn from the war's major engagements — ~14 missions

| # | Chapter | Colony / Region | Role |
| --- | --- | --- | --- |
| 1 | Lexington & Concord | Massachusetts | Tutorial — rout objective |
| 2 | Bunker Hill | Massachusetts | Defend objective |
| 3 | Siege of Boston | Massachusetts | First Generals unlock; siege objective (= seize, §8.2) |
| 4 | Long Island | New York | First hard loss-lesson map; retreat/survive (= escape, §8.2) |
| 5 | Trenton | New Jersey | Tight-slot raid; small elite force |
| 6 | Princeton | New Jersey | Momentum follow-up; turn-limit objective (= survive-X, §8.2) |
| 7 | Brandywine | Pennsylvania | Wide map, multi-front defense |
| 8 | Germantown | Pennsylvania | Fog of war introduction |
| 9 | Saratoga | New York | Mid-campaign climax; 3rd General slot unlocks |
| 10 | Monmouth | New Jersey | Enemy Generals begin mirroring player abilities |
| 11 | Siege of Charleston | South Carolina | Coastal siege — naval is flavour, not a system (§3.4; issue 13) |
| 12 | Camden | South Carolina | Designed setback — brutal composition puzzle |
| 13 | Cowpens / Guilford Courthouse | South Carolina / North Carolina | Combined; attrition mastery test |
| 14 | Yorktown | Virginia | Finale — combined siege and field battle |

Objectives vary FE-style: seize, defend, escape, survive-X-turns, rout. No in-battle economy or capture/income loop.

Objective semantics (ruled 2026-08-03, grilling issue 04). A chapter has exactly one primary objective **at a time**, plus any number of secondaries — scripted mutation events in chapter data may change the primary or the champion designation mid-mission (ruled 2026-08-12, reference-mining issue 32 — DECISIONS G29 Q4; amends G4 Q6's wording, not its intent — never two primaries at once). Win/loss evaluation always uses the current primary; `objective_progress` announces the change:

- Seize — a General ends its move on the HQ tile; the mission is won instantly on arrival. Non-General units cannot seize. (A defended HQ must be cleared first — no unit may end its move on an occupied tile, §3.4.)
- Defend — the mission is won at the end of turn N ("end of turn" = after the enemy phase of N, §3.7 — ruled G27). An enemy unit ending its turn inside the marked zone loses the mission immediately. Player units are not required to occupy the zone.
- Escape — all surviving deployed Generals must exit via the exit tiles; the mission completes when the last of them exits. Non-General units left behind are lost: they count as losses for secondary bonuses, but cost no souls (they are per-battle deployments).
- Survive-X-turns — the mission is won at the end of turn X if it has not been lost ("end of turn" = after the enemy phase of X, §3.7 — ruled G27). (Loss conditions: §6 "Defeat, retry, and saves", ruled grilling issue 05.)
- Checkpoint precedence (ruled 2026-08-12, reference-mining issue 29 — DECISIONS G27): when a win condition and a loss condition are satisfied at the same checkpoint, **the win evaluates first** — a simultaneous win+loss is a win. Mid-phase instant triggers (seize's instant win, defend's immediate zone loss) fire the moment they occur and cannot coincide with each other (D9's counter rule precludes the intra-skirmish case).
- Rout — every enemy unit that appears in the mission is destroyed: reinforcements included (they exist — §8.3 spawn events, ruled 2026-08-06, grilling issue 14) and enemy Generals included. There is no general flee mechanic; the single exception is a chapter-scripted boss-retreat event (§7, ruled 2026-08-03, grilling issue 07) — a General removed by such an event no longer counts toward rout.

(The chapter table's descriptors map onto the five types — ruled 2026-08-06, grilling issue 14: "siege" = seize, "retreat/survive" = escape, "turn-limit" = survive-X-turns.)

Challenge content (all asset reuse): the farming skirmish battles above, plus optional score-attack (turn-count) medals on story maps.

8.3 Data shape

Chapters are data, not code. The complete chapter schema (consolidated 2026-08-06, grilling issue 14 — fields marked with their ruling):

- `id`, name key, colony, position on the campaign map
- prerequisite chapter id — singular: the campaign is strictly linear (issue 14, Q4)
- battle map file — map data holds the terrain grid, start tiles (G9), and activation groups (G11). Authored in **Tiled** and stored as Tiled JSON (`data/maps/<id>.tmj`), parsed directly by the loader — ruled 2026-08-13, DECISIONS G43; the authoring profile and validation rules are the map schema (schema-forge ticket 43)
- per-category deployment slot caps: general / tank / infantry (issue 09)
- fog flag (issue 12)
- `objective` — the single primary: type (`seize | defend | escape | survive | rout`) + parameters per §8.2 (issue 04)
- optional `loss` conditions beyond the standard ones (issue 05)
- reinforcement spawn events — turn number + spawn tiles/edges + unit list; spawned units enter under normal dormancy unless the event marks them active; rout counts them (issue 14, Q1). A spawned unit **appears on its spawn tile** — no off-map entry walk — and is targetable and visible (fog rules permitting) from that moment; "edges" are simply authored border tiles (ruled 2026-08-11, reference-mining issue 26, Q3 — DECISIONS G24). If the spawn tile is occupied at the spawn turn, the unit spawns on a deterministic alternate tile (Q4 = shift; the shift chain and no-legal-tile fallback are logged at DECISIONS G24)
- enemy roster, including per-appearance enemy-General levels and scripted retreat events (issue 07); champion designation — the chapter's enemy General; simplest reading, logged G14: with multiple enemy Generals, chapter data marks which one is the champion
- scenes: intro and debrief ids, plus mid-mission scenes with event triggers — turn number, a unit entering a named region, or a named unit's death or retreat (issue 14, Q2). Event timing & order (ruled 2026-08-12, reference-mining issue 32 — DECISIONS G29): a turn-number trigger authors its boundary — `at: start` (player phase begins) or `at: end` (after the enemy phase, the §3.7/G27 boundary); when a scene and spawns share a trigger, the scene resolves first, then the spawns (the pause → beat → spawn → resume envelope). A turn-end trigger coincides with §8.2 checkpoints, where G27's win-first precedence governs — a won mission ends before the event fires.
- objective/champion mutation events (ruled G29 Q4) — chapter data may declare scripted events, on the same trigger vocabulary, that replace the primary objective or move the champion designation mid-mission (§8.2). Simplest reading, logged G29 (correct if wrong): the kill-champion secondary follows the current designation at the moment of the kill.
- base soul award; secondary objectives with their bonuses (per-chapter data, issue 10); a preservation ("lose no units") secondary additionally authors its loss scope — which slot categories count as losses (ruled 2026-08-12, G36 Q3; `units_lost` in the mission summary reports total non-General losses regardless — exact field shape: schema-forge ticket 44)
- unlocks (a General slot, a roster addition, an item entering the shop catalog — G33 Q2) — fire on the first story clear only; farming replays pay souls only and never re-fire unlocks (issue 14, Q5)
- enemy item pool (optional — G33 Q6): items available to the enemy side this chapter; the coordinator values their use like active abilities (§3.5)

Adding or reordering a chapter is a data edit.

9. Systems Explicitly Cut

Easy/Normal/Hard tiers → one moderate difficulty + farming (easy) + No-Revive (hard)
In-battle production, capture/income economy, economic AI (the most expensive AW component)
Hit/crit/dodge RNG (deterministic skirmishes suit a 5-hour campaign)
HP-degradation — damage scaling with remaining HP (formerly the squad tier rule; abolished with the squad/single merge — ruled 2026-08-12, G35. Reintroducing any HP-scaling damage mechanic requires a new ruling.)
Per-kill EXP (kill-feeding meta deleted; completion-only awards)
Budget carry-over between missions
Death-variant cutscene writing
Voice acting

Partially reversed (ruled 2026-08-12, reference-mining issue 28 — DECISIONS G26; canonical: §4 "Items & the camp shop"): consumable healing items, a souls-funded camp shop, and one **shared** army inventory now exist. Still cut: per-unit inventory (the pool is shared), weapons as items, durability or weapon uses, equipping, convoy-as-system, and **trading between units** (throwing a consumable consumes it — it is delivery, not transfer). Armament remains a fixed property of a unit type in data, not a carried object. Souls plus deployment slots (§4) remain the only economy — items are a soul sink, not a currency. The Fire Emblem reference implements the full item stack; only the pieces named in §4 carry over.
Weapon-level stats — might, weight, hit, crit, avoid.

10. Engine & Scope

Engine: Godot. Godot has mature grid-tactics paths (AStarGrid2D, GDQuest tactics tutorials, open-source FE-likes) and Dialogic for the VN layer. Dialogic is **adopted** as the VN/cutscene presentation layer (ruled 2026-08-12, reference-mining issue 32 — DECISIONS G29; owner: "No need to reinvent the wheel") — the single exception to the no-plugins convention. Boundaries: Dialogic renders, never simulates (zero presence in /sim; headless tests stay plugin-free); scene *content* is authored in DoT's JSON schema in /data (D1's one-format rule holds — §7), with the cutscene runner driving Dialogic; the gray-box prototype may still use the stub textbox until the VN layer is built (pre_prompt; simplest reading logged G29 — correct if wrong).

Scope estimate (solo, part-time): ~6–9 months

ComponentEstimateCore tactics engine (grid, movement, skirmish resolution, turns)2–3 monthsEnemy AI (FE-tier: dormant-until-approached + target scoring)3–5 weeksDeployment screen, soul/level UI, fog of war3–5 weeksCampaign content: 14 maps designed & tuned, ~40 mission scenes + 14 character scenes, damage table2–3 monthsMenus, save/load, farming mode, No-Revive mode, polish, playtesting1–2 months

Riskiest remaining work: (1) the skirmish damage table across two tiers, (2) tuning per-chapter slot caps and the soul economy, (3) mission design carrying the whole difficulty curve. All design-side, all spreadsheet-shaped, all prototypable with gray boxes before any art exists.

Architecture and coding standards are specified separately and bindingly in `conventions.md`. The short version: pure `/sim` logic with no nodes and no RNG, a view layer that holds no rules, all content in `/data`, and one function backing both the damage forecast and the resolved skirmish.

11. Economy Starting Numbers (tune later, verify on one spreadsheet)

Every constant below lives only in `data/economy.json` — the single source of truth; this section quotes starting values from it and states design latitude (ruled 2026-08-06, grilling issue 10).

Base soul award: 100/mission (starting constant); secondary objectives: up to +50 as an authoring guideline — bonuses are per-chapter data (§8.3), and the +25 turns / +15 no-unit-losses / +10 champion split is an example palette, not a canonical set
14 missions ≈ 1,400–2,100 souls (no farming)
Level costs: 30 / 60 / 100 / 150 / 210 (550 to max one General)
Revival: flat cost × current level — design latitude 15–20×; starting constant 18×
No-grind target outcome: ~2 maxed Generals, rest at level 2–3
Farming yield: design latitude 30–50%; starting constant 40% (replay payout semantics: §6)
Under-filled-slot soul bonus (G9): magnitude unruled — data authoring, placeholder in economy.json


12. Open Decisions for Pre-Production

Resolved in v1.1: player side (Continentals), nemesis (the isekai'd mage), enemy faction structure, the Arnold mid-boss recommendation — see §7.

Resolved in v1.4:

- Matchup system — the armament triangle, rifle → melee → musket → rifle; the three classes are exhaustive, no fourth class ("arcane" is a damage-table archetype only — see §3.1; ruled 2026-08-02, grilling issue 01)
- "HD 2D" definition — high-resolution flat 2D sprites, not Octopath-style 2.5D (§14)
- Chapter select structure — battles are chapters, the colonies are the map (§8)
- Item/inventory/trading economy — cut (§9)

Resolved in v1.5:

- Damage-table structure — every General, player and enemy alike, has a unique row/column (unique `type`, §3.3); archetype sharing rejected (ruled 2026-08-10, grilling issue 20 — decisions-reconciliation)

Still open:

1. Final General roster (which 7–8 figures), their 14 abilities, and each one's armament class. (Each roster addition now also requires authoring its own damage-table row and column — G18.)
2. Exact (non-General) unit type list — target ~8–10 types — each with an armament class assigned (prototype roster renamed — ruled 2026-08-12, G36: Line Infantry, Rifleman, Cavalryman, Cannoneer, Death Knight, Bound Golem, Arcane Sentinel).
3. ~~Deployment costs per unit and per General~~ — superseded (ruled 2026-08-06, grilling issue 09: battle budget abolished). Author instead: per-chapter slot caps (general/tank/infantry) and each unit type's `slot_category`.
4. Character design direction (the anime girl conversation — separate session).
5. The mage's identity, magic school, and personality. The rival CO deserves as much design as any player General.
6. Confirm or reject the Arnold-as-corrupted-lieutenant arc.


13. Budget & Production Analysis (Honest Version)

Rates are 2026 planning bands, not quotes. The §10 estimate of 6–9 months covered code/systems/mission design only and assumed Godot familiarity (first Godot project: ×1.5–2). Solo indie estimates historically run ~2×. All-in realistic timeline: 1.5–2.5 years part-time, with the spread determined almost entirely by the art strategy.

Asset bill (either path)


Portraits: ~15 characters × 2–3 expressions ≈ 40–50 images, one consistent anime style. The selling point — quality non-negotiable here.
Unit sprites: ~25–30 animated sets (~8–10 generic types × 2 factions via recolor + ~14 uniques; 2–4 frame animations suffice for grid tactics)
Tilesets: 2–3 sets (colonial forest/farm, coastal, winter, urban/siege)
VN backgrounds: 10–12 · UI/icons: menus + ~14 ability icons · Music: 20–30 min + SFX · Script: ~25–40k words


DIY vs. hire, per discipline

DisciplineDIY (part-time hrs)HireVerdictPortraits300–500 (only if already skilled)$2.5k–7.5k indie / $10k+ proHire — one artist for all 15 characters (style consistency is make-or-break)Unit sprites150–300$2k–8k ($75–250/set)Hire or modified packs; enemy recolorsTilesets80–150$1.5k–4k custom / $50–300 packsPacks — nobody reviews the grassVN backgrounds60–120$1k–3k / $100–300 packsPacks or cheap commissionsUI/icons40–80$500–1.5kEitherMusicnot viable for non-musician$1.5k–4k newer / $6k–15k established / $200–600 stockStock first; upgrade 3–4 signature tracks laterSFX—$100–300 packsPacksWriting150–300 — best DIY value in the project$3k–6k ($0.10–0.20/word)DIY — it's the voice of the game

Three scenarios


Full DIY (requires existing art skill): ~$500 cash · 18–30 months · highest abandonment risk
Hybrid (RECOMMENDED): DIY code + design + writing; hire one portrait artist; commission/pack sprites; pack/license the rest → $5k–12k · 12–16 months
Full outsource (non-code): $18k–35k (past $50k at senior rates) · 8–12 months of your time · +10–15% of hours for contractor management; portrait sets take an artist 2–4 calendar months regardless


Standing rules


One portrait artist for the entire cast. Mixed styles read as an asset flip even when each piece is good.
Gray-box before commissioning. Prove the skirmish loop is fun with rectangles first — art is the last money spent, because post-art design changes are the most expensive kind.
Money goes where players look: portraits first, music second, everything else packs until revenue argues otherwise.

14. Presentation Specification

Locked in v1.4. These numbers exist because map design, UI layout, camera behavior, and every art commission depend on them, and changing them later invalidates finished work.

Direction: HD 2D — high-resolution flat 2D sprites, drawn for a flat tactics grid. Explicitly not 2.5D.** Octopath-style layered depth was priced at roughly 3× the art cost for a genre that reads top-down anyway, and it complicates every camera and overlay decision on a grid. Rejected. This is not a pixel-art game either: sprites are high-resolution and filtered, not snapped.

| Parameter | Value |
| --- | --- |
| Base viewport | 1920 × 1080 |
| Stretch mode | `canvas_items` |
| Stretch aspect | `expand` |
| Logical tile size | **96 × 96 px** |
| Terrain art authoring size | 96 × 96 (or 192 × 192 for a future 4K/zoom pass) |
| Unit sprite authoring size | 192 × 192 — 2× tile, so units may overhang their tile for readability |
| Portrait authoring size | ~1024 × 1024, displayed up to ~700 px tall in VN scenes |
| Texture filter | Linear, mipmaps on |
| Frame rate target | 60 fps |

Camera. Pans across maps of any size; centers on the acting unit during enemy phase; plus a **zoom-out toggle and a minimap/overview mode** (ruled 2026-08-14, DECISIONS G44 Q3 — the G44 map-scale bands put standard maps at 2+ screens, where pan-only navigation and the danger-zone union overlay stop fitting one view; gray-box implementations are ColorRect-grade). (The former "fits maps up to 16 tiles wide without scrolling" claim was struck — maps have no hard dimension bounds; the old 12×12–16×16 authoring practice was superseded by the G44 bands, §8. Ruled 2026-08-06, grilling issue 15 / 2026-08-14, G44. At 96 px tiles a 1920×1080 viewport shows 20 × 11.25 tiles.)

Fonts. One UI font covering Latin + Latin Extended. Locale target: English-only (ruled 2026-08-06, grilling issue 15 — this replaces the former reference to a "§12 item 12" locale list, which never existed). No Cyrillic or CJK stack; `tr()` keys remain mandatory from the first line of UI (conventions §6), so a future locale expansion is a translation task, not a retrofit.

Gray-box phase. Until the skirmish loop is proven fun, all of the above is honored *dimensionally* with ColorRects, polygons, and text labels: units are tinted rectangles with a type initial and HP number, movement range is a blue tile overlay, attack range is red, enemy danger zones are a third overlay tint (per-enemy and union-toggle forms — G31, §3.1), portraits are colored rectangles. Art drops into the same dimensions later with no relayout. No art money is spent before the loop is fun.



End of document (v2.0 — map scale: per-archetype bands (16×12–20×16 / 24×20–32×24 / 32×24–40×30), scaled slot caps + multi-front mandate, §14 zoom+minimap, movement +1 retune, G44; v1.9 — map-authoring pipeline: Tiled adopted as the map editor, `data/maps/*.tmj` canonical, G43; v1.8 — individual-unit roster renames (Cavalryman, Cannoneer, Rifleman; Line Infantry kept), objective-only chapter beats, per-chapter preservation-secondary scope, data-declared ability target filters, G36; v1.7 — the single-unit paradigm: squads/singles merged into one unit tier, degradation abolished, per-unit counter_mult added, min-1 narrowed to initiated attacks, AW citation dropped, G35). Next session suggested focus: the General roster + abilities (open decision #1), or the character design conversation.