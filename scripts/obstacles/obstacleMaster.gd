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
const MAX_DELAY: float = 8.0

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
	# Pick a random number based on how many items are in the ObstacleType enum
	var random_obstacle = randi() % ObstacleType.size()
	
	match random_obstacle:
		#ObstacleType.SPEED_CAMERA:
			#trigger_speed_camera()
		ObstacleType.SIDE_VEHICLE:
			trigger_side_vehicle()
		#ObstacleType.SPEED_INCREASE:
			#trigger_speed_increase()
		#ObstacleType.FALL_OUT:
			#trigger_fall_out()

# --- Obstacle Triggers ---

func trigger_speed_camera():
	signalist._on_trigger_speed_camera()
	get_tree().create_timer(3.0).timeout.connect(resolve_obstacle)

func trigger_side_vehicle():
	signalist._on_car_break_check()
	get_tree().create_timer(4.0).timeout.connect(resolve_obstacle)

func trigger_speed_increase():
	signalist._on_trigger_speed_increase()
	get_tree().create_timer(2.0).timeout.connect(resolve_obstacle)

func trigger_fall_out():
	#signalist._on_trigger_fall_out()
	get_tree().create_timer(2.0).timeout.connect(resolve_obstacle)
# --- Resolution ---

# This function MUST be called whenever an obstacle leaves the screen or ends.
func resolve_obstacle():
	is_obstacle_active = false
	
	# Once the obstacle is cleared, start the 8-second maximum countdown for the next one
	start_next_obstacle_timer()
