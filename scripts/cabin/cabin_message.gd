extends Label

## Napis wyskakujący przy wybranych czynnościach — na przykład ostrzeżenie
## o fotoradarze, gdy kierowca zerknie na prędkościomierz.
##
## Treści siedzą w słowniku: identyfikator czynności na tekst. Dopisanie
## kolejnego komunikatu nie wymaga niczego w kodzie.

@export_node_path("Node") var controller_path: NodePath

## Identyfikator czynności na tekst do pokazania.
@export var messages: Dictionary = {}

## Jak długo napis stoi na ekranie w pełnej sile.
@export_range(0.1, 10.0, 0.1) var hold_seconds := 2.0

## Ile trwa pojawienie się i zniknięcie.
@export_range(0.05, 3.0, 0.05) var fade_seconds := 0.25

var _tween: Tween


func _ready() -> void:
	# Niewidoczny do pierwszego komunikatu. Sam węzeł zostaje włączony, bo
	# przezroczystość gasimy modulate, a nie widocznością — inaczej tween
	# nie miałby czego animować.
	modulate.a = 0.0

	var controller := get_node_or_null(controller_path) as CabinActivityController
	if controller == null:
		push_warning("[napis] brak kontrolera czynności — komunikaty nie zadziałają")
		return
	controller.activity_started.connect(_on_activity_started)


func _on_activity_started(activity_id: StringName) -> void:
	if not messages.has(activity_id):
		return
	show_message(str(messages[activity_id]))


func show_message(content: String) -> void:
	text = content

	# Nowy komunikat ubija poprzedni: create_tween sam kończy tweeny tego węzła,
	# więc dwa napisy pod rząd nie walczą o przezroczystość.
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", 1.0, fade_seconds)
	_tween.tween_interval(hold_seconds)
	_tween.tween_property(self, ^"modulate:a", 0.0, fade_seconds)
