# Playtest guide

For playtesters and developers. This is not in-game text: the game itself explains nothing beyond
the interaction prompts, on purpose. If a playtester needs this page to know what to do *in* the
game, write that down as a finding.

## Launch

**External playtesters get the exported release build** (no developer keys, no Godot needed):
run `tools\package_playtest.ps1`; it exports `export/windows/WanderersGuild.exe`, adds
`docs/playtest/README.txt` (the tester's only instructions) and `docs/playtest/FEEDBACK.txt`, and zips
all three into `export/playtest/`. Every tester gets the same zip. Needs the Godot 4.7.2 mono Windows
export templates installed.

For development the slice also runs from the Godot 4.7.2 editor build:

- Editor: open the project folder in Godot 4.7.2 and press F5 (Run Project).
- Command line:
  `C:\Tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe --path "<project folder>"`

In debug builds the developer keys below work. Playtesters should leave them alone.

## Controls

| | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD / arrow keys | left stick |
| Run | hold Shift | |
| Interact / talk | F (the prompt shows the key) | A |
| Orbit the camera | hold right mouse button and drag (vertical drag tilts) | right stick |
| Rotate the camera | Q / E | right stick |
| Zoom | mouse wheel (zooming all the way in looks out at the horizon) | LB / RB |

**Conversations:** W/S, arrows, stick or D-pad select a reply; F / A confirms; Esc / B leaves. Mouse hover + click also works.

**Combat:** move the cursor with the mouse or WASD; 1 / 2 / 3 pick an ability; F or click confirms; Esc cancels; Space ends the turn. Pad: A confirm, X / Y / D-pad up abilities, B cancel, Start end turn.

Health (the orange pips, top left) comes back slowly while you explore.

## Saving and loading

- One save slot. **F9** saves (all builds); it says "Saved." or "Can't save right now." Saving is refused in a fight, a conversation or a cinematic.
- **Closing the window autosaves** if you're at a safe moment (otherwise the last save stays).
- **Launching opens the title screen**: Continue (only when the save loads) and New Game. New Game over
  an existing save asks first; even then the old save is only replaced by the next F9 or close.
  Nothing saves while the title screen is open.
- Gamepad players have no save button; the autosave on close covers them.
- Save file: `%APPDATA%\Godot\app_userdata\The Wanderer's Guild\save.cfg`

## Starting fresh

Choose New Game on the title screen. For developers, `-- --fresh` skips the title straight into a new
game (the next F9 or window close then overwrites the old save):

`...console.exe --path "<project folder>" -- --fresh`

A new game starts inside the guild's cold common room, next to the hearth.

## Developer / debug keys (debug builds only)

They only act in normal exploration: never during a fight, a conversation or a cinematic.

| Key | Does |
|---|---|
| F1 | debug overlay (FPS, camera, key list); hidden by default |
| F2 / F3 | pixel scale / post shader |
| F4 | replay the overlook reveal from anywhere (writes nothing) |
| F5 | reload the world (leave + return; state must survive) |
| F6 | start the nearest fight |
| F7 | win the current fight |
| F8 | evaluate world events here |
| F10 | load the save |

## Tests

Headless, exit code 0 = pass:

`godot --headless --path . res://tests/<name>.tscn`

`test_exploration_loop`, `test_audio`, `test_combat_rules`, `test_combat_world`, `test_dialogue`,
`test_quest`, `test_events`, `test_guild`, `test_save`, `test_reveal`, `test_data_index`.

Scripted screenshots: see the `--shot` line in `CLAUDE.md`.

## What to write down

Where you got stuck or lost, what you didn't understand, what you wanted to go and look at, anything
that felt broken, and where you stopped playing and why.
