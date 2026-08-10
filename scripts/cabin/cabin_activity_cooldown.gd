extends Node

## Blokada czynności na losowy czas po użyciu — CB, które przez chwilę milczy.
##
## Zamyka wskazaną czynność zaraz po jej puszczeniu i otwiera po losowym czasie
## z podanego przedziału. Losowy, a nie stały, żeby gracz nie mógł odliczać
## sekund i wracać do CB jak w zegarku.
##
## Sam zamek nie zmienia wyglądu — gruszka wciąga się pod sufit, bo
## cabin_cb_handset.gd patrzy na ten sam stan czynności.

signal cooldown_started(seconds: float)
signal cooldown_finished()

## Czynność do zamykania.
@export_node_path("Node") var activity_path: NodePath

@export_node_path("Node") var controller_path: NodePath

## Najkrótsza blokada.
@export_range(0.0, 300.0, 0.5) var lock_seconds_min := 5.0

## Najdłuższa blokada.
@export_range(0.0, 300.0, 0.5) var lock_seconds_max := 30.0

@export var debug_log := true

var _activity: CabinActivity
var _seconds_left := 0.0
var _total_seconds := 0.0


func _ready() -> void:
	_activity = get_node_or_null(activity_path) as CabinActivity
	var controller := get_node_or_null(controller_path) as CabinActivityController
	if controller == null or _activity == null:
		push_warning("[blokada] brak kontrolera albo czynności — blokady nie będzie")
		return
	controller.activity_ended.connect(_on_activity_ended)


func _process(delta: float) -> void:
	if _seconds_left <= 0.0:
		return
	_seconds_left -= delta
	if _seconds_left <= 0.0:
		_seconds_left = 0.0
		_activity.set_locked(false, self)
		cooldown_finished.emit()
		if debug_log:
			print("[blokada] ", _activity.activity_id, " znowu dostępne")


## Czy czynność jest teraz zablokowana.
func is_locked() -> bool:
	return _seconds_left > 0.0


## Ile blokady zostało, od 1 na starcie do 0 na końcu. Tym karmi się tarcza
## odliczająca — liczbę trzyma jedno miejsce, więc wskazówka nie ma jak
## rozjechać się z faktycznym odblokowaniem.
func progress() -> float:
	if _total_seconds <= 0.0:
		return 0.0
	return clampf(_seconds_left / _total_seconds, 0.0, 1.0)


func seconds_left() -> float:
	return maxf(_seconds_left, 0.0)


func _on_activity_ended(ended_id: StringName, _held_seconds: float) -> void:
	if _activity == null or ended_id != _activity.activity_id:
		return

	var span_min := minf(lock_seconds_min, lock_seconds_max)
	var span_max := maxf(lock_seconds_min, lock_seconds_max)
	_seconds_left = randf_range(span_min, span_max)
	_total_seconds = _seconds_left
	_activity.set_locked(true, self)
	cooldown_started.emit(_seconds_left)
	if debug_log:
		print("[blokada] %s na %.1f s" % [_activity.activity_id, _seconds_left])
