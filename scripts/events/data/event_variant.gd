class_name EventVariant
extends Resource
## One way an event can play out (e.g. what's really behind the glowing fish). Picked by weight
## among the variants whose conditions pass; its id is stored as `event.<event id>.variant`.

@export var id: StringName
@export var weight := 1
@export var conditions: Array[DialogueCondition] = []
@export var start: Array[DialogueConsequence] = [] ## SET_FLAG only
