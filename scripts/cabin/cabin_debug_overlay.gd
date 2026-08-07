extends CanvasLayer

## Podgląd stanu aktywności na czas budowy. Do skasowania albo
## wyłączenia przełącznikiem visible, gdy przestanie być potrzebny.

@export_node_path("Node") var controller_path: NodePath

var controller: CabinActivityController

@onready var _label: Label = $StatusLabel


func _ready() -> void:
	controller = get_node_or_null(controller_path) as CabinActivityController


func _process(_delta: float) -> void:
	if controller == null:
		return
	var id := controller.active_id()
	if id != &"":
		_label.text = "%s — %.1f s" % [id, controller.held_seconds()]
	elif controller.is_returning():
		_label.text = "powrót kamery — klikanie zablokowane"
	else:
		_label.text = "—"
