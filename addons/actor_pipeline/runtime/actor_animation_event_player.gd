class_name ActorAnimationEventPlayer
extends Node

signal event_triggered(event: AnimationEvent)
signal custom_event_triggered(event_id: StringName, payload: Dictionary)
signal action_completed(semantic_role: StringName)

@export var animator_path: NodePath
@export var visual_controller_path: NodePath
@export var hitbox_controller_path: NodePath
@export var audio_controller_path: NodePath
@export var event_set: AnimationEventSet

var animator: ActorAnimator
var visual_controller: ActorVisualController
var hitbox_controller: HitboxController
var audio_controller: ActorAudioController

var _fired_event_ids: Dictionary = {}

func _ready() -> void:
	animator = get_node_or_null(animator_path) as ActorAnimator
	visual_controller = get_node_or_null(visual_controller_path) as ActorVisualController
	hitbox_controller = get_node_or_null(hitbox_controller_path) as HitboxController
	audio_controller = get_node_or_null(audio_controller_path) as ActorAudioController
	if animator != null:
		animator.animation_started.connect(_on_animation_started)
	if visual_controller != null:
		visual_controller.animation_frame_changed.connect(_on_animation_frame_changed)


func bind(
	new_animator: ActorAnimator,
	new_event_set: AnimationEventSet
) -> void:
	animator = new_animator
	event_set = new_event_set


func reset_playback_state() -> void:
	_fired_event_ids.clear()


func _on_animation_started(_semantic_role: StringName, _animation_name: StringName) -> void:
	reset_playback_state()
	_dispatch_current_frame()


func _on_animation_frame_changed(_animation_name: StringName, _frame: int) -> void:
	_dispatch_current_frame()


func _dispatch_current_frame() -> void:
	if event_set == null or visual_controller == null or animator == null:
		return
	var events := event_set.get_events_for_frame(
		visual_controller.get_current_animation(),
		animator.get_current_role(),
		visual_controller.get_current_frame()
	)
	for event in events:
		if event.fire_once_per_playback and _fired_event_ids.has(event.event_id):
			continue
		if event.fire_once_per_playback:
			_fired_event_ids[event.event_id] = true
		_dispatch_event(event)


func _dispatch_event(event: AnimationEvent) -> void:
	match event.event_type:
		AnimationEvent.EventType.HITBOX_ENABLE:
			if hitbox_controller != null:
				hitbox_controller.enable_hitbox(event.target_id)
		AnimationEvent.EventType.HITBOX_DISABLE:
			if hitbox_controller != null:
				hitbox_controller.disable_hitbox(event.target_id)
		AnimationEvent.EventType.PLAY_SOUND:
			if audio_controller != null:
				audio_controller.play_sound(event.target_id)
		AnimationEvent.EventType.ACTION_COMPLETE:
			action_completed.emit(animator.get_current_role())
		AnimationEvent.EventType.CUSTOM:
			custom_event_triggered.emit(event.event_id, event.payload)
	event_triggered.emit(event)
