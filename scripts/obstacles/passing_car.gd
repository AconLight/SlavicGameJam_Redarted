extends Sprite2D

## Autko, które tylko nas wyprzedza i jedzie dalej.
##
## Odchudzona wersja car.gd: bez sprawdzania hamulca, bez kiwania się, bez
## cofania i bez zgłaszania czegokolwiek do sygnalisty. Wyjeżdża ze swojego
## miejsca, oddala się do punktu zbiegu malejąc, znika i po losowej przerwie
## robi to od nowa.
##
## Pozycję i wielkość startową bierze z tego, co ustawisz myszką w scenie —
## `travel` mówi tylko, dokąd stąd odjeżdża.

signal pass_started()
signal pass_finished()

@export_group("Dojazd")

## Dokąd autko podjeżdża w pierwszej części przejazdu, w układzie rodzica.
## Liczby Adasia: (1000, 500) i skala 0.4.
##
## Punkt startowy to miejsce ustawione myszką w scenie — a leży ono pod dolną
## krawędzią ekranu, więc autko wchodzi w kadr dopiero po przejechaniu ponad
## tysiąca pikseli w górę. Zbyt małe przesunięcie znaczy, że nie pokaże się ani
## razu, mimo że przejazd normalnie chodzi.
@export var approach_position := Vector2(1000.0, 500.0)

## Wielkość po dojechaniu. Do tej chwili autko jest duże i właśnie tak ma
## wyglądać wyprzedzanie — kurczy się dopiero przy oddalaniu.
@export var approach_scale := Vector2(0.4, 0.4)

@export_range(0.1, 30.0, 0.1) var approach_seconds := 5.0

@export_group("Oddalanie")

## Dokąd odjeżdża na koniec i tam znika. U Adasia (950, 450) i skala 0.1.
@export var depart_position := Vector2(950.0, 450.0)

@export var depart_scale := Vector2(0.1, 0.1)

@export_range(0.1, 30.0, 0.1) var depart_seconds := 1.5

@export_group("Częstotliwość")

## Po ilu sekundach od startu gry pierwsze wyprzedzanie.
@export_range(0.0, 120.0, 0.5) var first_gap_seconds := 3.0

## Najkrótsza przerwa między przejazdami. Liczona od zniknięcia poprzedniego
## autka, więc do odstępu między wyprzedzeniami dochodzi jeszcze sam przejazd.
@export_range(0.0, 300.0, 0.5) var gap_min_seconds := 5.0

## Najdłuższa przerwa między przejazdami.
@export_range(0.0, 300.0, 0.5) var gap_max_seconds := 12.5

@export_group("Dźwięk")

## Klakson, raz na jedno wyprzedzanie. Wymaga węzła AudioStreamPlayer o nazwie
## Honk.
@export var honk_stream: AudioStream

@export_range(-40.0, 24.0, 0.1) var honk_volume_db := 0.0

## W której sekundzie próbki słychać samo mijanie — u dopplera to moment, gdy
## ton się łamie. Próbka ma dziesięć sekund, więc odtwarzana od początku
## trąbiłaby długo po tym, jak autko odjedzie.
@export_range(0.0, 30.0, 0.1) var honk_pass_by_in_sample := 4.0

## W której sekundzie przejazdu autko mija kabinę, czyli przecina dolną krawędź
## kadru. Te dwie liczby zestawiane są ze sobą: dźwięk wchodzi tak, żeby
## mijanie w próbce trafiło w mijanie na ekranie.
## Zmierzone: przy domyślnych czasach autko przecina dolną krawędź w 1,7 s.
@export_range(0.0, 30.0, 0.1) var honk_pass_by_in_run := 1.7

@export var debug_log := false

var _home_position := Vector2.ZERO
var _home_scale := Vector2.ONE
var _to_next := 0.0
var _passing := false
var _honk: AudioStreamPlayer
var _to_honk := -1.0


func _ready() -> void:
	_home_position = position
	_home_scale = scale
	_to_next = first_gap_seconds

	_honk = get_node_or_null(^"Honk") as AudioStreamPlayer
	if _honk != null:
		_honk.stream = honk_stream
		_honk.volume_db = honk_volume_db
	# Między przejazdami autka nie ma na drodze, żeby nie stało w miejscu
	# w środku kadru.
	visible = false


func _process(delta: float) -> void:
	if _passing:
		# Odliczanie do klaksonu żyje tylko w trakcie przejazdu, a ujemna wartość
		# znaczy „już zatrąbił" — stąd jeden raz na wyprzedzanie.
		if _to_honk >= 0.0:
			_to_honk -= delta
			if _to_honk <= 0.0:
				_to_honk = -1.0
				_play_honk()
		return

	_to_next -= delta
	if _to_next <= 0.0:
		_start_pass()


func _start_pass() -> void:
	_passing = true
	position = _home_position
	scale = _home_scale
	visible = true

	# Gdy mijanie w próbce wypada później niż na ekranie, wchodzimy w nią od
	# środka. Gdy wcześniej — czekamy z odpaleniem. Jedno albo drugie, nigdy
	# oba naraz.
	if honk_pass_by_in_sample >= honk_pass_by_in_run:
		_to_honk = -1.0
		_play_honk(honk_pass_by_in_sample - honk_pass_by_in_run)
	else:
		_to_honk = honk_pass_by_in_run - honk_pass_by_in_sample

	# Dwa etapy, tak jak u Adasia. Jedno płynne malenie przez cały przejazd
	# wygląda inaczej: autko kurczy się najmocniej na początku i przez większość
	# drogi przelatuje przez kadr jak szczur. Duże ma być do końca dojazdu,
	# a maleć dopiero, gdy się oddala.
	var tween := create_tween()
	# X liniowo, Y wyhamowujące: samo Y na sinusie daje wrażenie wjeżdżania
	# w perspektywę, a nie jazdy po prostej.
	tween.tween_property(self, ^"position:x", approach_position.x, approach_seconds) \
		.set_trans(Tween.TRANS_LINEAR)
	tween.parallel().tween_property(self, ^"position:y", approach_position.y, approach_seconds) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, ^"scale", approach_scale, approach_seconds) \
		.set_trans(Tween.TRANS_LINEAR)

	tween.chain().tween_property(self, ^"position", depart_position, depart_seconds) \
		.set_trans(Tween.TRANS_LINEAR)
	tween.parallel().tween_property(self, ^"scale", depart_scale, depart_seconds) \
		.set_trans(Tween.TRANS_LINEAR)

	tween.finished.connect(_finish_pass)

	pass_started.emit()
	if debug_log:
		print("[wyprzedzanie] jedzie")


## Odpala klakson od podanej sekundy próbki.
func _play_honk(from_seconds := 0.0) -> void:
	if _honk == null or _honk.stream == null:
		return
	_honk.play(maxf(from_seconds, 0.0))
	if debug_log:
		print("[wyprzedzanie] klakson od %.1f s próbki" % from_seconds)


func _finish_pass() -> void:
	_passing = false
	_to_honk = -1.0
	visible = false
	position = _home_position
	scale = _home_scale

	var span_min := minf(gap_min_seconds, gap_max_seconds)
	var span_max := maxf(gap_min_seconds, gap_max_seconds)
	_to_next = randf_range(span_min, span_max)

	pass_finished.emit()
	if debug_log:
		print("[wyprzedzanie] następne za %.1f s" % _to_next)
