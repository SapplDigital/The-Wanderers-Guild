# Progress log

## 2026-09-28
- Repo was empty except the GDD PDF. Extracted it to docs/GDD.md, `git init`.
- M1–M3 built: project.godot (input map, layers), pixel pipeline main scene, CameraController, Player, 12 palette materials, props (tree, rock, house, lantern, landmark ruin), visual_spike world.
- Verified via scripted screenshots: default, vista, rotated, horizon, walking (camera-relative), reveal. No errors/warnings in output.
- Bug found + fixed: hand-written .tscn node exports need `node_paths` header (player moved along world -Z regardless of camera).
- Not verified by hand yet: mouse orbit feel, zoom feel, shimmer while rotating.
- User approved pixel direction. Camera refinement: zoom rail NORMAL<->LOOK, pitch offset, CinematicReveal, camera_test.tscn (forest, overlook, ruin, floating-island silhouette, giant tree, mountains).
- Camera test findings fixed: LOOK framing too tight; ruin blocked the hero silhouette; island lost fog contrast; return from reveal lost the landmark vertically (now adopts pitch; pitch max +10 deg).
- M4 done: slice_region.tscn with village, forest, camp, combat clearing, hidden hollow, overlook reveal, landmarks. Verified via 8 shots (village NORMAL/LOOK, camp, hollow, arena, reveal mid/after) + clean MCP run.
- Bugs fixed on the way: debug label format/arg mismatch (would error every frame with the overlay on); shader toggle read null on first F3; camera clipping into well roof (added roof collisions); DECISIONS.md truncated by cp1252 Python write (restored).
- Added `--world=` and `--overlay` to the shot harness.
- Next: M5 interaction system (Interactable component + prompt + exploration HUD + GameState autoload).
- M5 done: GameState, Interactable/Interactor, DiscoveryZone, StateToggle, exploration HUD (in pixel viewport), F5 world reload, loop test (16 checks, passing).
- PX findings fixed: stale HUD text after reload; bad 8px no-AA kerning; hollow not discoverable from camp (added wisps).
- Open PX issues listed in DECISIONS (ruin payoff, audio, occluder fade, gamepad glyph, interaction feedback).
- Atmosphere pass done (ElevenLabs placeholders, 13 files; AudioManager/sound bank; test_audio 23 checks). Crown dither-fade, pad glyphs, interaction feedback. Needs a human listen.
- M6 done. Found + fixed: HP labels leaking through trees before the fight; water specular bloom blob on the stream; range tint drowning the grid; units had no reaction before their first turn; `round` shadowed a built-in.
- Open: exit-time "ObjectDB leaked" report appears intermittently on quit (not in --verbose runs; likely quitting mid-tween). Low priority.
- Next: M7 enemy AI (3 archetypes with scoring brains; replace BasicBrain by ai_profile).
