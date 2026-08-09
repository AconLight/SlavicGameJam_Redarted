extends Sprite2D

func _ready() -> void:
	modulate.a = 1.0

	# Wait up to 7 seconds, but stop early if the mouse is clicked.
	var elapsed := 0.0
	while elapsed < 7.0:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			modulate.a = 0.0
			visible = false
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	# 7 seconds passed with no click: do the normal fade.
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.5)
	await tween.finished
	visible = false

	# get_tree().change_scene_to_file("res://scenes/main.tscn")
