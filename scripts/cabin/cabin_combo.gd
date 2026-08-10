extends Label

## COMBO: papieros w palcach i CB w drugiej ręce naraz.
##
## Nagradza robienie dwóch rzeczy jednocześnie — kierowca odpala papierosa,
## a póki się żarzy, łapie gruszkę i gada. Wtedy leci dopłata do chillu i napis,
## który wjeżdża z obrotem.
##
## Warunek sprawdzamy odpytywaniem, a nie sygnałami: obie rzeczy mogą się
## zacząć w dowolnej kolejności, więc łatwiej patrzeć na stan niż łapać dwa
## zdarzenia i pilnować, które przyszło pierwsze.

signal combo_scored(amount: int)

@export_node_path("Node") var controller_path: NodePath

## Papieros — węzeł z metodą is_lit().
@export_node_path("Node") var cigarette_path: NodePath

## Węzeł z metodą AddChill(int) — w grze KeepScore ze sceny score.
@export_node_path("Node") var chill_source_path: NodePath

## Która czynność, złapana przy żarzącym się papierosie, robi combo.
@export var combo_activity_id: StringName = &"cb_radio"

## Ile chillu dopłacamy za combo.
@export_range(0, 100, 1) var combo_chill := 10

@export_group("Napis")

## %d podmienia się na dopłatę.
@export var template := "COMBO! +%d CHILL"

## Jak długo napis stoi, zanim zacznie gasnąć.
@export_range(0.1, 10.0, 0.1) var hold_seconds := 1.4

@export_range(0.05, 3.0, 0.05) var fade_seconds := 0.4

## O ile stopni napis jest przekręcony w chwili wjazdu. Odkręca się do zera,
## więc wygląda, jakby wpadł z rozmachem.
@export_range(-180.0, 180.0, 1.0) var spin_degrees := -25.0

## Jak mocno przeskaluje się w szczycie, zanim usiądzie na swoim rozmiarze.
@export_range(1.0, 3.0, 0.05) var overshoot := 1.35

var _controller: CabinActivityController
var _cigarette: Node
var _chill_source: Node

## Combo liczy się raz na jedno spotkanie obu czynności — dopóki trwa, nie
## dopłacamy co klatkę.
var _scored := false


func _ready() -> void:
	modulate.a = 0.0
	_controller = get_node_or_null(controller_path) as CabinActivityController
	_cigarette = get_node_or_null(cigarette_path)
	_chill_source = get_node_or_null(chill_source_path)
	if _controller == null or _cigarette == null:
		push_warning("[combo] brak kontrolera albo papierosa — combo nie zadziała")


func _process(_delta: float) -> void:
	if _controller == null or _cigarette == null:
		return

	var together := _controller.active_id() == combo_activity_id and _is_lit()
	if not together:
		# Rozbrojenie po rozejściu się czynności, żeby następne spotkanie znów
		# się liczyło.
		_scored = false
		return
	if _scored:
		return

	_scored = true
	_score()


func _is_lit() -> bool:
	if not _cigarette.has_method(&"is_lit"):
		return false
	return _cigarette.call(&"is_lit")


func _score() -> void:
	if combo_chill > 0 and _chill_source != null and _chill_source.has_method(&"AddChill"):
		_chill_source.call(&"AddChill", combo_chill)

	text = template % combo_chill
	_play_effect()
	combo_scored.emit(combo_chill)
	print("[combo] papieros i %s naraz, +%d chillu" % [combo_activity_id, combo_chill])


## Wjazd z obrotem i przeskalowaniem. Nowe combo ubija poprzedni pokaz, bo
## create_tween kończy tweeny tego węzła.
func _play_effect() -> void:
	modulate.a = 1.0
	scale = Vector2(0.3, 0.3)
	rotation_degrees = spin_degrees

	var tween := create_tween()
	tween.tween_property(self, ^"scale", Vector2.ONE * overshoot, 0.18) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, ^"rotation_degrees", -spin_degrees * 0.3, 0.18)

	tween.chain().tween_property(self, ^"scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, ^"rotation_degrees", 0.0, 0.14)

	tween.chain().tween_interval(hold_seconds)
	tween.chain().tween_property(self, ^"modulate:a", 0.0, fade_seconds)
