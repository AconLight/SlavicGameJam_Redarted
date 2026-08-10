@tool
extends Node2D

## Tarcza odliczająca blokadę czynności — kółko, które zjada się jak wskazówka
## zegara i pokazuje, ile jeszcze CB milczy.
##
## Bez cyfr, bo w kabinie nie ma na nie miejsca ani czasu: pełne kółko znaczy
## „dopiero się zwinęło", puste „już można łapać". Chodzi o to, żeby gracz
## przestał klikać w zwiniętą gruszkę, nie o dokładny odczyt sekund.
##
## Postęp bierzemy gotowy z blokady (cabin_activity_cooldown.gd), a nie liczymy
## czasu drugi raz u siebie — dwa zegary rozjechałyby się i wskazówka dobiłaby
## do zera w innej chwili niż faktyczne odblokowanie.
##
## Jest @tool, więc widać ją w edytorze i da się ustawić myszką.

## Węzeł blokady z metodami progress() i is_locked().
@export_node_path("Node") var cooldown_path: NodePath

@export_range(4.0, 200.0, 1.0) var radius := 34.0:
	set(value):
		radius = value
		queue_redraw()

## Grubość pierścienia. 0 rysuje pełne koło zamiast obwódki.
@export_range(0.0, 40.0, 0.5) var thickness := 7.0:
	set(value):
		thickness = value
		queue_redraw()

@export var color := Color(0.95, 0.85, 0.45, 0.9):
	set(value):
		color = value
		queue_redraw()

## Ślad po całej tarczy, żeby było widać, ile już zjechało.
@export var track_color := Color(0.08, 0.07, 0.1, 0.45):
	set(value):
		track_color = value
		queue_redraw()

## Ile tarczy pokazać w edytorze, od 0 do 1.
@export_range(0.0, 1.0, 0.05) var preview_progress := 0.7:
	set(value):
		preview_progress = value
		queue_redraw()

var _cooldown: Node


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_cooldown = get_node_or_null(cooldown_path)
	if _cooldown == null:
		push_warning("[tarcza] nie ma blokady pod \"%s\"" % cooldown_path)
	visible = false


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _cooldown == null or not _cooldown.has_method(&"is_locked"):
		return
	visible = _cooldown.call(&"is_locked")
	if visible:
		queue_redraw()


func _draw() -> void:
	var progress := preview_progress if Engine.is_editor_hint() else _progress()
	if progress <= 0.0:
		return

	# Wskazówka rusza z godziny dwunastej i idzie zgodnie z ruchem zegara,
	# a kółko zjada się od tyłu, bo pokazuje resztę, nie postęp.
	var start := -PI * 0.5
	var end := start + TAU * progress

	if thickness <= 0.0:
		draw_circle(Vector2.ZERO, radius, track_color)
		draw_circle(Vector2.ZERO, radius * progress, color)
		return

	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, track_color, thickness, true)
	draw_arc(Vector2.ZERO, radius, start, end, 64, color, thickness, true)


func _progress() -> float:
	if _cooldown == null or not _cooldown.has_method(&"progress"):
		return 0.0
	return _cooldown.call(&"progress")
