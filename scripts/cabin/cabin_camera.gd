extends Camera2D

## Kamera POV kierowcy.
##
## Najazd i powrót to przejazdy na czas ze stałą prędkością — kamera
## pokonuje drogę równo od pierwszej do ostatniej klatki, bez zrywu na
## starcie i bez pełzania na końcu. Czas najazdu zadaje pinezka
## (approach_seconds), czas powrotu aktywność (return_seconds).
##
## UWAGA na powiązania między węzłami: muszą być typu NodePath i
## rozwiązywane ręcznie w _ready. Pole zadeklarowane wprost jako typ
## węzła (np. `@export var controller: CabinActivityController`) nie
## przenosi się przez plik sceny pisany tekstem — wczytuje się jako null.

@export_node_path("Node") var controller_path: NodePath

var controller: CabinActivityController

var _from_position := Vector2.ZERO
var _from_zoom := Vector2.ONE
var _elapsed := 0.0
var _duration := 0.0


func _ready() -> void:
	controller = get_node_or_null(controller_path) as CabinActivityController
	if controller == null:
		return
	controller.activity_started.connect(_on_activity_started)
	controller.return_started.connect(_on_return_started)


func _process(delta: float) -> void:
	if controller == null:
		return
	var target := controller.current_target()
	if target == null:
		return

	# Powrót ma własny zegar w kontrolerze — to ten sam zegar, który
	# trzyma blokadę klikania, więc kamera i blokada nie mogą się rozjechać.
	if controller.is_returning():
		# Powrót wyhamowuje na końcu — inaczej niż najazd, celowo.
		_apply(target, smoothstep(0.0, 1.0, controller.return_progress()))
		return

	if _duration <= 0.0:
		_apply(target, 1.0)
		return

	_elapsed = minf(_elapsed + delta, _duration)
	_apply(target, _elapsed / _duration)


func _apply(target: CabinZoomTarget, t: float) -> void:
	global_position = _from_position.lerp(target.global_position, t)
	zoom = _from_zoom.lerp(Vector2.ONE * target.zoom, t)


func _on_activity_started(_activity_id: StringName) -> void:
	_begin_trip(controller.active_approach_seconds())


func _on_return_started(_seconds: float) -> void:
	_begin_trip(0.0)


func _begin_trip(duration: float) -> void:
	_from_position = global_position
	_from_zoom = zoom
	_elapsed = 0.0
	_duration = maxf(duration, 0.0)
