class_name StateToggle
extends Node3D
## Shows this node (and its children, lights included) only while GameState `flag` is set
## (or only while it's NOT set, with visible_when_set = false). Reacts live and on load.

@export var flag := ""
@export var visible_when_set := true


func _ready() -> void:
	GameState.flag_changed.connect(func(key: String, _v: Variant) -> void:
		if key == flag:
			_apply())
	_apply()


func _apply() -> void:
	visible = GameState.is_set(flag) == visible_when_set
