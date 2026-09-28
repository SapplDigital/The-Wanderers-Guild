class_name CombatState
extends RefCounted
## The rules of one fight (turn order + action economy + resolution), with no presentation.
## Commands return an event log (Array of Dictionaries) that the view plays back:
##   {type: "turn_start", unit}          {type: "step", unit, cell}
##   {type: "attack", user, target, ability, roll, total, defense, hit, crit, damage, cover, reaction}
##   {type: "buff", unit, ability}       {type: "defeated", unit}
##   {type: "combat_end", winner}        (winner: &"player" or &"enemy")

var grid: CombatGrid
var units: Array[CombatUnit] = []
var order: Array[CombatUnit] = [] ## initiative order, fixed for the fight
var round_number := 1
var rng := RandomNumberGenerator.new()
var _turn := 0


func _init(combat_grid: CombatGrid, combatants: Array[CombatUnit], seed_value: int = -1) -> void:
	grid = combat_grid
	units = combatants
	if seed_value >= 0:
		rng.seed = seed_value
	for u in units:
		grid.occupant[u.cell] = u
		u.initiative = rng.randi_range(1, 20) + u.data.initiative_mod
	# Ties: higher initiative modifier first, then the original listing order (deterministic).
	order = units.duplicate()
	order.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
		if a.initiative != b.initiative:
			return a.initiative > b.initiative
		if a.data.initiative_mod != b.data.initiative_mod:
			return a.data.initiative_mod > b.data.initiative_mod
		return units.find(a) < units.find(b))


func start() -> Array:
	current().begin_turn()
	return [{"type": "turn_start", "unit": current()}]


func current() -> CombatUnit:
	return order[_turn]


func foes_of(unit: CombatUnit) -> Array:
	return units.filter(func(u: CombatUnit) -> bool: return u.team != unit.team and u.is_alive())


func reachable_for(unit: CombatUnit) -> Dictionary:
	return grid.reachable(unit.cell, unit.movement_left, unit)


## Moves along the cheapest path. Leaving a foe's reach provokes its reaction (opportunity strike).
func move(unit: CombatUnit, target: Vector2i) -> Array:
	var flood := reachable_for(unit)
	if target == unit.cell or not flood.cost.has(target):
		return []
	var events: Array = []
	for step in CombatGrid.path_to(flood, target):
		if unit.provokes_reactions:
			for foe in foes_of(unit):
				if foe.has_reaction and CombatGrid.distance(foe.cell, unit.cell) == 1 and CombatGrid.distance(foe.cell, step) > 1:
					foe.has_reaction = false
					events.append_array(_resolve_attack(foe, foe.data.reaction_ability, unit, true))
					if not unit.is_alive():
						return events
		grid.occupant.erase(unit.cell)
		unit.cell = step
		grid.occupant[step] = unit
		unit.movement_left -= grid.move_cost(step)
		events.append({"type": "step", "unit": unit, "cell": step})
	return events


func can_use(unit: CombatUnit, ability: AbilityData) -> bool:
	match ability.cost:
		AbilityData.Cost.ACTION: return unit.has_action
		AbilityData.Cost.BONUS: return unit.has_bonus
	return false


func in_range(from: Vector2i, to: Vector2i, ability: AbilityData) -> bool:
	var d := CombatGrid.distance(from, to)
	return d >= ability.range_min and d <= ability.range_max \
		and (not ability.needs_line_of_sight or grid.has_line_of_sight(from, to))


func targets_for(unit: CombatUnit, ability: AbilityData) -> Array:
	if ability.kind != AbilityData.Kind.ATTACK:
		return []
	return foes_of(unit).filter(func(f: CombatUnit) -> bool: return in_range(unit.cell, f.cell, ability))


func use(unit: CombatUnit, ability: AbilityData, target: CombatUnit = null) -> Array:
	if not can_use(unit, ability):
		return []
	if ability.kind == AbilityData.Kind.ATTACK and not (target in targets_for(unit, ability)):
		return []
	if ability.cost == AbilityData.Cost.ACTION:
		unit.has_action = false
	else:
		unit.has_bonus = false
	if ability.kind == AbilityData.Kind.SELF_BUFF:
		unit.movement_left += ability.extra_movement
		if ability.prevents_reactions:
			unit.provokes_reactions = false
		return [{"type": "buff", "unit": unit, "ability": ability}]
	return _resolve_attack(unit, ability, target, false)


## What the UI shows before committing: same numbers the resolver will use.
func predict(user: CombatUnit, ability: AbilityData, target: CombatUnit) -> Dictionary:
	var cover := _cover_applies(user, ability, target)
	var defense := _defense_against(user, ability, target)
	return {
		"chance": ActionResolver.hit_chance(user.attack_mod() + ability.attack_bonus, defense),
		"damage": ActionResolver.damage_range(ability.damage_die, ability.damage_bonus),
		"cover": cover,
		"defense": defense,
	}


func end_turn() -> Array:
	var events: Array = []
	current().end_turn()
	var winner := outcome()
	if winner != &"":
		return [{"type": "combat_end", "winner": winner}]
	for i in order.size():
		_turn = (_turn + 1) % order.size()
		if _turn == 0:
			round_number += 1
		if current().is_alive():
			break
	current().begin_turn()
	events.append({"type": "turn_start", "unit": current()})
	return events


func outcome() -> StringName:
	var player_alive := units.any(func(u: CombatUnit) -> bool: return u.team == &"player" and u.is_alive())
	var enemy_alive := units.any(func(u: CombatUnit) -> bool: return u.team != &"player" and u.is_alive())
	if not enemy_alive:
		return &"player"
	if not player_alive:
		return &"enemy"
	return &""


func _cover_applies(user: CombatUnit, ability: AbilityData, target: CombatUnit) -> bool:
	return ability.range_max > 1 and grid.has_cover(user.cell, target.cell)


func _defense_against(user: CombatUnit, ability: AbilityData, target: CombatUnit) -> int:
	var cover_bonus := CombatGrid.COVER_DEFENSE if _cover_applies(user, ability, target) else 0
	return target.defense() + cover_bonus + grid.terrain_defense(target.cell)


func _resolve_attack(user: CombatUnit, ability: AbilityData, target: CombatUnit, is_reaction: bool) -> Array:
	var result := ActionResolver.attack(rng, user.attack_mod() + ability.attack_bonus,
		_defense_against(user, ability, target), ability.damage_die, ability.damage_bonus)
	result.merge({"type": "attack", "user": user, "target": target, "ability": ability,
		"cover": _cover_applies(user, ability, target), "reaction": is_reaction})
	var events: Array = [result]
	if result.hit:
		target.hp = maxi(target.hp - result.damage, 0)
		if ability.applies_status and target.is_alive():
			target.add_status(ability.applies_status)
	if not target.is_alive():
		grid.occupant.erase(target.cell)
		events.append({"type": "defeated", "unit": target})
	return events
