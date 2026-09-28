class_name EventHost
extends Node
## World glue for the WorldEventDirector (not an autoload). In M10 an evaluation opportunity is
## entering a different EventRegion than last time, at a safe moment (not in combat, dialogue or
## a cinematic). Unsafe entries are skipped, not queued. The decision itself is EventDirector's.

const EVENT_DIR := "res://data/events/"
const LAST_REGION := "event.director.last_region"

@export var player: Player
@export var camera_rig: CameraController

var _events: Array[EventData] = []


func _ready() -> void:
	add_to_group("event_host")
	for file in DirAccess.get_files_at(EVENT_DIR):
		if file.ends_with(".tres"):
			_events.append(load(EVENT_DIR + file))
	if GameState.get_flag(EventDirector.SEED) == null:
		GameState.set_flag(EventDirector.SEED, randi())


func on_region_entered(region: StringName) -> void:
	if String(region) == GameState.get_flag(LAST_REGION, "") or not is_safe():
		return
	GameState.set_flag(LAST_REGION, String(region))
	_announce(EventDirector.evaluate(_events, GameState, region))


## Nothing may start while the player is busy: combat and dialogue disable input.
func is_safe() -> bool:
	return player.input_enabled and camera_rig.state != CameraController.State.CINEMATIC


## F8 (debug builds): evaluate the current region now, ignoring the gap but not the conditions.
func debug_evaluate() -> void:
	if OS.is_debug_build() and is_safe():
		_announce(EventDirector.evaluate(_events, GameState, StringName(GameState.get_flag(LAST_REGION, "")), true))


func _announce(event: EventData) -> void:
	if event and event.announcement != "":
		get_tree().call_group("hud", "show_message", event.announcement)
		AudioManager.play(&"discovery")
