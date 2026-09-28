class_name RangedUtilityBrain
extends CombatBrain
## Demonstration brain for a distance fighter. It prefers an exposed foe, then samples legal
## firing positions that keep distance, preserve sight and put cover between itself and the foe.

const POSITION_SAMPLES := 16


func choose_turn(state: CombatState, unit: CombatUnit) -> Array:
	var attack := _ranged_attack(unit)
	var target := _exposed_foe(state, unit, attack)
	if attack == null or target == null:
		return []
	var destination: Variant = _best_firing_position(state, unit, target, attack)
	var intents: Array = []
	if destination != null and not CombatSpace.flat(destination).is_equal_approx(CombatSpace.flat(unit.position)):
		intents.append({"type": &"move", "destination": destination})
	intents.append({"type": &"use", "ability": attack, "target": target})
	return intents


func _ranged_attack(unit: CombatUnit) -> AbilityData:
	var best: AbilityData
	for ability in unit.data.abilities:
		if ability.kind == AbilityData.Kind.ATTACK and ability.range_max > 2.0:
			if best == null or ability.range_max > best.range_max:
				best = ability
	return best


func _exposed_foe(state: CombatState, unit: CombatUnit, attack: AbilityData) -> CombatUnit:
	var foes := state.foes_of(unit)
	if foes.is_empty() or attack == null:
		return null
	foes.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
		var a_cover := state.space.cover_between(unit.position, a.position) != ""
		var b_cover := state.space.cover_between(unit.position, b.position) != ""
		if a_cover != b_cover:
			return not a_cover
		var a_ratio := a.hp / float(a.data.max_hp)
		var b_ratio := b.hp / float(b.data.max_hp)
		return a_ratio < b_ratio)
	return foes[0]


func _best_firing_position(state: CombatState, unit: CombatUnit, target: CombatUnit, attack: AbilityData) -> Variant:
	var best: Dictionary = {}
	var ideal := clampf(attack.range_max * 0.72, attack.range_min + 1.0, attack.range_max - 0.4)
	for i in POSITION_SAMPLES:
		var p := CombatSpace.flat(target.position) + Vector2.RIGHT.rotated(TAU * i / POSITION_SAMPLES) * ideal
		var destination := state.space.ground(p)
		var plan := state.plan_move(unit, destination)
		if not plan.valid or not _can_fire_from(state, destination, target, attack):
			continue
		var score: float = -float(plan.cost)
		if state.space.cover_between(target.position, destination) != "":
			score += 4.0
		match state.space.terrain_at(p):
			&"water": score -= 4.0
			&"mud": score -= 1.0
		if best.is_empty() or score > best.score:
			best = {"score": score, "destination": destination}
	return best.destination if not best.is_empty() else null


func _can_fire_from(state: CombatState, from: Vector3, target: CombatUnit, attack: AbilityData) -> bool:
	var distance := CombatSpace.flat(from).distance_to(CombatSpace.flat(target.position))
	return distance >= attack.range_min - CombatSpace.EPS and distance <= attack.range_max + CombatSpace.EPS \
		and (not attack.needs_line_of_sight or state.space.line_of_sight(from, target.position))
