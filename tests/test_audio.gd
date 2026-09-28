extends Node
## System-correctness test for the audio pass:
##   godot --headless --path . res://tests/test_audio.tscn
## Checks the sound bank covers every event the region uses, ambience follows the player
## between areas, footsteps pick the right surface, and hum emitters follow world state.

const REGION := preload("res://scenes/world/slice_region.tscn")

var _failures := 0


func _ready() -> void:
	# Every event referenced by scene data or code must exist in the bank (catches typos).
	var world := REGION.instantiate()
	add_child(world)
	var used := {&"ui_confirm": true, &"discovery": true, &"reveal": true, &"step_grass": true, &"step_dirt": true, &"step_wood": true}
	for node in world.find_children("*", "SoundEmitter", true, false):
		used[node.event] = true
	for node in world.find_children("*", "AmbienceZone", true, false):
		for layer in node.layers:
			used[layer] = true
	for node in world.find_children("*", "Interactable", true, false):
		if node.sound != &"":
			used[node.sound] = true
	for event in used:
		var ev: SoundEvent = AudioManager.BANK.events.get(event)
		_check(ev != null and not ev.streams.is_empty() and ev.streams[0] != null, "bank has a stream for '%s'" % event)

	# Ambience follows the player: village -> forest -> combat clearing -> back to the village.
	# (Encounter marked cleared: this test walks through the clearing without fighting.)
	GameState.set_flag("encounter.clearing_boars.cleared")
	var player: Player = world.get_node("Player")
	await _settle()
	_check(&"amb_village" in AudioManager.active_ambience(), "village ambience at the start")
	player.global_position = Vector3(0, 0, -60)
	await _settle()
	_check(&"amb_forest" in AudioManager.active_ambience() and not &"amb_village" in AudioManager.active_ambience(), "forest ambience in the woods")
	player.global_position = Vector3(28, 0, -34)
	await _settle()
	_check(&"amb_combat" in AudioManager.active_ambience(), "combat bed in the clearing")
	player.global_position = Vector3(0, 0, 2)
	await _settle()
	_check(&"amb_village" in AudioManager.active_ambience() and not &"amb_combat" in AudioManager.active_ambience(), "village ambience again after returning")

	# Footstep surface: dirt on the plaza and path, grass off-path.
	var steps := player.get_node("Footsteps")
	_check(steps.surface() == "dirt", "plaza is dirt (got %s)" % steps.surface())
	player.global_position = Vector3(0, 0, -20)
	await _settle()
	_check(steps.surface() == "dirt", "forest path is dirt (got %s)" % steps.surface())
	player.global_position = Vector3(20, 0, -20)
	await _settle()
	_check(steps.surface() == "grass", "off-path is grass (got %s)" % steps.surface())

	# Hums follow world state: wisps and the dormant shrine go quiet, the well starts humming.
	var wisp_hum: SoundEmitter = world.get_node("Forest/AbandonedCamp/Wisps/Wisp0/Hum")
	var well_hum: SoundEmitter = world.get_node("Village/WellGlow/Hum")
	_check(wisp_hum.playing and not well_hum.playing, "wisps hum, well silent before the shrine")
	GameState.set_flag("world.shrine_awakened")
	_check(not wisp_hum.playing and well_hum.playing, "wisps silent, well hums after the shrine")

	print("audio: %s (%d failures)" % ["OK" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _settle() -> void:
	for i in 3:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAIL: " + what)
