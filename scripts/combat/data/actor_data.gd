class_name ActorData
extends Resource
## Static definition of a combatant (player, companion or enemy). Runtime state lives in CombatUnit.

@export var id: StringName
@export var display_name := ""
@export var team: StringName = &"enemy"
@export var max_hp := 10
@export var defense := 10
@export var movement := 4
@export var attack_mod := 2
@export var initiative_mod := 0
@export var abilities: Array[AbilityData] = []
@export var reaction_ability: AbilityData ## used for opportunity strikes; null = no reaction
@export var tint := Color.WHITE ## placeholder look
@export var ai_profile: StringName = &"basic" ## which brain drives it (enemies)
