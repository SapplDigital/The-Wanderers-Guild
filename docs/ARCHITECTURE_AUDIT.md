# Architecture audit (M15.5, 2026-10-03)

Baseline: M15 (`0d6994a`). Scope: every script in `scripts/`, the scenes that wire them, the data
classes, the tests and the export setup. Code was read, not inferred from names. The resulting
description of the architecture is `ARCHITECTURE.md`; this page records what was found and what
was done about it.

Classification: **P0** correctness/architecture hazard · **P1** significant maintainability or
extensibility problem · **P2** useful cleanup · **P3** preference. Only P0, P1 and very small P2
items were changed.

## 1. Current architecture (summary)

A flag store (`GameState`) is the single source of world truth. Content is typed Resources. Pure
logic classes interpret content against flags (`DialogueRunner`, `QuestTracker`, `EventDirector`,
`CombatState`, `SaveGame`). Small components in the world write their own facts (`Interactable`,
`DiscoveryZone`, `CinematicReveal`, `CombatArea`), and presentation reacts (`StateToggle`, HUD,
combat views). `main.gd` owns the start flow, the one world and save/load. Two autoloads:
`GameState`, `AudioManager`. Full map: `ARCHITECTURE.md` §1–2.

## 2. Dependency map

```
main ──► SaveGame, GameState, TitleMenu, ExplorationHUD, world scene (swap)
world scene:
  Player ◄── Interactor ──► Interactable ──► GameState, HUD(group), AudioManager
                                  └──► DialogueTrigger ──► DialogueRunner ──► GameState
                                                       └──► DialogueUI(group) ──► Player.input_enabled
  CameraController ◄── InteriorZone (group lookup), CinematicReveal, CombatController
  EventRegion ──► EventHost(group) ──► EventDirector ──► GameState ; EventHost ──► DataIndex
  CombatArea ──► CombatController ──► CombatState ──► CombatSpace, ActionResolver
            │                      └──► BrainDispatcher ──► CombatBrain (data-chosen script)
            └──► GameState (cleared), Player.health, HUD(group)
  DiscoveryZone, CinematicReveal ──► GameState, HUD(group), AudioManager
  StateToggle ◄── GameState.flag_changed
ExplorationHUD ──► GameState, QuestTracker, DataIndex, Player (focus, health)
Data: DialogueCondition / DialogueConsequence are shared by dialogue, quests and events.
```

No circular script dependencies were found. Cross-tree calls go through groups (`hud`,
`dialogue_ui`, `combat_hud`, `event_host`, `camera_rig`); everything else is an explicit export.

## 3. P0 findings

**None open.** The P0 class found in M15 (properties set on children of instanced scenes were
dropped in the exported build: mute NPCs, guild camera colliding) was fixed there and is guarded
by `test_data_index`. M15.5 re-audited for other editor-vs-export hazards:

| Pattern | Where | Verdict |
|---|---|---|
| Runtime `DirAccess` scans of `res://` | game code | None left (M15 `DataIndex`); guarded by `test_data_index` |
| `load()` by path string | `main.MAIN_WORLD`, `DataIndex.PATH` | Safe: remapped paths resolve (release smoke) |
| `scene_file_path` comparisons | `main.save_game`, combat obstacle labels | Safe: returns the original path in exports (release save works) |
| `FileAccess` on `res://` source | tests only | Fine for game code; the source-text check skips itself in the pack |
| Scripts referenced from data (`ActorData.ai_brain`) | combat | Safe: `test_combat_world` passes in the pack |
| Groups declared in `.tscn` (`camera_rig`) | camera rig | Safe: verified in the exported build (M15) |
| Overrides on instanced children | scenes | None left; guarded by test |

## 4. P1 findings

| # | Finding | Why it matters | Status |
|---|---|---|---|
| P1-1 | **The "safe moment" rule was written four times with two meanings.** `main.save_game` and `EventHost.is_safe` used `camera.state == CINEMATIC` (true through the 1.4 s blend back); `main._exploring`, `CombatArea.can_start` and `CinematicReveal.play` used `is_cinematic` (false as soon as control returns). | Saving, events, fights, reveals and debug keys disagreed about the same moment, and region exits / resting (M20/M22) would have added more copies. | **Fixed:** `Player.is_exploring()` is the only definition, used by all five. |
| P1-2 | **Consequence application and condition-list evaluation were duplicated.** SET_FLAG's "empty value = true" rule lived in `DialogueRunner` and `EventDirector`; the "all conditions pass" loop in `DialogueRunner`, `QuestTracker` and `EventDirector`. | M16 adds counting conditions and an ADD consequence to exactly these; copies would drift. | **Fixed:** `DialogueConsequence.apply(flags)` and `DialogueCondition.all_pass(list, flags)`. |
| P1-3 | **Encounter and actor data had no validation.** `CombatArea` indexes `enemy_offsets` per enemy; a shorter list crashes the fight at runtime. Every other content type had a `validate()`. | Content errors should fail in a test, not in a playtest. | **Fixed:** `EncounterData.validate()`, `ActorData.validate()`; `test_combat_world` validates every encounter and player actor a `CombatArea` in the region uses. |
| P1-4 | **Dialogue EVENT consequences have no listener.** `DialogueTrigger` broadcasts to the `dialogue_events` group; no node is in it. Wenna's `rumour.old_wood_lights` is an EVENT, so it leaves no trace. | Dead content that looks like it works; a trap for authors. | **Documented, not changed.** M21 (rumours/journal) decides whether the channel gets a listener or the rumour becomes a flag. The developer guide says to use SET_FLAG for anything that must be remembered. Changing the content now would change what the slice records. |
| P1-5 | **One hard-coded world.** `main.MAIN_WORLD` is the only world that may save. | Every later region depends on lifting this. | **Deferred to M22** (region frame + save v2), as planned. |

## 5. P2 / P3 findings

**Fixed (small, high confidence)**

| # | Finding | Change |
|---|---|---|
| P2-1 | `main.gd` replaced `GameState.flags` directly in two places, deliberately bypassing `flag_changed`. | `GameState.replace(flags)` names the operation and documents why it emits nothing. |
| P2-2 | The `--shot` developer harness (can set flags and quit) ran in release builds whenever someone passed `-- --shot=...`. | Gated by `OS.is_debug_build()`, like the other debug features. |
| P2-3 | The title-launch condition was one joined 150-character line. | `_normal_launch(args)`. |

**Deferred (documented)**

| # | Finding | Why not now |
|---|---|---|
| P2-4 | `main.gd` (~300 lines) does five jobs: pixel pipeline, start flow, save/load, debug keys, and a ~110-line shot harness. | Sections are clear and the harness is dev-only. Extract it to `scripts/debug/` when it next grows. |
| P2-5 | The HUD API (`show_message`, `show_location`, `set_combat_mode`) is called by string through the `hud` group from seven places. | Works, explicit enough, documented in `ARCHITECTURE.md` §3. Constants would add ceremony. |
| P2-6 | `CombatController` reaches into `CombatArea` (`player`, `camera_rig`, `encounter`, `view_for`) and sets `Player.input_enabled` / `camera_rig.target`. | Intentional coupling: the controller *is* the area's fight presentation and takes over player and camera for its duration. Documented. |
| P2-7 | Player HP is written in three places (combat start copy, controller mirror on hits, area outcome). | All go through the `Player.health` setter (clamped, emits the signal); ownership is documented. Revisit when party combat moves HP to flags. |
| P2-8 | The `"discovered."` prefix is built in both `DiscoveryZone` and `CinematicReveal`. | Two short lines; a shared constant would be a new file for one string. |
| P2-9 | Data-validation loops in `test_dialogue` / `test_quest` / `test_events` scan folders, so they pass vacuously when run against the exported pack. | They run fully in the editor, which is where content is authored; the pack run covers the in-game routes. |
| P2-10 | `ExplorationHUD` reads `Player/Interactor.focus` by node path. | Presentation reading state; stable path inside the player scene. |
| P3 | Group names as string literals; `ai_profile` (label) next to `ai_brain` (behaviour); the cosmetic random rotation of idle enemies. | Preferences, not problems. |

**Healthy, left alone on purpose:** the flag store as the single source of truth; the pure logic
layer and its headless tests; the save format (versioned, atomic, migrations); `StateToggle` as the
only "world reacts to a fact" mechanism; quests as facts; the seeded, stateless event director;
the rules/presentation split in combat; the audio event bank; `DataIndex`; the M15 export fixes
(`Villager` root configuration, `InteriorZone` group lookup), which are the right shape and not
just patches.

## 6. Refactors performed

| Refactor | Files | Behaviour change |
|---|---|---|
| One safe-moment rule `Player.is_exploring()` | `player.gd`, `main.gd`, `event_host.gd`, `combat_area.gd`, `cinematic_reveal.gd` | Only in the 1.4 s camera blend after a cinematic: saving and event opportunities are now allowed there (control is already back). Pinned by two new checks in `test_reveal`. |
| `DialogueCondition.all_pass`, `DialogueConsequence.apply` | the two data classes, `dialogue_runner.gd`, `event_director.gd`, `quest_tracker.gd` | None. |
| `ActorData.validate`, `EncounterData.validate` + test | data classes, `test_combat_world.gd` | None. |
| `GameState.replace` | `game_state.gd`, `main.gd` | None. |
| Shot harness debug-only, `_normal_launch` | `main.gd` | Release builds ignore `--shot` (and its flags/perf options). |

## 7. Refactors deliberately not performed

- No manager, service locator, registry or event bus. The groups and exports already say who talks to whom.
- `main.gd` wasn't split (P2-4), files weren't moved, folders weren't renamed. The structure is already by responsibility (`core`, `player`, `camera`, `interaction`, `world`, `dialogue`, `quests`, `events`, `combat`, `npcs`, `ui`, `audio`, `save`) and there are no `utils`/`misc` folders.
- No `RegionData`, no inventory, no counting conditions: those belong to M16/M19/M22.
- The EVENT consequence channel wasn't removed or wired (P1-4): M21 decides.
- No static-analysis framework. The guardrails are a handful of checks in existing tests.

## 8. Modding readiness

See `MODDING.md`. Short version: dialogue, quests, events (+ variants), enemies, abilities,
statuses, encounters and audio are data (A). NPCs, discoveries, interactables, combat placement
and guild upgrades need scene composition (C). Regions, condition/consequence types and combat
rules need core code (D). Items, recipes, fishing, crops and jobs don't exist yet (E). No mod
loading exists.

## 9. Export architecture findings

- M15's two export failures had one cause (instance-child overrides dropped). Both are fixed and the pattern is now a failing test.
- No other editor-only pattern was found (table in §3).
- The real export guardrail is procedural: run the suites against the exported pack (`--main-pack`) after any change that ships. Done for M15.5, see §13.

## 10. Technical debt (open)

- P1-4 dead EVENT channel / dead rumour (M21).
- P1-5 single world (M22).
- P2-4 `main.gd` harness extraction.
- `DataIndex` is one file: fine until there are mods or many authors.
- Flag keys are untyped strings with no lint (planned M16 `test_flag_lint`).
- An intermittent engine segfault at process exit (seen three times across M15/M15.5 test and export runs, always after complete output). It's harmless today, but it would make a CI runner report a failure.

## 11. Recommended future architecture work

1. **M16:** counting conditions + ADD + flag lint, built on the two shared methods from P1-2.
2. **M22:** `RegionData` + exits + save v2 (`[player] region`); `Player.is_exploring()` is the rule region exits should use.
3. **When the harness grows:** extract it from `main.gd` to `scripts/debug/`.
4. **When party combat is decided:** move HP ownership to flags (`actor.<id>.hp`) in one milestone.

## 12. Decisions now considered stable

- `GameState` flags are the only persistent world state; the save is flags + player position + health (+ region in v2).
- Pure logic for rules and decisions; presentation reacts; headless tests for logic.
- `DialogueCondition` / `DialogueConsequence` are the shared condition/effect language for dialogue, quests and events.
- `Player.is_exploring()` is the safe-moment rule.
- Content found by id goes through `DataIndex`; no runtime folder scans.
- Instanced scenes are configured on their root; never override their children from outside.
- Exported-pack test runs are part of verifying anything that ships.

## 13. Verification

- **Tests:** all 11 suites pass in the editor and against the exported pack. New checks: the two safe-moment checks in `test_reveal`, plus seven validation checks in `test_combat_world`. Details in the M15.5 entry in `DECISIONS.md`.
- **Export:** see the M15.5 entry in `DECISIONS.md`.
