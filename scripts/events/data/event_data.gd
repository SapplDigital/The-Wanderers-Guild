class_name EventData
extends Resource
## A world event the WorldEventDirector may start at an evaluation opportunity (see DECISIONS,
## M10). Static data only. The director decides whether, which and which variant; how the event
## plays out is up to dialogue, interactables and StateToggles reading the flags it writes.
## By convention, content that ends an event writes `event.<id>.resolved`.

enum Repeat { ONCE, COOLDOWN }

@export var id: StringName
@export var region: StringName ## the director only considers events of the region being evaluated
@export var weight := 1
@export var conditions: Array[DialogueCondition] = [] ## prerequisites, all must pass
@export var repeat := Repeat.ONCE
@export var cooldown := 0 ## COOLDOWN only: evaluation opportunities before it may fire again
@export var start: Array[DialogueConsequence] = [] ## flags written when it fires (SET_FLAG only)
@export_multiline var announcement := "" ## one HUD line when it fires
@export var variants: Array[EventVariant] = []


## Authoring errors; empty = valid. Checked for every file by tests/test_events.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or region == &"":
		errors.append("event needs an id and a region")
	if weight <= 0:
		errors.append("%s: weight must be > 0" % id)
	if repeat == Repeat.COOLDOWN and cooldown <= 0:
		errors.append("%s: COOLDOWN needs cooldown > 0" % id)
	if repeat == Repeat.ONCE and cooldown != 0:
		errors.append("%s: ONCE events have no cooldown" % id)
	if start.is_empty() and variants.is_empty():
		errors.append("%s: fires without changing anything" % id)
	var effects := start.duplicate()
	for v in variants:
		effects.append_array(v.start)
		if v.id == &"" or v.weight <= 0:
			errors.append("%s: variant needs an id and weight > 0" % id)
	if effects.any(func(c: DialogueConsequence) -> bool: return c.kind != DialogueConsequence.Kind.SET_FLAG):
		errors.append("%s: events only write flags (SET_FLAG)" % id)
	if not variants.is_empty() and variants.all(func(v: EventVariant) -> bool: return not v.conditions.is_empty()):
		errors.append("%s: every variant is conditional; it could fire with none" % id)
	return errors
