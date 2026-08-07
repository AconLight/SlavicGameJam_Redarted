class_name ScrollManager2D
extends Node2D

const DESIGN_SIZE := Vector2(1152, 648)

@export_group("Layout")
@export var layout_size := DESIGN_SIZE
@export var fill_viewport := false

@export_group("Projection")
@export var scroll_window := Rect2(140, 120, 880, 520)
@export var perspective_point := Vector2(580, 162)
@export_range(-89.0, 0.0, 0.1) var max_angle_left := -56.0
@export_range(0.0, 89.0, 0.1) var max_angle_right := 56.0
@export_range(0.0, 1.0, 0.01) var curve_factor := 0.18
@export_range(0.0, 1.0, 0.01) var curve_smoothness := 0.75
@export_range(0.01, 2.0, 0.01) var world_scroll_speed := 0.07
@export_range(1.01, 100.0, 0.01) var far_to_near_distance_ratio := 8.0
@export_range(0.01, 1.0, 0.01) var far_scale := 0.08
@export_range(0.1, 8.0, 0.01) var near_scale := 2.5
@export_range(0.2, 4.0, 0.01) var scale_easing := 1.45
@export_range(0.05, 0.5, 0.01) var slot_lateral_spacing := 0.22

@export_group("Debug")
@export var draw_debug_guides := true


func road_to_visual_progress(road_distance: float) -> float:
	var t := clampf(road_distance, 0.0, 1.0)
	var far_distance := maxf(far_to_near_distance_ratio, 1.01)
	# Pinhole perspective on a flat road. Physical road progress is constant, while
	# apparent screen speed rises as 1 / distance^2 toward the camera.
	return t / (far_distance - (far_distance - 1.0) * t)


func slot_to_lateral_offset(slot: int) -> float:
	return clampf(float(slot) * slot_lateral_spacing, -1.0, 1.0)


func layout_scale() -> Vector2:
	var effective_size := layout_size
	if fill_viewport:
		var viewport_size := get_viewport().get_visible_rect().size
		if viewport_size.x > 0.0 and viewport_size.y > 0.0:
			effective_size = viewport_size
	return Vector2(
		effective_size.x / DESIGN_SIZE.x,
		effective_size.y / DESIGN_SIZE.y,
	)


func apply_projection(element: ScrollElement2D) -> void:
	var visual_progress := road_to_visual_progress(element.road_distance)
	var lateral_offset := slot_to_lateral_offset(element.slot)
	element.apply_projection(
		project_position(lateral_offset, visual_progress),
		layout_scale() * project_scale(visual_progress),
		project_rotation(lateral_offset, visual_progress),
	)


func project_position(lateral_offset: float, visual_progress: float) -> Vector2:
	var t := clampf(visual_progress, 0.0, 1.0)
	var endpoint := _near_endpoint(lateral_offset)
	var side := signf(lateral_offset)
	var side_strength := absf(lateral_offset)
	var outward_bend := Vector2(
		side * scroll_window.size.x * curve_factor * 0.38 * side_strength,
		-scroll_window.size.y * curve_factor * 0.18 * side_strength,
	)
	# Separating the Bézier handles creates a continuous circular-feeling sweep.
	# At 0 both handles meet in the middle (the old sharp turn); at 1 they spread
	# along the route, preserving the entry and exit tangents.
	var first_handle := perspective_point.lerp(endpoint, lerpf(0.5, 0.28, curve_smoothness))
	var second_handle := perspective_point.lerp(endpoint, lerpf(0.5, 0.72, curve_smoothness))
	var bend_scale := lerpf(1.0, 0.65, curve_smoothness)
	first_handle += outward_bend * bend_scale
	second_handle += outward_bend * bend_scale
	return perspective_point.bezier_interpolate(first_handle, second_handle, endpoint, t) * layout_scale()


func project_scale(visual_progress: float) -> float:
	return lerpf(far_scale, near_scale, pow(clampf(visual_progress, 0.0, 1.0), scale_easing))


func project_rotation(lateral_offset: float, visual_progress: float) -> float:
	var t := clampf(visual_progress, 0.0, 1.0)
	var before := project_position(lateral_offset, maxf(0.0, t - 0.01))
	var after := project_position(lateral_offset, minf(1.0, t + 0.01))
	return (after - before).angle() - PI * 0.5


func _near_endpoint(lateral_offset: float) -> Vector2:
	var angle_degrees := max_angle_left * absf(lateral_offset) if lateral_offset < 0.0 else max_angle_right * absf(lateral_offset)
	var ray := Vector2(sin(deg_to_rad(angle_degrees)), cos(deg_to_rad(angle_degrees)))
	return perspective_point + ray * scroll_window.size.y * 1.08


func _draw() -> void:
	if not draw_debug_guides:
		return
	var scale_factor := layout_scale()
	var scaled_window := Rect2(scroll_window.position * scale_factor, scroll_window.size * scale_factor)
	var scaled_point := perspective_point * scale_factor
	draw_rect(scaled_window, Color(0.1, 0.16, 0.24, 0.35), true)
	draw_rect(scaled_window, Color(0.5, 0.7, 1.0, 0.75), false, 2.0)
	draw_line(Vector2(scaled_window.position.x, scaled_point.y), Vector2(scaled_window.end.x, scaled_point.y), Color(1.0, 0.76, 0.32, 0.8), 2.0)
	draw_circle(scaled_point, 6.0 * minf(scale_factor.x, scale_factor.y), Color(1.0, 0.76, 0.32, 1.0))
	for slot in [-4, -2, 0, 2, 4]:
		var points := PackedVector2Array()
		for step in 33:
			points.append(project_position(slot_to_lateral_offset(slot), float(step) / 32.0))
		draw_polyline(points, Color(0.42, 0.7, 1.0, 0.3), 1.0)
