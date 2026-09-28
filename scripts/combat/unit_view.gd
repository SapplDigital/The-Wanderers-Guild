class_name UnitView
extends Node3D
## Placeholder body for a non-player combatant: tinted mesh, small HP label, and a few cheap
## procedural motions so it reads as a living creature — grazing while idle, bobbing while
## walking, flinching when hit, keeling over when defeated.

const PIXEL_MATERIAL: StandardMaterial3D = preload("res://art/materials/cloak.tres")

@onready var _hp: Label3D = $HP
@onready var _body: Node3D = $Body
@onready var _head: Node3D = $Body/Head

var unit: CombatUnit
var show_hp := false ## HP is combat UI; hidden while the creature just grazes
var walking := false
var _down := false
var _phase := randf() * TAU


func bind(combat_unit: CombatUnit) -> void:
	unit = combat_unit
	_body.scale = Vector3.ONE * unit.data.view_scale
	var mat := PIXEL_MATERIAL.duplicate() as StandardMaterial3D
	mat.albedo_color = unit.data.tint * 1.7
	for mesh in find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_in_group("keep_material"):
			(mesh as MeshInstance3D).material_override = mat
	refresh()


func refresh() -> void:
	_hp.text = "%d/%d" % [unit.hp, unit.data.max_hp]
	_hp.visible = show_hp and unit.is_alive()


func _process(delta: float) -> void:
	if _down:
		return
	_phase += delta
	if walking:
		_body.position.y = absf(sin(_phase * 9.0)) * 0.08
		_head.rotation.x = 0.0
	elif show_hp: # in a fight: alert, head up, slight breathing
		_body.position.y = sin(_phase * 2.0) * 0.015
		_head.rotation.x = lerpf(_head.rotation.x, 0.15, delta * 5.0)
	else: # grazing: head goes down to the grass now and then
		_body.position.y = 0.0
		_head.rotation.x = lerpf(_head.rotation.x, 0.55 if sin(_phase * 0.7) > 0.2 else 0.05, delta * 2.0)


func flinch() -> void:
	var tw := create_tween()
	tw.tween_property(_body, "rotation:z", 0.25, 0.06)
	tw.tween_property(_body, "rotation:z", 0.0, 0.2)


func fall() -> void:
	_down = true
	var tw := create_tween()
	tw.tween_property(_body, "rotation:z", PI * 0.5, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(self, "scale", Vector3(1, 0.05, 1), 0.5)
	tw.tween_callback(hide)


func reset_pose() -> void:
	_down = false
	walking = false
	scale = Vector3.ONE
	_body.rotation = Vector3.ZERO
	show()
