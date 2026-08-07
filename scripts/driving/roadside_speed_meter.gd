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
	# Texture-free placeholder: a pole-mounted camera with a visible limit plate.
	draw_rect(Rect2(-7, -2, 14, 38), Color("44484b"), true)
	draw_rect(Rect2(-26, -46, 52, 38), Color("5d6265"), true)
	draw_rect(Rect2(-26, -46, 52, 38), Color("1b1d1f"), false, 3.0)
	draw_circle(Vector2(10, -28), 9.0, Color("151719"))
	draw_circle(Vector2(10, -28), 5.0, Color("c84232") if _flash_left <= 0.0 else Color.WHITE)
	draw_circle(Vector2(10, -28), 2.0, Color("24110d"))
	draw_circle(Vector2(-9, -28), 11.0, Color("f0eee7"))
	draw_arc(Vector2(-9, -28), 9.0, 0.0, TAU, 24, Color("c43232"), 2.5)
	draw_string(ThemeDB.fallback_font, Vector2(-16, -24), str(roundi(speed_limit_kmh)), HORIZONTAL_ALIGNMENT_LEFT, 16, 9, Color("171a1d"))
	if _flash_left > 0.0:
		draw_circle(Vector2(26, -38), 22.0, Color(1.0, 1.0, 0.93, 0.7))
