extends Node2D

## Trzyma węzeł nieruchomo względem ekranu, cokolwiek robi kamera.
##
## Kamera kabiny przechyla się przy zjeżdżaniu z drogi i dokłada zoomu, a to
## obraca i skaluje cały świat — razem ze zbożem, którego prosta górna krawędź
## natychmiast zdradza, że obraz się przekręcił.
##
## Zamiast odejmować sam obrót, zapamiętujemy pozycję węzła na ekranie
## w pierwszej klatce i w każdej następnej przeliczamy ją z powrotem na
## współrzędne świata. Kasuje to obrót, przesunięcie i zoom naraz — odjęcie
## samego obrotu zostawiłoby węzeł krążący po łuku wokół środka kadru.
##
## Przypięcia nie da się załatwić samym CanvasLayerem, bo ten wypadłby
## z kolejności rysowania między polem a drogą.

## Kamera, której ruch kasujemy. Puste = pierwsza kamera widoku.
@export_node_path("Camera2D") var camera_path: NodePath

var _pinned := Transform2D.IDENTITY
var _ready_done := false


func _ready() -> void:
	# Liczymy się po kamerze, nie przed nią. Węzły z wyższym priorytetem idą
	# później w tej samej klatce, więc kasujemy obrót już ustawiony, a nie ten
	# z poprzedniej klatki — inaczej zboże spóźniałoby się o klatkę i przy
	# szybkim przechyle widać by było, jak drga.
	process_priority = 100

	# Odczyt po pierwszej klatce: kamera ustawia swoje przekształcenie w trakcie
	# _ready sceny, więc wcześniej zapisalibyśmy pozycję z niegotowego kadru.
	_pin.call_deferred()


func _pin() -> void:
	_pinned = get_viewport().get_canvas_transform() * global_transform
	_ready_done = true


func _process(_delta: float) -> void:
	if not _ready_done:
		return
	global_transform = get_viewport().get_canvas_transform().affine_inverse() * _pinned
