@tool
extends Node2D

## Kierownica jako rysowany pierścień ze szprychami — atrapa na czas,
## zanim będzie grafika. Kołysze się delikatnie lewo-prawo, jakby
## kierowca trzymał ją luźno i korygował tor jazdy.
##
## Szprychy, piasta i znacznik na godzinie dwunastej są po to, żeby obrót
## było widać. Sam okrąg wygląda przy kręceniu na nieruchomy.
##
## Jest @tool, więc widać ją też w edytorze i da się ustawić myszką.

@export_range(10.0, 600.0, 1.0) var radius := 180.0:
	set(value):
		radius = value
		queue_redraw()

@export_range(1.0, 60.0, 1.0) var thickness := 16.0:
	set(value):
		thickness = value
		queue_redraw()

@export var color := Color(0.09, 0.07, 0.11, 1.0):
	set(value):
		color = value
		queue_redraw()

@export_group("Szprychy")

## Ile szprych. 0 zostawia sam pierścień.
@export_range(0, 8, 1) var spokes := 3:
	set(value):
		spokes = value
		queue_redraw()

## Obrót wachlarza szprych w stopniach. Przy trzech szprychach 0 daje
## jedną w dół i dwie na boki.
@export_range(0.0, 360.0, 1.0) var spoke_offset_degrees := 90.0:
	set(value):
		spoke_offset_degrees = value
		queue_redraw()

## Promień piasty jako ułamek promienia koła.
@export_range(0.0, 0.6, 0.01) var hub_ratio := 0.22:
	set(value):
		hub_ratio = value
		queue_redraw()

@export_group("Znacznik")

## Klocek na godzinie dwunastej. Najlepiej widać po nim obrót.
@export var show_marker := true:
	set(value):
		show_marker = value
		queue_redraw()

@export var marker_color := Color(0.85, 0.25, 0.2, 1.0):
	set(value):
		marker_color = value
		queue_redraw()

@export_group("Zatrzymanie na czas czynności")

@export_node_path("Node") var controller_path: NodePath

## Przy których czynnościach kierownica staje. Wszystko, co pod nią wisi —
## w tym ręka — staje razem z nią, bo dziedziczy jej obrót.
@export var pause_activity_ids: Array[StringName] = [&"cb_radio", &"radio"]

## Ile trwa wyhamowanie do bezruchu i powrót do kołysania.
@export_range(0.05, 3.0, 0.05) var pause_seconds := 0.35

@export_group("Kołysanie")

## Maksymalne wychylenie w stopniach. Ma być ledwo widoczne.
@export_range(0.0, 45.0, 0.5) var sway_degrees := 3.0

## Ile pełnych wahnięć na sekundę.
@export_range(0.05, 4.0, 0.05) var sway_frequency := 0.35

var _time := 0.0

## 0 = kołysze się, 1 = stoi. Mieszanie, żeby zatrzymanie i powrót nie
## szarpały kierownicą.
var _pause_blend := 0.0
var _paused := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var controller := get_node_or_null(controller_path) as CabinActivityController
	if controller == null:
		return
	controller.activity_started.connect(_on_activity_started)
	controller.activity_ended.connect(_on_activity_ended)


func _on_activity_started(started_id: StringName) -> void:
	if pause_activity_ids.has(started_id):
		_paused = true


func _on_activity_ended(ended_id: StringName, _held_seconds: float) -> void:
	if pause_activity_ids.has(ended_id):
		_paused = false


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_pause_blend = move_toward(_pause_blend, 1.0 if _paused else 0.0, delta / maxf(pause_seconds, 0.01))

	# W pełnym bezruchu nie liczymy dalej czasu, więc po puszczeniu czynności
	# kołysanie wraca z tej samej fazy i nie przeskakuje.
	if is_equal_approx(_pause_blend, 1.0):
		return

	_time += delta
	# Dwie fale o niewspółmiernych częstotliwościach, tak jak przy
	# wybojach — pojedyncza sinusoida wygląda jak wahadło zegara.
	var wave := sin(_time * TAU * sway_frequency)
	wave += 0.4 * sin(_time * TAU * sway_frequency * 1.6 + 0.7)
	rotation_degrees = wave * sway_degrees * (1.0 - _pause_blend)


func _draw() -> void:
	var hub := radius * hub_ratio

	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, color, thickness, true)

	if spokes > 0:
		var base := deg_to_rad(spoke_offset_degrees)
		for i in spokes:
			var dir := Vector2.RIGHT.rotated(base + TAU * i / spokes)
			draw_line(dir * hub, dir * (radius - thickness * 0.5), color, thickness * 0.75, true)

	if hub > 0.0:
		draw_circle(Vector2.ZERO, hub, color)

	if show_marker:
		var up := Vector2.UP * radius
		draw_line(up * 0.78, up, marker_color, thickness * 1.1, true)
