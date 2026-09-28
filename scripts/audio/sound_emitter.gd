class_name SoundEmitter
extends AudioStreamPlayer3D
## A looping world sound placed in a scene, e.g. a wisp's hum. Plays only while visible
## in the tree, so a StateToggle switches it off together with its visuals.

@export var event: StringName


func _ready() -> void:
	if AudioManager.configure(self, event):
		_sync()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		_sync()


func _sync() -> void:
	if is_visible_in_tree() and not playing and stream:
		play(randf() * stream.get_length()) # random offset so neighbours drift apart
	elif not is_visible_in_tree():
		stop()
