@tool
extends Node2D

## Czerwona kreska częstotliwości, jeżdżąca lewo-prawo razem z gałką.
##
## Nie liczy nic sama — pyta gałkę o jej wychylenie. Gdyby miała własny
## zegar, po chwili sunęłaby w inną stronę niż gałka się kręci.

## Gałka, z której bierze wychylenie.
@export_node_path("Node2D") var knob_path: NodePath

## Jak daleko odjeżdża od swojego miejsca, w pikselach w każdą stronę.
## To jest to pokrętło od zasięgu paska — kręć nim do woli.
@export_range(0.0, 200.0, 0.5) var travel := 20.0

@export var bar_size := Vector2(6.0, 44.0):
	set(value):
		bar_size = value
		queue_redraw()

@export var bar_color := Color(0.86, 0.16, 0.16, 1.0):
	set(value):
		bar_color = value
		queue_redraw()

var _knob: Node2D
var _home_x := 0.0


func _ready() -> void:
	_home_x = position.x
	if Engine.is_editor_hint():
		return
	_knob = get_node_or_null(knob_path) as Node2D


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _knob == null or not _knob.has_method(&"tuning_value"):
		return
	position.x = _home_x + _knob.tuning_value() * travel


func _draw() -> void:
	draw_rect(Rect2(-bar_size.x * 0.5, -bar_size.y * 0.5, bar_size.x, bar_size.y), bar_color)
