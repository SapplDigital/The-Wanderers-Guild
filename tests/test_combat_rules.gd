extends Node
## System-correctness test for the world-space combat rules (no scene nodes involved):
##   godot --headless --path . res://tests/test_combat_rules.tscn

const WANDERER: ActorData = preload("res://data/actors/wanderer.tres")
const BOAR: ActorData = preload("res://data/actors/thornback_boar.tres")
const MIDGE: ActorData = preload("res://data/actors/glimmer_midge.tres")
const GUARDIAN: ActorData = preload("res://data/actors/ruin_guardian.tres")
const ENCOUNTER: EncounterData = preload("res://data/encounters/clearing_boars.tres")
const DAZZLED: StatusData = preload("res://data/statuses/dazzled.tres")
const COMBAT_SCRIPTS := "res://scripts/combat/"

var _failures := 0


func _ready() -> void:
	_test_no_grid_left()
	_test_data()
	_test_movement()
	_test_terrain()
	_test_sight_cover_elevation()
	_test_resolution()
	_test_action_economy()
	_test_engagement_and_reactions()
	_test_turns_status_outcome()
	_test_brain_dispatcher()
	print("combat rules: %s (%d failures)" % ["OK" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


## The rules must not secretly depend on cells: no Vector2i / "cell" anywhere in the combat code.
func _test_no_grid_left() -> void:
	if not FileAccess.file_exists("res://project.godot"):
		print("SKIP: no grid remnants (an exported pack ships compiled scripts, not source)")
		return
	var files: Array[String] = []
	for dir in [COMBAT_SCRIPTS, COMBAT_SCRIPTS + "ai/", COMBAT_SCRIPTS + "data/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				files.append(dir + f)
	_check(files.size() >= 8, "found the combat scripts (%d)" % files.size())
	for path in files:
		var src := FileAccess.get_file_as_string(path)
		_check(not "Vector2i" in src and not "cell" in src.to_lower(), "no grid remnants in %s" % path.get_file())


func _test_data() -> void:
	_check(WANDERER.abilities.size() == 3 and is_equal_approx(WANDERER.movement, 6.0), "wanderer: 3 abilities, 6 m")
	_check(BOAR.abilities.size() == 1 and BOAR.reaction_ability != null, "boar has gore + reaction")
	_check(BOAR.ai_profile == &"melee_beast" and BOAR.ai_brain != null, "boar selects a brain through data")
	_check(MIDGE.ai_profile == &"ranged_utility" and MIDGE.ai_brain != null, "midge selects ranged utility brain through data")
	_check(GUARDIAN.ai_profile == &"elite_ruin_guardian" and GUARDIAN.ai_brain != null, "guardian selects telegraphed brain through data")
	_check(ENCOUNTER.enemies.size() == 2 and ENCOUNTER.enemy_offsets.size() == 2, "encounter lists 2 boars with offsets")
	_check(is_equal_approx(WANDERER.abilities[1].range_max, 9.0), "flare reaches 9 m")


func _open_space(r := 20.0) -> CombatSpace:
	return CombatSpace.new(Vector3.ZERO, r)


func _test_movement() -> void:
	var s := _open_space()
	var p := s.find_path(Vector3(0, 0, 0), Vector3(2.3, 0, 1.7))
	_check(p.points.size() == 2 and is_equal_approx(p.cost, Vector2(2.3, 1.7).length()), "open ground: straight path, cost = distance (%.3f)" % p.cost)

	s.add_obstacle(Vector3(0, 0, -3), 1.0, CombatSpace.Obstacle.BLOCKING, "trunk")
	p = s.find_path(Vector3(0, 0, 0), Vector3(0, 0, -6))
	_check(p.points.size() > 2 and p.cost > 6.0 and p.cost < 8.5, "obstacle in the way: path walks around it (%.2f m)" % p.cost)
	for i in range(1, p.points.size()):
		_check(s.segment_clear(CombatSpace.flat(p.points[i - 1]), CombatSpace.flat(p.points[i])), "detour segment %d is clear" % i)
	_check(s.find_path(Vector3.ZERO, Vector3(0, 0, -3)).points.is_empty(), "can't stand inside an obstacle")
	_check(not s.is_standable(Vector2(25, 0)), "outside the combat area is not standable")

	var blocker := [Vector2(0, 2)]
	p = s.find_path(Vector3(0, 0, 0), Vector3(0, 0, 4), blocker)
	_check(p.points.size() > 2, "other units block the straight line")

	var t := s.truncate([Vector3(0, 0, 0), Vector3(10, 0, 0)], 3.5)
	_check(t.points.size() == 2 and absf(t.points[1].x - 3.5) < 0.001, "truncate stops at the budget (%.4f)" % t.points[1].x)


func _test_terrain() -> void:
	var s := _open_space()
	s.add_terrain(PackedVector2Array([Vector2(1, -5), Vector2(3, -5), Vector2(3, 5), Vector2(1, 5)]), &"water")
	var c := s.segment_cost(Vector2(0, 0), Vector2(4, 0))
	_check(is_equal_approx(c, 6.0), "2 m of water costs 4 m: 4 m walk costs 6 (%.3f)" % c)
	_check(s.terrain_at(Vector2(2, 0)) == &"water" and s.terrain_defense(Vector2(2, 0)) == -1, "water: bad footing")
	var t := s.truncate([Vector3(0, 0, 0), Vector3(4, 0, 0)], 3.0)
	_check(absf(t.points[1].x - 2.0) < 0.01, "truncate accounts for terrain cost (stops at %.3f)" % t.points[1].x)
	# A cheaper way round exists: water strip 4 m wide but only 2 m long.
	var s2 := _open_space()
	s2.add_terrain(PackedVector2Array([Vector2(1, -1), Vector2(3, -1), Vector2(3, 1), Vector2(1, 1)]), &"mud")
	s2.add_obstacle(Vector3(2, 0, 3), 0.5, CombatSpace.Obstacle.BLOCKING) # gives the pathfinder waypoints nearby
	var p := s2.find_path(Vector3(0, 0, 0), Vector3(4, 0, 0))
	_check(p.cost <= 6.0 + 0.001, "path cost never exceeds walking straight through mud (%.2f)" % p.cost)


func _test_sight_cover_elevation() -> void:
	var s := _open_space()
	s.add_obstacle(Vector3(0, 0, -4), 0.6, CombatSpace.Obstacle.BLOCKING, "tree")
	_check(not s.line_of_sight(Vector3(0, 0, 0), Vector3(0, 0, -8)), "a trunk on the line blocks sight")
	_check(s.line_of_sight(Vector3(2, 0, 0), Vector3(2, 0, -8)), "clear line to the side")
	# brushing past the trunk near the target: cover, not blocked
	_check(s.line_of_sight(Vector3(0.9, 0, 0), Vector3(0.9, 0, -5)) and s.cover_between(Vector3(0.9, 0, 0), Vector3(0.9, 0, -5)) == "tree",
		"line grazing a trunk near the target gives cover")
	var r := _open_space()
	r.add_obstacle(Vector3(0, 0, -6), 0.8, CombatSpace.Obstacle.LOW_COVER, "rock")
	_check(r.line_of_sight(Vector3.ZERO, Vector3(0, 0, -7.5)), "a low rock doesn't block sight")
	_check(r.cover_between(Vector3.ZERO, Vector3(0, 0, -7.5)) == "rock", "…but covers a target right behind it")
	_check(r.cover_between(Vector3(0, 0, -7.5), Vector3.ZERO) == "", "the rock far from the target protects nobody")

	var m := _open_space()
	m.add_mound(Vector3(5, 0, 0), 1.5, 3.0, 1.2)
	_check(is_equal_approx(m.height_at(Vector2(5, 0)), 1.2) and is_equal_approx(m.height_at(Vector2(0, 0)), 0.0), "mound height")
	var top := m.ground(Vector2(5, 0))
	_check(m.has_high_ground(top, Vector3.ZERO) and not m.has_high_ground(Vector3.ZERO, top), "high ground only for the higher unit")
	var state := _fight(m, top, [Vector3(5, 0, 1.6)])
	var pred := state.predict(state.units[0], WANDERER.abilities[0], state.units[1])
	var flat := _fight(_open_space(), Vector3(5, 0, 0), [Vector3(5, 0, 1.6)])
	var pred_flat := flat.predict(flat.units[0], WANDERER.abilities[0], flat.units[1])
	_check(pred.high_ground and pred.chance > pred_flat.chance, "attacking from the mound is easier (%.2f vs %.2f)" % [pred.chance, pred_flat.chance])

	var c := _fight(r, Vector3.ZERO, [Vector3(0, 0, -7.5)])
	var flare: AbilityData = WANDERER.abilities[1]
	var pc := c.predict(c.units[0], flare, c.units[1])
	_check(pc.cover == "rock" and pc.defense == BOAR.defense + CombatSpace.COVER_DEFENSE, "cover raises defense against the flare")
	var melee_pred := c.predict(c.units[0], WANDERER.abilities[0], c.units[1])
	_check(melee_pred.cover == "", "melee ignores cover")


func _test_resolution() -> void:
	_check(is_equal_approx(ActionResolver.hit_chance(4, 11), 0.7), "+4 vs 11 hits 70%")
	_check(is_equal_approx(ActionResolver.hit_chance(20, 5), 0.95), "natural 1 always misses")
	_check(is_equal_approx(ActionResolver.hit_chance(0, 30), 0.05), "natural 20 always hits")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hits := 0
	var crits := 0
	var n := 4000
	for i in n:
		var r := ActionResolver.attack(rng, 4, 11, 8, 2)
		hits += int(r.hit)
		crits += int(r.crit)
	_check(absf(hits / float(n) - 0.7) < 0.03, "observed hit rate matches prediction (%.3f)" % (hits / float(n)))
	_check(absf(crits / float(n) - 0.05) < 0.015, "crit rate ~5%% (%.3f)" % (crits / float(n)))
	# the full pipeline (state.predict vs actual rolls) agrees too
	var state := _fight(_open_space(), Vector3.ZERO, [Vector3(0, 0, 1.5)], 11)
	var me := state.units[0]
	var boar := state.units[1]
	var strike: AbilityData = WANDERER.abilities[0]
	var predicted: float = state.predict(me, strike, boar).chance
	var landed := 0
	for i in n:
		boar.hp = 999
		me.has_action = true
		landed += int(state.use(me, strike, boar)[0].hit)
	_check(absf(landed / float(n) - predicted) < 0.03, "state.predict matches state.use over %d attacks (%.3f vs %.3f)" % [n, landed / float(n), predicted])


func _fight(space: CombatSpace, me_at: Vector3, boars_at: Array, seed_value := 1) -> CombatState:
	var units: Array[CombatUnit] = [CombatUnit.new(WANDERER, me_at)]
	for p in boars_at:
		units.append(CombatUnit.new(BOAR, p))
	var state := CombatState.new(space, units, seed_value)
	for u in units:
		u.begin_turn()
	return state


func _test_action_economy() -> void:
	var state := _fight(_open_space(), Vector3.ZERO, [Vector3(6, 0, 0)])
	var me := state.units[0]
	var boar := state.units[1]
	var strike: AbilityData = WANDERER.abilities[0]
	var flare: AbilityData = WANDERER.abilities[1]
	var step: AbilityData = WANDERER.abilities[2]
	_check(state.use(me, strike, boar).is_empty(), "strike at 6 m is refused")
	_check(boar in state.targets_for(me, flare), "flare reaches 6 m with sight")
	state.use(me, step)
	_check(not me.has_bonus and is_equal_approx(me.movement_left, 9.0) and not me.provokes_reactions, "nimble step: bonus spent, +3 m")
	_check(state.use(me, step).is_empty(), "second bonus action refused")
	var events := state.use(me, flare, boar)
	_check(not me.has_action and events[0].type == "attack", "flare spends the action")
	_check(state.use(me, strike, boar).is_empty(), "no second action")
	events = state.move(me, Vector3(2.5, 0, 1.25))
	_check(me.position.is_equal_approx(Vector3(2.5, 0, 1.25)) and absf(me.movement_left - (9.0 - Vector2(2.5, 1.25).length())) < 0.001,
		"moving spends exactly the walked metres (%.3f left)" % me.movement_left)
	_check(state.plan_move(me, Vector3(-9, 0, 0)).valid == false and state.move(me, Vector3(-9, 0, 0)).is_empty(), "can't move beyond remaining movement")
	_check(state.move(me, Vector3(6, 0, 0)).is_empty(), "can't walk into another unit")


func _test_engagement_and_reactions() -> void:
	# Leaving reach provokes.
	var state := _fight(_open_space(), Vector3(0, 0, 0), [Vector3(1.5, 0, 0)])
	var me := state.units[0]
	var boar := state.units[1]
	var plan := state.plan_move(me, Vector3(-3, 0, 0))
	_check(plan.valid and plan.provokes == [boar], "the preview warns that walking away provokes")
	var events := state.move(me, Vector3(-3, 0, 0))
	var reactions := events.filter(func(e: Dictionary) -> bool: return e.type == "attack" and e.reaction)
	_check(reactions.size() == 1 and reactions[0].user == boar, "leaving reach provokes one opportunity strike")
	var legs := events.filter(func(e: Dictionary) -> bool: return e.type == "move")
	var exit_point: Vector3 = legs[0].points.back()
	_check(absf(exit_point.distance_to(boar.position) - boar.threat_radius) < 0.01, "the strike happens exactly at the edge of reach")
	_check(not boar.has_reaction, "reaction spent")
	_check(state.move(me, Vector3(-3, 0, 2)).filter(func(e: Dictionary) -> bool: return e.type == "attack").is_empty() or not me.is_alive(),
		"a spent reaction doesn't fire again")

	# Moving inside the zone without leaving it: nothing.
	state = _fight(_open_space(), Vector3(0, 0, 0), [Vector3(1.2, 0, 0)])
	events = state.move(state.units[0], Vector3(1.2, 0, 1.0))
	_check(not events.any(func(e: Dictionary) -> bool: return e.type == "attack"), "shuffling around inside reach provokes nothing")

	# Passing through a zone: enters and leaves -> provokes.
	state = _fight(_open_space(), Vector3(-3, 0, 1.0), [Vector3(0, 0, 0)])
	events = state.move(state.units[0], Vector3(3, 0, 1.0))
	_check(events.any(func(e: Dictionary) -> bool: return e.type == "attack" and e.reaction), "running past a boar provokes")

	# Walking by outside the zone: nothing.
	state = _fight(_open_space(), Vector3(-3, 0, 2.5), [Vector3(0, 0, 0)])
	events = state.move(state.units[0], Vector3(3, 0, 2.5))
	_check(not events.any(func(e: Dictionary) -> bool: return e.type == "attack"), "keeping your distance provokes nothing")

	# Nimble Step disengages.
	state = _fight(_open_space(), Vector3(0, 0, 0), [Vector3(1.5, 0, 0)])
	state.use(state.units[0], WANDERER.abilities[2])
	_check(state.plan_move(state.units[0], Vector3(-3, 0, 0)).provokes.is_empty(), "preview: nimble step means no warning")
	events = state.move(state.units[0], Vector3(-3, 0, 0))
	_check(not events.any(func(e: Dictionary) -> bool: return e.type == "attack"), "nimble step avoids the opportunity strike")

	# The player's reaction works the same way against a boar that walks off.
	state = _fight(_open_space(), Vector3(0, 0, 0), [Vector3(1.5, 0, 0)])
	events = state.move(state.units[1], Vector3(5, 0, 0))
	_check(events.any(func(e: Dictionary) -> bool: return e.type == "attack" and e.reaction and e.user == state.units[0]), "the player's reaction fires too")
	_check(not state.units[0].has_reaction, "player's reaction spent")

	# Reactions refresh on your own turn.
	state.units[0].begin_turn()
	_check(state.units[0].has_reaction, "reaction refreshes at the start of your turn")


func _test_turns_status_outcome() -> void:
	var a := _fight(_open_space(), Vector3.ZERO, [Vector3(8, 0, 0), Vector3(-8, 0, 0)], 42)
	var b := _fight(_open_space(), Vector3.ZERO, [Vector3(8, 0, 0), Vector3(-8, 0, 0)], 42)
	_check(a.order.map(func(u: CombatUnit) -> Vector3: return u.position) == b.order.map(func(u: CombatUnit) -> Vector3: return u.position),
		"same seed, same initiative order")

	var state := _fight(_open_space(), Vector3.ZERO, [Vector3(8, 0, 0)], 3)
	var boar := state.units[1]
	boar.add_status(DAZZLED)
	_check(boar.attack_mod() == BOAR.attack_mod - 3, "dazzled: -3 to hit")
	boar.end_turn()
	_check(not boar.has_status(&"dazzled"), "dazzled wears off after the unit's next turn")

	state.start()
	var first := state.current()
	var events := state.end_turn()
	_check(events[0].type == "turn_start" and state.current() != first, "end turn passes to the next unit")
	state.end_turn()
	_check(state.round_number == 2 and state.current() == first, "after everyone acted, round 2 starts")

	boar.hp = 0
	_check(state.outcome() == &"player", "all enemies down = player wins")
	events = state.end_turn()
	_check(events[0].type == "combat_end" and events[0].winner == &"player", "victory ends combat")

	var lost := _fight(_open_space(), Vector3.ZERO, [Vector3(8, 0, 0)], 3)
	lost.start()
	lost.units[0].hp = 0
	events = lost.end_turn()
	_check(events[0].type == "combat_end" and events[0].winner == &"enemy", "defeat ends combat")
	_check(lost.blockers_for(lost.units[1]).is_empty(), "the fallen don't block movement")


func _test_brain_dispatcher() -> void:
	var state := _fight(_open_space(), Vector3(0, 0, 0), [Vector3(5, 0, 0)], 5)
	var boar := state.units[1]
	var events := BrainDispatcher.take_turn(state, boar)
	_check(state.distance(boar, state.units[0]) <= BOAR.abilities[0].range_max + 0.01, "dispatcher's melee brain closes to melee (%.2f m)" % state.distance(boar, state.units[0]))
	_check(events.any(func(e: Dictionary) -> bool: return e.type == "attack"), "dispatcher resolves the melee brain's attack intent")

	# A wide stream between them: the boar pays for the water and can't reach this turn.
	var s := _open_space()
	s.add_terrain(PackedVector2Array([Vector2(1, -10), Vector2(3.5, -10), Vector2(3.5, 10), Vector2(1, 10)]), &"water")
	state = _fight(s, Vector3(0, 0, 0), [Vector3(6, 0, 0)], 5)
	boar = state.units[1]
	events = BrainDispatcher.take_turn(state, boar)
	_check(boar.movement_left >= -0.001 and not events.any(func(e: Dictionary) -> bool: return e.type == "attack"),
		"the stream slows the boar: no attack this turn (at x=%.2f)" % boar.position.x)
	_check(boar.position.x < 6.0, "…but it still wades in")

	# Profile labels are descriptive data, not a dispatcher switch: a future label can reuse a brain.
	var future_data := BOAR.duplicate() as ActorData
	future_data.ai_profile = &"territorial_future_creature"
	var future := CombatUnit.new(future_data, Vector3(5, 0, 0))
	state = CombatState.new(_open_space(), [CombatUnit.new(WANDERER, Vector3.ZERO), future], 5)
	for unit in state.units:
		unit.begin_turn()
	events = BrainDispatcher.take_turn(state, future)
	_check(events.any(func(e: Dictionary) -> bool: return e.type == "attack"), "arbitrary future profile uses its configured brain")

	# Actors without a combat brain intentionally wait; the dispatcher does not impose hostility.
	var passive_data := BOAR.duplicate() as ActorData
	passive_data.ai_profile = &"social_noncombatant"
	passive_data.ai_brain = null
	var passive := CombatUnit.new(passive_data, Vector3(5, 0, 0))
	state = CombatState.new(_open_space(), [CombatUnit.new(WANDERER, Vector3.ZERO), passive], 5)
	for unit in state.units:
		unit.begin_turn()
	_check(BrainDispatcher.take_turn(state, passive).is_empty() and passive.position.is_equal_approx(Vector3(5, 0, 0)),
		"actor with no combat brain waits safely")

	# Ranged utility samples firing positions and favours cover between itself and its target.
	var ranged_space := _open_space()
	ranged_space.add_obstacle(Vector3(4.6, 0, 0), 0.7, CombatSpace.Obstacle.LOW_COVER, "rock")
	var midge := CombatUnit.new(MIDGE, Vector3(4, 0, 1))
	state = CombatState.new(ranged_space, [CombatUnit.new(WANDERER, Vector3.ZERO), midge], 8)
	for unit in state.units:
		unit.begin_turn()
	events = BrainDispatcher.take_turn(state, midge)
	_check(events.any(func(e: Dictionary) -> bool: return e.type == "attack") and state.distance(midge, state.units[0]) >= MIDGE.abilities[0].range_min,
		"ranged utility brain keeps firing distance and attacks")
	_check(ranged_space.cover_between(state.units[0].position, midge.position) == "rock", "ranged utility brain chooses low-cover firing position")

	# A guardian declares its heavy attack, then follows through next turn through the dispatcher.
	var guardian := CombatUnit.new(GUARDIAN, Vector3(1.5, 0, 0))
	state = CombatState.new(_open_space(), [CombatUnit.new(WANDERER, Vector3.ZERO), guardian], 9)
	for unit in state.units:
		unit.begin_turn()
	events = BrainDispatcher.take_turn(state, guardian)
	_check(events.size() == 1 and events[0].type == "telegraph" and guardian.brain_memory.has(&"guardian_heavy_strike"),
		"guardian declares a visible heavy strike before using it")
	_check(is_equal_approx(guardian.telegraph_radius, GUARDIAN.abilities[0].range_max), "telegraph exposes the danger reach for the overlay")
	guardian.begin_turn()
	events = BrainDispatcher.take_turn(state, guardian)
	_check(events.any(func(e: Dictionary) -> bool: return e.type == "attack") and not guardian.brain_memory.has(&"guardian_heavy_strike"),
		"guardian follows through and clears its telegraph after the attack")
	_check(guardian.telegraph_radius == 0.0, "the danger ring disappears after the blow")

	# The positional answer: stepping out of reach after the telegraph means no blow this turn.
	guardian = CombatUnit.new(GUARDIAN, Vector3(1.5, 0, 0))
	state = CombatState.new(_open_space(), [CombatUnit.new(WANDERER, Vector3.ZERO), guardian], 9)
	for unit in state.units:
		unit.begin_turn()
	BrainDispatcher.take_turn(state, guardian)
	state.units[0].position = Vector3(-6, 0, 0)
	guardian.begin_turn()
	events = BrainDispatcher.take_turn(state, guardian)
	_check(not events.any(func(e: Dictionary) -> bool: return e.type == "attack") and guardian.telegraph_radius > 0.0,
		"stepping out of the telegraphed reach dodges the blow; the guardian lumbers after you, still wound up")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAIL: " + what)
