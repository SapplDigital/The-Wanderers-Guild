extends Node
## Root: owns the low-res pixel pipeline (SubViewportContainer shrink + post shader)
## and the debug keys. Debug input is ignored in release builds.

const PIXEL_SCALES: Array[int] = [1, 2, 3, 4, 5, 6]
const MAIN_WORLD := "res://scenes/world/slice_region.tscn" ## the only world that saves and loads

var save_path := SaveGame.PATH
var _autosave := true ## on quit; off for scripted shot runs

@onready var _pixel_view: SubViewportContainer = $PixelView
@onready var _world: Node3D = $PixelView/SubViewport/World
@onready var _debug_label: Label = $DebugHUD/Label
@onready var _hud: CanvasLayer = $PixelView/SubViewport/ExplorationHUD
@onready var _title: TitleMenu = $PixelView/SubViewport/TitleMenu


func _ready() -> void:
	_debug_label.visible = false # F1 / --overlay show it; a normal start never does
	# Uniforms left at their shader default read back as null; make the toggle state explicit.
	(_pixel_view.material as ShaderMaterial).set_shader_parameter("enabled", true)
	var args := _cli_args()
	if OS.is_debug_build():
		save_path = args.get("save-file", save_path)
		if args.has("world"):
			_swap_world(args.world)
	_hud.bind(_world)
	_title.chosen.connect(_on_title_chosen)
	# A normal launch opens the title screen (Continue / New Game). Shot runs, test worlds and
	# tests (main isn't the current scene there) never show it and never pick up a developer's
	# save unless asked with --load; --fresh skips the title straight into a new game.
	if args.has("load") and OS.is_debug_build():
		load_game()
	elif (get_tree().current_scene == self and not (args.has("fresh") or args.has("shot") or args.has("world"))) 			or (args.has("title") and OS.is_debug_build()): # --title: shot runs of the start screen
		show_title()
	_autosave = not args.has("shot")
	_handle_cli_screenshot(args)


## `--key=value` user args (after `--` on the command line).
func _cli_args() -> Dictionary:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	return args


## `player_at`/`health` (from a save) are applied before the world enters the tree, so the first
## physics step already happens there: no overlap at the default spawn (no false region entry,
## discovery or trigger) and interiors detect the player straight away. The camera rig snaps to
## the player in its own _ready.
func _swap_world(path: String, player_at: Variant = null, health := 0) -> void:
	var viewport := _world.get_parent()
	_world.free()
	_world = (load(path) as PackedScene).instantiate()
	_world.name = "World"
	var player: Player = _world.get_node("Player")
	if player_at != null:
		player.position = player_at
	if health > 0:
		player.health = health
	_hud.bind(_world) # before add_child: the quest cache matches the (loaded) flags before anything can write one
	viewport.add_child(_world)
	viewport.move_child(_world, 0) # keep the HUD drawn on top


## Debug stand-in for leaving and coming back: rebuilds the world from its scene.
## Everything the world remembers must come back from GameState.
func _reload_world() -> void:
	_swap_world(_world.scene_file_path)


## The title screen over the world as a backdrop. The player has no input (so no event, regen or
## interaction), and after a few frames, once the camera and the interior cutaway have settled,
## the world is frozen. It is thrown away either way: both choices rebuild it. The save is only
## read here, never written.
func show_title() -> void:
	var data := SaveGame.read(save_path)
	var exists := FileAccess.file_exists(save_path)
	var note := "" if data.ok or not exists else "The saved game can't be loaded (%s)." % data.error
	(_world.get_node("Player") as Player).input_enabled = false
	_hud.visible = false
	_title.open(data.ok, exists, note)
	var backdrop := _world
	for i in 10:
		await get_tree().physics_frame
	if is_instance_valid(backdrop) and _title.is_open():
		backdrop.process_mode = Node.PROCESS_MODE_DISABLED


## Continue = the normal load; New Game = empty flags + a fresh world at the new-game spawn.
## Both wait one frame so the confirming key press can't also reach the new world.
func _on_title_chosen(action: StringName) -> void:
	await get_tree().process_frame
	if action == TitleMenu.CONTINUE:
		if not load_game():
			show_title() # the save went bad since the title opened: say so, stay here
			return
	else:
		GameState.flags = {}
		_swap_world(MAIN_WORLD)
	_title.close()
	_hud.visible = true


## Saves GameState.flags + the player (see SaveGame). Refused on the title screen, outside the
## main world and while the player is busy (combat, dialogue, cinematic: the same rule as
## EventHost.is_safe).
func save_game() -> bool:
	if _title.is_open():
		return false
	var player: Player = _world.get_node("Player")
	if _world.scene_file_path != MAIN_WORLD or not player.input_enabled or _rig().state == CameraController.State.CINEMATIC:
		return false
	return SaveGame.write(save_path, GameState.flags, player.global_position, player.health) == OK


## Replaces the flags wholesale (no flag_changed: the world is rebuilt from them anyway) and
## rebuilds the main world with the player where they saved. A missing or bad save changes
## nothing; `report_missing` = say so when there is no save at all.
func load_game(report_missing := true) -> bool:
	var data := SaveGame.read(save_path)
	if not data.ok:
		if data.error != SaveGame.NO_SAVE or report_missing:
			_hud.show_message("No save to load." if data.error == SaveGame.NO_SAVE else data.error)
		return false
	GameState.flags = data.flags
	_swap_world(MAIN_WORLD, data.position, data.health)
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _autosave:
		save_game() # unsafe moment: the previous save stays


func _unhandled_input(event: InputEvent) -> void:
	if _title.is_open():
		return # no save, load or debug key before the player has chosen
	if event.is_action_pressed("quicksave"):
		_hud.show_message("Saved." if save_game() else "Can't save right now.")
	if not OS.is_debug_build():
		return
	if event.is_action_pressed("debug_quickload"):
		if _exploring(): # never tear down a fight, conversation or cinematic
			load_game()
	elif event.is_action_pressed("debug_toggle_overlay"):
		_debug_label.visible = not _debug_label.visible
	elif event.is_action_pressed("debug_cycle_pixel_scale"):
		var i := PIXEL_SCALES.find(_pixel_view.stretch_shrink)
		_pixel_view.stretch_shrink = PIXEL_SCALES[(i + 1) % PIXEL_SCALES.size()]
	elif event.is_action_pressed("debug_toggle_post"):
		var mat := _pixel_view.material as ShaderMaterial
		mat.set_shader_parameter("enabled", not mat.get_shader_parameter("enabled"))
	elif event.is_action_pressed("debug_test_cinematic"):
		_test_cinematic()
	elif event.is_action_pressed("debug_reload_world"):
		if _exploring():
			_reload_world()
	elif event.is_action_pressed("debug_start_combat"):
		if _exploring():
			_debug_start_combat()
	elif event.is_action_pressed("debug_trigger_event"):
		get_tree().call_group("event_host", "debug_evaluate")
	elif event.is_action_pressed("debug_win_combat"):
		for combat_area in _world.find_children("*", "CombatArea"):
			if combat_area.controller:
				combat_area.controller.debug_win()


func _process(_delta: float) -> void:
	if not _debug_label.visible:
		return
	var rig := _rig()
	var player: Player = _world.get_node("Player")
	_debug_label.text = "FPS %d | internal %s (x%d) | post %s\ncam %s yaw %.0f° pitch %.0f° zoom %.1f | player %s\n[F2] pixel scale  [F3] post  [F4] play reveal  [F5] reload world  [F6] start fight  [F7] win fight  [F8] trigger event  [F9] save  [F10] load  [RMB] orbit  [Q/E] rotate  [wheel] zoom (in = look at horizon)" % [
		Engine.get_frames_per_second(), _pixel_view.get_node("SubViewport").size, _pixel_view.stretch_shrink,
		(_pixel_view.material as ShaderMaterial).get_shader_parameter("enabled"),
		CameraController.State.keys()[rig.state], rad_to_deg(rig.rotation.y), rad_to_deg(rig.get_node("Pitch").rotation.x),
		rig.get_node("Pitch/SpringArm3D").spring_length, Player.MoveState.keys()[player.move_state]]


func _rig() -> CameraController:
	return _world.get_node("CameraRig")


## Normal exploration: not in a fight, a conversation or a cinematic (they all take player input).
## Debug keys that rebuild the world, start a fight or play a cinematic only act here.
func _exploring() -> bool:
	var player: Player = _world.get_node("Player")
	return player.input_enabled and not _rig().is_cinematic


## Walks the player into the nearest CombatArea's fight (debug shortcut).
func _debug_start_combat() -> void:
	var player: Node3D = _world.get_node("Player")
	var areas := _world.find_children("*", "CombatArea")
	areas.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
	if areas and areas[0].can_start():
		player.global_position = areas[0].global_position + Vector3(-6, 0, 0)
		areas[0].start()


## Replays the first CinematicReveal in the world, wherever the player stands, even after its
## discovery. Debug only: writes no flag and leaves the trigger armed.
func _test_cinematic() -> void:
	var reveals := _world.find_children("*", "CinematicReveal")
	if reveals and _exploring():
		reveals[0].play(_world.get_node("Player"), false)


## `godot -- [--world=res://...tscn] --shot=C:/abs/shot.png [--save-file=C:/abs/save.cfg] [--load] [--title] [--perf[=frames]] [--stress=3] [--overlay] [--flags=a,b] [--pad] [--interact] [--actions=name@frame,...] [--seed=N] [--then=x,y,z] [--pos=x,y,z] [--yaw=90] [--pitch=10 (offset)] [--zoom=14] [--scale=3] [--post=0] [--walk] [--reveal] [--frames=90]`
## renders N frames, saves the PNG and quits. --seed also seeds the world event director. --interact sends a real "interact" input event at frame 45;
## --then reloads the world afterwards (leave + return) and puts the player at that position.
func _handle_cli_screenshot(args: Dictionary) -> void:
	if not args.has("shot"):
		return
	if args.has("scale"):
		_pixel_view.stretch_shrink = int(args.scale)
	if args.has("post"):
		(_pixel_view.material as ShaderMaterial).set_shader_parameter("enabled", args.post != "0")
	if args.has("yaw"):
		_rig()._yaw_goal = deg_to_rad(float(args.yaw))
	if args.has("pos"):
		var p: PackedFloat64Array = (args.pos as String).split_floats(",")
		_world.get_node("Player").global_position = Vector3(p[0], p[1], p[2])
		_rig().global_position = Vector3(p[0], p[1], p[2])
	if args.has("pitch"):
		_rig()._pitch_offset_goal = deg_to_rad(float(args.pitch))
	if args.has("zoom"):
		_rig()._zoom_goal = float(args.zoom)
	if args.has("walk"):
		Input.action_press("move_forward")
	if args.has("reveal"):
		_test_cinematic.call_deferred()
	if args.has("pad"):
		var pad := InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_Y
		pad.pressed = true
		Input.parse_input_event(pad)
	if args.has("seed"):
		for combat_area in _world.find_children("*", "CombatArea"):
			combat_area.rng_seed = int(args.seed)
		GameState.set_flag(EventDirector.SEED, int(args.seed))
	if args.has("stress"):
		print("stress: added %d forest mesh copies" % PerfProbe.stress(_world.get_node("Forest"), int(args.stress)))
	for key in (args.get("flags", "") as String).split(",", false):
		GameState.set_flag(key)
	_debug_label.visible = args.has("overlay")
	for i in int(args.get("frames", "90")):
		await get_tree().process_frame
		for spec in (args.get("actions", "") as String).split(",", false):
			var parts := spec.split("@")
			if parts.size() == 2 and int(parts[1]) == i:
				var press := InputEventAction.new()
				press.action = parts[0]
				press.pressed = true
				Input.parse_input_event(press)
				var release := press.duplicate() as InputEventAction
				release.pressed = false
				Input.parse_input_event(release)
		if i == 45 and args.has("interact"):
			var press := InputEventAction.new()
			press.action = "interact"
			press.pressed = true
			Input.parse_input_event(press)
		if i == 75 and args.has("then"):
			_reload_world()
			var t: PackedFloat64Array = (args.then as String).split_floats(",")
			_world.get_node("Player").global_position = Vector3(t[0], t[1], t[2])
			_rig().global_position = Vector3(t[0], t[1], t[2])
	if args.has("perf"):
		var sub: Viewport = _pixel_view.get_node("SubViewport")
		print(await PerfProbe.measure(get_tree(), sub, int(args.perf) if args.perf != "" else 300))
	var shot_texture := get_viewport().get_texture() if DisplayServer.get_name() != "headless" else null
	var shot_image := shot_texture.get_image() if shot_texture else null
	if shot_image:
		shot_image.save_png(args.shot)
	else:
		print("shot skipped: the active renderer does not expose viewport pixels")
	print("shot: player at ", _world.get_node("Player").global_position, " camera=", CameraController.State.keys()[_rig().state], " flags=", GameState.flags, _combat_summary())
	get_tree().quit()


func _combat_summary() -> String:
	for combat_area in _world.find_children("*", "CombatArea"):
		if combat_area.controller:
			var st: CombatState = combat_area.controller.state
			var parts := st.order.map(func(u: CombatUnit) -> String:
				return "%s@(%0.1f,%0.1f) %d/%dhp" % [u.data.display_name, u.position.x, u.position.z, u.hp, u.data.max_hp])
			return "\n  combat round %d, turn: %s, order: %s" % [st.round_number, st.current().data.display_name, ", ".join(parts)]
	return ""
