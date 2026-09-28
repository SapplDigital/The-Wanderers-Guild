extends Node
## Event-based audio (autoload `AudioManager`). Gameplay code only uses event names
## ("step_grass", "interact", "discovery"); files, volumes and buses live in
## data/audio/sound_bank.tres, so sounds can be replaced without touching gameplay code.
##   play(event)                        one-shot, non-positional (UI, stings)
##   play_at(event, node)               one-shot at a world node's position
##   configure(player, event)           set up a scene-placed player (see SoundEmitter)
##   push_ambience / pop_ambience       layered, crossfaded ambience beds (see AmbienceZone)
##   set_bus_volume / get_bus_volume    linear 0..1, saved to user://audio.cfg

const BANK: SoundBank = preload("res://data/audio/sound_bank.tres")
const BUSES: Array[StringName] = [&"Music", &"Ambience", &"SFX", &"UI"]
const SETTINGS_PATH := "user://audio.cfg"
const AMBIENCE_FADE := 2.5
const SILENT_DB := -60.0

var _ambience_stack: Array[Dictionary] = [] ## [{id, layers}], the last entry wins
var _ambience_players := {} ## event -> AudioStreamPlayer


func _ready() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, &"Master")
	_load_settings()


func play(event: StringName) -> void:
	var ev := _event(event)
	if not ev:
		return
	var player := AudioStreamPlayer.new()
	_setup(player, ev)
	_start_one_shot(player, self)


## Plays in the viewport of `where`, so the sound is heard by the camera that renders it.
func play_at(event: StringName, where: Node3D) -> void:
	var ev := _event(event)
	if not ev:
		return
	var player := AudioStreamPlayer3D.new()
	_setup(player, ev)
	player.position = where.global_position # the viewport is not a Node3D: local == global
	_start_one_shot(player, where.get_viewport())


## Deferred add + autoplay: safe to call while the target is still setting up its children.
func _start_one_shot(player: Node, parent: Node) -> void:
	player.autoplay = true
	player.finished.connect(player.queue_free)
	parent.add_child.call_deferred(player)


func configure(player: Node, event: StringName) -> bool:
	var ev := _event(event)
	if ev:
		_setup(player, ev)
	return ev != null


func push_ambience(id: StringName, layers: Array[StringName]) -> void:
	pop_ambience(id, false)
	_ambience_stack.append({"id": id, "layers": layers})
	_apply_ambience()


func pop_ambience(id: StringName, apply := true) -> void:
	_ambience_stack = _ambience_stack.filter(func(entry: Dictionary) -> bool: return entry.id != id)
	if apply:
		_apply_ambience()


func active_ambience() -> Array:
	return _ambience_players.keys()


func set_bus_volume(bus: StringName, linear: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(clampf(linear, 0.0, 1.0)))
	var cfg := ConfigFile.new()
	for b in BUSES:
		cfg.set_value("volume", b, get_bus_volume(b))
	cfg.save(SETTINGS_PATH)


func get_bus_volume(bus: StringName) -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus)))


func _apply_ambience() -> void:
	var wanted: Array = _ambience_stack.back().layers if _ambience_stack else []
	for event in wanted:
		if _ambience_players.has(event):
			continue
		var ev := _event(event)
		if not ev:
			continue
		var player := AudioStreamPlayer.new()
		_setup(player, ev)
		player.volume_db = SILENT_DB
		add_child(player)
		player.play(randf() * player.stream.get_length())
		create_tween().tween_property(player, "volume_db", ev.volume_db, AMBIENCE_FADE)
		_ambience_players[event] = player
	for event in _ambience_players.keys():
		if event in wanted:
			continue
		var player: AudioStreamPlayer = _ambience_players[event]
		_ambience_players.erase(event)
		var tw := create_tween()
		tw.tween_property(player, "volume_db", SILENT_DB, AMBIENCE_FADE)
		tw.tween_callback(player.queue_free)


func _event(event: StringName) -> SoundEvent:
	var ev: SoundEvent = BANK.events.get(event)
	if not ev or ev.streams.is_empty():
		push_warning("AudioManager: no sound for event '%s'" % event)
		return null
	return ev


func _setup(player: Node, ev: SoundEvent) -> void:
	var stream: AudioStream = ev.streams.pick_random()
	if ev.loop and "loop" in stream:
		stream.loop = true
	player.stream = stream
	player.bus = ev.bus
	player.volume_db = ev.volume_db
	player.pitch_scale = 1.0 + randf_range(-ev.pitch_variance, ev.pitch_variance)
	if player is AudioStreamPlayer3D:
		player.unit_size = ev.unit_size
		player.max_distance = ev.max_distance


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for b in BUSES:
		var v: float = cfg.get_value("volume", b, 1.0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(b), linear_to_db(v))
