class_name Interactable
extends Area3D
## Anything the player can use: objects, resources, doors, containers, NPCs.
## Needs a CollisionShape3D child (the "reach" volume). The player's Interactor focuses it,
## the HUD shows "F  <verb>". Other systems hook in via `interacted` or the flags it writes.

signal interacted(actor: Node3D)

@export var verb := "Examine"
@export var state_id := "" ## persistent id; writes `<state_id>.used`. Empty = no memory.
@export var once := false ## stop offering the interaction after the first use
@export var prompt_height := 1.0
@export var sets_flag := "" ## world flag set to true on use, e.g. world.shrine_awakened
@export var sound: StringName = &"interact" ## AudioManager event played at the object
@export_multiline var message := ""
@export_multiline var message_repeat := "" ## shown instead when already used
@export var condition_flag := "" ## if this flag is set...
@export_multiline var condition_message := "" ## ...show this instead

var used: bool:
	get: return state_id != "" and GameState.is_set(state_id + ".used")


func _ready() -> void:
	collision_layer = 8 # layer 4 "interact"
	collision_mask = 0
	monitoring = false


func can_interact() -> bool:
	return not (once and used)


func interact(actor: Node3D) -> void:
	var text := message
	if used and message_repeat != "":
		text = message_repeat
	if condition_flag != "" and GameState.is_set(condition_flag) and condition_message != "":
		text = condition_message
	if state_id != "":
		GameState.set_flag(state_id + ".used")
	if sets_flag != "":
		GameState.set_flag(sets_flag)
	if text != "":
		get_tree().call_group("hud", "show_message", text)
	if sound != &"":
		AudioManager.play_at(sound, self)
	interacted.emit(actor)
