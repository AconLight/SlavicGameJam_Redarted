@tool
class_name CabinActivity
extends Area2D

## Przedmiot w kabinie, który da się przytrzymać.
##
## Jest @tool, żeby prostokąt obszaru klikalnego był widoczny w edytorze
## i dało się go ustawić myszką. Logika działa tylko w grze.

signal press_requested(activity: CabinActivity)

const GROUP := &"cabin_activity"

## Identyfikator trafiający do sygnałów, np. &"radio".
@export var activity_id: StringName = &""

## Pinezka, na którą najedzie kamera. Puste = kamera zostaje w spoczynku.
## Musi być NodePath, nie bezpośrednia referencja — patrz komentarz
## w cabin_camera.gd.
@export_node_path("Marker2D") var zoom_target_path: NodePath

## Grafika przedmiotu. Gdy ustawiona, zastępczy prostokąt znika sam.
@export var texture: Texture2D:
	set(value):
		texture = value
		if is_node_ready():
			_apply_size()

## Rozmiar obszaru klikalnego.
@export var click_size := Vector2(200.0, 120.0):
	set(value):
		click_size = value
		if is_node_ready():
			_apply_size()

## Czy rysować zastępczy prostokąt, gdy nie ma grafiki. Wyłącz, gdy
## przedmiot jest już narysowany gdzie indziej i ten obszar ma być
## niewidzialny.
@export var show_placeholder := true:
	set(value):
		show_placeholder = value
		if is_node_ready():
			_apply_size()

## Od jakiego poziomu chillu ta aktywność jest widoczna. 0 = od początku.
## Poniżej progu przedmiot znika i nie da się go kliknąć.
@export_range(0, 100, 1) var min_chill := 0

## Węzeł, który znika razem z aktywnością. Puste = znika sama aktywność.
##
## Potrzebne, gdy przedmiot jest rysowany gdzie indziej niż tu — na
## przykład gruszka CB, którą rysuje jej rodzic. Wskaż wtedy tego rodzica
## (ścieżka `..`), inaczej klikanie zgaśnie, a obrazek zostanie na ekranie.
@export_node_path("CanvasItem") var visual_root_path: NodePath

## Czy przedmiot przenosi się do swojej pinezki na czas czynności — tak
## jakby kierowca brał go do ręki. Po puszczeniu wraca na swoje miejsce.
## Wymaga ustawionej pinezki.
@export var move_to_focus_while_active := false

## Dokąd przenieść przedmiot na czas czynności. Puste = na swoją pinezkę
## zoomu. Ustaw, gdy ma jechać gdzie indziej niż patrzy kamera — na przykład
## ukulele zjeżdża pod ekran, a w kadrze zostaje osobna grafika grania.
@export_node_path("Node2D") var active_pose_path: NodePath

## Ile sekund leci przedmiot między swoim miejscem a pinezką.
## 0 = przeskok bez animacji.
@export_range(0.0, 2.0, 0.01) var focus_travel_seconds := 0.2

## O ile stopni przedmiot kołysze się podczas czynności. 0 = stoi
## nieruchomo. Kołysanie startuje dopiero po dolocie na miejsce.
@export_range(0.0, 45.0, 0.5) var sway_degrees_while_active := 0.0

## Ile wahnięć na sekundę podczas czynności.
@export_range(0.05, 6.0, 0.05) var sway_frequency := 1.2

@export_group("Tempo kamery")

## Ile sekund trwa najazd kamery na tę aktywność. Jazda jest jednostajna,
## tak samo szybka na początku jak na końcu.
@export_range(0.1, 20.0, 0.1) var approach_seconds := 3.0

## Ile sekund zajmuje kamerze powrót do spoczynku po puszczeniu tej
## aktywności. Przez ten czas nie da się kliknąć niczego innego.
@export_range(0.0, 10.0, 0.05) var return_seconds := 1.8

var zoom_target: CabinZoomTarget
var _active_pose: Node2D

## Czy przedmiot jest odblokowany. Ustawia to kontroler, patrząc na chill.
var available := true

var _visual_root: CanvasItem

## Węzeł, którym faktycznie ruszamy i który chowamy — sam przedmiot albo
## wskazany visual_root.
var _mover: Node2D
var _home_position := Vector2.ZERO
var _home_rotation := 0.0
var _travel_tween: Tween
var _is_active := false
var _active_rotation := 0.0
var _sway_time := 0.0

@onready var _visual: Polygon2D = $Visual
@onready var _art: Sprite2D = $Art
@onready var _click_area: CollisionShape2D = $ClickArea


func _ready() -> void:
	_apply_size()
	if Engine.is_editor_hint():
		return

	zoom_target = get_node_or_null(zoom_target_path) as CabinZoomTarget
	_active_pose = get_node_or_null(active_pose_path) as Node2D
	if _active_pose != null:
		_active_pose.visible = false
	_visual_root = get_node_or_null(visual_root_path) as CanvasItem
	_mover = (_visual_root as Node2D) if _visual_root is Node2D else self
	_home_position = _mover.position
	_home_rotation = _mover.rotation
	add_to_group(GROUP)
	input_event.connect(_on_input_event)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _is_active or _mover == null:
		return
	if sway_degrees_while_active <= 0.0:
		return
	# W trakcie przelotu obrotem rządzi tween — dokładanie tu drugiego
	# źródła szarpałoby przedmiotem w locie.
	if _travel_tween != null and _travel_tween.is_valid():
		return

	_sway_time += delta
	var wave := sin(_sway_time * TAU * sway_frequency)
	wave += 0.3 * sin(_sway_time * TAU * sway_frequency * 1.6 + 0.8)
	_mover.rotation = _active_rotation + deg_to_rad(wave * sway_degrees_while_active)


func _apply_size() -> void:
	var half := click_size * 0.5

	# Nowy kształt zamiast zmiany istniejącego: zasób z pliku sceny jest
	# współdzielony przez wszystkie kopie klocka, więc grzebanie w nim
	# zmieniłoby rozmiar każdej aktywności naraz.
	var shape := RectangleShape2D.new()
	shape.size = click_size
	_click_area.shape = shape

	_visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])

	_art.texture = texture
	_art.visible = texture != null
	_visual.visible = show_placeholder and texture == null


## Pokazuje albo chowa przedmiot. Ukryty przestaje też łapać kliknięcia —
## samo visible nie wyłącza obszaru Area2D.
##
## Ustawia wszystko za każdym razem, bez skrótu „nic się nie zmieniło".
## Wcześniej ten skrót tu był i powodował, że gdy scena startowała
## z visible = false, a próg chillu był spełniony, przedmiot zostawał
## niewidzialny na zawsze — flaga zgadzała się od początku, więc nikt
## widoczności nie poprawiał.
func set_available(value: bool) -> void:
	available = value
	input_pickable = value
	if _visual_root != null:
		_visual_root.visible = value
		return
	visible = value


## Woła to kontroler przy rozpoczęciu i zakończeniu czynności. Przenosi
## przedmiot do pinezki i z powrotem, jeśli tak ustawiono.
func set_active(value: bool) -> void:
	_is_active = value
	_sway_time = 0.0

	# Własna poza ma pierwszeństwo nad pinezką kamery.
	var destination: Node2D = _active_pose if _active_pose != null else zoom_target

	if not move_to_focus_while_active or destination == null or _mover == null:
		# Kołysać można się też bez przenoszenia — wtedy wokół własnego kąta.
		if _mover != null:
			_active_rotation = _mover.rotation
		return

	var target := _home_position
	var target_rotation := _home_rotation
	if value:
		# Pinezka żyje w innej gałęzi drzewa, więc jej globalną pozycję
		# i obrót trzeba przeliczyć na układ rodzica przenoszonego węzła.
		var parent := _mover.get_parent() as Node2D
		if parent != null:
			target = parent.to_local(destination.global_position)
			target_rotation = destination.global_rotation - parent.global_rotation
		else:
			target = destination.global_position
			target_rotation = destination.global_rotation

	_active_rotation = target_rotation

	# Ubicie poprzedniego przelotu — bez tego szybkie łapanie i puszczanie
	# zostawiłoby dwa tweeny szarpiące ten sam węzeł w różne strony.
	if _travel_tween != null and _travel_tween.is_valid():
		_travel_tween.kill()

	if focus_travel_seconds <= 0.0:
		_mover.position = target
		_mover.rotation = target_rotation
		return

	_travel_tween = create_tween().set_parallel(true)
	_travel_tween.tween_property(_mover, ^"position", target, focus_travel_seconds) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_CUBIC)
	_travel_tween.tween_property(_mover, ^"rotation", target_rotation, focus_travel_seconds) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_CUBIC)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	press_requested.emit(self)
