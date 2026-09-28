extends Node
## Save/load (M12): the SaveGame format (types, determinism, validation, migration), logic that
## must decide the same after a round trip (events, quests), and the real main scene: save and
## load outside, in the forest and inside the guild, refusals, a corrupt save, and an end-to-end
## run through real content (boards, Wenna, hearth, Glowing Fish, lodger) reloaded from scratch.
##   godot --headless --path . res://tests/test_save.tscn

const MAIN := preload("res://scenes/main.tscn")
const HEARTH := preload("res://data/dialogue/common_room_hearth.tres")
const WENNA := preload("res://data/dialogue/well_keeper.tres")
const LODGER := preload("res://data/dialogue/lodger.tres")
const COMMON_ROOM := preload("res://data/quests/common_room.tres")
const RING := preload("res://data/quests/missing_ring.tres")
const PATH := "user://test_save.cfg"
const HALL := Vector3(-17, 0, 0)
const INSIDE := HALL + Vector3(2.5, 0, -2)
const OUTSIDE := HALL + Vector3(7, 0, 0)
const CAMP := Vector3(-12.6, 0, -41.5)

var _failures := 0


func _ready() -> void:
	_test_format()
	_test_logic()
	await _test_world()
	await _test_end_to_end()
	_remove(PATH)
	GameState.flags = {}
	print("save: %s (%d failures)" % ["OK" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _test_format() -> void:
	_remove(PATH)
	var none := SaveGame.read(PATH)
	_check(not none.ok and none.error == SaveGame.NO_SAVE, "no file reads as 'no save'")

	var flags := {"a.bool": true, "a.string": "false", "a.int": 3, "a.float": 0.5, "future.unknown": "kept"}
	_check(SaveGame.write(PATH, flags, Vector3(1.25, 0.5, -3.75), 7) == OK, "write succeeds")
	_check(not FileAccess.file_exists(PATH + ".tmp"), "no .tmp left after a write")
	var back := SaveGame.read(PATH)
	_check(back.ok, "the save reads back")
	_check(_same(back.flags, flags), "every flag comes back with its type (bool, String, int, float, unknown keys)")
	_check(back.flags["a.int"] is int and back.flags["a.float"] is float and back.flags["a.bool"] is bool
		and back.flags["a.string"] is String, "int stays int, float stays float, bool bool, String String")
	_check(back.position is Vector3 and back.position == Vector3(1.25, 0.5, -3.75), "Vector3 position round-trips exactly")
	_check(back.health is int and back.health == 7, "health round-trips as int")
	_check(SaveGame.write(PATH, flags, Vector3.ZERO, 7) == OK and SaveGame.read(PATH).ok, "overwriting an existing save works")

	var reversed := {}
	var keys := flags.keys()
	keys.reverse()
	for k in keys:
		reversed[k] = flags[k]
	SaveGame.write(PATH, flags, Vector3.ONE, 5)
	var bytes_a := FileAccess.get_file_as_bytes(PATH)
	SaveGame.write(PATH, reversed, Vector3.ONE, 5)
	_check(bytes_a == FileAccess.get_file_as_bytes(PATH), "insertion order doesn't change a byte")

	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("someday", "weather", "rain")
	cfg.save(PATH)
	_check(SaveGame.read(PATH).ok, "unknown sections are ignored")

	var before := {"sentinel": true}
	GameState.flags = before.duplicate()
	_write_text("[save\nversion=")
	_check(_rejected(), "a corrupt file is rejected")
	_write_cfg({"player": {"position": Vector3.ZERO, "health": 5}, "state": {"flags": {}}})
	_check(_rejected(), "a save without [save] is rejected")
	_write_cfg({"save": {"version": 1}, "player": {"position": Vector3.ZERO, "health": 5}, "state": {"flags": [1, 2]}})
	_check(_rejected(), "flags that aren't a Dictionary are rejected")
	_write_cfg({"save": {"version": 1}, "player": {"position": Vector3.ZERO, "health": 5}, "state": {"flags": {"x": Vector3.ONE}}})
	_check(_rejected(), "a flag value of an unsupported type is rejected")
	_write_cfg({"save": {"version": 1}, "player": {"position": "here", "health": 5}, "state": {"flags": {}}})
	_check(_rejected(), "a non-Vector3 position is rejected")
	_write_cfg({"save": {"version": 1}, "player": {"position": Vector3.ZERO, "health": 0}, "state": {"flags": {}}})
	_check(_rejected(), "health below 1 is rejected")
	_write_cfg({"save": {"version": 1}, "player": {"position": Vector3.ZERO}, "state": {"flags": {}}})
	_check(_rejected(), "missing player data is rejected")
	_write_cfg({"save": {"version": SaveGame.VERSION + 1}, "player": {"position": Vector3.ZERO, "health": 5}, "state": {"flags": {}}})
	var newer := SaveGame.read(PATH)
	_check(not newer.ok and newer.error.contains("newer"), "a newer version is rejected as newer")
	_check(_same(GameState.flags, before), "failed reads never touch GameState")

	# Migration: no older format exists yet, so a version-0 file has no step and is refused;
	# with a step registered it goes through that step, and only that step.
	_write_cfg({"save": {"version": 0}, "player": {"position": Vector3.ZERO, "health": 5}, "state": {"flags": {"old": true}}})
	_check(_rejected(), "an old version without a migration step is refused")
	SaveGame.migrations = {0: func(d: Dictionary) -> Dictionary:
		d.flags["migrated.from_0"] = true
		return d}
	var migrated := SaveGame.read(PATH)
	SaveGame.migrations = {}
	_check(migrated.ok and migrated.flags.get("migrated.from_0") == true and migrated.flags.get("old") == true,
		"an old version goes through its migration step")
	GameState.flags = {}


## Same flags in, same decisions out, before and after a round trip (JSON would fail this: the
## director's gap and cooldown checks need ints).
func _test_logic() -> void:
	var events: Array[EventData] = []
	for file in DirAccess.get_files_at("res://data/events/"):
		if file.ends_with(".tres"):
			events.append(load("res://data/events/" + file))
	var start := {EventDirector.SEED: 1, "discovered.abandoned_camp": true, "world.berries_picked": true}
	var a := Flags.new(start.duplicate())
	var b := Flags.new(start.duplicate())
	var picks_a := []
	var picks_b := []
	for i in 8:
		var region := &"village" if i % 2 == 0 else &"forest"
		var ea := EventDirector.evaluate(events, a, region)
		picks_a.append(ea.id if ea else &"")
		SaveGame.write(PATH, b.data, Vector3.ZERO, 1) # b lives through a save every step
		b = Flags.new(SaveGame.read(PATH).flags)
		var eb := EventDirector.evaluate(events, b, region)
		picks_b.append(eb.id if eb else &"")
	_check(picks_a == picks_b and _same(a.data, b.data), "EventDirector decides identically through 8 save/load round trips %s" % [picks_a])
	_check(picks_a.has(&"glowing_fish") and picks_a.has(&"berries_regrow"), "the run exercised both events (fired, gap and cooldown)")
	_check(b.data[EventDirector.OPPORTUNITY] is int and b.data[EventDirector.LAST_FIRED] is int, "director counters stay ints")

	GameState.flags = {}
	var run := DialogueRunner.new(HEARTH, GameState)
	run.start()
	run.choose(0) # "What would it take?": takes the job
	GameState.set_flag("quest.common_room.has_timber")
	SaveGame.write(PATH, GameState.flags, Vector3.ZERO, 1)
	var q := Flags.new(SaveGame.read(PATH).flags)
	var same := true
	for quest: QuestData in [COMMON_ROOM, RING]:
		same = same and QuestTracker.is_active(quest, GameState) == QuestTracker.is_active(quest, q) \
			and QuestTracker.current_objective(quest, GameState) == QuestTracker.current_objective(quest, q) \
			and QuestTracker.outcome(quest, GameState) == QuestTracker.outcome(quest, q)
	_check(same and QuestTracker.is_active(COMMON_ROOM, q), "QuestTracker reads the same status after a round trip")
	GameState.flags = {}


func _test_world() -> void:
	# Outside in the village and in the forest: position, health, flags, no opportunity.
	for spot: Vector3 in [OUTSIDE, CAMP]:
		GameState.flags = {EventHost.LAST_REGION: "village", EventDirector.SEED: 1}
		var m := await _boot()
		var p := _player(m)
		p.global_position = spot
		await _physics(4)
		p.health = 7
		_check(m.save_game(), "saving at %s works" % spot)
		var saved: Dictionary = GameState.flags.duplicate()
		var at := p.global_position
		m = await _fresh_load(m)
		p = _player(m)
		await _physics(10)
		_check(p.global_position.distance_to(at) < 0.05, "loaded at the saved position (%s vs %s)" % [p.global_position, at])
		_check(p.health == 7, "health is restored")
		_check(_same(GameState.flags, saved), "flags are exactly the saved ones after load + 10 physics steps (no discovery, no opportunity)")
		_check(_hud(m)._message.modulate.a == 0.0 and _hud(m)._location.modulate.a == 0.0, "loading shows no message or place name")
		m.queue_free()
		await get_tree().process_frame

	# Inside the damaged guild.
	GameState.flags = {EventHost.LAST_REGION: "village", EventDirector.SEED: 1}
	var main := await _boot()
	_player(main).global_position = INSIDE
	await _physics(4)
	_check(main.save_game(), "saving inside the damaged guild works")
	main = await _fresh_load(main)
	await _physics(3)
	var hall: Node3D = main._world.get_node("Village/GuildHall")
	_check((hall.get_node("Damaged") as Node3D).visible and not (hall.get_node("Repaired") as Node3D).visible,
		"the damaged room loads damaged")
	_check(_cut_away(main), "loading inside the damaged guild comes back cut away with camera collision off")

	# Refusals: combat, dialogue, cinematic, test worlds.
	var player := _player(main)
	player.global_position = OUTSIDE
	await _physics(3)
	var wenna: Interactable = main._world.get_node("Village/WellKeeper/Talk")
	wenna.interact(player)
	await get_tree().process_frame
	_check(not player.input_enabled and not main.save_game(), "saving is refused during a conversation")
	main.queue_free()
	await get_tree().process_frame

	GameState.flags = {EventHost.LAST_REGION: "village", EventDirector.SEED: 1}
	main = await _boot()
	main._debug_start_combat()
	await _physics(3)
	var fighting: bool = main._world.find_children("*", "CombatArea").any(func(c: CombatArea) -> bool: return c.controller != null)
	_check(fighting and not main.save_game(), "saving is refused during combat")
	main.queue_free()
	await get_tree().process_frame

	GameState.flags = {EventHost.LAST_REGION: "village", EventDirector.SEED: 1}
	main = await _boot()
	main._test_cinematic()
	await _physics(2)
	_check(_rig(main).is_cinematic and not main.save_game(), "saving is refused during a cinematic")
	main._swap_world("res://scenes/world/camera_test.tscn")
	await _physics(2)
	_check(not main.save_game(), "saving is refused in a test world")
	_swap_back(main)

	# A corrupt save neither loads nor disturbs the running world, and stays on disk.
	await _physics(2)
	var world_before: Node = main._world
	var flags_before: Dictionary = GameState.flags.duplicate()
	_write_text("[save]\nversion=1\n[player\n")
	var bytes := FileAccess.get_file_as_bytes(PATH)
	_check(not main.load_game(), "a corrupt save doesn't load")
	_check(main._world == world_before and _same(GameState.flags, flags_before), "...and the running world and flags stay as they were")
	_check(_hud(main)._message.text == "The save file is damaged.", "...and the HUD says why")
	_check(FileAccess.get_file_as_bytes(PATH) == bytes, "...and the bad save isn't overwritten by the failed load")
	_remove(PATH)
	_check(not main.load_game() and _hud(main)._message.text == "No save to load.", "loading with no save says so and changes nothing")
	main.queue_free()
	await get_tree().process_frame


## Clean state -> timber, Wenna's coal, the hearth repair, the Glowing Fish, Maren -> save inside
## the repaired guild -> forget everything -> load in a fresh main -> all of it is back.
func _test_end_to_end() -> void:
	_remove(PATH)
	GameState.flags = {EventDirector.SEED: 1}
	var main := await _boot()
	var player := _player(main)
	var world: Node3D = main._world
	_talk(HEARTH, ["What would it take?"])
	player.global_position = CAMP # forest entry + camp discovery, for real
	await _physics(4)
	(world.get_node("Forest/AbandonedCamp/SalvageBoards") as Interactable).interact(player)
	player.global_position = OUTSIDE # back to the village: the Glowing Fish starts
	await _physics(4)
	_check(GameState.is_set("event.glowing_fish.fired"), "e2e: the Glowing Fish fired on the way back")
	_talk(WENNA, [])
	_talk(WENNA, ["The guild hearth needs a live coal."])
	_talk(HEARTH, ["Repair the common room."])
	_talk(LODGER, ["What brings you here?", "I'll go up and look."])
	_check(GameState.is_set("guild.common_room.repaired") and GameState.is_set("npc.lodger.told_island"), "e2e: the room is repaired and Maren has talked")
	player.global_position = INSIDE
	player.health = 9
	await _physics(4)
	var saved: Dictionary = GameState.flags.duplicate()
	var at := player.global_position
	_check(main.save_game(), "e2e: saving inside the repaired guild works")

	main = await _fresh_load(main)
	player = _player(main)
	await _physics(30)
	world = main._world
	var hall: Node3D = world.get_node("Village/GuildHall")
	_check(_same(GameState.flags, saved), "e2e: every flag and its type is back, and 30 steps later nothing has changed")
	_check(GameState.get_flag(EventDirector.OPPORTUNITY) is int and GameState.get_flag(EventDirector.SEED) is int
		and GameState.get_flag(EventDirector.LAST_FIRED) is int and GameState.get_flag(EventHost.LAST_REGION) == "village",
		"e2e: director seed, opportunity, last fired and last region survive as saved")
	_check(player.global_position.distance_to(at) < 0.05 and player.health == 9, "e2e: player position and health restored")
	_check((hall.get_node("Repaired") as Node3D).visible and not (hall.get_node("Damaged") as Node3D).visible, "e2e: repaired shown, damaged hidden")
	var lodger: Interactable = hall.get_node("Repaired/Lodger/Talk")
	_check(lodger.is_visible_in_tree() and lodger.can_process(), "e2e: the lodger is there and can be talked to")
	_check(_body_at(world, HALL + Vector3(0.8, 0.4, 0.4)), "e2e: the mended table is solid")
	_check(_cut_away(main), "e2e: inside the guild, cut away, camera collision off")
	_check(QuestTracker.outcome(COMMON_ROOM, GameState) != null and _opening(HEARTH) == &"warm" and _opening(LODGER) == &"again",
		"e2e: quest resolved and dialogue openings follow the loaded flags")
	var hud := _hud(main)
	_check(hud._message.modulate.a == 0.0 and hud._location.modulate.a == 0.0, "e2e: no announcement or place name from loading")
	GameState.set_flag("test.poke") # a stale quest cache would announce every quest now
	_check(hud._message.text == "", "e2e: the quest cache matches the loaded flags (a later flag change announces nothing)")
	main.queue_free()
	await get_tree().process_frame


# --- helpers ---------------------------------------------------------------------------------

func _boot() -> Node:
	var main := MAIN.instantiate()
	main.save_path = PATH
	add_child(main)
	await _physics(3)
	return main


## Frees `main`, forgets all flags (a new runtime) and loads the save into a new main scene
## straight away, as a launch would (before any physics step of the default spawn).
func _fresh_load(main: Node) -> Node:
	main.free()
	GameState.flags = {}
	var fresh := MAIN.instantiate()
	fresh.save_path = PATH
	add_child(fresh)
	_check(fresh.load_game(), "the save loads in a fresh main scene")
	await _physics(3)
	return fresh


func _swap_back(main: Node) -> void:
	main._swap_world(main.MAIN_WORLD)


func _cut_away(main: Node) -> bool:
	var hall: Node3D = main._world.get_node("Village/GuildHall")
	var arm: SpringArm3D = main._world.get_node("CameraRig/Pitch/SpringArm3D")
	return (hall.get_node("Interior") as InteriorZone).inside and not (hall.get_node("Cutaway") as Node3D).visible \
		and arm.collision_mask == 0


func _player(main: Node) -> Player:
	return main._world.get_node("Player")


func _rig(main: Node) -> CameraController:
	return main._world.get_node("CameraRig")


func _hud(main: Node) -> Node:
	return main.get_node("PixelView/SubViewport/ExplorationHUD")


func _rejected() -> bool:
	return not SaveGame.read(PATH).ok


func _write_text(text: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _write_cfg(sections: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for s in sections:
		for k in sections[s]:
			cfg.set_value(s, k, sections[s][k])
	cfg.save(PATH)


func _remove(path: String) -> void:
	for p in [path, path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## Same keys, same values, same types (== alone would call 1 and 1.0 equal).
func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k) or typeof(a[k]) != typeof(b[k]) or a[k] != b[k]:
			return false
	return true


func _body_at(world: Node3D, point: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collision_mask = 1
	return not world.get_world_3d().direct_space_state.intersect_point(query).is_empty()


## Runs a conversation on the real flags, picking replies by text; lines without replies continue.
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


func _physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame
	await get_tree().process_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAIL: " + what)
	else:
		print("PASS: " + what)


## Scratch flag store (same shape as GameState) so round-tripped copies can be driven side by side.
class Flags:
	var data: Dictionary
	func _init(d: Dictionary) -> void:
		data = d
	func get_flag(key: String, default: Variant = null) -> Variant:
		return data.get(key, default)
	func set_flag(key: String, value: Variant = true) -> void:
		var old: Variant = data.get(key)
		if typeof(old) == typeof(value) and old == value:
			return
		data[key] = value
	func is_set(key: String) -> bool:
		var v: Variant = data.get(key, false)
		return v is bool and v
