extends Node
## DataIndex (M15): the explicit content index matches the data folders, has no broken or
## duplicate entries, keeps the event order the director's seeds depend on, and the validator
## reports what goes wrong. Runtime code must not scan data folders (they may not list in exports).
##   godot --headless --path . res://tests/test_data_index.tscn

var _failures := 0


func _ready() -> void:
	var index := DataIndex.main()
	_check(index.validate().is_empty(), "the project index validates %s" % index.validate())
	_check_matches_folder(index.quests, "res://data/quests/")
	_check_matches_folder(index.events, "res://data/events/")
	var event_ids := index.events.map(func(e: EventData) -> String: return String(e.id))
	var sorted := event_ids.duplicate()
	sorted.sort()
	_check(event_ids == sorted, "events stay in id order (director picks depend on it): %s" % [event_ids])
	for q in index.quests:
		_check(q.validate().is_empty(), "quest %s validates" % q.id)
	for e in index.events:
		_check(e.validate().is_empty(), "event %s validates" % e.id)
	_test_validator()
	_test_no_runtime_scans()
	_test_no_instance_child_overrides("res://scenes/")
	print("data index: %s (%d failures)" % ["OK" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


## Every .tres in the folder is indexed, and nothing indexed lives elsewhere.
func _check_matches_folder(list: Array, dir: String) -> void:
	var indexed := list.map(func(r: Resource) -> String: return r.resource_path)
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tres"):
			_check(indexed.has(dir + file), "%s%s is in data_index.tres" % [dir, file])
	for path in indexed:
		_check(path.begins_with(dir), "%s is indexed under %s" % [path, dir])


func _test_validator() -> void:
	var bad := DataIndex.new()
	var q := QuestData.new()
	q.id = &"same"
	bad.quests = [q, q.duplicate(), null]
	var errors := bad.validate()
	_check(errors.size() == 2, "validator reports the duplicate id and the missing entry: %s" % errors)
	_check(" ".join(errors).contains("duplicate id 'same'"), "duplicate message names the id")
	_check(" ".join(errors).contains("quests[2] is missing"), "missing message names the slot")


## Guardrail: the old export-unsafe folder scans must not come back in game code.
func _test_no_runtime_scans() -> void:
	for dir in ["res://scripts/core/", "res://scripts/events/", "res://scripts/quests/", "res://scripts/ui/", "res://scripts/world/", "res://scripts/save/"]:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				var src := FileAccess.get_file_as_string(dir + file)
				_check(not src.contains("get_files_at(") and not src.contains("DirAccess.open(\"res://"),
					"%s%s doesn't scan res:// folders at runtime" % [dir, file])


## Guardrail (M15): the exported build dropped properties that an outer scene set on a *child*
## of an instanced scene (the guild's camera link, every villager's conversation). Such an
## override is a node header with neither `type=` nor `instance=`. Configure the instance root.
func _test_no_instance_child_overrides(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_test_no_instance_child_overrides(dir + sub + "/")
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".tscn"):
			continue
		var bad := PackedStringArray()
		for line in FileAccess.get_file_as_string(dir + file).split("\n"):
			if line.begins_with("[node ") and line.contains(" parent=") and not line.contains(" type=") and not line.contains(" instance="):
				bad.append(line)
		_check(bad.is_empty(), "%s%s sets nothing on children of instanced scenes %s" % [dir, file, bad])


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAIL: " + what)
	else:
		print("PASS: " + what)
