class_name CombatArena
extends Node3D
## A place where a fight can happen. Maps the real world onto a combat grid (trees and houses
## block, `low_cover` bodies give cover, SurfaceAreas "mud"/"water" set terrain), shows the
## enemies idling before the fight so the player can choose to engage or walk around, and
## starts the encounter when the player enters the Trigger area.

signal combat_finished(winner: StringName)

const ENEMY_VIEW := preload("res://scenes/combat/enemy_unit.tscn")
const TERRAINS: Array[StringName] = [&"mud", &"water"]

@export var encounter: EncounterData
@export var player_data: ActorData
@export var cols := 10
@export var rows := 8
@export var cell_size := 1.5
@export var camera_rig: CameraController
@export var player: Player
@export var rng_seed := -1 ## >= 0 makes fights repeatable (debug / tests)

var controller: CombatController
var enemy_views: Array[UnitView] = []


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


func can_start() -> bool:
	return controller == null and not is_cleared()


func origin() -> Vector3:
	return global_position - Vector3(cols, 0, rows) * cell_size * 0.5


func cell_center(c: Vector2i) -> Vector3:
	return origin() + Vector3((c.x + 0.5) * cell_size, 0.0, (c.y + 0.5) * cell_size)


func world_to_cell(p: Vector3) -> Vector2i:
	var local := (p - origin()) / cell_size
	return Vector2i(floori(local.x), floori(local.z))


func build_grid() -> CombatGrid:
	var grid := CombatGrid.new(Vector2i(cols, rows))
	var space := get_world_3d().direct_space_state
	var probe := BoxShape3D.new()
	probe.size = Vector3(cell_size * 0.7, 1.0, cell_size * 0.7)
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = probe
	shape_query.collision_mask = 1 # world
	var point_query := PhysicsPointQueryParameters3D.new()
	point_query.collide_with_areas = true
	point_query.collide_with_bodies = false
	point_query.collision_mask = 16 # surfaces
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			var center := cell_center(c)
			shape_query.transform = Transform3D(Basis(), center + Vector3.UP * 0.8)
			for hit in space.intersect_shape(shape_query, 8):
				var k := CombatGrid.Kind.COVER if hit.collider.is_in_group("low_cover") else CombatGrid.Kind.BLOCKED
				grid.set_kind(c, maxi(grid.kind(c), k))
			point_query.position = center + Vector3.UP * 0.1
			for hit in space.intersect_point(point_query, 4):
				if hit.collider is SurfaceArea and StringName(hit.collider.surface) in TERRAINS:
					grid.set_terrain(c, StringName(hit.collider.surface))
	return grid


func start() -> void:
	if not can_start():
		return
	var grid := build_grid()
	var units: Array[CombatUnit] = []
	var me := CombatUnit.new(player_data, _nearest_open(grid, world_to_cell(player.global_position), units))
	me.hp = player.health # exploration health carries into the fight
	units.append(me)
	for i in encounter.enemies.size():
		var unit := CombatUnit.new(encounter.enemies[i], _nearest_open(grid, encounter.enemy_cells[i], units))
		units.append(unit)
		enemy_views[i].show_hp = true
		enemy_views[i].bind(unit)
	controller = CombatController.new()
	add_child(controller)
	controller.finished.connect(_on_finished)
	controller.begin(self, grid, units)


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
		view.global_position = cell_center(encounter.enemy_cells[i])
		view.rotation.y = randf() * TAU
		view.bind(CombatUnit.new(encounter.enemies[i], encounter.enemy_cells[i]))
		enemy_views.append(view)


func _nearest_open(grid: CombatGrid, wanted: Vector2i, taken: Array[CombatUnit]) -> Vector2i:
	var best := Vector2i(-1, -1)
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			if grid.kind(c) != CombatGrid.Kind.OPEN or taken.any(func(u: CombatUnit) -> bool: return u.cell == c):
				continue
			if best.x < 0 or CombatGrid.distance(c, wanted) < CombatGrid.distance(best, wanted):
				best = c
	return best


func _on_finished(winner: StringName) -> void:
	player.health = maxi(controller.player_unit.hp, 1)
	controller.queue_free()
	controller = null
	if winner == &"player":
		GameState.set_flag(cleared_flag())
		get_tree().call_group("hud", "show_message", encounter.victory_message)
	else:
		# Defeat is a setback, not a game over: wake at the clearing's edge, the boars stay.
		player.health = maxi(floori(player.max_health / 3.0), 1)
		player.global_position = global_position + Vector3(-(cols * cell_size * 0.5 + 3.0), 0, 0)
		for v in enemy_views:
			v.show_hp = false
			v.show()
			v.scale = Vector3.ONE
			v.bind(CombatUnit.new(v.unit.data, v.unit.cell))
		get_tree().call_group("hud", "show_message", encounter.defeat_message)
	combat_finished.emit(winner)
