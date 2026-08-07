@tool
extends Node2D

## Gruszka od CB zwisająca na spiralnym kablu.
##
## Węzeł stoi w punkcie zaczepienia kabla, a wszystko wisi w dół — obrót
## węzła kiwa całością jak wahadłem. Kabel jest rozciągany w pionie
## (udaje sprężynkę), gruszka tylko jeździ za jego końcem i nigdy się nie
## deformuje.
##
## Rozmach kołysania bierze się z drżenia kamery: na gładkiej drodze
## gruszka ledwo dynda, na wybojach rzuca nią wyraźnie. Podskakiwanie
## chodzi w tym samym rytmie, tylko dwa razy szybciej — sprężyna napina
## się najmocniej, gdy gruszka mija dół łuku, czyli dwa razy na wahnięcie.
##
## Jest @tool, więc widać ją w edytorze i da się ustawić myszką.

## Kamera kabiny. Bez niej gruszka kiwa się samym minimalnym rozmachem.
@export_node_path("Camera2D") var camera_path: NodePath

@export_group("Kształt")

## Ile razy powiększyć kabel. Osobno od gruszki, bo obie grafiki są
## rysowane w innej skali pikselarta.
@export_range(0.1, 32.0, 0.1) var cable_scale := 8.0:
	set(value):
		cable_scale = value
		_apply_shape()

## Ile razy powiększyć gruszkę.
@export_range(0.1, 32.0, 0.1) var body_scale := 1.0:
	set(value):
		body_scale = value
		_apply_shape()

## Długość kabla w spoczynku, w pikselach ekranu.
@export_range(20.0, 900.0, 1.0) var cable_length := 300.0:
	set(value):
		cable_length = value
		_apply_shape()

@export_group("Kiwanie")

## Wychylenie na gładkiej drodze, w stopniach.
@export_range(0.0, 30.0, 0.5) var swing_degrees_min := 2.0

## Wychylenie przy mocnym wyboju, w stopniach.
@export_range(0.0, 60.0, 0.5) var swing_degrees_max := 11.0

## Ile pełnych wahnięć na sekundę.
@export_range(0.05, 4.0, 0.05) var swing_frequency := 0.8

## O ile pikseli rozciąga się sprężyna w dolnym punkcie łuku.
@export_range(0.0, 200.0, 1.0) var bounce_pixels := 24.0

var _camera: Node2D
var _time := 0.0

@onready var _cable: Sprite2D = $Cable
@onready var _body: Sprite2D = $Body


func _ready() -> void:
	_apply_shape()
	if Engine.is_editor_hint():
		return
	_camera = get_node_or_null(camera_path) as Node2D


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_time += delta

	var intensity := 0.0
	if _camera != null and _camera.has_method(&"shake_intensity"):
		intensity = _camera.shake_intensity()

	var reach := lerpf(swing_degrees_min, swing_degrees_max, intensity)
	var wave := sin(_time * TAU * swing_frequency)
	wave += 0.35 * sin(_time * TAU * swing_frequency * 1.7 + 0.9)
	rotation_degrees = wave * reach

	# Zero na skraju łuku, maksimum w dole — stąd podwojona częstotliwość
	# i cosinus zamiast sinusa.
	var stretch := 0.5 - 0.5 * cos(_time * TAU * swing_frequency * 2.0)
	_apply_length(cable_length + bounce_pixels * stretch)


func _apply_shape() -> void:
	if _cable == null or _body == null:
		return
	_cable.scale.x = cable_scale
	_body.scale = Vector2(body_scale, body_scale)
	_center(_cable)
	_center(_body)
	_apply_length(cable_length)


## Ustawia sprite tak, żeby wisiał środkiem pod punktem zaczepienia
## i rósł w dół. Liczone z rozmiaru tekstury, więc podmiana grafiki na
## inną wielkość nie wymaga poprawiania niczego ręcznie.
func _center(sprite: Sprite2D) -> void:
	if sprite.texture == null:
		return
	sprite.centered = false
	sprite.offset = Vector2(-sprite.texture.get_width() * 0.5, 0.0)


## Rozciąga sam kabel i przesuwa gruszkę na jego koniec. Gruszka dostaje
## pozycję, nigdy skalę — inaczej rozjeżdżałaby się razem ze sprężyną.
func _apply_length(length: float) -> void:
	if _cable == null or _body == null:
		return
	var texture_height := 1.0
	if _cable.texture != null:
		texture_height = maxf(float(_cable.texture.get_height()), 1.0)
	_cable.scale.y = length / texture_height
	_body.position.y = length
