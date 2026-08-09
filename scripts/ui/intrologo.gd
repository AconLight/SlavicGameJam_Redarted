extends Sprite2D

func _ready() -> void:
	# Make sure it starts fully visible.
	modulate.a = 1.0

	# Stay fully visible for 7 seconds.
	await get_tree().create_timer(7.0).timeout

	# Fade out over 1.5 seconds.
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.5)
	await tween.finished

	print("intro logo finished")
	visible = false

	# If this logo screen should then move on to your actual game/menu,
	# uncomment and point at the right scene:
	# get_tree().change_scene_to_file("res://scenes/main.tscn")
