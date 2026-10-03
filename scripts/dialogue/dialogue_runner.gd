class_name DialogueRunner
extends RefCounted
## Walks one conversation. Pure logic: no scene nodes, so it runs headless. The flag store is
## injected (GameState in the game); presentation only reads `node`/`choices()` and calls
## `choose()` / `advance()` / `leave()`.

signal event_fired(id: StringName)
signal finished

var data: DialogueData
var flags: Object ## anything with get_flag(key, default) / set_flag(key, value)
var node: DialogueNode ## current line; null once finished


func _init(dialogue: DialogueData, flag_store: Object) -> void:
	data = dialogue
	flags = flag_store


## Opens with the first entry whose conditions pass. False if none does.
func start() -> bool:
	for entry in data.entries:
		if _visible(entry):
			_take(entry)
			return node != null
	return false


func is_finished() -> bool:
	return node == null


## The replies the player may pick right now (conditions checked live).
func choices() -> Array[DialogueChoice]:
	var out: Array[DialogueChoice] = []
	if node:
		for c in node.choices:
			if _visible(c):
				out.append(c)
	return out


func choose(index: int) -> void:
	var options := choices()
	if index >= 0 and index < options.size():
		_take(options[index])


## Continue a line that has no visible replies.
func advance() -> void:
	if node and choices().is_empty():
		_go(node.next)


## Walk away mid-conversation: nothing is applied.
func leave() -> void:
	if node:
		_go(&"")


func _visible(choice: DialogueChoice) -> bool:
	return DialogueCondition.all_pass(choice.conditions, flags)


func _take(choice: DialogueChoice) -> void:
	for effect in choice.consequences:
		if effect.kind == DialogueConsequence.Kind.EVENT:
			event_fired.emit(StringName(effect.key))
		else:
			effect.apply(flags)
	_go(choice.next)


func _go(next: StringName) -> void:
	node = data.find(next) if next != &"" else null
	if node == null:
		finished.emit()
