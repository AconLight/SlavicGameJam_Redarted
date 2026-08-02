extends Sprite2D

@export var orbit_radius := 100.0
@export var orbit_speed := 1.0

var orbit_angle := 0.0

@onready var center_sprite: Sprite2D = $"../Sprite2D"

func _ready() -> void:
	if texture == null:
		texture = center_sprite.texture

func _process(delta: float) -> void:
	orbit_angle += orbit_speed * delta
	global_position = center_sprite.global_position + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
