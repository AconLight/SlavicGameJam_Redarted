extends Node

## Prosty dźwięk aktywności: losowy z jednej listy na start, losowy
## z drugiej na koniec. Bez pętli i bez kolejek — do rzeczy, które
## zaczynają się i kończą, jak granie na ukulele i jego odstawienie.
##
## Losowanie idzie z worka nieodegranych, więc ta sama próbka nie leci
## dwa razy pod rząd.

@export_node_path("Node") var controller_path: NodePath

## Której aktywności dotyczy.
@export var activity_id: StringName = &""

## Dźwięki na rozpoczęcie. Losowany jeden.
@export var start_streams: Array[AudioStream] = []

## Dźwięki na zakończenie. Losowany jeden.
@export var end_streams: Array[AudioStream] = []

## Czy urwać dźwięk startowy w chwili zakończenia aktywności.
@export var cut_start_on_end := true

@export var debug_log := true

@onready var _start_player: AudioStreamPlayer = $Start
@onready var _end_player: AudioStreamPlayer = $End

var _start_bag: Array[AudioStream] = []
var _end_bag: Array[AudioStream] = []


func _ready() -> void:
	var controller := get_node_or_null(controller_path) as CabinActivityController
	if controller == null:
		return
	controller.activity_started.connect(_on_activity_started)
	controller.activity_ended.connect(_on_activity_ended)


func _on_activity_started(started_id: StringName) -> void:
	if started_id != activity_id:
		return
	_end_player.stop()
	_play(_start_player, _draw(start_streams, _start_bag))


func _on_activity_ended(ended_id: StringName, _held_seconds: float) -> void:
	if ended_id != activity_id:
		return
	if cut_start_on_end:
		_start_player.stop()
	_play(_end_player, _draw(end_streams, _end_bag))


func _play(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if stream == null:
		return
	player.stream = stream
	player.play()
	if debug_log:
		print("[audio] ", activity_id, ": ", stream.resource_path.get_file())


func _draw(streams: Array[AudioStream], bag: Array[AudioStream]) -> AudioStream:
	if streams.is_empty():
		return null
	if bag.is_empty():
		bag.assign(streams)
		bag.shuffle()
	return bag.pop_back()
