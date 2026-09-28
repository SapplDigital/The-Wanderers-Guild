class_name CombatController
extends Node
## Runs one fight on a CombatArena: player input (cursor, abilities, confirm), enemy turns,
## and playback of CombatState's event log as small animations. No rules live here.

signal finished(winner: StringName)

enum Mode { BUSY, MOVE, TARGET }

const STEP_TIME := 0.16
const TACTICAL_ZOOM := 19.0
const COLOR_GRID := Color(0.95, 0.9, 0.8, 0.07)
const COLOR_MOVE := Color(0.35, 0.65, 1.0, 0.32)
const COLOR_PATH := Color(1.0, 0.85, 0.4, 0.55)
const COLOR_RANGE := Color(1.0, 0.4, 0.3, 0.07)
const COLOR_TARGET := Color(1.0, 0.35, 0.3, 0.55)
const COLOR_ACTIVE := Color(1.0, 1.0, 1.0, 0.35)
const COLOR_CURSOR := Color(1.0, 1.0, 1.0, 0.6)
const COLOR_COVER := Color(0.6, 0.62, 0.7, 0.3)
const COLOR_MUD := Color(0.55, 0.38, 0.22, 0.3)
const COLOR_WATER := Color(0.3, 0.55, 0.8, 0.3)

var arena: CombatArena
var state: CombatState
var player_unit: CombatUnit
var mode := Mode.BUSY
var ability: AbilityData ## selected in TARGET mode
var cursor := Vector2i.ZERO

var _overlay: GridOverlay
var _focus := Node3D.new() ## what the camera follows during the fight
var _hud: Node
var _ended := false
var _previous_camera_target: Node3D


func begin(combat_arena: CombatArena, grid: CombatGrid, units: Array[CombatUnit]) -> void:
	arena = combat_arena
	state = CombatState.new(grid, units, arena.rng_seed)
	player_unit = units[0]
	_overlay = GridOverlay.new()
	arena.add_child(_overlay)
	_overlay.setup(arena)
	arena.add_child(_focus)
	arena.player.input_enabled = false
	for u in units:
		var view := arena.view_for(u)
		var tw := create_tween()
		tw.tween_property(view, "global_position", arena.cell_center(u.cell), 0.3)
		_face(view, arena.cell_center(state.foes_of(u)[0].cell) if state.foes_of(u) else view.global_position)
	_focus.global_position = arena.cell_center(player_unit.cell)
	_previous_camera_target = arena.camera_rig.target
	arena.camera_rig.target = _focus
	arena.camera_rig.set_zoom(TACTICAL_ZOOM)
	get_tree().call_group("hud", "set_combat_mode", true)
	_hud = get_tree().get_first_node_in_group("combat_hud")
	_hud.open(self)
	_hud.log_line("The boars notice you.")
	await _play(state.start())
	_next()


# ---------------------------------------------------------------- turn flow

func _next() -> void:
	if _ended:
		return
	var unit := state.current()
	if unit.team == &"player":
		mode = Mode.MOVE
		cursor = unit.cell
		_refresh()
		return
	mode = Mode.BUSY
	_refresh()
	await get_tree().create_timer(0.45).timeout
	await _play(BasicBrain.take_turn(state, unit)) # M7: pick the brain by unit.data.ai_profile
	await _end_turn()


func _end_turn() -> void:
	mode = Mode.BUSY
	await _play(state.end_turn())
	_next()


## Runs a player command, then either ends the fight or hands control back.
func _run(events: Array) -> void:
	mode = Mode.BUSY
	await _play(events)
	if state.outcome() != &"":
		await _play(state.end_turn())
	elif not _ended:
		mode = Mode.MOVE
		_refresh()


## Debug: every enemy drops, the fight ends through the normal end-of-turn path.
func debug_win() -> void:
	for u in state.units:
		if u.team != &"player" and u.is_alive():
			u.hp = 0
			state.grid.occupant.erase(u.cell)
			arena.view_for(u).hide()
	mode = Mode.BUSY
	_play(state.end_turn())


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.BUSY:
		return
	var handled := true
	if event is InputEventMouseMotion:
		var c := _cell_under_mouse(event.position)
		if state.grid.in_bounds(c) and c != cursor:
			cursor = c
			_refresh()
		handled = false # let the camera see mouse motion too
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_confirm()
	elif event.is_action_pressed("interact"):
		_confirm()
	elif event.is_action_pressed("ui_cancel") and mode == Mode.TARGET:
		mode = Mode.MOVE
		_refresh()
	elif event.is_action_pressed("combat_end_turn"):
		_end_turn()
	elif event.is_action_pressed("combat_ability_1"):
		_select_ability(0)
	elif event.is_action_pressed("combat_ability_2"):
		_select_ability(1)
	elif event.is_action_pressed("combat_ability_3"):
		_select_ability(2)
	elif _cursor_step(event) != Vector2i.ZERO:
		var next := cursor + _cursor_step(event)
		if state.grid.in_bounds(next):
			cursor = next
			_refresh()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _confirm() -> void:
	var target: CombatUnit = state.grid.occupant.get(cursor)
	if mode == Mode.TARGET:
		if target and target in state.targets_for(player_unit, ability):
			_run(state.use(player_unit, ability, target))
		return
	# MOVE mode: clicking a foe you can already hit is a shortcut for your first attack.
	var first: AbilityData = player_unit.data.abilities[0]
	if target and target.team != &"player" and state.can_use(player_unit, first) and target in state.targets_for(player_unit, first):
		_run(state.use(player_unit, first, target))
	elif state.reachable_for(player_unit).cost.has(cursor) and cursor != player_unit.cell:
		_run(state.move(player_unit, cursor))


func _select_ability(i: int) -> void:
	var abilities := player_unit.data.abilities
	if i >= abilities.size():
		return
	var a: AbilityData = abilities[i]
	if not state.can_use(player_unit, a):
		_hud.log_line("No %s left this turn." % ("bonus action" if a.cost == AbilityData.Cost.BONUS else "action"))
		return
	if a.kind == AbilityData.Kind.SELF_BUFF:
		_run(state.use(player_unit, a))
		return
	if mode == Mode.TARGET and ability == a:
		mode = Mode.MOVE # pressing the same ability again cancels
	else:
		mode = Mode.TARGET
		ability = a
		var targets := state.targets_for(player_unit, a)
		if targets:
			cursor = targets[0].cell # snap to the first valid target (pad-friendly)
	_refresh()


## Camera-relative cursor movement, snapped to the grid axes.
func _cursor_step(event: InputEvent) -> Vector2i:
	var v := Vector2.ZERO
	if event.is_action_pressed("move_forward"): v.y -= 1
	if event.is_action_pressed("move_back"): v.y += 1
	if event.is_action_pressed("move_left"): v.x -= 1
	if event.is_action_pressed("move_right"): v.x += 1
	if v == Vector2.ZERO:
		return Vector2i.ZERO
	var world := Vector3(v.x, 0, v.y).rotated(Vector3.UP, arena.camera_rig.global_rotation.y)
	return Vector2i(signi(roundi(world.x)), 0) if absf(world.x) > absf(world.z) else Vector2i(0, signi(roundi(world.z)))


func _cell_under_mouse(screen_pos: Vector2) -> Vector2i:
	var cam := get_viewport().get_camera_3d()
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.001:
		return Vector2i(-1, -1)
	return arena.world_to_cell(from + dir * (-from.y / dir.y))


# ---------------------------------------------------------------- presentation

func _refresh() -> void:
	var colors := {}
	for y in arena.rows:
		for x in arena.cols:
			var c := Vector2i(x, y)
			match state.grid.kind(c):
				CombatGrid.Kind.OPEN:
					colors[c] = {&"mud": COLOR_MUD, &"water": COLOR_WATER}.get(state.grid.terrain(c), COLOR_GRID)
				CombatGrid.Kind.COVER:
					colors[c] = COLOR_COVER
	var unit := state.current()
	if mode == Mode.MOVE:
		var flood := state.reachable_for(unit)
		for c in flood.cost:
			colors[c] = COLOR_MOVE
		for c in CombatGrid.path_to(flood, cursor):
			colors[c] = COLOR_PATH
	elif mode == Mode.TARGET:
		for y in arena.rows:
			for x in arena.cols:
				var c := Vector2i(x, y)
				if state.in_range(unit.cell, c, ability):
					colors[c] = COLOR_RANGE
		for t in state.targets_for(unit, ability):
			colors[t.cell] = COLOR_TARGET
	colors[unit.cell] = COLOR_ACTIVE
	if mode != Mode.BUSY:
		colors[cursor] = COLOR_CURSOR
		_focus.global_position = _focus.global_position.lerp(arena.cell_center(cursor), 0.35)
	_overlay.paint(colors)
	_hud.refresh()


func hovered_unit() -> CombatUnit:
	return state.grid.occupant.get(cursor)


func prediction() -> Dictionary:
	var target := hovered_unit()
	if mode == Mode.TARGET and target and target in state.targets_for(player_unit, ability):
		return state.predict(player_unit, ability, target)
	return {}


func _play(events: Array) -> void:
	for e in events:
		match e.type:
			"turn_start":
				_focus_on(e.unit)
				_hud.log_line("Round %d: %s's turn." % [state.round_number, e.unit.data.display_name])
				_hud.refresh()
				await get_tree().create_timer(0.25).timeout
			"step":
				var view := arena.view_for(e.unit)
				var to := arena.cell_center(e.cell)
				_face(view, to)
				create_tween().tween_property(view, "global_position", to, STEP_TIME)
				_focus.global_position = to
				var t: StringName = state.grid.terrain(e.cell)
				AudioManager.play_at(StringName("step_" + (t if t != &"" else &"grass")), view)
				await get_tree().create_timer(STEP_TIME).timeout
			"attack":
				await _animate_attack(e)
			"buff":
				_float_text(arena.view_for(e.unit), e.ability.display_name, Color(0.6, 0.9, 1.0))
				AudioManager.play(&"ui_confirm")
				_hud.log_line("%s uses %s." % [e.unit.data.display_name, e.ability.display_name])
				await get_tree().create_timer(0.35).timeout
			"defeated":
				var view := arena.view_for(e.unit)
				_hud.log_line("%s is down." % e.unit.data.display_name)
				if e.unit.team != &"player":
					var tw := create_tween()
					tw.tween_property(view, "scale", Vector3(1, 0.1, 1), 0.4)
					tw.tween_callback(view.hide)
				await get_tree().create_timer(0.4).timeout
			"combat_end":
				_finish(e.winner)
		_hud.refresh()


func _animate_attack(e: Dictionary) -> void:
	var user_view := arena.view_for(e.user)
	var target_view := arena.view_for(e.target)
	_face(user_view, target_view.global_position)
	var home := arena.cell_center(e.user.cell)
	var lunge := home.lerp(target_view.global_position, 0.3 if e.ability.range_max <= 1 else 0.08)
	var tw := create_tween()
	tw.tween_property(user_view, "global_position", lunge, 0.1)
	tw.tween_property(user_view, "global_position", home, 0.18)
	await get_tree().create_timer(0.1).timeout
	var prefix := "Reaction! " if e.reaction else ""
	if e.hit:
		AudioManager.play_at(&"combat_hit", target_view)
		_float_text(target_view, ("CRIT -%d" if e.crit else "-%d") % e.damage, Color(1, 0.55, 0.4))
		_hud.log_line("%s%s: %s rolls %d+%d=%d vs %d. Hit for %d%s." % [prefix, e.ability.display_name,
			e.user.data.display_name, e.roll, e.total - e.roll, e.total, e.defense, e.damage, " (critical)" if e.crit else ""])
		if e.ability.applies_status and e.target.is_alive():
			_float_text(target_view, e.ability.applies_status.display_name, Color(1, 0.95, 0.6), 0.5)
	else:
		AudioManager.play_at(&"combat_miss", target_view)
		_float_text(target_view, "miss", Color(0.8, 0.8, 0.85))
		_hud.log_line("%s%s: %s rolls %d+%d=%d vs %d. Miss." % [prefix, e.ability.display_name,
			e.user.data.display_name, e.roll, e.total - e.roll, e.total, e.defense])
	if target_view is UnitView:
		target_view.refresh()
	if e.target == player_unit:
		arena.player.health = e.target.hp
	await get_tree().create_timer(0.55).timeout


func _float_text(view: Node3D, text: String, color: Color, rise_from := 1.9) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0012
	label.font_size = 12
	label.outline_size = 4
	label.modulate = color
	label.outline_modulate = Color(0.08, 0.07, 0.1)
	arena.add_child(label)
	label.global_position = view.global_position + Vector3.UP * rise_from
	var tw := create_tween().set_parallel()
	tw.tween_property(label, "global_position:y", label.global_position.y + 0.9, 1.1)
	tw.tween_property(label, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tw.chain().tween_callback(label.queue_free)


func _focus_on(unit: CombatUnit) -> void:
	_focus.global_position = arena.cell_center(unit.cell)


func _face(view: Node3D, point: Vector3) -> void:
	var to := point - view.global_position
	if Vector2(to.x, to.z).length() < 0.05:
		return
	var yaw := atan2(-to.x, -to.z)
	if view is Player:
		view.get_node("Visual").rotation.y = yaw
	else:
		view.rotation.y = yaw


func _finish(winner: StringName) -> void:
	if _ended:
		return
	_ended = true
	mode = Mode.BUSY
	_overlay.queue_free()
	_focus.queue_free()
	arena.camera_rig.target = _previous_camera_target
	arena.player.input_enabled = true
	_hud.close()
	get_tree().call_group("hud", "set_combat_mode", false)
	finished.emit(winner)
