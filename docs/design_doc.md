PROJECT: DEATH OR TAXATION
Backlog Design Document — v1.3

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

Mission list drawn from the war's major engagements (~14 missions, slightly above the original 12 — accepted; the historical sequence is worth it). Roughly 20–25 min/mission ≈ 5+ hours.


Lexington & Concord (tutorial — squads only)
Bunker Hill (introduce singles; defend objective)
Siege of Boston (first Generals unlock; siege objective)
Long Island (first hard loss-lesson map; retreat/survive objective)
Trenton (low-budget raid mission; small elite force)
Princeton (momentum follow-up; turn-limit objective)
Brandywine (wide map, multi-front defense)
Germantown (fog of war introduction)
Saratoga (mid-campaign climax; 3rd General slot unlocks)
Monmouth (enemy Generals begin mirroring player abilities)
Siege of Charleston (naval/coastal mission)
Camden (designed setback — brutal composition puzzle)
Cowpens / Guilford Courthouse (combined; attrition mastery test)
Yorktown (finale — everything test, combined siege + field battle)


Objectives vary FE-style: seize, defend, escape, survive-X-turns, rout. No in-battle economy or capture/income loop.

Challenge content (all asset reuse): the farming skirmish battles above, plus optional score-attack (turn-count) medals on story maps.

9. Systems Explicitly Cut

Easy/Normal/Hard tiers → one moderate difficulty + farming (easy) + No-Revive (hard)
In-battle production, capture/income economy, economic AI (the most expensive AW component)
Hit/crit/dodge RNG (deterministic skirmishes suit a 5-hour campaign)
Per-kill EXP (kill-feeding meta deleted; completion-only awards)
Budget carry-over between missions
Death-variant cutscene writing
Voice acting


10. Engine & Scope

Engine: Godot. Godot has mature grid-tactics paths (AStarGrid2D, GDQuest tactics tutorials, open-source FE-likes) and Dialogic for the VN layer.

Scope estimate (solo, part-time): ~6–9 months

ComponentEstimateCore tactics engine (grid, movement, skirmish resolution, turns)2–3 monthsEnemy AI (FE-tier: dormant-until-approached + target scoring + squad-degradation awareness)3–5 weeksDeployment screen, soul/level UI, fog of war3–5 weeksCampaign content: 14 maps designed & tuned, ~40 mission scenes + 14 character scenes, damage table2–3 monthsMenus, save/load, farming mode, No-Revive mode, polish, playtesting1–2 months

Riskiest remaining work: (1) the skirmish damage table across three tiers, (2) pricing deployment costs and the soul economy, (3) mission design carrying the whole difficulty curve. All design-side, all spreadsheet-shaped, all prototypable with gray boxes before any art exists.

11. Economy Starting Numbers (tune later, verify on one spreadsheet)


Base soul award: ~100/mission; secondary objectives: up to +50
14 missions ≈ 1,400–2,100 souls (no farming)
Level costs: 30 / 60 / 100 / 150 / 210 (550 to max one General)
Revival: flat cost × current level (ballpark 15–20 × level)
No-grind target outcome: ~2 maxed Generals, rest at level 2–3
Farming yield: 30–50% of story missions


12. Open Decisions for Pre-Production

Resolved in v1.1: player side (Continentals), nemesis (the isekai'd mage), enemy faction structure, and the Arnold mid-boss recommendation — see §7.


Final General roster (which 7–8 figures) and their 14 abilities
Exact squad/single unit type list (target ~8–10 types total across tiers)
Deployment costs per unit/General
"HD 2D" definition: high-res 2D sprites (recommended for a flat tactics grid) vs. Octopath-style 2.5D depth (≈3× art cost)
Character design direction (the anime girl conversation — separate session)
The mage's identity, magic school, and personality — the rival CO deserves as much design as any player General
Confirm or reject the Arnold-as-corrupted-lieutenant arc


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



End of document (v1.2). Next session suggested focus: the General roster + abilities (open decision #1), or the character design conversation — the narrative frame is now fully resolved and content design can begin.