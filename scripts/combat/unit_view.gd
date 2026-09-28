class_name UnitView
extends Node3D
## Placeholder body for a non-player combatant: tinted mesh + small HP label.

const PIXEL_MATERIAL: StandardMaterial3D = preload("res://art/materials/cloak.tres")

@onready var _hp: Label3D = $HP

var unit: CombatUnit
var show_hp := false ## HP is combat UI; hidden while the creature just grazes


func bind(combat_unit: CombatUnit) -> void:
	unit = combat_unit
	var mat := PIXEL_MATERIAL.duplicate() as StandardMaterial3D
	mat.albedo_color = unit.data.tint * 1.6
	for mesh in find_children("*", "MeshInstance3D", true, false):
		if mesh.name != "Tusk":
			(mesh as MeshInstance3D).material_override = mat
	refresh()


func refresh() -> void:
	_hp.text = "%d/%d" % [unit.hp, unit.data.max_hp]
	_hp.visible = show_hp and unit.is_alive()
