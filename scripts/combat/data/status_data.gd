class_name StatusData
extends Resource
## A timed condition on a unit (e.g. Dazzled). Modifiers stack additively with the unit's base values.

@export var id: StringName
@export var display_name := ""
@export var duration_turns := 1 ## counted down at the end of the affected unit's turns
@export var attack_mod := 0
@export var defense_mod := 0
