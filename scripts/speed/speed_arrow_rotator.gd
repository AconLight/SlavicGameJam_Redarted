extends Sprite2D

@export var speed_controller: Node
@export var max_speed := 130.0

@export var min_angle := -80.0
@export var max_angle := 170.0

@export var smooth_speed := 5.0

var target_rotation := 0.0


func _ready():
	if speed_controller:
		speed_controller.speed_changed.connect(_on_speed_changed)


func _process(delta):
	rotation_degrees = lerp(
		rotation_degrees,
		target_rotation,
		smooth_speed * delta
	)


func _on_speed_changed(speed: float):
	var angle = remap(
		speed,
		0.0,
		max_speed,
		min_angle,
		max_angle
	)

	target_rotation = clamp(angle, min_angle, max_angle)
