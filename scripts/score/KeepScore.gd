extends Node

@onready var score_label: Label = $ScoreLabel
@onready var chill_label: Label = $ChillLabel
@onready var chill_ProgressBar: TextureProgressBar = $ProgressBar

var score: int = 0
var chill: int = 10
var chill_active: bool = false

var chill_timer: Timer
var decay_timer: Timer

@onready var highscore = $"../HighScore"

func _ready():
	
	add_to_group("keep_score")
	# Timer for chill activity (score + chill gain)
	chill_timer = Timer.new()
	chill_timer.wait_time = 1.0
	chill_timer.one_shot = false
	chill_timer.timeout.connect(_on_chill_tick)
	add_child(chill_timer)
	
	# Passive chill decay timer
	decay_timer = Timer.new()
	decay_timer.wait_time = 1.0
	decay_timer.one_shot = false
	decay_timer.timeout.connect(_on_chill_decay)
	add_child(decay_timer)
	decay_timer.start()
	
	# NEW: Initialize the labels on screen load
	update_ui()

# Chill naliczają teraz aktywności w kabinie: CabinActivityController woła
# ChillActivity() na starcie trzymania i EndChill() po puszczeniu.
# Wcześniej stała tu atrapa reagująca na spację — spacja obsługuje dziś gaz,
# więc chill rósłby od dodawania gazu zamiast od czynności kierowcy.

# Start ChillActivity
func ChillActivity():
	if chill_active:
		return
	chill_active = true
	chill_timer.start()

# Runs every second while Space is held
func _on_chill_tick():
	score += 100 * get_chill_multiplier()
	chill += 10
	chill = clamp(chill, 0, 100)
	# NEW: Update screen when variables increase
	update_ui() 

# Passive chill decay always runs
func _on_chill_decay():
	if not chill_active:
		chill -= 2
		chill = clamp(chill, 0, 100)
		# NEW: Update screen when variables decay
		update_ui()
		
		if chill == 0:
			highscore.SetHighscore(score)
			EndChill()
	print("Score: ", score, " | Chill: ", chill)

# Stop ChillActivity
func EndChill():
	if not chill_active:
		return
	chill_active = false
	chill_timer.stop()

# Determines score multiplier from chill amount
func get_chill_multiplier() -> int:
	if chill <= 25:
		return 1
	elif chill <= 50:
		return 2
	elif chill <= 80:
		return 4
	else:
		return 8

# Add chill from other actions
func AddChill(amount: int):
	chill += amount
	chill = clamp(chill, 0, 100)
	# NEW: Update screen when outside sources change chill
	update_ui()

# NEW: Helper function to push variables to the Label nodes
func update_ui():
	# The str() function converts integers to text that the Label can read
	score_label.text = "Score: " + str(score)
	chill_label.text = "Chill: " + str(chill)
	chill_ProgressBar.value = chill
