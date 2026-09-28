class_name QuestOutcome
extends Resource
## One way the quest can end. The quest is over once any outcome's conditions all pass.

@export var id: StringName
@export var text := "" ## shown when the quest ends this way
@export var conditions: Array[DialogueCondition] = []
