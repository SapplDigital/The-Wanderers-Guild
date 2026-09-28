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
- [ ] M9 Quest: The Missing Ring (2+ outcomes)
- [ ] M10 WorldEventDirector + Glowing Fish (variants)
- [ ] M11 Guild upgrade: Repair the Common Room
- [ ] M12 Save/load (versioned)
- [ ] M13 Cinematic discovery at the overlook
- [ ] M14 Polish + playtest

## Open risks
- Combat UX backlog (playtest): "smart attack movement" (click a target out of reach → walk into range and attack). Not scheduled; not part of M8.
- Texel shimmer during fast rotation (not measurable in screenshots — check by hand).
- Distant ruin textures alias into noise at 100 m+; may need a lower-detail ruin material or mipmap bias.
- Controller: basic stick/button bindings exist, menus not yet.
- Tree crowns have no collision, so the camera can clip into them in dense forest at LOOK zoom. Fix in polish with occluder fading (dither-fade meshes between camera and player).
- Guild hall is a scaled house; interior comes with M11.
