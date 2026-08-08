class_name RoadsideSpeedCamera
extends Node2D

## A scrollable roadside speed camera. Enforcement systems can listen to the
## signal hub; this asset only detects, flashes, and reports the photograph.

@export var camera_id: StringName = &"roadside_speed_meter"
@export_range(1.0, 300.0, 1.0) var speed_limit_kmh := 90.0
@export_range(0.0, 1.0, 0.01) var detection_road_distance := 0.72
@export_range(0.05, 2.0, 0.05) var flash_duration := 0.25

var _has_reported := false
var _flash_left := 0.0
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
				_flash_left = flash_duration
			_signalist.report_speed_camera_passed(camera_id, speed_limit_kmh)
	_flash_left = maxf(0.0, _flash_left - _delta)
	queue_redraw()


func _connect_signalist() -> void:
	_signalist = get_tree().get_first_node_in_group(&"game_state_signalist") as GameStateSignalist
	if _signalist == null:
		push_warning("RoadsideSpeedCamera could not find GameStateSignalist.")
		return
	queue_redraw()


func _draw() -> void:
	# The final fotoradar artwork is a child Sprite2D. Draw only its triggered flash.
	if _flash_left > 0.0:
		draw_circle(LENS_POSITION, 42.0, Color(1.0, 1.0, 0.93, 0.82))
