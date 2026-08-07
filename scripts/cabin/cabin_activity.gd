class_name CabinActivity
extends Area2D

## Przedmiot w kabinie, który da się przytrzymać.

signal press_requested(activity: CabinActivity)

const GROUP := &"cabin_activity"

## Identyfikator trafiający do sygnałów, np. &"radio".
@export var activity_id: StringName = &""

## Pinezka, na którą najedzie kamera. Puste = kamera zostaje w spoczynku.
## Musi być NodePath, nie bezpośrednia referencja — patrz komentarz
## w cabin_camera.gd.
@export_node_path("Marker2D") var zoom_target_path: NodePath

## Ile sekund trwa najazd kamery na tę aktywność. Jazda jest jednostajna,
## tak samo szybka na początku jak na końcu.
@export_range(0.1, 20.0, 0.1) var approach_seconds := 3.0

## Ile sekund zajmuje kamerze powrót do spoczynku po puszczeniu tej
## aktywności. Przez ten czas nie da się kliknąć niczego innego.
@export_range(0.0, 10.0, 0.05) var return_seconds := 1.8

var zoom_target: CabinZoomTarget


func _ready() -> void:
	zoom_target = get_node_or_null(zoom_target_path) as CabinZoomTarget
	add_to_group(GROUP)
	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	press_requested.emit(self)
