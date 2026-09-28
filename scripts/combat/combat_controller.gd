class_name CombatController
extends Node
## Runs one fight in a CombatArea: player input (a free cursor point in the world, abilities,
## confirm), enemy turns, and playback of CombatState's event log. No rules live here.

signal finished(winner: StringName)

enum Mode { BUSY, MOVE, TARGET }

const WALK_SPEED := 4.0 ## m/s for playback
const COMBAT_ZOOM := 14.0 ## a little further out than exploration, still 3/4
const CURSOR_SPEED := 6.0 ## m/s for stick/keyboard cursor
const STEP_EVERY := 0.8 ## metres between footstep sounds
const HOVER_RADIUS := 0.9 ## cursor this close to a unit hovers it
const REPLAN_DISTANCE := 0.08

const C_RANGE := Color(0.75, 0.88, 1.0, 0.35)
const C_PATH := Color(1.0, 0.95, 0.8, 0.9)
const C_TOO_FAR := Color(1.0, 0.45, 0.35, 0.8)
const C_THREAT := Color(1.0, 0.45, 0.35, 0.3)
const C_THREAT_HOT := Color(1.0, 0.35, 0.25, 0.95)
const C_OBSTACLE := Color(0.8, 0.8, 0.9, 0.3)
const C_TARGET := Color(1.0, 0.7, 0.35, 0.85)
const C_LINE_CLEAR := Color(1.0, 0.95, 0.8, 0.85)
const C_LINE_COVER := Color(1.0, 0.85, 0.3, 0.9)
const C_LINE_BLOCKED := Color(1.0, 0.35, 0.3, 0.9)

var area: CombatArea
var state: CombatState
var player_unit: CombatUnit
var mode := Mode.BUSY
var ability: AbilityData ## selected in TARGET mode
var target: CombatUnit ## selected in TARGET mode
var cursor := Vector3.ZERO
var hovered: CombatUnit
var plan := {} ## movement preview for the cursor (CombatState.plan_move)

var _overlay: TacticalOverlay
var _focus := Node3D.new() ## what the camera follows during the fight
var _hud: Node
var _ended := false
var _previous_camera_target: Node3D
var _planned_at := Vector3.INF
var _mouse_active := false


func begin(combat_area: CombatArea, space: CombatSpace, units: Array[CombatUnit]) -> void:
	area = combat_area
	state = CombatState.new(space, units, area.rng_seed)
	player_unit = units[0]
	_overlay = TacticalOverlay.new()
	_overlay.space = space
	area.add_child(_overlay)
	area.add_child(_focus)
	area.player.input_enabled = false
	for u in units: # everyone settles onto their rule position and faces the fight
		var view := area.view_for(u)
		create_tween().tween_property(view, "global_position", u.position, 0.25)
		var foes := state.foes_of(u)
		if foes:
			_face(view, foes[0].position)
	_focus.global_position = player_unit.position
	_previous_camera_target = area.camera_rig.target
	area.camera_rig.target = _focus
	area.camera_rig.set_zoom(COMBAT_ZOOM)
	get_tree().call_group("hud", "set_combat_mode", true)
	_hud = get_tree().get_first_node_in_group("combat_hud")
	_hud.open(self)
	if area.encounter.engage_message != "":
		_hud.log_line(area.encounter.engage_message)
	AudioManager.play(&"turn_start")
	await _play(state.start())
	_next()


# ---------------------------------------------------------------- turn flow

func _next() -> void:
	if _ended:
		return
	var unit := state.current()
	if unit.team == &"player":
		mode = Mode.MOVE
		cursor = unit.position
		_planned_at = Vector3.INF
		_overlay.fade_in()
		_refresh()
		return
	mode = Mode.BUSY
	_overlay.fade_out()
	_refresh()
	await get_tree().create_timer(0.4).timeout
	await _play(BrainDispatcher.take_turn(state, unit))
	await _end_turn()


func _end_turn() -> void:
	mode = Mode.BUSY
	_overlay.fade_out()
	await _play(state.end_turn())
	_next()


## Runs a player command, then either ends the fight or hands control back.
func _run(events: Array) -> void:
	mode = Mode.BUSY
	_overlay.fade_out()
	await _play(events)
	if state.outcome() != &"":
		await _play(state.end_turn())
	elif not _ended:
		mode = Mode.MOVE
		cursor = player_unit.position
		_planned_at = Vector3.INF
		_overlay.fade_in()
		_refresh()


## Debug: every enemy drops, the fight ends through the normal end-of-turn path.
func debug_win() -> void:
	for u in state.units:
		if u.team != &"player" and u.is_alive():
			u.hp = 0
			area.view_for(u).hide()
	mode = Mode.BUSY
	_play(state.end_turn())


# ---------------------------------------------------------------- input

func _process(delta: float) -> void:
	if mode == Mode.BUSY:
		return
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if mode == Mode.MOVE and v.length() > 0.1:
		_mouse_active = false
		var dir := Vector3(v.x, 0, v.y).rotated(Vector3.UP, area.camera_rig.global_rotation.y)
		_set_cursor(cursor + dir * CURSOR_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.BUSY:
		return
	var handled := true
	if event is InputEventMouseMotion:
		_mouse_active = true
		var p: Variant = _ground_under_mouse(event.position)
		if p != null:
			_set_cursor(p)
		handled = false # the camera still needs mouse motion (orbit)
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
	elif mode == Mode.TARGET and (event.is_action_pressed("move_right") or event.is_action_pressed("move_left")):
		_cycle_target(1 if event.is_action_pressed("move_right") else -1)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _confirm() -> void:
	if mode == Mode.TARGET:
		if target and target in state.targets_for(player_unit, ability):
			_run(state.use(player_unit, ability, target))
		return
	# MOVE mode: confirming on a foe you can already hit is a shortcut for your first attack.
	var first: AbilityData = player_unit.data.abilities[0]
	if hovered and hovered.team != &"player" and state.can_use(player_unit, first) and hovered in state.targets_for(player_unit, first):
		_run(state.use(player_unit, first, hovered))
	elif plan.get("valid", false):
		_run(state.move(player_unit, cursor))
	else:
		AudioManager.play(&"combat_miss") # soft "can't do that"
		_hud.log_line(_plan_text())


func _select_ability(i: int) -> void:
	var abilities := player_unit.data.abilities
	if i >= abilities.size():
		return
	var a: AbilityData = abilities[i]
	if not state.can_use(player_unit, a):
		_hud.log_line("No %s left this turn." % ("bonus action" if a.cost == AbilityData.Cost.BONUS else "action"))
		return
	AudioManager.play(&"ui_confirm")
	if a.kind == AbilityData.Kind.SELF_BUFF:
		_run(state.use(player_unit, a))
		return
	if mode == Mode.TARGET and ability == a:
		mode = Mode.MOVE # pressing the same ability again cancels
	else:
		mode = Mode.TARGET
		ability = a
		var valid := state.targets_for(player_unit, a)
		target = hovered if hovered in valid else (valid[0] if valid else _nearest_foe())
	_refresh()


func _cycle_target(step: int) -> void:
	var foes := state.foes_of(player_unit)
	if foes.is_empty():
		return
	foes.sort_custom(func(x: CombatUnit, y: CombatUnit) -> bool:
		return state.distance(player_unit, x) < state.distance(player_unit, y))
	var i := foes.find(target)
	target = foes[(i + step + foes.size()) % foes.size()]
	_refresh()


func _set_cursor(p: Vector3) -> void:
	var c := CombatSpace.flat(p)
	var center := state.space.center
	if c.distance_to(center) > state.space.radius:
		c = center + (c - center).normalized() * state.space.radius
	cursor = state.space.ground(c)
	hovered = null
	for u in state.units:
		if u.is_alive() and u != player_unit and CombatSpace.flat(u.position).distance_to(c) < HOVER_RADIUS:
			hovered = u
	if mode == Mode.TARGET and hovered and hovered.team != &"player":
		target = hovered
	_refresh()


func _ground_under_mouse(screen_pos: Vector2) -> Variant:
	var cam := get_viewport().get_camera_3d()
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0, 1)
	var hit := area.get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		return hit.position
	if absf(dir.y) < 0.001:
		return null
	return from + dir * (-from.y / dir.y)


func _nearest_foe() -> CombatUnit:
	var foes := state.foes_of(player_unit)
	foes.sort_custom(func(x: CombatUnit, y: CombatUnit) -> bool:
		return state.distance(player_unit, x) < state.distance(player_unit, y))
	return foes[0] if foes else null


# ---------------------------------------------------------------- presentation

func _refresh() -> void:
	var me := player_unit
	_overlay.begin()
	if mode == Mode.MOVE:
		if cursor.distance_to(_planned_at) > REPLAN_DISTANCE:
			plan = state.plan_move(me, cursor)
			_planned_at = cursor
		_overlay.ring(me.position, me.movement_left, C_RANGE, true)
		for foe in state.foes_of(me):
			if foe.has_reaction and foe.threat_radius > 0.0:
				var hot: bool = me.provokes_reactions and foe in plan.get("provokes", [])
				_overlay.ring(foe.position, foe.threat_radius, C_THREAT_HOT if hot else C_THREAT)
			if foe.telegraph_radius > 0.0: # a declared heavy blow: its whole reach is dangerous
				_overlay.ring(foe.position, foe.telegraph_radius, C_THREAT_HOT)
		for o in state.space.obstacles: # show what's in the way near the cursor
			if o.pos.distance_to(CombatSpace.flat(cursor)) < o.radius + 2.5:
				_overlay.ring(state.space.ground(o.pos), o.radius + CombatSpace.UNIT_RADIUS, C_OBSTACLE, true)
		if plan.get("reachable", false):
			var fits := state.space.truncate(plan.points, me.movement_left)
			_overlay.polyline(fits.points, C_PATH)
			if not plan.valid:
				_overlay.polyline([fits.points.back(), plan.points.back()], C_TOO_FAR)
		_overlay.marker(cursor, C_PATH if plan.get("valid", false) else C_TOO_FAR)
		_focus.global_position = me.position.lerp(cursor, 0.35)
	elif mode == Mode.TARGET:
		_overlay.ring(me.position, ability.range_max, C_RANGE, true)
		if ability.range_min > 0.0:
			_overlay.ring(me.position, ability.range_min, C_RANGE, true)
		for foe in state.targets_for(me, ability):
			_overlay.ring(foe.position, 0.6, C_TARGET)
		if target:
			var blocker := state.space.sight_blocker(me.position, target.position) if ability.needs_line_of_sight else ""
			var cover := ""
			if blocker == "":
				cover = state.predict(me, ability, target).cover
			var col := C_LINE_BLOCKED if blocker != "" or not state.in_range(me, target, ability) \
				else (C_LINE_COVER if cover != "" else C_LINE_CLEAR)
			_overlay.polyline([me.position, target.position], col)
			_overlay.ring(target.position, 0.75, col)
			_focus.global_position = me.position.lerp(target.position, 0.5)
	_overlay.finish()
	_hud.refresh()


## One line explaining the current movement choice (shown in the HUD, and logged when refused).
func _plan_text() -> String:
	if not plan.get("reachable", false):
		return "Can't stand there."
	if not plan.valid:
		return "Too far: %.1f m (%.1f m left)." % [plan.cost, player_unit.movement_left]
	var text := "Walk %.1f m." % plan.cost
	var provoked: Array = plan.get("provokes", [])
	if not provoked.is_empty():
		text += " Leaving %s's reach: it gets a free strike!" % provoked[0].data.display_name
	for foe in state.foes_of(player_unit):
		if foe.telegraph_radius > 0.0 and CombatSpace.flat(cursor).distance_to(CombatSpace.flat(foe.position)) <= foe.telegraph_radius + CombatSpace.EPS: # same edge as CombatState.in_range
			text += " Still inside %s's swing!" % foe.data.display_name
	return text


func plan_text() -> String:
	return _plan_text() if mode == Mode.MOVE else ""


## Target line for the HUD: why this target is easy or hard, in plain words.
func target_text() -> String:
	var t := target if mode == Mode.TARGET else hovered
	if not t or t == player_unit:
		return ""
	var lines: Array[String] = ["%s   %d/%d HP%s" % [t.data.display_name, t.hp, t.data.max_hp, _status_text(t)]]
	if mode != Mode.TARGET:
		return lines[0]
	var d := state.distance(player_unit, t)
	var blocker := state.space.sight_blocker(player_unit.position, t.position) if ability.needs_line_of_sight else ""
	if d > ability.range_max:
		lines.append("Out of reach: %.1f m (max %.1f m)" % [d, ability.range_max])
	elif d < ability.range_min:
		lines.append("Too close for %s (min %.1f m)" % [ability.display_name, ability.range_min])
	elif blocker != "":
		lines.append("A %s is in the way." % blocker)
	else:
		var p := state.predict(player_unit, ability, t)
		lines.append("%.1f m   Hit %d%%   %d-%d dmg" % [d, roundi(p.chance * 100), p.damage.x, p.damage.y])
		if p.cover != "":
			lines.append("Partly behind a %s: harder to hit." % p.cover)
		if p.high_ground:
			lines.append("You stand higher: easier to hit.")
		if state.space.terrain_at(CombatSpace.flat(t.position)) == &"water":
			lines.append("It stands in the stream: easier to hit.")
	return "\n".join(lines)


func _status_text(unit: CombatUnit) -> String:
	var names := unit.statuses.map(func(s: Dictionary) -> String: return "%s (%d)" % [s.status.display_name, s.turns_left])
	return ("   " + ", ".join(names)) if names else ""


func _play(events: Array) -> void:
	for e in events:
		match e.type:
			"turn_start":
				_focus.global_position = e.unit.position
				_hud.log_line("Round %d: %s's turn." % [state.round_number, e.unit.data.display_name])
				if e.unit == player_unit:
					AudioManager.play(&"turn_start")
				_hud.refresh()
				await get_tree().create_timer(0.25).timeout
			"move":
				await _walk(e.unit, e.points)
			"attack":
				await _animate_attack(e)
			"buff":
				_float_text(area.view_for(e.unit), e.ability.display_name, Color(0.6, 0.9, 1.0))
				_hud.log_line("%s uses %s." % [e.unit.data.display_name, e.ability.display_name])
				await get_tree().create_timer(0.35).timeout
			"telegraph":
				_float_text(area.view_for(e.unit), "Watch out!", Color(1.0, 0.7, 0.35), 2.3)
				_hud.log_line(e.message)
				await get_tree().create_timer(0.5).timeout
			"defeated":
				var view := area.view_for(e.unit)
				_hud.log_line("%s is down." % e.unit.data.display_name)
				if view is UnitView:
					AudioManager.play_at(&"enemy_down", view)
					view.fall()
				await get_tree().create_timer(0.5).timeout
			"combat_end":
				_finish(e.winner)
		_hud.refresh()


func _walk(unit: CombatUnit, points: Array) -> void:
	var view := area.view_for(unit)
	if view is UnitView:
		view.walking = true
	var since_step := STEP_EVERY * 0.5
	for i in range(1, points.size()):
		var from: Vector3 = points[i - 1]
		var to: Vector3 = points[i]
		var length := from.distance_to(to)
		if length < 0.01:
			continue
		_face(view, to)
		var tw := create_tween()
		tw.tween_property(view, "global_position", to, length / WALK_SPEED)
		var t := 0.0
		while t < length / WALK_SPEED:
			await get_tree().process_frame
			var dt := get_process_delta_time()
			t += dt
			since_step += dt * WALK_SPEED
			_focus.global_position = _focus.global_position.lerp(view.global_position, 0.2)
			if since_step >= STEP_EVERY:
				since_step = 0.0
				var ground := state.space.terrain_at(CombatSpace.flat(view.global_position))
				AudioManager.play_at(StringName("step_" + (String(ground) if ground != &"" else "grass")), view)
	if view is UnitView:
		view.walking = false


func _animate_attack(e: Dictionary) -> void:
	var user_view := area.view_for(e.user)
	var target_view := area.view_for(e.target)
	_face(user_view, e.target.position)
	if e.reaction:
		AudioManager.play_at(&"reaction", user_view)
		_float_text(user_view, "Reaction!", Color(1, 0.8, 0.4), 2.2)
		_focus.global_position = e.user.position.lerp(e.target.position, 0.5)
		await get_tree().create_timer(0.35).timeout
	var home: Vector3 = e.user.position
	var lunge := home.lerp(e.target.position, 0.3 if e.ability.range_max <= 2.0 else 0.06)
	var tw := create_tween()
	tw.tween_property(user_view, "global_position", lunge, 0.1)
	tw.tween_property(user_view, "global_position", home, 0.18)
	await get_tree().create_timer(0.1).timeout
	var why := ""
	if e.cover != "":
		why += ", %s cover" % e.cover
	if e.high_ground:
		why += ", high ground"
	var prefix := "Reaction! " if e.reaction else ""
	var roll_text := "%s%s: %s rolls %d+%d=%d vs %d%s." % [prefix, e.ability.display_name, e.user.data.display_name,
		e.roll, e.total - e.roll, e.total, e.defense, why]
	if e.hit:
		AudioManager.play_at(&"combat_hit", target_view)
		_float_text(target_view, ("CRIT -%d" if e.crit else "-%d") % e.damage, Color(1, 0.55, 0.4))
		_hud.log_line("%s Hit for %d%s." % [roll_text, e.damage, " (critical)" if e.crit else ""])
		if target_view is UnitView:
			target_view.flinch()
		if e.ability.applies_status and e.target.is_alive():
			_float_text(target_view, e.ability.applies_status.display_name, Color(1, 0.95, 0.6), 0.5)
	else:
		AudioManager.play_at(&"combat_miss", target_view)
		_float_text(target_view, "miss", Color(0.8, 0.8, 0.85))
		_hud.log_line("%s Miss." % roll_text)
	if target_view is UnitView:
		target_view.refresh()
	if e.target == player_unit:
		area.player.health = e.target.hp
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
	area.add_child(label)
	label.global_position = view.global_position + Vector3.UP * rise_from
	var tw := create_tween().set_parallel()
	tw.tween_property(label, "global_position:y", label.global_position.y + 0.9, 1.1)
	tw.tween_property(label, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tw.chain().tween_callback(label.queue_free)


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
	area.camera_rig.target = _previous_camera_target
	area.player.input_enabled = true
	_hud.close()
	get_tree().call_group("hud", "set_combat_mode", false)
	finished.emit(winner)
