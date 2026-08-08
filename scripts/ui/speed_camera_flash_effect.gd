class_name SpeedCameraFlashEffect
extends CanvasLayer

## Full-screen enforcement-camera flash. It listens to GameStateSignalist so
## camera objects stay responsible only for detecting a violation.

@export_range(0.0, 1.0, 0.01) var peak_alpha := 0.99
@export_range(0.01, 1.0, 0.01) var flash_in_seconds := 0.02
@export_range(0.0, 1.0, 0.01) var hold_seconds := 0.08
@export_range(0.05, 5.0, 0.05) var fade_seconds := 1.35

@onready var _overlay: ColorRect = $Overlay

var _elapsed := -1.0
var _signalist: GameStateSignalist


func _ready() -> void:
	_overlay.color.a = 0.0
	call_deferred("_connect_signalist")


func _process(delta: float) -> void:
	if _elapsed < 0.0:
		return
	_elapsed += delta
	_overlay.color.a = _flash_alpha_at(_elapsed)
	if _elapsed >= flash_in_seconds + hold_seconds + fade_seconds:
		_elapsed = -1.0
		_overlay.color.a = 0.0


func _connect_signalist() -> void:
	_signalist = get_tree().get_first_node_in_group(&"game_state_signalist") as GameStateSignalist
	if _signalist == null:
		push_warning("SpeedCameraFlashEffect could not find GameStateSignalist.")
		return
	if not _signalist.speed_camera_triggered.is_connected(_on_speed_camera_triggered):
		_signalist.speed_camera_triggered.connect(_on_speed_camera_triggered)


func _on_speed_camera_triggered(_camera_id: StringName, _speed_kmh: float, _speed_limit_kmh: float) -> void:
	# Restart at full intensity if another camera catches the player mid-fade.
	_elapsed = 0.0
	_overlay.color.a = 0.0


func _flash_alpha_at(elapsed: float) -> float:
	if elapsed < flash_in_seconds:
		return peak_alpha * (elapsed / flash_in_seconds)
	if elapsed < flash_in_seconds + hold_seconds:
		return peak_alpha
	var fade_progress := clampf((elapsed - flash_in_seconds - hold_seconds) / fade_seconds, 0.0, 1.0)
	# Squared easing keeps the blown-out white image around longer, then releases.
	return peak_alpha * pow(1.0 - fade_progress, 2.0)
