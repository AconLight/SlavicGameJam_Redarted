class_name ScrollElement2D
extends Node2D

enum ProjectionMode { FLAT, VERTICAL }
enum DebugVisual { NONE, STRIPE, TREE, CAR }

@export var projection_mode: ProjectionMode = ProjectionMode.FLAT
@export var slot := 0
@export_range(-0.95, 3.0, 0.01) var relative_speed := 0.0
@export_range(0.01, 8.0, 0.01) var size_multiplier := 1.0
@export var content_scene: PackedScene
@export var debug_visual: DebugVisual = DebugVisual.NONE

# Physical distance along the road. The manager converts this to visual progress.
var road_distance := 0.0


func _ready() -> void:
	if content_scene == null or get_node_or_null("Content") != null:
		return
	var content := content_scene.instantiate()
	content.name = "Content"
	add_child(content)


func apply_projection(screen_position: Vector2, screen_scale: Vector2, path_rotation: float) -> void:
	position = screen_position
	scale = screen_scale * size_multiplier
	rotation = 0.0 if projection_mode == ProjectionMode.VERTICAL else path_rotation
	# The hosting scene owns global draw order. Scroll elements stay at normal depth.
	z_index = 0
	visible = road_distance >= 0.0


func _draw() -> void:
	if content_scene != null:
		return
	match debug_visual:
		DebugVisual.STRIPE:
			# The stripe's anchor is its first pixel, at the perspective point.
			draw_rect(Rect2(-5, 0, 10, 40), Color(0.94, 0.92, 0.72, 1.0))
		DebugVisual.TREE:
			draw_rect(Rect2(-4, 2, 8, 20), Color(0.28, 0.14, 0.06, 1.0))
			draw_circle(Vector2(0, -10), 18, Color(0.08, 0.48, 0.19, 1.0))
		DebugVisual.CAR:
			draw_rect(Rect2(-16, -28, 32, 56), Color(0.9, 0.18, 0.12, 1.0))
			draw_rect(Rect2(-11, -18, 22, 20), Color(0.45, 0.75, 0.95, 1.0))
