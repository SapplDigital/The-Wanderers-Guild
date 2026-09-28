class_name DialogueConsequence
extends Resource
## What a choice changes: a GameState flag, or a named event other systems can listen to.

enum Kind { SET_FLAG, EVENT }

@export var kind := Kind.SET_FLAG
@export var key := "" ## flag key, or event id
@export var value := "" ## SET_FLAG only; empty = true
