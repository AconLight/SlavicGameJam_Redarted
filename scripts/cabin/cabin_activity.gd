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

## Rozmiar obszaru klikalnego.
@export var click_size := Vector2(200.0, 120.0):
	set(value):
		click_size = value
		if is_node_ready():
			_apply_size()

## Czy rysować zastępczy prostokąt. Wyłącz, gdy przedmiot ma już własną
## grafikę i ten obszar ma być niewidzialny.
@export var show_placeholder := true:
	set(value):
		show_placeholder = value
		if is_node_ready():
			_apply_size()

@export_group("Tempo kamery")

## Ile sekund trwa najazd kamery na tę aktywność. Jazda jest jednostajna,
## tak samo szybka na początku jak na końcu.
@export_range(0.1, 20.0, 0.1) var approach_seconds := 3.0

## Ile sekund zajmuje kamerze powrót do spoczynku po puszczeniu tej
## aktywności. Przez ten czas nie da się kliknąć niczego innego.
@export_range(0.0, 10.0, 0.05) var return_seconds := 1.8

var zoom_target: CabinZoomTarget

@onready var _visual: Polygon2D = $Visual
@onready var _click_area: CollisionShape2D = $ClickArea


func _ready() -> void:
	_apply_size()
	if Engine.is_editor_hint():
		return

	zoom_target = get_node_or_null(zoom_target_path) as CabinZoomTarget
	add_to_group(GROUP)
	input_event.connect(_on_input_event)


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
	_visual.visible = show_placeholder


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	press_requested.emit(self)
