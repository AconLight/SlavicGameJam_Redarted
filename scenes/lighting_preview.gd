extends Node2D

@export var orbit_radius := Vector2(220.0, 140.0)
@export var orbit_speed := 1.1
@export var actor_speed := 220.0

@onready var _light: PointLight2D = $PointLight2D
@onready var _actor: Node2D = $Boss
@onready var _sprite: AnimatedSprite2D = $Boss/VisualRoot/AnimatedSprite2D

var _elapsed := 0.0


func _ready() -> void:
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	_sprite.play()


func _process(delta: float) -> void:
	_elapsed += delta * orbit_speed
	_update_layout()
	var direction := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)),
	).normalized()
	if direction != Vector2.ZERO:
		_actor.position += direction * actor_speed * delta
		if not is_zero_approx(direction.x):
			_sprite.flip_h = direction.x < 0.0
	_light.position = _actor.position + Vector2(cos(_elapsed) * orbit_radius.x, sin(_elapsed * 1.35) * orbit_radius.y)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_play_animation(&"Idle")
		KEY_2:
			_play_animation(&"Fly")
		KEY_3:
			_play_animation(&"Hurt")
		KEY_4:
			_play_animation(&"Attack")
		KEY_5:
			_play_animation(&"Death")


func _play_animation(animation_name: StringName) -> void:
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(animation_name):
		_sprite.play(animation_name)


func _update_layout() -> void:
	if not is_instance_valid(_actor):
		return
	if _actor.position == Vector2.ZERO:
		_actor.position = get_viewport_rect().size * 0.5
