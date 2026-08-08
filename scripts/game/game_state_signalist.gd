class_name GameStateSignalist
extends Node

## Small, scene-independent relay for shared gameplay state.
## Systems listen here instead of reaching into the cabin's accelerator directly.

signal driving_speed_changed(speed_kmh: float)
signal speed_camera_passed(camera_id: StringName, speed_kmh: float, speed_limit_kmh: float)
signal speed_camera_triggered(camera_id: StringName, speed_kmh: float, speed_limit_kmh: float)
signal speed_camera_photo_taken(camera_id: StringName, speed_kmh: float, speed_limit_kmh: float)
signal speed_camera_trigger
# Obstacle & Event Signals
signal car_break_check()
signal car_break_checked()

@export_group("Sources")
@export_node_path("Node") var accelerator_path: NodePath

var current_speed_kmh := 0.0
var _accelerator: Node


func _ready() -> void:
	add_to_group(&"game_state_signalist")
	call_deferred("_connect_accelerator")


# --- Speed Camera Reporting ---

func _on_trigger_speed_camera():
	speed_camera_trigger.emit()

func report_speed_camera_passed(camera_id: StringName, speed_limit_kmh: float) -> void:
	speed_camera_passed.emit(camera_id, current_speed_kmh, speed_limit_kmh)


func report_speed_camera_photo_taken(camera_id: StringName, speed_limit_kmh: float) -> void:
	speed_camera_triggered.emit(camera_id, current_speed_kmh, speed_limit_kmh)
	speed_camera_photo_taken.emit(camera_id, current_speed_kmh, speed_limit_kmh)


# --- Brake Check Reporting ---

func report_car_brake_check() -> void:
	car_break_check.emit()


func report_car_brake_checked() -> void:
	car_break_checked.emit()


# --- Accelerator Setup ---

func _connect_accelerator() -> void:
	_accelerator = get_node_or_null(accelerator_path)
	if _accelerator == null:
		_accelerator = get_tree().get_first_node_in_group(&"accelerometer")
	if _accelerator == null:
		push_warning("GameStateSignalist could not find an accelerator source.")
		return
	if _accelerator.has_method("get"):
		current_speed_kmh = float(_accelerator.get("speed"))
	if _accelerator.has_signal(&"speed_changed") and not _accelerator.speed_changed.is_connected(_on_accelerator_speed_changed):
		_accelerator.speed_changed.connect(_on_accelerator_speed_changed)
	driving_speed_changed.emit(current_speed_kmh)


func _on_accelerator_speed_changed(speed_kmh: float) -> void:
	current_speed_kmh = speed_kmh
	driving_speed_changed.emit(current_speed_kmh)


# Backward-compatibility wrappers so existing calls don't crash
func _on_car_break_checked() -> void:
	report_car_brake_checked()

func _on_car_break_check() -> void:
	report_car_brake_check()
