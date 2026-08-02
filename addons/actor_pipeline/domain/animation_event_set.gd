@tool
class_name AnimationEventSet
extends Resource

@export var events: Array[AnimationEvent] = []

func get_events_for_frame(animation_name: StringName, semantic_role: StringName, frame: int) -> Array[AnimationEvent]:
	var matches: Array[AnimationEvent] = []
	for event in events:
		if event == null or not event.enabled or event.frame != frame:
			continue
		var matches_role := event.animation_role != &"" and event.animation_role == semantic_role
		var matches_animation := event.animation_name_override != &"" and event.animation_name_override == animation_name
		if matches_role or matches_animation:
			matches.append(event)
	return matches
