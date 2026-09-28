class_name CameraController
extends Node3D
## 3/4 orbit camera with one continuous zoom "rail":
##   far  = elevated tactical view (NORMAL)
##   near = low pitch, raised pivot, player framed low -> horizon and landmarks fill the view (LOOK)
## Mouse drag / right stick adds a pitch offset on top of the rail.
## Camera3D is top_level and blends between the spring-arm anchor and any Node3D pose
## (CINEMATIC), which ignores all gameplay constraints.

enum State { NORMAL, LOOK, CINEMATIC }

@export var target: Node3D
@export_group("Follow")
@export var follow_sharpness := 8.0
@export var rig_sharpness := 8.0
@export_group("Orbit")
@export var key_yaw_speed := 2.5 ## rad/s for keys / right stick
@export var stick_pitch_speed := 1.2 ## rad/s
@export var mouse_sensitivity := 0.005
@export var pitch_min_deg := -75.0 ## absolute limits after the offset
@export var pitch_max_deg := 10.0 ## > 0 lets LOOK tilt above the horizon for tall landmarks
@export var pitch_offset_range_deg := 25.0
@export_group("Zoom rail")
@export var default_zoom := 17.0
@export var zoom_min := 6.5
@export var zoom_max := 28.0
@export var zoom_step := 1.5
@export var pitch_near_deg := -8.0
@export var pitch_far_deg := -55.0
@export var pitch_curve := 0.5 ## <1: pitch flattens only in the last part of the zoom-in
@export var pivot_height_near := 1.6
@export var pivot_height_far := 0.6
@export var frame_offset_near := 0.7 ## Camera3D.v_offset: pushes the player down the frame
@export var look_threshold_deg := -25.0 ## pitch above this counts as LOOK
@export_group("Cinematic")
@export var blend_time := 1.4

@onready var camera: Camera3D = $Camera3D
@onready var _pitch: Node3D = $Pitch
@onready var _arm: SpringArm3D = $Pitch/SpringArm3D
@onready var _anchor: Node3D = $Pitch/SpringArm3D/Anchor
@onready var _base_fov := camera.fov
@onready var _arm_mask := _arm.collision_mask

var _yaw_goal := 0.0
var _zoom_goal := 0.0
var _pitch_offset_goal := 0.0
var _zoom := 0.0
var _pitch_offset := 0.0
var _orbiting := false
var _cinematic: Node3D
var _cinematic_xform := Transform3D.IDENTITY
var _cinematic_fov := 0.0
var _blend := 0.0 ## 0 = gameplay anchor, 1 = cinematic pose

var is_cinematic: bool:
	get: return _cinematic != null

var state: State:
	get:
		if _blend > 0.0:
			return State.CINEMATIC
		return State.LOOK if rad_to_deg(_pitch.rotation.x) > look_threshold_deg else State.NORMAL


func _ready() -> void:
	top_level = true
	camera.top_level = true
	_yaw_goal = rotation.y
	_zoom_goal = default_zoom
	_zoom = default_zoom
	_cinematic_fov = _base_fov
	if target:
		global_position = target.global_position
	_apply_rail()


## Interiors switch the spring arm's collision off while the player is inside: the cut-away
## walls and roof would otherwise pull the camera down into the room.
func set_collision_enabled(on: bool) -> void:
	_arm.collision_mask = _arm_mask if on else 0


func set_zoom(distance: float) -> void:
	_zoom_goal = clampf(distance, zoom_min, zoom_max)
	_pitch_offset_goal = 0.0


## Hand the view to a pose node (callers may animate it while active).
## fov <= 0 keeps the gameplay FOV.
func play_cinematic(pose: Node3D, fov := 0.0) -> void:
	_cinematic = pose
	_orbiting = false # its release is ignored while cinematic: a held RMB would orbit forever after
	_cinematic_fov = fov if fov > 0.0 else _base_fov


## Return control. adopt_view turns the orbit (yaw and pitch, within limits) to look where the
## cinematic looked, so the revealed thing stays in frame. return_zoom (>0) picks the rail position.
## Goals are snapped, not eased: the camera blend already hides the change.
func end_cinematic(adopt_view := true, return_zoom := 0.0) -> void:
	if return_zoom > 0.0:
		_zoom_goal = clampf(return_zoom, zoom_min, zoom_max)
		_zoom = _zoom_goal
	if _cinematic and adopt_view:
		var fwd := -_cinematic.global_basis.z
		_yaw_goal = atan2(-fwd.x, -fwd.z)
		rotation.y = _yaw_goal
		_pitch_offset_goal = 0.0
		_add_pitch_offset(asin(fwd.y) - _rail_pitch())
		_pitch_offset = _pitch_offset_goal
	_cinematic = null


func _unhandled_input(event: InputEvent) -> void:
	if is_cinematic:
		return
	if event.is_action_pressed("camera_zoom_in"):
		_zoom_goal = clampf(_zoom_goal - zoom_step, zoom_min, zoom_max)
	elif event.is_action_pressed("camera_zoom_out"):
		_zoom_goal = clampf(_zoom_goal + zoom_step, zoom_min, zoom_max)
	elif event.is_action("camera_orbit"):
		_orbiting = event.is_pressed()
	elif event is InputEventMouseMotion and _orbiting:
		_yaw_goal -= event.relative.x * mouse_sensitivity
		_add_pitch_offset(-event.relative.y * mouse_sensitivity)


func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(target.global_position, 1.0 - exp(-follow_sharpness * delta))
	if not is_cinematic:
		_yaw_goal += Input.get_axis("camera_rotate_right", "camera_rotate_left") * key_yaw_speed * delta
		_add_pitch_offset(Input.get_axis("camera_pitch_down", "camera_pitch_up") * stick_pitch_speed * delta)

	var t := 1.0 - exp(-rig_sharpness * delta)
	rotation.y = lerp_angle(rotation.y, _yaw_goal, t)
	_zoom = lerpf(_zoom, _zoom_goal, t)
	_pitch_offset = lerpf(_pitch_offset, _pitch_offset_goal, t)
	_apply_rail()

	if _cinematic:
		_cinematic_xform = _cinematic.global_transform
	_blend = move_toward(_blend, 1.0 if _cinematic else 0.0, delta / blend_time)
	var w := smoothstep(0.0, 1.0, _blend)
	camera.global_transform = _anchor.global_transform.interpolate_with(_cinematic_xform, w)
	camera.fov = lerpf(_base_fov, _cinematic_fov, w)
	camera.v_offset *= 1.0 - w


## Rail pitch (radians, before the player's offset) for the current zoom.
func _rail_pitch() -> float:
	var r := pow(inverse_lerp(zoom_min, zoom_max, _zoom), pitch_curve)
	return deg_to_rad(lerpf(pitch_near_deg, pitch_far_deg, r))


func _apply_rail() -> void:
	var linear := inverse_lerp(zoom_min, zoom_max, _zoom)
	_arm.spring_length = _zoom
	_pitch.rotation.x = clampf(_rail_pitch() + _pitch_offset, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
	_pitch.position.y = lerpf(pivot_height_near, pivot_height_far, linear)
	camera.v_offset = lerpf(frame_offset_near, 0.0, linear)


func _add_pitch_offset(amount: float) -> void:
	var limit := deg_to_rad(pitch_offset_range_deg)
	_pitch_offset_goal = clampf(_pitch_offset_goal + amount, -limit, limit)
