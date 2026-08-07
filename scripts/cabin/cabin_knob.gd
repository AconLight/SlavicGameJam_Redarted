@tool
extends Sprite2D

## Gałka strojenia, która przekręca się w lewo i w prawo, dopóki trwa
## wskazana aktywność. Po puszczeniu zostaje w miejscu, w którym się
## zatrzymała — tak jak prawdziwe pokrętło, które nie wraca samo na zero.
##
## Jest źródłem prawdy o wychyleniu strojenia: wystawia tuning_value()
## od -1 do 1, z którego korzystają rzeczy pokazujące to samo w inny
## sposób, na przykład pasek częstotliwości. Dzięki temu wszystko rusza
## się zgodnie, zamiast każde na własnym zegarze.
##
## Nie zna aktywności bezpośrednio, tylko pyta kontroler o identyfikator
## trwającej czynności. Gałkę można więc postawić gdziekolwiek.

@export_node_path("Node") var controller_path: NodePath

## Przy której aktywności ma się kręcić, np. &"radio".
@export var activity_id: StringName = &""

## Maksymalne wychylenie w stopniach, w każdą stronę.
@export_range(0.0, 360.0, 1.0) var swing_degrees := 70.0

## Ile pełnych przejazdów lewo-prawo na sekundę.
@export_range(0.05, 5.0, 0.05) var tuning_speed := 0.5

var _controller: CabinActivityController
var _phase := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_controller = get_node_or_null(controller_path) as CabinActivityController


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _controller == null or _controller.active_id() != activity_id:
		return

	_phase += delta * TAU * tuning_speed
	rotation_degrees = tuning_value() * swing_degrees


## Wychylenie strojenia od -1 do 1. Zamrożone, gdy aktywność nie trwa.
func tuning_value() -> float:
	return sin(_phase)
