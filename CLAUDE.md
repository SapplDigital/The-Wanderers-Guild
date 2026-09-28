# The Wanderer's Guild — project notes

Cozy dark-fantasy exploration RPG with turn-based tactical combat, Godot **4.7.2** (mono build installed, but the project uses **GDScript**).
Design authority: `docs/GDD.md` (text copy of `The_Wanderers_Guild_GDD.pdf`). Decisions: `docs/DECISIONS.md`.
Milestone status: `task_plan.md`, session log: `progress.md`.

## Run / verify
- Godot: `C:\Tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe`
- Re-import after adding scripts with `class_name`: `godot --headless --path . --import`
- Scripted screenshot (debug builds, `scripts/core/main.gd`):
  `godot --path . -- --shot=<abs png path> [--world=res://...tscn] [--pos=x,y,z] [--yaw=90] [--pitch=10 (offset)] [--zoom=14] [--scale=3] [--post=0] [--walk] [--reveal] [--frames=90] [--flags=a,b] [--interact] [--then=x,y,z] [--pad] [--actions=name@frame,...] [--seed=N]` (the shot line also prints combat order and HP when a fight is running)
  Renders N frames, saves the PNG, prints player position, quits. Use it to verify visuals and flows.

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
- Camera: design landmarks against the LOOK end of the rail (pitch -8°..+10°); reveals use `CinematicReveal` (see DECISIONS).
- Main world: `scenes/world/slice_region.tscn` (village south at origin, forest north along -Z). Named anchors for later milestones: `Village/GuildDoor`, `Village/Well`, `Village/NoticeBoard`, `Forest/CombatClearing/CombatArea`, `Forest/AbandonedCamp`, `Forest/HiddenHollow`, `Forest/ResourceNodes`, `Landmarks/*`.
- Test scenes: `scenes/world/visual_spike.tscn` (M3), `scenes/world/camera_test.tscn` (camera states); run with `--world=`.
- Props that the camera must not enter need collision on their visual volume (roofs have it); tree crowns deliberately don't.
- World memory: `GameState` autoload (`set_flag/get_flag/is_set`, `flag_changed`). Key conventions in `scripts/core/game_state.gd`. Never store world facts elsewhere.
- Interaction: add an `Interactable` (Area3D + CollisionShape3D child, layer 4) to anything usable; `DiscoveryZone` for named places; `StateToggle` to make the world visibly react to a flag. HUD is reached via `get_tree().call_group("hud", "show_message"/"show_location", ...)`.
- Tests: `godot --headless --path . res://tests/<name>.tscn` (exit code 0 = pass): `test_exploration_loop`, `test_audio`, `test_combat_rules`, `test_combat_world` (real clearing scan). Tests are scenes so autoloads exist.
- Audio: never reference audio files from gameplay code. Use `AudioManager.play/play_at(&"event")`; add/replace sounds in `data/audio/sound_bank.tres`. Log external assets in `docs/ASSET-SOURCES.md`. Normalise new files (peak -1 dBFS, OGG) and set loudness in the bank.
- Combat: world-space rules in `scripts/combat/` (`combat_space`, `action_resolver`, `combat_unit`, `combat_state`), data Resources in `scripts/combat/data/` with instances in `data/`. Presentation: `CombatArea` (world scan + trigger), `CombatController` (input + event playback), `TacticalOverlay`, `scenes/ui/combat_hud.tscn`. Never put rules in the controller: add them to `CombatState` and a test. Grid combat is obsolete.
- Two kinds of verification per milestone: system correctness (headless test) and player experience (scripted screenshots + audit in DECISIONS).
- Windows Python: run with `PYTHONUTF8=1`, otherwise it writes cp1252 and can truncate files on encode errors.
- Shot runs: always wrap in `timeout`; a GDScript parse error leaves the window open forever.

## Controls (current)
WASD/arrows move, Shift run, RMB drag orbit (vertical = pitch offset), Q/E rotate, wheel zoom (in = LOOK toward horizon), F interact. Gamepad: left stick move, right stick orbit/pitch, LB/RB zoom.
Debug: F1 overlay, F2 pixel scale, F3 post shader, F4 play the world's first CinematicReveal, F5 reload world (leave + return; state must survive), F6 start the clearing fight, F7 win the current fight.
Combat: mouse or WASD cursor, 1/2/3 abilities, F/click confirm, Esc cancel, Space end turn (pad: A confirm, X/Y/D-pad up abilities, B cancel, Start end turn).
