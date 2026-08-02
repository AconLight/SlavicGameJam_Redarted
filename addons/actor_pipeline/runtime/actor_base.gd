class_name ActorBase
extends CharacterBody2D

@export var definition: ActorDefinition
@export var visual_controller_path: NodePath
@export var animator_path: NodePath
@export var event_player_path: NodePath
@export var hitbox_controller_path: NodePath
@export var audio_controller_path: NodePath

var visual_controller: ActorVisualController
var animator: ActorAnimator
var event_player: ActorAnimationEventPlayer
var hitbox_controller: HitboxController
var audio_controller: ActorAudioController

func _ready() -> void:
	visual_controller = get_node_or_null(visual_controller_path) as ActorVisualController
	animator = get_node_or_null(animator_path) as ActorAnimator
	event_player = get_node_or_null(event_player_path) as ActorAnimationEventPlayer
	hitbox_controller = get_node_or_null(hitbox_controller_path) as HitboxController
	audio_controller = get_node_or_null(audio_controller_path) as ActorAudioController
	if definition == null:
		push_warning("ActorBase has no ActorDefinition assigned.")
		return
	if visual_controller != null:
		visual_controller.set_sprite_frames(definition.sprite_frames)
	if animator != null:
		animator.animation_contract = definition.animation_contract
	if event_player != null:
		event_player.event_set = definition.animation_events
	if audio_controller != null:
		audio_controller.sound_set = definition.sound_set
	if hitbox_controller != null:
		hitbox_controller.disable_all_hitboxes()
