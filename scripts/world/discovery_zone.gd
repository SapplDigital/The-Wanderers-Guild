class_name DiscoveryZone
extends Area3D
## Records `discovered.<location_id>` the first time the player enters and shows the place name.

@export var location_id := ""
@export var title := ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # actors
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var key := "discovered." + location_id
	if body is Player and not GameState.is_set(key):
		GameState.set_flag(key)
		AudioManager.play(&"discovery")
		get_tree().call_group("hud", "show_location", title)
