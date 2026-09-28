class_name DialogueData
extends Resource
## A conversation. `entries` are picked automatically (first whose conditions pass) and lead
## into `nodes`. Static data only; the walk through it lives in DialogueRunner.

@export var id: StringName
@export var entries: Array[DialogueChoice] = []
@export var nodes: Array[DialogueNode] = []


func find(node_id: StringName) -> DialogueNode:
	for node in nodes:
		if node.id == node_id:
			return node
	return null


## Authoring errors; empty = valid. Checked for every file by tests/test_dialogue.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if entries.is_empty():
		errors.append("%s: no entries" % id)
	if not entries.any(func(e: DialogueChoice) -> bool: return e.conditions.is_empty()):
		errors.append("%s: every entry is conditional; the conversation may not open" % id)
	var seen := {}
	for node in nodes:
		if seen.has(node.id):
			errors.append("%s: duplicate node id '%s'" % [id, node.id])
		seen[node.id] = true
		if node.text.strip_edges() == "":
			errors.append("%s/%s: empty text" % [id, node.id])
		if not node.choices.is_empty() and node.choices.all(func(c: DialogueChoice) -> bool: return not c.conditions.is_empty()):
			errors.append("%s/%s: every choice is conditional; the player may be left without a reply" % [id, node.id])
	# Broken links and reachability, walking from the entries.
	var reached := {}
	var queue: Array[StringName] = []
	for e in entries:
		queue.append(e.next)
	while not queue.is_empty():
		var next: StringName = queue.pop_back()
		if next == &"" or reached.has(next):
			continue
		var node := find(next)
		if node == null:
			errors.append("%s: link to missing node '%s'" % [id, next])
			continue
		reached[next] = true
		queue.append(node.next)
		for c in node.choices:
			queue.append(c.next)
	for node in nodes:
		if not reached.has(node.id):
			errors.append("%s/%s: unreachable" % [id, node.id])
	return errors
