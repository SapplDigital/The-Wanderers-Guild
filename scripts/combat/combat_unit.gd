class_name CombatUnit
extends RefCounted
## Runtime state of one combatant: HP, world position, action economy, statuses.
## Player and enemies use the same class; ActorData holds the static definition.

var data: ActorData
var hp: int
var position: Vector3
var initiative := 0

var movement_left := 0.0 ## metres
var has_action := false
var has_bonus := false
var has_reaction := false
var provokes_reactions := true
var statuses: Array = [] ## of {"status": StatusData, "turns_left": int}
var brain_memory: Dictionary = {} ## AI-owned ephemeral state (telegraphs, goals); CombatState never interprets it
var telegraph_radius := 0.0 ## public warning from a declared intent: danger reach around this unit; 0 = none


func _init(actor: ActorData, start: Vector3) -> void:
	data = actor
	hp = actor.max_hp
	position = start
	has_reaction = actor.reaction_ability != null # ready from the start of the fight


var team: StringName:
	get: return data.team


## Radius of the area this unit threatens (its reaction reach); 0 if it has no reaction.
var threat_radius: float:
	get: return data.reaction_ability.range_max if data.reaction_ability else 0.0


func is_alive() -> bool:
	return hp > 0


func attack_mod() -> int:
	var mod := data.attack_mod
	for s in statuses:
		mod += (s.status as StatusData).attack_mod
	return mod


func defense() -> int:
	var d := data.defense
	for s in statuses:
		d += (s.status as StatusData).defense_mod
	return d


func begin_turn() -> void:
	movement_left = data.movement
	has_action = true
	has_bonus = true
	has_reaction = data.reaction_ability != null # one reaction per round, refreshed on your own turn
	provokes_reactions = true


func end_turn() -> void:
	for s in statuses:
		s.turns_left -= 1
	statuses = statuses.filter(func(s: Dictionary) -> bool: return s.turns_left > 0)


func add_status(status: StatusData) -> void:
	statuses = statuses.filter(func(s: Dictionary) -> bool: return s.status.id != status.id)
	statuses.append({"status": status, "turns_left": status.duration_turns})


func has_status(id: StringName) -> bool:
	return statuses.any(func(s: Dictionary) -> bool: return s.status.id == id)
