class_name CombatGrid
extends RefCounted
## Square combat grid: cell kinds, terrain, occupancy, 4-way movement ranges/paths,
## line of sight and cover. Pure data + algorithms, no scene nodes (tested headless).

enum Kind { OPEN, COVER, BLOCKED } ## COVER blocks movement but not sight; BLOCKED blocks both

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const TERRAIN_COST := {&"mud": 2, &"water": 2}
const TERRAIN_DEFENSE := {&"water": -1} ## bad footing
const COVER_DEFENSE := 2

var size: Vector2i
var occupant := {} ## Vector2i -> CombatUnit
var _kind := {} ## Vector2i -> Kind (missing = OPEN)
var _terrain := {} ## Vector2i -> StringName (missing = plain ground)


func _init(grid_size: Vector2i) -> void:
	size = grid_size


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func set_kind(c: Vector2i, k: Kind) -> void:
	_kind[c] = k


func kind(c: Vector2i) -> Kind:
	return _kind.get(c, Kind.OPEN)


func set_terrain(c: Vector2i, t: StringName) -> void:
	_terrain[c] = t


func terrain(c: Vector2i) -> StringName:
	return _terrain.get(c, &"")


func move_cost(c: Vector2i) -> int:
	return TERRAIN_COST.get(terrain(c), 1)


func terrain_defense(c: Vector2i) -> int:
	return TERRAIN_DEFENSE.get(terrain(c), 0)


func is_passable(c: Vector2i, mover: Object = null) -> bool:
	return in_bounds(c) and kind(c) == Kind.OPEN and (not occupant.has(c) or occupant[c] == mover)


static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Dijkstra flood from `start` within `budget` movement points.
## Returns {"cost": {cell: int}, "came_from": {cell: cell}}. Units block cells (no passing through).
## ponytail: linear-scan priority queue; fine for ~100-cell arenas, use a heap if grids get large.
func reachable(start: Vector2i, budget: int, mover: Object = null) -> Dictionary:
	var cost := {start: 0}
	var came_from := {start: start}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var best := 0
		for i in frontier.size():
			if cost[frontier[i]] < cost[frontier[best]]:
				best = i
		var current: Vector2i = frontier.pop_at(best)
		for d in DIRS:
			var next := current + d
			if not is_passable(next, mover):
				continue
			var c: int = cost[current] + move_cost(next)
			if c <= budget and c < cost.get(next, 1 << 30):
				cost[next] = c
				came_from[next] = current
				frontier.append(next)
	return {"cost": cost, "came_from": came_from}


## Cells from the flood's start to `target` (start excluded). Empty if unreachable.
static func path_to(flood: Dictionary, target: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not flood.came_from.has(target):
		return path
	var c := target
	while flood.came_from[c] != c:
		path.push_front(c)
		c = flood.came_from[c]
	return path


## Cells the straight line between two cell centres passes through (endpoints excluded).
## ponytail: sampled line, not an exact supercover; can miss corner-grazing cells.
func cells_between(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y)) * 4
	for i in range(1, steps):
		var p := Vector2(a).lerp(Vector2(b), float(i) / steps).round()
		var c := Vector2i(p)
		if c != a and c != b and not c in result:
			result.append(c)
	return result


func has_line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	for c in cells_between(a, b):
		if kind(c) == Kind.BLOCKED:
			return false
	return true


## True when a low obstacle next to the target sits on the line from the attacker.
func has_cover(attacker: Vector2i, target: Vector2i) -> bool:
	for c in cells_between(attacker, target):
		if kind(c) == Kind.COVER and distance(c, target) == 1:
			return true
	return false
