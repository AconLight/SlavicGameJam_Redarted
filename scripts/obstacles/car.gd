extends Sprite2D

func _ready():
	# Call this function whenever you want the animation to start
	play_animation_sequence()

func play_animation_sequence():
	var tween = create_tween()
	
	# ---------------------------------------------------------
	# STEP 1: Move on a curve and change size
	# ---------------------------------------------------------
	var target_location = Vector2(940, 500)
	var move_time = 5.0
	
	# TRICK FOR CURVES: Animate X and Y independently with different easing.
	# Linear X combined with a Sine Y creates a nice, sweeping arc.
	tween.tween_property(self, "position:x", target_location.x, move_time).set_trans(Tween.TRANS_LINEAR)
	tween.parallel().tween_property(self, "position:y", target_location.y, move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Change scale at the exact same time using .parallel()
	tween.parallel().tween_property(self, "scale", Vector2(0.4, 0.4), move_time)
	
	# ---------------------------------------------------------
	# STEP 2: Stop (Wait)
	# ---------------------------------------------------------
	tween.tween_interval(0.5) # Pauses the sequence for half a second
	
	# ---------------------------------------------------------
	# STEP 3: Wiggle
	# ---------------------------------------------------------
	var wiggle_speed = 1
	# A simple loop to quickly rotate left and right
	for i in range(4):
		tween.tween_property(self, "rotation_degrees", 2.0, wiggle_speed)
		tween.tween_property(self, "rotation_degrees", -2.0, wiggle_speed)
	
	# Return to normal upright rotation
	tween.tween_property(self, "rotation_degrees", 0.0, wiggle_speed)
	
	# ---------------------------------------------------------
	# STEP 4: Slowly move up and reduce size
	# ---------------------------------------------------------
	var up_location = target_location + Vector2(0, -200) # 200 pixels straight up
	var shrink_time = 1.5
	
	tween.tween_property(self, "position", up_location, shrink_time)
	tween.parallel().tween_property(self, "scale", Vector2(0.1, 0.1), shrink_time)
	
	# ---------------------------------------------------------
	# STEP 5: Teleport
	# ---------------------------------------------------------
	var new_teleport_location = Vector2(-1000, -1000)
	
	# A tween with a time of 0.0 is an instant teleport!
	tween.tween_property(self, "position", new_teleport_location, 0.0)
	
	# We also pop the scale back to normal instantly so you can see it again
	tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.0)
