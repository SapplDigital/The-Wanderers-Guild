class_name GridOverlay
extends MultiMeshInstance3D
## Flat tinted quads over the arena cells (one MultiMesh, colour per cell).

const INSET := 0.9 ## gap between tiles so the grid reads as cells

var _index := {} ## Vector2i -> instance index


func setup(arena: CombatArena) -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * arena.cell_size * INSET
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = 1 # draw after other transparent surfaces (water) so tiles never break up
	quad.material = mat
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = arena.cols * arena.rows
	var i := 0
	for y in arena.rows:
		for x in arena.cols:
			var c := Vector2i(x, y)
			_index[c] = i
			multimesh.set_instance_transform(i, Transform3D(Basis(), arena.cell_center(c) + Vector3.UP * 0.05))
			i += 1
	paint({})


## `colors`: cell -> Color. Cells not listed are hidden.
func paint(colors: Dictionary) -> void:
	for c in _index:
		multimesh.set_instance_color(_index[c], colors.get(c, Color(0, 0, 0, 0)))
