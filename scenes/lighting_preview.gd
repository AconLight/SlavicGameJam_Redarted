extends Node2D

@export var orbit_radius := Vector2(220.0, 140.0)
@export var orbit_speed := 1.1

@onready var _light: PointLight2D = $PointLight2D
@onready var _actor: Node2D = $Boss

var _elapsed := 0.0


func _ready() -> void:
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()


func _process(delta: float) -> void:
	_elapsed += delta * orbit_speed
	_update_layout()
	_light.position = _actor.position + Vector2(cos(_elapsed) * orbit_radius.x, sin(_elapsed * 1.35) * orbit_radius.y)


func _update_layout() -> void:
	if not is_instance_valid(_actor):
		return
	_actor.position = get_viewport_rect().size * 0.5
