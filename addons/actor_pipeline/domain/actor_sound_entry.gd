@tool
class_name ActorSoundEntry
extends Resource

@export var sound_id: StringName
@export var streams: Array[AudioStream] = []
@export_range(-80.0, 24.0, 0.1) var volume_db := 0.0
@export_range(0.1, 4.0, 0.01) var pitch_min := 1.0
@export_range(0.1, 4.0, 0.01) var pitch_max := 1.0
@export var bus: StringName = &"SFX"
