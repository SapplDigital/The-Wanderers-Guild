extends Node
## The Missing Ring: quest data validates, the tracker reads status from flags alone, and every
## route through the real dialogue files works in any order.
##   godot --headless --path . res://tests/test_quest.tscn

const QUEST := preload("res://data/quests/missing_ring.tres")
const OWNER := preload("res://data/dialogue/ring_owner.tres")
const WENNA := preload("res://data/dialogue/well_keeper.tres")
const HOARD := preload("res://data/dialogue/midge_hoard.tres")
const Q := "quest.missing_ring."
const CLEARED := "encounter.forest_edge_midges.cleared"

var _failures := 0


func _ready() -> void:
	_test_all_quests_validate()
	_test_tracker()
	_test_routes()
	await _test_in_world()
	print("quest: %s (%d failures)" % ["OK" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _test_all_quests_validate() -> void:
	var files := DirAccess.get_files_at("res://data/quests")
	_check(files.size() > 0, "data/quests has quest files")
	for file in files:
		if file.ends_with(".tres"):
			var quest := load("res://data/quests/" + file) as QuestData
			var errors := quest.validate() if quest else PackedStringArray(["not a QuestData"])
			_check(errors.is_empty(), "%s validates %s" % [file, errors])
	_check(QuestData.new().validate().size() > 0, "an empty quest is rejected")


func _test_tracker() -> void:
	GameState.flags = {}
	_check(not QuestTracker.is_active(QUEST, GameState), "not active before accepting")
	GameState.set_flag(Q + "accepted")
	_check(QuestTracker.is_active(QUEST, GameState) and _objective() == "Find out where the ring went.", "accepting starts at the first open objective")
	# Facts, not a sequence: each objective reads its own fact (the dialogue data makes taking
	# the ring also record where the hoard is).
	GameState.set_flag(Q + "has_ring")
	_check(_objective() == "Find out where the ring went.", "objectives follow facts (knowing is its own fact)")
	GameState.set_flag(Q + "knows_hoard")
	_check(_objective() == "Take the ring to Hollis, or don't.", "with both facts true, the last objective is current")
	GameState.set_flag(Q + "kept")
	var o := QuestTracker.outcome(QUEST, GameState)
	_check(o != null and o.id == &"kept" and not QuestTracker.is_active(QUEST, GameState), "an outcome ends the quest")
	GameState.flags = {}


## Every combination of how you learn, how you get the ring and how it ends.
func _test_routes() -> void:
	for learn in ["wenna", "explore"]:
		for obtain in ["fight", "trade"]:
			for ending in ["returned", "kept"]:
				var name := "%s/%s/%s" % [learn, obtain, ending]
				GameState.flags = {}
				GameState.set_flag("npc.well_keeper.met") # skip the first-meeting line
				_talk(OWNER, ["I'll look for it."])
				if learn == "wenna":
					_talk(WENNA, ["Have you seen a lost gold ring?", "Then I'll go and take it back."])
				else:
					_talk(HOARD, ["Pull your hand back."]) # finding the guarded hoard
				_check(GameState.is_set(Q + "knows_hoard") and _objective() == "Get the ring back.", name + ": knows where the ring is")
				if obtain == "fight":
					GameState.set_flag(CLEARED) # what CombatArea writes on victory
					_talk(HOARD, ["Take the ring."])
				else:
					# The trade needs Wenna's stone; either way you learned it, you tell her about the hoard.
					_talk(WENNA, ["The midges at the forest edge are hoarding bright things.", "Take the glint stone."])
					_talk(HOARD, ["Offer Wenna's glint stone."])
				_check(GameState.is_set(Q + "has_ring") and _objective() == "Take the ring to Hollis, or don't.", name + ": has the ring")
				_talk(OWNER, ["Give the ring back." if ending == "returned" else "No. I found nothing."])
				var o := QuestTracker.outcome(QUEST, GameState)
				_check(o != null and o.id == StringName(ending) and not QuestTracker.is_active(QUEST, GameState), name + ": ends " + ending)

	# Order independence: fight and loot first, never talk to anyone, then meet Hollis.
	GameState.flags = {}
	GameState.set_flag(CLEARED)
	_talk(HOARD, ["Take the ring."])
	_check(not QuestTracker.is_accepted(QUEST, GameState), "the ring can be found before the quest exists")
	_check(_opening(OWNER) == &"found", "Hollis recognises the ring without being asked first")
	_talk(OWNER, ["Give the ring back."])
	_check(QuestTracker.outcome(QUEST, GameState).id == &"returned", "returning it unasked still resolves the quest")
	_check(_opening(HOARD) == &"empty", "the hoard is empty afterwards")

	# Regression (manual M9 test): have ring -> tell Hollis "found nothing" -> talk again -> return it.
	GameState.flags = {Q + "accepted": true, Q + "knows_hoard": true, Q + "has_ring": true}
	_talk(OWNER, ["No. I found nothing."])
	_check(QuestTracker.outcome(QUEST, GameState).id == &"kept", "saying 'found nothing' keeps the ring for now")
	_check(_replies(OWNER).has("Actually... I did find it."), "talking again still offers the ring while you have it")
	_talk(OWNER, ["Actually... I did find it.", "Give the ring back."])
	_check(QuestTracker.outcome(QUEST, GameState).id == &"returned" and not GameState.is_set(Q + "kept"),
		"the ring can still be returned after lying, and the kept outcome (LOST notice) is undone")
	_check(_opening(OWNER) == &"thanks", "Hollis thanks you afterwards")

	# The guarded hoard gives nothing without a fight or a stone.
	GameState.flags = {}
	_talk(HOARD, ["Pull your hand back."])
	_check(not GameState.is_set(Q + "has_ring"), "reaching into the guarded hoard takes nothing")
	# Wenna only offers ring lines once there's a reason, and never after you have it.
	GameState.flags = {"npc.well_keeper.met": true}
	_check(not _replies(WENNA).has("Have you seen a lost gold ring?"), "Wenna isn't asked about a ring nobody mentioned")
	GameState.flags = {"npc.well_keeper.met": true, Q + "accepted": true, Q + "has_ring": true, Q + "knows_hoard": true}
	_check(not _replies(WENNA).any(func(t: String) -> bool: return "ring" in t or "midges" in t), "no ring lines once you have it")
	# Keeping it: Wenna remarks once.
	GameState.flags = {"npc.well_keeper.met": true, Q + "kept": true}
	_check(_opening(WENNA) == &"kept_remark", "Wenna remarks on the notice after you keep the ring")
	_check(_opening(WENNA) != &"kept_remark", "...only once")
	GameState.flags = {}


## End to end in the real region: talk to Hollis, win the midge fight through the controller,
## search the hoard, return the ring, and the lantern appears by the door.
func _test_in_world() -> void:
	GameState.flags = {}
	add_child(preload("res://scenes/ui/combat_hud.tscn").instantiate())
	var ui := DialogueUI.new()
	add_child(ui)
	var world: Node3D = load("res://scenes/world/slice_region.tscn").instantiate()
	add_child(world)
	await get_tree().physics_frame # idle enemies spawn deferred
	await get_tree().process_frame
	var player: Player = world.get_node("Player")
	var owner_talk: Interactable = world.get_node("Village/RingOwner/Talk")
	var hoard: Interactable = world.get_node("Forest/MidgeStones/Hoard")
	var midges: CombatArea = world.get_node("Forest/MidgeStones/CombatArea")
	var door_lamp: Node3D = world.get_node("Village/RingReturnedLamp")
	var notice: Node3D = world.get_node("Village/RingKeptNotice")
	_check(not door_lamp.visible and not notice.visible, "neither outcome shows before the quest")
	var trigger := (midges.get_node("Trigger/Shape") as CollisionShape3D).shape as SphereShape3D
	_check(hoard.global_position.distance_to(midges.global_position) > trigger.radius + 0.5,
		"the hoard can be reached without walking into the midge trigger")

	owner_talk.interact(player)
	ui.confirm(0) # I'll look for it.
	ui.confirm(0) # continue
	_check(QuestTracker.is_active(QUEST, GameState), "talking to Hollis accepts the quest")

	player.global_position = midges.global_position + Vector3(0, 0, 6)
	midges.start()
	midges.controller.debug_win() # the F7 path; its result plays back over a few frames
	for i in 600:
		if midges.is_cleared() and midges.controller == null:
			break
		await get_tree().process_frame
	_check(midges.is_cleared(), "winning the midge fight clears the encounter")
	hoard.interact(player)
	_check(ui.runner.node.id == &"unguarded", "after the fight the hoard is unguarded")
	ui.confirm(0) # Take the ring.
	ui.confirm(0) # continue
	_check(GameState.is_set(Q + "has_ring"), "the ring is taken from the hoard")

	owner_talk.interact(player)
	ui.confirm(0) # Give the ring back.
	ui.confirm(0) # continue
	_check(door_lamp.visible and not notice.visible, "returning the ring lights a lantern by Hollis's door")
	world.queue_free()
	await get_tree().process_frame
	GameState.flags = {}


func _objective() -> String:
	var o := QuestTracker.current_objective(QUEST, GameState)
	return o.text if o else ""


## Runs a conversation, picking replies by text; lines without replies are continued.
func _talk(data: DialogueData, picks: Array) -> void:
	var run := DialogueRunner.new(data, GameState)
	if not run.start():
		_check(false, "%s did not open" % data.id)
		return
	var queue := picks.duplicate()
	var guard := 0
	while not run.is_finished() and guard < 20:
		guard += 1
		var replies := run.choices().map(func(c: DialogueChoice) -> String: return c.text)
		if replies.is_empty():
			run.advance()
		elif queue.is_empty():
			run.leave()
		else:
			var i := replies.find(queue.pop_front())
			if i < 0:
				_check(false, "%s/%s: reply not offered (%s)" % [data.id, run.node.id, replies])
				run.leave()
			else:
				run.choose(i)


func _opening(data: DialogueData) -> StringName:
	var run := DialogueRunner.new(data, GameState)
	return run.node.id if run.start() else &""


func _replies(data: DialogueData) -> Array:
	var run := DialogueRunner.new(data, GameState)
	run.start()
	return run.choices().map(func(c: DialogueChoice) -> String: return c.text)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAIL: " + what)
	else:
		print("PASS: " + what)
