@tool
extends Node2D

## Nutki nad radiem — tyle prostokącików, ile chillu na sekundę leci teraz
## z grającego radia. Podskakują, więc widać, że radio pracuje, i widać, ile
## było warte kręcenie gałką.
##
## Jest @tool, żeby dało się je ustawić myszką. W edytorze rysuje `preview_notes`
## sztuk, bo bez uruchomionej gry nie ma skąd wziąć prawdziwej liczby.

## Węzeł z metodami chill_per_second() i is_playing() — w grze radio w tle.
@export_node_path("Node") var source_path: NodePath

@export var color := Color(0.06, 0.05, 0.08, 1.0)

## Rozmiar jednej nutki.
@export var note_size := Vector2(22.0, 30.0):
	set(value):
		note_size = value
		queue_redraw()

## Odstęp między nutkami.
@export_range(0.0, 120.0, 1.0) var spacing := 16.0:
	set(value):
		spacing = value
		queue_redraw()

## O ile pikseli nutka skacze w górę i w dół.
@export_range(0.0, 200.0, 1.0) var bounce_pixels := 14.0

## Ile podskoków na sekundę.
@export_range(0.05, 8.0, 0.05) var bounce_frequency := 1.4

## Przesunięcie fazy między kolejnymi nutkami w obrotach. 0 = wszystkie skaczą
## równo, co wygląda jak jeden klocek. Ułamek rozsypuje je na falę.
@export_range(0.0, 1.0, 0.01) var phase_step := 0.18

## Ile nutek pokazywać w edytorze. W grze bez znaczenia.
@export_range(0, 30, 1) var preview_notes := 3:
	set(value):
		preview_notes = value
		queue_redraw()

var _source: Node
var _time := 0.0
var _count := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_source = get_node_or_null(source_path)
	if not source_path.is_empty() and _source == null:
		push_warning("[nutki] nie ma źródła pod \"%s\"" % source_path)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var count := 0
	if _source != null and _source.has_method(&"chill_per_second"):
		count = _source.call(&"chill_per_second")

	# Zegar chodzi tylko wtedy, gdy coś gra, więc każde granie zaczyna się od
	# nutek w spoczynku, a nie w losowym miejscu skoku.
	if count <= 0:
		if _count != 0:
			_count = 0
			_time = 0.0
			queue_redraw()
		return

	_count = count
	_time += delta
	queue_redraw()


func _draw() -> void:
	var count := preview_notes if Engine.is_editor_hint() else _count
	if count <= 0:
		return

	var step := note_size.x + spacing
	# Rysujemy od środka węzła, żeby rząd nutek rósł na boki równo i pinezka
	# została tam, gdzie ją postawiono.
	var start_x := -(count - 1) * step * 0.5

	for index in count:
		var phase := TAU * (_time * bounce_frequency + index * phase_step)
		var lift := sin(phase) * bounce_pixels
		var top_left := Vector2(start_x + index * step - note_size.x * 0.5, -note_size.y * 0.5 - lift)
		draw_rect(Rect2(top_left, note_size), color)
