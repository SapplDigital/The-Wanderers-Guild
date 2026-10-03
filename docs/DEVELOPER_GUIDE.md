# Developer guide

Practical recipes. Read `ARCHITECTURE.md` once first (15 minutes); this page assumes it.
Run commands with the console editor binary:
`C:\Tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe` (below: `godot`).

**Ground rules for every recipe**

- Persistent facts are `GameState` flags (`prefix.id.fact`). Nothing else is saved.
- Content is a Resource in `data/` or an instance in a scene. Core scripts shouldn't need edits
  for new content; if a recipe below makes you edit a core script, that's a design smell, so say so.
- Hand-written `.tscn`: Node-typed exports need `node_paths=PackedStringArray("prop")` in the node
  header, and never set properties on a *child* of an instanced scene from outside (export drops
  them; `test_data_index` fails). Configure the instance root.
- After adding a script with `class_name`: `godot --headless --path . --import`.
- Finish with the tests: `godot --headless --path . res://tests/<name>.tscn` (exit 0 = pass).

## Where is what

| Folder | Holds |
|---|---|
| `scripts/core/` | `main.gd` (root: start flow, save/load, world swap, debug keys, shot harness), `game_state.gd` (autoload), `data_index.gd`, `perf_probe.gd` (debug) |
| `scripts/player/`, `scripts/camera/` | player, footsteps; camera rig, cinematic reveal |
| `scripts/interaction/` | `Interactable` (anything usable), `Interactor` (on the player) |
| `scripts/world/` | world components: `DiscoveryZone`, `StateToggle`, `InteriorZone`, `SurfaceArea`, `HighGround`, collision helpers |
| `scripts/dialogue/`, `scripts/quests/`, `scripts/events/` | runner/trigger, tracker, director/host/region; `data/` subfolders hold their Resource classes |
| `scripts/combat/` | rules (`combat_state`, `combat_space`, `action_resolver`, `combat_unit`), world glue (`combat_area`), presentation (`combat_controller`, `tactical_overlay`, `unit_view`), `ai/` brains, `data/` Resource classes |
| `scripts/npcs/`, `scripts/ui/`, `scripts/audio/`, `scripts/save/` | villager, HUDs/menus/glyphs, audio, save format |
| `data/` | content Resources (`.tres`); `data/data_index.tres` lists quests and events |
| `scenes/` | `main.tscn`, `world/` (regions + `props/`), `npcs/`, `player/`, `combat/`, `ui/` |
| `tests/` | headless test scenes (`test_*.tscn` + `.gd`) |
| `tools/` | `package_playtest.ps1` (tester zip) |

**Infrastructure: change only on purpose, with tests:** `main.gd`, `game_state.gd`,
`save_game.gd`, `data_index.gd`, `dialogue_runner.gd`, `quest_tracker.gd`, `event_director.gd`,
`combat_state.gd`/`combat_space.gd`/`action_resolver.gd`, `camera_controller.gd`,
`dialogue_condition.gd`/`dialogue_consequence.gd` (shared by dialogue, quests and events).

## How do I add an NPC?

1. Write the conversation (next recipe).
2. In the region scene, instance `scenes/npcs/villager.tscn` where the NPC stands.
3. On the **instance root** set `dialogue` (the `.tres`), optionally `body_material` and
   `show_bucket`. Don't edit the instance's `Dialogue`/`Visual` children from the region.
4. If the NPC appears only after something happens, put the instance under a `StateToggle` whose
   `flag` is that fact (hidden = can't be talked to or bumped into).
5. Flags for what the NPC remembers: `npc.<id>.<fact>` (e.g. `npc.lodger.met`).

## How do I add dialogue?

1. New `DialogueData` resource in `data/dialogue/<id>.tres` (in the inspector, or by hand following
   `well_keeper.tres`): `id`, `entries` (openings, first passing one wins), `nodes`.
2. A `DialogueNode` has `id`, `speaker`, `text`, `choices` and `next` (used when there are no
   visible choices). A `DialogueChoice` has `text`, `conditions`, `consequences` and `next` (empty
   = end the conversation).
3. Conditions: `DialogueCondition` IS_SET / NOT_SET / EQUALS on a flag. Consequences:
   `DialogueConsequence` SET_FLAG (empty value = `true`) or EVENT. Note: nothing listens to EVENT yet
   (group `dialogue_events`), so use SET_FLAG for anything the world must remember.
4. Hook it up: an NPC (above) or any object: `Interactable` + a `DialogueTrigger` child
   (`dialogue`, `interactable` = the parent; see `HearthUse` in `guild_hall.tscn`). Speaker-less
   conversations work for objects.
5. `test_dialogue` validates every file in `data/dialogue/`; run it.

## How do I add a quest?

1. `data/quests/<id>.tres` (`QuestData`): `id`, `title`, `accepted_when` (conditions), `objectives`
   (`text` + `done_when`), `outcomes` (`id`, `text`, `conditions`). Model objectives as facts:
   `quest.<id>.has_timber`, not "step 2".
2. Make content write those facts: dialogue consequences, `Interactable.sets_flag`, a combat
   victory (`encounter.<id>.cleared`). Several routes to a fact write the same flag.
3. **Add it to `data/data_index.tres`** (`quests` array). `test_data_index` fails otherwise.
4. The HUD shows it automatically when accepted. Add a route test to `test_quest` (see the Missing
   Ring tests).

## How do I add a rumour?

Today a rumour is a fact: a dialogue reply writes `rumour.<id>` (SET_FLAG) and another piece of
content (an NPC line, a notice, a `StateToggle`) reads it. There is no journal yet (planned M21).
Don't use an EVENT consequence for it: nothing listens (see `rumour.old_wood_lights`).

## How do I add a world event?

1. `data/events/<id>.tres` (`EventData`): `region` (an `EventRegion` id), `weight`, `conditions`,
   `repeat` ONCE or COOLDOWN (+ `cooldown` in opportunities), `start` (SET_FLAG consequences),
   `announcement`, optional `variants` (`EventVariant`: `id`, `weight`, `conditions`, `start`).
2. Make the world react: `StateToggle`s on the start flags; dialogue entries with EQUALS on
   `event.<id>.variant`; an interactable that ends it writes `event.<id>.resolved`.
3. **Add it to `data/data_index.tres`** (`events`), keeping the list sorted by id (the director's
   pick order depends on it; the test checks).
4. Test with fixed seeds in `test_events` (see Glowing Fish). In a debug run, F8 evaluates events
   where you stand.

## How do I add an enemy?

1. `data/actors/<id>.tres` (`ActorData`): stats, `abilities` (`data/abilities/*.tres`,
   `AbilityData`), optional `reaction_ability`, `ai_profile` (a label), `ai_brain` (a
   `CombatBrain` script, below), `tint`/`view_scale` for the placeholder body.
2. Use it in an encounter: `data/encounters/<id>.tres` (`EncounterData`): `enemies`, one
   `enemy_offsets` entry per enemy (metres from the area centre), messages.
3. Place a fight: add a `CombatArea` node (copy one in `slice_region.tscn`) with `encounter`,
   `player_data` (`data/actors/wanderer.tres`), `camera_rig`, `player`, a `Trigger` Area3D child.
   Enemies graze there until the player walks into the trigger.
4. `test_combat_world` validates every encounter a `CombatArea` in the region uses.

## How do I add a combat brain?

1. New script in `scripts/combat/ai/` extending `CombatBrain`; implement
   `choose_turn(state, unit) -> Array` of intent dictionaries (see `melee_beast_brain.gd`). Read
   the `CombatState` API (`foes_of`, `plan_move`, `targets_for`, `predict`); don't change units
   yourself: `CombatState` validates and applies every intent.
2. Set it as `ai_brain` on the actor. `BrainDispatcher` needs no change.
3. Test the choice in `test_combat_rules` with a fixed seed.

## How do I add a discovery?

- A named place: an Area3D with `DiscoveryZone` (`location_id`, `title`) + a CollisionShape3D.
  First entry writes `discovered.<location_id>` and shows the name card.
- A place revealed by the camera: a `CinematicReveal` instead (don't use both on one place); see
  the camera rules in `CLAUDE.md` and `OverlookReveal` in `slice_region.tscn`.
- Make it findable without markers (a light, a trail, a sightline) and add the anchor to
  `test_exploration_loop` if it matters for the loop.

## How do I add a new interactable?

An Area3D with `scripts/interaction/interactable.gd` and a CollisionShape3D child (the reach).
Set `verb`, `message`/`message_repeat`, `state_id` (remembers use as `<state_id>.used`), `once`,
`sets_flag`, `condition_flag`/`condition_message`, `sound`. For more than a message, add a
`DialogueTrigger` child or connect to `interacted`. Layer 4 is set by the script.

## How do I add a new region?

Not supported yet: there is one world (`main.MAIN_WORLD`) and saving is only allowed there.
The plan (M22) is `RegionData` + region exits + save v2 with the region in `[player]`. Until then,
new areas go into `scenes/world/slice_region.tscn`, inside the `Edge` wall loop
(`test_exploration_loop` checks the anchors). Test scenes can be run with `--world=`.

## How do I add audio?

1. Normalise the file (peak -1 dBFS, OGG) into `audio/`, log it in `docs/ASSET-SOURCES.md`.
2. Add or edit a `SoundEvent` in `data/audio/sound_bank.tres` (event name → streams, bus, volume,
   pitch variance, loop, 3D range).
3. Play it by name: `AudioManager.play(&"name")` / `play_at(&"name", node)`, or place a
   `SoundEmitter` (looping world sound) / `AmbienceZone` (beds). Never reference files from code.
4. `test_audio` checks that every event used in the region exists in the bank.

## How do I change HUD behaviour?

`scripts/ui/exploration_hud.gd` + `scenes/ui/exploration_hud.tscn`. Other code talks to it only
through the `hud` group: `show_message`, `show_location`, `set_combat_mode`. The HUD may read
flags, quests and the player's focus; it must not change game state. Combat UI:
`scripts/ui/combat_hud.gd`; dialogue: `dialogue_ui.gd`; start screen: `title_menu.gd`.

## How do I change persistent state?

- **A new fact:** just write a new flag with a documented prefix (add the prefix to the header of
  `game_state.gd` if it's new). Values must be bool/int/float/String. No save change needed.
- **Something that isn't a world fact** (e.g. which region the player stands in): change the save
  format in `scripts/save/save_game.gd`: bump `VERSION`, add a step to `migrations` that upgrades
  the old dictionary, and extend `test_save`. Load order in `main.load_game` matters (see
  `ARCHITECTURE.md` §6).
- **Renaming a flag** once saves exist also needs a migration step.

## How do I add a test?

1. `tests/test_<name>.gd` extending `Node` with `_ready()` running checks and
   `get_tree().quit(1 if _failures else 0)`, plus a `.tscn` whose root has that script (copy
   `test_data_index`). Tests are scenes so autoloads exist.
2. Prefer pure logic with a fake flag store (see `test_events`'s `Flags` class); load the real
   region only for integration checks (`test_guild`, `test_combat_world`).
3. Add it to the test list in `CLAUDE.md` and `docs/PLAYTEST.md`.
4. For anything that ships, also run it against the exported pack (see `CLAUDE.md`, Export).

## Debugging aids (debug builds only)

F1 overlay, F4 replay reveal, F5 reload world, F6/F7 start/win nearest fight, F8 evaluate events,
F10 load. Scripted screenshots and measurements: the `--shot` harness in `main.gd`
(`--pos`, `--yaw`, `--flags`, `--actions`, `--perf`, `--stress`, `--title`, ...).
