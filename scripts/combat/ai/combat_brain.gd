class_name CombatBrain
extends RefCounted
## Strategy for one combatant's turn. A brain may inspect the public combat state to choose
## intents, but it never changes units or resolves rules itself. BrainDispatcher is the only
## bridge from intent to CombatState commands.


## Returns ordered intent dictionaries. Supported core intents are:
##   {"type": &"move", "destination": Vector3}
##   {"type": &"use", "ability": AbilityData, "target": CombatUnit}
## New brains may return an empty list while their encounter-specific intent is handled by a
## later system; the dispatcher intentionally has no taxonomy of creature types.
func choose_turn(_state: CombatState, _unit: CombatUnit) -> Array:
	return []
