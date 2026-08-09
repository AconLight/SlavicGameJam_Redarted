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

## Węzeł z polem `chill` — w grze jest to KeepScore ze sceny score.
## Puste albo nieodnalezione = wszystkie aktywności dostępne, dzięki czemu
## samą kabinę da się odpalić i testować bez reszty gry.
@export_node_path("Node") var chill_source_path: NodePath

## Węzeł z metodami HeavyFoot() i HittinBrakes() — w grze Accelerometer.
## Tir przyspiesza, dopóki trwa czynność, i hamuje po jej puszczeniu.
@export_node_path("Node") var speed_source_path: NodePath

## Czy wypisywać zdarzenia do konsoli.
@export var debug_log := true

var neutral_target: CabinZoomTarget

var _chill_source: Node
var _speed_source: Node
var _activities: Array[CabinActivity] = []

var _active: CabinActivity = null

## Akcja, którą trzymana jest bieżąca czynność. Puste = trzyma ją myszka.
var _hold_action: StringName = &""
var _held := 0.0
var _return_left := 0.0
var _return_total := 0.0


func _ready() -> void:
	neutral_target = get_node_or_null(neutral_target_path) as CabinZoomTarget
	_chill_source = get_node_or_null(chill_source_path)
	_speed_source = get_node_or_null(speed_source_path)
	_connect_activities.call_deferred()


func _process(delta: float) -> void:
	_refresh_availability()

	if _active != null:
		_held += delta
		if _hold_released():
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


## Trwająca czynność albo null. Do czytania jej własnych parametrów przez
## rzeczy, które nie mają po co znać nazw czynności — patrz cabin_drift.gd.
func active_activity() -> CabinActivity:
	return _active


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


## Aktualny poziom chillu. Bez podpiętego źródła zwraca maksimum, więc
## nic nie jest zablokowane.
func current_chill() -> int:
	if _chill_source == null:
		return 200
	var value: Variant = _chill_source.get(&"chill")
	if value == null:
		return 200
	return int(value)


## Poziom chillu, czyli mnożnik punktów: od 1 do 5. To po nim odblokowują się
## czynności — progi mnożnika żyją w KeepScore i tam mają zostać.
func current_chill_level() -> int:
	if _chill_source == null or not _chill_source.has_method(&"get_chill_multiplier"):
		return 5
	return int(_chill_source.call(&"get_chill_multiplier"))


## Zawołanie metody na cudzym węźle, jeśli ten węzeł i metoda istnieją.
## Przy uruchomieniu samej kabiny żadnego z tych źródeł nie ma, a nazwy po
## stronie score i prędkości mogą się kiedyś zmienić — kabina ma wtedy
## dalej działać, tylko bez naliczania i bez przyspieszania.
func _notify(source: Node, method: StringName) -> void:
	if source != null and source.has_method(method):
		source.call(method)


func _connect_activities() -> void:
	_activities.clear()
	for node in get_tree().get_nodes_in_group(CabinActivity.GROUP):
		var activity := node as CabinActivity
		_activities.append(activity)
		if not activity.press_requested.is_connected(_on_press_requested):
			activity.press_requested.connect(_on_press_requested)
	_refresh_availability()


func _refresh_availability() -> void:
	var level := current_chill_level()
	for activity in _activities:
		# Trwającej aktywności nie chowamy w połowie trzymania, nawet gdyby
		# chill zdążył spaść poniżej jej progu.
		if activity == _active:
			continue
		# Próg działa raz, w jedną stronę. Przedmiot zdobyty chillem zostaje
		# w kabinie na resztę przejazdu — mrugające co chwilę ukulele wyglądało
		# jak błąd, a gracz nie ma jak zaplanować czynności, która znika mu
		# z ekranu w połowie zjazdu chillu.
		if not activity.chill_unlocked and level >= activity.min_chill_level:
			activity.chill_unlocked = true
		activity.set_available(activity.chill_unlocked)


## Czy kierowca puścił przedmiot. Sposób puszczenia musi być ten sam co chwytu:
## czynność chwycona klawiszem trwa do puszczenia klawisza, bo w przeciwnym
## razie urwałaby się natychmiast — przycisk myszy przecież nie jest wciśnięty.
func _hold_released() -> bool:
	if _hold_action != &"":
		return not Input.is_action_pressed(_hold_action)
	return not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _on_press_requested(activity: CabinActivity, held_by_action: bool) -> void:
	if not accepts_input() or not activity.available or activity.locked:
		return
	_active = activity
	_hold_action = activity.activation_action if held_by_action else &""
	_held = 0.0
	activity.set_active(true)
	# Stawka za sekundę zależy od czynności, więc podajemy ją licznikowi przed
	# uruchomieniem naliczania.
	if _chill_source != null and _chill_source.has_method(&"SetChillGain"):
		_chill_source.call(&"SetChillGain", activity.hold_chill_per_second)
	_notify(_chill_source, &"ChillActivity")
	# Gaz i hamowanie chodzą parą: czego kierowca nie dodaje, tego nie zdejmuje.
	if activity.accelerates:
		_notify(_speed_source, &"HeavyFoot")
	activity_started.emit(activity.activity_id)
	if debug_log:
		print("[cabin] start: ", activity.activity_id)


func _end() -> void:
	var id := _active.activity_id
	var held := _held
	var seconds := maxf(_active.return_seconds, 0.0)
	var was_accelerating := _active.accelerates
	_active.set_active(false)
	_active = null
	_hold_action = &""
	_held = 0.0
	_return_total = seconds
	_return_left = seconds
	_notify(_chill_source, &"EndChill")
	if was_accelerating:
		_notify(_speed_source, &"HittinBrakes")
	activity_ended.emit(id, held)
	if debug_log:
		print("[cabin] koniec: ", id, " trzymane=%.2fs, powrót=%.2fs" % [held, seconds])
	if seconds > 0.0:
		return_started.emit(seconds)
	else:
		return_finished.emit()
