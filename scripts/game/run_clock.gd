extends Node

## Zegar trasy. Przejazd trwa tyle samo za każdym razem i kończy się sam.
##
## To on kończy grę, a nie chill: chill leżący na zerze zabiera tylko mnożnik.
## Drugim sposobem zakończenia jest wypadnięcie z drogi (cabin_drift.gd), które
## woła to samo GameOver() — koniec zawsze idzie jedną drogą, więc wynik trafia
## na listę i ekran gaśnie zawsze tak samo.
##
## Postęp trasy wystawiamy jako progress() od 0 do 1, żeby pasek postępu miał
## co pokazywać i nie musiał liczyć czasu drugi raz u siebie.

signal run_finished()

## Ile trwa przejazd.
@export_range(10.0, 1800.0, 5.0) var run_seconds := 300.0

## Węzeł z metodą GameOver() — w grze KeepScore ze sceny score.
@export_node_path("Node") var score_source_path: NodePath

## Co ile sekund wypisać postęp do konsoli. 0 wyłącza.
@export_range(0.0, 120.0, 1.0) var log_every_seconds := 30.0

var _score_source: Node
var _elapsed := 0.0
var _finished := false
var _next_log := 0.0


func _ready() -> void:
	_score_source = get_node_or_null(score_source_path)
	if _score_source == null or not _score_source.has_method(&"GameOver"):
		push_warning("[trasa] brak licznika z GameOver() — przejazd nie skończy się sam")
	_next_log = log_every_seconds


func _process(delta: float) -> void:
	if _finished:
		return

	_elapsed += delta

	if log_every_seconds > 0.0 and _elapsed >= _next_log:
		_next_log += log_every_seconds
		print("[trasa] %.0f z %.0f s (%.0f%%)" % [_elapsed, run_seconds, progress() * 100.0])

	if _elapsed >= run_seconds:
		_finish()


## Ile trasy za nami, od 0 do 1. Tym karmi się pasek postępu.
func progress() -> float:
	if run_seconds <= 0.0:
		return 1.0
	return clampf(_elapsed / run_seconds, 0.0, 1.0)


func seconds_left() -> float:
	return maxf(run_seconds - _elapsed, 0.0)


func _finish() -> void:
	_finished = true
	print("[trasa] koniec trasy")
	run_finished.emit()
	if _score_source != null and _score_source.has_method(&"GameOver"):
		_score_source.call(&"GameOver")
