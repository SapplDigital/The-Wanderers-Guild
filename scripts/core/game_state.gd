extends Node
## World memory (autoload `GameState`). A flat store of facts, keyed by strings.
## Everything the world should remember goes through here; systems react via `flag_changed`.
## Key conventions (not enforced):
##   discovered.<location>     places the player has found
##   <object_id>.used          interactables that were used
##   world.<fact>              persistent world changes (e.g. world.shrine_awakened)
##   npc.<id>.<fact>, quest.<id>.<fact>, event.<id>.<fact>
##   guild.<room>.<fact>      guild upgrades (e.g. guild.common_room.repaired)
## ponytail: untyped string keys, no schema; add validation when data files start writing keys.

signal flag_changed(key: String, value: Variant)

var flags := {}


func set_flag(key: String, value: Variant = true) -> void:
	var old: Variant = flags.get(key)
	if typeof(old) == typeof(value) and old == value: # values may be bools or strings; == across types errors
		return
	flags[key] = value
	flag_changed.emit(key, value)


## Swaps in a whole new set of facts (a load, or a new game with `{}`). Deliberately emits no
## `flag_changed`: the caller rebuilds the world right after, and every listener reads the flags
## again on `_ready`. Emitting per key here would announce quest updates for a loaded save.
func replace(new_flags: Dictionary) -> void:
	flags = new_flags


func get_flag(key: String, default: Variant = null) -> Variant:
	return flags.get(key, default)


func is_set(key: String) -> bool:
	var value: Variant = flags.get(key, false)
	return value is bool and value # only boolean true counts as set
