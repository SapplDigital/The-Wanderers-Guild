extends Node
## Integration check: CombatArea must read the real clearing into world-space rules data.
##   godot --headless --path . res://tests/test_combat_world.tscn

const REGION := preload("res://scenes/world/slice_region.tscn")

var _failures := 0


func _ready() -> void:
	add_child(preload("res://scenes/ui/combat_hud.tscn").instantiate()) # main.tscn provides it in the game
	var world: Node3D = REGION.instantiate()
	add_child(world)
	# Let scene _ready/deferred setup and the physics broadphase finish before querying it.
	await get_tree().physics_frame
	await get_tree().physics_frame

	var by_id := {}
	for a in world.find_children("*", "CombatArea"):
		by_id[a.encounter.id] = a
		# Every encounter and actor the region really uses validates (and so does the player's).
		_check(a.encounter.validate().is_empty(), "encounter %s validates %s" % [a.encounter.id, a.encounter.validate()])
		_check(a.player_data != null and a.player_data.validate().is_empty(), "%s: the player's ActorData validates" % a.encounter.id)
	var bad := EncounterData.new()
	bad.id = &"bad"
	bad.enemies = [null]
	_check(bad.validate().size() == 2, "encounter validator catches a missing offset and an empty enemy slot: %s" % bad.validate())
	_check(by_id.has(&"clearing_boars") and by_id.has(&"forest_edge_midges") and by_id.has(&"broken_gate_guardian"),
		"slice region authors the boar, midge and gate-guardian encounters")
	if by_id.size() != 3:
		await _finish(world)
		return
	var area: CombatArea = by_id[&"clearing_boars"]
	var space := area.build_space()
	_check(not space.obstacles.is_empty(), "real collision shapes become combat obstacles")
	_check(space.obstacles.any(func(o: Dictionary) -> bool: return o.kind == CombatSpace.Obstacle.LOW_COVER),
		"clearing rocks are scanned as low cover")
	_check(space.terrain.any(func(t: Dictionary) -> bool: return t.kind == &"mud"), "mud surface becomes a terrain polygon")
	_check(space.terrain.any(func(t: Dictionary) -> bool: return t.kind == &"water"), "stream surface becomes a terrain polygon")
	_check(space.mounds.size() == 1 and is_equal_approx(space.height_at(Vector2(23, -36)), 1.2),
		"visible clearing mound becomes matching combat elevation")
	_check(area.enemy_views.size() == 2, "both visible idle boars spawn")
	var player_distance := CombatSpace.flat(area.player.global_position).distance_to(CombatSpace.flat(area.global_position))
	_check(player_distance > 7.0 and area.can_start() and area.controller == null,
		"combat stays idle while the player is outside the engage trigger")

	# The demonstration creatures stand in the real world, their brains chosen by ActorData alone.
	var midges: CombatArea = by_id[&"forest_edge_midges"]
	var midge_space := midges.build_space()
	_check(midge_space.obstacles.filter(func(o: Dictionary) -> bool: return o.kind == CombatSpace.Obstacle.LOW_COVER).size() >= 3,
		"midge stones are scanned as low cover")
	_check(midge_space.terrain.any(func(t: Dictionary) -> bool: return t.kind == &"mud"), "midge mud becomes terrain")
	_check(midges.enemy_views.size() == 2 and midges.enemy_views.all(func(v: UnitView) -> bool:
		return v.unit.data.ai_brain == RangedUtilityBrain), "two idle midges spawn with the ranged brain from data")
	var gate: CombatArea = by_id[&"broken_gate_guardian"]
	var gate_space := gate.build_space()
	_check(gate.enemy_views.size() == 1 and gate.enemy_views[0].unit.data.ai_brain == GuardianBrain,
		"the gate guardian spawns with the guardian brain from data")
	_check(gate_space.obstacles.any(func(o: Dictionary) -> bool: return o.kind == CombatSpace.Obstacle.LOW_COVER),
		"gate rubble is scanned as cover")
	_check(gate_space.obstacles.any(func(o: Dictionary) -> bool: return o.kind == CombatSpace.Obstacle.BLOCKING),
		"gate pillars are scanned as blocking obstacles")
	var ray := PhysicsRayQueryParameters3D.create(gate.global_position + Vector3(-20, 1, 0), gate.global_position + Vector3(20, 1, 0), 1)
	_check(not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "ruin pillars have walk-blocking collision")
	# Defeat wakes the player on the side they approached from, outside the trigger and clear of pillars.
	gate.player.global_position = gate.global_position + Vector3(0, 0, 6)
	gate.start()
	gate.controller.state.units[0].hp = 0
	gate.controller._finish(&"enemy")
	var woke := gate.player.global_position
	_check(woke.distance_to(gate.global_position) > 7.0 and woke.z > gate.global_position.z,
		"defeat wakes the player outside the trigger on the approach side (%s)" % woke)
	_check(gate.controller == null and gate.can_start(), "after defeat the guardian encounter can be retried")
	for a: CombatArea in by_id.values():
		_check(a.can_start() and a.controller == null, "%s stays optional until the player walks in" % a.encounter.id)
	var gap := func(a: CombatArea, b: CombatArea) -> float: return a.global_position.distance_to(b.global_position)
	_check(gap.call(area, midges) > 2.0 * area.radius + 7.0 and gap.call(midges, gate) > 2.0 * area.radius + 7.0,
		"encounter areas and triggers don't overlap")

	await _finish(world)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAIL: " + what)
	else:
		print("PASS: " + what)


func _finish(world: Node) -> void:
	world.queue_free()
	await get_tree().process_frame
	print("combat world: %s (%d failures)" % ["OK" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)
