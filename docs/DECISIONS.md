# Decisions

Short log. Newest at the bottom. Format: date — decision — why.

- 2026-09-28 — **GDScript**, not C#. — No build step, works with the godot MCP, simple headless tests. Revisit only if performance-heavy systems need it.
- 2026-09-28 — **Pixel pipeline = SubViewportContainer with `stretch_shrink` (default 3 → 640×360) + nearest upscale + posterize/Bayer-dither shader.** UI renders at native res above it. — Standard low-res 3D approach; UI text stays readable; shrink is tunable per display.
- 2026-09-28 — **Perspective camera, FOV 40**, not orthographic. — Distant landmarks (the core "what's that?" hook) need perspective depth. Cost: some texel shimmer while rotating; accepted after the spike.
- 2026-09-28 — **Visual spike passed; pixel-art-3D direction approved by the user.** No low-poly fallback.
- 2026-09-28 — Cinematics: Camera3D is top_level and blends between the gameplay anchor and any `Node3D` pose (`play_cinematic(pose, fov)` / `end_cinematic(adopt_view, return_zoom)`). — Any scripted tween/animation can drive a pose; the return blend is automatic.
- 2026-09-28 — Textures are procedural (NoiseTexture2D with palette gradients) until the art direction is locked. — No asset production before the spike is validated (GDD 19.3).
- 2026-09-28 — **Camera states NORMAL / LOOK / CINEMATIC.** NORMAL and LOOK are one continuous zoom rail, not modes: zooming in lowers pitch (-55° far → -8° near), raises the pivot to shoulder height and shifts the frame (v_offset) so the player sits low and the horizon fills the view. Mouse/stick pitch offset (±25°) rides on top; absolute limits -75°..+10°. — Looking at the horizon is a scroll-wheel away and never feels like a separate mode.
- 2026-09-28 — **`CinematicReveal` (Area3D + Marker3D path + focus).** Starts at the current camera pose (no cut), glides through markers while slerping toward the focus, widens FOV, holds, then returns with yaw AND pitch adopted on the LOOK end of the rail. Player input is locked only during the ~5 s reveal. — The revealed thing is still in frame when control returns; that's the moment the player decides to go there.
- 2026-09-28 — **Landmark readability = thin exponential fog (0.0025) + height fog (below 4 m).** — Ground clutter fades into mist while tall silhouettes stay readable at 300 m+. Composition rule from the camera test: the hero silhouette must stand against open sky, not overlap nearer landmarks or mountains.
- 2026-09-28 — **Slice region layout:** village south, forest north, path → overlook hill → reachable ruin; floating island + giant tree + mountains as unreachable horizon landmarks. Every stop has a reason: village LOOK shows the ruin above the treeline, the camp's trail stones point to the hidden hollow, the overlook reveal frames the island with the ruin as the next reachable goal. — Pull the player forward with sightlines, not waypoints (GDD 7).
- 2026-09-28 — Blockout geometry is instanced prop scenes + generated `.tscn` (generator was a one-off); edit the scene in the editor from now on. Hill collision via `trimesh_collision.gd`.
- 2026-09-28 — **World memory = `GameState` autoload with flat string flags** (`discovered.*`, `<id>.used`, `world.*`; later `npc.*`, `quest.*`, `event.*`) + `flag_changed` signal. — The event director (M10) will read prerequisites from and write consequences to the same store; save/load (M12) is just this dictionary. No schema until data files start writing keys.
- 2026-09-28 — **Interaction building blocks:** `Interactable` (verb, persistent id, one-shot, message / repeat / flag-conditional message, sets a flag, emits `interacted`), `Interactor` on the player (nearest usable in reach), `DiscoveryZone` (first entry → flag + place-name card), `StateToggle` (show/hide world pieces from a flag). Messages are a stopgap until dialogue (M8) takes over longer text.
- 2026-09-28 — **HUD renders inside the 640×360 pixel viewport** (pixel-consistent, upscaled with the world). Prompt is anchored to the focused object, not a fixed screen slot. Grayscale font AA at 10 px: no-AA 8 px kerned badly ("old" read as "ald"). No quest markers; compass shows cardinals only.

## Player experience audit — end of M5 (2026-09-28)

Evidence: scripted screenshots of village, notice board, camp arrival, camp→hollow sightline, shrine, return to the glowing well; headless loop test (16 checks) passes.

- **Is the player looking at the environment?** Yes. HUD is ~3% of the screen: six pips, a faint compass strip, a prompt that sits on the object, text that fades.
- **Is the UI distracting?** No. Messages up to two lines at the bottom for ~4–6 s. Place-name cards only on first discovery.
- **Is exploration rewarding?** Partly. Each discovery gets a name card and a line of writing; the shrine changes the village well (visible cross-map consequence). *Gaps:* berries have no use yet (inventory M9-ish); the reachable ruin ("The Broken Gate") has nothing in it yet — a promise without payoff; no audio at all, so discoveries have no sound beat.
- **Discoverable without markers?** Camp: yes (burning lantern + light pool off the path). Hollow: **failed on first check** — from the camp nothing pointed to it. Fixed with diegetic wisps ("lights in the old wood" from the notice board and journal) leading to the hollow's gap; they go out once the shrine wakes. Re-checked: a clear teal mote and light pool reads between the trunks.
- **Does the camera still encourage looking into the distance?** In the village and on the overlook, yes (ruin and island above the treeline). In the forest the canopy closes the sky at LOOK zoom — intended (forest = enclosed, overlook = release), but the crown clipping issue makes it worse; needs occluder fading.
- **Place or collection of objects?** Blockout-level place: lit windows, lanterns, the camp scene read as lived-in. Missing: people and sound. The village has no NPCs yet (M8/M9) and silence makes everything feel like a diorama.

**Open issues to carry forward**
1. Ruin needs a payoff (combat encounter or quest beat there in M6–M9).
2. Ambient audio (village fire/voices, forest wind, wisp hum) is the cheapest big win for "place" — do before or with M13's music sting.
3. Occluder fading for tree crowns/roofs (polish).
4. Prompt shows "F" even on gamepad; swap glyph by last input device later.
5. Interaction feedback is text only; a small sound + tiny camera nudge would make it feel physical.
6. Not hand-tested: walking the full loop with real input end to end (all steps verified individually via scripted shots/tests).

## Atmosphere pass (2026-09-28)

- **Audio = event names, not files.** Gameplay calls `AudioManager.play(&"discovery")`, `play_at(&"interact", node)`; `data/audio/sound_bank.tres` maps each event to stream(s), bus, volume, pitch variance, loop, 3D range. Replacing a sound = editing the bank. Scene pieces: `SoundEmitter` (looping world sound, follows visibility so StateToggles silence it), `AmbienceZone` (layered beds, last-entered wins, 2.5 s crossfade), `SurfaceArea` + `Footsteps` (dirt/wood/grass by area under the feet). Buses Music/Ambience/SFX/UI created at startup; volumes saved in user://audio.cfg.
- Placeholder sounds generated with ElevenLabs; source files had wildly different levels (forest bed -74 dB mean, combat bed -12 dB), so all files are peak-normalised and **the mix lives in the bank's volume_db**. OGG instead of MP3 so loops are gapless.
- One-shots are added deferred with autoplay: `play_at` during scene setup (e.g. a discovery on spawn) used to fail with "parent busy".
- **Tree crowns fade near the camera** with StandardMaterial3D's built-in pixel-dither distance fade (3–7 m). Native feature, dithered look fits the pixel style; replaces the planned custom occluder shader for now. Does not handle crowns >7 m between camera and player (rare at LOOK zoom).
- Prompt glyph follows the last used device, read from the InputMap (layout-correct key names; Xbox labels on pad).
- Interaction feedback: UI tick + world sound at the object + player turns toward it and leans in + prompt pulse.
- Wisps sit 2.1 m high and alternate 1.5 m either side of the trail: at chest height in the gap they covered the player.

### "Does this feel like a place now?" (honest answer)

I cannot listen to the output, so this is what is verified and what is not:
- **Verified (test_audio, 23 checks: 14 bank-coverage + 9 behaviour):** every event used in the region exists in the bank; village → forest → combat clearing → village switches beds correctly; plaza/path are dirt, off-path grass; wisps and dormant shrine hum until the shrine wakes, then go silent and the well starts humming (matches "the humming stops" in the text). All files measured: levels normalised, durations 0.5–5 s.
- **Verified visually:** crowns no longer wall off the camera at the hollow; wisps read from the camp and no longer cover the player; pad prompt shows "A".
- **Not verified — needs a human ear:** whether the mix balance is right, whether 5-second loops sound repetitive (ElevenLabs caps SFX at 5 s; two layers of different content help but may not hide it), whether the footstep sample (one per surface, pitch-varied) sounds machine-gunny when running.
- Likely weak spots: 5 s ambience loops; a single interact sound for everything (journal, berries, lantern); no reverb/occlusion.

## Milestone 6: world-space combat migration (2026-09-28)

The earlier grid prototype is obsolete. The GDD's world-space combat design is authoritative: positions and distances are continuous, and the actual clearing supplies obstacles, cover, terrain and elevation. Do not restore `CombatGrid`, cell coordinates, grid overlays or grid-based UI.

- **Rules vs presentation split.** `CombatSpace` and `CombatState` are testable rules; commands return events which `CombatController` plays back. `CombatArea` scans scene collision and surface data. `TacticalOverlay` draws temporary rings, paths and attack lines only while choosing. `CombatUnit.position` is a `Vector3`; movement plans are distance based and route around obstacles.
- **Tactical factors:** line of sight, partial cover, terrain cost/defense, height advantage, engagement zones and opportunity attacks are handled in the shared world-space rules. HUD language explains range, cover and blocked sight in metres and plain words.
- **Encounter design:** enemies are visible before combat; entering the trigger engages, while walking around preserves the option to avoid the encounter. Victory persists the cleared flag; defeat returns the player to the clearing edge. Exploration health carries into and out of combat.
- **Verification status:** `tests/test_combat_rules.gd` was migrated to world-space cases and checks the combat scripts for grid remnants. Run it and validate the actual scene in Godot before treating this migration as complete; the current handoff environment has no Godot executable/MCP available.

## Pre-M7 design audit (2026-09-28)

- The game is an exploration RPG first. Combat is optional when the encounter fiction allows it; preserve bypass, investigation, negotiation and retreat as future encounter outcomes.
- Treat enemies as behavior/data profiles rather than assuming all hostile entities are conventional combatants. The three slice archetypes are examples, not an exhaustive model; allow passive, fleeing, territorial, negotiable and world-scale entities later.
- Do not introduce traditional classes, levels or numerical progression inflation before the core loop proves a need. Keep progression open to equipment, abilities, discoveries, relationships, guild growth and player choices.
- Environmental rules should follow visible physical causes. Keep the tactical overlay temporary and modest; do not convert every prop into a bonus.
- The revised GDD and master prompt now use the exploration-first genre and add the audit's slice success criteria. M7 stays gated until the migration and integration are verified.

### M6 player-experience check
- **At the end of the grid prototype:** the HUD showed turn, movement, targets, hit chance, damage, cover and action economy; the log explained attack rolls. This observation predates the world-space migration and is not evidence for the current interface.
- **World-space target:** tactical overlays should explain metre range, route cost, threat zones, cover and blocked sight only while deciding; the clearing remains visible and usable as the battlefield.
- **Weak spots:** placeholder boars are boxes; the move range colour hides terrain tints inside it; the enemy "brain" is a stub (M7); no turn-start sound; the reaction is easy to miss in the log (it has a float text but no distinct sound or camera beat).

## M7 AI dispatcher (2026-09-28)

- **Data chooses the brain; profile labels do not dispatch behavior.** `ActorData.ai_profile` is readable encounter data, while `ActorData.ai_brain` names a `CombatBrain` script. `BrainDispatcher` creates that script and sends only its intent dictionaries to `CombatState`, which continues to validate movement and ability use. Adding passive, fleeing, defensive, territorial, social, negotiable, environmental or unusual creatures requires a data/script choice, not a dispatcher edit.
- **Three demonstration strategies:** `MeleeBeastBrain` approaches a vulnerable foe; `RangedUtilityBrain` samples legal firing positions and values target exposure, cover and terrain; `GuardianBrain` declares a generic visible intent before its heavy strike. The declaration is transient AI state on `CombatUnit.brain_memory`; combat rules do not interpret it.

## M7 authored encounters (2026-09-28)

- **Three optional encounters, each visible before it starts:** boars in the clearing (unchanged), two Glimmer Midges among three stones and a mud patch at the forest edge (`Forest/MidgeStones`, ~11 m off the direct overlook→gate line, so walking past is a natural choice), and the Mossbound Guardian standing in the Broken Gate (`Landmarks/GateGuardian`, inside the discovery zone, so you see and name the place before the 7 m trigger). Copy lives in `EncounterData` (`engage_message` added; the controller no longer hardcodes "The boars notice you.").
- **Telegraph = public warning, not rules state.** A `declare` intent may carry `radius`; the dispatcher copies it to `CombatUnit.telegraph_radius`, which the controller draws as a solid hot ring during the player's turn and mentions in the move hint ("Still inside X's swing!"). `forget` clears it. The positional answer is to step out of reach; the guardian (3 m/turn) then lumbers after you still wound up.
- **Defeat wakes you on the side you came from** (was always centre −x, which lands inside the gate's pillar). The ruin's pillars got collision, so the player can't walk through them and combat treats them as obstacles.
- **Placeholder bodies:** `ActorData.view_scale` (guardian 1.7, midge 0.6) so the elite reads as big and the midges as small. No new art.
