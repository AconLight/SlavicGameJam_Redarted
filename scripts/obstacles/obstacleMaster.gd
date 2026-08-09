extends Node

# Define the types of obstacles using an enum for easy reading
enum ObstacleType {
	SPEED_CAMERA,
	SIDE_VEHICLE,
	SPEED_INCREASE,
	FALL_OUT
}

var signalist = null
var spawn_timer: Timer
var is_obstacle_active: bool = false

# The maximum gap between obstacles is 8 seconds.
# You can adjust the minimum delay to whatever feels fair.
const MIN_DELAY: float = 2.0
const MAX_DELAY: float = 5.0

# How often each obstacle gets drawn, relative to the others. The side vehicle
# is the one the player actually reacts to, so it gets picked most.
#
# FALL_OUT is not in the table on purpose: its trigger is commented out, so it
# used to burn 18 seconds of the one-at-a-time lock doing nothing at all. With
# four equal draws that swallowed a quarter of the run and made the car show up
# roughly once a minute.
const OBSTACLE_WEIGHTS := {
	ObstacleType.SIDE_VEHICLE: 3,
	ObstacleType.SPEED_CAMERA: 2,
	ObstacleType.SPEED_INCREASE: 1,
}

func _ready():
	signalist = get_tree().get_first_node_in_group(&"game_state_signalist")
	
	# randomize() ensures the random number generator is seeded differently every time you play
	randomize() 

	# Setup the timer that handles the gap between obstacles
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true # We will manually restart it with a new random time
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	
	# Start the very first countdown
	start_next_obstacle_timer()

func start_next_obstacle_timer():
	# Pick a random wait time between 2 and 8 seconds
	var wait_time = randf_range(MIN_DELAY, MAX_DELAY)
	spawn_timer.start(wait_time)

func _on_spawn_timer_timeout():
	# Double check to prevent overlaps, just in case
	if is_obstacle_active:
		return
		
	is_obstacle_active = true
	spawn_random_obstacle()

func spawn_random_obstacle():
	match pick_weighted_obstacle():
		ObstacleType.SPEED_CAMERA:
			trigger_speed_camera()
		ObstacleType.SIDE_VEHICLE:
			trigger_side_vehicle()
		ObstacleType.SPEED_INCREASE:
			trigger_speed_increase()
		_:
			# Nothing to run, so do not hold the lock: draw again right away.
			resolve_obstacle()

# Draws an obstacle from OBSTACLE_WEIGHTS. A weighted table instead of a plain
# random index, so the side vehicle can come up more often than the rest without
# touching the enum.
func pick_weighted_obstacle() -> int:
	var total := 0
	for weight in OBSTACLE_WEIGHTS.values():
		total += weight
	if total <= 0:
		return -1

	var roll := randi() % total
	for obstacle in OBSTACLE_WEIGHTS:
		roll -= OBSTACLE_WEIGHTS[obstacle]
		if roll < 0:
			return obstacle
	return -1

# --- Obstacle Triggers ---

func trigger_speed_camera():
	signalist._on_trigger_speed_camera()
	get_tree().create_timer(17).timeout.connect(resolve_obstacle)

func trigger_side_vehicle():
	signalist._on_car_break_check()
	get_tree().create_timer(11).timeout.connect(resolve_obstacle)

func trigger_speed_increase():
	signalist._on_trigger_speed_increase()
	get_tree().create_timer(4.0).timeout.connect(resolve_obstacle)

func trigger_fall_out():
	#signalist._on_trigger_fall_out()
	get_tree().create_timer(18.0).timeout.connect(resolve_obstacle)
# --- Resolution ---

# This function MUST be called whenever an obstacle leaves the screen or ends.
func resolve_obstacle():
	is_obstacle_active = false
	
	# Once the obstacle is cleared, start the 8-second maximum countdown for the next one
	start_next_obstacle_timer()
