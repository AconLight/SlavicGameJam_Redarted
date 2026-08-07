extends Node

signal speed_changed(speed: float)

enum State {
	NORMAL,
	ACCELERATING,
	HEAVY_FOOT,
	BRAKING
}


var state = State.NORMAL

var speed: float = 80.0
var previous_speed: float = 80.0


const NORMAL_MIN := 75.0
const NORMAL_MAX := 85.0

const HEAVY_MIN := 115.0
const HEAVY_MAX := 125.0

const OSCILLATION_STEP := 1.0
const OSCILLATION_TIME := 0.5

const BRAKE_RATE := 25.0
const ACCEL_RATE := 2.0


var direction := 1
var timer := 0.0


# NEW: Brake sound
var brake_sound: AudioStreamPlayer


func _ready():

	randomize()
	direction = [-1, 1].pick_random()


	# NEW: Create brake audio player
	brake_sound = AudioStreamPlayer.new()
	add_child(brake_sound)

	brake_sound.stream = load("res://car brake.mp3")


	speed_changed.connect(_on_speed_changed)


	print("=== Controls ===")
	print("SPACE = HeavyFoot")
	print("ESC = HittinBrakes")
	print("================")



func _process(delta):

	match state:

		State.NORMAL:
			timer += delta

			if timer >= OSCILLATION_TIME:
				timer = 0.0
				_update_oscillation(NORMAL_MIN, NORMAL_MAX)



		State.ACCELERATING:

			speed += ACCEL_RATE * delta

			if speed >= HEAVY_MIN:
				speed = HEAVY_MIN
				state = State.HEAVY_FOOT
				timer = 0.0
				direction = [-1, 1].pick_random()
				print("Reached HeavyFoot speed.")



		State.HEAVY_FOOT:

			timer += delta

			if timer >= OSCILLATION_TIME:
				timer = 0.0
				_update_oscillation(HEAVY_MIN, HEAVY_MAX)



		State.BRAKING:

			speed -= BRAKE_RATE * delta

			if speed <= NORMAL_MAX:
				speed = clamp(speed, NORMAL_MIN, NORMAL_MAX)
				state = State.NORMAL
				timer = 0.0
				direction = [-1, 1].pick_random()
				print("Returned to cruising speed.")



	if not is_equal_approx(speed, previous_speed):
		previous_speed = speed
		emit_signal("speed_changed", speed)




func _update_oscillation(min_speed: float, max_speed: float):

	if speed >= max_speed:
		direction = -1

	elif speed <= min_speed:
		direction = 1

	elif randf() < 0.3:
		direction *= -1


	speed += OSCILLATION_STEP * direction
	speed = clamp(speed, min_speed, max_speed)




func HeavyFoot():

	if state == State.ACCELERATING or state == State.HEAVY_FOOT:
		return


	print("HeavyFoot triggered!")

	state = State.ACCELERATING
	timer = 0.0




func HittinBrakes():

	if state == State.BRAKING:
		return


	print("HittinBrakes triggered!")


	# NEW: Play brake sound only above 100 km/h
	if speed > 100.0:
		if brake_sound:
			brake_sound.play()


	state = State.BRAKING
	timer = 0.0




func _input(event):

	if event.is_action_pressed("ui_accept"):
		HeavyFoot()


	if event.is_action_pressed("ui_cancel"):
		HittinBrakes()




func _on_speed_changed(current_speed: float):

	print("Speed: %.1f km/h" % current_speed)
