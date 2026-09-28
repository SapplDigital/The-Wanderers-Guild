extends CanvasLayer
## Exploration HUD. Lives inside the 640x360 pixel viewport, so it is pixel-crisp and
## matches the world. Deliberately sparse: health pips, a cardinal-only compass,
## a contextual prompt anchored to the focused object, a place-name card on discovery,
## one message line, and the active quest's current objective. Everything fades out during cinematics.

const HP_PER_PIP := 2
const PIP_FULL := Color(0.95, 0.62, 0.36)
const PIP_EMPTY := Color(0.2, 0.18, 0.22, 0.8)
const QUEST_DIR := "res://data/quests/"

@onready var _root: Control = $Root
@onready var _pips: HBoxContainer = $Root/Pips
@onready var _compass: Compass = $Root/Compass
@onready var _prompt: Label = $Root/Prompt
@onready var _location: Label = $Root/Location
@onready var _message: Label = $Root/Message
@onready var _quest: Label = $Root/Quest

var _player: Player
var _rig: CameraController
var _location_tween: Tween
var _message_tween: Tween
var _quests: Array[QuestData] = []
var _quest_text := {} ## quest id -> last shown status, to announce changes once


func _ready() -> void:
	add_to_group("hud")
	_location.modulate.a = 0.0
	_message.modulate.a = 0.0
	for file in DirAccess.get_files_at(QUEST_DIR):
		if file.ends_with(".tres"):
			_quests.append(load(QUEST_DIR + file))
	GameState.flag_changed.connect(func(_k: String, _v: Variant) -> void: _refresh_quests(true))
	_refresh_quests(false)


func bind(world: Node) -> void:
	_player = world.get_node("Player")
	_rig = world.get_node("CameraRig")
	_compass.rig = _rig
	_player.health_changed.connect(_on_health_changed)
	_player.get_node("Interactor").used.connect(func(_t: Interactable) -> void: _pulse_prompt())
	_on_health_changed(_player.health, _player.max_health)
	# A new world means we're somewhere else: drop leftover place names and messages.
	for tw in [_location_tween, _message_tween]:
		if tw:
			tw.kill()
	_location.modulate.a = 0.0
	_message.modulate.a = 0.0


func show_location(title: String) -> void:
	_location.text = title
	_location_tween = _fade(_location, _location_tween, 3.0)


func show_message(text: String) -> void:
	_message.text = text
	_message_tween = _fade(_message, _message_tween, 2.0 + text.length() * 0.05)


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var in_cinematic := _rig.state == CameraController.State.CINEMATIC
	_root.modulate.a = move_toward(_root.modulate.a, 0.0 if in_cinematic else 1.0, delta * 3.0)

	var focus: Interactable = _player.get_node("Interactor").focus
	var cam := get_viewport().get_camera_3d()
	var anchor := focus.global_position + Vector3.UP * focus.prompt_height if focus else Vector3.ZERO
	_prompt.visible = focus != null and cam != null and not cam.is_position_behind(anchor)
	if _prompt.visible:
		_prompt.text = InputGlyphs.label(&"interact") + "  " + focus.verb
		_prompt.position = (cam.unproject_position(anchor) - _prompt.size * Vector2(0.5, 1.0)).round()


func _input(event: InputEvent) -> void:
	InputGlyphs.track(event)


## Shows the first active quest's current objective; announces objective changes and endings.
func _refresh_quests(announce: bool) -> void:
	_quest.text = ""
	for quest in _quests:
		var status := ""
		var ended := QuestTracker.outcome(quest, GameState)
		if ended:
			status = ended.text
		elif QuestTracker.is_active(quest, GameState):
			var objective := QuestTracker.current_objective(quest, GameState)
			status = objective.text if objective else ""
			if _quest.text == "":
				_quest.text = "%s
%s" % [quest.title, status]
		if announce and status != "" and status != _quest_text.get(quest.id, ""):
			show_message("%s: %s" % [quest.title, status])
		_quest_text[quest.id] = status


## Combat has its own HUD; the exploration layer steps aside (messages included).
func set_combat_mode(on: bool) -> void:
	_root.visible = not on


func _pulse_prompt() -> void:
	_prompt.pivot_offset = _prompt.size * 0.5
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_prompt.scale = Vector2(1.35, 1.35)
	tw.tween_property(_prompt, "scale", Vector2.ONE, 0.25)


func _on_health_changed(health: int, max_health: int) -> void:
	var pip_count := ceili(max_health / float(HP_PER_PIP))
	while _pips.get_child_count() < pip_count:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(5, 5)
		_pips.add_child(pip)
	for i in _pips.get_child_count():
		(_pips.get_child(i) as ColorRect).color = PIP_FULL if i * HP_PER_PIP < health else PIP_EMPTY


func _fade(label: Label, old: Tween, hold: float) -> Tween:
	if old:
		old.kill()
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.4)
	tw.tween_interval(hold)
	tw.tween_property(label, "modulate:a", 0.0, 0.8)
	return tw
