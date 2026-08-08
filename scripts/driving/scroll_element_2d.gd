class_name ScrollElement2D
extends Node2D

enum ProjectionMode { FLAT, VERTICAL, EXPAND_RIGHT }
enum DebugVisual { NONE, STRIPE, TREE, CAR }

@export var projection_mode: ProjectionMode = ProjectionMode.FLAT
@export var slot := 0
@export_range(-0.95, 3.0, 0.01) var relative_speed := 0.0
@export_range(0.01, 8.0, 0.01) var size_multiplier := 1.0
@export var content_scene: PackedScene
@export var debug_visual: DebugVisual = DebugVisual.NONE
@export_range(-100, 100, 1) var render_order_offset := 0
@export_range(0.001, 0.25, 0.001) var flat_road_length := 0.022
@export_range(0.01, 1.0, 0.01) var flat_half_width_in_slots := 0.14
var flat_texture: Texture2D

# Physical distance along the road. The manager converts this to visual progress.
var road_distance := 0.0
@export_range(0.0, 0.95, 0.01) var near_offset := 0.0
var _flat_ground_quad := PackedVector2Array()


func _ready() -> void:
	if content_scene == null or get_node_or_null("Content") != null:
		return
	var content := content_scene.instantiate()
	content.name = "Content"
	add_child(content)
	if projection_mode == ProjectionMode.EXPAND_RIGHT:
		_anchor_content_to_left_edge(content)


func apply_projection(screen_position: Vector2, screen_scale: Vector2, path_rotation: float, render_z_index: int, effective_lane_offset: float) -> void:
	_flat_ground_quad.clear()
	position = screen_position
	scale = screen_scale * size_multiplier
	rotation = 0.0 if projection_mode != ProjectionMode.FLAT else path_rotation
	# This is absolute so nested spawn-handler nodes cannot accidentally put the
	# generated element above the cockpit/cabin artwork.
	z_as_relative = false
	z_index = render_z_index
	visible = road_distance >= 0.0
	queue_redraw()


func uses_flat_ground_projection() -> bool:
	return content_scene == null and projection_mode == ProjectionMode.FLAT and (debug_visual == DebugVisual.STRIPE or flat_texture != null)


func apply_flat_ground_projection(ground_quad: PackedVector2Array, render_z_index: int, effective_lane_offset: float) -> void:
	_flat_ground_quad = ground_quad
	position = Vector2.ZERO
	scale = Vector2.ONE
	rotation = 0.0
	z_as_relative = false
	z_index = render_z_index
	visible = road_distance >= 0.0
	queue_redraw()


func _draw() -> void:
	if content_scene != null:
		return
	if flat_texture != null and _flat_ground_quad.size() == 4:
		_draw_textured_flat_quad()
		return
	match debug_visual:
		DebugVisual.STRIPE:
			if _flat_ground_quad.size() == 4:
				# Curved routes can make the projected quad non-convex. Two individual
				# triangles avoid Godot's polygon-triangulation failure in that case.
				var stripe_color := Color(0.94, 0.92, 0.72, 1.0)
				_draw_triangle(_flat_ground_quad[0], _flat_ground_quad[1], _flat_ground_quad[2], stripe_color)
				_draw_triangle(_flat_ground_quad[0], _flat_ground_quad[2], _flat_ground_quad[3], stripe_color)
			else:
				draw_rect(Rect2(-5, 0, 10, 40), Color(0.94, 0.92, 0.72, 1.0))
		DebugVisual.TREE:
			draw_rect(Rect2(-4, 2, 8, 20), Color(0.28, 0.14, 0.06, 1.0))
			draw_circle(Vector2(0, -10), 18, Color(0.08, 0.48, 0.19, 1.0))
		DebugVisual.CAR:
			draw_rect(Rect2(-16, -28, 32, 56), Color(0.9, 0.18, 0.12, 1.0))
			draw_rect(Rect2(-11, -18, 22, 20), Color(0.45, 0.75, 0.95, 1.0))


func _draw_triangle(first: Vector2, second: Vector2, third: Vector2, color: Color) -> void:
	var signed_double_area := (second - first).cross(third - first)
	if absf(signed_double_area) > 0.01:
		draw_primitive(
			PackedVector2Array([first, second, third]),
			PackedColorArray([color, color, color]),
			PackedVector2Array(),
		)


func _draw_textured_flat_quad() -> void:
	# Draw as two UV-mapped triangles: curved road paths can yield non-convex
	# quads, and this remains stable where a single polygon may not.
	draw_primitive(
		PackedVector2Array([_flat_ground_quad[0], _flat_ground_quad[1], _flat_ground_quad[2]]),
		PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE]),
		# The noise art is a landscape strip. Its long axis crosses the road,
		# keeping each mark perpendicular to the direction of travel.
		PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]),
		flat_texture,
	)
	draw_primitive(
		PackedVector2Array([_flat_ground_quad[0], _flat_ground_quad[2], _flat_ground_quad[3]]),
		PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE]),
		PackedVector2Array([Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]),
		flat_texture,
	)


func _anchor_content_to_left_edge(node: Node) -> void:
	for child in node.get_children():
		if child is Sprite2D:
			(child as Sprite2D).centered = false
		elif child is AnimatedSprite2D:
			(child as AnimatedSprite2D).centered = false
		_anchor_content_to_left_edge(child)
