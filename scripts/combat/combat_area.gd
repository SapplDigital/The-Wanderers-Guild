class_name CombatArea
extends Node3D
## A place in the world where a fight can happen. Nothing is replaced: the real scene is scanned
## into a CombatSpace — collision shapes become obstacles (bodies in group `low_cover` are rocks
## you can see over, everything else blocks), SurfaceAreas "mud"/"water" become terrain regions,
## HighGround nodes become elevation. Enemies graze here before the fight so the player can choose
## to engage or walk around; entering the Trigger starts the encounter where everyone stands.

signal combat_finished(winner: StringName)

const ENEMY_VIEW := preload("res://scenes/combat/enemy_unit.tscn")
const TERRAINS: Array[StringName] = [&"mud", &"water"]

@export var encounter: EncounterData
@export var player_data: ActorData
@export var radius := 9.0 ## metres; units can't leave this circle during the fight
@export var camera_rig: CameraController
@export var player: Player
@export var rng_seed := -1 ## >= 0 makes fights repeatable (debug / tests)

var controller: CombatController
var enemy_views: Array[UnitView] = []
var _came_from := Vector3.LEFT ## direction the player engaged from; defeat wakes them on that side


func _ready() -> void:
	$Trigger.collision_layer = 0
	$Trigger.collision_mask = 2 # actors
	$Trigger.body_entered.connect(func(body: Node3D) -> void:
		if body == player and can_start():
			start.call_deferred())
	if not is_cleared():
		_spawn_idle_enemies.call_deferred()


func cleared_flag() -> String:
	return "encounter.%s.cleared" % encounter.id


func is_cleared() -> bool:
	return GameState.is_set(cleared_flag())


## Only from normal exploration: never under a conversation, a cinematic or another fight.
func can_start() -> bool:
	return controller == null and not is_cleared() and player.input_enabled and not camera_rig.is_cinematic


func build_space() -> CombatSpace:
	var space := CombatSpace.new(global_position, radius)
	var world := get_world_3d().direct_space_state
	var probe := SphereShape3D.new()
	probe.radius = radius + 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = Transform3D(Basis(), global_position + Vector3.UP)
	query.collision_mask = 1 # world bodies
	var seen := {}
	for hit in world.intersect_shape(query, 128):
		var body: Node = hit.collider
		if seen.has(body) or body.is_in_group("high_ground_body"):
			continue
		seen[body] = true
		var kind := CombatSpace.Obstacle.LOW_COVER if body.is_in_group("low_cover") else CombatSpace.Obstacle.BLOCKING
		var label := (body as Node).scene_file_path.get_file().get_basename()
		for shape_node in body.find_children("*", "CollisionShape3D", false, false):
			var r := _footprint_radius(shape_node)
			if r > 0.0:
				space.add_obstacle(shape_node.global_position, r, kind, label if label != "" else "obstacle")
	for area in get_tree().get_nodes_in_group("surface_area"):
		if not StringName(area.surface) in TERRAINS:
			continue
		for shape_node in area.find_children("*", "CollisionShape3D", false, false):
			if shape_node.shape is BoxShape3D:
				space.add_terrain(_box_footprint(shape_node), StringName(area.surface))
	for mound in get_tree().get_nodes_in_group("high_ground"):
		if CombatSpace.flat(mound.global_position).distance_to(CombatSpace.flat(global_position)) < radius + mound.bottom_radius:
			space.add_mound(mound.global_position, mound.top_radius, mound.bottom_radius, mound.height)
	return space


func start() -> void:
	if not can_start():
		return
	var space := build_space()
	var away := CombatSpace.flat(player.global_position - global_position)
	if away.length() > 0.1:
		_came_from = Vector3(away.x, 0, away.y).normalized()
	var units: Array[CombatUnit] = []
	var me := CombatUnit.new(player_data, _standable_near(space, player.global_position, units))
	me.hp = player.health # exploration health carries into the fight
	units.append(me)
	for i in encounter.enemies.size():
		var unit := CombatUnit.new(encounter.enemies[i], _standable_near(space, enemy_views[i].global_position, units))
		units.append(unit)
		enemy_views[i].show_hp = true
		enemy_views[i].bind(unit)
	controller = CombatController.new()
	add_child(controller)
	controller.finished.connect(_on_finished)
	controller.begin(self, space, units)


func view_for(unit: CombatUnit) -> Node3D:
	if unit.team == &"player":
		return player
	for v in enemy_views:
		if v.unit == unit:
			return v
	return null


func _spawn_idle_enemies() -> void:
	for i in encounter.enemies.size():
		var view: UnitView = ENEMY_VIEW.instantiate()
		add_child(view)
		var offset := encounter.enemy_offsets[i]
		view.global_position = global_position + Vector3(offset.x, 0, offset.z)
		view.rotation.y = randf() * TAU
		view.bind(CombatUnit.new(encounter.enemies[i], view.global_position))
		enemy_views.append(view)


## Where a unit actually stands for the rules: its own spot if free, else the nearest free spot.
func _standable_near(space: CombatSpace, p: Vector3, taken: Array[CombatUnit]) -> Vector3:
	var blockers := taken.map(func(u: CombatUnit) -> Vector2: return CombatSpace.flat(u.position))
	var here := CombatSpace.flat(p)
	if space.is_standable(here, blockers):
		return space.ground(here)
	for ring in range(1, 12):
		for i in 12:
			var q := here + Vector2.RIGHT.rotated(TAU * i / 12.0) * ring * 0.4
			if space.is_standable(q, blockers):
				return space.ground(q)
	return space.ground(here)


## Radius of a collision shape's footprint on the ground (scale included). 0 = ignore (ground, hills).
func _footprint_radius(shape_node: CollisionShape3D) -> float:
	var s := shape_node.global_transform.basis.get_scale()
	var shape := shape_node.shape
	if shape is CylinderShape3D:
		return shape.radius * maxf(s.x, s.z)
	if shape is SphereShape3D:
		return shape.radius * maxf(s.x, s.z)
	if shape is CapsuleShape3D:
		return shape.radius * maxf(s.x, s.z)
	if shape is BoxShape3D:
		return Vector2(shape.size.x * s.x, shape.size.z * s.z).length() * 0.5
	return 0.0


func _box_footprint(shape_node: CollisionShape3D) -> PackedVector2Array:
	var half: Vector3 = shape_node.shape.size * 0.5
	var xf := shape_node.global_transform
	var poly := PackedVector2Array()
	for corner in [Vector3(-half.x, 0, -half.z), Vector3(half.x, 0, -half.z), Vector3(half.x, 0, half.z), Vector3(-half.x, 0, half.z)]:
		poly.append(CombatSpace.flat(xf * corner))
	return poly


func _on_finished(winner: StringName) -> void:
	player.health = maxi(controller.player_unit.hp, 1)
	controller.queue_free()
	controller = null
	if winner == &"player":
		GameState.set_flag(cleared_flag())
		get_tree().call_group("hud", "show_message", encounter.victory_message)
	else:
		# Defeat is a setback, not a game over: wake outside the area on the side you came from; the enemies stay.
		player.health = maxi(floori(player.max_health / 3.0), 1)
		player.global_position = global_position + _came_from * (radius + 3.0)
		for i in enemy_views.size():
			var v := enemy_views[i]
			v.show_hp = false
			v.reset_pose()
			var offset := encounter.enemy_offsets[i]
			v.global_position = global_position + Vector3(offset.x, 0, offset.z)
			v.bind(CombatUnit.new(v.unit.data, v.global_position))
		get_tree().call_group("hud", "show_message", encounter.defeat_message)
	combat_finished.emit(winner)
