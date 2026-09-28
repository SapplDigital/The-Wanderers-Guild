extends CanvasLayer
## Combat HUD (inside the pixel viewport). Whose turn it is, the active unit's action economy
## ([x] available / [ ] spent, never colour alone), movement left in metres, the ability bar with
## keys, one plain-language line about the current move, the target and why it is easy or hard,
## and a short combat log.

const LOG_LINES := 3

@onready var _root: Control = $Root
@onready var _turn: Label = $Root/Turn
@onready var _unit: Label = $Root/Unit
@onready var _abilities: Label = $Root/Abilities
@onready var _target: Label = $Root/Target
@onready var _plan: Label = $Root/Plan
@onready var _log: Label = $Root/Log

var _controller: CombatController
var _lines: Array[String] = []


func _ready() -> void:
	add_to_group("combat_hud")
	_root.visible = false


func open(controller: CombatController) -> void:
	_controller = controller
	_lines.clear()
	_log.text = ""
	_root.visible = true
	refresh()


func close() -> void:
	_controller = null
	_root.visible = false


func log_line(text: String) -> void:
	_lines.append(text)
	while _lines.size() > LOG_LINES:
		_lines.pop_front()
	_log.text = "\n".join(_lines)


func refresh() -> void:
	if not _controller:
		return
	var state := _controller.state
	var me := _controller.player_unit
	var current := state.current()
	var order := state.order.filter(func(u: CombatUnit) -> bool: return u.is_alive()) \
		.map(func(u: CombatUnit) -> String: return ("> " if u == current else "") + u.data.display_name)
	_turn.text = "Round %d\n%s" % [state.round_number, "   ".join(order)]

	var statuses := me.statuses.map(func(s: Dictionary) -> String: return "%s (%d)" % [s.status.display_name, s.turns_left])
	_unit.text = "%s   %d/%d HP%s\nMove %.1f m   %s Action   %s Bonus   %s Reaction" % [
		me.data.display_name, me.hp, me.data.max_hp, ("   " + ", ".join(statuses)) if statuses else "",
		me.movement_left, _box(me.has_action), _box(me.has_bonus), _box(me.has_reaction)]

	if current != me:
		_abilities.text = "%s is acting..." % current.data.display_name
	else:
		var parts: Array[String] = []
		for i in me.data.abilities.size():
			var a: AbilityData = me.data.abilities[i]
			var selected := _controller.mode == CombatController.Mode.TARGET and _controller.ability == a
			parts.append("%s%s %s%s%s" % [">" if selected else "", InputGlyphs.label(StringName("combat_ability_%d" % (i + 1))),
				a.display_name, " (bonus)" if a.cost == AbilityData.Cost.BONUS else "", "" if state.can_use(me, a) else " -"])
		parts.append("%s End turn" % InputGlyphs.label(&"combat_end_turn"))
		_abilities.text = "   ".join(parts)

	_plan.text = _controller.plan_text()
	_target.text = _controller.target_text()


func _box(available: bool) -> String:
	return "[x]" if available else "[ ]"
