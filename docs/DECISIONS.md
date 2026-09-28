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

## Milestone 6: tactical combat prototype (2026-09-28)

- **Rules vs presentation split.** `CombatGrid` (cells, terrain, occupancy, Dijkstra range/paths, line of sight, cover), `ActionResolver` (d20), `CombatUnit` (runtime state), `CombatState` (turn order + action economy + resolution) are pure logic, tested headless. Commands return an **event log** (`step`, `attack`, `buff`, `defeated`, `turn_start`, `combat_end`) that `CombatController` plays back as animation. Mapping to the master prompt's names: TurnManager = `CombatState` turn order; TargetingSystem = `CombatState.targets_for/in_range`; StatusEffectSystem = `StatusData` + `CombatUnit` statuses; PathfindingService = `CombatGrid.reachable/path_to`; GridBoard/GridCell = `CombatGrid` (cells are plain Vector2i keys, no GridCell object needed yet).
- **Resolution:** d20 + attack modifier ≥ defense. Natural 20 = hit + damage die rolled twice, natural 1 = miss. Cover (+2) when a low obstacle next to the target lies on the line from a ranged attacker. Water: −1 defense (bad footing). Mud and water cost 2 movement. `hit_chance()` uses the same rule, so the HUD's "Hit 70%" is exact. Verified statistically (4000 rolls, ±3%).
- **Movement is 4-way (Manhattan)** and range uses the same metric: readable and consistent (Fire Emblem-like). Units can't pass through each other (ponytail: allies passing through each other later if needed).
- **Reactions are ready from the start of a fight**, one per round, refreshed at the start of the unit's own turn. The only reaction for now: opportunity strike when a foe leaves your reach.
- **Player kit (original):** Strike (action, melee, 1d8+2), Lantern Flare (action, range 2–5, needs sight, 1d4 + Dazzled −3 to hit for a turn), Nimble Step (bonus: +2 move, moving provokes no reactions), opportunity strike (reaction). Wanderer: 12 HP, DEF 12, move 5, +4. Thornback Boar: 9 HP, DEF 11, move 4, +3, Gore 1d6+1.
- **The world is the arena.** `CombatArena` scans the real clearing: trees/houses → blocked, `low_cover` group (rocks) → cover, SurfaceArea mud/water → terrain. The clearing's rocks and stream form a natural wall; boars need two turns to reach you, which gives the flare and positioning a purpose.
- **Engage or bypass:** enemies graze visibly in the clearing before the fight (HP labels hidden until combat, which is UI), the combat ambience bed telegraphs it on approach; entering the trigger starts the fight, walking around doesn't. Victory sets `encounter.<id>.cleared`; defeat is a setback (wake at the edge with 1/3 HP, boars stay), not a game over.
- **Exploration HP carries into the fight and back.**
- Combat input: mouse (hover/click) or keyboard/pad cursor (camera-relative), 1/2/3 (X/Y/D-pad up) abilities, confirm = interact, cancel = ui_cancel, end turn = Space/Start. Clicking an enemy in move mode = first attack if in range. Choosing a targeted ability snaps the cursor to the first valid target.
- Water material made less glossy (roughness 0.55, metallic 0): its moonlight specular turned into a huge bloom blob on the stream at some camera angles. Grid overlay has `render_priority = 1` so it always draws over water.
- **Scripted in-app runs are not strict replays:** the rules RNG is seeded (`--seed`), but inputs sent at fixed frames can land during busy animations and be ignored. In-app runs verify presentation/flow; correctness lives in `test_combat_rules`.

### M6 player-experience check
- **Understandable without a manual?** Mostly: whose turn, move range, path, targets, hit %, damage range, cover and the `[x]/[ ]` action economy are all on screen; the log explains every roll ("rolls 10+4=14 vs 11. Hit for 8"). Not yet explained: *why* you can't reach a cell (cover/water costs are colour-only on the grid when not in move range).
- **Looks like the world, not a board game:** the grid sits on the real clearing with its rocks, stream and mud; the camera stays the exploration camera at tactical zoom.
- **Weak spots:** placeholder boars are boxes; the move range colour hides terrain tints inside it; the enemy "brain" is a stub (M7); no turn-start sound; the reaction is easy to miss in the log (it has a float text but no distinct sound or camera beat).
