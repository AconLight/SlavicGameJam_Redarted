@tool
extends Node2D

## Papierośnica i papieros — jedyna czynność na kliknięcie, nie na trzymanie.
##
## Papierośnica pojawia się, gdy chill sięgnie progu, i tak jak reszta zostaje
## już na stałe. Kliknięcie w nią odpala zapalniczkę i wykłada papierosa na
## `cigarette_seconds`; przez ten czas papierośnica jest zajęta. Kliknięcie
## w papierosa to zaciągnięcie: leci dźwięk i grafika zmienia się na czas jego
## trwania.
##
## Nie jest to CabinActivity, bo tamta obsługuje trzymanie: najazd kamery,
## naliczanie chillu przez cały czas trzymania, gaz. Tu liczy się pojedyncze
## kliknięcie i nic z tamtego nie pasuje.
##
## Jest @tool, żeby oba obszary klikalne było widać w edytorze i dało się je
## ustawić myszką.

signal case_opened()
signal puff_taken()

@export_group("Odblokowanie")

## Od jakiego chillu papierośnica jest w kabinie. Raz odblokowana zostaje,
## tak samo jak pozostałe czynności. Progi mnożnika: 1 = 0, 2 = 20, 3 = 40,
## 4 = 60, 5 = 80.
@export_range(0, 100, 1) var min_chill := 60

## Węzeł z polem `chill` — w grze KeepScore ze sceny score. Puste = widoczna
## od początku, żeby dało się testować samą kabinę.
@export_node_path("Node") var chill_source_path: NodePath

@export_group("Grafiki")

## Papierośnica gotowa do kliknięcia.
@export var case_texture: Texture2D:
	set(value):
		case_texture = value
		if is_node_ready():
			_apply_shapes()

## Papierośnica zajęta, gdy papieros już leży wyjęty.
@export var case_busy_texture: Texture2D

## Wyjęty papieros.
@export var cigarette_texture: Texture2D:
	set(value):
		cigarette_texture = value
		if is_node_ready():
			_apply_shapes()

## Węzeł pokazywany na czas zaciągnięcia — grafika ustawiona myszką tam, gdzie
## ma się pojawiać. Chowamy go przy starcie i pokazujemy tylko na czas dźwięku.
##
## Ma pierwszeństwo nad `puff_texture`: własny węzeł znaczy własne miejsce
## i własny obrót, czego podmiana grafiki na papierosie nie daje.
@export_node_path("CanvasItem") var puff_node_path: NodePath

## Papieros w trakcie zaciągnięcia, gdy nie ma osobnego węzła: podmieniana
## grafika samego papierosa.
@export var puff_texture: Texture2D

@export_group("Obszary klikalne")

@export var case_click_size := Vector2(120.0, 80.0):
	set(value):
		case_click_size = value
		if is_node_ready():
			_apply_shapes()

@export var cigarette_click_size := Vector2(90.0, 160.0):
	set(value):
		cigarette_click_size = value
		if is_node_ready():
			_apply_shapes()

@export_group("Tempo")

## Jak długo papieros leży wyjęty i da się w niego klikać.
@export_range(1.0, 60.0, 0.5) var cigarette_seconds := 20.0

@export_group("Skutki")

## Ile chillu daje jedno zaciągnięcie.
@export_range(0, 50, 1) var puff_chill := 10

## Ile chillu na sekundę daje sam żarzący się papieros, bez zaciągania.
@export_range(0, 20, 1) var lit_chill_per_second := 1

## Węzeł z metodą pop(int, Node2D) — cyferki chillu. Puste = bez cyferek.
@export_node_path("Node") var popups_path: NodePath

## Gdzie staje cyferka za zaciągnięcie. Puste = na grafice zaciągnięcia.
## Osobna pinezka, bo miejsce dobre dla oka nie musi wypadać na środku grafiki.
@export_node_path("Node2D") var puff_popup_anchor_path: NodePath

## Czynności zamknięte na czas, gdy papieros jest wyjęty. Kierowca ma jedne
## ręce: z papierosem w palcach nie weźmie ukulele.
@export var blocked_activity_paths: Array[NodePath] = []

## Węzły schowane na czas samego zaciągnięcia — ręka w oknie i papieros
## w palcach. Grafika zaciągnięcia pokazuje je już razem i w innym miejscu,
## więc te dwa muszą na tę chwilę zniknąć, żeby nie dublowały ręki.
##
## Poprzednia widoczność jest zapamiętywana i przywracana, nie ustawiana na
## twarde „widoczne" — inaczej zaciągnięcie odsłaniałoby rzeczy schowane
## wcześniej z innego powodu.
@export var hidden_while_puffing: Array[NodePath] = []

@export_group("Dźwięk")

## Odpalanie papierosa.
@export var lighter_stream: AudioStream

## Zaciągnięcie.
@export var puff_stream: AudioStream

@export_range(-40.0, 24.0, 0.1) var volume_db := 0.0

@export var debug_log := true

var _chill_source: Node
var _popups: Node
var _puff_popup_anchor: Node2D
var _puff_node: CanvasItem
var _blocked: Array[CabinActivity] = []
var _hidden: Array[CanvasItem] = []
var _hidden_was_visible: Array[bool] = []

## Raz odblokowana papierośnica zostaje — spadek chillu jej nie zabiera.
var _unlocked := false

var _cigarette_left := 0.0
var _to_next_chill := 0.0

@onready var _case: Node2D = $Case
@onready var _case_art: Sprite2D = $Case/Art
@onready var _case_placeholder: Polygon2D = $Case/Placeholder
@onready var _case_shape: CollisionShape2D = $Case/Area/Shape
@onready var _case_area: Area2D = $Case/Area
@onready var _cigarette: Node2D = $Cigarette
@onready var _cigarette_art: Sprite2D = $Cigarette/Art
@onready var _cigarette_placeholder: Polygon2D = $Cigarette/Placeholder
@onready var _cigarette_shape: CollisionShape2D = $Cigarette/Area/Shape
@onready var _cigarette_area: Area2D = $Cigarette/Area
@onready var _lighter: AudioStreamPlayer = $Lighter
@onready var _puff: AudioStreamPlayer = $Puff


func _ready() -> void:
	_apply_shapes()
	if Engine.is_editor_hint():
		return

	_chill_source = get_node_or_null(chill_source_path)
	_popups = get_node_or_null(popups_path)
	_puff_popup_anchor = get_node_or_null(puff_popup_anchor_path) as Node2D
	_puff_node = get_node_or_null(puff_node_path) as CanvasItem
	if _puff_node != null:
		_puff_node.visible = false

	for path in blocked_activity_paths:
		var activity := get_node_or_null(path) as CabinActivity
		if activity == null:
			push_warning("[papieros] nie ma czynności do zamknięcia pod \"%s\"" % path)
			continue
		_blocked.append(activity)

	for path in hidden_while_puffing:
		var node := get_node_or_null(path) as CanvasItem
		if node == null:
			push_warning("[papieros] nie ma węzła do schowania pod \"%s\"" % path)
			continue
		_hidden.append(node)

	_lighter.stream = lighter_stream
	_puff.stream = puff_stream
	_lighter.volume_db = volume_db
	_puff.volume_db = volume_db
	_puff.finished.connect(_on_puff_finished)

	_case_area.input_event.connect(_on_case_input)
	_cigarette_area.input_event.connect(_on_cigarette_input)

	_show_case(false)
	_hide_cigarette()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not _unlocked and _current_chill() >= min_chill:
		_unlocked = true
		_show_case(true)
		if debug_log:
			print("[papieros] papierośnica odblokowana")

	if _cigarette_left <= 0.0:
		return

	# Sam żarzący się papieros dolewa chillu co sekundę, bez klikania.
	if lit_chill_per_second > 0:
		_to_next_chill -= delta
		if _to_next_chill <= 0.0:
			_to_next_chill += 1.0
			_add_chill(lit_chill_per_second)

	_cigarette_left -= delta
	if _cigarette_left > 0.0:
		return

	# Zaciągnięcie zaczęte tuż przed końcem dopalamy do końca dźwięku —
	# urwanie grafiki w połowie sapnięcia wygląda jak zacięcie.
	if _puff.playing:
		_cigarette_left = 0.01
		return

	_hide_cigarette()
	_set_case_busy(false)
	if debug_log:
		print("[papieros] papieros dopalony")


## Dolewa chillu i wypuszcza cyferkę nad papierosem. Jedno miejsce dla obu
## dróg — żarzenia i zaciągnięcia — żeby liczba na ekranie nie mogła się
## rozjechać z tym, co faktycznie trafiło do licznika.
func _add_chill(amount: int, anchor: Node2D = null, seconds := 0.0, grow := false) -> void:
	if amount <= 0:
		return
	if _chill_source != null and _chill_source.has_method(&"AddChill"):
		_chill_source.call(&"AddChill", amount)
	if _popups != null and _popups.has_method(&"pop"):
		_popups.call(&"pop", amount, anchor if anchor != null else _cigarette, seconds, grow)


## Czy papieros jest wyjęty i się żarzy. Tym karmi się dym.
func is_lit() -> bool:
	return _cigarette_left > 0.0


## Czy trwa właśnie zaciągnięcie.
func is_puffing() -> bool:
	return _puff.playing


func _current_chill() -> int:
	if _chill_source == null:
		return 100
	var value: Variant = _chill_source.get(&"chill")
	return 100 if value == null else int(value)


## Buduje kształty i rozkłada grafiki. Nowy kształt za każdym razem, bo zasób
## z pliku sceny bywa współdzielony i grzebanie w nim ruszyłoby oba obszary.
func _apply_shapes() -> void:
	if _case_shape == null or _cigarette_shape == null:
		return

	var case_shape := RectangleShape2D.new()
	case_shape.size = case_click_size
	_case_shape.shape = case_shape

	var cigarette_shape := RectangleShape2D.new()
	cigarette_shape.size = cigarette_click_size
	_cigarette_shape.shape = cigarette_shape

	_fit_placeholder(_case_placeholder, case_click_size, case_texture)
	_fit_placeholder(_cigarette_placeholder, cigarette_click_size, cigarette_texture)

	_case_art.texture = case_texture
	_case_art.visible = case_texture != null
	_cigarette_art.texture = cigarette_texture
	_cigarette_art.visible = cigarette_texture != null


## Zastępczy prostokąt na czas, gdy grafiki jeszcze nie ma. Znika sam, gdy
## grafika się pojawi.
func _fit_placeholder(polygon: Polygon2D, size: Vector2, texture: Texture2D) -> void:
	if polygon == null:
		return
	var half := size * 0.5
	polygon.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	polygon.visible = texture == null


func _show_case(shown: bool) -> void:
	_case.visible = shown
	_case_area.input_pickable = shown


## Papierośnica zajęta: widać ją dalej, ale nie da się jej kliknąć, dopóki
## papieros leży wyjęty.
func _set_case_busy(busy: bool) -> void:
	_case_area.input_pickable = not busy and _unlocked
	if case_busy_texture == null or case_texture == null:
		return
	_case_art.texture = case_busy_texture if busy else case_texture


func _hide_cigarette() -> void:
	_cigarette_left = 0.0
	_cigarette.visible = false
	_cigarette_area.input_pickable = false
	_show_puff(false)
	for activity in _blocked:
		activity.set_locked(false, self)


## Pokazuje albo chowa grafikę zaciągnięcia — osobnym węzłem, jeśli jest,
## a bez niego podmianą grafiki samego papierosa.
func _show_puff(shown: bool) -> void:
	_hide_others(shown)
	if _puff_node != null:
		_puff_node.visible = shown
		return
	if cigarette_texture == null or puff_texture == null:
		return
	_cigarette_art.texture = puff_texture if shown else cigarette_texture


func _hide_others(hide_them: bool) -> void:
	if hide_them:
		_hidden_was_visible.clear()
		for node in _hidden:
			_hidden_was_visible.append(node.visible)
			node.visible = false
		return

	for index in mini(_hidden.size(), _hidden_was_visible.size()):
		_hidden[index].visible = _hidden_was_visible[index]
	_hidden_was_visible.clear()


func _on_case_input(_viewport: Node, event: InputEvent, _shape: int) -> void:
	if not _is_left_click(event) or not _unlocked or _cigarette_left > 0.0:
		return

	_cigarette_left = cigarette_seconds
	_to_next_chill = 1.0
	_cigarette.visible = true
	_cigarette_area.input_pickable = true
	_set_case_busy(true)
	for activity in _blocked:
		activity.set_locked(true, self)
	if _lighter.stream != null:
		_lighter.play()
	case_opened.emit()
	if debug_log:
		print("[papieros] odpalony, %.0f s na zaciągnięcia" % cigarette_seconds)


func _on_cigarette_input(_viewport: Node, event: InputEvent, _shape: int) -> void:
	# Kolejne zaciągnięcie dopiero po poprzednim — inaczej młócenie myszką
	# ucinałoby dźwięk co klatkę.
	if not _is_left_click(event) or _cigarette_left <= 0.0 or _puff.playing:
		return

	_show_puff(true)
	if _puff.stream != null:
		_puff.play()

	# Chill dostaje się od razu, nie po dopaleniu dźwięku — gracz ma widzieć
	# skutek kliknięcia w tej samej chwili, w której klika.
	#
	# Cyferka stoi na środku grafiki zaciągnięcia i rośnie tyle, ile trwa
	# dźwięk, więc gaśnie razem z nim, a nie w losowym momencie.
	var puff_seconds := 0.0
	if _puff.stream != null:
		puff_seconds = _puff.stream.get_length()
	var puff_anchor := _puff_popup_anchor if _puff_popup_anchor != null else (_puff_node as Node2D)
	_add_chill(puff_chill, puff_anchor, puff_seconds, true)

	puff_taken.emit()
	if debug_log:
		print("[papieros] zaciągnięcie, +%d chillu" % puff_chill)


func _on_puff_finished() -> void:
	_show_puff(false)


func _is_left_click(event: InputEvent) -> bool:
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed
