# Vertical slice plan

Order from the master prompt §21. Definition of done: master prompt §23 / GDD 18.2.

- [x] M1 Godot project + folders + baseline scene
- [x] M2 3D player + camera (orbit, zoom, spring-arm collision, camera-relative move, cinematic override)
- [x] M3 Visual rendering spike (passed, see DECISIONS)
- [x] M3.5 Camera states NORMAL/LOOK/CINEMATIC + camera test area (passed)
- [x] M4 Village + forest blockout — `scenes/world/slice_region.tscn` (guild hall, 3 houses, well, notice board, pond; forest path; camp; combat clearing; hidden hollow; overlook + reveal; ruin, floating island, giant tree, mountains)
- [x] M5 Interaction system + exploration HUD + GameState; loop guild→village→camp→hollow→village verified; PX audit in DECISIONS
- [x] M5.5 Atmosphere pass: AudioManager + sound bank + ambience/footsteps/emitters; crown fade; pad glyph; interaction feedback
- [x] M6 world-space combat migration: continuous metre movement, terrain/obstacles/elevation, temporary tactical overlay, real clearing scan, rules tests, actual-clearing debug victory/exit, visible bypass and rendered player-turn overlay verified (2026-09-28).
- [x] M7 Enemy AI CLOSED: data-selected Brain Dispatcher (ActorData.ai_brain) with melee-beast, ranged/utility and guardian demonstration brains; authored optional encounters (boars, Glimmer Midges at the forest-edge stones, Mossbound Guardian at the Broken Gate); guardian telegraph ring + move hint; rules/world tests and rendered midge/guardian smoke runs verified (2026-09-28).
- [x] M8 Dialogue CLOSED: Resource dialogue data + validator, pure DialogueRunner (flag-only conditions, flag/event consequences), DialogueTrigger on Interactable, compact dialogue UI (keyboard/mouse/pad), Wenna the well-keeper with a visible world consequence; test_dialogue 33/33 + regression + rendered checks (2026-09-28).
- [x] M9 Quest: The Missing Ring CLOSED: declarative QuestData + pure QuestTracker over flags; Hollis, midge hoard (learn from Wenna or find it; fight or trade), return/keep outcomes with visible consequences; quest HUD line; test_quest 48/48 + regression + rendered routes (2026-09-28).
- [x] M10 WorldEventDirector CLOSED: pure seeded EventDirector over flags (region, prerequisites, ONCE/COOLDOWN, weighted event + variant, safe-moment opportunities), EventHost/EventRegion, The Glowing Fish (3 variants, investigate + release into the pond) and Night-berries (cooldown regrowth); F8 debug trigger; test_events 62/62 + regression + renders (2026-09-28).
- [~] M11 Guild upgrade: Repair the Common Room: IMPLEMENTED + VERIFIED, awaiting review (not committed). Walkable in-place guild hall with roof/upper-wall cutaway + camera-collision switch (`InteriorZone`), `common_room` quest (timber at the camp, ember from Wenna, repair at the hearth), before/after StateToggles, lodger Maren with an island rumour; StateToggle disables what it hides; test_guild 46/46 + full regression + renders (2026-09-28).
- [ ] M12 Save/load (versioned)
- [ ] M13 Cinematic discovery at the overlook
- [ ] M14 Polish + playtest

## Open risks
- Backlog: minimal inventory/item support (ItemData + carried items + compact HUD list). In slice scope (GDD 18.1 inventory-lite) but unscheduled; M9 keeps the ring and glint stone as flags.
- Combat UX backlog (playtest): "smart attack movement" (click a target out of reach → walk into range and attack). Not scheduled; not part of M8.
- Texel shimmer during fast rotation (not measurable in screenshots — check by hand).
- Distant ruin textures alias into noise at 100 m+; may need a lower-detail ruin material or mipmap bias.
- Controller: basic stick/button bindings exist, menus not yet.
- Tree crowns have no collision, so the camera can clip into them in dense forest at LOOK zoom. Fix in polish with occluder fading (dither-fade meshes between camera and player).
- Camera pull-in right after leaving the guild (and behind any roofed building): the roof really occludes the player for about 5 m; fix with roof/occluder fading (see the crown item above), not in M11.
- Guild: damaged-state detail is subtle at normal zoom; indoor LOOK sees through the cut-away far walls (dollhouse); no fire sound (bank has none; polish).
- Exploration HUD shows only the first active quest (by file name): with both quests active it shows the common room. Revisit if quests multiply.
