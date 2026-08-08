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

## Grafika nutki. Powinna być biała: barwa nakłada się mnożeniem, więc biel
## przyjmuje każdy kolor, a to, co na grafice jest czarne, czarne zostanie.
## Puste = rysujemy zastępcze prostokąciki.
@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()

## Kolory kolejnych nutek, brane po kolei od lewej. Krótsza lista niż rząd
## nutek zaczyna się powtarzać od początku.
##
## Kolor wynika z miejsca w rzędzie, nie z losowania — ta sama nutka ma zawsze
## ten sam kolor przez całe granie, więc rząd nie migocze.
@export var colors: Array[Color] = [
	Color(0.93, 0.27, 0.24, 1.0),
	Color(0.98, 0.72, 0.20, 1.0),
	Color(0.42, 0.78, 0.35, 1.0),
	Color(0.29, 0.62, 0.89, 1.0),
	Color(0.66, 0.40, 0.82, 1.0),
	Color(0.96, 0.47, 0.62, 1.0),
	Color(0.31, 0.78, 0.74, 1.0),
	Color(0.99, 0.55, 0.26, 1.0),
]:
	set(value):
		colors = value
		queue_redraw()

## Ile razy powiększyć grafikę nutki. Bez znaczenia dla zastępczych
## prostokącików — te trzymają się `note_size`.
@export_range(0.05, 20.0, 0.05) var note_scale := 1.0:
	set(value):
		note_scale = value
		queue_redraw()

## Rozmiar zastępczego prostokącika, gdy nie ma grafiki.
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

	var size := note_size
	if texture != null:
		size = texture.get_size() * note_scale

	var step := size.x + spacing
	# Rysujemy od środka węzła, żeby rząd nutek rósł na boki równo i pinezka
	# została tam, gdzie ją postawiono.
	var start_x := -(count - 1) * step * 0.5

	for index in count:
		var phase := TAU * (_time * bounce_frequency + index * phase_step)
		var lift := sin(phase) * bounce_pixels
		var top_left := Vector2(start_x + index * step - size.x * 0.5, -size.y * 0.5 - lift)
		var tint := _color_for(index)
		if texture != null:
			draw_texture_rect(texture, Rect2(top_left, size), false, tint)
		else:
			draw_rect(Rect2(top_left, size), tint)


func _color_for(index: int) -> Color:
	if colors.is_empty():
		return Color.WHITE
	return colors[index % colors.size()]
