
extends Sprite2D

var keep_score
var active := false

const APPROACH_POSITION := Vector2(1000, 500)
const BACKUP_DISTANCE := 50.0
const MAX_BACKUPS := 3

const DRIVE_AWAY_POSITION := Vector2(950, 650)
const TELEPORT_POSITION := Vector2(-1000, -1000)


func _ready() -> void:
	keep_score = get_tree().get_first_node_in_group(&"keep_score")
	call_deferred("_connect_signalist")


func _connect_signalist() -> void:
	var signalist := get_tree().get_first_node_in_group(
		&"game_state_signalist"
	) as GameStateSignalist

	if signalist == null:
		push_warning("Car could not find GameStateSignalist.")
		return

	if not signalist.car_break_check.is_connected(play_animation_sequence):
		signalist.car_break_check.connect(play_animation_sequence)


# ============================================================
# MAIN SEQUENCE
# ============================================================

func play_animation_sequence() -> void:
	await approach()

	var should_check_brakes: bool = [true, false].pick_random()

	if should_check_brakes:
		await brake_check_sequence()

	await drive_away()

	teleport()


# ============================================================
# STEP 1 - APPROACH
# ============================================================

func approach() -> void:
	var tween := create_tween()

	tween.tween_property(
		self,
		"position:x",
		APPROACH_POSITION.x,
		5.0
	).set_trans(Tween.TRANS_LINEAR)

	tween.parallel().tween_property(
		self,
		"position:y",
		APPROACH_POSITION.y,
		5.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(
		self,
		"scale",
		Vector2(0.4, 0.4),
		5.0
	)

	await tween.finished


# ============================================================
# STEP 2 - BRAKE CHECK
# ============================================================

func brake_check_sequence() -> void:
	var backup_count := 0

	# Random amount of time before the brake check starts.
	var wait_cycles := randi_range(4, 9)

	for i in range(wait_cycles):
		await wiggle_once()

	# Now actually perform the brake check.
	while backup_count < MAX_BACKUPS:

		update_active_from_chill()

		print("Brake check. active = ", active)

		if not active:
			# Player is not braking.
			# Brake check is considered complete.
			report_brake_check()
			return

		# Player is braking.
		# Back up another 50 pixels.
		backup_count += 1

		print("Backing up: ", backup_count, "/", MAX_BACKUPS)

		await back_up(backup_count)

	print("Maximum backups reached.")


# ============================================================
# WIGGLE
# ============================================================

func wiggle_once() -> void:
	var tween := create_tween()

	tween.tween_property(
		self,
		"rotation_degrees",
		2.0,
		1.0
	)

	tween.tween_property(
		self,
		"rotation_degrees",
		-2.0,
		1.0
	)

	await tween.finished


# ============================================================
# BACK UP
# ============================================================

func back_up(backup_count: int) -> void:
	var target_position := position + Vector2(0, BACKUP_DISTANCE)

	var duration := 1.0 + (backup_count - 1) * 0.05

	var tween := create_tween()

	tween.tween_property(
		self,
		"position",
		target_position,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(
		self,
		"scale",
		Vector2(1.2, 1.2),
		duration
	)

	await tween.finished


# ============================================================
# READ PLAYER STATE
# ============================================================

func update_active_from_chill() -> void:
	if keep_score == null:
		active = false
		return

	active = keep_score.chill_active

	print("chill_active = ", active)


# ============================================================
# REPORT SUCCESSFUL BRAKE CHECK
# ============================================================

func report_brake_check() -> void:
	var signalist := get_tree().get_first_node_in_group(
		&"game_state_signalist"
	) as GameStateSignalist

	if signalist:
		signalist._on_car_break_checked()


# ============================================================
# STEP 4 - DRIVE AWAY
# ============================================================

func drive_away() -> void:
	var target_position := DRIVE_AWAY_POSITION + Vector2(0, -200)

	# Reset rotation first.
	var tween := create_tween()

	tween.tween_property(
		self,
		"rotation_degrees",
		0.0,
		1.0
	)

	tween.parallel().tween_property(
		self,
		"position",
		target_position,
		1.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.parallel().tween_property(
		self,
		"scale",
		Vector2(0.1, 0.1),
		1.5
	)

	await tween.finished


# ============================================================
# STEP 5 - TELEPORT
# ============================================================

func teleport() -> void:
	position = TELEPORT_POSITION
	scale = Vector2.ONE
	rotation_degrees = 0.0
