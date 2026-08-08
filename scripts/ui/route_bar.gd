extends CanvasLayer

## Pasek trasy: znacznik jedzie od pinezki startu do pinezki końca w tempie
## zegara trasy.
##
## Postęp bierzemy gotowy z run_clock.gd, a nie liczymy tu czasu drugi raz —
## dwa zegary rozjechałyby się i znacznik dobijałby do końca w innej chwili
## niż faktyczny koniec przejazdu.
##
## Skrajne położenia zadają pinezki ustawiane myszką, więc przesunięcie paska
## albo podmiana grafiki na dłuższą nie wymaga niczego w kodzie.

## Zegar trasy — węzeł z metodą progress().
@export_node_path("Node") var clock_path: NodePath

## Znacznik, który jedzie po pasku.
@export_node_path("Node2D") var marker_path: NodePath

## Gdzie znacznik stoi na początku trasy.
@export_node_path("Node2D") var start_path: NodePath

## Gdzie kończy, czyli w chwili końca przejazdu.
@export_node_path("Node2D") var end_path: NodePath

var _clock: Node
var _marker: Node2D
var _start: Node2D
var _end: Node2D


func _ready() -> void:
	_clock = get_node_or_null(clock_path)
	_marker = get_node_or_null(marker_path) as Node2D
	_start = get_node_or_null(start_path) as Node2D
	_end = get_node_or_null(end_path) as Node2D

	if _clock == null or not _clock.has_method(&"progress"):
		push_warning("[pasek trasy] brak zegara trasy — znacznik będzie stał")
	if _marker == null or _start == null or _end == null:
		push_warning("[pasek trasy] brak znacznika albo pinezki — znacznik będzie stał")
		return

	# Pinezki są tylko punktami odniesienia, nie mają nic rysować.
	_start.visible = false
	_end.visible = false
	_place(0.0)


func _process(_delta: float) -> void:
	if _clock == null or not _clock.has_method(&"progress"):
		return
	_place(_clock.call(&"progress"))


func _place(progress: float) -> void:
	if _marker == null or _start == null or _end == null:
		return
	_marker.position = _start.position.lerp(_end.position, clampf(progress, 0.0, 1.0))
