class_name QuestTracker
extends RefCounted
## Reads a quest's status from flags. Pure and read-only: dialogue, interactions and combat
## write the flags; this only interprets them (so it runs headless and needs no saving).


static func outcome(quest: QuestData, flags: Object) -> QuestOutcome:
	for o in quest.outcomes:
		if _all(o.conditions, flags):
			return o
	return null


static func is_accepted(quest: QuestData, flags: Object) -> bool:
	return _all(quest.accepted_when, flags)


## Accepted and not yet resolved: what the HUD shows.
static func is_active(quest: QuestData, flags: Object) -> bool:
	return is_accepted(quest, flags) and outcome(quest, flags) == null


## The first objective whose facts aren't true yet; null when all are (or none exist).
static func current_objective(quest: QuestData, flags: Object) -> QuestObjective:
	for o in quest.objectives:
		if not _all(o.done_when, flags):
			return o
	return null


static func _all(conditions: Array[DialogueCondition], flags: Object) -> bool:
	return conditions.all(func(c: DialogueCondition) -> bool: return c.passes(flags))
