class_name DialogueChoice
extends Resource
## A player reply (or, in `DialogueData.entries`, an automatic opening). Shown only if every
## condition passes; picking it applies the consequences and moves to `next` (empty = end).

@export var text := ""
@export var conditions: Array[DialogueCondition] = []
@export var consequences: Array[DialogueConsequence] = []
@export var next: StringName
