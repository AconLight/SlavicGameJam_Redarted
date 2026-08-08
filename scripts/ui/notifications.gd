extends Label

@export var chill_penalty: int = 15

func _ready():
	# 1. Hide the text by default by setting its alpha (opacity) to 0
	modulate.a = 0.0
	call_deferred("_connect_signalist")


func _connect_signalist() -> void:
	# Score is created before GameStateSignalist in main.tscn, so this must be
	# deferred until the signalist has joined its group.
	var signalist := get_tree().get_first_node_in_group(&"game_state_signalist") as GameStateSignalist
	if signalist == null:
		push_warning("Notifications could not find GameStateSignalist.")
		return
	if not signalist.speed_camera_photo_taken.is_connected(_on_photo_taken):
		signalist.speed_camera_photo_taken.connect(_on_photo_taken)


func _on_photo_taken(_camera_id: StringName, speed_kmh: float, speed_limit_kmh: float):
	# Format the text to show the penalty and the speeds
	text = "-%d CHILL!\nSpeeding: %d / %d" % [chill_penalty, speed_kmh, speed_limit_kmh]
	
	var keep_score = get_tree().get_first_node_in_group("keep_score")
	if keep_score: keep_score.AddChill(-chill_penalty)

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
	tween.tween_interval(0.35)                         
	
	# Step C: Fade out to invisible (0.0) over 0.1 seconds
	tween.tween_property(self, "modulate:a", 0.0, 0.1) 
	
	# Step D: Brief pause before the loop starts again
	tween.tween_interval(0.05)
