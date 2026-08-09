extends Sprite2D
@export var car_textures: Array[Texture2D] = []
var keep_score
var active = false
func _ready():
	keep_score = get_tree().get_first_node_in_group("keep_score")
	call_deferred("_connect_signalist")
	# Pick the starting skin now, while the car is sitting off-screen
	# at its initial placed position.
	_pick_random_texture()
func _connect_signalist() -> void:
	var signalist = get_tree().get_first_node_in_group(&"game_state_signalist")
	if signalist:
		signalist.car_break_check.connect(play_animation_sequence)
func _update_active_from_chill():
	if keep_score:
		# Update 'active' to match 'chill_active' in real time
		active = keep_score.chill_active
		print(active)
func _pick_random_texture() -> void:
	if car_textures.size() > 0:
		texture = car_textures.pick_random()
func play_animation_sequence():
	var tween = create_tween()
# ------------------------- --------------------------------
# STEP 1: Move on a curve and change size
# ---------------------------------------------------------
	var target_location = Vector2(1000, 500)
	var move_time = 5.0
	tween.tween_property(self, "position:x", target_location.x, move_time).set_trans(Tween.TRANS_LINEAR)
	tween.parallel().tween_property(self, "position:y", target_location.y, move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2(0.4, 0.4), move_time)
	await tween.finished
	print("krowa")
# ---------------------------------------------------------
# STEP 2: Stop (Wait)
# ---------------------------------------------------------
# ---------------------------------------------------------
# STEP 3: Wiggle
# ---------------------------------------------------------
	var wiggle_speed = 1.0
	var wait_cycles = randi_range(4, 9)
	var will_brake_check: bool = [true, false].pick_random()
	var backup_count = 0
	var shrink_time1 = 1.0
	for i in range(wait_cycles):
		print(i)
		tween = create_tween()
		tween.tween_property(self, "rotation_degrees", 2.0, wiggle_speed)
		tween.tween_property(self, "rotation_degrees", -2.0, wiggle_speed)
		await tween.finished
		if will_brake_check:
			print("will_brake_check")
			tween = create_tween()
			tween.tween_callback(_update_active_from_chill)
			await tween.finished
			if not active:
				if backup_count >= 3:
					var signalist = get_tree().get_first_node_in_group(&"game_state_signalist")
					signalist._on_car_break_checked()
					break
			else:
				var up_location1 = target_location + Vector2(0, 50)
				tween = create_tween()
				tween.tween_property(self, "position", up_location1, shrink_time1)
				tween.parallel().tween_property(self, "scale", Vector2(1, 1), shrink_time1)
				await tween.finished
				target_location = target_location + Vector2(0, 50)
				backup_count += 1
				shrink_time1 = shrink_time1 + 0.05
				if backup_count >= 3:
					var signalist = get_tree().get_first_node_in_group(&"game_state_signalist")
					signalist._on_car_break_checked()
					break
	if not target_location >= Vector2(1000, 650):
		tween = create_tween()
		tween.tween_property(self, "rotation_degrees", 0.0, wiggle_speed)
		await tween.finished
# ---------------------------------------------------------
# STEP 4: Slowly move up and reduce size
# ---------------------------------------------------------
	target_location = Vector2(950, 650)
	var up_location2 = target_location + Vector2(0, -200)
	var shrink_time2 = 1.5
	tween = create_tween()
	tween.tween_property(self, "position", up_location2, shrink_time2)
	tween.parallel().tween_property(self, "scale", Vector2(0.1, 0.1), shrink_time2)
	await tween.finished
# ---------------------------------------------------------
# STEP 5: Teleport
# ---------------------------------------------------------
	var new_teleport_location = Vector2(-300, 1600)
	tween = create_tween()
	tween.tween_property(self, "position", new_teleport_location, 0.0)
	tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.0)
	await tween.finished

	# Now that the car is safely off-screen (just teleported away),
	# pick the texture it'll wear on its NEXT appearance.
	_pick_random_texture()
