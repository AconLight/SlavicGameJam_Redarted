class_name RoadsideSpeedCamera
extends Node2D

## A scrollable roadside speed camera. Enforcement systems can listen to the
## signal hub; this asset only detects, flashes, and reports the photograph.

@export var camera_id: StringName = &"roadside_speed_meter"
@export_range(1.0, 300.0, 1.0) var speed_limit_kmh := 90.0
@export_range(0.0, 1.0, 0.01) var detection_road_distance := 0.72
@export_range(0.01, 2.0, 0.01) var pre_flash_glow_seconds := 0.18
@export_range(0.05, 2.0, 0.05) var flash_duration := 0.25
@export_range(0.1, 5.0, 0.05) var afterglow_duration := 1.2

var _has_reported := false
var _flash_left := 0.0
var _afterglow_left := 0.0
var _pre_flash_glow_left := 0.0
var _violation_pending := false
var _signalist: GameStateSignalist
var _scroll_element: ScrollElement2D

const LENS_POSITION := Vector2(-40, -685)


func _ready() -> void:
	_scroll_element = get_parent() as ScrollElement2D
	call_deferred("_connect_signalist")
	queue_redraw()


func _process(_delta: float) -> void:
	if not _has_reported and _scroll_element != null and _scroll_element.road_distance >= detection_road_distance:
		_has_reported = true
		if _signalist != null:
			if _signalist.current_speed_kmh > speed_limit_kmh:
				_violation_pending = true
				_pre_flash_glow_left = pre_flash_glow_seconds
			else:
				_signalist.report_speed_camera_passed(camera_id, speed_limit_kmh)
	if _violation_pending:
		_pre_flash_glow_left = maxf(0.0, _pre_flash_glow_left - _delta)
		if _pre_flash_glow_left <= 0.0:
			_violation_pending = false
			_flash_left = flash_duration
			_afterglow_left = afterglow_duration
			_signalist.report_speed_camera_passed(camera_id, speed_limit_kmh)
	_flash_left = maxf(0.0, _flash_left - _delta)
	_afterglow_left = maxf(0.0, _afterglow_left - _delta)
	queue_redraw()


func _connect_signalist() -> void:
	_signalist = get_tree().get_first_node_in_group(&"game_state_signalist") as GameStateSignalist
	if _signalist == null:
		push_warning("RoadsideSpeedCamera could not find GameStateSignalist.")
		return
	queue_redraw()


func _draw() -> void:
	# The final fotoradar artwork is a child Sprite2D. Draw only its triggered flash.
	var glow_progress := _afterglow_left / afterglow_duration
	if _pre_flash_glow_left > 0.0:
		var pre_flash_progress := 1.0 - (_pre_flash_glow_left / pre_flash_glow_seconds)
		glow_progress = maxf(glow_progress, pre_flash_progress)
	if glow_progress <= 0.0:
		return
	# Several translucent circles make a small point-light bloom without requiring
	# a separate light texture or changing the scene's global lighting setup.
	draw_circle(LENS_POSITION, 100.0, Color(1.0, 0.89, 0.56, 0.24 * glow_progress))
	draw_circle(LENS_POSITION, 64.0, Color(1.0, 0.92, 0.68, 0.52 * glow_progress))
	draw_circle(LENS_POSITION, 32.0, Color(1.0, 0.98, 0.88, 0.92 * glow_progress))
	if _flash_left > 0.0:
		draw_circle(LENS_POSITION, 10.0, Color(1.0, 1.0, 0.96, 1.0))
