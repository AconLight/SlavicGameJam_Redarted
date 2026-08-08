extends Node

## Gadka na CB.
##
## W tle, przez całą grę: co kilkanaście sekund ktoś się odzywa. Każde
## wejście to trójka CB_ON → losowa kwestia → CB_OFF, odtwarzana po kolei
## na jednym odtwarzaczu przez kolejkę.
##
## Gdy kierowca sam bierze gruszkę do ręki, obca gadka milknie i zamiast
## niej lecą jego własne kwestie, jedna po drugiej, aż puści.

@export_node_path("Node") var controller_path: NodePath

## Aktywność, która przełącza na gadanie kierowcy.
@export var activity_id: StringName = &"cb_radio"

@export_group("Obca gadka w tle")

## Kwestie z CB. Losowane pojedynczo.
@export var cb_lines: Array[AudioStream] = []

## Trzask włączenia i wyłączenia, owijany wokół każdej kwestii.
@export var cb_on: AudioStream
@export var cb_off: AudioStream

@export_range(0.5, 120.0, 0.5) var gap_min_seconds := 5.0
@export_range(0.5, 120.0, 0.5) var gap_max_seconds := 10.0

## Głośność obcej gadki. 0 to bez zmiany, wyżej głośniej.
@export_range(-40.0, 24.0, 0.5) var cb_volume_db := 0.0

@export_group("Kierowca gada")

## Kwestie kierowcy, lecące podczas trzymania CB.
@export var driver_lines: Array[AudioStream] = []

## Przerwa między kolejnymi kwestiami kierowcy.
@export_range(0.0, 10.0, 0.1) var driver_gap_seconds := 1.5

## Głośność kwestii kierowcy. Osobno od obcej gadki, bo obie lecą na
## jednym odtwarzaczu i inaczej nie dałoby się ich rozdzielić.
@export_range(-40.0, 24.0, 0.5) var driver_volume_db := 6.0

## O ile przyciszyć gadkę, gdy kierowca zajmuje się czymkolwiek innym —
## radiem, ukulele. Wchodzi natychmiast z rozpoczęciem czynności i dotyczy
## też kwestii, która właśnie leci, żeby nie zagłuszała głosu kierowcy.
## Nie milczymy całkiem, bo droga ma dalej żyć w tle.
@export_range(-40.0, 0.0, 0.5) var duck_db := -16.0

## Ile trwa powrót do pełnej głośności po zakończeniu czynności.
## Przyciszanie jest natychmiastowe — tam chodzi o to, żeby nie zdążyć
## zagłuszyć kierowcy. Powrót jest łagodny, bo skok na full słychać.
@export_range(0.0, 5.0, 0.1) var duck_release_seconds := 2.0

@export var debug_log := true

@onready var _player: AudioStreamPlayer = $Player

var _queue: Array[AudioStream] = []
var _driver_mode := false
var _until_next := 0.0

## Czy trwa sekwencja. Trzymamy to jawnie, a nie wnioskujemy z pola
## playing odtwarzacza: playing gaśnie w chwili końca próbki, a sygnał
## finished przychodzi dopiero potem. W tej szczelinie _process uznawał, że
## nic nie leci, i odpalał następne wejście bez żadnej przerwy.
var _busy := false
var _ducked := false
var _controller: CabinActivityController
var _volume_tween: Tween

## Worki na kwestie jeszcze nieodegrane w tym obiegu.
var _cb_bag: Array[AudioStream] = []
var _driver_bag: Array[AudioStream] = []


func _ready() -> void:
	_player.finished.connect(_advance)
	_schedule_gap()

	_controller = get_node_or_null(controller_path) as CabinActivityController
	if _controller == null:
		return
	_controller.activity_started.connect(_on_activity_started)
	_controller.activity_ended.connect(_on_activity_ended)


func _process(delta: float) -> void:
	if _busy:
		return

	if _until_next > 0.0:
		_until_next -= delta
		return

	if _driver_mode:
		_start_sequence([_draw(driver_lines, _driver_bag)])
	else:
		_start_sequence([cb_on, _draw(cb_lines, _cb_bag), cb_off])


func _on_activity_started(started_id: StringName) -> void:
	if started_id != activity_id:
		# Inna czynność — przyciszamy się, żeby jej nie zagłuszyć.
		_ducked = true
		_apply_volume()
		return

	_driver_mode = true
	_ducked = false
	_silence()
	# Trzask i pierwsza kwestia w jednej kolejce, żeby kierowca zaczynał
	# gadać od razu po włączeniu. Przerwa dotyczy dopiero następnych kwestii.
	_start_sequence([cb_on, _draw(driver_lines, _driver_bag)])
	if debug_log:
		print("[audio] CB: kierowca przejmuje mikrofon")


func _on_activity_ended(ended_id: StringName, _held_seconds: float) -> void:
	if ended_id != activity_id:
		_ducked = false
		_apply_volume(false)
		return

	_driver_mode = false
	_ducked = false
	_silence()
	# Trzask wyłączenia, a po nim wraca zwykła przerwa i obca gadka.
	_start_sequence([cb_off])
	if debug_log:
		print("[audio] CB: wracamy do słuchania")


## Głośność odtwarzacza: poziom zależny od trybu, obniżony gdy kierowca
## zajmuje się czymś innym. Wołane też w trakcie kwestii, więc przyciszenie
## łapie ją w locie.
func _target_volume() -> float:
	var base := driver_volume_db if _driver_mode else cb_volume_db
	return base + (duck_db if _ducked else 0.0)


func _apply_volume(instant := true) -> void:
	if _volume_tween != null and _volume_tween.is_valid():
		_volume_tween.kill()

	if instant or duck_release_seconds <= 0.0:
		_player.volume_db = _target_volume()
		return

	_volume_tween = create_tween()
	_volume_tween.tween_property(_player, ^"volume_db", _target_volume(), duck_release_seconds)


func _start_sequence(streams: Array) -> void:
	_queue.clear()
	for stream in streams:
		if stream != null:
			_queue.append(stream)
	if _queue.is_empty():
		_busy = false
		_schedule_gap()
		return
	_busy = true
	_advance()


## Kolejny element kolejki albo, gdy pusta, odliczanie do następnego wejścia.
## Podpięte pod finished odtwarzacza. Godot nie wysyła finished po stop(),
## więc wyciszenie nie przesuwa kolejki samo z siebie.
func _advance() -> void:
	if _queue.is_empty():
		_busy = false
		_schedule_gap()
		return
	# W trakcie rozjaśniania nie ruszamy głośności, żeby fade szedł gładko
	# przez kolejne elementy kolejki.
	if _volume_tween == null or not _volume_tween.is_valid():
		_apply_volume()
	_player.stream = _queue.pop_front()
	_player.play()


func _silence() -> void:
	_queue.clear()
	_busy = false
	_player.stop()


func _schedule_gap() -> void:
	if _driver_mode:
		_until_next = driver_gap_seconds
	else:
		_until_next = randf_range(gap_min_seconds, maxf(gap_max_seconds, gap_min_seconds))
	if debug_log:
		print("[audio] CB przerwa ", "%.1f" % _until_next, " s")


## Losowanie bez powtórzeń: ciągniemy z worka nieodegranych kwestii,
## a gdy się opróżni, napełniamy go na nowo i tasujemy. Zwykłe losowanie
## potrafi puścić tę samą kwestię trzy razy pod rząd, co od razu słychać.
func _draw(streams: Array[AudioStream], bag: Array[AudioStream]) -> AudioStream:
	if streams.is_empty():
		return null
	if bag.is_empty():
		bag.assign(streams)
		bag.shuffle()
	return bag.pop_back()
