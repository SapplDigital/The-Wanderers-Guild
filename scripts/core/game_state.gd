extends Node
## World memory (autoload `GameState`). A flat store of facts, keyed by strings.
## Everything the world should remember goes through here; systems react via `flag_changed`.
## Key conventions (not enforced):
##   discovered.<location>     places the player has found
##   <object_id>.used          interactables that were used
##   world.<fact>              persistent world changes (e.g. world.shrine_awakened)
##   npc.<id>.<fact>, quest.<id>.<fact>, event.<id>.<fact>   (later milestones)
## ponytail: untyped string keys, no schema; add validation when data files start writing keys.

signal flag_changed(key: String, value: Variant)

var flags := {}


func set_flag(key: String, value: Variant = true) -> void:
	if flags.get(key) == value:
		return
	flags[key] = value
	flag_changed.emit(key, value)


func get_flag(key: String, default: Variant = null) -> Variant:
	return flags.get(key, default)


func is_set(key: String) -> bool:
	return flags.get(key, false) == true
