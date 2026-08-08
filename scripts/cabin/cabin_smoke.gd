@tool
extends Node2D

## Dym z papierosa: cienkie szare kreseczki, które pojawiają się nad węzłem,
## lecą kawałek w górę i zanikają.
##
## Rysowane wprost w _draw(), bez węzła cząstek. Kreseczek jest naraz kilka,
## żyją po ułamku sekundy i nie wchodzą w interakcje z niczym — cały system
## cząstek byłby tu grubszy niż to, co ma pokazać.
##
## Jest @tool, żeby dało się ustawić pozycję myszką. W edytorze rysuje kilka
## nieruchomych kreseczek, bo bez gry nie ma czego animować.

## Węzeł z metodami is_lit() i is_puffing() — w grze papieros. Puste = dym
## leci zawsze, co przydaje się przy ustawianiu.
@export_node_path("Node") var source_path: NodePath

@export var color := Color(0.72, 0.72, 0.75, 0.55)

@export_group("Kreseczki")

## Co ile sekund pojawia się nowa kreseczka, gdy papieros się żarzy.
@export_range(0.02, 2.0, 0.01) var spawn_interval := 0.18

## Ile razy gęściej dymi w trakcie zaciągnięcia.
@export_range(1.0, 10.0, 0.1) var puff_density := 3.0

## Jak długo żyje jedna kreseczka.
@export_range(0.1, 5.0, 0.05) var life_seconds := 1.1

## Jak wysoko wznosi się przez swoje życie.
@export_range(5.0, 400.0, 1.0) var rise_pixels := 70.0

## Długość kreseczki.
@export_range(1.0, 60.0, 1.0) var line_length := 14.0

## Grubość kreseczki.
@export_range(0.5, 8.0, 0.1) var line_width := 2.0

## Na ile pikseli w bok rozjeżdżają się kreseczki przy starcie.
@export_range(0.0, 120.0, 1.0) var spread_pixels := 14.0

## O ile pikseli kreseczka odchyla się w bok, wznosząc się. Nadaje dymowi
## leniwe wężykowanie zamiast pionowej linijki.
@export_range(0.0, 120.0, 1.0) var wander_pixels := 18.0

## Ile najwyżej kreseczek naraz. Zabezpiecznik, gdyby ktoś ustawił bardzo
## krótki odstęp.
@export_range(1, 60, 1) var max_lines := 24

## Ile kreseczek pokazać w edytorze.
@export_range(0, 12, 1) var preview_lines := 4:
	set(value):
		preview_lines = value
		queue_redraw()

var _source: Node

## Każda kreseczka to wiek, przesunięcie w bok, kierunek wężyka i długość.
var _lines: Array[Dictionary] = []
var _to_next := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_source = get_node_or_null(source_path)
	if not source_path.is_empty() and _source == null:
		push_warning("[dym] nie ma źródła pod \"%s\"" % source_path)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var index := _lines.size() - 1
	while index >= 0:
		_lines[index]["age"] += delta
		if _lines[index]["age"] >= life_seconds:
			_lines.remove_at(index)
		index -= 1

	if _is_lit():
		_to_next -= delta
		if _to_next <= 0.0:
			var pace := spawn_interval / (puff_density if _is_puffing() else 1.0)
			_to_next = maxf(pace, 0.01)
			_spawn()

	queue_redraw()


func _is_lit() -> bool:
	if _source == null or not _source.has_method(&"is_lit"):
		return true
	return _source.call(&"is_lit")


func _is_puffing() -> bool:
	if _source == null or not _source.has_method(&"is_puffing"):
		return false
	return _source.call(&"is_puffing")


func _spawn() -> void:
	if _lines.size() >= max_lines:
		return
	_lines.append({
		"age": 0.0,
		"offset": randf_range(-spread_pixels, spread_pixels),
		"wander": randf_range(-1.0, 1.0),
		"length": line_length * randf_range(0.7, 1.3),
	})


func _draw() -> void:
	if Engine.is_editor_hint():
		_draw_preview()
		return

	for line in _lines:
		var t: float = clampf(line["age"] / maxf(life_seconds, 0.01), 0.0, 1.0)
		_draw_line_at(line["offset"], line["wander"], line["length"], t)


## Kreseczka na swojej wysokości. Zanika po kwadracie postępu, więc trzyma się
## widoczna, dopóki jest nisko, a gaśnie szybko na końcu — tak jak dym, który
## się rozprasza.
func _draw_line_at(offset: float, wander: float, length: float, t: float) -> void:
	var lift := rise_pixels * t
	var side := offset + wander * wander_pixels * t
	var alpha := color.a * (1.0 - t * t)
	var faded := Color(color.r, color.g, color.b, alpha)
	draw_line(Vector2(side, -lift), Vector2(side, -lift - length), faded, line_width, true)


func _draw_preview() -> void:
	for index in preview_lines:
		var t := float(index) / maxf(float(preview_lines), 1.0)
		_draw_line_at(lerpf(-spread_pixels, spread_pixels, t), 0.5, line_length, t)
