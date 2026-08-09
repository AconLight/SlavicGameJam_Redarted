extends CanvasLayer

## Koniec gry: chill spadł do zera.
##
## Obraz i dźwięk gasną, a dopiero potem wchodzi ekran z wynikiem. Ściemnianie
## musi być tutaj, w scenie rozgrywki, bo ma przykryć kabinę — na ekranie
## wyniku nie ma już czego przykrywać.
##
## Warstwa jest wysoko, żeby czerń szła po wszystkim: kabina, HUD i droga
## mają własne CanvasLayery.

@export_file("*.tscn") var result_scene := "res://scenes/start_screen_consequent.tscn"

## Ile trwa gaśnięcie obrazu i dźwięku, zanim wejdzie ekran z wynikiem.
@export_range(0.0, 10.0, 0.1) var fade_seconds := 1.6

@onready var _fade: ColorRect = $Fade

var _master_bus := 0
var _master_bus_db := 0.0
var _finished := false


func _ready() -> void:
	_fade.color.a = 0.0
	_master_bus = AudioServer.get_bus_index("Master")
	_master_bus_db = AudioServer.get_bus_volume_db(_master_bus)

	# Licznik chillu siedzi w score.tscn, więc nie ma do niego stałej ścieżki
	# z tego miejsca — grupa jest jedynym pewnym uchwytem.
	var keeper := get_tree().get_first_node_in_group(&"keep_score")
	if keeper == null or not keeper.has_signal(&"game_over"):
		push_warning("[game over] brak licznika chillu — koniec gry nie zadziała")
		return
	keeper.connect(&"game_over", _on_game_over)


func _on_game_over(final_score: int) -> void:
	if _finished:
		return
	_finished = true
	Leaderboard.last_score = final_score

	if fade_seconds <= 0.0:
		_show_result()
		return

	var fade := create_tween().set_parallel(true)
	fade.tween_property(_fade, ^"color:a", 1.0, fade_seconds)
	# Dźwięk gaszony hurtem przez szynę główną. W kabinie grają radio, CB,
	# silnik i ukulele z osobnych odtwarzaczy, każdy z własnym wyciszaniem —
	# uciszanie ich po kolei rozjechałoby się z obrazem.
	fade.tween_method(_set_master_db, _master_bus_db, -60.0, fade_seconds)
	fade.finished.connect(_show_result)


func _set_master_db(value: float) -> void:
	AudioServer.set_bus_volume_db(_master_bus, value)


func _show_result() -> void:
	# Szyna wraca na swoje, bo przeżywa zmianę scen — bez tego ekran wyniku
	# i następny przejazd byłyby głuche.
	_set_master_db(_master_bus_db)
	get_tree().change_scene_to_file(result_scene)
