extends Sprite2D # (Change this to TextureRect if you are using a UI node)
@export_group("Multiplier Textures")
@export var texture_x1: Texture2D
@export var texture_x2: Texture2D
@export var texture_x3: Texture2D
@export var texture_x4: Texture2D
@export var texture_x5: Texture2D
@onready var keep_score_node = get_parent()
var current_multiplier: int = 1
var _pulse_tween: Tween

func _process(_delta):
	if keep_score_node:
		
		# Get the current multiplier from your KeepScore script
		var new_multiplier = keep_score_node.get_chill_multiplier()
		
		# Only update the texture if the multiplier has actually changed
		# (This saves performance so we aren't swapping textures 60 times a second)
		if new_multiplier != current_multiplier:
			
			current_multiplier = new_multiplier
			update_graphic(current_multiplier)
func update_graphic(mult: int):
	
	match mult:
		1:
			texture = texture_x1
			print("set texture1")
		2:
			texture = texture_x2
			print("set texture2")
		3:
			texture = texture_x3
			print("set texture3")
		4:
			texture = texture_x4
			print("set texture4")
		5:
			texture = texture_x5
			print("set texture5")
	
	_pulse_scale()

func _pulse_scale():
	# Cancel any pulse still in progress so rapid multiplier changes
	# don't stack up competing tweens.
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_interval(0.3)
	_pulse_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
