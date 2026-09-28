class_name GuardianBrain
extends CombatBrain
## Demonstration brain for a slow, durable threat. When it reaches a foe it declares a visible
## heavy strike, giving the player a turn to react; on its next turn it follows through if able.

const TELEGRAPH_KEY := &"guardian_heavy_strike"
const APPROACH_SAMPLES := 12


func choose_turn(state: CombatState, unit: CombatUnit) -> Array:
	var attack := _strongest_attack(unit)
	var target := _nearest_foe(state, unit)
	if attack == null or target == null:
		return []
	if unit.brain_memory.has(TELEGRAPH_KEY):
		if state.in_range(unit, target, attack):
			return [{"type": &"use", "ability": attack, "target": target}, {"type": &"forget", "key": TELEGRAPH_KEY}]
		var close: Variant = _approach_point(state, unit, target, attack.range_max)
		return [{"type": &"move", "destination": close}] if close != null else []
	if state.in_range(unit, target, attack):
		return [{"type": &"declare", "key": TELEGRAPH_KEY, "value": attack.id, "radius": attack.range_max,
			"message": "%s raises its weapon for %s! Get out of its reach." % [unit.data.display_name, attack.display_name]}]
	var destination: Variant = _approach_point(state, unit, target, attack.range_max)
	return [{"type": &"move", "destination": destination}] if destination != null else []


func _nearest_foe(state: CombatState, unit: CombatUnit) -> CombatUnit:
	var foes := state.foes_of(unit)
	if foes.is_empty():
		return null
	foes.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool: return state.distance(unit, a) < state.distance(unit, b))
	return foes[0]


func _strongest_attack(unit: CombatUnit) -> AbilityData:
	var best: AbilityData
	for ability in unit.data.abilities:
		if ability.kind == AbilityData.Kind.ATTACK:
			if best == null or ability.damage_die + ability.damage_bonus > best.damage_die + best.damage_bonus:
				best = ability
	return best


func _approach_point(state: CombatState, unit: CombatUnit, target: CombatUnit, reach: float) -> Variant:
	var best: Dictionary = {}
	for i in APPROACH_SAMPLES:
		var p := CombatSpace.flat(target.position) + Vector2.RIGHT.rotated(TAU * i / APPROACH_SAMPLES) * maxf(reach - 0.25, CombatSpace.UNIT_RADIUS * 2.0)
		var plan := state.plan_move(unit, state.space.ground(p))
		if plan.reachable and (best.is_empty() or plan.cost < best.cost):
			best = plan
	if best.is_empty():
		return null
	if best.valid:
		return best.points.back()
	var part := state.space.truncate(best.points, unit.movement_left)
	return part.points.back() if part.points.size() > 1 else null
