<!-- Text extracted from The_Wanderers_Guild_GDD.pdf (v0.1). The PDF is the original; this file is the working copy. -->

       THE WANDERER'S GUILD

                                          Game Design Document

Working title. Cozy dark-fantasy tactical adventure RPG with a huge, mysterious
   world, strange people, systemic weirdness, and a strong focus on discovery.

Version 0.1 -- Concept + Vertical Slice Specification

The Wanderer's Guild -- GDD v0.1                                                 1
1. High Concept

One-sentence pitch: A cozy dark-fantasy tactical RPG where you run a tiny adventurer's guild, explore a
strange interconnected world, solve everyday problems and absurd mysteries, and slowly discover that
reality itself is changing.

Player promise: The world itself is the reward. The player should repeatedly think, "What is that?" and
choose to investigate because a distant landmark, strange NPC, rumor, ruin, creature, or event caught
their attention.

Tone: 60% cozy, 25% strange/absurd, 15% dark/mysterious. The game can be beautiful, funny,
unsettling, and melancholy without becoming grimdark.

Core fantasy: Be a wandering problem-solver who builds a home, builds relationships, becomes
capable, and gradually becomes entangled in a world-scale mystery.

2. Design Pillars

  - Awe through discovery: vistas, landmarks, hidden places, environmental storytelling, and camera
    reveals are core rewards.

  - Cozy dark fantasy: warm villages, camps, guild life and ordinary routines coexist with ruins, ancient
    gods and dangerous wilderness.

  - Systemic weirdness: a world-event system creates unexpected consequences while authored
    encounters provide memorable handcrafted moments.

  - Tactical consequence: combat is grid-based and turn-based, with meaningful positioning, movement,
    action economy, terrain and character abilities.

  - The world remembers: quests and events can alter NPCs, locations, rumors, shops, relationships and
    future encounters.

  - Small studio scalability: systems are data-driven, regions are modular, and the first vertical slice
    proves the core loop before full content production.

3. Genre & Format

  - Genre: exploration/adventure RPG + tactical turn-based combat + light life-sim/base building.
  - Perspective: 3/4 elevated exploration camera, freely orbitable and zoomable; cinematic camera control

    for discoveries, conversations and important moments.
  - World: interconnected medium-sized regions rather than one enormous seamless map.
  - Combat: Fire-Emblem-like grid tactics combined with an original tabletop-inspired action economy:

    Movement + Action + Bonus Action + Reaction.
  - Platform target: PC first; controller and mouse/keyboard support planned.

The Wanderer's Guild -- GDD v0.1                                                                           2
4. Visual Direction

Primary target: high-detail pixel-art-inspired 3D presentation rather than conventional low-poly art.
A fully 2D pixel-art world with a freely rotating 3D camera creates practical problems: sprites need
many orientations, lighting consistency is difficult, and environments become expensive to author. The
recommended solution is a 3D world rendered through a pixel-art pipeline: simple-to-moderate 3D
geometry, 64×64 or 128×128-inspired textures/materials, low-resolution rendering, pixel-stable edges,
controlled palettes, strong silhouettes, and hand-authored pixel textures.
Rule: do not chase photorealism. Detail should read as deliberate pixel art, even when the underlying
scene is 3D.

4.1 Camera

  - Default: 3/4 elevated camera, roughly 45-55° downward.
  - Free yaw rotation and controlled pitch within a readable range.
  - Smooth zoom from close interaction view to wide exploration view.
  - Camera collision and occlusion handling are mandatory.
  - Player remains relatively small on screen so the environment dominates.
  - Cinematic mode can temporarily take control for reveals, landmarks, boss entrances and major story

    beats.
  - Cinematic transitions should be short and return control quickly; avoid turning exploration into

    constant cutscenes.

  - [Updated 2026-09-28] Camera states: NORMAL (elevated 3/4, ~-40..-55°) and LOOK (low pitch toward
    the horizon, player framed low) are one continuous zoom rail, not separate modes; the player can
    always zoom in to look at distant landmarks. CINEMATIC reveals override all constraints briefly
    and return control facing the revealed landmark. Landmarks must read within LOOK's pitch range.

4.2 Visual Composition Rules

  - Every region needs large readable silhouettes: castles, trees, mountains, statues, bridges, towers,
    waterfalls, dead gods, etc.

  - Landmarks should be visible from multiple distances and act as navigation anchors.
  - Use warm/cool contrast: lanterns and fireplaces against fog, moonlight and cold landscapes.
  - Avoid visual noise. Large shapes first; small details second.
  - Environmental reveals should be authored as moments: a hill crest, forest opening, bridge crossing,

    mountain pass, or lake shore.

The Wanderer's Guild -- GDD v0.1                                                                         3
5. World & Setting

The setting is a fantasy world that has existed for so long that its people have normalized the
impossible. Ancient ruins are infrastructure. Monsters have jobs. Ghosts have paperwork. Gods may still
exist, but nobody agrees what counts as a god.
The player begins in a neglected frontier settlement where an old adventurer's guild has fallen into
disrepair. The guild is not prestigious. It survives by accepting jobs nobody else wants.

5.1 World Structure

  - Central hub town and guild.
  - Deep Forest -- dense, old, mysterious, inhabited by spirits and woodland communities.
  - Sunken Swamps -- wet ruins, strange lights, smugglers, amphibious creatures and lost relics.
  - Western Wilds -- rough grasslands, old roads, abandoned farms and roaming beasts.
  - Central Lake -- water routes, fishing villages, ruins and a major visual landmark.
  - Old Kingdom -- enormous ruins and remnants of a dead civilization; bureaucratic ghosts and ancient

    mechanisms.
  - Frozen North -- mountains, snowbound settlements, fortresses and ancient things beneath the ice.
  - Eastern Hills -- smaller villages, mines, old watchtowers and travel routes.
  - Southern Plains/Deserted Lands -- dry, weathered terrain, forgotten roads and remnants of older

    cultures.

5.2 World Mystery

The underlying mystery should be discovered indirectly. Early clues are mundane: changed
constellations, NPCs remembering different versions of events, roads that seem older than yesterday,
ruins whose inscriptions do not match history, and objects that appear in places they should not exist.
Over time the player realizes the world is not merely decaying; reality is becoming inconsistent.
Do not explain the mystery early. Let players form theories.

6. Core Gameplay Loop

Wake at the guild  check jobs/rumors  choose destination  travel and explore  encounter
NPCs/objects/events  resolve a problem through dialogue, exploration, combat or improvisation 
collect information/resources  return to guild  upgrade, craft, recruit, decorate, socialize  new
rumors/events become available.
The game should never punish the player for spending time exploring. The main story should progress
at a measured pace, while local stories provide most of the moment-to-moment motivation.

The Wanderer's Guild -- GDD v0.1                                                                         4
7. Exploration

  - Free movement in 3D with a readable 3/4 camera.
  - Landmark-based navigation rather than waypoint dependency.
  - Interactive objects: doors, chests, shrines, books, signs, plants, resource nodes, campfires, strange

    artifacts.
  - Traversal is initially simple; later upgrades can unlock new routes or interactions.
  - Hidden paths, optional caves, overlooks and environmental puzzles.
  - The player can camp at designated locations and some safe wilderness sites.
  - Exploration can trigger authored encounters and systemic world events.

7.1 The Awe System

A lightweight design framework, not necessarily a visible stat. Important discoveries are tagged as Awe
Moments. They trigger composition changes: camera pull-back, music sting, environmental animation,
NPC reaction, or a new map marker. Examples include discovering a city beneath a lake, seeing a
colossal creature move in the distance, or reaching a mountain pass overlooking multiple regions.

8. Tactical Combat

Combat uses a square grid and a turn-based structure inspired by classic tactical RPGs. The system is
original and should not copy proprietary rules text.

8.1 Turn Structure

  - Initiative: units are ordered by an initiative value; ties use a deterministic tiebreaker.
  - Turn: a unit receives Movement, one Action, one Bonus Action, and potentially one Reaction resource.
  - Movement: spend movement points to traverse grid cells. Terrain can modify cost.
  - Action: primary attacks, powerful abilities, interact, dash, help, etc.
  - Bonus Action: quick abilities, stance changes, secondary attacks, item use or class features.
  - Reaction: one interrupt/response per round, such as opportunity attack, guard, counter or protective

    ability.
  - End Turn: resolve statuses, environmental effects and ongoing hazards.

8.2 Resolution

Use a simple d20-style resolution layer for attacks, skill checks and contested actions. Core formula can
be: d20 + attribute/skill modifier + situational modifiers vs a target difficulty. Critical results can occur
on natural extremes. Keep numbers compact and readable.

8.3 Tactical Factors

  - Elevation and line of sight.
  - Cover and partial cover.
  - Flanking/rear attacks where appropriate.
  - Terrain hazards: fire, mud, water, poison pools, ice, brambles.
  - Push/pull and positional abilities.
  - Status effects: burning, bleeding, chilled, stunned, rooted, frightened, weakened, inspired.
  - Enemy behaviors with clear telegraphs and roles.

The Wanderer's Guild -- GDD v0.1                                                                               5
9. Player Character & Progression

Vertical slice: one placeholder adventurer with a small fixed kit. Full game: character creation with
appearance, background, origin, combat archetype, starting proficiencies and personality tags.
Progression should reward both combat mastery and exploration. Avoid pure numerical inflation.
Potential full-game archetypes: Vanguard, Scout, Arcanist, Warden, Trickster, Mystic, etc. These are
starting identities, not rigid classes.

10. Companions & NPCs

  - Companions have relationships, preferences, quirks, strengths and fears.
  - Recruitment can come from quests, chance encounters, guild jobs or exploration.
  - Companions can comment on locations and react to world events.
  - NPC schedules create the feeling that the world exists without the player.
  - NPCs can remember selected outcomes rather than every interaction.

11. Guild / Base Building

The guild begins as a shabby building and grows into a lived-in headquarters.
  - Repair rooms and unlock functions.
  - Workshop: crafting/upgrades.
  - Library: lore and research.
  - Kitchen: meals and temporary buffs.
  - Training room: combat testing and skill upgrades.
  - Trophy/curio room: display strange items.
  - Guest/companion rooms: relationship progression.
  - Notice board: jobs and rumors.
  - Decorations can be cosmetic but should also communicate progress.

12. Quest System

Quests should be authored from reusable data structures. A quest is a chain of conditions, objectives,
choices, consequences and rewards.
Quest types: delivery, investigation, rescue, hunt, escort, retrieval, social problem, dungeon/ruin,
mystery, world event, companion story, guild upgrade.
A quest should ideally support more than one solution: combat, dialogue, exploration, item use,
knowledge, or simply choosing to walk away.

The Wanderer's Guild -- GDD v0.1                                                                        6
13. Systemic Weirdness

This is a major identity system. The game combines a World Event Director with handcrafted weird
encounters.

13.1 World Event Director

  - Each region has event pools tagged by biome, time, weather, reputation, story state and previous
    events.

  - Events have weights, cooldowns, prerequisites and consequences.
  - The director selects an event, but the event itself can generate variants.
  - Events can alter NPC schedules, shops, quests, enemies, weather, rumors or landmarks.
  - Avoid random chaos that makes quests unreadable. Randomness should create stories, not erase

    player agency.
Example: a village's well starts producing glowing fish. Possible causes include a harmless magical leak,
a sleeping spirit, an underground river, or an event from the world mystery. Different investigations
lead to different outcomes.

13.2 Handcrafted Weird Encounters

These are authored, memorable moments: a frog knight demanding a toll, a ghost bureaucrat
requesting an expired permit, a giant asleep beneath a village, a merchant selling an object that
remembers its previous owner, or a group of villagers holding a serious meeting about an obviously
ridiculous problem.

14. Economy, Items & Crafting

  - Simple currency with regional variation only if it adds meaningful flavor.
  - Equipment slots: weapon, offhand, armor, accessory, utility.
  - Consumables and quest objects.
  - Crafting focuses on useful preparations rather than hundreds of recipes.
  - Rare objects should often have narrative utility, not just higher stats.
  - Inventory should be readable and compact.

15. Day/Night, Weather & Camping

Time changes atmosphere, NPC schedules, encounters and visibility. Weather can be scenic first and
systemic second. Camping is a quiet reset point where the player can cook, talk, inspect discoveries,
and receive companion scenes.

The Wanderer's Guild -- GDD v0.1                                                                           7
16. UI / UX

  - Minimal HUD during exploration: health/condition, small compass/minimap, interaction prompt and
    quick-access items.

  - Map screen shows discovered regions, landmarks, guild jobs and rumors without revealing everything.
  - Combat HUD shows grid highlights, unit information, action/bonus/reaction availability, predicted

    damage and status effects.
  - Dialogue UI should be compact and atmospheric rather than covering most of the screen.
  - Menus should support controller navigation from the beginning.
  - Use iconography + text; never rely on color alone.

17. Audio Direction

  - Exploration: sparse ambient music, environmental sound, distant wildlife and subtle magical tones.
  - Town: warmer instrumentation, fireplaces, voices, market sounds.
  - Combat: percussion and tension, but avoid turning every encounter into an epic boss track.
  - Awe moments: short musical reveals rather than constant cinematic scoring.
  - Weird events can use small audio surprises.

18. Vertical Slice

Purpose: prove that the game's camera, visual presentation, exploration, tactical combat, dialogue,
questing, weirdness and guild loop are fun before building the full world.

18.1 Slice Scope

  - Hub: one small village + guild building.
  - Region: one forest area with a small ruined landmark and one hidden location.
  - Player: one placeholder character.
  - Companion: optional simple animal companion or one NPC companion.
  - Enemies: 3 archetypes: melee beast, ranged/utility enemy, elite ruin guardian.
  - Combat: 6×8 or 8×10 grid encounters; movement, action, bonus action, reaction, terrain and 3-5

    abilities.
  - Quest: missing item / investigation quest with at least two solutions.
  - Weird event: one systemic event with 3 variants.
  - Guild: one upgrade and one interactable room.
  - Camera: free orbit, zoom, occlusion, one scripted reveal.
  - UI: exploration HUD, combat HUD, dialogue, inventory-lite, map-lite.
  - Save: one local save slot.

18.2 Vertical Slice Success Criteria

  - The player can walk from the guild to a scenic overlook and immediately understand the game's visual
    promise.

  - The camera feels stable and readable while orbiting and zooming.
  - A normal exploration session naturally leads into at least one unexpected event.
  - A tactical encounter is understandable without reading a manual.

The Wanderer's Guild -- GDD v0.1                                                                          8
- The player can solve the sample quest through at least two approaches.
- Returning to the guild feels like returning home.

The Wanderer's Guild -- GDD v0.1                                          9
19. Technical Direction -- Godot

Engine: Godot 4.x.
Architecture principle: data-driven systems + composition over deep inheritance. Keep game logic
separate from presentation where practical.

19.1 Suggested Project Structure

              res:// scenes/ player/ world/ combat/ ui/ npcs/ scripts/ core/ player/ combat/ world/ quests/ dialogue/ inventory/ events/
              save/ data/ actors/ abilities/ items/ quests/ encounters/ events/ art/ audio/ shaders/ tests/ tools/

19.2 Key Systems

  - GameState: current region, quest flags, world flags, time, weather, relationships.
  - Grid/Combat: board, cells, pathfinding, turn manager, action economy, targeting, status effects.
  - QuestManager: objective tracking, conditions, branching consequences.
  - DialogueManager: dialogue data, conditions, choices, events.
  - WorldEventDirector: weighted event selection and cooldowns.
  - SaveManager: versioned save schema.
  - CameraController: orbit, zoom, collision, cinematic override.
  - Data resources: Godot Resource-based definitions for abilities, items, actors, quests and events.

19.3 Pixel-Art Rendering Recommendation

Prototype the visual pipeline before producing large amounts of art. Recommended experiment: 3D
scene  low internal viewport resolution  nearest-neighbor/upscaled presentation  pixel-art
textures/materials  controlled lighting and fog  optional dither/post-process. If the result does not
preserve the desired pixel-art identity during free camera rotation, fall back to a more explicitly
low-poly 3D style rather than forcing 2D sprites into a fully free 3D camera.

The Wanderer's Guild -- GDD v0.1                                                                                                          10
20. Production Roadmap

Phase 0 -- Technical Spike: camera, grid, low-res rendering, pixel material, one tiny environment.
Phase 1 -- Vertical Slice: hub, forest, player, combat, quest, dialogue, event, save/load, basic guild
upgrade.
Phase 2 -- Content Prototype: second region, 5-8 enemy types, 3-5 companions/NPC archetypes,
expanded event director.
Phase 3 -- Core Game: world map, guild progression, character creation, equipment, crafting, more
quests and regions.
Phase 4 -- World Mystery: main story, major landmarks, late-game systems and regional consequences.
Phase 5 -- Polish: art pass, animation, audio, accessibility, performance, controller UX, QA.

21. Content Scaling Strategy

  - Prefer reusable systems that generate variations rather than hand-authoring every minor encounter.
  - Author major landmarks and companion stories by hand.
  - Use region-specific palettes, props, enemies and event pools to make reuse feel distinct.
  - Build tools early: quest editor, dialogue data validation, encounter editor, event debugger and map

    marker tools.
  - Every new system should be proven in the vertical slice before expanding it.

22. Risks & Mitigations

  - Pixel-art + free camera becomes visually inconsistent: solve with 3D pixel-render pipeline; validate
    early.

  - Scope explosion: build one polished region before adding more.
  - Combat becomes too complicated: keep action economy small and readable.
  - Random events feel meaningless: give events consequences and memory.
  - World looks beautiful but is empty: prioritize landmarks, NPC routines and interactive

    micro-discoveries.
  - Too much UI: keep exploration HUD minimal and let the environment communicate information.

23. North Star

The player should regularly stop moving because they saw something in the
distance and thought: "I need to know what that is."

The game succeeds when exploration itself produces stories the player wants to tell someone else.

The Wanderer's Guild -- GDD v0.1  11
Appendix A -- Vertical Slice Implementation
Checklist

  - Create Godot project and baseline settings
  - Implement 3D player controller
  - Implement free 3/4 orbit camera + zoom + collision
  - Prototype low-resolution/pixel rendering pipeline
  - Build tiny village hub
  - Build forest region with landmark vista
  - Create grid board + pathfinding
  - Create turn manager
  - Implement movement/action/bonus/reaction resources
  - Implement one melee attack + one ranged/utility attack
  - Implement basic terrain modifiers
  - Implement enemy AI roles
  - Implement dialogue data + choices
  - Implement quest data + objective tracking
  - Implement one branching quest
  - Implement World Event Director
  - Implement one weird event with variants
  - Implement inventory-lite
  - Implement one guild upgrade
  - Implement save/load
  - Create exploration/combat/dialogue HUDs
  - Add one cinematic camera reveal
  - Playtest and record issues

Appendix B -- Initial Asset List

  - Player placeholder model/sprite representation.
  - Village: 8-12 modular buildings/structures, props, lanterns, signs, fences.
  - Forest: trees, rocks, shrubs, flowers, paths, ruins, water, fog cards/effects.
  - Enemies: 3 base archetypes with idle/walk/attack/hit/death animations.
  - UI: health, action economy, grid highlights, ability icons, dialogue, map, inventory.
  - VFX: hit, dodge, fire, healing, status effects, interaction, discovery reveal.
  - Audio: footsteps, UI, combat, ambient forest, village, discovery sting.

Appendix C -- Design Vocabulary

  - Awe Moment: an authored or systemic discovery whose primary reward is seeing/understanding
    something remarkable.

  - Weird Event: a world event that is unusual, humorous, mysterious or surreal and can alter local state.

The Wanderer's Guild -- GDD v0.1                                                                            12
  - Landmark: a large visual feature used for navigation and world identity.
  - World Memory: persistent state created by player actions or events.
  - Guild Loop: leave  solve problems  return  improve home  unlock new possibilities.

End of GDD -- Version 0.1

The Wanderer's Guild -- GDD v0.1                                                        13
