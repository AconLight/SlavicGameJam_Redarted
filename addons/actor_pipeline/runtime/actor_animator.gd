class_name ActorAnimator
extends Node

signal animation_started(semantic_role: StringName, animation_name: StringName)
signal animation_finished(semantic_role: StringName, animation_name: StringName)

@export var visual_controller_path: NodePath
@export var animation_contract: AnimationContract

var visual_controller: ActorVisualController

var _current_role: StringName
var _locked := false

func _ready() -> void:
	visual_controller = get_node_or_null(visual_controller_path) as ActorVisualController
	if visual_controller != null and visual_controller.get_sprite() != null:
		visual_controller.get_sprite().animation_finished.connect(_on_animation_finished)


func play_role(semantic_role: StringName, restart := false) -> bool:
	if animation_contract == null:
		return false
	var entry := animation_contract.get_entry_for_role(semantic_role)
	if entry == null:
		return false
	return _play_entry(entry, restart)


func play_animation(animation_name: StringName, restart := false) -> bool:
	if animation_contract == null:
		return false
	var entry := animation_contract.get_entry_for_animation(animation_name)
	if entry == null:
		return false
	return _play_entry(entry, restart)


func force_play_role(semantic_role: StringName) -> bool:
	var was_locked := _locked
	_locked = false
	var did_play := play_role(semantic_role, true)
	if not did_play:
		_locked = was_locked
	return did_play


func unlock() -> void:
	_locked = false


func is_locked() -> bool:
	return _locked


func has_role(semantic_role: StringName) -> bool:
	return animation_contract != null and animation_contract.get_entry_for_role(semantic_role) != null


func get_current_role() -> StringName:
	return _current_role


func _play_entry(entry: AnimationContractEntry, restart: bool) -> bool:
	if visual_controller == null or visual_controller.get_sprite() == null:
		return false
	if _locked and entry.semantic_role != _current_role:
		return false
	var sprite := visual_controller.get_sprite()
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(entry.animation_name):
		return false
	_current_role = entry.semantic_role
	_locked = entry.interruption_policy != AnimationContractEntry.InterruptionPolicy.INTERRUPTIBLE
	sprite.play(entry.animation_name)
	if restart:
		sprite.frame = 0
		sprite.frame_progress = 0.0
	animation_started.emit(_current_role, entry.animation_name)
	return true


func _on_animation_finished() -> void:
	var animation_name := visual_controller.get_current_animation()
	var entry := animation_contract.get_entry_for_animation(animation_name) if animation_contract != null else null
	if entry != null and entry.interruption_policy == AnimationContractEntry.InterruptionPolicy.LOCK_UNTIL_FINISHED:
		_locked = false
	animation_finished.emit(_current_role, animation_name)
