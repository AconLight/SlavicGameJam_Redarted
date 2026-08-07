extends Node

@onready var highscore_label: Label = $HighScoreLabel
const HIGHSCORE_PATH = "user://highscore.json"
var highscore: int = 0

func _ready():
	load_highscore()
	# NEW: Set the label as soon as the saved score is loaded
	update_highscore_ui()

func SetHighscore(current_score: int):
	# Replace saved score if current score is higher
	if current_score > highscore:
		highscore = current_score
		save_highscore()
		# NEW: Update the label in real-time when a new record is set
		update_highscore_ui()

func load_highscore():
	if not FileAccess.file_exists(HIGHSCORE_PATH):
		highscore = 0
		return
	var file = FileAccess.open(HIGHSCORE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data != null and data.has("highscore"):
		highscore = int(data["highscore"])
	else:
		highscore = 0

func save_highscore():
	# Opening with WRITE automatically overwrites the old JSON
	var file = FileAccess.open(HIGHSCORE_PATH, FileAccess.WRITE)
	var data = {
		"highscore": highscore
	}
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

# NEW: Helper function to update the highscore label
func update_highscore_ui():
	if highscore_label:
		highscore_label.text = "Highscore: " + str(highscore)
