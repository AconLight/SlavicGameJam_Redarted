class_name CabinActivityController
extends Node

## Jedyne miejsce z logiką stanu aktywności. Pilnuje, że naraz trwa
## najwyżej jedna, mierzy czas trzymania i ogłasza to na zewnątrz.
##
## Trzy stany: bezczynność, trwająca aktywność, powrót kamery. W czasie
## powrotu kliknięcia są odrzucane — dopóki kamera nie stanie na miejscu,
## nie da się zacząć niczego nowego.

signal activity_started(activity_id: StringName)
signal activity_ended(activity_id: StringName, held_seconds: float)
signal return_started(return_seconds: float)
signal return_finished()

## Pinezka, do której kamera wraca, gdy nic się nie dzieje.
@export_node_path("Marker2D") var neutral_target_path: NodePath

## Czy wypisywać zdarzenia do konsoli.
@export var debug_log := true

var neutral_target: CabinZoomTarget

var _active: CabinActivity = null
var _held := 0.0
var _return_left := 0.0
var _return_total := 0.0


func _ready() -> void:
	neutral_target = get_node_or_null(neutral_target_path) as CabinZoomTarget
	_connect_activities.call_deferred()


func _process(delta: float) -> void:
	if _active != null:
		_held += delta
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_end()
		return

	if _return_left > 0.0:
		_return_left = maxf(_return_left - delta, 0.0)
		if is_zero_approx(_return_left):
			_return_left = 0.0
			return_finished.emit()
			if debug_log:
				print("[cabin] gotowe, można klikać")


## Cel dla kamery. Nigdy nie zwraca null, o ile ustawiono neutral_target.
func current_target() -> CabinZoomTarget:
	if _active != null and _active.zoom_target != null:
		return _active.zoom_target
	return neutral_target


## Identyfikator trwającej aktywności albo pusty StringName.
func active_id() -> StringName:
	return _active.activity_id if _active != null else &""


func held_seconds() -> float:
	return _held


## Czas najazdu zadany przez trwającą aktywność.
func active_approach_seconds() -> float:
	return _active.approach_seconds if _active != null else 0.0


## Czy kamera jest w drodze powrotnej do spoczynku.
func is_returning() -> bool:
	return _return_left > 0.0


## Postęp powrotu od 0.0 do 1.0.
func return_progress() -> float:
	if _return_total <= 0.0:
		return 1.0
	return 1.0 - (_return_left / _return_total)


## Czy wolno teraz rozpocząć aktywność.
func accepts_input() -> bool:
	return _active == null and _return_left <= 0.0


func _connect_activities() -> void:
	for node in get_tree().get_nodes_in_group(CabinActivity.GROUP):
		var activity := node as CabinActivity
		if not activity.press_requested.is_connected(_on_press_requested):
			activity.press_requested.connect(_on_press_requested)


func _on_press_requested(activity: CabinActivity) -> void:
	if not accepts_input():
		return
	_active = activity
	_held = 0.0
	activity_started.emit(activity.activity_id)
	if debug_log:
		print("[cabin] start: ", activity.activity_id)


func _end() -> void:
	var id := _active.activity_id
	var held := _held
	var seconds := maxf(_active.return_seconds, 0.0)
	_active = null
	_held = 0.0
	_return_total = seconds
	_return_left = seconds
	activity_ended.emit(id, held)
	if debug_log:
		print("[cabin] koniec: ", id, " trzymane=%.2fs, powrót=%.2fs" % [held, seconds])
	if seconds > 0.0:
		return_started.emit(seconds)
	else:
		return_finished.emit()
