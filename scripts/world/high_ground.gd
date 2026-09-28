class_name HighGround
extends Node3D
## A walkable grassy mound. Builds its own mesh and collision from three numbers, and the combat
## rules read the same numbers (CombatSpace.add_mound), so what you see is what the rules use.

const GRASS: Material = preload("res://art/materials/grass.tres")

@export var top_radius := 1.6
@export var bottom_radius := 3.4
@export var height := 1.2


func _ready() -> void:
	add_to_group("high_ground")
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	mesh.material = GRASS
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position.y = height * 0.5
	add_child(view)
	view.create_trimesh_collision()
	# CombatArea models elevation separately, so the generated collision must not
	# also be mistaken for a blocking obstacle during its world scan.
	for child in view.get_children():
		if child is StaticBody3D:
			child.add_to_group("high_ground_body")
