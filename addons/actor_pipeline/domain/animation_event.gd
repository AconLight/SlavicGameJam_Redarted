@tool
class_name AnimationEvent
extends Resource

enum EventType {
	HITBOX_ENABLE,
	HITBOX_DISABLE,
	PLAY_SOUND,
	ACTION_COMPLETE,
	CUSTOM,
}

@export var event_id: StringName
@export var enabled := true

@export_group("Trigger")
@export var animation_role: StringName
@export var animation_name_override: StringName
@export_range(0, 999, 1) var frame := 0
@export var fire_once_per_playback := true

@export_group("Action")
@export var event_type := EventType.CUSTOM
@export var target_id: StringName
@export var payload: Dictionary = {}
