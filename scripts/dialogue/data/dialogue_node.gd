class_name DialogueNode
extends Resource
## One line. With visible choices the player picks; without, "continue" goes to `next` (empty = end).

@export var id: StringName
@export var speaker := ""
@export_multiline var text := ""
@export var choices: Array[DialogueChoice] = []
@export var next: StringName
