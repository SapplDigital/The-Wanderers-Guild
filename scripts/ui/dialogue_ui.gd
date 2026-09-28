class_name DialogueUI
extends CanvasLayer
## Compact dialogue panel at the bottom of the pixel layer. Presentation only: shows the
## runner's speaker/text/replies and forwards picks. Selection is marked with ">" (not colour).
## Up/down (W/S, arrows, stick, D-pad) select, interact (F / A) confirms, dialogue_leave
## (Esc / B) walks away. Mouse hover selects, click confirms. The player can't move meanwhile.

const INK := Color(0.95, 0.89, 0.78)
const SPEAKER := Color(0.95, 0.62, 0.36)
const DIM := Color(0.62, 0.58, 0.54)
const OUTLINE := Color(0.08, 0.07, 0.1)
const FONT_SIZE := 10
const WIDTH := 420.0

var runner: DialogueRunner
var _player: Node3D
var _selected := 0
var _opened_frame := -1
var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _choices: VBoxContainer
var _hint: Label


func _ready() -> void:
	add_to_group("dialogue_ui")
	layer = 2
	_build()
	_panel.visible = false


func is_open() -> bool:
	return runner != null


func open(dialogue_runner: DialogueRunner, player: Node3D) -> void:
	runner = dialogue_runner
	runner.finished.connect(close, CONNECT_ONE_SHOT)
	_player = player
	if "input_enabled" in _player:
		_player.input_enabled = false
	_opened_frame = Engine.get_process_frames() # the press that opened us must not also confirm
	_panel.visible = true
	_show_line()


func close() -> void:
	if _player and "input_enabled" in _player:
		_player.input_enabled = true
	runner = null
	_player = null
	_panel.visible = false


## Pick the reply at `index` of the visible replies (or continue a line without replies).
func confirm(index: int) -> void:
	if runner == null:
		return
	AudioManager.play(&"ui_confirm")
	if runner.choices().is_empty():
		runner.advance()
	else:
		runner.choose(index)
	if runner and not runner.is_finished():
		_show_line()


func leave() -> void:
	if runner:
		runner.leave()


func _process(_delta: float) -> void:
	if runner == null or Engine.get_process_frames() == _opened_frame:
		return
	var count := maxi(runner.choices().size(), 1)
	if Input.is_action_just_pressed("move_forward") or Input.is_action_just_pressed("ui_up"):
		_select(wrapi(_selected - 1, 0, count))
	elif Input.is_action_just_pressed("move_back") or Input.is_action_just_pressed("ui_down"):
		_select(wrapi(_selected + 1, 0, count))
	elif Input.is_action_just_pressed("interact"):
		confirm(_selected)
	elif Input.is_action_just_pressed("dialogue_leave"):
		leave()
	elif _hint.visible:
		_update_hint() # the last-used device can change while the panel is open


func _show_line() -> void:
	_speaker.text = runner.node.speaker
	_speaker.visible = runner.node.speaker != ""
	_text.text = runner.node.text
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	var options := runner.choices()
	var texts: Array = options.map(func(c: DialogueChoice) -> String: return c.text)
	if texts.is_empty():
		texts = ["..."]
	for i in texts.size():
		var row := _label(texts[i], INK)
		row.set_meta("reply", texts[i])
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_entered.connect(_select.bind(i))
		row.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				confirm(i))
		_choices.add_child(row)
	_select(0)


func _select(index: int) -> void:
	_selected = index
	for i in _choices.get_child_count():
		var row: Label = _choices.get_child(i)
		var chosen := i == index
		row.text = ("> " if chosen else "   ") + row.get_meta("reply")
		row.label_settings.font_color = INK if chosen else DIM
	_update_hint()


func _update_hint() -> void:
	var verb := "Continue" if runner and runner.choices().is_empty() else "Choose"
	_hint.text = "%s %s    %s Leave" % [InputGlyphs.label(&"interact"), verb, InputGlyphs.label(&"dialogue_leave")]


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.09, 1.0)
	style.border_color = Color(0.45, 0.36, 0.28, 0.9)
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -WIDTH / 2.0
	_panel.offset_right = WIDTH / 2.0
	_panel.offset_bottom = -8.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_panel.add_child(box)
	_speaker = _label("", SPEAKER)
	_text = _label("", INK)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 1)
	_hint = _label("", DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for node in [_speaker, _text, _choices, _hint]:
		box.add_child(node)


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	var settings := LabelSettings.new()
	settings.font_size = FONT_SIZE
	settings.font_color = color
	settings.outline_size = 3
	settings.outline_color = OUTLINE
	label.label_settings = settings
	return label
