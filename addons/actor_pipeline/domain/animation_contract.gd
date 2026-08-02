@tool
class_name AnimationContract
extends Resource

@export var entries: Array[AnimationContractEntry] = []

func get_entry_for_role(semantic_role: StringName) -> AnimationContractEntry:
	for entry in entries:
		if entry != null and entry.semantic_role == semantic_role:
			return entry
	return null


func get_entry_for_animation(animation_name: StringName) -> AnimationContractEntry:
	for entry in entries:
		if entry != null and entry.animation_name == animation_name:
			return entry
	return null
