# Architecture

How The Wanderer's Guild is put together today (after M15.5). This describes the code as it is,
not a future design. For how-to recipes see `DEVELOPER_GUIDE.md`; for why things are the way they
are, `DECISIONS.md` (one entry per milestone).

Godot 4.7.2, GDScript, Forward+. One developer; the architecture is deliberately small.

## 1. The big picture

```
                     ┌──────────────── GameState (autoload) ────────────────┐
                     │  flags: {"quest.x.accepted": true, "event.y.variant": │
                     │          "leak", "event.director.opportunity": 3 ...} │
                     └───▲───────────────▲──────────────▲──────────▲────────┘
        writes facts     │ reads/writes  │ reads        │ reads    │ replace() on load/new game
   ┌─────────────────────┴──┐  ┌─────────┴──────┐  ┌────┴─────┐ ┌──┴───────────────┐
   │ world components        │  │ pure logic      │  │ HUD      │ │ main.gd          │
   │ Interactable, Discovery │  │ DialogueRunner  │  │ quests,  │ │ title, save/load,│
   │ Zone, CinematicReveal,  │  │ EventDirector   │  │ prompts  │ │ world swap,      │
   │ CombatArea (cleared),   │  │ QuestTracker    │  └──────────┘ │ pixel pipeline,  │
   │ StateToggle (reads)     │  │ (static/RefCnt) │               │ debug keys       │
   └─────────────────────────┘  └────────────────┘               └──────────────────┘
                     ▲ data in                         SaveGame (pure): flags + player → file
          Resources in data/  (DialogueData, QuestData, EventData, ActorData, EncounterData …)
```

- **All persistent world memory is flat string flags in `GameState`.** Quests, dialogue facts,
  discoveries, events, encounters and guild upgrades are all flags. There is no second store.
- **Content is data** (typed Resources in `data/`). **Behaviour is small scripts** (components on
  nodes, or pure `RefCounted`/static logic). **The world is composition** (scenes in `scenes/`).
- **Pure logic never touches scene nodes** (`DialogueRunner`, `QuestTracker`, `EventDirector`,
  `CombatState`/`CombatSpace`, `SaveGame`), so it is tested headlessly with a fake flag store.
- **Presentation reacts to state**: `StateToggle` shows/hides world pieces from a flag, the HUD
  reads quests from flags, combat views play back events that the rules produced.
- **No god object.** The only autoloads are `GameState` (facts) and `AudioManager` (sound). Other
  "managers" deliberately don't exist: quests have no QuestManager (flags + tracker), dialogue has
  no DialogueManager (trigger + runner + UI), events have no autoload (an `EventHost` node in the
  world). Adding an autoload needs a reason that a node in the world can't satisfy.

## 2. Systems and ownership

| System | Owner (file) | Persistent state | Temporary state | Who may change it |
|---|---|---|---|---|
| World facts | `scripts/core/game_state.gd` (autoload) | `flags` | – | Any gameplay component via `set_flag` for **its own facts** (below); `main` via `replace()` |
| Save file | `scripts/save/save_game.gd` (pure) | `user://save.cfg` | – | Only `main.save_game()` writes; `main.load_game()` reads |
| Start, world lifecycle | `scripts/core/main.gd` | – | current world node, title open | Only `main` (`_swap_world`) |
| Player | `scripts/player/player.gd` | position, `health` (saved in `[player]`) | `input_enabled`, move state | Movement: the player. `input_enabled`: whoever takes control (dialogue UI, combat controller, cinematic reveal, title). `health`: the player (regen) and combat (damage, outcome) |
| Camera | `scripts/camera/camera_controller.gd` | – (never saved) | yaw/zoom/pitch goals, cinematic pose, collision on/off | Player input; `play_cinematic`/`end_cinematic` (CinematicReveal); `target`/`set_zoom` (combat); `set_collision_enabled` (InteriorZone) |
| Dialogue | `DialogueTrigger` → `DialogueRunner` → `DialogueUI` | only through consequences (flags) | the open conversation | The runner applies consequences; the UI only presents |
| Quests | `data/quests/*.tres` + `QuestTracker` (read-only) | none of its own: quest state *is* flags | HUD's announce cache | Nobody "advances" a quest: content writes the facts its objectives test |
| World events | `EventHost` (node) → `EventDirector` (pure) | `event.*` flags | – | Only the director writes `event.*` bookkeeping; content writes `event.<id>.resolved` |
| Combat | `CombatArea` (world) → `CombatController` (presentation) → `CombatState` (rules) | `encounter.<id>.cleared` | the whole fight | Rules only in `CombatState`/`CombatSpace`; the area writes the cleared flag and applies the outcome to the player |
| Discoveries | `DiscoveryZone`, `CinematicReveal` | `discovered.<id>` | – | The component that owns the place |
| Guild rooms | quest + `guild.<room>.*` flags + `StateToggle` | flags | `InteriorZone` cutaway (derived) | Content (dialogue/interactables) |
| HUD | `scripts/ui/exploration_hud.gd` (group `hud`) | – | messages, prompt, quest cache | Others call `show_message` / `show_location` / `set_combat_mode` via the `hud` group |
| Audio | `scripts/audio/audio_manager.gd` (autoload) | bus volumes in `user://audio.cfg` | playing streams, ambience stack | Gameplay calls `AudioManager.play(&"event")`; the bank maps names to files |
| Content discovery | `scripts/core/data_index.gd` + `data/data_index.tres` | – | – | Content authors (add the file to the index) |

**Who may write which flags (convention, not enforced):**

| Prefix | Written by |
|---|---|
| `discovered.<place>` | `DiscoveryZone`, `CinematicReveal` |
| `<state_id>.used`, any `sets_flag` | `Interactable` |
| `quest.<id>.*`, `npc.<id>.*`, `world.*`, `guild.<room>.*`, `rumour.*` | dialogue consequences and `Interactable.sets_flag` (content decides) |
| `event.director.*`, `event.<id>.fired/variant/last_opportunity` | `EventDirector` only |
| `event.<id>.resolved` | content that ends the event (dialogue) |
| `encounter.<id>.cleared` | `CombatArea` only |

Conventions live in the header of `game_state.gd`. Flag values are bool/int/float/String only
(the save refuses anything else). Only boolean `true` counts as "set" (`is_set`), so string flags
like `"false"` are safe to test.

## 3. How systems talk to each other

In order of preference:

1. **Through flags.** Most communication is "A writes a fact, B reads it later". A quest never
   hears from dialogue; it reads the flags the dialogue wrote. A `StateToggle` listens to
   `GameState.flag_changed` for its one flag.
2. **Signals** for "something just happened" inside a scene: `Interactable.interacted`,
   `CombatArea.combat_finished`, `CinematicReveal.revealed`, `Player.health_changed`,
   `DialogueRunner.finished`.
3. **Scene groups** for the few cross-tree calls, so the caller needs no path:
   - `hud`: `show_message(text)`, `show_location(title)`, `set_combat_mode(on)` (the HUD API).
   - `dialogue_ui`, `combat_hud`: the single UI instance of each.
   - `event_host`: `on_region_entered(region)` (from `EventRegion`), `debug_evaluate()`.
   - `camera_rig` (`CameraController.GROUP`): lets a prop inside an instanced scene find the rig.
   - `surface_area`, `high_ground`, `high_ground_body`, `low_cover`: what `CombatArea` scans.
   - `dialogue_events`: listeners for dialogue EVENT consequences. **No node listens yet.**
4. **Direct calls on explicit exports** where one node legitimately drives another: `CombatArea`
   → `player`/`camera_rig`; `InteriorZone` → `camera_rig.set_collision_enabled`; `CinematicReveal`
   → `camera_rig.play_cinematic`.

**The safe-moment rule** is one method: `Player.is_exploring()` = the player has input and no
cinematic owns the camera. Saving, event opportunities, starting a fight, starting a reveal and
the debug keys all ask it. Fights, conversations, cinematics and the title take `input_enabled`
away while they own the player and give it back when they end.

## 4. Persistent vs temporary state

**Persistent** (in the save): `GameState.flags`, player position and health. Nothing else.

**Derived** (rebuilt from flags when a world loads, never saved): what `StateToggle`s show, the
`InteriorZone` cutaway and camera collision, the HUD's quest lines, idle enemies (skipped if the
encounter is cleared), event presentation (dialogue branches on `event.<id>.variant`), whether a
reveal is armed (`discovered.<id>`).

**Temporary** (lost on save/load by design): fights, conversations, cinematics, camera pose,
player facing, HUD messages. Saving is refused while any of them is running.

**Rule:** a new persistent fact is a new flag. If it can't be a flag (a position, per-instance data),
change the save format (below) instead of hiding a second copy of state somewhere.

## 5. Data vs logic

| Content | Data (declarative) | Logic (reusable) | Composition |
|---|---|---|---|
| Dialogue | `DialogueData`/`Node`/`Choice` + `DialogueCondition`/`DialogueConsequence` in `data/dialogue/` | `DialogueRunner` | `DialogueTrigger` on an `Interactable` |
| Quest | `QuestData`/`QuestObjective`/`QuestOutcome` in `data/quests/`, listed in `data_index.tres` | `QuestTracker` | none (facts come from other content) |
| World event | `EventData`/`EventVariant` in `data/events/`, listed in `data_index.tres` | `EventDirector`, `EventHost` | `EventRegion` areas + dialogue/toggles that read `event.*` |
| Enemy | `ActorData`, `AbilityData`, `StatusData` in `data/actors`, `data/abilities`, `data/statuses` | `CombatState` rules; AI = `CombatBrain` script named by `ActorData.ai_brain` | – |
| Encounter | `EncounterData` in `data/encounters/` | `CombatArea`, `CombatController` | a `CombatArea` node in the region |
| NPC | its `DialogueData` | – | `scenes/npcs/villager.tscn` instance, configured on the root (`Villager`) |
| Discovery | `location_id` + `title` on the node | `DiscoveryZone` / `CinematicReveal` | an Area3D in the region |
| Interactable | exports on the node (verb, message, `sets_flag`, `state_id`) | `Interactable`/`Interactor` | an Area3D + shape in a scene |
| Audio | `SoundEvent`s in `data/audio/sound_bank.tres` | `AudioManager` | `SoundEmitter`, `AmbienceZone`, `SurfaceArea` nodes |
| Region | the scene itself (`slice_region.tscn`) | `main._swap_world` | everything above |

Conditions everywhere are `DialogueCondition` (IS_SET / NOT_SET / EQUALS on flags), evaluated
through `DialogueCondition.all_pass`. Consequences are `DialogueConsequence` (SET_FLAG / EVENT),
applied through `DialogueConsequence.apply`. Dialogue, quests and events share them, so one
change (e.g. counting conditions, planned for M16) reaches all three.

## 6. Save and load

- `SaveGame` (pure, static) writes one versioned `ConfigFile`: `[save] version`, `[player]
  position, health`, `[state] flags` (keys sorted, so the same facts give the same bytes). It
  writes to `<path>.tmp` and renames, so a crash never leaves half a save. `read` validates and
  migrates (`SaveGame.migrations`, one step per version); newer or broken saves are refused and
  change nothing.
- Why ConfigFile and not JSON: JSON turns ints into floats and `EventDirector` needs ints.
- `main.save_game()` (F9, window close) saves only in the main world at a safe moment.
- `main.load_game()`: `GameState.replace(flags)` (no `flag_changed` storm), then `_swap_world` with
  the player's position and health set **before** the world enters the tree. Order matters: the
  first physics step then happens at the saved spot, so no trigger, region entry or discovery at
  the default spawn fires, and interiors detect the player immediately. The HUD binds before
  `add_child` so its quest cache matches the loaded flags and nothing is announced.
- The title screen reads the save to decide whether Continue exists; it never writes. New Game =
  `GameState.replace({})` + a fresh world; the old save is replaced at the next save.

## 7. World lifecycle

- `scenes/main.tscn` is the root: a `SubViewportContainer` pixel pipeline (640×360, shrink 3, post
  shader) with the world, the exploration HUD, combat HUD, dialogue UI and title menu inside the
  low-res viewport, plus a native-resolution debug label.
- There is **one world scene**, `scenes/world/slice_region.tscn` (`main.MAIN_WORLD`). A "world swap"
  (`_swap_world`) frees the world node and instantiates a scene in its place; F5, load and New
  Game all use it. Everything the world remembers must come back from flags.
- Region transitions don't exist yet (planned: `RegionData` + exits, save v2 with `[player]
  region`; see `POST_M14_PRODUCTION_PLAN.md` M22). Sub-areas inside a world are `EventRegion`s
  (for events) and `AmbienceZone`s (for sound).
- The guild interior is part of the world (no scene swap): `InteriorZone` hides the roof/upper
  walls and switches the camera arm's collision off while the player is inside, or on the doorstep
  while the building blocks the camera's view.

## 8. Combat

```
CombatArea (in the world) ── start() ──► CombatController (Node, presentation)
   scans collision/terrain/                  input, overlay, camera, animation,
   elevation → CombatSpace                    HUD; plays back rule events
   owns: idle enemies, outcome,                      │ commands        ▲ events (Dictionaries)
   cleared flag, player health after                 ▼                  │
                                             CombatState (pure rules) + CombatSpace (geometry)
                                             ActionResolver (d20), BrainDispatcher → CombatBrain
```

- Rules (movement, reach, line of sight, cover, terrain, elevation, reactions, statuses, d20) live
  only in `CombatState`/`CombatSpace`/`ActionResolver` and return event dictionaries. The
  controller never decides an outcome; it animates what the rules said. New rule = `CombatState`
  + a case in `test_combat_rules`.
- AI: `ActorData.ai_brain` names a `CombatBrain` script; `BrainDispatcher` runs it and passes its
  *intent* to `CombatState`, which validates it like a player command.
- Health: `Player.health` is the one HP value outside a fight. `CombatArea.start` copies it into
  the player's `CombatUnit`; the controller mirrors hits back so the HUD pips move; the area
  applies the outcome (at least 1 HP after a win; a third of max after a defeat, woken outside).
- A fight is never saved. Victory writes `encounter.<id>.cleared`.

## 9. Dialogue

`Interactable.interacted` → `DialogueTrigger` creates a `DialogueRunner(dialogue, GameState)` →
`DialogueUI.open(runner, player)` (takes player input) → the UI shows `runner.node` and
`runner.choices()` and calls `choose`/`advance`/`leave` → the runner applies consequences →
`finished` closes the UI and gives input back. Entries pick the opening line (first entry whose
conditions pass). Leaving mid-conversation applies nothing. `DialogueData.validate()` (run by
`test_dialogue` on every file) rejects broken links, duplicates, unreachable nodes and lines
whose replies are all conditional.

## 10. Quests

A quest is a description over facts: `accepted_when`, objectives with `done_when`, outcomes with
`conditions`. `QuestTracker` answers "accepted? active? current objective? outcome?" from flags;
the current objective is the first whose facts aren't all true. "Objectives are facts, not steps":
every route to a fact writes the same flag. The HUD lists active quests and announces changes.
Quests are found through `DataIndex`.

## 11. World events

`EventRegion` (Area3D) → `EventHost.on_region_entered` → if the region changed and
`Player.is_exploring()` → `EventDirector.evaluate(events, GameState, region)`, which counts an
"opportunity", respects ONCE/COOLDOWN/gap, picks an event and a variant with an RNG seeded from
`[seed, opportunity, id]` (no RNG state to save), and writes the start flags. The event then plays
out through existing content: dialogue that branches on `event.<id>.variant`, interactables,
`StateToggle`s. The director never runs dialogue or starts fights.

## 12. Camera

`CameraController` (`scenes/player/camera_rig.tscn`): orbit + one zoom "rail" from the elevated
NORMAL view to the low LOOK view, a spring arm for collision, and a top-level `Camera3D` that
blends between the rig anchor and any cinematic pose. Cinematics (`CinematicReveal`) call
`play_cinematic(pose)` / `end_cinematic()`; `is_cinematic` is true while one owns the camera,
`state == CINEMATIC` stays true through the blend back. Combat retargets the rig to a focus node.
Nothing about the camera is saved.

## 13. UI

All game UI lives inside the 640×360 pixel viewport (pixel-consistent, scaled with the world).
UI never contains rules: the dialogue panel presents a runner, the combat HUD reads the controller,
the exploration HUD reads flags/quests and the player's focus, the title menu emits a choice and
`main` acts on it. Input prompts read `InputGlyphs.label(action)` (keyboard or pad, whichever was
used last). Menus use the same keys: up/down, `interact` confirm, `dialogue_leave` back.

## 14. Export considerations (learned in M15)

- **No runtime folder scans of `res://`.** Exported resources are packed/remapped (`*.tres.remap`),
  so listings find nothing. Content that is discovered by id is listed in `data/data_index.tres`.
- **Don't set properties on children of instanced scenes from an outer scene** (a node header
  with neither `type=` nor `instance=`). The exported build dropped exactly those (the guild's
  camera link, every villager's conversation) while the editor kept them. Configure the instance
  root instead (see `Villager`), or resolve links inside the instanced scene / via a group.
  `test_data_index` fails on such overrides.
- **Test in the exported pack**, not only the editor: the smoke preset includes the tests;
  `godot --headless --main-pack export/smoke/WanderersGuild_smoke.exe res://tests/<name>.tscn`.
- Exported builds share `user://` with editor runs.
- Debug-only code checks `OS.is_debug_build()` (debug keys, the `--shot` harness, `--save-file`).

## 15. Modding boundary

Nothing loads external content today. The boundary the architecture is moving toward: content =
Resources + scenes addressed by id, systems = code that never needs to change for new content.
Details and the current status per content type: `MODDING.md`.

## 16. Rules for adding content

1. New persistent fact → a flag with a documented prefix. Never a variable that must be saved.
2. New content found by id (quest, event) → add it to `data/data_index.tres`.
3. New rule → the pure rules class + a headless test; never in a controller or UI.
4. New visual reaction to a fact → `StateToggle` on that flag, not code.
5. Configure instanced scenes on their root; don't override their children from outside.
6. Every data type with a `validate()` must pass it in a test.
7. After changes that reach the exported game, run the suites against the exported pack.

Recipes: `DEVELOPER_GUIDE.md`.
