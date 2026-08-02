@tool
extends EditorPlugin

const ActorPipelineDock := preload("res://addons/actor_pipeline/editor/actor_pipeline_dock.gd")

var _dock: Control

func _enter_tree() -> void:
	_dock = ActorPipelineDock.new()
	_dock.name = "Actor Pipeline"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
