# CLAUDE CODE MASTER PROMPT — THE WANDERER'S GUILD

> Canonical copy of the master prompt, kept in the repo so future sessions follow the current design.
> **Updated 2026-09-28:** combat changed from square-grid tactics to turn-based tactical combat with free
> physical positioning inside the world. The design authority remains `docs/GDD.md` (v0.2).
> Current status and decisions: `task_plan.md`, `progress.md`, `docs/DECISIONS.md`.

You are the lead technical designer and gameplay engineer for a new Godot 4.x game called **The Wanderer's Guild**, a cozy dark-fantasy exploration RPG with turn-based tactical combat, guild building and systemic weirdness.

Read the GDD (`docs/GDD.md`) as the source of truth. The GDD is the design authority; this prompt defines how you should implement the project.

## 1. GAME

The game is a cozy dark-fantasy exploration RPG with turn-based tactical combat, guild building and systemic weirdness.

Pitch:

> A cozy dark-fantasy exploration RPG where the player runs a tiny adventurer's guild, explores a strange interconnected world, solves ordinary and absurd problems, meets memorable NPCs, and slowly discovers that reality itself is changing. Turn-based tactical combat is one way to engage with this world, not the reason to explore it.

Tone: 60% cozy, 25% strange/absurd, 15% dark/mysterious.

The most important player emotion is:

> "Wait... what's that?"

The world itself should be the reward for exploration — and the world is also the battlefield.

## 2. ENGINE / PRESENTATION

Use:
- Godot 4.x
- 3D world
- 3/4 elevated exploration camera, freely rotatable, zoomable, with cinematic override
- turn-based tactical combat with free physical positioning inside the same 3D world (no grid)

Visual direction: high-detail pixel-art-inspired 3D (low internal resolution, nearest-neighbour upscale, controlled palette, strong silhouettes, fog, warm lantern light against cool environments). The visual spike has been validated; the pixel-art-3D direction is approved.

## 3. DEVELOPMENT RULE

DO NOT attempt to build the whole game. Build a **small vertical slice** first while creating architecture that can scale to the full game.

The vertical slice contains:
- one tiny village hub
- one forest region
- one landmark/vista
- one hidden location
- one placeholder player
- one optional simple companion
- three enemy archetypes
- turn-based tactical combat with free positioning in the real environment
- action + bonus action + reaction economy
- terrain, cover, line of sight, elevation and engagement zones
- one branching quest
- dialogue
- one systemic weird event with variants
- one guild upgrade
- inventory-lite
- basic save/load
- exploration HUD
- combat HUD with temporary tactical overlays
- dialogue UI
- map-lite UI
- one cinematic camera reveal

## 4. WORKING STYLE FOR NEW WORK

1. Inspect the repository and existing files before modifying them. Do not overwrite user work.
2. Short plan first, identify dependencies, then implement in small vertical increments.
3. Keep the existing folder organisation (`scenes/`, `scripts/<system>/`, `data/`, `art/`, `audio/`, `shaders/`, `tests/`, `tools/`, `docs/`).

## 5. ARCHITECTURE PRINCIPLES

Prefer: composition, small focused scripts, data-driven resources, signals/events, deterministic systems where useful, testable game logic separated from presentation, explicit state machines where state matters.

Avoid: giant GameManager/Player scripts, quest logic inside UI, per-scene enemy behaviour, duplicated combat logic, magic numbers scattered through scripts.

Design authority:
- This is an exploration RPG first. Discovery, local stories and relationships motivate travel; combat is one possible outcome, not the default solution. Preserve avoidance, investigation, negotiation and retreat when an encounter's fiction supports them.
- Keep encounter entities broader than combatants. Data-driven behavior profiles should eventually allow passive, fleeing, territorial, negotiable and world-scale creatures without requiring every entity to be a conventional hostile unit.
- Do not add traditional classes or level-based numerical progression until the core loop demonstrates a need. Leave room for growth through abilities, equipment, discoveries, relationships, guild development and player choices.

Use Godot Resources for definitions (ActorData, AbilityData, ItemData, QuestData, EventData, EncounterData, StatusData). Keep runtime state separate from static data.

## 6. CAMERA

CameraController (not in Player): elevated 3/4 view, orbit, constrained pitch, smooth yaw/zoom, collision/occlusion handling, camera-relative movement, cinematic override with a smooth return. NORMAL and LOOK are one continuous zoom rail; CINEMATIC reveals return control facing the revealed landmark. Tree crowns near the camera dither-fade.

Combat uses the same camera at a slightly pulled-back 3/4 framing that keeps the player, enemies and the environment in view. It may subtly frame the relevant target when an ability is chosen. It never becomes a top-down board view.

## 7. VISUAL SPIKE — done

(Validated in Milestone 3; keep the 640×360 internal resolution and sharp upscale unless testing demonstrates a clear problem.)

## 8. PLAYER

Placeholder character: 3D movement, idle/walk/run, camera-relative movement, interact, enter combat, selected-unit indicator, basic health and stats, combat abilities. No character creation yet.

## 9. COMBAT SYSTEM

Combat is **turn-based 3D tactical combat with free physical positioning**. It happens in the place where the encounter starts (e.g. the forest clearing): the same rocks, stream, trees, ruins, slopes and light as exploration. No separate combat scene, no teleport, no board on top of the world, no permanently visible grid. It is not action combat — nothing happens in real time.

Core turn: Movement (metres) → Action → Bonus Action → Reaction → End Turn.

Systems (reuse the existing ones where practical; see `CLAUDE.md` for current names):
- **CombatArea** — the part of the world where a fight takes place. Scans the real scene into obstacles (blocking / low cover), terrain regions (mud, water, …), elevation features and the area boundary. Owns the engage trigger and the idle enemies shown before a fight.
- **CombatSpace / MovementResolver** — world-space movement: path around obstacles with terrain cost, movement validation against the allowance, path truncation, height at a point.
- **Range / line-of-sight / cover evaluation** — in world space (distances in metres, segment tests or raycasts against real obstacles).
- **Engagement zones** — each melee-capable unit threatens its reach; leaving a threat zone provokes a reaction.
- **CombatUnit** — runtime state (HP, position as Vector3, movement left, action/bonus/reaction, statuses). Player and enemies share it.
- **TurnManager / CombatState** — initiative, turn order, action economy, command validation; commands return an event log that the presentation plays back.
- **ActionResolver** — d20 resolution and predictions (same math).
- **TargetingSystem** — valid targets by range, line of sight and team.
- **StatusEffectSystem** — timed StatusData on units.
- **Enemy AI** — brains chosen by ActorData.ai_profile.

Do not fake free movement with an invisible grid underneath. Positions are Vector3; the rules must not depend on cell coordinates.

### Combat resolution
roll = d20 + relevant modifier (+ situational: cover, elevation, status) vs defense or another target value. Natural 20 always hits (extra damage die), natural 1 always misses. Keep numbers small. Do not copy proprietary D&D text, names, tables or rules verbatim.

### d20 scope
d20 rolls are for combat (attacks, combat-related checks). Exploration is generally deterministic; dialogue uses checks only when uncertainty creates an interesting consequence; world events come from the WorldEventDirector, never from player rolls.

### Tactical features for the vertical slice
Implement only: movement in metres with terrain cost, melee attack, ranged/utility attack, one bonus action, one reaction (opportunity strike on leaving a threat zone), terrain modifiers (mud, water), line of sight, cover, elevation bonus, one or two status effects, enemy AI. Flanking later. Do NOT implement 50 abilities.

### Tactical readability without a grid
While the player decides: remaining movement range, path preview (valid / too far), blocked obstacles, enemy threat zones (highlighted when the path provokes). While targeting: range, valid targets, line of attack, blocked/cover, predicted hit chance and damage range. Thin lines, rings and markers only; they fade when not needed. Never tint large areas of the environment.

## 10. ENEMY AI

Three archetypes demonstrate the data-driven model; they are not a fixed taxonomy:
1. **Melee Beast** — approaches, attacks in reach, prioritises vulnerable nearby targets.
2. **Ranged/Utility Creature** — keeps distance, attacks exposed targets, uses cover and terrain.
3. **Elite Ruin Guardian** — slow, high defense, telegraphed powerful attack, creates a positional problem.

`ActorData.ai_profile` is a descriptive label; `ActorData.ai_brain` is the `CombatBrain` script selected by data. `BrainDispatcher` instantiates that script and applies its ordered intents through `CombatState`. It does not switch on profile names or contain an enemy taxonomy. A passive, fleeing, defensive, territorial, social, negotiable, environmental or unusual creature can use a new brain script, reuse an existing one, or leave `ai_brain` empty without changing dispatcher code.

Brains evaluate candidate **positions in world space** (sampled points around targets, cover spots, points along paths within the movement allowance), targets, distance, danger, cover and priorities. They return intents only; `CombatState` remains responsible for validating movement/abilities and resolving their events. No machine learning.

## 11. EXPLORATION — done in the slice region
Readable paths, off-path exploration, overlook, ruin, hidden location, resource nodes, interactive props, environmental storytelling, distant landmark visible early.

## 12. AWE MOMENT
One cinematic discovery at the overlook (implemented as CinematicReveal; M13 adds the music sting and polish).

## 13. DIALOGUE
Small data-driven dialogue system: speaker, text, choices, conditions, consequences, event triggers. Not hardcoded in UI.

## 14. QUEST — The Missing Ring
Receive the request; approaches: investigate an NPC, explore the forest, fight a creature, alternative solution. At least two valid outcomes; updates world state with a visible consequence.

## 15. SYSTEMIC WEIRDNESS
WorldEventDirector: weighted events, prerequisites, cooldowns, region tags, time/weather conditions, variants, consequences. Built on the `GameState` flag store. Vertical-slice event: **The Glowing Fish** (variants: magical leak, harmless spirit, underground creature, world anomaly). Randomness creates stories, never invalidates player agency.

## 16. GUILD
Guild interior with entrance, notice board, one upgrade point, one upgradable room: **Repair the Common Room** (before: damaged, dark, empty; after: fireplace, warm light, usable table, new NPC interaction).

## 17. UI
Exploration: health, small compass, contextual interaction prompt, quick slots. Minimal.
Combat: turn indicator, active unit, action / bonus / reaction availability, movement left (metres), target information, predicted result (hit %, damage range, cover, elevation), ability bar, combat log; temporary world overlays (range, path, threat zones, line of attack). No grid, no cell indicators.
Dialogue: speaker, text, choices. Use iconography + text; never colour alone. Prompts follow the last used input device.

## 18. SAVE SYSTEM
Versioned local save: player position, stats, inventory, quest state, world event state, NPC state, guild upgrade state, time, discovered landmarks. `GameState.flags` is the core of it. Schema version for migrations.

## 19. DEBUG TOOLS
Teleport, start combat (F6), win combat (F7), give item, complete quest, trigger event, advance time, reveal map, camera debug, **show combat space (obstacles, terrain regions, threat zones, paths)**, show NPC state, world reload (F5). Debug-only (`OS.is_debug_build()`).

## 20. TESTING
After each major system: run the project, test the real player flow, fix errors before the next system.
Headless tests (scenes in `tests/`, exit code = result) for pure logic: world-space movement and path cost, movement validation, terrain cost, range, line of sight, cover, elevation, engagement zones and reactions (triggering and prevention), action economy, turn order, d20 resolution (statistical: observed hit rate ≈ predicted), statuses, victory/defeat, quest conditions, event selection, save/load serialisation, audio routing. Also verify there are no hidden grid dependencies.
Two kinds of verification per milestone: **system correctness** (tests) and **player experience** (scripted screenshots + a short audit in `docs/DECISIONS.md`).

## 21. IMPLEMENTATION ORDER

1. Godot project + folders + baseline scene — done
2. 3D player + camera — done
3. Visual rendering spike — done
4. Village + forest blockout — done
5. Exploration interaction + world memory + HUD — done (+ atmosphere/audio pass)
6. Tactical combat prototype — done as grid; **migrated to free-position world-space combat**
7. Enemy AI: three archetypes (world-space position evaluation)
8. Dialogue
9. Quest system (The Missing Ring)
10. Weird event system (WorldEventDirector + The Glowing Fish)
11. Guild upgrade
12. Save/load
13. Cinematic discovery polish (music sting)
14. Polish + playtest

## 22. SCOPE RULES
Do NOT: build the full world, character customisation, traditional class/level progression before it is proven necessary, dozens of enemies, procedural terrain, multiplayer, hundreds of items, a huge crafting system, the entire story, large amounts of final art, systems not needed for the slice, complex physics combat, elaborate animation systems.
Do: make the slice playable, keep systems extensible, use placeholders, create clean interfaces, document decisions, keep content data-driven.

## 23. DEFINITION OF DONE

A new player can:
1. Start at the guild. 2. Walk around the village. 3. Accept the missing-ring quest. 4. Leave town. 5. Explore the forest. 6. See a large distant landmark. 7. Trigger the camera reveal. 8. Encounter a weird event. 9. Enter tactical combat in the world where they stand. 10. Move freely through the environment within their movement allowance. 11. Use an Action. 12. Use a Bonus Action. 13. Use/trigger a Reaction. 14. Defeat or bypass an enemy. 15. Finish the quest. 16. Return to the guild. 17. Upgrade the common room. 18. Save the game. 19. Quit. 20. Reload and retain meaningful progress.

The game should feel like a tiny but convincing piece of the larger world — and combat should feel like "tactical combat happening inside the world", not "a board game placed on top of it".

The slice must also show that the world is enjoyable to walk through between events, distant places invite investigation, combat is a natural extension of the environment, some encounters can be avoided, environmental positioning matters without excessive UI, a strange event sparks curiosity, returning to the guild matters, and at least one unexpected moment stays memorable.

## 24. WORK STYLE
Act like a senior Godot engineer and technical game designer: explain the intended architecture briefly, identify risks, implement the smallest useful version, test it, then expand. When a design decision is ambiguous, choose the simplest option consistent with the GDD and document it. When a system is too large, reduce it to the vertical-slice requirement and leave an extension point. Never claim something is implemented without verifying: files exist, scripts parse, scenes load, the game runs, the interaction works.
