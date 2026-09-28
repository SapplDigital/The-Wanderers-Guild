class_name CombatUnit
extends RefCounted
## Runtime state of one combatant: HP, position, action economy, statuses.
## Player and enemies use the same class; ActorData holds the static definition.

var data: ActorData
var hp: int
var cell: Vector2i
var initiative := 0

var movement_left := 0
var has_action := false
var has_bonus := false
var has_reaction := false
var provokes_reactions := true
var statuses: Array = [] ## of {"status": StatusData, "turns_left": int}


func _init(actor: ActorData, start_cell: Vector2i) -> void:
	data = actor
	hp = actor.max_hp
	cell = start_cell
	has_reaction = actor.reaction_ability != null # ready from the start of the fight


var team: StringName:
	get: return data.team


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
