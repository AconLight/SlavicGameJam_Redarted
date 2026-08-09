extends Label

@export var chill_penalty: int = 50

## Stuknięcie przy brake checku. Wymaga węzła AudioStreamPlayer o nazwie Crash.
## Fotoradar go nie odpala — tam gra już błysk migawki.
@export var crash_stream: AudioStream

@export_range(-40.0, 24.0, 0.1) var crash_volume_db: float = 0.0

var crash_player: AudioStreamPlayer

func _ready():
	# 1. Hide the text by default by setting its alpha (opacity) to 0
	modulate.a = 0.0
	call_deferred("_connect_signalist")

	crash_player = get_node_or_null(^"Crash") as AudioStreamPlayer
	if crash_player:
		crash_player.stream = crash_stream
		crash_player.volume_db = crash_volume_db
	


func _connect_signalist() -> void:
	# Score is created before GameStateSignalist in main.tscn, so this must be
	# deferred until the signalist has joined its group.
	var signalist := get_tree().get_first_node_in_group(&"game_state_signalist") as GameStateSignalist
	if signalist == null:
		push_warning("Notifications could not find GameStateSignalist.")
		return
	if not signalist.speed_camera_photo_taken.is_connected(_on_photo_taken):
		signalist.speed_camera_photo_taken.connect(_on_photo_taken)
	if not signalist.car_break_checked.is_connected(_on_car_break_checked):
		signalist.car_break_checked.connect(_on_car_break_checked)
		


func _on_photo_taken(_camera_id: StringName, speed_kmh: float, speed_limit_kmh: float):
	# Format the text to show the penalty and the speeds
	text = "-%d CHILL!\nSpeeding!" % [chill_penalty]
	
	var keep_score = get_tree().get_first_node_in_group("keep_score")
	if keep_score: keep_score.AddChill(-chill_penalty)

	play_flash_animation()
	
func _on_car_break_checked():
	# Format the text to show the penalty and the speeds
	text = "-%d CHILL!\nBreak Check!" % [chill_penalty]

	var keep_score = get_tree().get_first_node_in_group("keep_score")
	if keep_score: keep_score.AddChill(-chill_penalty)

	if crash_player and crash_player.stream: crash_player.play()

	play_flash_animation()

func play_flash_animation():
	# create_tween() automatically stops any previous tweens on this node, 
	# preventing glitches if the player hits two cameras back-to-back.
	var tween = create_tween()
	
	# We want it to blink on and off 3 times
	tween.set_loops(5)

	# Step A: Fade in instantly to full opacity (1.0) over 0.1 seconds
	tween.tween_property(self, "modulate:a", 1.0, 0.1) 
	
	# Step B: Hold it on screen for 0.15 seconds
	tween.tween_interval(0.65)                         
	
	# Step C: Fade out to invisible (0.0) over 0.1 seconds
	tween.tween_property(self, "modulate:a", 0.0, 0.1) 
	
	# Step D: Brief pause before the loop starts again
	tween.tween_interval(0.05)
