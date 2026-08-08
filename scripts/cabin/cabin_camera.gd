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

@export_group("Drżenie na wybojach")

## Wychylenie na gładkiej drodze. Kabina nigdy nie staje — to jest
## poziom, poniżej którego drżenie nie schodzi. 0 wyłącza całość.
@export_range(0.0, 30.0, 0.5) var bump_amplitude_min := 2.0

## Wychylenie w szczycie wyboja.
@export_range(0.0, 60.0, 0.5) var bump_amplitude_max := 14.0

## Ile podskoków na sekundę.
@export_range(0.1, 12.0, 0.1) var bump_frequency := 2.2

## Co ile mniej więcej sekund droga robi się wyboista. Mniej więcej,
## bo szczyty są rozłożone nierówno.
@export_range(1.0, 60.0, 0.5) var swell_period := 11.0

## Węzły, które podskakują na wybojach — wnętrze kabiny i jej przedmioty.
##
## Drżenie idzie po nich, a nie po kamerze, bo kamera rusza całym widokiem
## i wtedy skakałaby też droga oraz niebo. Pinezek zoomu tu nie ma i mieć
## nie może: gdyby drgały, kamera goniłaby za nimi i drżenie zniosłoby się
## na ekranie do zera.
@export var bumped_paths: Array[NodePath] = []

@export_group("Przechył na zjeżdżaniu")

## Węzeł CabinDrift ze sceny rozgrywki. Puste albo nieodnalezione = kamera stoi
## prosto, więc sama kabina odpalona osobno działa dalej.
@export_node_path("Node") var drift_source_path: NodePath

## O ile stopni przekręca się kadr przy pełnym zjeżdżeniu na pobocze. Wartość
## ujemna przechyla w drugą stronę. Wymaga odznaczonego ignore_rotation na
## kamerze — z zaznaczonym Godot obrót kamery pomija.
@export_range(-30.0, 30.0, 0.5) var drift_tilt_degrees := -10.0

## Ile zoomu dokładamy przy pełnym zjeżdżeniu. Przechylony kadr odsłania puste
## narożniki ekranu, bo grafika kabiny ma tylko dwa procent zapasu — lekkie
## przybliżenie chowa je z powrotem.
@export_range(0.0, 0.5, 0.01) var drift_zoom_boost := 0.06

var controller: CabinActivityController

var _from_position := Vector2.ZERO
var _from_zoom := Vector2.ONE
var _elapsed := 0.0
var _duration := 0.0
var _bump_time := 0.0
var _swell := 0.0
var _bumped: Array[Node2D] = []
var _bumped_home: Array[Vector2] = []
var _drift_source: Node

## Zoom zadany przez przejazd kamery, bez dodatku od zjeżdżania. Przechył
## mnoży ten zapis, a nie własny wynik z poprzedniej klatki — inaczej dodatek
## narastałby sam z siebie w klatkach, w których przejazd nie liczy zoomu.
var _base_zoom := Vector2.ONE


func _ready() -> void:
	_drift_source = get_node_or_null(drift_source_path)
	if not drift_source_path.is_empty() and _drift_source == null:
		push_warning("[kamera] nie ma węzła zjazdu pod \"%s\"" % drift_source_path)
	_base_zoom = zoom

	for path in bumped_paths:
		var node := get_node_or_null(path) as Node2D
		if node != null:
			_bumped.append(node)
			_bumped_home.append(node.position)

	controller = get_node_or_null(controller_path) as CabinActivityController
	if controller == null:
		return
	controller.activity_started.connect(_on_activity_started)
	controller.return_started.connect(_on_return_started)


func _process(delta: float) -> void:
	_apply_bump(delta)
	_drive_trip(delta)
	# Na końcu, bo przechył opiera się na zoomie policzonym przez przejazd.
	_apply_drift_tilt()


func _drive_trip(delta: float) -> void:
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


## Przechylenie kadru razem z torem jazdy. Im dalej tir na poboczu, tym mocniej
## obrócony obraz — drugie ostrzeżenie obok przekręconej kierownicy.
func _apply_drift_tilt() -> void:
	if _drift_source == null or not _drift_source.has_method(&"drift_signed"):
		return
	var signed: float = _drift_source.call(&"drift_signed")
	rotation = deg_to_rad(signed * drift_tilt_degrees)
	zoom = _base_zoom * (1.0 + absf(signed) * drift_zoom_boost)


## Delikatne podskakiwanie na wybojach. Przesuwa wskazane węzły kabiny,
## nie kamerę — kamera rusza całym widokiem, więc skakałaby też droga.
##
## Dwie fale o niewspółmiernych częstotliwościach zamiast jednej — jedna
## sinusoida czytałaby się jak metronom, a nie jak droga.
func _apply_bump(delta: float) -> void:
	_bump_time += delta

	var wave := sin(_bump_time * TAU * bump_frequency)
	wave += 0.45 * sin(_bump_time * TAU * bump_frequency * 1.7 + 1.3)
	# Dzielenie przez zoom trzyma stałe wychylenie na ekranie — bez tego
	# przy przybliżeniu 3x kabina trzęsłaby się trzy razy mocniej.
	var shift := wave * _swell_amplitude() / maxf(zoom.y, 0.01)
	for index in _bumped.size():
		_bumped[index].position.y = _bumped_home[index].y + shift


## Amplituda drżenia, pełzająca między spokojem a wybojem.
##
## Dwie powolne fale o niewspółmiernych okresach, przemnożone i podniesione
## do kwadratu. Iloczyn sprawia, że szczyty wypadają nieregularnie i nie
## powtarzają się co równe tyle samo. Kwadrat spycha wynik w dół, więc
## przez większość czasu kabina buja delikatnie, a mocno tylko chwilami.
func _swell_amplitude() -> float:
	var slow := 0.5 + 0.5 * sin(_bump_time * TAU / swell_period)
	var slower := 0.5 + 0.5 * sin(_bump_time * TAU / (swell_period * 0.63) + 2.1)
	_swell = pow(slow * slower, 2.0)
	return lerpf(bump_amplitude_min, bump_amplitude_max, _swell)


## Jak wyboista jest teraz droga, od 0 do 1. Do podpięcia rzeczy, które
## mają się bujać razem z kabiną — żeby wszystko reagowało na tę samą
## drogę, zamiast każde na własny zegar.
func shake_intensity() -> float:
	return _swell


func _apply(target: CabinZoomTarget, t: float) -> void:
	global_position = _from_position.lerp(target.global_position, t)
	_base_zoom = _from_zoom.lerp(Vector2.ONE * target.zoom, t)
	zoom = _base_zoom


func _on_activity_started(_activity_id: StringName) -> void:
	_begin_trip(controller.active_approach_seconds())


func _on_return_started(_seconds: float) -> void:
	_begin_trip(0.0)


func _begin_trip(duration: float) -> void:
	_from_position = global_position
	# Zapis bez dodatku od zjeżdżania, inaczej przejazd rozpoczęty na poboczu
	# wpiekłby przechył w cel i został z nim po powrocie na pas.
	_from_zoom = _base_zoom
	_elapsed = 0.0
	_duration = maxf(duration, 0.0)
