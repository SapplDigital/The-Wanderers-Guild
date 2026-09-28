class_name DialogueTrigger
extends Node
## Starts `dialogue` when its Interactable is used (the Interactable itself stays unaware).
## Re-broadcasts dialogue events: `event_fired` here, and `on_dialogue_event(id)` on the
## "dialogue_events" group, so quests/world events can listen without a dialogue manager.

signal event_fired(id: StringName)

@export var dialogue: DialogueData
@export var interactable: Interactable


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)


func _on_interacted(actor: Node3D) -> void:
	var ui := get_tree().get_first_node_in_group("dialogue_ui")
	if ui == null or ui.is_open():
		return
	var runner := DialogueRunner.new(dialogue, GameState)
	runner.event_fired.connect(_broadcast)
	if runner.start():
		ui.open(runner, actor)


func _broadcast(id: StringName) -> void:
	event_fired.emit(id)
	get_tree().call_group("dialogue_events", "on_dialogue_event", id)
