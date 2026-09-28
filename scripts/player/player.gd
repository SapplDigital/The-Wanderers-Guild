class_name Player
extends CharacterBody3D
## Placeholder exploration character. Movement is relative to the camera rig's yaw.

enum MoveState { IDLE, WALK, RUN }

signal health_changed(health: int, max_health: int)

@export var camera_rig: Node3D
@export var walk_speed := 4.0
@export var run_speed := 7.5
@export var acceleration := 12.0
@export var turn_sharpness := 12.0
@export var max_health := 12
@export var regen_interval := 3.0 ## seconds per HP while exploring: about one walk between encounters heals a hard fight (M14 playtest)

@onready var _visual: Node3D = $Visual

var move_state := MoveState.IDLE
var input_enabled := true
var _regen := 0.0
var health := max_health:
	set(value):
		health = clampi(value, 0, max_health)
		health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	_recover(delta)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if input_enabled else Vector2.ZERO
	var yaw := camera_rig.global_rotation.y if camera_rig else 0.0
	var dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)
	var running := Input.is_action_pressed("run")
	var goal := dir * (run_speed if running else walk_speed)

	var horizontal := Vector3(velocity.x, 0.0, velocity.z).lerp(goal, 1.0 - exp(-acceleration * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

	if dir.length_squared() > 0.01:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-turn_sharpness * delta))
		move_state = MoveState.RUN if running else MoveState.WALK
	else:
		move_state = MoveState.IDLE


## Slow recovery between fights. Only in normal exploration (fights, conversations and cinematics
## take player input away) and never at 0 HP. Health is already saved, so nothing else changes.
func _recover(delta: float) -> void:
	if not input_enabled or health <= 0 or health >= max_health:
		_regen = 0.0
		return
	_regen += delta
	if _regen >= regen_interval:
		_regen -= regen_interval
		health += 1


## Small physical response to an interaction: turn toward the target and lean in briefly.
func reach_toward(point: Vector3) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() > 0.1:
		_visual.rotation.y = atan2(-to.x, -to.z)
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(_visual, "rotation:x", deg_to_rad(-14.0), 0.12)
	tw.tween_property(_visual, "rotation:x", 0.0, 0.25)
