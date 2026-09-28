extends Node
## System-correctness test for the M5 loop, run as a scene so autoloads exist:
##   godot --headless --path . res://tests/test_exploration_loop.tscn
## Exits 0 on success, 1 on failure (prints each failed check).

const REGION := preload("res://scenes/world/slice_region.tscn")

var _failures := 0


func _ready() -> void:
	var world := _spawn()
	var player: Player = world.get_node("Player")

	# Discovery: entering the camp zone records it once.
	_check(not GameState.is_set("discovered.abandoned_camp"), "camp starts undiscovered")
	(world.get_node("Forest/AbandonedCamp/CampZone") as DiscoveryZone)._on_body_entered(player)
	_check(GameState.is_set("discovered.abandoned_camp"), "camp discovered after entering")

	# Interactions: journal remembers it was read; shrine flips a world flag and turns itself off.
	var journal: Interactable = world.get_node("Forest/AbandonedCamp/ReadJournal")
	_check(not journal.used, "journal unread")
	journal.interact(player)
	_check(journal.used, "journal marked used")
	var shrine: Interactable = world.get_node("Forest/HiddenHollow/TouchShard")
	shrine.interact(player)
	_check(GameState.is_set("world.shrine_awakened"), "shrine sets world.shrine_awakened")
	_check(not shrine.can_interact(), "one-shot shrine no longer offers interaction")
	var berries: Interactable = world.get_node("Forest/ResourceNodes/PickBerries0")
	berries.interact(player)
	_check(not (world.get_node("Forest/ResourceNodes/Berries0") as Node3D).visible, "picked berries disappear")
	_check((world.get_node("Village/WellGlow") as Node3D).visible, "well glows right after the shrine")
	_check(not (world.get_node("Forest/AbandonedCamp/Wisps") as Node3D).visible, "wisps go out once the shrine wakes")

	# Leave and return: rebuild the world; everything must come back from GameState.
	world.free()
	world = _spawn()
	player = world.get_node("Player")
	_check((world.get_node("Village/WellGlow") as Node3D).visible, "well still glows after reload")
	_check(not (world.get_node("Forest/HiddenHollow/Dormant") as Node3D).visible, "shrine stays awakened after reload")
	_check(not (world.get_node("Forest/ResourceNodes/Berries0") as Node3D).visible, "berries stay picked after reload")
	_check((world.get_node("Forest/ResourceNodes/Berries1") as Node3D).visible, "other bushes untouched")
	_check((world.get_node("Forest/AbandonedCamp/ReadJournal") as Interactable).used, "journal still read after reload")
	_check(not (world.get_node("Forest/HiddenHollow/TouchShard") as Interactable).can_interact(), "shrine still spent after reload")

	# Condition message: the well talks about the glow once the shrine is awake.
	var shown := []
	add_to_group("hud")
	set_meta("messages", shown)
	(world.get_node("Village/LookInWell") as Interactable).interact(player)
	_check(shown.size() == 1 and "teal" in shown[0], "well uses the shrine-awakened message")

	print("exploration loop: %s (%d failures)" % ["OK" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


## Stands in for the HUD so we can see which message an interaction produced.
func show_message(text: String) -> void:
	(get_meta("messages") as Array).append(text)


func show_location(_title: String) -> void:
	pass


func _spawn() -> Node:
	var world := REGION.instantiate()
	add_child(world)
	return world


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAIL: " + what)
