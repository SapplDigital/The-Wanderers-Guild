extends Node
## Root: owns the low-res pixel pipeline (SubViewportContainer shrink + post shader)
## and the debug keys. Debug input is ignored in release builds.

const PIXEL_SCALES: Array[int] = [1, 2, 3, 4, 5, 6]

@onready var _pixel_view: SubViewportContainer = $PixelView
@onready var _world: Node3D = $PixelView/SubViewport/World
@onready var _debug_label: Label = $DebugHUD/Label
@onready var _hud: CanvasLayer = $PixelView/SubViewport/ExplorationHUD


func _ready() -> void:
	_debug_label.visible = OS.is_debug_build()
	# Uniforms left at their shader default read back as null; make the toggle state explicit.
	(_pixel_view.material as ShaderMaterial).set_shader_parameter("enabled", true)
	var args := _cli_args()
	if args.has("world") and OS.is_debug_build():
		_swap_world(args.world)
	_hud.bind(_world)
	_handle_cli_screenshot(args)


## `--key=value` user args (after `--` on the command line).
func _cli_args() -> Dictionary:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	return args


func _swap_world(path: String) -> void:
	var viewport := _world.get_parent()
	_world.free()
	_world = (load(path) as PackedScene).instantiate()
	_world.name = "World"
	viewport.add_child(_world)
	viewport.move_child(_world, 0) # keep the HUD drawn on top
	_hud.bind(_world)


## Debug stand-in for leaving and coming back: rebuilds the world from its scene.
## Everything the world remembers must come back from GameState.
func _reload_world() -> void:
	_swap_world(_world.scene_file_path)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed("debug_toggle_overlay"):
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
		_reload_world()
	elif event.is_action_pressed("debug_start_combat"):
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
	_debug_label.text = "FPS %d | internal %s (x%d) | post %s\ncam %s yaw %.0f° pitch %.0f° zoom %.1f | player %s\n[F2] pixel scale  [F3] post  [F4] play reveal  [F5] reload world  [F6] start fight  [F7] win fight  [F8] trigger event  [RMB] orbit  [Q/E] rotate  [wheel] zoom (in = look at horizon)" % [
		Engine.get_frames_per_second(), _pixel_view.get_node("SubViewport").size, _pixel_view.stretch_shrink,
		(_pixel_view.material as ShaderMaterial).get_shader_parameter("enabled"),
		CameraController.State.keys()[rig.state], rad_to_deg(rig.rotation.y), rad_to_deg(rig.get_node("Pitch").rotation.x),
		rig.get_node("Pitch/SpringArm3D").spring_length, Player.MoveState.keys()[player.move_state]]


func _rig() -> CameraController:
	return _world.get_node("CameraRig")


## Walks the player into the nearest CombatArea's fight (debug shortcut).
func _debug_start_combat() -> void:
	var player: Node3D = _world.get_node("Player")
	var areas := _world.find_children("*", "CombatArea")
	areas.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
	if areas and areas[0].can_start():
		player.global_position = areas[0].global_position + Vector3(-6, 0, 0)
		areas[0].start()


## Plays the first CinematicReveal in the world, wherever the player stands.
func _test_cinematic() -> void:
	var reveals := _world.find_children("*", "CinematicReveal")
	if reveals and not _rig().is_cinematic:
		reveals[0].play(_world.get_node("Player"))


## `godot -- [--world=res://...tscn] --shot=C:/abs/shot.png [--overlay] [--flags=a,b] [--pad] [--interact] [--actions=name@frame,...] [--seed=N] [--then=x,y,z] [--pos=x,y,z] [--yaw=90] [--pitch=10 (offset)] [--zoom=14] [--scale=3] [--post=0] [--walk] [--reveal] [--frames=90]`
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
