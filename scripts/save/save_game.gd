class_name SaveGame
extends RefCounted
## One save slot as a ConfigFile (text, keeps Godot types: JSON would turn every int into a
## float and break EventDirector's `is int` checks). Pure: no scene nodes, so it runs headless.
## Holds only authoritative state: GameState.flags, player position and health. Everything else
## (StateToggles, interiors, quests, events, encounters) rebuilds itself from the flags.
##   [save]   version=1
##   [player] position=Vector3(...)  health=12
##   [state]  flags={ sorted keys }

const VERSION := 1
const PATH := "user://save.cfg"
const NO_SAVE := "no save"
const FLAG_TYPES: Array[int] = [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]

## Upgrades from version N to N+1, keyed by N: func(data: Dictionary) -> Dictionary.
## Empty while version 1 is the only format; add a step here when the format changes.
static var migrations := {}


## Writes to `<path>.tmp` first and only then replaces the real save, so a failed or
## interrupted write never leaves a half-written save behind.
static func write(path: String, flags: Dictionary, position: Vector3, health: int) -> Error:
	var keys := flags.keys()
	keys.sort() # same facts in any insertion order give the same bytes
	var sorted := {}
	for key in keys:
		sorted[key] = flags[key]
	var cfg := ConfigFile.new()
	cfg.set_value("save", "version", VERSION)
	cfg.set_value("player", "position", position)
	cfg.set_value("player", "health", health)
	cfg.set_value("state", "flags", sorted)
	var tmp := path + ".tmp"
	var err := cfg.save(tmp)
	if err == OK:
		err = DirAccess.rename_absolute(tmp, path) # replaces the old save in one step (checked on Windows)
	if err != OK and FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(tmp)
	return err


## Returns {ok = true, flags, position, health} or {ok = false, error}. `error` is NO_SAVE when
## there's no file. Never touches GameState: the caller applies a result only when it's ok.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fail(NO_SAVE)
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return _fail("The save file is damaged.")
	var version: Variant = _value(cfg, "save", "version")
	if not version is int or version < 0:
		return _fail("The save file is damaged.")
	if version > VERSION:
		return _fail("The save was made by a newer version.")
	var data := {
		position = _value(cfg, "player", "position"),
		health = _value(cfg, "player", "health"),
		flags = _value(cfg, "state", "flags"),
	}
	data = migrate(data, version)
	if data.is_empty():
		return _fail("The save is too old to load.")
	var problem := validate(data)
	if problem != "":
		return _fail("The save file is damaged.")
	data.ok = true
	return data


## Runs the upgrade steps from `from` up to VERSION. Empty result = no step for some version.
static func migrate(data: Dictionary, from: int, steps: Dictionary = migrations) -> Dictionary:
	for v in range(from, VERSION):
		if not steps.has(v):
			return {}
		data = steps[v].call(data)
	return data


## "" when the data is structurally sound, otherwise what's wrong (for tests and logs).
static func validate(data: Dictionary) -> String:
	var p: Variant = data.get("position")
	if not p is Vector3 or not p.is_finite():
		return "player.position"
	var h: Variant = data.get("health")
	if not h is int or h < 1:
		return "player.health"
	var flags: Variant = data.get("flags")
	if not flags is Dictionary:
		return "state.flags"
	for key: Variant in flags:
		if not key is String:
			return "flag key %s" % key
		if not FLAG_TYPES.has(typeof(flags[key])):
			return "flag %s" % key
	return ""


## null when missing (ConfigFile treats a null default as "no default" and logs an error).
static func _value(cfg: ConfigFile, section: String, key: String) -> Variant:
	return cfg.get_value(section, key) if cfg.has_section_key(section, key) else null


static func _fail(error: String) -> Dictionary:
	return {ok = false, error = error}
