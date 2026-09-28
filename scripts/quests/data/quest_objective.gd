class_name QuestObjective
extends Resource
## One thing the player is working toward. Done once every `done_when` condition passes,
## however the player got there.

@export var text := ""
@export var done_when: Array[DialogueCondition] = []
