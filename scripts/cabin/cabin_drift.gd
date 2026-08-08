extends Node

## Zjeżdżanie z drogi, gdy kierowca za długo grzebie w jednej czynności.
##
## Trzyma jedną liczbę od 0 do 1: jak daleko tir zjechał na pobocze. Rośnie
## dopiero po okresie darmowym danej czynności, a po jej puszczeniu wraca do
## zera — kierowca odkręca. Jedynka to wypadnięcie z drogi i koniec przejazdu.
##
## Które czynności ściągają tira i jak mocno, mówią same czynności
## (`drift_per_second`, `drift_grace_seconds`) — tutaj nie ma listy nazw.
##
## Zjazd pokazujemy przesuwaniem drogi w bok, bo system perspektywy nie ma
## pojęcia „gdzie w poprzek jest gracz" — wszystko stoi na numerach pasów.
## Droga jedzie na całość, tło mniej, i z tej różnicy robi się paralaksa.
## Węzeł żyje w scenie rozgrywki, nie w kabinie, bo droga i tło są rodzeństwem
## kabiny; sama kabina odpalona osobno działa dalej, tylko bez zjeżdżania.

@export_node_path("Node") var controller_path: NodePath

## Węzeł z metodą GameOver() — w grze KeepScore ze sceny score. Bez niego
## wypadnięcie z drogi tylko się wypisze i nic nie zrobi.
@export_node_path("Node") var score_source_path: NodePath

@export_group("Co się przesuwa")

## Droga. Jedzie w bok na pełną wartość zjazdu.
@export var road_paths: Array[NodePath] = []

## To samo, ale wskazuje rodzica: przesuwają się wszystkie jego dzieci typu
## Node2D, a on sam nie.
##
## Tak trzeba dosięgnąć zawartości scrollera. Jego pojemnik na elementy jest
## zwykłym węzłem Node, bez przekształcenia, a to przerywa łańcuch: elementy
## liczą swoje położenie od warstwy rysowania, nie od węzła zarządcy. Ruszanie
## zarządcy nie robi im nic. Wskazanie rodzica zamiast listy dzieci sprawia,
## że nowe pasy czy drzewa dodane po drodze pojadą razem z resztą.
@export var road_children_paths: Array[NodePath] = []

## Tło i otoczenie. Jadą słabiej, żeby złapać paralaksę.
@export var background_paths: Array[NodePath] = []

## Jaką część drogi przejeżdża tło. 0 = stoi.
@export_range(0.0, 1.0, 0.05) var background_factor := 0.35

## O ile pikseli ucieka droga przy pełnym zjeżdżeniu.
@export_range(0.0, 1200.0, 10.0) var max_shift_pixels := 600.0

## Czy tir ściąga w prawo. Odznaczenie przerzuca zjazd na lewy pas.
@export var drift_right := true

@export_group("Tempo")

## Jak szybko kierowca odkręca po puszczeniu czynności, w jednostkach zjazdu
## na sekundę. 0.4 to dwie i pół sekundy z pobocza na środek pasa.
@export_range(0.05, 2.0, 0.05) var recover_rate := 0.4

## Od tego poziomu jest już nerwowo — do podpięcia dźwięku i mocniejszego
## trzęsienia, gdy będą.
@export_range(0.0, 1.0, 0.05) var warning_threshold := 0.7

@export var debug_log := true

var controller: CabinActivityController

var _score_source: Node
var _roads: Array[Node2D] = []
var _road_home: Array[Vector2] = []
var _backgrounds: Array[Node2D] = []
var _background_home: Array[Vector2] = []

var _drift := 0.0
var _crashed := false
var _warned := false


func _ready() -> void:
	controller = get_node_or_null(controller_path) as CabinActivityController
	_score_source = get_node_or_null(score_source_path)

	for path in road_paths:
		var node := get_node_or_null(path) as Node2D
		if node == null:
			push_warning("[zjazd] nie ma drogi pod ścieżką \"%s\"" % path)
			continue
		_remember_road(node)

	for path in road_children_paths:
		var parent := get_node_or_null(path)
		if parent == null:
			push_warning("[zjazd] nie ma rodzica drogi pod ścieżką \"%s\"" % path)
			continue
		for child in parent.get_children():
			var node := child as Node2D
			if node != null:
				_remember_road(node)

	for path in background_paths:
		var node := get_node_or_null(path) as Node2D
		if node == null:
			push_warning("[zjazd] nie ma tła pod ścieżką \"%s\"" % path)
			continue
		_backgrounds.append(node)
		_background_home.append(node.position)

	# Milcząca literówka w ścieżce znaczyłaby, że zjeżdżania po prostu nie ma —
	# a to widać dopiero wtedy, gdy ktoś siedzi na ukulele i nic się nie dzieje.
	if controller == null:
		push_warning("[zjazd] brak kontrolera aktywności — zjeżdżanie nie zadziała")
	if _score_source == null or not _score_source.has_method(&"GameOver"):
		push_warning("[zjazd] brak licznika z GameOver() — wypadnięcie z drogi nie skończy gry")


func _process(delta: float) -> void:
	if _crashed or controller == null:
		return

	if _pull_per_second() > 0.0:
		_drift = minf(_drift + _pull_per_second() * delta, 1.0)
	else:
		_drift = maxf(_drift - recover_rate * delta, 0.0)

	_apply_shift()

	if debug_log and not _warned and _drift >= warning_threshold:
		_warned = true
		print("[zjazd] pobocze blisko")
	elif _warned and _drift < warning_threshold:
		_warned = false

	if _drift >= 1.0:
		_crash()


func _remember_road(node: Node2D) -> void:
	_roads.append(node)
	_road_home.append(node.position)


## Jak mocno w tej chwili ściąga tira. 0 = nic go nie ciągnie, więc kierowca
## odkręca. Okres darmowy liczymy z czasu trzymania mierzonego przez kontroler,
## żeby nie było tu drugiego zegara, który mógłby się z tym rozjechać.
func _pull_per_second() -> float:
	var activity := controller.active_activity()
	if activity == null or activity.drift_per_second <= 0.0:
		return 0.0
	if controller.held_seconds() < activity.drift_grace_seconds:
		return 0.0
	return activity.drift_per_second


## Jak daleko tir zjechał, od 0 do 1.
func drift_value() -> float:
	return _drift


## To samo ze znakiem strony: dodatnie w prawo. Do podpięcia rzeczy, które
## mają się przekręcać razem z torem jazdy — na przykład kierownicy.
func drift_signed() -> float:
	return _drift if drift_right else -_drift


func _apply_shift() -> void:
	# Tir jedzie w prawo, więc droga ucieka w lewo — stąd minus.
	var shift := -signf(drift_signed()) * _drift * max_shift_pixels
	for index in _roads.size():
		_roads[index].position.x = _road_home[index].x + shift
	for index in _backgrounds.size():
		_backgrounds[index].position.x = _background_home[index].x + shift * background_factor


func _crash() -> void:
	_crashed = true
	if debug_log:
		print("[zjazd] wypadnięcie z drogi")
	if _score_source != null and _score_source.has_method(&"GameOver"):
		_score_source.call(&"GameOver")
