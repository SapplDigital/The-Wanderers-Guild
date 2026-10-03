class_name DialogueConsequence
extends Resource
## What a choice changes: a GameState flag, or a named event other systems can listen to.

enum Kind { SET_FLAG, EVENT }

@export var kind := Kind.SET_FLAG
@export var key := "" ## flag key, or event id
@export var value := "" ## SET_FLAG only; empty = true


## Writes a SET_FLAG consequence into `flags` (anything with `set_flag`). The one place the
## "empty value means true" rule lives: dialogue replies and world events both apply through here.
## EVENT consequences are not flags; the caller decides who hears them.
func apply(flags: Object) -> void:
	if kind == Kind.SET_FLAG:
		flags.set_flag(key, true if value == "" else value)
