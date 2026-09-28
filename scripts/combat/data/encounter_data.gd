class_name EncounterData
extends Resource
## Who fights where. Offsets are metres from the CombatArea's centre (y ignored; ground height is used).

@export var id: StringName
@export var enemies: Array[ActorData] = []
@export var enemy_offsets: Array[Vector3] = []
@export var engage_message := "" ## first combat log line
@export_multiline var victory_message := ""
@export_multiline var defeat_message := ""
