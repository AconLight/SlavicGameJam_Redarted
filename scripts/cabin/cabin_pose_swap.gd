extends Node2D

## Przestawia ten węzeł w pozę wskazanego węzła-wzorca na czas czynności,
## i wraca po jej zakończeniu.
##
## Wzorzec to zwykły zduplikowany sprite, ustawiony myszką tam, gdzie ma
## trafić oryginał. W grze jest ukrywany — służy tylko za współrzędne.
## Przejście jest ciągłym mieszaniem dwóch poz, nie tweenem, więc
## przerwanie czynności w połowie ruchu zawraca gładko, bez szarpnięcia.
##
## Poz może być wiele, po jednej na czynność — ręka inaczej łapie gruszkę
## CB, a inaczej sięga do radia.

@export_node_path("Node") var controller_path: NodePath

## Mapa czynności na wzorce poz, na przykład:
##   { &"cb_radio": NodePath("../reka-cb"), &"radio": NodePath("../reka-radio") }
@export var poses: Dictionary = {}

## Ile trwa przejście w jedną stronę.
@export_range(0.05, 3.0, 0.05) var swap_seconds := 0.35

var _pose: Node2D
var _active := false
var _progress := 0.0

var _home_position := Vector2.ZERO
var _home_rotation := 0.0
var _home_scale := Vector2.ONE
var _home_skew := 0.0


func _ready() -> void:
	_home_position = position
	_home_rotation = rotation
	_home_scale = scale
	_home_skew = skew

	# Wzorce mają być niewidzialne — istnieją tylko po to, żeby dać się
	# ustawić myszką w edytorze.
	for key in poses:
		var node := get_node_or_null(poses[key]) as Node2D
		if node != null:
			node.visible = false

	var controller := get_node_or_null(controller_path) as CabinActivityController
	if controller == null:
		return
	controller.activity_started.connect(_on_activity_started)
	controller.activity_ended.connect(_on_activity_ended)


func _process(delta: float) -> void:
	if _pose == null:
		return

	var goal := 1.0 if _active else 0.0
	if is_equal_approx(_progress, goal):
		return

	_progress = move_toward(_progress, goal, delta / maxf(swap_seconds, 0.01))

	position = _home_position.lerp(_pose.position, _progress)
	rotation = lerp_angle(_home_rotation, _pose.rotation, _progress)
	scale = _home_scale.lerp(_pose.scale, _progress)
	skew = lerpf(_home_skew, _pose.skew, _progress)


func _on_activity_started(started_id: StringName) -> void:
	if not poses.has(started_id):
		return
	var node := get_node_or_null(poses[started_id]) as Node2D
	if node == null:
		return
	_pose = node
	_active = true


func _on_activity_ended(ended_id: StringName, _held_seconds: float) -> void:
	# Wzorca nie zerujemy — jest jeszcze potrzebny, żeby powrót do pozycji
	# wyjściowej dał się policzyć i przebiegł gładko.
	if poses.has(ended_id):
		_active = false
