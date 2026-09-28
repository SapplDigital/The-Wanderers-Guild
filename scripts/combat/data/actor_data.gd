class_name ActorData
extends Resource
## Static definition of a combatant (player, companion or enemy). Runtime state lives in CombatUnit.

@export var id: StringName
@export var display_name := ""
@export var team: StringName = &"enemy"
@export var max_hp := 10
@export var defense := 10
@export var movement := 5.0 ## metres per turn
@export var attack_mod := 2
@export var initiative_mod := 0
@export var abilities: Array[AbilityData] = []
@export var reaction_ability: AbilityData ## used for opportunity strikes; null = no reaction
@export var tint := Color.WHITE ## placeholder look
@export var view_scale := 1.0 ## placeholder body size
@export var ai_profile: StringName = &"" ## descriptive, data-facing profile label; not dispatcher taxonomy
@export var ai_brain: GDScript ## CombatBrain script that chooses this actor's turn; null = no combat intent
