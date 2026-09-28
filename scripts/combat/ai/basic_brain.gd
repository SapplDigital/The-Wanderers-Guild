class_name BasicBrain
extends RefCounted
## Placeholder enemy behaviour for M6: walk toward the nearest foe and hit it with the first attack.
## M7 replaces this with archetype brains that score cells/targets.


static func take_turn(state: CombatState, unit: CombatUnit) -> Array:
	var events: Array = []
	var attack := _first_attack(unit)
	var foes := state.foes_of(unit)
	if foes.is_empty() or attack == null:
		return events
	foes.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
		return CombatGrid.distance(unit.cell, a.cell) < CombatGrid.distance(unit.cell, b.cell))
	var target: CombatUnit = foes[0]
	if not state.in_range(unit.cell, target.cell, attack):
		var flood := state.reachable_for(unit)
		var best := unit.cell
		for c in flood.cost:
			if CombatGrid.distance(c, target.cell) < CombatGrid.distance(best, target.cell):
				best = c
		events.append_array(state.move(unit, best))
	if unit.is_alive() and target.is_alive() and state.can_use(unit, attack) and target in state.targets_for(unit, attack):
		events.append_array(state.use(unit, attack, target))
	return events


static func _first_attack(unit: CombatUnit) -> AbilityData:
	for a in unit.data.abilities:
		if a.kind == AbilityData.Kind.ATTACK:
			return a
	return null
