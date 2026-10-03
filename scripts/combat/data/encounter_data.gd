class_name EncounterData
extends Resource
## Who fights where. Offsets are metres from the CombatArea's centre (y ignored; ground height is used).

@export var id: StringName
@export var enemies: Array[ActorData] = []
@export var enemy_offsets: Array[Vector3] = []
@export var engage_message := "" ## first combat log line
@export_multiline var victory_message := ""
@export_multiline var defeat_message := ""


## Authoring errors; empty = valid. CombatArea indexes `enemy_offsets` by enemy, so a length
## mismatch would crash the fight instead of failing here.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or enemies.is_empty():
		errors.append("encounter needs an id and at least one enemy")
	if enemies.size() != enemy_offsets.size():
		errors.append("%s: %d enemies but %d offsets" % [id, enemies.size(), enemy_offsets.size()])
	for e in enemies:
		if e == null:
			errors.append("%s: an enemy slot is empty (deleted or broken resource)" % id)
		else:
			for problem in e.validate():
				errors.append("%s: %s" % [id, problem])
	return errors
