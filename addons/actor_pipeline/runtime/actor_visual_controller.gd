class_name ActorVisualController
extends Node

signal animation_changed(animation_name: StringName)
signal animation_frame_changed(animation_name: StringName, frame: int)

@export var animated_sprite_path: NodePath
var animated_sprite: AnimatedSprite2D

func _ready() -> void:
	animated_sprite = get_node_or_null(animated_sprite_path) as AnimatedSprite2D
	if animated_sprite == null:
		return
	animated_sprite.animation_changed.connect(_on_animation_changed)
	animated_sprite.frame_changed.connect(_on_frame_changed)


func set_sprite_frames(value: SpriteFrames) -> void:
	if animated_sprite != null:
		animated_sprite.sprite_frames = value


func set_facing(direction: float) -> void:
	if animated_sprite != null and not is_zero_approx(direction):
		animated_sprite.flip_h = direction < 0.0


func get_current_animation() -> StringName:
	return animated_sprite.animation if animated_sprite != null else &""


func get_current_frame() -> int:
	return animated_sprite.frame if animated_sprite != null else 0


func get_sprite() -> AnimatedSprite2D:
	return animated_sprite


func _on_animation_changed() -> void:
	animation_changed.emit(get_current_animation())


func _on_frame_changed() -> void:
	animation_frame_changed.emit(get_current_animation(), get_current_frame())
