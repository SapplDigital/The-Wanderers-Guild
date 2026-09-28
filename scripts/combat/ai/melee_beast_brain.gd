class_name MeleeBeastBrain
extends CombatBrain
## Demonstration brain for a direct creature. It chooses a vulnerable nearby foe, walks toward
## melee reach and attempts its first attack. CombatState still validates every selected command.

const APPROACH_SAMPLES := 12


func choose_turn(state: CombatState, unit: CombatUnit) -> Array:
	var attack := _first_attack(unit)
	var target := _priority_foe(state, unit)
	if attack == null or target == null:
		return []
	var intents: Array = []
	if not state.in_range(unit, target, attack):
		var destination: Variant = _approach_point(state, unit, target, attack.range_max)
		if destination != null:
			intents.append({"type": &"move", "destination": destination})
	intents.append({"type": &"use", "ability": attack, "target": target})
	return intents


func _priority_foe(state: CombatState, unit: CombatUnit) -> CombatUnit:
	var foes := state.foes_of(unit)
	if foes.is_empty():
		return null
	foes.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
		var a_ratio := a.hp / float(a.data.max_hp)
		var b_ratio := b.hp / float(b.data.max_hp)
		if not is_equal_approx(a_ratio, b_ratio):
			return a_ratio < b_ratio
		return state.distance(unit, a) < state.distance(unit, b))
	return foes[0]


## Cheapest reachable point just inside attack reach; otherwise the furthest legal part of it.
func _approach_point(state: CombatState, unit: CombatUnit, target: CombatUnit, reach: float) -> Variant:
	var best: Dictionary = {}
	var around := CombatSpace.flat(target.position)
	for i in APPROACH_SAMPLES:
		var p := around + Vector2.RIGHT.rotated(TAU * i / APPROACH_SAMPLES) * maxf(reach - 0.3, CombatSpace.UNIT_RADIUS * 2.0)
		var plan := state.plan_move(unit, state.space.ground(p))
		if plan.reachable and (best.is_empty() or plan.cost < best.cost):
			best = plan
	if best.is_empty():
		return null
	if best.valid:
		return best.points.back()
	var part := state.space.truncate(best.points, unit.movement_left)
	return part.points.back() if part.points.size() > 1 else null


func _first_attack(unit: CombatUnit) -> AbilityData:
	for ability in unit.data.abilities:
		if ability.kind == AbilityData.Kind.ATTACK:
			return ability
	return null
