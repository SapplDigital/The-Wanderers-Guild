extends Node
## Repair the Common Room (M11): quest routes through the real data in any order, and the guild
## interior in the real region (cutaway + camera collision, doorway/walls, before/after, lodger,
## reload, no event opportunity from walking in and out).
##   godot --headless --path . res://tests/test_guild.tscn

const QUEST := preload("res://data/quests/common_room.tres")
const HEARTH := preload("res://data/dialogue/common_room_hearth.tres")
const WENNA := preload("res://data/dialogue/well_keeper.tres")
const LODGER := preload("res://data/dialogue/lodger.tres")
const Q := "quest.common_room."
const REPAIRED := "guild.common_room.repaired"
const EMBER_LINE := "The guild hearth needs a live coal."
const REPAIR_LINE := "Repair the common room."

var _failures := 0


func _ready() -> void:
	_check(QUEST.validate().is_empty() and HEARTH.validate().is_empty() and LODGER.validate().is_empty(),
		"quest, hearth and lodger data validate")
	_test_routes()
	await _test_in_world()
	print("guild: %s (%d failures)" % ["OK" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _test_routes() -> void:
	# Inspecting the cold hearth takes the job on and says what's missing.
	GameState.flags = {"npc.well_keeper.met": true}
	_check(not _replies(WENNA).has(EMBER_LINE), "Wenna isn't asked for a coal before the job exists")
	_check(_opening(HEARTH) == &"cold", "the hearth starts cold")
	_talk(HEARTH, ["What would it take?"])
	_check(QuestTracker.is_active(QUEST, GameState) and _objective() == "Find timber to mend the table and shutters.",
		"inspecting the hearth accepts the quest")

	# Route A: timber first, then the coal.
	GameState.set_flag("camp_boards.used")
	GameState.set_flag(Q + "has_timber") # what SalvageBoards writes
	_check(_objective() == "Find a live coal for the hearth.", "timber done, the coal is next")
	_check(_opening(HEARTH) == &"cold", "one material isn't enough to repair")
	_check(not _reachable_replies(HEARTH).has(REPAIR_LINE), "no repair choice with one material")
	_check(_hint_replies() == ["And a live coal?"], "the hearth only hints at what's still missing")
	_talk(WENNA, [EMBER_LINE])
	_check(GameState.is_set(Q + "has_ember") and not _replies(WENNA).has(EMBER_LINE), "Wenna gives one coal, once")
	_check(_objective() == "Bring the boards and the coal to the hearth.", "both materials: repair is next")
	_talk(HEARTH, [REPAIR_LINE])
	var o := QuestTracker.outcome(QUEST, GameState)
	_check(GameState.is_set(REPAIRED) and o != null and o.id == &"repaired" and not QuestTracker.is_active(QUEST, GameState),
		"repairing ends the quest")
	_check(_opening(HEARTH) == &"warm", "the hearth is warm afterwards")

	# Route B: coal first, then timber.
	GameState.flags = {"npc.well_keeper.met": true}
	_talk(HEARTH, [])
	_talk(WENNA, [EMBER_LINE])
	_check(_objective() == "Find timber to mend the table and shutters.", "coal first: timber still open")
	_check(_hint_replies() == ["Where would I find timber?"], "...and the hearth hints at timber only")
	GameState.set_flag(Q + "has_timber")
	_check(_opening(HEARTH) == &"ready", "the order of the materials doesn't matter")

	# Timber salvaged before the job existed still counts.
	GameState.flags = {"npc.well_keeper.met": true, Q + "has_timber": true}
	_check(not QuestTracker.is_accepted(QUEST, GameState), "salvaging boards doesn't start the quest by itself")
	_talk(HEARTH, [])
	_check(_objective() == "Find a live coal for the hearth.", "boards found before the job count once it's taken")
	# Both facts true before ever touching the hearth: straight to the repair, and the job is recorded.
	GameState.flags = {Q + "has_timber": true, Q + "has_ember": true}
	_check(_opening(HEARTH) == &"ready", "materials first: the hearth offers the repair at once")
	_talk(HEARTH, ["Not yet."])
	_check(QuestTracker.is_accepted(QUEST, GameState), "...and the job is recorded")
	_check(not GameState.is_set(REPAIRED), "'Not yet.' changes nothing")

	# The lodger: first meeting points at the floating island; later visits open differently.
	GameState.flags = {REPAIRED: true}
	_check(_opening(LODGER) == &"first", "the lodger introduces herself on the first visit")
	_talk(LODGER, ["What brings you here?", "I'll go up and look."])
	_check(GameState.is_set("npc.lodger.told_island"), "the lodger's rumour points at the island")
	_check(_opening(LODGER) == &"again", "later she asks about the overlook")
	GameState.set_flag("discovered.overlook")
	_check(_opening(LODGER) == &"overlook", "after the overlook she knows you've been up there")
	_talk(LODGER, ["It hung right over the mountains."])
	_check(_opening(LODGER) == &"overlook", "...and keeps acknowledging it")
	_check("I've been up there already." in _island_replies(true), "meeting her after the overlook, you can say you've been")
	_check(not "I've been up there already." in _island_replies(false), "...a reply that isn't offered before the overlook")
	GameState.flags.erase("discovered.overlook")
	GameState.flags = {}


func _test_in_world() -> void:
	GameState.flags = {EventHost.LAST_REGION: "village", EventDirector.SEED: 1}
	var ui := DialogueUI.new()
	add_child(ui)
	var world := await _load_world()
	var player: Player = world.get_node("Player")
	var rig: CameraController = world.get_node("CameraRig")
	var hall: Node3D = world.get_node("Village/GuildHall")
	var zone: InteriorZone = hall.get_node("Interior")
	var cutaway: Node3D = hall.get_node("Cutaway")
	var arm: SpringArm3D = rig.get_node("Pitch/SpringArm3D")
	var inside := hall.global_position + Vector3(2.5, 0, -2)
	var outside := hall.global_position + Vector3(7, 0, 0)

	_check(zone.camera_rig == rig and zone.cutaway == cutaway, "the interior is wired to the camera and the cutaway")
	_check(not cutaway.visible and arm.collision_mask == 0 and zone.inside, "a new game starts inside the common room, cut away")
	var hearth: Interactable = hall.get_node("HearthUse")
	_check((player.get_node("Interactor") as Interactor).focus == hearth, "...with the hearth in reach (the first prompt)")
	player.global_position = outside
	await _physics(4)
	_check(cutaway.visible and arm.collision_mask == 1 and not zone.inside, "outside: roof shown, camera collides")
	_check((hall.get_node("Damaged") as Node3D).visible and not (hall.get_node("Repaired") as Node3D).visible,
		"before the repair the room is damaged")
	_check(not _body_at(world, hall.global_position + Vector3(0.8, 0.4, 0.4)), "the hidden table doesn't block")
	var region := world.get_node("Events/VillageRegion/Shape") as CollisionShape3D
	var r := (region.shape as SphereShape3D).radius
	_check([Vector3(-4.8, 0, -4.4), Vector3(4.8, 0, -4.4), Vector3(-4.8, 0, 4.4), Vector3(4.8, 0, 4.4)].all(
		func(c: Vector3) -> bool: return (hall.global_position + c).distance_to(region.global_position) < r - 1.0),
		"the whole hall lies inside the village event region")

	# Walking in and out through the doorway.
	var opportunity: Variant = GameState.get_flag(EventDirector.OPPORTUNITY)
	player.global_position = outside
	await _physics(4)
	var hit := player.move_and_collide(Vector3(-4.5, 0, 0))
	_check(hit == null and player.global_position.x < hall.global_position.x + 3.5, "the player fits through the doorway")
	await _physics(4)
	_check(zone.inside and not cutaway.visible and arm.collision_mask == 0, "inside: roof and upper walls hide, camera collision is off")
	_check(_surface_at(world, player.global_position) == "wood", "the guild floor sounds like wood")
	hit = player.move_and_collide(Vector3(-8, 0, 0))
	_check(hit != null and player.global_position.x > hall.global_position.x - 4.4, "the west wall stops the player (collision stays while cut away)")
	player.global_position = outside + Vector3(0, 0, 2.5)
	await _physics(4)
	_check(not zone.inside and cutaway.visible and arm.collision_mask == 1, "outside again: roof back, camera collides again")
	hit = player.move_and_collide(Vector3(-4, 0, 0))
	_check(hit != null and player.global_position.x > hall.global_position.x + 4.6, "the east wall beside the door blocks")
	_check(GameState.get_flag(EventDirector.OPPORTUNITY) == opportunity and GameState.get_flag(EventHost.LAST_REGION) == "village",
		"walking in and out of the guild is not an event opportunity")

	# The hidden lodger can't be talked to.
	player.global_position = hall.global_position + Vector3(-0.8, 0, 1.6)
	await _physics(3)
	var interactor: Interactor = player.get_node("Interactor")
	var lodger_talk: Interactable = hall.get_node("Repaired/Lodger/Talk")
	_check(interactor.focus != lodger_talk, "no lodger to talk to before the repair")

	# Repair at the hearth.
	GameState.set_flag(Q + "has_timber")
	GameState.set_flag(Q + "has_ember")
	(hall.get_node("HearthUse") as Interactable).interact(player)
	_check(ui.runner != null and ui.runner.node.id == &"ready", "the hearth offers the repair")
	ui.confirm(0) # Repair the common room.
	ui.confirm(0) # continue
	_check(GameState.is_set(REPAIRED), "the repair is done")
	_check((hall.get_node("Repaired") as Node3D).visible and not (hall.get_node("Damaged") as Node3D).visible,
		"the room changes: table, fire and lodger")
	await _physics(3)
	_check(interactor.focus == lodger_talk, "the lodger can be talked to")
	_check(_body_at(world, hall.global_position + Vector3(0.8, 0.4, 0.4)), "the mended table is solid")

	# Reload while standing inside (F5 = leave + return): nothing breaks, the repair persists.
	world.free()
	world = await _load_world(inside)
	hall = world.get_node("Village/GuildHall")
	zone = hall.get_node("Interior")
	arm = world.get_node("CameraRig/Pitch/SpringArm3D")
	_check(zone.inside and not (hall.get_node("Cutaway") as Node3D).visible and arm.collision_mask == 0,
		"after a reload inside, the room is cut away straight away")
	_check((hall.get_node("Repaired") as Node3D).visible and not (hall.get_node("Damaged") as Node3D).visible,
		"the repair survives the reload")
	world.get_node("Player").global_position = outside
	await _physics(4)
	_check((hall.get_node("Cutaway/LitWindows") as Node3D).is_visible_in_tree(), "outside, the windows glow")
	_check(GameState.get_flag(EventDirector.OPPORTUNITY) == opportunity, "reloading in the guild is not an event opportunity")
	world.free()
	world = await _load_world() # the real F5 path: the player respawns at the start, in the common room
	_check(not (world.get_node("Village/GuildHall/Cutaway") as Node3D).visible, "a plain reload starts in the common room, cut away")
	world.queue_free()
	ui.queue_free()
	await get_tree().process_frame
	GameState.flags = {}


func _load_world(player_at: Variant = null) -> Node3D:
	var world: Node3D = load("res://scenes/world/slice_region.tscn").instantiate()
	if player_at != null:
		(world.get_node("Player") as Node3D).position = player_at
	add_child(world)
	await _physics(3)
	return world


## Area overlaps are reported a physics step after a move, so give it a few.
func _physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame
	await get_tree().process_frame


func _body_at(world: Node3D, point: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collision_mask = 1
	return not world.get_world_3d().direct_space_state.intersect_point(query).is_empty()


func _surface_at(world: Node3D, point: Vector3) -> String:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point + Vector3(0, 0.1, 0)
	query.collision_mask = 16
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in world.get_world_3d().direct_space_state.intersect_point(query):
		if hit.collider is SurfaceArea:
			return hit.collider.surface
	return ""


func _hint_replies() -> Array:
	var run := DialogueRunner.new(HEARTH, Flags.new(GameState.flags.duplicate()))
	run.start()
	run.choose(0) # What would it take?
	return run.choices().map(func(c: DialogueChoice) -> String: return c.text).filter(
		func(t: String) -> bool: return t != "Leave it for now.")


## Every reply offered anywhere in the conversation, on a copy of the flags.
func _reachable_replies(data: DialogueData) -> Array:
	var out := []
	var run := DialogueRunner.new(data, Flags.new(GameState.flags.duplicate()))
	run.start()
	for c in run.choices():
		out.append(c.text)
		var node := data.find(c.next)
		if node:
			out.append_array(node.choices.map(func(x: DialogueChoice) -> String: return x.text))
	return out


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
	var run := DialogueRunner.new(data, Flags.new(GameState.flags.duplicate()))
	return run.node.id if run.start() else &""


## Maren's replies after "What brings you here?" on a first meeting, with or without the overlook.
func _island_replies(overlook: bool) -> Array:
	var flags := GameState.flags.duplicate()
	flags.erase("npc.lodger.met")
	flags["discovered.overlook"] = overlook
	var run := DialogueRunner.new(LODGER, Flags.new(flags))
	run.start()
	var texts := run.choices().map(func(c: DialogueChoice) -> String: return c.text)
	run.choose(texts.find("What brings you here?"))
	return run.choices().map(func(c: DialogueChoice) -> String: return c.text)


func _replies(data: DialogueData) -> Array:
	var run := DialogueRunner.new(data, Flags.new(GameState.flags.duplicate()))
	run.start()
	return run.choices().map(func(c: DialogueChoice) -> String: return c.text)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAIL: " + what)
	else:
		print("PASS: " + what)


## Scratch flag store so peeking at a conversation doesn't run its entry consequences for real.
class Flags:
	var data: Dictionary
	func _init(d: Dictionary) -> void:
		data = d
	func get_flag(key: String, default: Variant = null) -> Variant:
		return data.get(key, default)
	func set_flag(key: String, value: Variant = true) -> void:
		data[key] = value
	func is_set(key: String) -> bool:
		var v: Variant = data.get(key, false)
		return v is bool and v
