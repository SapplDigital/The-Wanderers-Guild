class_name DataIndex
extends Resource
## The explicit list of content that systems discover by id rather than by scene reference
## (quests for the HUD, events for EventHost). One file: `data/data_index.tres`.
##
## Why not scan `res://data/...` at runtime: in an exported build resources can be packed or
## remapped (`*.tres.remap`), so a directory listing may find nothing and quests/events would
## silently vanish. An index is an ordinary resource dependency and exports like any other.
## Order matters: EventDirector's weighted pick walks `events` in this order (kept alphabetical,
## as the old directory scan was), so reordering changes which event a given seed picks.
## `tests/test_data_index` checks that every file in the data folders is listed here.

const PATH := "res://data/data_index.tres"

@export var quests: Array[QuestData] = []
@export var events: Array[EventData] = []

static var _index: DataIndex


## The project's index, loaded once. Problems are reported loudly but don't stop the game:
## broken entries are dropped so one bad file can't take every quest or event with it.
static func main() -> DataIndex:
	if _index == null:
		_index = load(PATH)
		for problem in _index.validate():
			push_error("DataIndex: " + problem)
		_index.quests = _index.quests.filter(func(q: QuestData) -> bool: return q != null)
		_index.events = _index.events.filter(func(e: EventData) -> bool: return e != null)
	return _index


## Authoring errors; empty = valid.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	_check(quests, "quests", errors)
	_check(events, "events", errors)
	return errors


func _check(list: Array, what: String, errors: PackedStringArray) -> void:
	var seen := {}
	for i in list.size():
		var entry: Resource = list[i]
		if entry == null:
			errors.append("%s[%d] is missing (deleted or broken resource)" % [what, i])
		elif entry.id == &"":
			errors.append("%s[%d] (%s) has no id" % [what, i, entry.resource_path])
		elif seen.has(entry.id):
			errors.append("%s: duplicate id '%s' (%s and %s)" % [what, entry.id, seen[entry.id], entry.resource_path])
		else:
			seen[entry.id] = entry.resource_path
