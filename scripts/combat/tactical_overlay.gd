class_name TacticalOverlay
extends MeshInstance3D
## Temporary tactical hints drawn as thin lines on the ground (1 px at the 640x360 render):
## movement range, path preview, threat zones, line of attack, targets. Never filled areas.
## Everything is redrawn on demand and fades out when the player isn't deciding.

const SEGMENTS := 56
const LIFT := 0.06 ## above the ground

var space: CombatSpace
var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
var _alpha := 0.0
var _visible_goal := false


func _init() -> void:
	top_level = true
	mesh = _mesh
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = true # hints stay readable over rocks, grass and bodies
	_material.render_priority = 2
	material_override = _material


func _process(delta: float) -> void:
	_alpha = move_toward(_alpha, 1.0 if _visible_goal else 0.0, delta * 4.0)
	_material.albedo_color = Color(1, 1, 1, _alpha)


func fade_in() -> void:
	_visible_goal = true


func fade_out() -> void:
	_visible_goal = false


func begin() -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	# ImmediateMesh can't end an empty surface: start with an invisible degenerate line.
	_mesh.surface_set_color(Color(0, 0, 0, 0))
	_mesh.surface_add_vertex(Vector3.ZERO)
	_mesh.surface_add_vertex(Vector3.ZERO)


func finish() -> void:
	_mesh.surface_end()


func ring(center: Vector3, radius: float, color: Color, dashed := false) -> void:
	var c := CombatSpace.flat(center)
	for i in SEGMENTS:
		if dashed and i % 2 == 1:
			continue
		var a := c + Vector2.RIGHT.rotated(TAU * i / SEGMENTS) * radius
		var b := c + Vector2.RIGHT.rotated(TAU * (i + 1) / SEGMENTS) * radius
		_line(_on_ground(a), _on_ground(b), color)


func polyline(points: Array, color: Color) -> void:
	for i in range(1, points.size()):
		# follow the ground between waypoints so the line hugs slopes
		var a := CombatSpace.flat(points[i - 1])
		var b := CombatSpace.flat(points[i])
		var steps := maxi(1, ceili(a.distance_to(b) / 0.5))
		for k in steps:
			_line(_on_ground(a.lerp(b, float(k) / steps)), _on_ground(a.lerp(b, float(k + 1) / steps)), color)


func marker(at: Vector3, color: Color, size := 0.25) -> void:
	var c := CombatSpace.flat(at)
	_line(_on_ground(c + Vector2(-size, 0)), _on_ground(c + Vector2(size, 0)), color)
	_line(_on_ground(c + Vector2(0, -size)), _on_ground(c + Vector2(0, size)), color)


func _line(a: Vector3, b: Vector3, color: Color) -> void:
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(a)
	_mesh.surface_add_vertex(b)


func _on_ground(p: Vector2) -> Vector3:
	return Vector3(p.x, space.height_at(p) + LIFT, p.y)
