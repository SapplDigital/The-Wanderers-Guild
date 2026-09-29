extends CanvasLayer
## Exploration HUD. Lives inside the 640x360 pixel viewport, so it is pixel-crisp and
## matches the world. Deliberately sparse: health pips, a cardinal-only compass,
## a contextual prompt anchored to the focused object, a place-name card on discovery,
## one message line, a quest-update line above it, and every active quest's current objective.
## Everything fades out during cinematics.

const HP_PER_PIP := 2
const PIP_FULL := Color(0.95, 0.62, 0.36)
const PIP_EMPTY := Color(0.2, 0.18, 0.22, 0.8)

@onready var _root: Control = $Root
@onready var _pips: HBoxContainer = $Root/Pips
@onready var _compass: Compass = $Root/Compass
@onready var _prompt: Label = $Root/Prompt
@onready var _location: Label = $Root/Location
@onready var _message: Label = $Root/Message
@onready var _quest: Label = $Root/Quest
@onready var _update: Label = $Root/Update ## quest changes: own line, so flavour text can't overwrite them

var _player: Player
var _rig: CameraController
var _location_tween: Tween
var _message_tween: Tween
var _update_tween: Tween
var _update_held := false ## paused by us while a conversation is open
var _quests: Array[QuestData] = []
var _quest_text := {} ## quest id -> last shown status, to announce changes once


func _ready() -> void:
	add_to_group("hud")
	_location.modulate.a = 0.0
	_message.modulate.a = 0.0
	_update.modulate.a = 0.0
	_quests = DataIndex.main().quests
	GameState.flag_changed.connect(func(_k: String, _v: Variant) -> void: _refresh_quests(true))
	_refresh_quests(false)


func bind(world: Node) -> void:
	_player = world.get_node("Player")
	_rig = world.get_node("CameraRig")
	_compass.rig = _rig
	_player.health_changed.connect(_on_health_changed)
	_player.get_node("Interactor").used.connect(func(_t: Interactable) -> void: _pulse_prompt())
	_on_health_changed(_player.health, _player.max_health)
	_refresh_quests(false) # flags may have been replaced (load): rebuild the cache without announcing
	# A new world means we're somewhere else: drop leftover place names and messages.
	for tw in [_location_tween, _message_tween, _update_tween]:
		if tw:
			tw.kill()
	_location.modulate.a = 0.0
	_message.modulate.a = 0.0
	_update.modulate.a = 0.0


func show_location(title: String) -> void:
	_location.text = title
	_location_tween = _fade(_location, _location_tween, 3.0)


func show_message(text: String) -> void:
	_message.text = text
	_message_tween = _fade(_message, _message_tween, 2.0 + text.length() * 0.05)


## A quest update waits (paused before it fades in) while a conversation covers the bottom of the
## screen, so a change made by a dialogue reply shows once the player is back in the world.
func show_update(text: String) -> void:
	_update.text = text
	_update_tween = _fade(_update, _update_tween, 2.5 + text.length() * 0.05)
	_update_held = false
	if _talking():
		_update.modulate.a = 0.0 # a still-visible older update mustn't stand in for it
		_update_tween.pause()
		_update_held = true


func _talking() -> bool:
	var ui := get_tree().get_first_node_in_group("dialogue_ui")
	return ui != null and ui.is_open()


func _process(delta: float) -> void:
	if _update_tween and _update_tween.is_valid():
		if _talking() and _update_tween.is_running():
			_update_tween.pause()
			_update_held = true
		elif _update_held and not _talking():
			_update_tween.play()
			_update_held = false
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


## Shows every active quest's current objective (title + objective, stacked); announces objective
## changes and endings on the update line.
func _refresh_quests(announce: bool) -> void:
	var lines: PackedStringArray = []
	for quest in _quests:
		var status := ""
		var ended := QuestTracker.outcome(quest, GameState)
		if ended:
			status = ended.text
		elif QuestTracker.is_active(quest, GameState):
			var objective := QuestTracker.current_objective(quest, GameState)
			status = objective.text if objective else ""
			lines.append("%s\n%s" % [quest.title, status])
		if announce and status != "" and status != _quest_text.get(quest.id, ""):
			show_update("%s: %s" % [quest.title, status])
		_quest_text[quest.id] = status
	_quest.text = "\n\n".join(lines) # a blank line keeps each quest's title with its objective


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
