@tool
extends EditorPlugin

const ActorPipelineDock := preload("res://addons/actor_pipeline/editor/actor_pipeline_dock.gd")
const LAIGTER_COMMAND_SETTING := "actor_pipeline/lighting/laigter_command"

var _dock: Control

func _enter_tree() -> void:
	var settings := EditorInterface.get_editor_settings()
	if not settings.has_setting(LAIGTER_COMMAND_SETTING):
		settings.set_setting(LAIGTER_COMMAND_SETTING, "")
	settings.set_initial_value(LAIGTER_COMMAND_SETTING, "", false)
	settings.add_property_info({
		"name": LAIGTER_COMMAND_SETTING,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.exe",
	})
	_dock = ActorPipelineDock.new()
	_dock.name = "Actor Pipeline"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
