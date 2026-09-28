extends Node
## System-correctness test for the combat rules (no scene nodes involved):
##   godot --headless --path . res://tests/test_combat_rules.tscn

const WANDERER: ActorData = preload("res://data/actors/wanderer.tres")
const BOAR: ActorData = preload("res://data/actors/thornback_boar.tres")
const ENCOUNTER: EncounterData = preload("res://data/encounters/clearing_boars.tres")
const DAZZLED: StatusData = preload("res://data/statuses/dazzled.tres")

var _failures := 0


func _ready() -> void:
	_test_data()
	_test_grid()
	_test_resolution()
	_test_action_economy()
	_test_reactions()
	_test_turns_and_status()
	_test_brain()
	print("combat rules: %s (%d failures)" % ["OK" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _test_data() -> void:
	_check(WANDERER.abilities.size() == 3, "wanderer has 3 abilities (typed array loaded)")
	_check(BOAR.abilities.size() == 1 and BOAR.reaction_ability != null, "boar has gore + reaction")
	_check(ENCOUNTER.enemies.size() == 2 and ENCOUNTER.enemy_cells.size() == 2, "encounter lists 2 boars")
	_check(WANDERER.abilities[1].applies_status == DAZZLED, "flare applies dazzled")


func _test_grid() -> void:
	var g := CombatGrid.new(Vector2i(5, 5))
	var flood := g.reachable(Vector2i(0, 0), 2)
	_check(flood.cost.size() == 6, "budget 2 reaches 6 cells on open ground (got %d)" % flood.cost.size())
	g.set_terrain(Vector2i(1, 0), &"mud")
	flood = g.reachable(Vector2i(0, 0), 2)
	_check(flood.cost.get(Vector2i(1, 0)) == 2 and not flood.cost.has(Vector2i(2, 0)), "mud costs 2")
	g.set_kind(Vector2i(0, 1), CombatGrid.Kind.BLOCKED)
	flood = g.reachable(Vector2i(0, 0), 3)
	_check(not flood.cost.has(Vector2i(0, 1)), "blocked cells are not reachable")
	var open := CombatGrid.new(Vector2i(6, 6))
	var path := CombatGrid.path_to(open.reachable(Vector2i(0, 0), 10), Vector2i(3, 2))
	_check(path.size() == 5 and path.back() == Vector2i(3, 2), "path length = manhattan distance")

	var los := CombatGrid.new(Vector2i(7, 3))
	los.set_kind(Vector2i(3, 1), CombatGrid.Kind.BLOCKED)
	_check(not los.has_line_of_sight(Vector2i(0, 1), Vector2i(6, 1)), "blocked cell breaks line of sight")
	los.set_kind(Vector2i(3, 1), CombatGrid.Kind.COVER)
	_check(los.has_line_of_sight(Vector2i(0, 1), Vector2i(6, 1)), "low cover does not break sight")
	_check(not los.has_cover(Vector2i(0, 1), Vector2i(6, 1)), "cover far from the target doesn't count")
	los.set_kind(Vector2i(5, 1), CombatGrid.Kind.COVER)
	_check(los.has_cover(Vector2i(0, 1), Vector2i(6, 1)), "cover next to the target counts")


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
		if r.hit and not r.crit and (r.damage < 3 or r.damage > 10):
			_check(false, "normal damage within 1d8+2")
	_check(absf(hits / float(n) - 0.7) < 0.03, "observed hit rate matches prediction (%.3f)" % (hits / float(n)))
	_check(absf(crits / float(n) - 0.05) < 0.015, "crit rate ~5%% (%.3f)" % (crits / float(n)))


func _fight(player_cell: Vector2i, boar_cells: Array[Vector2i], seed_value := 1) -> CombatState:
	var units: Array[CombatUnit] = [CombatUnit.new(WANDERER, player_cell)]
	for c in boar_cells:
		units.append(CombatUnit.new(BOAR, c))
	var state := CombatState.new(CombatGrid.new(Vector2i(10, 8)), units, seed_value)
	for u in units:
		u.begin_turn()
	return state


func _test_action_economy() -> void:
	var state := _fight(Vector2i(1, 4), [Vector2i(5, 4)])
	var me := state.units[0]
	var boar := state.units[1]
	var strike: AbilityData = WANDERER.abilities[0]
	var flare: AbilityData = WANDERER.abilities[1]
	var step: AbilityData = WANDERER.abilities[2]
	_check(state.use(me, strike, boar).is_empty(), "strike out of range is refused")
	_check(boar in state.targets_for(me, flare), "flare reaches 4 cells with sight")
	state.use(me, step)
	_check(not me.has_bonus and me.movement_left == 7 and not me.provokes_reactions, "nimble step: bonus spent, +2 move")
	_check(state.use(me, step).is_empty(), "second bonus action refused")
	var events := state.use(me, flare, boar)
	_check(not me.has_action and events.size() >= 1 and events[0].type == "attack", "flare spends the action")
	_check(state.use(me, strike, boar).is_empty(), "no second action")
	state.move(me, Vector2i(3, 4))
	_check(me.cell == Vector2i(3, 4) and me.movement_left == 5, "moving spends movement")
	_check(state.move(me, Vector2i(9, 0)).is_empty(), "can't move beyond remaining movement")


func _test_reactions() -> void:
	var state := _fight(Vector2i(4, 4), [Vector2i(5, 4)])
	var me := state.units[0]
	var boar := state.units[1]
	var events := state.move(me, Vector2i(2, 4))
	var reaction := events.filter(func(e: Dictionary) -> bool: return e.type == "attack" and e.reaction)
	_check(reaction.size() == 1 and reaction[0].user == boar, "leaving reach provokes one opportunity strike")
	_check(not boar.has_reaction, "reaction spent")

	state = _fight(Vector2i(4, 4), [Vector2i(5, 4)])
	me = state.units[0]
	state.use(me, WANDERER.abilities[2])
	events = state.move(me, Vector2i(2, 4))
	_check(not events.any(func(e: Dictionary) -> bool: return e.type == "attack"), "nimble step avoids the opportunity strike")

	state = _fight(Vector2i(4, 4), [Vector2i(6, 4)])
	events = state.move(state.units[0], Vector2i(4, 1))
	_check(not events.any(func(e: Dictionary) -> bool: return e.type == "attack"), "moving while not adjacent provokes nothing")


func _test_turns_and_status() -> void:
	var a := _fight(Vector2i(1, 1), [Vector2i(8, 1), Vector2i(8, 6)], 42)
	var b := _fight(Vector2i(1, 1), [Vector2i(8, 1), Vector2i(8, 6)], 42)
	var names_a := a.order.map(func(u: CombatUnit) -> Vector2i: return u.cell)
	var names_b := b.order.map(func(u: CombatUnit) -> Vector2i: return u.cell)
	_check(names_a == names_b, "same seed, same initiative order")

	var state := _fight(Vector2i(1, 1), [Vector2i(8, 1)], 3)
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
	state.grid.occupant.erase(boar.cell)
	_check(state.outcome() == &"player", "all enemies down = player wins")
	events = state.end_turn()
	_check(events[0].type == "combat_end" and events[0].winner == &"player", "end turn reports the end of combat")


func _test_brain() -> void:
	var state := _fight(Vector2i(1, 4), [Vector2i(6, 4)], 5)
	var boar := state.units[1]
	var events := BasicBrain.take_turn(state, boar)
	_check(CombatGrid.distance(boar.cell, state.units[0].cell) == 1, "boar closes to melee (at %s)" % boar.cell)
	_check(events.any(func(e: Dictionary) -> bool: return e.type == "attack"), "boar attacks after closing in")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAIL: " + what)
