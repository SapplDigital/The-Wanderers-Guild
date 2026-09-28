extends CanvasLayer
## Combat HUD (inside the pixel viewport). Shows whose turn it is, the active unit's
## action economy ([x] available / [ ] spent, never colour alone), the ability bar with keys,
## hovered target info with the predicted result, and a short combat log.

const LOG_LINES := 3

@onready var _root: Control = $Root
@onready var _turn: Label = $Root/Turn
@onready var _unit: Label = $Root/Unit
@onready var _abilities: Label = $Root/Abilities
@onready var _target: Label = $Root/Target
@onready var _log: Label = $Root/Log

var _controller: CombatController
var _lines: Array[String] = []


func _ready() -> void:
	add_to_group("combat_hud")
	_root.visible = false


func open(controller: CombatController) -> void:
	_controller = controller
	_lines.clear()
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

	_unit.text = "%s   %d/%d HP\nMove %d   %s Action   %s Bonus   %s Reaction%s" % [
		me.data.display_name, me.hp, me.data.max_hp, me.movement_left,
		_box(me.has_action), _box(me.has_bonus), _box(me.has_reaction), _status_text(me)]

	var parts: Array[String] = []
	for i in me.data.abilities.size():
		var a: AbilityData = me.data.abilities[i]
		var selected := _controller.mode == CombatController.Mode.TARGET and _controller.ability == a
		var usable := state.can_use(me, a) and current == me
		parts.append("%s%s %s%s%s" % [">" if selected else "", InputGlyphs.label(StringName("combat_ability_%d" % (i + 1))),
			a.display_name, " (bonus)" if a.cost == AbilityData.Cost.BONUS else "", "" if usable else " -"])
	parts.append("%s End turn" % InputGlyphs.label(&"combat_end_turn"))
	_abilities.text = "   ".join(parts)
	if current != me:
		_abilities.text = "Enemy turn..."

	var hovered := _controller.hovered_unit()
	if hovered and hovered != me:
		var text := "%s   %d/%d HP\nDefense %d%s" % [hovered.data.display_name, hovered.hp, hovered.data.max_hp,
			hovered.defense(), _status_text(hovered)]
		var p := _controller.prediction()
		if p:
			text += "\nHit %d%%   %d-%d dmg%s" % [roundi(p.chance * 100), p.damage.x, p.damage.y,
				"   cover +2" if p.cover else ""]
		_target.text = text
	else:
		_target.text = ""


func _box(available: bool) -> String:
	return "[x]" if available else "[ ]"


func _status_text(unit: CombatUnit) -> String:
	var names := unit.statuses.map(func(s: Dictionary) -> String: return "%s (%d)" % [s.status.display_name, s.turns_left])
	return ("   " + ", ".join(names)) if names else ""
