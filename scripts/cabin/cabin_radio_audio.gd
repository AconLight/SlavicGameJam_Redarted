extends Node

## Dźwięk radia, spięty z aktywnością kabiny.
##
## Przebieg:
##   start   → urywa muzykę i DJ-a, puszcza strojenie w pętli,
##             czasem odzywa się kierowca
##   koniec  → urywa strojenie, puszcza losowego DJ-a
##   DJ koniec → leci muzyka, raz, bez pętli
##
## Kolejność DJ → muzyka opiera się na sygnale finished odtwarzacza DJ-a.
## Godot nie wysyła finished po stop(), więc urwanie DJ-a przy ponownym
## rozpoczęciu aktywności nie odpali muzyki w tle strojenia.

@export_node_path("Node") var controller_path: NodePath

## Której aktywności dotyczy ten zestaw dźwięków.
@export var activity_id: StringName = &"radio"

## Szum strojenia. Musi mieć włączoną pętlę w ustawieniach importu.
@export var tuning_stream: AudioStream

## Wejścia DJ-a. Losowane przy każdym zakończeniu aktywności.
@export var dj_streams: Array[AudioStream] = []

## Utwór lecący po DJ-u, raz.
@export var music_stream: AudioStream

## Komentarz kierowcy przy włączaniu radia.
@export var driver_line_stream: AudioStream

## Szansa, że kierowca się odezwie przy włączeniu radia. 1.0 = zawsze.
@export_range(0.0, 1.0, 0.05) var driver_line_chance := 0.6

@export var debug_log := true

@onready var _tuning: AudioStreamPlayer = $Tuning
@onready var _dj: AudioStreamPlayer = $Dj
@onready var _music: AudioStreamPlayer = $Music
@onready var _voice: AudioStreamPlayer = $Voice

var _tuning_looping := false


func _ready() -> void:
	_tuning.stream = tuning_stream
	_music.stream = music_stream
	_voice.stream = driver_line_stream
	_dj.finished.connect(_on_dj_finished)
	_tuning.finished.connect(_on_tuning_finished)

	var controller := get_node_or_null(controller_path) as CabinActivityController
	if controller == null:
		return
	controller.activity_started.connect(_on_activity_started)
	controller.activity_ended.connect(_on_activity_ended)


func _on_activity_started(started_id: StringName) -> void:
	if started_id != activity_id:
		return

	_music.stop()
	_dj.stop()

	if _tuning.stream != null:
		_tuning_looping = true
		_tuning.play()

	if _voice.stream != null and randf() < driver_line_chance:
		_voice.play()
		if debug_log:
			print("[audio] kierowca o radiu")

	if debug_log:
		print("[audio] strojenie start")


func _on_activity_ended(ended_id: StringName, _held_seconds: float) -> void:
	if ended_id != activity_id:
		return

	_tuning_looping = false
	_tuning.stop()
	if dj_streams.is_empty():
		return

	_dj.stream = dj_streams.pick_random()
	_dj.play()
	if debug_log:
		print("[audio] DJ: ", _dj.stream.resource_path.get_file())


## Ponowne puszczenie szumu, gdy próbka dobiegła końca. Nie polegamy na
## pętli z ustawień importu — ta zależy od trybu kompresji i cicho nie
## działa. Godot nie wysyła finished po stop(), więc urwanie aktywności
## nie odpali szumu jeszcze raz.
func _on_tuning_finished() -> void:
	if _tuning_looping:
		_tuning.play()


func _on_dj_finished() -> void:
	if _music.stream == null:
		return
	_music.play()
	if debug_log:
		print("[audio] muzyka")
