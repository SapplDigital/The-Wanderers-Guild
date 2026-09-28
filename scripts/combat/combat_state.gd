class_name CombatState
extends RefCounted
## The rules of one fight (turn order + action economy + movement + resolution), in world space,
## with no presentation. Commands return an event log (Array of Dictionaries) the view plays back:
##   {type: "turn_start", unit}
##   {type: "move", unit, points: Array[Vector3]}          one uninterrupted leg of a walk
##   {type: "attack", user, target, ability, roll, total, defense, hit, crit, damage,
##          cover (label or ""), high_ground, reaction}
##   {type: "buff", unit, ability}      {type: "defeated", unit}
##   {type: "combat_end", winner}        (winner: &"player" or &"enemy")

var space: CombatSpace
var units: Array[CombatUnit] = []
var order: Array[CombatUnit] = [] ## initiative order, fixed for the fight
var round_number := 1
var rng := RandomNumberGenerator.new()
var _turn := 0


func _init(combat_space: CombatSpace, combatants: Array[CombatUnit], seed_value: int = -1) -> void:
	space = combat_space
	units = combatants
	if seed_value >= 0:
		rng.seed = seed_value
	for u in units:
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


## Positions of every other living unit (they block movement).
func blockers_for(unit: CombatUnit) -> Array:
	return units.filter(func(u: CombatUnit) -> bool: return u != unit and u.is_alive()) \
		.map(func(u: CombatUnit) -> Vector2: return CombatSpace.flat(u.position))


# ---------------------------------------------------------------- movement

## What walking to `destination` would mean, without doing it. The UI preview and move() share it.
## {"points", "cost", "valid", "reachable" (a path exists), "provokes": Array of foes, in path order}
func plan_move(unit: CombatUnit, destination: Vector3) -> Dictionary:
	var path := space.find_path(unit.position, destination, blockers_for(unit))
	var reachable: bool = not path.points.is_empty()
	var plan := {"points": path.points, "cost": path.cost, "reachable": reachable,
		"valid": reachable and path.cost <= unit.movement_left + CombatSpace.EPS, "provokes": []}
	if plan.valid and unit.provokes_reactions:
		plan.provokes = _reaction_triggers(unit, path.points).map(func(t: Dictionary) -> CombatUnit: return t.foe)
	return plan


## Walks the planned path. Leaving a foe's threat zone provokes its reaction (opportunity strike)
## at the exact point of exit; the walk continues afterwards unless the mover drops.
func move(unit: CombatUnit, destination: Vector3) -> Array:
	var plan := plan_move(unit, destination)
	if not plan.valid or plan.points.size() < 2:
		return []
	var points: Array = plan.points
	var triggers: Array[Dictionary] = []
	if unit.provokes_reactions:
		triggers = _reaction_triggers(unit, points)
	var events: Array = []
	var leg: Array[Vector3] = [points[0]]
	var seg := 1
	for t in triggers:
		while seg < t.index:
			leg.append(points[seg])
			seg += 1
		leg.append(t.point)
		events.append({"type": "move", "unit": unit, "points": leg})
		unit.position = t.point
		var foe: CombatUnit = t.foe
		foe.has_reaction = false
		events.append_array(_resolve_attack(foe, foe.data.reaction_ability, unit, true))
		if not unit.is_alive():
			return events
		leg = [t.point]
	while seg < points.size():
		leg.append(points[seg])
		seg += 1
	events.append({"type": "move", "unit": unit, "points": leg})
	unit.position = points.back()
	unit.movement_left -= plan.cost
	return events


## Foes whose threat zone the path leaves, in path order, first exit per foe only.
func _reaction_triggers(unit: CombatUnit, points: Array) -> Array[Dictionary]:
	var triggers: Array[Dictionary] = []
	for foe in foes_of(unit):
		if not foe.has_reaction or foe.threat_radius <= 0.0:
			continue
		var exits := space.zone_exits(points, foe.position, foe.threat_radius)
		if not exits.is_empty():
			var first: Dictionary = exits[0]
			first.foe = foe
			triggers.append(first)
	triggers.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.distance < y.distance)
	return triggers


# ---------------------------------------------------------------- actions

func can_use(unit: CombatUnit, ability: AbilityData) -> bool:
	match ability.cost:
		AbilityData.Cost.ACTION: return unit.has_action
		AbilityData.Cost.BONUS: return unit.has_bonus
	return false


func distance(a: CombatUnit, b: CombatUnit) -> float:
	return CombatSpace.flat(a.position).distance_to(CombatSpace.flat(b.position))


func in_range(user: CombatUnit, target: CombatUnit, ability: AbilityData) -> bool:
	var d := distance(user, target)
	return d >= ability.range_min - CombatSpace.EPS and d <= ability.range_max + CombatSpace.EPS \
		and (not ability.needs_line_of_sight or space.line_of_sight(user.position, target.position))


func targets_for(unit: CombatUnit, ability: AbilityData) -> Array:
	if ability.kind != AbilityData.Kind.ATTACK:
		return []
	return foes_of(unit).filter(func(f: CombatUnit) -> bool: return in_range(unit, f, ability))


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


## What the UI shows before committing: the same numbers the resolver will use.
func predict(user: CombatUnit, ability: AbilityData, target: CombatUnit) -> Dictionary:
	var mods := _modifiers(user, ability, target)
	return {
		"chance": ActionResolver.hit_chance(mods.attack, mods.defense),
		"damage": ActionResolver.damage_range(ability.damage_die, ability.damage_bonus),
		"cover": mods.cover,
		"high_ground": mods.high_ground,
		"defense": mods.defense,
		"distance": distance(user, target),
	}


func end_turn() -> Array:
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
	return [{"type": "turn_start", "unit": current()}]


func outcome() -> StringName:
	var player_alive := units.any(func(u: CombatUnit) -> bool: return u.team == &"player" and u.is_alive())
	var enemy_alive := units.any(func(u: CombatUnit) -> bool: return u.team != &"player" and u.is_alive())
	if not enemy_alive:
		return &"player"
	if not player_alive:
		return &"enemy"
	return &""


## Cover counts against ranged attacks; high ground helps any attack.
func _modifiers(user: CombatUnit, ability: AbilityData, target: CombatUnit) -> Dictionary:
	var cover := space.cover_between(user.position, target.position) if ability.range_max > 2.0 else ""
	var high := space.has_high_ground(user.position, target.position)
	return {
		"cover": cover,
		"high_ground": high,
		"attack": user.attack_mod() + ability.attack_bonus + (CombatSpace.HIGH_GROUND_BONUS if high else 0),
		"defense": target.defense() + (CombatSpace.COVER_DEFENSE if cover != "" else 0) \
			+ space.terrain_defense(CombatSpace.flat(target.position)),
	}


func _resolve_attack(user: CombatUnit, ability: AbilityData, target: CombatUnit, is_reaction: bool) -> Array:
	var mods := _modifiers(user, ability, target)
	var result := ActionResolver.attack(rng, mods.attack, mods.defense, ability.damage_die, ability.damage_bonus)
	result.merge({"type": "attack", "user": user, "target": target, "ability": ability,
		"cover": mods.cover, "high_ground": mods.high_ground, "reaction": is_reaction})
	var events: Array = [result]
	if result.hit:
		target.hp = maxi(target.hp - result.damage, 0)
		if ability.applies_status and target.is_alive():
			target.add_status(ability.applies_status)
	if not target.is_alive():
		events.append({"type": "defeated", "unit": target})
	return events
