class_name SoundEvent
extends Resource
## One named sound: which file(s), how loud, which bus. Edited in data/audio/sound_bank.tres.

@export var streams: Array[AudioStream] = [] ## one is picked at random per play
@export var bus: StringName = &"SFX"
@export var volume_db := 0.0
@export var pitch_variance := 0.0 ## ± fraction, e.g. 0.08 for footsteps
@export var loop := false
@export_group("3D")
@export var unit_size := 6.0
@export var max_distance := 40.0
