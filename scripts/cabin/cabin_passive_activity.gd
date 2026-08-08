extends Node

## Czynność, która pracuje dalej po puszczeniu — radio grające w tle.
##
## Kierowca kręci gałką jak dotąd, a po puszczeniu radio gra jeszcze przez
## `play_seconds` i przez ten czas dolewa chillu co sekundę. Ile dolewa, zależy
## od tego, jak długo było ustawiane: sekunda kręcenia to jeden punkt na
## sekundę grania. Krótkie machnięcie daje jeden punkt, dłuższe szukanie stacji
## kilka. Na czas grania radio jest zamknięte — widać je, ale nie da się złapać.
##
## Nagroda liczona z czasu trzymania, a nie stała, jest tu całą treścią: bez
## tego opłacałoby się puszczać radio od razu i łapać je ciągle od nowa.

signal playback_started(chill_per_second: int)
signal playback_finished()

## Czynność, która ma pracować w tle.
@export_node_path("Node") var activity_path: NodePath

@export_node_path("Node") var controller_path: NodePath

## Węzeł z metodą AddChill(int) — w grze KeepScore ze sceny score.
@export_node_path("Node") var chill_source_path: NodePath

@export_group("Tempo")

## Jak długo czynność pracuje po puszczeniu.
@export_range(1.0, 300.0, 1.0) var play_seconds := 30.0

## Co ile sekund dolewa chillu.
@export_range(0.1, 5.0, 0.1) var tick_seconds := 1.0

## Górna granica nagrody. Bez niej minuta kręcenia gałką dawałaby sześćdziesiąt
## punktów na sekundę i chill nie miałby jak spaść.
@export_range(1, 30, 1) var max_chill_per_second := 8

## Dolna granica. Nawet najkrótsze machnięcie ma coś dać, żeby gracz nie miał
## wrażenia, że kliknięcie przepadło.
@export_range(0, 10, 1) var min_chill_per_second := 1

@export var debug_log := true

var _activity: CabinActivity
var _chill_source: Node

var _chill_per_second := 0
var _seconds_left := 0.0
var _to_next_tick := 0.0


func _ready() -> void:
	_activity = get_node_or_null(activity_path) as CabinActivity
	_chill_source = get_node_or_null(chill_source_path)

	var controller := get_node_or_null(controller_path) as CabinActivityController
	if controller == null or _activity == null:
		push_warning("[radio w tle] brak kontrolera albo czynności — grania w tle nie będzie")
		return
	controller.activity_ended.connect(_on_activity_ended)


func _process(delta: float) -> void:
	if _seconds_left <= 0.0:
		return

	_seconds_left -= delta
	_to_next_tick -= delta
	if _to_next_tick <= 0.0:
		_to_next_tick += tick_seconds
		if _chill_source != null and _chill_source.has_method(&"AddChill"):
			_chill_source.call(&"AddChill", _chill_per_second)

	if _seconds_left <= 0.0:
		_stop()


## Ile chillu na sekundę leci teraz z tej czynności. 0 = nie gra.
func chill_per_second() -> int:
	return _chill_per_second if is_playing() else 0


func is_playing() -> bool:
	return _seconds_left > 0.0


## Ile jeszcze grania, od 1 do 0.
func playback_progress() -> float:
	if play_seconds <= 0.0:
		return 0.0
	return clampf(_seconds_left / play_seconds, 0.0, 1.0)


func _on_activity_ended(ended_id: StringName, held_seconds: float) -> void:
	if _activity == null or ended_id != _activity.activity_id:
		return

	# Ucięcie w dół, nie zaokrąglenie: gracz widzi nutki i sam liczy sekundy,
	# więc nagroda ma rosnąć dokładnie na pełnych sekundach trzymania.
	_chill_per_second = clampi(int(floorf(held_seconds)), min_chill_per_second, max_chill_per_second)
	_seconds_left = play_seconds
	_to_next_tick = tick_seconds
	_activity.set_locked(true)
	playback_started.emit(_chill_per_second)
	if debug_log:
		print("[radio w tle] gra %.0f s, %d chillu na sekundę" % [play_seconds, _chill_per_second])


func _stop() -> void:
	_seconds_left = 0.0
	_chill_per_second = 0
	if _activity != null:
		_activity.set_locked(false)
	playback_finished.emit()
	if debug_log:
		print("[radio w tle] koniec grania")
