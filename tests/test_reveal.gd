extends Node
## M13 overlook reveal in the real main scene: walking onto the crest starts the reveal (input,
## camera, save and event opportunities locked), the glide is one continuous path ending at the
## last marker, the camera aims at the composition, control returns on the LOOK end facing it
## with the island and the Broken Gate both in frame, and `discovered.overlook` is written only
## then. Afterwards it never replays (re-entry, F5, save/load); fresh flags replay; the F4 debug
## replay writes nothing. Timings are shortened on the instances; the path and aim are real.
##   godot --headless --path . res://tests/test_reveal.tscn

const MAIN := preload("res://scenes/main.tscn")
const PATH := "user://test_reveal.cfg"
const FLAG := "discovered.overlook"
const APPROACH := Vector3(24, 11, -78) ## on the path below the crest, outside the reveal box
const CREST := Vector3(24, 11, -86) ## inside the reveal box (overlaps report ~3 physics steps after a teleport)
const RUIN_AIM := Vector3(0, 20, 0) ## middle of the 40 m gate, relative to Landmarks/Ruin
const SPIRE_TIP := Vector3(-8, 75, 4) ## top of the island's tall spire, relative to the island
const CUT := 5.0 ## metres in one frame
const ASPECT := 16.0 / 9.0 ## the game's 640x360 view (headless windows are square)

var _failures := 0


func _ready() -> void:
	GameState.flags = {EventDirector.SEED: 1}
	var main := MAIN.instantiate()
	main.save_path = PATH
	add_child(main)
	await _physics(3)
	await _first_reveal(main)
	await _no_replay(main)
	await _fresh_and_debug(main)
	main.queue_free()
	_remove(PATH)
	GameState.flags = {}
	print("reveal: %s (%d failures)" % ["OK" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _first_reveal(main: Node) -> void:
	var reveal := _fast(main)
	var rig := _rig(main)
	var player := _player(main)
	_check(reveal.location_id == "overlook" and reveal.title == "The Overlook", "the reveal is the overlook's discovery")
	_check(main._world.find_children("*", "DiscoveryZone").all(func(z: DiscoveryZone) -> bool: return z.location_id != "overlook"),
		"no separate DiscoveryZone competes for the overlook")

	await _place(main, APPROACH)
	var opportunity: Variant = GameState.get_flag(EventDirector.OPPORTUNITY)
	_check(not rig.is_cinematic and not GameState.is_set(FLAG), "below the crest nothing plays yet")
	var orbit := InputEventAction.new()
	orbit.action = &"camera_orbit"
	orbit.pressed = true
	Input.parse_input_event(orbit) # RMB held while walking onto the crest
	await get_tree().process_frame
	_check(rig._orbiting, "(setup) orbit is held before the reveal")

	# Onto the crest; the rig comes along so any camera jump from here on would be a cut.
	player.global_position = CREST
	rig.global_position = CREST
	var cam_path: Array[Vector3] = []
	for i in 6:
		await get_tree().physics_frame
		cam_path.append(rig.camera.global_position)
	_check(rig.is_cinematic and rig.state == CameraController.State.CINEMATIC, "entering the crest starts the reveal (rig CINEMATIC)")
	_check(not player.input_enabled, "player input is off during the reveal")
	_check(not rig._orbiting, "the reveal clears a held orbit")
	_check(not main.save_game(), "saving is refused during the reveal")
	_check(not GameState.is_set(FLAG), "the discovery isn't written while the reveal plays")
	var release := orbit.duplicate() as InputEventAction
	release.pressed = false
	Input.parse_input_event(release) # released mid-reveal: ignored by the rig

	# Debug keys are guarded: F5 and F6 do nothing mid-reveal.
	var world: Node = main._world
	main._unhandled_input(_action(&"debug_reload_world"))
	main._unhandled_input(_action(&"debug_start_combat"))
	await _physics(1)
	_check(main._world == world and rig.is_cinematic, "F5 doesn't rebuild the world mid-reveal")
	_check(main._world.find_children("*", "CombatArea").all(func(c: CombatArea) -> bool: return c.controller == null),
		"F6 doesn't start a fight mid-reveal")

	# Sample the pose every frame until control returns.
	var samples: Array[Vector3] = []
	var aim_error := 180.0
	var last_forward := Vector3.ZERO
	var timeout := Time.get_ticks_msec() + 6000
	while reveal._pose and Time.get_ticks_msec() < timeout:
		samples.append(reveal._pose.global_position)
		cam_path.append(rig.camera.global_position)
		last_forward = -reveal._pose.global_basis.z
		aim_error = rad_to_deg(last_forward.angle_to(reveal.aim_point() - reveal._pose.global_position))
		if rig.is_cinematic:
			_check_quiet(not GameState.is_set(FLAG) and not main.save_game(), "flag unset and save refused throughout")
		await get_tree().process_frame
	var markers := reveal.get_children().filter(func(n: Node) -> bool: return n is Marker3D)
	var last_marker: Vector3 = markers[-1].global_position
	_check(samples.size() > 10 and samples[-1].distance_to(last_marker) < 0.05, "the glide ends at the last marker (%.3f m)" % samples[-1].distance_to(last_marker))
	_check(aim_error < 2.0, "at the hold the camera aims at the composition (%.2f°)" % aim_error)
	_check(_passes_marker_moving(samples, markers[0].global_position), "the glide doesn't stop at the middle marker")
	# A cut would jump tens of metres in one frame; the eased glide moves well under a metre
	# per frame even at the shortened test timing (frame hitches included).
	_check(_max_step(samples) < CUT, "no jump along the glide (max %.2f m per frame)" % _max_step(samples))
	_check(_max_step(cam_path) < CUT, "the camera itself never cuts, from the crest to the hold (max %.2f m per frame)" % _max_step(cam_path))

	_check(not rig.is_cinematic and player.input_enabled, "control returns after the hold")
	_check(GameState.is_set(FLAG), "discovered.overlook is written once control is back")
	_check(_hud_location(main) == "The Overlook", "the place card shows 'The Overlook'")
	_check(not rig._orbiting, "no leftover orbit after the reveal")
	var yaw_goal := atan2(-last_forward.x, -last_forward.z)
	_check(absf(angle_difference(rig.rotation.y, yaw_goal)) < deg_to_rad(1.0), "the camera keeps the reveal's yaw")
	_check(is_equal_approx(rig._zoom, reveal.return_zoom), "zoom returns to the LOOK end (%.1f)" % rig._zoom)
	_check(GameState.get_flag(EventDirector.OPPORTUNITY) == opportunity, "the reveal created no event opportunity")

	await _until(func() -> bool: return rig.state != CameraController.State.CINEMATIC)
	await _physics(2)
	var pitch := rad_to_deg(rig.get_node("Pitch").rotation.x)
	_check(pitch <= rig.pitch_max_deg + 0.01 and pitch >= rig.pitch_min_deg, "pitch stays within the camera limits (%.1f°)" % pitch)
	var cam := rig.camera
	var island: Vector3 = main._world.get_node("Landmarks/FloatingIsland").global_position
	var ruin: Vector3 = main._world.get_node("Landmarks/Ruin").global_position + RUIN_AIM
	var i2 := _frame(cam, island)
	var r2 := _frame(cam, ruin)
	_check(_inside(i2) and _inside(r2), "after the return blend the island and the Broken Gate are both in frame (island %s, gate %s)" % [i2, r2])
	_check(r2.x < 0.45 and i2.x > 0.55 and i2.y < 0.5, "gate on the left, island upper right")
	print("  info: island spire tip at frame y %.2f (< 0 = cropped by the +10° pitch limit)" % _frame(cam, island + SPIRE_TIP).y)
	_check(main.save_game(), "saving works again once the camera is back")


func _no_replay(main: Node) -> void:
	await _place(main, APPROACH)
	_player(main).global_position = CREST
	await _physics(4)
	_check(not _rig(main).is_cinematic, "walking back onto the crest doesn't replay")

	main._reload_world() # F5
	_fast(main)
	await _physics(3)
	await _place(main, APPROACH)
	_player(main).global_position = CREST
	await _physics(4)
	_check(not _rig(main).is_cinematic, "after F5 the crest doesn't replay")

	_check(main.save_game(), "save on the crest after the discovery")
	GameState.flags = {EventDirector.SEED: 1}
	_check(main.load_game(), "load it back")
	await _physics(3)
	var rig := _rig(main)
	_check(GameState.is_set(FLAG), "the discovery survives save/load")
	_check(_player(main).global_position.distance_to(CREST) < 1.0, "loaded standing on the crest")
	_check(not rig.is_cinematic and rig.state != CameraController.State.CINEMATIC and _player(main).input_enabled,
		"loading on the crest starts in normal exploration (no replay)")


func _fresh_and_debug(main: Node) -> void:
	GameState.flags = {EventDirector.SEED: 1}
	main._reload_world()
	var reveal := _fast(main)
	await _physics(3)
	await _place(main, APPROACH)
	main._test_cinematic() # F4 from below the crest
	await _physics(2)
	_check(_rig(main).is_cinematic, "F4 plays the reveal from anywhere")
	await _until(func() -> bool: return not _rig(main).is_cinematic)
	_check(not GameState.is_set(FLAG) and reveal.monitoring, "F4 writes no discovery and leaves the trigger armed")

	await _until(func() -> bool: return _rig(main).state != CameraController.State.CINEMATIC)
	_player(main).global_position = CREST
	await _physics(4)
	_check(_rig(main).is_cinematic, "with fresh flags the crest plays the reveal")
	await _until(func() -> bool: return not _rig(main).is_cinematic)
	_check(GameState.is_set(FLAG), "and records the discovery")

	await _until(func() -> bool: return _rig(main).state != CameraController.State.CINEMATIC)
	main._test_cinematic()
	await _physics(2)
	_check(_rig(main).is_cinematic, "F4 still replays after the discovery")
	await _until(func() -> bool: return not _rig(main).is_cinematic)
	_check(GameState.is_set(FLAG) and _player(main).input_enabled, "the debug replay leaves the discovery and control intact")


## Shortened timings (the path, markers and aim stay real). A fast turn so the aim converges.
func _fast(main: Node) -> CinematicReveal:
	var reveal: CinematicReveal = main._world.get_node("Forest/OverlookReveal")
	reveal.travel_time = 0.8
	reveal.hold_time = 0.3
	reveal.sting_delay = 0.1
	reveal.turn_sharpness = 20.0
	_rig(main).blend_time = 0.3
	return reveal


## Teleports the player (and the rig, so it doesn't trail across the map) and lets it settle.
func _place(main: Node, at: Vector3) -> void:
	_player(main).global_position = at
	_rig(main).global_position = at
	await _physics(20)


func _passes_marker_moving(samples: Array[Vector3], marker: Vector3) -> bool:
	var nearest := 0
	for i in samples.size():
		if samples[i].distance_to(marker) < samples[nearest].distance_to(marker):
			nearest = i
	if nearest == 0 or nearest >= samples.size() - 1:
		return false
	var step := samples[nearest + 1].distance_to(samples[nearest - 1]) / 2.0
	var mean := 0.0
	for i in range(1, samples.size()):
		mean += samples[i].distance_to(samples[i - 1])
	mean /= samples.size() - 1
	return samples[nearest].distance_to(marker) < 0.5 and step > mean * 0.5


func _max_step(points: Array[Vector3]) -> float:
	var most := 0.0
	for i in range(1, points.size()):
		most = maxf(most, points[i].distance_to(points[i - 1]))
	return most


## Where a point lands in a 16:9 frame of this camera: (0,0) top left, (1,1) bottom right.
func _frame(cam: Camera3D, point: Vector3) -> Vector2:
	var local := cam.global_transform.affine_inverse() * point
	var half := tan(deg_to_rad(cam.fov) / 2.0)
	if local.z >= 0.0:
		return Vector2(-1, -1) # behind the camera
	return Vector2(0.5 + 0.5 * (local.x / -local.z) / (half * ASPECT), 0.5 - 0.5 * (local.y / -local.z) / half)


func _inside(p: Vector2) -> bool:
	return p.x > 0.0 and p.x < 1.0 and p.y > 0.0 and p.y < 1.0


func _action(action: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func _hud_location(main: Node) -> String:
	return (main.get_node("PixelView/SubViewport/ExplorationHUD/Root/Location") as Label).text


func _player(main: Node) -> Player:
	return main._world.get_node("Player")


func _rig(main: Node) -> CameraController:
	return main._world.get_node("CameraRig")


func _until(cond: Callable, seconds := 6.0) -> void:
	var timeout := Time.get_ticks_msec() + int(seconds * 1000)
	while not cond.call() and Time.get_ticks_msec() < timeout:
		await get_tree().process_frame


func _physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame
	await get_tree().process_frame


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


var _quiet_failed := {}
func _check_quiet(ok: bool, what: String) -> void: # per-frame check: report a failure once
	if not ok and not _quiet_failed.has(what):
		_quiet_failed[what] = true
		_check(false, what)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAIL: " + what)
	else:
		print("PASS: " + what)
