extends Node
## WorldEventDirector: event data validates, selection is deterministic and respects eligibility,
## the two M10 events work through the real data, and the director works in the real region.
## Deterministic only: fixed seeds, no probability sweeps.
##   godot --headless --path . res://tests/test_events.tscn

const FISH := preload("res://data/events/glowing_fish.tres")
const BERRIES := preload("res://data/events/berries_regrow.tres")
const WENNA := preload("res://data/dialogue/well_keeper.tres")
const BUCKET := preload("res://data/dialogue/fish_bucket.tres")
const CAMP := "discovered.abandoned_camp"
const SHRINE := "world.shrine_awakened"
# Found once for opportunity 1 (see DECISIONS, M10): which Glowing Fish variant each seed picks.
const SEED_SPIRIT := 1 ## no shrine -> sleeping_spirit
const SEED_LEAK := 3 ## no shrine -> magical_leak
const SEED_ANOMALY := 8 ## shrine awake -> world_anomaly

var _failures := 0


func _ready() -> void:
	_test_all_events_validate()
	_test_validator_rejects()
	_test_eligibility()
	_test_determinism_and_variants()
	_test_glowing_fish()
	_test_berries()
	await _test_in_world()
	print("events: %s (%d failures)" % ["OK" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _test_all_events_validate() -> void:
	var files := DirAccess.get_files_at("res://data/events")
	_check(files.size() >= 2, "data/events has the M10 events")
	for file in files:
		if file.ends_with(".tres"):
			var event := load("res://data/events/" + file) as EventData
			var errors := event.validate() if event else PackedStringArray(["not an EventData"])
			_check(errors.is_empty(), "%s validates %s" % [file, errors])


func _test_validator_rejects() -> void:
	var cases := {
		"weight 0": func(e: EventData) -> void: e.weight = 0,
		"cooldown event without a cooldown": func(e: EventData) -> void: e.repeat = EventData.Repeat.COOLDOWN,
		"once event with a cooldown": func(e: EventData) -> void: e.cooldown = 2,
		"no region": func(e: EventData) -> void: e.region = &"",
		"non-flag start": func(e: EventData) -> void: e.start[0].kind = DialogueConsequence.Kind.EVENT,
		"variant weight 0": func(e: EventData) -> void: e.variants = [_variant(&"a", 0)],
		"all variants conditional": func(e: EventData) -> void: e.variants = [_variant(&"a", 1, [_cond("x")])],
		"changes nothing": func(e: EventData) -> void: e.start = [],
	}
	for what in cases:
		var e := _event(&"t", &"village")
		cases[what].call(e)
		_check(not e.validate().is_empty(), "validator rejects: " + what)


func _test_eligibility() -> void:
	var flags := {}
	var only := _event(&"only", &"village")
	var gated := _event(&"gated", &"village", [_cond("some.fact")])
	var elsewhere := _event(&"elsewhere", &"forest")
	var events: Array[EventData] = [only, gated, elsewhere]
	var ok := EventDirector.eligible(events, _store(flags), &"village", 1)
	_check(ok == [only], "only same-region events whose prerequisites pass are eligible")
	_check(EventDirector.choose(ok, 5, 1, &"village") == only, "the one eligible event is chosen")
	_check(EventDirector.choose([], 5, 1, &"village") == null, "nothing eligible, nothing chosen")

	# ONCE: never again after firing.
	EventDirector.fire(only, null, _store(flags), 1)
	_check(not EventDirector.eligible(events, _store(flags), &"village", 50).has(only), "a ONCE event never fires twice")

	# COOLDOWN: counted in opportunities since it last fired.
	var again := _event(&"again", &"forest")
	again.repeat = EventData.Repeat.COOLDOWN
	again.cooldown = 3
	var forest: Array[EventData] = [again]
	EventDirector.fire(again, null, _store(flags), 10)
	_check(EventDirector.eligible(forest, _store(flags), &"forest", 12).is_empty(), "inside the cooldown it is not eligible")
	_check(EventDirector.eligible(forest, _store(flags), &"forest", 13) == forest, "after the cooldown it is eligible again")

	# Director-wide gap: the opportunity right after any event stays quiet.
	flags = {EventDirector.LAST_FIRED: 4, EventDirector.OPPORTUNITY: 4}
	var fresh: Array[EventData] = [_event(&"fresh", &"village")]
	_check(EventDirector.evaluate(fresh, _store(flags), &"village") == null, "no event on the opportunity right after one fired")
	_check(EventDirector.evaluate(fresh, _store(flags), &"village") != null, "one opportunity later it can fire")
	flags = {EventDirector.LAST_FIRED: 4, EventDirector.OPPORTUNITY: 4}
	_check(EventDirector.evaluate(fresh, _store(flags), &"village", true) != null, "the debug trigger ignores the gap")
	flags = {}
	_check(EventDirector.evaluate([gated] as Array[EventData], _store(flags), &"village", true) == null, "...but never the prerequisites")


func _test_determinism_and_variants() -> void:
	var no_shrine := _store({})
	var picks := []
	for i in 2:
		picks.append(EventDirector.choose_variant(FISH, no_shrine, SEED_SPIRIT, 1).id)
	_check(picks == [&"sleeping_spirit", &"sleeping_spirit"], "same seed and state give the same variant")
	_check(EventDirector.choose_variant(FISH, no_shrine, SEED_LEAK, 1).id == &"magical_leak", "a different fixed seed gives a different valid variant")
	for seed in range(1, 13):
		_check(EventDirector.choose_variant(FISH, no_shrine, seed, 1).id != &"world_anomaly", "seed %d: no world anomaly before the shrine wakes" % seed)
	_check(EventDirector.choose_variant(FISH, _store({SHRINE: true}), SEED_ANOMALY, 1).id == &"world_anomaly", "with the shrine awake the anomaly variant can be chosen")

	# Whole evaluation is reproducible from the flags alone (what a save would hold).
	var a := {EventDirector.SEED: SEED_LEAK, CAMP: true}
	var b := a.duplicate()
	var fa := EventDirector.evaluate([FISH] as Array[EventData], _store(a), &"village")
	var fb := EventDirector.evaluate([FISH] as Array[EventData], _store(b), &"village")
	_check(fa == FISH and fb == FISH and a == b, "same flags -> same event, same variant, same bookkeeping")


func _test_glowing_fish() -> void:
	var events: Array[EventData] = [FISH, BERRIES]
	GameState.flags = {EventDirector.SEED: SEED_LEAK}
	_check(EventDirector.evaluate(events, GameState, &"village") == null, "no fish before the forest camp is discovered")
	GameState.flags = {EventDirector.SEED: SEED_LEAK, CAMP: true}
	_check(EventDirector.evaluate(events, GameState, &"forest") == null, "fish only happen in the village")
	GameState.flags = {EventDirector.SEED: SEED_LEAK, CAMP: true}
	_check(EventDirector.evaluate(events, GameState, &"village") == FISH, "returning to the village after the camp starts the fish")
	var variant: String = GameState.get_flag("event.glowing_fish.variant")
	_check(GameState.is_set("world.well_fish") and variant == "magical_leak", "fish are in the well with a stored variant")

	# Variant-specific dialogue: exactly Wenna's matching line, only while the fish are there.
	GameState.set_flag("npc.well_keeper.met")
	_check(_talk_path(WENNA, ["Those fish in the well..."]) == [&"again", &"fish_magical_leak"], "Wenna explains this variant")
	for other in ["sleeping_spirit", "world_anomaly"]:
		GameState.set_flag("event.glowing_fish.variant", other)
		_check(_talk_path(WENNA, ["Those fish in the well..."]).back() == StringName("fish_" + other), "Wenna's line follows the variant (%s)" % other)
		_check(_opening(BUCKET) == StringName(other), "the bucket describes the variant (%s)" % other)
	GameState.set_flag("event.glowing_fish.variant", variant)

	# Investigation and resolution through the bucket.
	_talk_path(BUCKET, ["Release them into the pond."])
	_check(GameState.is_set("world.pond_glows") and GameState.is_set("event.glowing_fish.resolved") and not GameState.is_set("world.well_fish"),
		"releasing the fish resolves the event: pond glows, well empties")
	_check(not _replies(WENNA).has("Those fish in the well..."), "Wenna's fish line is gone afterwards")
	_check(_opening(BUCKET) == &"after", "the bucket remembers")
	for i in 5:
		GameState.set_flag(EventHost.LAST_REGION, "")
		EventDirector.evaluate(events, GameState, &"village")
	_check(GameState.get_flag("event.glowing_fish.last_opportunity") == 1, "the fish never return")
	GameState.flags = {}


func _test_berries() -> void:
	var events: Array[EventData] = [FISH, BERRIES]
	GameState.flags = {EventDirector.SEED: 7}
	_check(EventDirector.evaluate(events, GameState, &"forest") == null, "berries don't regrow before anyone picked them")
	GameState.set_flag("berry_bush_0.used")
	GameState.set_flag("berry_bush_2.used")
	GameState.set_flag("world.berries_picked") # what PickBerries' sets_flag writes
	_check(EventDirector.evaluate(events, GameState, &"forest") == BERRIES, "after picking, the forest can fruit again")
	_check(not GameState.is_set("berry_bush_0.used") and not GameState.is_set("berry_bush_2.used") and not GameState.is_set("world.berries_picked"),
		"all bushes are pickable again and the prerequisite resets")
	var fired: int = GameState.get_flag("event.berries_regrow.last_opportunity")
	GameState.set_flag("world.berries_picked")
	var results := []
	for i in 3:
		results.append(EventDirector.evaluate(events, GameState, &"forest") == BERRIES)
	_check(results == [false, false, true], "picked again: quiet during the cooldown, eligible after 3 opportunities (fired at %d)" % fired)
	GameState.flags = {}


## The real region: EventRegions -> EventHost -> director -> StateToggles, safety and reloads.
func _test_in_world() -> void:
	# As if the player had been standing in the village already (spawning there isn't a region change).
	GameState.flags = {EventDirector.SEED: SEED_LEAK, CAMP: true, EventHost.LAST_REGION: "village"}
	var ui := DialogueUI.new()
	add_child(ui)
	var world: Node3D = load("res://scenes/world/slice_region.tscn").instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().process_frame
	var host: EventHost = world.get_node("Events")
	var player: Player = world.get_node("Player")
	var well_fish: Node3D = world.get_node("Village/WellFish")
	_check(host.player == player and host.camera_rig != null, "the event host is wired to the player and camera")
	_check(not well_fish.visible, "no fish at the start")

	# A conversation is open: entering a new region is not an opportunity.
	GameState.set_flag(EventHost.LAST_REGION, "forest")
	world.get_node("Village/WellKeeper/Talk").interact(player)
	var before: Variant = GameState.get_flag(EventDirector.OPPORTUNITY)
	host.on_region_entered(&"village")
	_check(GameState.get_flag(EventDirector.OPPORTUNITY) == before and not well_fish.visible, "nothing happens while talking")
	ui.leave()

	# Walking back into the village is: the fish appear.
	host.on_region_entered(&"village")
	_check(well_fish.visible and (world.get_node("Village/FishBucket/Glow") as Node3D).visible, "entering the village starts the fish; well and bucket glow")
	var opportunity: Variant = GameState.get_flag(EventDirector.OPPORTUNITY)
	host.on_region_entered(&"village")
	_check(GameState.get_flag(EventDirector.OPPORTUNITY) == opportunity, "re-entering the same region is not a new opportunity")

	# Investigate, resolve, reload: the consequence persists and nothing new starts.
	(world.get_node("Village/FishBucket") as Interactable).interact(player)
	ui.confirm(0) # Release them into the pond.
	ui.confirm(0) # continue
	_check((world.get_node("Village/PondGlow") as Node3D).visible and not well_fish.visible, "releasing the fish lights the pond in the world")
	world.queue_free()
	await get_tree().process_frame
	world = load("res://scenes/world/slice_region.tscn").instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().process_frame
	_check((world.get_node("Village/PondGlow") as Node3D).visible and not (world.get_node("Village/WellFish") as Node3D).visible,
		"after a reload the pond still glows and the well stays empty")
	_check(GameState.get_flag(EventDirector.OPPORTUNITY) == opportunity, "reloading inside the village is not an opportunity")
	world.queue_free()
	ui.queue_free()
	await get_tree().process_frame
	GameState.flags = {}


func _store(flags: Dictionary) -> Flags:
	return Flags.new(flags)


## Minimal flag store over a plain dictionary (the director only needs get_flag/set_flag).
class Flags:
	var data: Dictionary
	func _init(d: Dictionary) -> void:
		data = d
	func get_flag(key: String, default: Variant = null) -> Variant:
		return data.get(key, default)
	func set_flag(key: String, value: Variant = true) -> void:
		data[key] = value


func _event(id: StringName, region: StringName, conditions: Array = []) -> EventData:
	var e := EventData.new()
	e.id = id
	e.region = region
	e.conditions.assign(conditions)
	var set := DialogueConsequence.new()
	set.key = "t." + id
	e.start.assign([set])
	return e


func _variant(id: StringName, weight: int, conditions: Array = []) -> EventVariant:
	var v := EventVariant.new()
	v.id = id
	v.weight = weight
	v.conditions.assign(conditions)
	return v


func _cond(flag: String) -> DialogueCondition:
	var c := DialogueCondition.new()
	c.flag = flag
	return c


## Runs a conversation picking replies by text; returns the ids of the lines shown.
func _talk_path(data: DialogueData, picks: Array) -> Array:
	var run := DialogueRunner.new(data, GameState)
	var path := []
	if not run.start():
		return path
	var queue := picks.duplicate()
	while not run.is_finished() and path.size() < 20:
		path.append(run.node.id)
		var replies := run.choices().map(func(c: DialogueChoice) -> String: return c.text)
		if replies.is_empty():
			run.advance()
		elif queue.is_empty() or replies.find(queue.front()) < 0:
			run.leave()
		else:
			run.choose(replies.find(queue.pop_front()))
	return path


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
