@tool
extends Node2D

## Gruszka od CB zwisająca na spiralnym kablu.
##
## Węzeł stoi w punkcie zaczepienia kabla. Kiedy gruszka wisi, kołysze się
## razem z całym węzłem i podskakuje na sprężynie. Kiedy kierowca ją bierze,
## przenosi się w pozę wskazaną węzłem-wzorcem, a kołysanie ustaje.
##
## Kabel nie ma własnej długości — w każdej klatce celuje w gruszkę i
## rozciąga się dokładnie na odległość do niej. Dzięki temu ta sama logika
## obsługuje zwisanie, podskakiwanie i trzymanie w ręce.
##
## Rozmach kołysania bierze się z drżenia kamery: na gładkiej drodze gruszka
## ledwo dynda, na wybojach rzuca nią wyraźnie. Podskakiwanie chodzi w tym
## samym rytmie, tylko dwa razy szybciej — sprężyna napina się najmocniej,
## gdy gruszka mija dół łuku, czyli dwa razy na wahnięcie.
##
## Jest @tool, więc widać ją w edytorze i da się ustawić myszką.

## Kamera kabiny. Bez niej gruszka kiwa się samym minimalnym rozmachem.
@export_node_path("Camera2D") var camera_path: NodePath

@export_group("Branie do ręki")

@export_node_path("Node") var controller_path: NodePath

## Przy której czynności gruszka trafia do ręki.
@export var activity_id: StringName = &"cb_radio"

## Węzeł-wzorzec z pozą gruszki w ręce. Ustawiany myszką, w grze ukrywany.
@export_node_path("Node2D") var held_pose_path: NodePath

## Ile trwa podniesienie i odłożenie.
@export_range(0.05, 3.0, 0.05) var grab_seconds := 0.35

@export_group("Zwijanie")

## Czynność, której stan decyduje, czy gruszka zwisa. Zwykle własne dziecko
## tego węzła. Puste = gruszka wisi zawsze.
##
## Zwinięta oznacza kabel długości zero: gruszka siedzi w punkcie zaczepienia,
## jakby wciągnięta pod sufit. Rozwija się, gdy chill odblokuje CB, i wjeżdża
## z powrotem na czas blokady po użyciu.
@export_node_path("Node") var activity_path: NodePath

## Ile trwa opadanie gruszki po odblokowaniu.
@export_range(0.05, 5.0, 0.05) var unroll_seconds := 0.9

## Ile trwa wciąganie gruszki, gdy CB się blokuje.
@export_range(0.05, 5.0, 0.05) var roll_seconds := 0.55

## Grafika gruszki na czas blokady — bez obwódki. Ustawiana tutaj, a nie na
## czynności, bo gruszkę rysuje ten węzeł; czynność jest samym obszarem
## klikalnym bez własnej grafiki. Puste = grafika się nie zmienia.
##
## Leży na zwykłej i pulsuje przezroczystością, tak samo jak przy pozostałych
## czynnościach — pod spodem zostaje normalna gruszka, więc widać mruganie
## między dwoma kolorami. Wymaga węzła Sprite2D o nazwie LockedArt pod Body.
@export var locked_texture: Texture2D

## Ile mrugnięć na sekundę.
@export_range(0.1, 8.0, 0.1) var locked_pulse_frequency := 0.8

## Jak bardzo grafika blokady przygasa w dołku pulsu.
@export_range(0.0, 1.0, 0.05) var locked_pulse_floor := 0.0

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
var _held_pose: Node2D
var _time := 0.0

## 0 = wisi, 1 = w ręce. Mieszanie zamiast tweena, żeby puszczenie
## w połowie ruchu zawracało gładko.
var _grab := 0.0
var _held := false

var _activity: CabinActivity
var _locked_art: Sprite2D
var _base_texture: Texture2D
var _pulse_time := 0.0

## 0 = kabel wciągnięty do zera, 1 = pełna długość. Rozwijanie i zwijanie mają
## własne czasy, bo opadanie ma być cięższe niż wciąganie.
var _roll := 0.0

@onready var _cable: Sprite2D = $Cable
@onready var _body: Sprite2D = $Body


func _ready() -> void:
	_apply_shape()
	if Engine.is_editor_hint():
		return

	_camera = get_node_or_null(camera_path) as Node2D
	_base_texture = _body.texture if _body != null else null
	_locked_art = get_node_or_null(^"Body/LockedArt") as Sprite2D
	if _locked_art != null:
		_locked_art.visible = false
	_activity = get_node_or_null(activity_path) as CabinActivity
	# Bez wskazanej czynności gruszka po prostu zwisa — inaczej kabina odpalona
	# osobno pokazywałaby ją na zawsze wciągniętą pod sufit.
	_roll = 0.0 if _activity != null else 1.0

	_held_pose = get_node_or_null(held_pose_path) as Node2D
	if _held_pose != null:
		_held_pose.visible = false

	var controller := get_node_or_null(controller_path) as CabinActivityController
	if controller == null:
		return
	controller.activity_started.connect(_on_activity_started)
	controller.activity_ended.connect(_on_activity_ended)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_time += delta
	_grab = move_toward(_grab, 1.0 if _held else 0.0, delta / maxf(grab_seconds, 0.01))

	var wants_hanging := _hangs_now()
	var roll_pace := unroll_seconds if wants_hanging else roll_seconds
	_roll = move_toward(_roll, 1.0 if wants_hanging else 0.0, delta / maxf(roll_pace, 0.01))
	_refresh_body_texture(delta)

	var intensity := 0.0
	if _camera != null and _camera.has_method(&"shake_intensity"):
		intensity = _camera.shake_intensity()

	# Kołysanie i podskakiwanie gasną w miarę brania do ręki.
	var hanging := 1.0 - _grab

	var reach := lerpf(swing_degrees_min, swing_degrees_max, intensity)
	var wave := sin(_time * TAU * swing_frequency)
	wave += 0.35 * sin(_time * TAU * swing_frequency * 1.7 + 0.9)
	rotation_degrees = wave * reach * hanging

	# Zero na skraju łuku, maksimum w dole — stąd podwojona częstotliwość
	# i cosinus zamiast sinusa.
	var stretch := 0.5 - 0.5 * cos(_time * TAU * swing_frequency * 2.0)
	# Zwinięcie skraca cały zwis, także sprężynę — inaczej wciągnięta gruszka
	# dalej podskakiwałaby pod sufitem.
	var hang_position := Vector2(0.0, (cable_length + bounce_pixels * stretch * hanging) * _roll)

	var target := hang_position
	var target_rotation := 0.0
	if _held_pose != null:
		target = hang_position.lerp(_held_pose.position, _grab)
		target_rotation = lerp_angle(0.0, _held_pose.rotation, _grab)

	_body.position = target
	_body.rotation = target_rotation
	_aim_cable_at(target)


## Mrugająca warstwa na gruszce. Zwykła grafika zostaje pod spodem, a ta gaśnie
## i wraca cosinusem, więc gruszka gotowa do złapania miga między dwoma
## kolorami. Zablokowana nie mruga — stoi na wersji bez obwódki.
func _refresh_body_texture(delta: float) -> void:
	if _locked_art == null:
		return

	if locked_texture == null or _body == null:
		_locked_art.visible = false
		return

	_locked_art.texture = locked_texture

	# Mruga gruszka gotowa do złapania, i tylko dopóki gracz jej nie tknął.
	var locked := _activity != null and _activity.locked
	var invites := _activity == null or (_activity.available and not locked and not _activity.used)
	_locked_art.visible = invites

	if not invites:
		# Poza mruganiem podmieniamy samą grafikę gruszki. Wersja bez obwódki
		# położona na wierzchu przepuszczałaby ramkę spod spodu.
		_pulse_time = 0.0
		_body.texture = locked_texture if locked else _base_texture
		return

	_body.texture = _base_texture
	_pulse_time += delta
	var wave := 0.5 + 0.5 * cos(_pulse_time * TAU * locked_pulse_frequency)
	_locked_art.modulate.a = lerpf(locked_pulse_floor, 1.0, wave)


## Czy gruszka ma teraz zwisać. Trzymana w ręce zawsze, bo w trakcie rozmowy
## nie wolno jej wciągnąć kierowcy z dłoni.
func _hangs_now() -> bool:
	if _held:
		return true
	if _activity == null:
		return true
	return _activity.available and not _activity.locked


func _apply_shape() -> void:
	if _cable == null or _body == null:
		return
	_cable.scale.x = cable_scale
	_body.scale = Vector2(body_scale, body_scale)
	_center(_cable)
	_center(_body)
	_aim_cable_at(Vector2(0.0, cable_length))


## Ustawia sprite tak, żeby wisiał środkiem pod punktem zaczepienia
## i rósł w dół. Liczone z rozmiaru tekstury, więc podmiana grafiki na
## inną wielkość nie wymaga poprawiania niczego ręcznie.
func _center(sprite: Sprite2D) -> void:
	if sprite.texture == null:
		return
	sprite.centered = false
	sprite.offset = Vector2(-sprite.texture.get_width() * 0.5, 0.0)


## Obraca i rozciąga kabel tak, żeby sięgał od zaczepienia do podanego
## punktu. Sam kabel dostaje skalę, gruszka nigdy — inaczej rozjeżdżałaby
## się razem ze sprężyną.
func _aim_cable_at(point: Vector2) -> void:
	if _cable == null:
		return

	var texture_height := 1.0
	if _cable.texture != null:
		texture_height = maxf(float(_cable.texture.get_height()), 1.0)

	# Lokalna oś Y kabla ma wskazywać na punkt. Kąt osi Y to obrót + PI/2.
	_cable.rotation = point.angle() - PI * 0.5
	_cable.scale.y = point.length() / texture_height


func _on_activity_started(started_id: StringName) -> void:
	if started_id == activity_id:
		_held = true


func _on_activity_ended(ended_id: StringName, _held_seconds: float) -> void:
	if ended_id == activity_id:
		_held = false
