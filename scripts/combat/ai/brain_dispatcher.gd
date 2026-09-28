class_name BrainDispatcher
extends RefCounted
## Turns a data-selected CombatBrain's intents into CombatState commands. The dispatcher knows
## no enemy categories: ActorData supplies both a descriptive profile name and a Brain script.
## This lets future passive, social, territorial or unusual entities opt out or provide their
## own behavior without changing this class or CombatState.


static func take_turn(state: CombatState, unit: CombatUnit) -> Array:
	var brain := _brain_for(unit)
	if brain == null:
		return []
	var events: Array = []
	for intent in brain.choose_turn(state, unit):
		if not unit.is_alive() or state.outcome() != &"":
			break
		if intent is Dictionary:
			events.append_array(_resolve_intent(state, unit, intent))
	return events


static func _brain_for(unit: CombatUnit) -> CombatBrain:
	var script: GDScript = unit.data.ai_brain
	if script == null:
		return null
	var instance: Variant = script.new()
	return instance as CombatBrain if instance is CombatBrain else null


## CombatState owns legality and resolution. Invalid/malformed intents safely produce no event.
static func _resolve_intent(state: CombatState, unit: CombatUnit, intent: Dictionary) -> Array:
	match intent.get("type", &""):
		&"move":
			var destination: Variant = intent.get("destination")
			return state.move(unit, destination) if destination is Vector3 else []
		&"use":
			var ability: Variant = intent.get("ability")
			var target: Variant = intent.get("target")
			return state.use(unit, ability, target) if ability is AbilityData else []
		&"declare":
			var key: Variant = intent.get("key")
			if key is StringName:
				unit.brain_memory[key] = intent.get("value", true)
				unit.telegraph_radius = float(intent.get("radius", 0.0))
				return [{"type": "telegraph", "unit": unit, "message": String(intent.get("message", ""))}]
		&"forget":
			var key: Variant = intent.get("key")
			if key is StringName:
				unit.brain_memory.erase(key)
				unit.telegraph_radius = 0.0
	return []
