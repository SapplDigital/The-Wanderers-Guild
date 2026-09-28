class_name AbilityData
extends Resource
## Static definition of something a unit can do in combat.

enum Cost { ACTION, BONUS, REACTION }
enum Kind { ATTACK, SELF_BUFF }

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var cost: Cost = Cost.ACTION
@export var kind: Kind = Kind.ATTACK
@export_group("Attack")
@export var range_min := 1
@export var range_max := 1
@export var needs_line_of_sight := false
@export var attack_bonus := 0
@export var damage_die := 6
@export var damage_bonus := 0
@export var applies_status: StatusData
@export_group("Self buff")
@export var extra_movement := 0
@export var prevents_reactions := false ## moving this turn doesn't provoke opportunity strikes
