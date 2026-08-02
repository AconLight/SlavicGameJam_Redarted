class_name ActorAudioController
extends Node

@export var audio_player_path: NodePath
@export var sound_set: ActorSoundSet

var audio_player: AudioStreamPlayer2D

var _random := RandomNumberGenerator.new()

func _ready() -> void:
	audio_player = get_node_or_null(audio_player_path) as AudioStreamPlayer2D

func play_sound(sound_id: StringName) -> bool:
	if audio_player == null or sound_set == null:
		return false
	var sound := sound_set.get_sound(sound_id)
	if sound == null or sound.streams.is_empty():
		return false
	var valid_streams: Array[AudioStream] = []
	for stream in sound.streams:
		if stream != null:
			valid_streams.append(stream)
	if valid_streams.is_empty():
		return false
	audio_player.stream = valid_streams[_random.randi_range(0, valid_streams.size() - 1)]
	audio_player.volume_db = sound.volume_db
	audio_player.pitch_scale = _random.randf_range(sound.pitch_min, sound.pitch_max)
	audio_player.bus = sound.bus
	audio_player.play()
	return true
