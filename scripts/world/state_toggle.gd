class_name StateToggle
extends Node3D
## Shows this node (and its children, lights included) only while GameState `flag` is set
## (or only while it's NOT set, with visible_when_set = false). Reacts live and on load.
## Hidden pieces are also disabled, so their bodies stop colliding and their Interactables
## (e.g. an NPC that isn't there yet) can't be used.

@export var flag := ""
@export var visible_when_set := true


func _ready() -> void:
	GameState.flag_changed.connect(func(key: String, _v: Variant) -> void:
		if key == flag:
			_apply())
	_apply()


func _apply() -> void:
	var shown := GameState.is_set(flag) == visible_when_set
	process_mode = PROCESS_MODE_INHERIT if shown else PROCESS_MODE_DISABLED # before visible: emitters start enabled
	visible = shown
