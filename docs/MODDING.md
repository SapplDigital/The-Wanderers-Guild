# Modding: current state and intended boundary

**The game does not support mods today.** Nothing loads content from outside the exported pack,
and there is no mod loader, API or SDK. This page records how far each kind of content already is
from "addable without touching core code", so that future work moves toward that boundary
instead of away from it.

The intended boundary:

- **Content** = Resources (`.tres`) + scenes, addressed by id. A mod would *add* files.
- **Systems** = GDScript that never needs to change for new content.
- **No scripting language, no executing code from mods.** The one place content names code is
  `ActorData.ai_brain` (a `CombatBrain` script). Mods could choose from built-in brains, not ship
  their own, unless that is decided later on purpose.

Status legend: **A** data-driven · **B** mostly data-driven · **C** needs scene composition ·
**D** hard-coded · **E** doesn't exist yet.

## Currently data-driven (A)

| Content | Where | Notes |
|---|---|---|
| Dialogue | `data/dialogue/*.tres` | Graph + flag conditions/consequences; validated by `DialogueData.validate()` |
| Quests | `data/quests/*.tres` + `data/data_index.tres` | Facts over flags; must be listed in the index |
| World events + variants | `data/events/*.tres` + index | Weighted, conditional, seeded; must be listed in the index |
| Enemies (stats, abilities, statuses) | `data/actors`, `data/abilities`, `data/statuses` | `ActorData.validate()` |
| Encounters | `data/encounters/*.tres` | `EncounterData.validate()` |
| Audio events | `data/audio/sound_bank.tres` | Event name → streams; gameplay never names files |

## Partially data-driven (B / C)

| Content | Status | What's missing |
|---|---|---|
| NPCs | C | A `villager.tscn` instance configured on its root (`dialogue`, `body_material`). Placement is scene work in the region. |
| Discoveries / locations | C | `DiscoveryZone` / `CinematicReveal` nodes placed in the region scene; no data file. |
| Interactables | C | Exports on an Area3D in a scene. |
| Guild upgrades | B/C | A quest (data) + `guild.<room>.*` flags + `StateToggle`s placed in `guild_hall.tscn`. |
| Combat placement | C | A `CombatArea` node in the region; the encounter itself is data. |
| Combat behaviours (AI) | B | Chosen by data (`ai_brain`), but a new behaviour is a new script. |
| Rumours | B | Just flags written by dialogue; no rumour type or journal (planned M21). |
| Jobs | E | Planned as `QuestData.kind = JOB` posted by events (M21). |

## Requires core code (D)

| Thing | Why |
|---|---|
| New regions / worlds | One hard-coded world (`main.MAIN_WORLD`); saving only there. Planned: `RegionData` registry + exits (M22). |
| New condition or consequence *types* | `DialogueCondition` / `DialogueConsequence` enums (counting conditions planned for M16). |
| Combat rules (terrain kinds, cover, reactions) | `CombatState` / `CombatSpace` constants and code by design: rules are core. |
| Content discovery | `data/data_index.tres` is one file: adding a quest or event means editing it. |

## Future modding support (E)

Not built, and not promised: items, equipment, recipes, fishing tables, crops, regions as data.
The production plan (`POST_M14_PRODUCTION_PLAN.md`) designs each of these as Resources plus flag
conventions (`ItemData`, `RecipeData`, `CatchData`, `RegionData`), which keeps them inside the
boundary above.

## What a future mod system would need (not designed yet)

- Several indexes instead of one `data_index.tres` (base game + one per mod), merged at start, with
  `DataIndex.validate()`'s duplicate-id check across all of them.
- Namespaced ids (`modname.quest_id`) so flags from different mods can't collide.
- Loading external `.pck` files (`ProjectSettings.load_resource_pack`); scenes inside them would
  still need to follow the export rule in `ARCHITECTURE.md` §14.
- A way to place content into an existing region without editing its scene (anchor nodes plus
  spawned instances), and a policy on whether mods may ship scripts at all.

## Rules that keep the door open (follow them now)

1. Address content by **id**, never by file path in code.
2. New content types are **Resources with `validate()`**, tested in a suite.
3. Systems read content through `DataIndex` (or a scene reference), never by scanning folders.
4. World state is **flags** with documented prefixes; no hidden per-system saves.
5. Configure scene instances on their **root**.
