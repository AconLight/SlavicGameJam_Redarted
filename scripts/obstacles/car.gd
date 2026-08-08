extends Sprite2D

var keep_score
var active: bool = false

# Where the car should ENTER from the side.
const START_POSITION: Vector2 = Vector2(-300, 1600)

# Where the car stops after entering.
const APPROACH_POSITION: Vector2 = Vector2(1000, 500)

# How far the car backs up each time.
const BACKUP_DISTANCE: float = 50.0

# Maximum number of times it can back up.
const MAX_BACKUPS: int = 3

# Where the car goes when leaving.
const DRIVE_AWAY_POSITION: Vector2 = Vector2(950, 450)

# Where the car is hidden after finishing.
const TELEPORT_POSITION: Vector2 = Vector2(-1000, -1000)


func _ready() -> void:
	keep_score = get_tree().get_first_node_in_group(&"keep_score")

	# Make absolutely sure the car starts from the side.
	position = START_POSITION
	scale = Vector2.ONE
	rotation_degrees = 0.0

	call_deferred("_connect_signalist")


func _connect_signalist() -> void:
	var signalist: GameStateSignalist = get_tree().get_first_node_in_group(
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

	# Always start from the side.
	position = START_POSITION
	scale = Vector2.ONE
	rotation_degrees = 0.0

	# 1. Drive/fly in from the side.
	await approach()

	# 1b. Wiggle a bit before deciding anything.
	await wiggle_once()

	# 2. Randomly decide whether this car performs a brake check.
	var should_check_brakes: bool = [true, false].pick_random()

	if should_check_brakes:
		await brake_check_sequence()

	# 3. Leave the scene.
	await drive_away()

	# 4. Hide/reset the car.
	teleport()


# ============================================================
# STEP 1 - ENTER FROM SIDE
# ============================================================

func approach() -> void:
	var tween: Tween = create_tween()

	# Move horizontally from the side.
	tween.tween_property(
		self,
		"position:x",
		APPROACH_POSITION.x,
		5.0
	).set_trans(Tween.TRANS_LINEAR)

	# Move vertically slightly to create the curved entrance.
	tween.parallel().tween_property(
		self,
		"position:y",
		APPROACH_POSITION.y,
		5.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Become smaller as it approaches.
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
	var backup_count: int = 0

	# The car will wiggle a random number of times before it gives up
	# and just drives off.
	var wait_cycles: int = randi_range(4, 9)

	for i in range(wait_cycles):

		print("Wiggle ", i + 1, "/", wait_cycles)

		# -------------------------
		# WIGGLE
		# -------------------------
		await wiggle_once()

		# -------------------------
		# CHECK BRAKING
		# -------------------------
		update_active_from_chill()

		print("active = ", active)

		# -------------------------
		# PLAYER IS BRAKING -> BACK UP
		# -------------------------
		if active:

			backup_count += 1

			print(
				"Player is braking. Backing up #",
				backup_count
			)

			await back_up(backup_count)

			# Backed up 3 times: the brake check landed. Report it
			# and stop wiggling/backing up (the car will drive away
			# afterwards, back in play_animation_sequence).
			if backup_count >= MAX_BACKUPS:
				print("Maximum backups reached. Reporting brake check.")
				report_brake_check()
				return

		# -------------------------
		# PLAYER IS NOT BRAKING -> KEEP WIGGLING
		# -------------------------
		else:
			print("Player not braking, wiggling again.")

	# Ran out of wiggle cycles without ever hitting 3 backups.
	# The car just gives up and runs away.
	print("Ran out of wiggles. Running away.")


# ============================================================
# WIGGLE
# ============================================================

func wiggle_once() -> void:
	var tween: Tween = create_tween()

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

	# Use the CURRENT real position of the Sprite.
	var target_position: Vector2 = position + Vector2(
		0,
		BACKUP_DISTANCE
	)

	# Each backup can become slightly slower.
	var duration: float = 1.0 + (backup_count - 1) * 0.05

	var tween: Tween = create_tween()

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
# READ PLAYER BRAKING STATE
# ============================================================

func update_active_from_chill() -> void:

	if keep_score == null:
		active = false
		return

	active = keep_score.chill_active

	print("chill_active = ", active)


# ============================================================
# BRAKE CHECK SUCCESS
# ============================================================

func report_brake_check() -> void:

	var signalist: GameStateSignalist = get_tree().get_first_node_in_group(
		&"game_state_signalist"
	) as GameStateSignalist

	if signalist:
		signalist._on_car_break_checked()


# ============================================================
# STEP 3 - DRIVE AWAY
# ============================================================

func drive_away() -> void:

	# Move upward from the current position.
	var target_position: Vector2 = DRIVE_AWAY_POSITION

	var tween: Tween = create_tween()

	# Straighten the car.
	tween.tween_property(
		self,
		"rotation_degrees",
		0.0,
		1.0
	)

	# Move away.
	tween.parallel().tween_property(
		self,
		"position",
		target_position,
		1.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Shrink away.
	tween.parallel().tween_property(
		self,
		"scale",
		Vector2(0.1, 0.1),
		1.5
	)

	await tween.finished


# ============================================================
# STEP 4 - TELEPORT / RESET
# ============================================================

func teleport() -> void:

	position = TELEPORT_POSITION
	scale = Vector2.ONE
	rotation_degrees = 0.0
