# The Wanderer's Guild — project notes

Cozy dark-fantasy exploration RPG with turn-based tactical combat, Godot **4.7.2** (mono build installed, but the project uses **GDScript**).
Design authority: `docs/GDD.md` (text copy of `The_Wanderers_Guild_GDD.pdf`). Decisions: `docs/DECISIONS.md`.
Milestone status: `task_plan.md`, session log: `progress.md`.

## Run / verify
- Godot: `C:\Tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe`
- Re-import after adding scripts with `class_name`: `godot --headless --path . --import`
- Scripted screenshot (debug builds, `scripts/core/main.gd`):
  `godot --path . -- --shot=<abs png path> [--world=res://...tscn] [--pos=x,y,z] [--yaw=90] [--pitch=10 (offset)] [--zoom=14] [--scale=3] [--post=0] [--walk] [--reveal] [--frames=90] [--flags=a,b] [--interact] [--then=x,y,z] [--pad] [--actions=name@frame,...] [--seed=N] [--save-file=<abs cfg>] [--load]` (the shot line also prints combat order and HP when a fight is running)
  Renders N frames, saves the PNG, prints player position, quits. Use it to verify visuals and flows.
  Shot and `--world` runs never continue from the developer save; save/load pairs = two processes: `--save-file=X --actions=quicksave@60`, then `--save-file=X --load`. The first shot frame is always black (harness), frame 2 is the first real image.

## Layout
- `scenes/` main.tscn (pixel pipeline root), `player/`, `world/` (+ `props/`), later `combat/`, `npcs/`, `ui/`
- `scripts/` by system: `core/`, `player/`, `camera/`, later `combat/`, `world/`, `quests/`, `dialogue/`, `events/`, `inventory/`, `save/`
- `data/` Resource definitions (ActorData, AbilityData, ItemData, QuestData, EventData, EncounterData). Static data only; runtime state lives elsewhere.
- `art/materials/` shared materials, `shaders/`, `tests/` (headless logic tests), `tools/`
- Folders get created when first used, not up front.

## Conventions
- Composition + small scripts; signals between systems; no god-object GameManager.
- Pure game logic (world-space movement/pathfinding, d20, action economy, quest conditions, event selection, save) must not depend on scene nodes, so it can be tested headless.
- Physics layers: 1 = world (camera spring arm collides), 2 = actors.
- Hand-written `.tscn`: Node-typed exports assigned by path NEED `node_paths=PackedStringArray("prop")` in the node header, otherwise they silently stay null.
- Materials: 64px NoiseTexture2D + constant-interpolation Gradient (hard palette steps), world triplanar, `uv1_scale 0.5` (= 32 texels/m). Keep texel density consistent.
- Debug-only features check `OS.is_debug_build()`.
- Camera: design landmarks against the LOOK end of the rail (pitch -8°..+10°); reveals use `CinematicReveal` (see DECISIONS): child `Marker3D`s are the glide path (one eased curve), `focus` + `focus_offset` is the aim (frame the landmark AND the next reachable goal; check the return frame at FOV 40 / pitch +10°), `location_id`/`title` make it that place's one-time discovery (`discovered.<id>`, written when control returns). Don't also put a `DiscoveryZone` on the same place.
- Main world: `scenes/world/slice_region.tscn` (village south at origin, forest north along -Z). Named anchors for later milestones: `Village/GuildDoor`, `Village/Well`, `Village/NoticeBoard`, `Forest/CombatClearing/CombatArea`, `Forest/AbandonedCamp`, `Forest/HiddenHollow`, `Forest/ResourceNodes`, `Landmarks/*`.
- Test scenes: `scenes/world/visual_spike.tscn` (M3), `scenes/world/camera_test.tscn` (camera states); run with `--world=`.
- Props that the camera must not enter need collision on their visual volume (roofs have it); tree crowns deliberately don't.
- World memory: `GameState` autoload (`set_flag/get_flag/is_set`, `flag_changed`). Key conventions in `scripts/core/game_state.gd`. Never store world facts elsewhere.
- Interaction: add an `Interactable` (Area3D + CollisionShape3D child, layer 4) to anything usable; `DiscoveryZone` for named places; `StateToggle` to make the world visibly react to a flag (hidden pieces are also disabled: no collision, no interaction). HUD is reached via `get_tree().call_group("hud", "show_message"/"show_location", ...)`.
- Tests: `godot --headless --path . res://tests/<name>.tscn` (exit code 0 = pass): `test_exploration_loop`, `test_audio`, `test_combat_rules`, `test_combat_world` (real clearing scan), `test_dialogue`, `test_quest`, `test_events`, `test_guild`, `test_save`, `test_reveal`. Tests are scenes so autoloads exist.
- Audio: never reference audio files from gameplay code. Use `AudioManager.play/play_at(&"event")`; add/replace sounds in `data/audio/sound_bank.tres`. Log external assets in `docs/ASSET-SOURCES.md`. Normalise new files (peak -1 dBFS, OGG) and set loudness in the bank.
- Combat: world-space rules in `scripts/combat/` (`combat_space`, `action_resolver`, `combat_unit`, `combat_state`), data Resources in `scripts/combat/data/` with instances in `data/`. Presentation: `CombatArea` (world scan + trigger), `CombatController` (input + event playback), `TacticalOverlay`, `scenes/ui/combat_hud.tscn`. Never put rules in the controller: add them to `CombatState` and a test. Grid combat is obsolete.
- Dialogue: data in `data/dialogue/*.tres` (`DialogueData` → `DialogueNode` → `DialogueChoice` + `DialogueCondition`/`DialogueConsequence`, classes in `scripts/dialogue/data/`). Conditions/consequences are GameState flags only; `EVENT` consequences reach `on_dialogue_event(id)` on the `dialogue_events` group. Logic in `DialogueRunner` (pure); `DialogueTrigger` starts it from an `Interactable`; `DialogueUI` (in main.tscn) only presents. Every file must pass `DialogueData.validate()` (checked by `test_dialogue`).
- Quests: `data/quests/*.tres` (`QuestData` → `QuestObjective`/`QuestOutcome`, classes in `scripts/quests/data/`, conditions are `DialogueCondition`). State is GameState flags only (`quest.<id>.*`); `QuestTracker` is pure and read-only. Objectives are facts, not steps: every route to a fact writes the same flag. The exploration HUD shows the active quest. NPCs are `scenes/npcs/villager.tscn` instances with the conversation set on their `Dialogue` child.
- World events: `data/events/*.tres` (`EventData`/`EventVariant`, classes in `scripts/events/data/`). `EventDirector` is pure and only decides whether, which event and which variant, and writes start flags; events play out through dialogue (EQUALS on `event.<id>.variant`), `Interactable`s and `StateToggle`s. `EventHost` in the region creates an evaluation opportunity when the player enters a different `EventRegion` at a safe moment; an opportunity is not game time. State is `event.*` flags only.
- Guild: `scenes/world/props/guild_hall.tscn` is a walkable in-place interior (no scene swap). `InteriorZone` hides the `Cutaway` node (roof, upper walls, windows) and turns the camera spring arm's collision off while the player is inside; wall collision stays on the body. Upgrades are quests (`data/quests/common_room.tres`) + `guild.<room>.*` flags + StateToggles; no upgrade framework.
- Save/load: `SaveGame` (`scripts/save/save_game.gd`, pure) writes one versioned ConfigFile slot (`user://save.cfg`): `GameState.flags` (sorted, types kept), player position and health. Nothing else: all other state must rebuild from flags. Never add a second copy of world state to the save; new persistent facts are flags. Flag values must be bool/int/float/String. `main.gd` saves (F9 / window close) only in the main world at a safe moment, loads by replacing the flags wholesale and rebuilding the world via `_swap_world` with the player placed before `add_child`. Format changes: bump `SaveGame.VERSION` and add a step to `SaveGame.migrations`.
- Two kinds of verification per milestone: system correctness (headless test) and player experience (scripted screenshots + audit in DECISIONS).
- Windows Python: run with `PYTHONUTF8=1`, otherwise it writes cp1252 and can truncate files on encode errors.
- Shot runs: always wrap in `timeout`; a GDScript parse error leaves the window open forever.

## Controls (current)
WASD/arrows move, Shift run, RMB drag orbit (vertical = pitch offset), Q/E rotate, wheel zoom (in = LOOK toward horizon), F interact. Gamepad: left stick move, right stick orbit/pitch, LB/RB zoom.
Debug: F1 overlay, F2 pixel scale, F3 post shader, F4 replay the world's first CinematicReveal (writes nothing, works after the discovery), F5 reload world (leave + return; state must survive), F6 start the nearest fight (F5/F6 do nothing during a cinematic), F7 win the current fight, F8 evaluate world events here (ignores the gap, not the conditions), F10 load the save.
Save: F9 quicksave (all builds); autosave when the window closes at a safe moment; the game continues from the save on launch (`--fresh` skips that; `--save-file=<abs>` changes the path in debug builds).
Dialogue: W/S or arrows/stick/D-pad select, F/A confirm, Esc/B leave, mouse hover+click.
Combat: mouse or WASD cursor, 1/2/3 abilities, F/click confirm, Esc cancel, Space end turn (pad: A confirm, X/Y/D-pad up abilities, B cancel, Start end turn).
