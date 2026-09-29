class_name TitleMenu
extends CanvasLayer
## Start screen for playtest builds (M15): Continue (only with a loadable save) and New Game.
## Presentation only: it reports the choice through `chosen` and `main.gd` does the work.
## New Game over an existing save file asks first ("Back" is preselected); confirming changes
## nothing on disk either: the old save is replaced at the next save (F9 / autosave on close).
## Same controls and look as DialogueUI: up/down (W/S, arrows, stick, D-pad), F / Enter / A
## confirm, Esc / B back, mouse hover + click. Selection is a ">" plus brighter text, not colour.

signal chosen(action: StringName) ## &"continue" or &"new_game"

const CONTINUE := &"continue"
const NEW_GAME := &"new_game"
const BACK := &"back"
const CONFIRM_NEW := &"confirm_new"

var _rows: Array[StringName] = []
var _selected := 0
var _can_continue := false
var _save_exists := false
var _opened_frame := -1
var _box: VBoxContainer
var _question: Label
var _options: VBoxContainer
var _note: Label
var _hint: Label


func _ready() -> void:
	layer = 3
	_build()
	visible = false


func is_open() -> bool:
	return visible


## `can_continue`: a save that loads. `save_exists`: any save file (even a broken one) that a new
## game would replace. `note`: why Continue is missing, if a file exists but can't be loaded.
func open(can_continue: bool, save_exists: bool, note := "") -> void:
	_can_continue = can_continue
	_save_exists = save_exists
	_note.text = note
	_note.visible = note != ""
	_opened_frame = Engine.get_process_frames()
	visible = true
	_show_main()


func close() -> void:
	visible = false


func pick(action: StringName) -> void:
	AudioManager.play(&"ui_confirm")
	match action:
		CONTINUE:
			chosen.emit(CONTINUE)
		NEW_GAME:
			if _save_exists:
				_show_confirm()
			else:
				chosen.emit(NEW_GAME)
		CONFIRM_NEW:
			chosen.emit(NEW_GAME)
		BACK:
			_show_main()


## Rows currently on offer (for tests and mouse picks).
func rows() -> Array[StringName]:
	return _rows


func _unhandled_input(event: InputEvent) -> void:
	if visible:
		InputGlyphs.track(event)


func _process(_delta: float) -> void:
	if not visible or Engine.get_process_frames() == _opened_frame:
		return
	if Input.is_action_just_pressed("move_forward") or Input.is_action_just_pressed("ui_up"):
		_select(wrapi(_selected - 1, 0, _rows.size()))
	elif Input.is_action_just_pressed("move_back") or Input.is_action_just_pressed("ui_down"):
		_select(wrapi(_selected + 1, 0, _rows.size()))
	elif Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		pick(_rows[_selected])
	elif Input.is_action_just_pressed("dialogue_leave") or Input.is_action_just_pressed("ui_cancel"):
		if _rows.has(BACK):
			pick(BACK)
	_update_hint()


func _show_main() -> void:
	_question.visible = false
	var list: Array[StringName] = [NEW_GAME]
	if _can_continue:
		list.push_front(CONTINUE)
	_set_rows(list,{CONTINUE: "Continue", NEW_GAME: "New Game"})


func _show_confirm() -> void:
	_question.text = "Start a new game? Your saved game will be\nreplaced the next time the game saves."
	_question.visible = true
	_set_rows([BACK, CONFIRM_NEW], {BACK: "Back", CONFIRM_NEW: "Start a new game"})


func _set_rows(list: Array[StringName], texts: Dictionary) -> void:
	_rows = list
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	for i in _rows.size():
		var row := _label(texts[_rows[i]], DialogueUI.INK, DialogueUI.FONT_SIZE + 2)
		row.set_meta("text", texts[_rows[i]])
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_entered.connect(_select.bind(i))
		row.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				pick(_rows[i]))
		_options.add_child(row)
	_select(0)


func _select(index: int) -> void:
	_selected = index
	for i in _options.get_child_count():
		var row: Label = _options.get_child(i)
		var on := i == index
		row.text = ("> " if on else "   ") + row.get_meta("text")
		row.label_settings.font_color = DialogueUI.INK if on else DialogueUI.DIM
	_update_hint()


func _update_hint() -> void:
	var back := ("    %s Back" % InputGlyphs.label(&"dialogue_leave")) if _rows.has(BACK) else ""
	_hint.text = "%s Choose%s" % [InputGlyphs.label(&"interact"), back]


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.03, 0.05, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	center.add_child(_box)
	var title := _label("The Wanderer's Guild", DialogueUI.SPEAKER, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label("playtest build", DialogueUI.DIM, DialogueUI.FONT_SIZE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question = _label("", DialogueUI.INK, DialogueUI.FONT_SIZE)
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 2)
	_note = _label("", DialogueUI.DIM, DialogueUI.FONT_SIZE)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint = _label("", DialogueUI.DIM, DialogueUI.FONT_SIZE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	for node in [title, sub, gap, _question, _options, _note, _hint]:
		_box.add_child(node)
	_options.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _label(text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	var settings := LabelSettings.new()
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = 3
	settings.outline_color = DialogueUI.OUTLINE
	label.label_settings = settings
	return label
