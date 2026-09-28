class_name CombatSpace
extends RefCounted
## The fight's piece of the world, reduced to what the rules need: obstacles (circles on the
## ground plane), terrain regions (polygons), elevation (mounds) and the area boundary.
## Movement, paths, line of sight, cover and threat-zone exits are all computed here in world
## space (metres). Pure logic, no scene nodes — built by CombatArea, tested headless.

enum Obstacle { BLOCKING, LOW_COVER } ## BLOCKING: trunks, boulders, walls. LOW_COVER: rocks you can see over.

const UNIT_RADIUS := 0.45 ## body clearance used for movement
const TERRAIN_COST := {&"mud": 2.0, &"water": 2.0} ## metres of movement per metre walked
const TERRAIN_DEFENSE := {&"water": -1} ## bad footing
const COVER_DEFENSE := 2
const COVER_REACH := 2.5 ## an obstacle protects a target only if it is this close to it
const TRUNK_GRAZE := 0.45 ## passing this close to a blocking obstacle gives cover instead of blocking
const HIGH_GROUND_HEIGHT := 1.0
const HIGH_GROUND_BONUS := 2
const WAYPOINTS_PER_OBSTACLE := 8
const EPS := 0.001

var center: Vector2
var radius: float
var obstacles: Array[Dictionary] = [] ## {pos: Vector2, radius: float, kind: Obstacle, label: String}
var terrain: Array[Dictionary] = [] ## {polygon: PackedVector2Array, kind: StringName}
var mounds: Array[Dictionary] = [] ## {pos: Vector2, top: float, bottom: float, height: float}


func _init(area_center: Vector3, area_radius: float) -> void:
	center = flat(area_center)
	radius = area_radius


static func flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func add_obstacle(pos: Vector3, r: float, kind: Obstacle, label := "") -> void:
	obstacles.append({"pos": flat(pos), "radius": r, "kind": kind, "label": label})


func add_terrain(polygon: PackedVector2Array, kind: StringName) -> void:
	terrain.append({"polygon": polygon, "kind": kind})


func add_mound(pos: Vector3, top_radius: float, bottom_radius: float, height: float) -> void:
	mounds.append({"pos": flat(pos), "top": top_radius, "bottom": bottom_radius, "height": height})


# ---------------------------------------------------------------- ground

func height_at(p: Vector2) -> float:
	var h := 0.0
	for m in mounds:
		var d := p.distance_to(m.pos)
		if d <= m.top:
			h = maxf(h, m.height)
		elif d < m.bottom:
			h = maxf(h, m.height * (m.bottom - d) / (m.bottom - m.top))
	return h


func ground(p: Vector2) -> Vector3:
	return Vector3(p.x, height_at(p), p.y)


func terrain_at(p: Vector2) -> StringName:
	for t in terrain:
		if Geometry2D.is_point_in_polygon(p, t.polygon):
			return t.kind
	return &""


func terrain_defense(p: Vector2) -> int:
	return TERRAIN_DEFENSE.get(terrain_at(p), 0)


## A unit could stand here: inside the area, not inside an obstacle, not on another unit.
func is_standable(p: Vector2, blockers: Array = []) -> bool:
	if p.distance_to(center) > radius - UNIT_RADIUS:
		return false
	for o in obstacles:
		if p.distance_to(o.pos) < o.radius + UNIT_RADIUS - EPS:
			return false
	for b in blockers:
		if p.distance_to(b) < UNIT_RADIUS * 2.0 - EPS:
			return false
	return true


# ---------------------------------------------------------------- movement

## Metres of movement a straight walk costs: its length plus the terrain surcharge inside mud/water.
func segment_cost(a: Vector2, b: Vector2) -> float:
	var cost := a.distance_to(b)
	for t in terrain:
		var extra: float = TERRAIN_COST.get(t.kind, 1.0) - 1.0
		if extra <= 0.0:
			continue
		for part in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), t.polygon):
			for i in part.size() - 1:
				cost += extra * part[i].distance_to(part[i + 1])
	return cost


func segment_clear(a: Vector2, b: Vector2, blockers: Array = []) -> bool:
	for o in obstacles:
		if _segment_distance(o.pos, a, b) < o.radius + UNIT_RADIUS - EPS:
			return false
	for u in blockers:
		if _segment_distance(u, a, b) < UNIT_RADIUS * 2.0 - EPS:
			return false
	return true


## Cheapest walk from `from` to `to` around obstacles and other units (`blockers`: Vector2 positions).
## Returns {"points": Array[Vector3] (start included), "cost": float}; empty points if impossible.
## Visibility graph over waypoints placed around every obstacle and unit, Dijkstra on segment_cost.
## ponytail: O(n^2) visibility checks per query; fine for a clearing (~10 obstacles), add a cached
## static graph or a navmesh if arenas grow large.
func find_path(from: Vector3, to: Vector3, blockers: Array = []) -> Dictionary:
	var a := flat(from)
	var b := flat(to)
	if not is_standable(b, blockers):
		return {"points": [], "cost": INF}
	if segment_clear(a, b, blockers):
		return {"points": [ground(a), ground(b)], "cost": segment_cost(a, b)}

	var nodes: Array[Vector2] = [a, b]
	var circles: Array = []
	for o in obstacles:
		circles.append([o.pos, o.radius + UNIT_RADIUS])
	for u in blockers:
		circles.append([u, UNIT_RADIUS * 2.0])
	for c in circles:
		var r: float = c[1] + 0.08
		for i in WAYPOINTS_PER_OBSTACLE:
			var p: Vector2 = c[0] + Vector2.RIGHT.rotated(TAU * i / WAYPOINTS_PER_OBSTACLE) * r / cos(PI / WAYPOINTS_PER_OBSTACLE)
			if is_standable(p, blockers):
				nodes.append(p)

	var dist := {0: 0.0}
	var prev := {}
	var open := [0]
	var closed := {}
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if dist[open[i]] < dist[open[best]]:
				best = i
		var cur: int = open.pop_at(best)
		if cur == 1:
			break
		closed[cur] = true
		for n in nodes.size():
			if closed.has(n) or n == cur:
				continue
			if not segment_clear(nodes[cur], nodes[n], blockers):
				continue
			var d: float = dist[cur] + segment_cost(nodes[cur], nodes[n])
			if d < dist.get(n, INF):
				if not dist.has(n):
					open.append(n)
				dist[n] = d
				prev[n] = cur
	if not dist.has(1):
		return {"points": [], "cost": INF}
	var points: Array[Vector3] = []
	var k := 1
	while k != 0:
		points.push_front(ground(nodes[k]))
		k = prev[k]
	points.push_front(ground(a))
	return {"points": points, "cost": dist[1]}


## The part of a path that fits in `budget` metres of movement (same cost rule as segment_cost).
func truncate(points: Array, budget: float) -> Dictionary:
	var out: Array[Vector3] = []
	if points.is_empty():
		return {"points": out, "cost": 0.0}
	out.append(points[0])
	var spent := 0.0
	for i in range(1, points.size()):
		var a := flat(points[i - 1])
		var b := flat(points[i])
		var c := segment_cost(a, b)
		if spent + c <= budget + EPS:
			spent += c
			out.append(points[i])
			continue
		var lo := 0.0
		var hi := 1.0
		for _j in 16: # terrain makes cost non-linear along the segment: bisect
			var mid := (lo + hi) * 0.5
			if spent + segment_cost(a, a.lerp(b, mid)) <= budget:
				lo = mid
			else:
				hi = mid
		var end := a.lerp(b, lo)
		if lo > 0.0:
			spent += segment_cost(a, end)
			out.append(ground(end))
		break
	return {"points": out, "cost": spent}


## Points along the path where it leaves the circle (centre, r): each is {"distance": metres along
## the path, "point": Vector3, "index": segment index}. Used for engagement/reaction zones.
func zone_exits(points: Array, zone_center: Vector3, r: float) -> Array[Dictionary]:
	var exits: Array[Dictionary] = []
	var c := flat(zone_center)
	var walked := 0.0
	for i in range(1, points.size()):
		var a := flat(points[i - 1])
		var b := flat(points[i])
		var seg := b - a
		var length := seg.length()
		if length < EPS:
			continue
		# |a + t*seg - c| = r  ->  quadratic in t
		var f := a - c
		var qa := seg.dot(seg)
		var qb := 2.0 * f.dot(seg)
		var qc := f.dot(f) - r * r
		var disc := qb * qb - 4.0 * qa * qc
		if disc > 0.0:
			var t_out := (-qb + sqrt(disc)) / (2.0 * qa)
			var t_in := (-qb - sqrt(disc)) / (2.0 * qa)
			# exits when the far intersection lies on the segment and we were inside just before it
			if t_out > EPS and t_out <= 1.0 and t_in < t_out:
				var p := a + seg * t_out
				exits.append({"distance": walked + length * t_out, "point": ground(p), "index": i})
		walked += length
	return exits


# ---------------------------------------------------------------- sight and cover

func line_of_sight(from: Vector3, to: Vector3) -> bool:
	return sight_blocker(from, to) == ""


## Label of the first solid obstacle on the line ("" if the line is clear).
func sight_blocker(from: Vector3, to: Vector3) -> String:
	var a := flat(from)
	var b := flat(to)
	for o in obstacles:
		if o.kind == Obstacle.BLOCKING and _segment_distance(o.pos, a, b) < o.radius:
			return o.label if o.label != "" else "obstacle"
	return ""


## Label of the obstacle that shields `target` from `attacker` ("" if none). Only obstacles close to
## the target count: low rocks the line passes through, or trunks the line brushes past.
func cover_between(attacker: Vector3, target: Vector3) -> String:
	var a := flat(attacker)
	var b := flat(target)
	for o in obstacles:
		if b.distance_to(o.pos) - o.radius > COVER_REACH:
			continue
		var d := _segment_distance(o.pos, a, b)
		if o.kind == Obstacle.LOW_COVER and d < o.radius:
			return o.label
		if o.kind == Obstacle.BLOCKING and d >= o.radius and d < o.radius + TRUNK_GRAZE:
			return o.label
	return ""


func has_high_ground(attacker: Vector3, target: Vector3) -> bool:
	return attacker.y - target.y >= HIGH_GROUND_HEIGHT


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
