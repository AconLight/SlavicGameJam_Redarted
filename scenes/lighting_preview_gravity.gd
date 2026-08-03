extends Node2D

@export var orbit_radius := Vector2(220.0, 140.0)
@export var orbit_speed := 1.1
@export var move_speed := 220.0
@export var gravity := 1800.0
@export var jump_velocity := 700.0
@export var floor_height := 48.0

@onready var _light: PointLight2D = $PointLight2D
@onready var _actor: CharacterBody2D = $Boss
@onready var _sprite: AnimatedSprite2D = $Boss/VisualRoot/AnimatedSprite2D
@onready var _floor: StaticBody2D = $Floor
@onready var _floor_shape: CollisionShape2D = $Floor/CollisionShape2D
@onready var _floor_visual: Polygon2D = $Floor/Visual

var _elapsed := 0.0


func _ready() -> void:
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	var viewport_size := get_viewport_rect().size
	_actor.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.25)
	_sprite.play(&"Idle")


func _physics_process(delta: float) -> void:
	var direction := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	_actor.velocity.x = direction * move_speed
	_actor.velocity.y += gravity * delta

	if _actor.is_on_floor() and Input.is_key_pressed(KEY_SPACE):
		_actor.velocity.y = -jump_velocity

	_actor.move_and_slide()

	if not is_zero_approx(direction):
		_sprite.flip_h = direction < 0.0
	_play_animation(&"Fly" if not _actor.is_on_floor() else &"Idle")

	_elapsed += delta * orbit_speed
	_light.position = _actor.position + Vector2(
		cos(_elapsed) * orbit_radius.x,
		sin(_elapsed * 1.35) * orbit_radius.y,
	)


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
		KEY_R:
			_reset_actor()


func _play_animation(animation_name: StringName) -> void:
	if _sprite.animation == animation_name and _sprite.is_playing():
		return
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(animation_name):
		_sprite.play(animation_name)


func _reset_actor() -> void:
	var viewport_size := get_viewport_rect().size
	_actor.velocity = Vector2.ZERO
	_actor.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.25)


func _update_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var half_width := viewport_size.x * 0.5
	_floor.position = Vector2(half_width, viewport_size.y - floor_height * 0.5)
	(_floor_shape.shape as RectangleShape2D).size = Vector2(viewport_size.x, floor_height)
	_floor_visual.polygon = PackedVector2Array([
		Vector2(-half_width, -floor_height * 0.5),
		Vector2(half_width, -floor_height * 0.5),
		Vector2(half_width, floor_height * 0.5),
		Vector2(-half_width, floor_height * 0.5),
	])
