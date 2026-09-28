extends Node
## Dialogue: every data file validates, the validator catches authoring errors, and the runner
## branches, applies consequences and fires events from GameState flags alone.
##   godot --headless --path . res://tests/test_dialogue.tscn

const WELL := preload("res://data/dialogue/well_keeper.tres")

var _failures := 0
var _heard: Array[StringName] = []


func _ready() -> void:
	_test_all_files_validate()
	_test_validator_catches_errors()
	_test_well_keeper_runner()
	await _test_well_keeper_in_world()
	print("dialogue: %s (%d failures)" % ["OK" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _test_all_files_validate() -> void:
	var files := DirAccess.get_files_at("res://data/dialogue")
	_check(files.size() > 0, "data/dialogue has dialogue files")
	for file in files:
		if not file.ends_with(".tres"):
			continue
		var data := load("res://data/dialogue/" + file) as DialogueData
		var errors := data.validate() if data else PackedStringArray(["not a DialogueData"])
		_check(errors.is_empty(), "%s validates %s" % [file, errors])


func _test_validator_catches_errors() -> void:
	var bad := DialogueData.new()
	bad.id = &"bad"
	_check(bad.validate().size() > 0, "no entries is an error")
	bad.entries = [_choice("", &"a")]
	var a := _node(&"a", "Hello.", [_choice("Only if.", &"missing", [_cond("x")])])
	var dup := _node(&"a", "Again.")
	var lonely := _node(&"lonely", "Nobody links here.")
	bad.nodes = [a, dup, lonely]
	var text := "\n".join(bad.validate())
	_check("missing node 'missing'" in text, "broken link is reported")
	_check("duplicate node id 'a'" in text, "duplicate id is reported")
	_check("lonely: unreachable" in text, "unreachable node is reported")
	_check("every choice is conditional" in text, "all-conditional choices (soft-lock) are reported")


func _test_well_keeper_runner() -> void:
	GameState.flags = {}
	var events: Array[StringName] = []

	var run := _run(events)
	_check(run.start() and run.node.id == &"first", "first meeting opens with the first-meeting line")
	_check(GameState.is_set("npc.well_keeper.met"), "entry consequence remembers the meeting")
	_check(run.node.speaker == "Wenna", "line carries its speaker")
	_check(_texts(run).has("The lamp on the post is dark."), "lamp choice is offered while the lamp is dark")
	_check(not _texts(run).has("The well is glowing."), "no glow line before the shrine wakes")

	run.choose(_texts(run).find("Answering back?"))
	_check(run.node.id == &"reflection", "choice moves to its next line")
	run.choose(_texts(run).find("What lights?"))
	_check(events == [&"rumour.old_wood_lights"], "rumour choice fires its event")
	_check(GameState.is_set("npc.well_keeper.told_lights"), "rumour choice writes its flag")
	_check(run.node.id == &"lights" and run.choices().is_empty(), "rumour line has no replies")
	run.advance()
	_check(run.is_finished(), "continuing a line with empty next ends the conversation")

	run = _run(events)
	_check(run.start() and run.node.id == &"again", "revisit opens with the return line")
	run.choose(_texts(run).find("The lamp on the post is dark."))
	run.choose(_texts(run).find("Light it from my lantern."))
	_check(GameState.is_set("world.well_lamp_lit") and run.node.id == &"lamp_lit", "lighting the lamp sets the world flag")
	run.advance()

	run = _run(events)
	_check(run.start() and run.node.id == &"lamp_thanks", "after the lamp, the opening changes")
	_check(not _texts(run).has("The lamp on the post is dark."), "lamp choice is gone once lit")
	GameState.set_flag("world.shrine_awakened")
	_check(_texts(run).has("The well is glowing."), "shrine flag reveals the glow line (conditions are live)")

	var before := GameState.flags.duplicate()
	run.choose(_texts(run).find("About the water..."))
	run.leave()
	_check(run.is_finished() and GameState.flags == before, "walking away applies nothing")

	var eq := _cond("quest.ring.stage", DialogueCondition.Test.EQUALS, "found")
	GameState.set_flag("quest.ring.stage", "found")
	_check(eq.passes(GameState), "EQUALS compares flag values")
	GameState.set_flag("quest.ring.stage", "lost")
	_check(not eq.passes(GameState), "EQUALS rejects other values")
	GameState.flags = {}


## End to end in the real region: Interactable -> DialogueTrigger -> DialogueUI -> GameState -> StateToggle.
func _test_well_keeper_in_world() -> void:
	GameState.flags = {}
	add_to_group("dialogue_events")
	var ui := DialogueUI.new()
	add_child(ui)
	var world: Node3D = load("res://scenes/world/slice_region.tscn").instantiate()
	add_child(world)
	await get_tree().physics_frame
	var player: Player = world.get_node("Player")
	var talk: Interactable = world.get_node("Village/WellKeeper/Talk")
	var lamp_lit: Node3D = world.get_node("Village/WellLampLit")
	_check(talk.verb == "Talk" and not lamp_lit.visible, "well keeper stands at the well; lamp starts dark")

	talk.interact(player)
	_check(ui.is_open() and not player.input_enabled, "talking opens the panel and holds the player still")
	_check(ui.runner.node.id == &"first", "the panel shows the first-meeting line")
	ui.confirm(0) # Answering back?
	ui.confirm(0) # What lights?
	_check(_heard == [&"rumour.old_wood_lights"], "rumour event reaches the dialogue_events group")
	ui.confirm(0) # continue -> end
	_check(not ui.is_open() and player.input_enabled, "the conversation ends and control returns")

	talk.interact(player)
	_check(ui.runner.node.id == &"again", "talking again opens with the return line")
	ui.confirm(0) # The lamp on the post is dark. (no glow line yet)
	ui.confirm(0) # Light it from my lantern.
	_check(lamp_lit.visible and not (world.get_node("Village/WellLampDark") as Node3D).visible,
		"lighting the lamp visibly changes the well")
	ui.leave()
	_check(not ui.is_open() and player.input_enabled, "leaving mid-line closes the panel")
	world.queue_free()
	ui.queue_free()
	await get_tree().process_frame
	GameState.flags = {}


func on_dialogue_event(id: StringName) -> void:
	_heard.append(id)


func _run(events: Array[StringName]) -> DialogueRunner:
	var run := DialogueRunner.new(WELL, GameState)
	run.event_fired.connect(func(id: StringName) -> void: events.append(id))
	return run


func _texts(run: DialogueRunner) -> Array:
	return run.choices().map(func(c: DialogueChoice) -> String: return c.text)


func _choice(text: String, next: StringName, conditions: Array = []) -> DialogueChoice:
	var c := DialogueChoice.new()
	c.text = text
	c.next = next
	c.conditions.assign(conditions)
	return c


func _node(id: StringName, text: String, choices: Array = []) -> DialogueNode:
	var n := DialogueNode.new()
	n.id = id
	n.text = text
	n.choices.assign(choices)
	return n


func _cond(flag: String, test := DialogueCondition.Test.IS_SET, value := "") -> DialogueCondition:
	var c := DialogueCondition.new()
	c.flag = flag
	c.test = test
	c.value = value
	return c


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAIL: " + what)
	else:
		print("PASS: " + what)
