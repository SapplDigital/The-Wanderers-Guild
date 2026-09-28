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

	_test_recovery(player)
	await _test_edge(world, player)

	print("exploration loop: %s (%d failures)" % ["OK" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


## M14: HP comes back slowly while exploring, never in a fight/conversation/cinematic or at 0 HP.
func _test_recovery(player: Player) -> void:
	var step := player.regen_interval
	player.health = 6
	player._recover(step * 0.5)
	_check(player.health == 6, "no HP before a full interval")
	player._recover(step * 0.5 + 0.01)
	_check(player.health == 7, "one HP per interval while exploring")
	player.input_enabled = false # fight, conversation or cinematic
	player._recover(step * 10.0)
	_check(player.health == 7, "no recovery while input belongs to a fight, conversation or cinematic")
	player.input_enabled = true
	player._recover(step * 0.9)
	player.input_enabled = false
	player._recover(0.0)
	player.input_enabled = true
	player._recover(step * 0.2)
	_check(player.health == 7, "a partial interval doesn't carry over a fight or conversation")
	player.health = 0
	player._recover(step * 2.0)
	_check(player.health == 0, "no recovery at 0 HP")
	player.health = player.max_health
	player._recover(step * 2.0)
	_check(player.health == player.max_health, "never above max")


## M14: the region is finite. A wall on layer 3 (player only) surrounds everything; the camera and
## combat scans (layer 1) never see it, and no place the slice sends you to lies behind it.
func _test_edge(world: Node, player: Player) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := (world as Node3D).get_world_3d().direct_space_state
	var from := Vector3(0, 1, -60) # the middle of the region
	for i in 8:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 250.0, 4))
		_check(not hit.is_empty(), "the edge closes the region toward %d deg" % (45 * i))
	for path in ["Player", "Village/GuildDoor", "Village/Well", "Village/NoticeBoard", "Village/GuildHall",
			"Forest/AbandonedCamp/CampZone", "Forest/HiddenHollow/HollowZone", "Forest/CombatClearing/CombatArea",
			"Forest/MidgeStones/CombatArea", "Forest/MidgeStones/Hoard", "Forest/OverlookReveal",
			"Landmarks/Ruin", "Landmarks/GateGuardian/CombatArea"]:
		var at := (world.get_node(path) as Node3D).global_position
		var to := Vector3(at.x, 1, at.z)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 4))
		var hit_back := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-8, 1, 1), to, 4))
		_check(hit.is_empty() and hit_back.is_empty(), "%s is inside the edge" % path)
	_check(player.collision_mask & 4 and not (world.get_node("CameraRig/Pitch/SpringArm3D") as SpringArm3D).collision_mask & 4,
		"the player collides with the edge, the camera doesn't")
	var wall := world.get_node("Edge/Wall") as StaticBody3D
	_check(wall.collision_layer == 4, "the edge is on its own layer (combat scans layer 1)")
	for area in world.find_children("*", "CombatArea"):
		var c := (area as Node3D).global_position
		var probe := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = area.radius + 2.0
		probe.shape = sphere
		probe.transform = Transform3D(Basis(), c + Vector3.UP)
		probe.collision_mask = 1
		var edge_trees := space.intersect_shape(probe, 64).filter(func(h: Dictionary) -> bool:
			return (h.collider as Node).get_parent().name == "Trees" and (h.collider as Node).get_parent().get_parent().name == "Edge")
		_check(edge_trees.is_empty(), "no edge tree inside %s's fight" % area.get_parent().name)


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
