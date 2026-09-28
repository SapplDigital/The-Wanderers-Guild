class_name QuestData
extends Resource
## A quest described entirely by GameState facts (see DECISIONS, M9). Static data only;
## QuestTracker reads it together with the flags.

@export var id: StringName
@export var title := ""
@export var accepted_when: Array[DialogueCondition] = [] ## the player has taken it on (shows in the HUD)
@export var objectives: Array[QuestObjective] = []
@export var outcomes: Array[QuestOutcome] = []


## Authoring errors; empty = valid. Checked for every file by tests/test_quest.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or title == "":
		errors.append("quest needs an id and a title")
	if accepted_when.is_empty():
		errors.append("%s: no accepted_when conditions" % id)
	if outcomes.is_empty():
		errors.append("%s: no outcomes" % id)
	for o in objectives:
		if o.text == "" or o.done_when.is_empty():
			errors.append("%s: objective needs text and done_when" % id)
	for o in outcomes:
		if o.id == &"" or o.conditions.is_empty():
			errors.append("%s: outcome needs an id and conditions" % id)
	for c in _all_conditions():
		if c == null or c.flag == "":
			errors.append("%s: condition without a flag" % id)
	return errors


func _all_conditions() -> Array:
	var out: Array = accepted_when.duplicate()
	for o in objectives:
		out.append_array(o.done_when)
	for o in outcomes:
		out.append_array(o.conditions)
	return out
