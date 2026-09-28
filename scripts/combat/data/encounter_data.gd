class_name EncounterData
extends Resource
## Who fights where. Cells are grid coordinates inside the arena.

@export var id: StringName
@export var enemies: Array[ActorData] = []
@export var enemy_cells: Array[Vector2i] = []
@export var player_cell := Vector2i.ZERO
@export_multiline var victory_message := ""
@export_multiline var defeat_message := ""
