@tool
extends Node2D

## Gruszka od CB zwisająca na kablu — atrapa z dwóch prostokątów, zanim
## będzie grafika. Węzeł stoi w punkcie zaczepienia kabla, a rysunek leci
## w dół, więc obrót węzła kiwa całością jak wahadłem.
##
## Rozmach kołysania bierze się z drżenia kamery: na gładkiej drodze
## gruszka ledwo dynda, na wybojach rzuca nią wyraźnie. Dzięki temu kabina
## i gruszka reagują na tę samą drogę, zamiast każde na swój zegar.
##
## Jest @tool, więc widać ją w edytorze i da się ustawić myszką.

## Kamera kabiny. Bez niej gruszka kiwa się samym minimalnym rozmachem.
@export_node_path("Camera2D") var camera_path: NodePath

@export_group("Kształt")

@export_range(20.0, 800.0, 1.0) var cable_length := 300.0:
	set(value):
		cable_length = value
		queue_redraw()

@export_range(1.0, 40.0, 1.0) var cable_width := 8.0:
	set(value):
		cable_width = value
		queue_redraw()

@export var body_size := Vector2(90.0, 160.0):
	set(value):
		body_size = value
		queue_redraw()

@export var cable_color := Color(0.12, 0.1, 0.14, 1.0):
	set(value):
		cable_color = value
		queue_redraw()

@export var body_color := Color(0.16, 0.14, 0.19, 1.0):
	set(value):
		body_color = value
		queue_redraw()

@export_group("Kiwanie")

## Wychylenie na gładkiej drodze, w stopniach.
@export_range(0.0, 30.0, 0.5) var swing_degrees_min := 2.0

## Wychylenie przy mocnym wyboju, w stopniach.
@export_range(0.0, 60.0, 0.5) var swing_degrees_max := 11.0

## Ile pełnych wahnięć na sekundę. Gruszka na kablu buja się wolniej niż
## trzęsie się sama kabina.
@export_range(0.05, 4.0, 0.05) var swing_frequency := 0.8

var _camera: Node2D
var _time := 0.0


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Node2D


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_time += delta

	var intensity := 0.0
	if _camera != null and _camera.has_method(&"shake_intensity"):
		intensity = _camera.shake_intensity()

	var reach := lerpf(swing_degrees_min, swing_degrees_max, intensity)
	var wave := sin(_time * TAU * swing_frequency)
	wave += 0.35 * sin(_time * TAU * swing_frequency * 1.7 + 0.9)
	rotation_degrees = wave * reach


func _draw() -> void:
	draw_rect(Rect2(-cable_width * 0.5, 0.0, cable_width, cable_length), cable_color)
	draw_rect(Rect2(-body_size.x * 0.5, cable_length, body_size.x, body_size.y), body_color)
