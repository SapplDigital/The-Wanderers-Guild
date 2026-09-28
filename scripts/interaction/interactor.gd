class_name Interactor
extends Area3D
## Lives on the player. Focuses the nearest usable Interactable in reach; "interact" uses it.

signal focus_changed(target: Interactable)
signal used(target: Interactable)

@onready var _player: Player = get_parent()

var focus: Interactable


func _ready() -> void:
	collision_layer = 0
	collision_mask = 8 # layer 4 "interact"
	monitorable = false


func _physics_process(_delta: float) -> void:
	var best: Interactable = null
	var best_dist := INF
	if _player.input_enabled:
		for area in get_overlapping_areas():
			var target := area as Interactable
			if target and target.can_interact():
				var d := target.global_position.distance_squared_to(global_position)
				if d < best_dist:
					best = target
					best_dist = d
	if best != focus:
		focus = best
		focus_changed.emit(focus)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and focus:
		get_viewport().set_input_as_handled()
		AudioManager.play(&"ui_confirm")
		_player.reach_toward(focus.global_position)
		used.emit(focus)
		focus.interact(_player)
