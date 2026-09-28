extends MeshInstance3D
## Blockout helper: builds static trimesh collision from this mesh on load.

func _ready() -> void:
	create_trimesh_collision()
