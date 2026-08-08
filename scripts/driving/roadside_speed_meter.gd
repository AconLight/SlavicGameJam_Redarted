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

@onready var _flash_sound: AudioStreamPlayer = $FlashSound

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
			_play_flash_detached()
			_signalist.report_speed_camera_photo_taken(camera_id, speed_limit_kmh)
	_flash_left = maxf(0.0, _flash_left - _delta)
	_afterglow_left = maxf(0.0, _afterglow_left - _delta)
	queue_redraw()


## Odtwarza błysk na osobnym, samousuwającym się odtwarzaczu podwieszonym
## pod scenę, a nie na dziecku fotoradaru.
##
## Fotoradar jest elementem przewijanej drogi i zostaje usunięty przez
## ScrollSpawnHandler, gdy jego road_distance przekroczy 1.0. Wyzwala się na
## 0.86, więc do usunięcia zostaje mu ułamek sekundy — a próbka trwa ponad
## cztery. Zagranie na własnym dziecku ucinało dźwięk razem z węzłem.
func _play_flash_detached() -> void:
	if _flash_sound.stream == null:
		return

	var host := get_tree().current_scene
	if host == null:
		_flash_sound.play()
		return

	var player := AudioStreamPlayer.new()
	player.stream = _flash_sound.stream
	player.volume_db = _flash_sound.volume_db
	player.bus = _flash_sound.bus
	host.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


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
