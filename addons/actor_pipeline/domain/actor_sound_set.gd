@tool
class_name ActorSoundSet
extends Resource

@export var sounds: Array[ActorSoundEntry] = []

func get_sound(sound_id: StringName) -> ActorSoundEntry:
	for sound in sounds:
		if sound != null and sound.sound_id == sound_id:
			return sound
	return null
