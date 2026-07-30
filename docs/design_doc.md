PROJECT: DEATH OR TAXATION
Backlog Design Document — v1.4

1. High Concept

An HD 2D tactics game blending Advance Wars (army-scale grid combat, skirmish damage math) with Fire Emblem (unique persistent characters, VN-style story scenes). An outlandish retelling of the American Revolution: an isekai'd mage seized control of the Crown and assassinated America's founding fathers to strangle the revolution in its crib. The player is an isekai'd lich, sent to this world to rescue America from the horrors of Taxation without Representation — by raising the murdered founders as undead Generals and fighting the Revolutionary War, battle by historical battle, as the Continentals.

Genre: Turn-based tactics / SRPG
Presentation: HD 2D, VN-style text cutscenes, no voice acting
Campaign length: ~5 hours (14 missions)
Platform target: PC first
Team: Solo, part-time
Engine: Godot (see §10)


2. Design Pillars

Simple systems, felt choices. Three unit tiers, each defined by one rule. Two currencies, each with one job.
Player freedom over balance purity. Farming is allowed; overpowered players are a feature, not a bug. Tune one moderate difficulty well instead of three poorly.
Mechanics are the story. The lich fantasy justifies revival, death-agnostic cutscenes, and soul-currency diegetically. No game-isms that need excuses.
Ship it. Every decision favors the version that a solo dev can finish. Descope toward the FE chassis whenever in doubt.


3. The Three Unit Tiers

Squads degrade. Singles endure. Generals grow.

SquadsSingle UnitsGenerals (Named)FantasyMassed troopsMonsters/war-engines (e.g., death knight)The founding fathers, raisedCombat mathAW model: damage scales with remaining HPStatic stats — full damage at any HPStatic per level, grows via EXPPersistenceDisposable, per-battlePer-battlePermanent rosterPurchased withBattle budgetBattle budgetBattle budget (deploy cost)On deathGoneGoneRevivable with souls (unless No-Revive mode)

Combat resolution: When two units interact, a skirmish resolves — both sides deal damage (attacker first, defender counters with remaining strength). Deterministic: guaranteed hits, no hit/crit RNG. Damage = lookup table (attacker type × defender type) × terrain modifier × (remaining HP% for squads), rounded down, minimum 1 damage on any legal attack (no zero-damage hits).

The damage pipeline: (single source of truth; the forecast shown to the player and the damage applied are the same computation):

```
base  = damage_table[attacker_type][defender_type]     # role matchup
base *= armament_triangle[attacker_arm][defender_arm]  # §3.1
base *= attacker_power_mult                            # General level package; 1.0 otherwise
base *= ability modifiers                              # multiplicative, in data-declared order
hp_f  = attacker_hp / attacker_max_hp                  # squads only; 1.0 for singles and Generals
terr  = 1.0 - terrain_defense[defender_tile]
damage = floor(base * armament * power * abilities * hp_f * terr)
damage = max(damage, 1)                                # minimum 1 on any legal attack
```
Rounded down; minimum 1 damage on any legal attack — zero-damage hits are impossible.

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

Player-facing readability. The forecast popup must show the matchup state — advantage, neutral, disadvantage — alongside the exact damage numbers. Because combat is deterministic, the forecast is a promise, and the triangle is only a meaningful decision if the player can see it before committing.

4. The Two Currencies

Battle Budget (per-mission, does not carry over): Each mission grants a fresh budget. Spent on the pre-battle deployment screen to buy squads, single units, and to field Generals (Generals cost budget too — stronger Generals cost more). Composition is the pre-battle puzzle: heroes + chaff vs. balanced army.

Souls (persistent, campaign-wide, shared pool): Awarded on mission completion only — base award + secondary objective bonuses (turn count, squad preservation, kill the enemy champion). Spent between missions on two things:

Leveling Generals (escalating cost per level)
Reviving dead Generals (flat cost × the character's current level)


No mid-mission spending. Shared pool means benched Generals never fall behind and rotation is free.

5. General Progression

Roster: 7–8 Generals. Deployment limit of 2 slots, growing to 3 mid-campaign. Story missions may force-deploy specific Generals.
Levels: 5 per character, hard cap. Significant cost, significant gain.

Levels 1, 2, 4: chunky stat packages (+15–20% effective power each, visibly changes skirmish math)
Levels 3, 5: unlock an ability (active skill, aura affecting adjacent squads, movement upgrade) and trigger a character cutscene

Ability budget: 2 abilities × ~7 Generals = ~14 abilities total.
Level-gated scenes: One VN scene at level 3 and level 5 per General (~14 scenes, 300–500 words each). The scene is the story of the ability. FE-support-style favor content, fused to the economy.
Stretch goal (not scope): one secret scene or bonus mission for maxing the full roster.

Stretch goal (not scope): one secret scene or bonus mission for maxing the full roster.


6. Death, Revival & Difficulty

Standard mode (default, single moderate difficulty):


A downed General is out for the rest of the mission, revivable between missions for souls (flat cost × level — invested carries are expensive to lose).
Dead-but-not-revived Generals still appear in cutscenes (their spirit attends the war council — one line of flavor text justifies this forever). They simply can't deploy.
Difficulty curve comes from mission design — enemy compositions that counter learned habits, terrain, objectives, enemy Generals — never stat inflation.
Farming is the easy mode. Replayable skirmish battles on reused campaign maps, rescaled enemies, souls at 30–50% of story-mission yield. Level cap of 5 is the farming ceiling: overpowered-by-breadth allowed, overpowered-by-depth impossible.


No-Revive mode (the hard mode):
Chosen at campaign start, locked in for the run.
General death = campaign permadeath (still appears in cutscenes, never battles again).
Losing all Generals = game over. Player is warned of this when selecting the mode. You better be ready.


7. Narrative

Sides: The player fights as the Continentals. The Crown (redcoats) are the bad guys. A revised, outlandish retelling of American history.
Protagonist: An isekai'd lich, sent to this world to rescue America from the horrors of Taxation without Representation. Villain-protagonist as liberator — still a lich doing lich things, but the Crown's master is worse. Play the tax-policy grievance completely straight-faced; earnestness is the joke.
The Big Bad: An isekai'd mage who arrived first, embedded himself behind the Crown, and assassinated the founding fathers to strangle the revolution in its crib — which is why they are dead and raisable, and why the lich was sent. Mirror antagonist: two otherworlders waging a proxy war over the continent. Final confrontation at Yorktown.
Generals: The murdered founding fathers and great Revolutionary generals, raised as undead — heavily stylized as anime girls (character design pass is a separate future conversation). Powers riff on the historical figures — e.g., Benjamin Franklin: electricity. Others TBD (suggestions: Washington — command auras; Hamilton — artillery/economy flavor; Lafayette — cavalry mobility; Knox — siege; Greene — attrition/retreat tactics; John Paul Jones — naval missions; Daniel Morgan — riflemen/skirmishers).
Roster growth as mission rewards: Generals can join as liberation prizes — free the region, recover the remains, raise the General, cutscene. Fuses roster pacing with mission structure.
Enemy faction: The mage's forces — redcoat squads plus his summoned constructs / bound magic (justifies non-historical enemy unit types), led by corrupted mortal enemy Generals drawn from British command (Cornwallis, Howe, Clinton, Tarleton), escalating in power alongside the player's roster.
Benedict Arnold (recommended): the mage's living American lieutenant — corrupted rather than killed — serving as recurring mid-boss and the mage's human face through the first two acts. (Much cheaper to build than a defecting-player-General version of the arc.)
Tone: Stylized, irreverent, "clearly inspired by but renamed/reimagined" wherever safer or funnier.
Cutscenes: VN-style text with character portraits (2–3 expressions each), no VA. Budget 2–4 scenes per mission (briefing / optional mid-mission banter / debrief) + 14 level-gated character scenes. All scenes proceed regardless of who is dead. No death-variant writing, ever.


8. Campaign — Major Battles of the Revolutionary War

Mission list drawn from the war's major engagements (~14 missions). Roughly 20–25 min/mission ≈ 5+ hours.
The thirteen colonies are the canvas those chapters sit on, not the selector itself.

8.1 The campaign map

A single illustrated map of the eastern seaboard with the thirteen colonies drawn and labeled as visible geography. This is the between-mission navigation screen, in the Fire Emblem world-map idiom.

Battle nodes sit at their historical locations on that map — one node per chapter, connected along the campaign route so the war's progress reads as a line moving down the coast.
Colonies are context, not buttons. They give the player a sense of place, of how far the war has spread, and of which region a mission is fought over. They are not individually selectable and they are not chapters.
-Node states are visible:** cleared, current, and locked-but-visible future chapters, so the player can see the shape of the war ahead. Selecting a node opens its briefing (objective, budget, known enemy composition), then deployment, then battle.
Cleared story nodes become replayable as farming skirmishes at reduced soul yield.
Optional flavor, cheap to build: each colony carries a liberation state that tints as its battles are cleared, turning the map into a progress readout. Purely visual — no mechanical effect.

8.2 Chapter list

Drawn from the war's major engagements — ~14 missions

| # | Chapter | Colony / Region | Role |
| --- | --- | --- | --- |
| 1 | Lexington & Concord | Massachusetts | Tutorial — squads only |
| 2 | Bunker Hill | Massachusetts | Introduce singles; defend objective |
| 3 | Siege of Boston | Massachusetts | First Generals unlock; siege objective |
| 4 | Long Island | New York | First hard loss-lesson map; retreat/survive |
| 5 | Trenton | New Jersey | Low-budget raid; small elite force |
| 6 | Princeton | New Jersey | Momentum follow-up; turn-limit objective |
| 7 | Brandywine | Pennsylvania | Wide map, multi-front defense |
| 8 | Germantown | Pennsylvania | Fog of war introduction |
| 9 | Saratoga | New York | Mid-campaign climax; 3rd General slot unlocks |
| 10 | Monmouth | New Jersey | Enemy Generals begin mirroring player abilities |
| 11 | Siege of Charleston | South Carolina | Naval / coastal mission |
| 12 | Camden | South Carolina | Designed setback — brutal composition puzzle |
| 13 | Cowpens / Guilford Courthouse | South Carolina / North Carolina | Combined; attrition mastery test |
| 14 | Yorktown | Virginia | Finale — combined siege and field battle |

Objectives vary FE-style: seize, defend, escape, survive-X-turns, rout. No in-battle economy or capture/income loop.

Challenge content (all asset reuse): the farming skirmish battles above, plus optional score-attack (turn-count) medals on story maps.

8.3 Data shape

Chapters are data, not code. Each chapter node declares: `id`, name key, colony, position on the campaign map, prerequisite chapter ids, battle map file, battle budget, intro and debrief scene ids, base soul award, secondary objectives with their bonuses, and anything it unlocks (a General slot, a roster addition). Adding or reordering a chapter is a data edit.

9. Systems Explicitly Cut

Easy/Normal/Hard tiers → one moderate difficulty + farming (easy) + No-Revive (hard)
In-battle production, capture/income economy, economic AI (the most expensive AW component)
Hit/crit/dodge RNG (deterministic skirmishes suit a 5-hour campaign)
Per-kill EXP (kill-feeding meta deleted; completion-only awards)
Budget carry-over between missions
Death-variant cutscene writing
Voice acting

No per-unit inventory, no weapons as items, no durability or weapon uses, no equipping, no consumables, no convoy, no shops, and **no trading between units**. Armament is a fixed property of a unit type in data, not a carried object. The two currencies (§4) are the entire economy. This is listed explicitly because the Fire Emblem reference project implements all of it, and none of it carries over.
Weapon-level stats — might, weight, hit, crit, avoid.

10. Engine & Scope

Engine: Godot. Godot has mature grid-tactics paths (AStarGrid2D, GDQuest tactics tutorials, open-source FE-likes) and Dialogic for the VN layer.

Scope estimate (solo, part-time): ~6–9 months

ComponentEstimateCore tactics engine (grid, movement, skirmish resolution, turns)2–3 monthsEnemy AI (FE-tier: dormant-until-approached + target scoring + squad-degradation awareness)3–5 weeksDeployment screen, soul/level UI, fog of war3–5 weeksCampaign content: 14 maps designed & tuned, ~40 mission scenes + 14 character scenes, damage table2–3 monthsMenus, save/load, farming mode, No-Revive mode, polish, playtesting1–2 months

Riskiest remaining work: (1) the skirmish damage table across three tiers, (2) pricing deployment costs and the soul economy, (3) mission design carrying the whole difficulty curve. All design-side, all spreadsheet-shaped, all prototypable with gray boxes before any art exists.

Architecture and coding standards are specified separately and bindingly in `conventions.md`. The short version: pure `/sim` logic with no nodes and no RNG, a view layer that holds no rules, all content in `/data`, and one function backing both the damage forecast and the resolved skirmish.

11. Economy Starting Numbers (tune later, verify on one spreadsheet)


Base soul award: ~100/mission; secondary objectives: up to +50
14 missions ≈ 1,400–2,100 souls (no farming)
Level costs: 30 / 60 / 100 / 150 / 210 (550 to max one General)
Revival: flat cost × current level (ballpark 15–20 × level)
No-grind target outcome: ~2 maxed Generals, rest at level 2–3
Farming yield: 30–50% of story missions


12. Open Decisions for Pre-Production

Resolved in v1.1: player side (Continentals), nemesis (the isekai'd mage), enemy faction structure, the Arnold mid-boss recommendation — see §7.

Resolved in v1.4:

- Matchup system — the armament triangle, rifle → melee → musket → rifle, with `arcane` as a neutral fourth class (§3.1)
- "HD 2D" definition — high-resolution flat 2D sprites, not Octopath-style 2.5D (§14)
- Chapter select structure — battles are chapters, the colonies are the map (§8)
- Item/inventory/trading economy — cut (§9)

Still open:

1. Final General roster (which 7–8 figures), their 14 abilities, and each one's armament class.
2. Exact squad/single unit type list — target ~8–10 types total across tiers — each with an armament class assigned.
3. Deployment costs per unit and per General.
4. Character design direction (the anime girl conversation — separate session).
5. The mage's identity, magic school, and personality. The rival CO deserves as much design as any player General.
6. Confirm or reject the Arnold-as-corrupted-lieutenant arc.


13. Budget & Production Analysis (Honest Version)

Rates are 2026 planning bands, not quotes. The §10 estimate of 6–9 months covered code/systems/mission design only and assumed Godot familiarity (first Godot project: ×1.5–2). Solo indie estimates historically run ~2×. All-in realistic timeline: 1.5–2.5 years part-time, with the spread determined almost entirely by the art strategy.

Asset bill (either path)


Portraits: ~15 characters × 2–3 expressions ≈ 40–50 images, one consistent anime style. The selling point — quality non-negotiable here.
Unit sprites: ~25–30 animated sets (9 generic types × 2 factions via recolor + ~14 uniques; 2–4 frame animations suffice for grid tactics)
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

Camera. Fits maps up to 16 tiles wide without scrolling; pans for anything larger; centers on the acting unit during enemy phase.

Fonts. One UI font covering Latin + Latin Extended at minimum. The final locale list (§12, item 12) determines whether Cyrillic and CJK stacks are needed; CJK is a separate font with separate metrics and is decided deliberately or not at all.

Gray-box phase. Until the skirmish loop is proven fun, all of the above is honored *dimensionally* with ColorRects, polygons, and text labels: units are tinted rectangles with a type initial and HP number, movement range is a blue tile overlay, attack range is red, portraits are colored rectangles. Art drops into the same dimensions later with no relayout. No art money is spent before the loop is fun.



End of document (v1.4). Next session suggested focus: the General roster + abilities (open decision #1), or the character design conversation — the narrative frame is now fully resolved and content design can begin.