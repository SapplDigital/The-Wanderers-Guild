class_name CinematicReveal
extends Area3D
## Environmental reveal: when the player enters, the camera leaves the rig, glides through
## the child Marker3Ds (in order) while turning toward `focus`, holds, then hands control back
## facing the focus on the LOOK end of the zoom rail. Short by design; no dialogue.

signal revealed

@export var camera_rig: CameraController
@export var focus: Node3D
@export var focus_offset := Vector3.ZERO ## aim above/beside the focus origin
@export var segment_time := 1.8
@export var hold_time := 1.2
@export var reveal_fov := 55.0
@export var turn_sharpness := 2.5
@export var return_zoom := 6.5
@export var once := true

var _pose: Node3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # actors
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and not _pose and not camera_rig.is_cinematic:
		play(body)


func play(player: Player) -> void:
	player.input_enabled = false
	_pose = Node3D.new()
	add_child(_pose)
	_pose.global_transform = camera_rig.camera.global_transform # start where the camera is: no cut
	camera_rig.play_cinematic(_pose, reveal_fov)

	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for marker in get_children():
		if marker is Marker3D:
			tw.tween_property(_pose, "global_position", marker.global_position, segment_time)
	tw.tween_interval(hold_time)
	await tw.finished

	camera_rig.end_cinematic(true, return_zoom)
	player.input_enabled = true
	_pose.queue_free()
	_pose = null
	revealed.emit()
	if once:
		set_deferred("monitoring", false)


func _process(delta: float) -> void:
	if not _pose:
		return
	var aim := focus.global_position + focus_offset
	var goal := _pose.global_transform.looking_at(aim, Vector3.UP).basis
	_pose.global_basis = _pose.global_basis.slerp(goal, 1.0 - exp(-turn_sharpness * delta)).orthonormalized()
