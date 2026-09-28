class_name CinematicReveal
extends Area3D
## Environmental reveal: when the player enters, the camera leaves the rig where it is (no cut),
## glides along one eased path through the child Marker3Ds while turning toward `focus`, holds,
## then hands control back facing the same view on the LOOK end of the zoom rail.
## With a `location_id` the reveal IS that place's discovery: `discovered.<id>` is written once
## control is back (an interrupted reveal simply plays again), the place card shows, and it never
## plays again for this save. Short by design; no dialogue, no skip.

signal revealed

@export var camera_rig: CameraController
@export var focus: Node3D
@export var focus_offset := Vector3.ZERO ## aim beside the focus, e.g. to frame the next reachable goal too
@export var location_id := "" ## empty: no discovery, plays once per world instance (test scenes)
@export var title := ""
@export var travel_time := 3.6 ## the whole path with one ease: no stop at the markers
@export var hold_time := 1.2
@export var reveal_fov := 55.0
@export var turn_sharpness := 2.5
@export var return_zoom := 6.5
@export var sting_delay := 0.8 ## the `reveal` sound, timed to swell into the hold
@export var once := true

var _pose: Node3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # actors
	set_process(false)
	body_entered.connect(_on_body_entered)


func is_discovered() -> bool:
	return location_id != "" and GameState.is_set("discovered." + location_id)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and not _pose and not camera_rig.is_cinematic and not is_discovered():
		play(body)


## record = false is the F4 debug replay: the same shot, but nothing is written and the trigger stays armed.
## Refused while a fight, conversation or another cinematic owns the player's input: the reveal
## hands input back when it ends, so starting inside one of those would unlock the player mid-fight.
func play(player: Player, record := true) -> void:
	if not player.input_enabled or camera_rig.is_cinematic:
		return
	player.input_enabled = false
	_pose = Node3D.new()
	add_child(_pose)
	_pose.global_transform = camera_rig.camera.global_transform # start where the camera is: no cut
	camera_rig.play_cinematic(_pose, reveal_fov)
	set_process(true)

	var path := _path(_pose.global_position)
	var tw := create_tween()
	tw.tween_method(func(d: float) -> void: _pose.global_position = path.sample_baked(d, true),
		0.0, path.get_baked_length(), travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(hold_time)
	create_tween().tween_callback(AudioManager.play.bind(&"reveal")).set_delay(sting_delay)
	await tw.finished

	camera_rig.end_cinematic(true, return_zoom)
	player.input_enabled = true
	_pose.queue_free()
	_pose = null
	set_process(false)
	if record:
		if location_id != "":
			GameState.set_flag("discovered." + location_id)
			get_tree().call_group("hud", "show_location", title)
		if once:
			set_deferred("monitoring", false)
	revealed.emit()


## Start + markers, with Catmull-Rom handles so the glide rounds the markers instead of turning at them.
func _path(start: Vector3) -> Curve3D:
	var points: Array[Vector3] = [start]
	for marker in get_children():
		if marker is Marker3D:
			points.append(marker.global_position)
	var curve := Curve3D.new()
	for i in points.size():
		var tangent := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]) / 6.0
		curve.add_point(points[i], -tangent, tangent)
	return curve


func aim_point() -> Vector3:
	return focus.global_position + focus_offset


func _process(delta: float) -> void:
	var goal := _pose.global_transform.looking_at(aim_point(), Vector3.UP).basis
	_pose.global_basis = _pose.global_basis.slerp(goal, 1.0 - exp(-turn_sharpness * delta)).orthonormalized()
