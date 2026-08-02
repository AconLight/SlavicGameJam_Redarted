class_name HitboxController
extends Node

func enable_hitbox(hitbox_id: StringName) -> bool:
	return _set_hitbox_enabled(hitbox_id, true)


func disable_hitbox(hitbox_id: StringName) -> bool:
	return _set_hitbox_enabled(hitbox_id, false)


func disable_all_hitboxes() -> void:
	for hitbox in get_tree().get_nodes_in_group(&"actor_hitbox"):
		if _belongs_to_this_actor(hitbox):
			_set_area_enabled(hitbox, false)


func has_hitbox(hitbox_id: StringName) -> bool:
	return _find_hitbox(hitbox_id) != null


func _set_hitbox_enabled(hitbox_id: StringName, enabled: bool) -> bool:
	var hitbox := _find_hitbox(hitbox_id)
	if hitbox == null:
		return false
	_set_area_enabled(hitbox, enabled)
	return true


func _find_hitbox(hitbox_id: StringName) -> Area2D:
	for hitbox in get_tree().get_nodes_in_group(&"actor_hitbox"):
		if hitbox is Area2D and _belongs_to_this_actor(hitbox) and hitbox.get_meta(&"hitbox_id", &"") == hitbox_id:
			return hitbox
	return null


func _belongs_to_this_actor(hitbox: Node) -> bool:
	return get_parent() != null and get_parent().is_ancestor_of(hitbox)


func _set_area_enabled(hitbox: Area2D, enabled: bool) -> void:
	hitbox.set_deferred(&"monitoring", enabled)
	hitbox.set_deferred(&"monitorable", enabled)
	for child in hitbox.get_children():
		if child is CollisionShape2D:
			child.set_deferred(&"disabled", not enabled)
