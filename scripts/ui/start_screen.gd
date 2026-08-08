extends Control

## Ekran startowy: lista najlepszych wyników i przycisk startu.
##
## Po naciśnięciu startu odpala się dźwięk przekręcania kluczyka, a gra
## wchodzi po krótkiej chwili. Nie czekamy na koniec próbki, bo ma ona
## dziewięć sekund — gracz siedziałby i patrzył w przycisk. W kabinie i tak
## czeka pętla pracującego silnika, więc przejście brzmi naturalnie.

@export_file("*.tscn") var game_scene := "res://scenes/main.tscn"

## Ile trwa odpalanie, zanim wejdzie gra. Tyle samo trwa ściemnianie —
## ekran gaśnie dokładnie na moment wejścia rozgrywki.
@export_range(0.0, 10.0, 0.1) var start_delay_seconds := 2.0

@onready var _scores: Label = $Panel/Scores
@onready var _start_button: Button = $Panel/StartButton
@onready var _key_start: AudioStreamPlayer = $KeyStart
@onready var _fade: ColorRect = $Fade
@onready var _music: AudioStreamPlayer = $AudioStreamPlayer


func _ready() -> void:
	_show_scores()
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.grab_focus()


func _show_scores() -> void:
	var scores := Leaderboard.load_scores()
	if scores.is_empty():
		_scores.text = "jeszcze nikt nie jechał"
		return

	var lines := PackedStringArray()
	for index in scores.size():
		lines.append("%2d.   %d" % [index + 1, scores[index]])
	_scores.text = "\n".join(lines)


func _on_start_pressed() -> void:
	# Blokada, żeby dwa kliknięcia nie odpaliły dwóch przejść scen.
	_start_button.disabled = true

	if _key_start.stream != null:
		_key_start.play()

	if start_delay_seconds <= 0.0:
		_start_game()
		return

	# Ściemnianie zastępuje zwykły odmierzacz czasu: koniec przejścia jest
	# jednocześnie końcem oczekiwania, więc obraz nie mruga jasnym ekranem
	# ułamek sekundy przed wejściem rozgrywki.
	var fade := create_tween().set_parallel(true)
	fade.tween_property(_fade, ^"color:a", 1.0, start_delay_seconds)
	# Muzyka gaśnie razem z obrazem. -60 dB to praktyczna cisza; zjeżdżanie
	# do -80 słychać jako nagłe urwanie pod koniec, bo w decybelach ostatnie
	# dwadzieścia to już nic.
	if _music != null:
		fade.tween_property(_music, ^"volume_db", -60.0, start_delay_seconds)
	if _key_start.stream != null:
		fade.tween_property(_key_start, ^"volume_db", -60.0, start_delay_seconds)
	fade.finished.connect(_start_game)


func _start_game() -> void:
	get_tree().change_scene_to_file(game_scene)
