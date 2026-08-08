class_name ScrollManager2D
extends Node2D

const DESIGN_SIZE := Vector2(1920, 1080)

@export_group("Layout")
@export var layout_size := DESIGN_SIZE
@export var fill_viewport := true

@export_group("Projection")
@export var scroll_window := Rect2(140, 120, 880, 520)
@export var perspective_point := Vector2(560, 270)
@export_range(-89.0, 0.0, 0.1) var max_angle_left := -82.9
@export_range(0.0, 89.0, 0.1) var max_angle_right := 89.0
## Multiplier for the near end of each perspective path. A value above 1 lets
## elements exit outside the visible road before their lifetime ends.
@export_range(1.0, 4.0, 0.05) var near_path_extension := 3.0
@export_range(0.0, 1.0, 0.01) var curve_factor := 0.24
@export_range(0.0, 1.0, 0.01) var curve_smoothness := 1.0
@export_range(0.01, 2.0, 0.01) var world_scroll_speed := 0.17
@export_range(1.01, 100.0, 0.01) var far_to_near_distance_ratio := 43.5
@export_range(0.01, 1.0, 0.01) var far_scale := 0.03
@export_range(0.1, 8.0, 0.01) var near_scale := 6.0
@export_range(0.2, 4.0, 0.01) var scale_easing := 1.45
@export_range(0.05, 0.5, 0.01) var slot_lateral_spacing := 0.1
@export var slot_origin := -2

@export_group("Render")
## Absolute canvas depth used by generated elements. Keep this below cabin art.
@export var element_z_index := -10

@export_group("Game State Speed")
## At this accelerator speed, World Scroll Speed is used unchanged.
@export_range(1.0, 300.0, 1.0) var reference_driving_speed_kmh := 80.0
## The high-speed target from the accelerator. At this speed, scroll speed
## reaches Maximum Speed Multiplier.
@export_range(1.0, 300.0, 1.0) var high_speed_target_kmh := 120.0
@export_range(0.1, 10.0, 0.1) var maximum_speed_multiplier := 4.0
@export var use_game_state_speed := true

@export_group("Debug")
@export var draw_debug_guides := false

var _driving_speed_kmh := 0.0
var _signalist: GameStateSignalist


func _ready() -> void:
	call_deferred("_connect_game_state_signalist")


func effective_world_scroll_speed() -> float:
	if not use_game_state_speed or _driving_speed_kmh <= 0.0:
		return world_scroll_speed
	var speed_ratio := _driving_speed_kmh / reference_driving_speed_kmh
	if _driving_speed_kmh <= reference_driving_speed_kmh:
		return world_scroll_speed * speed_ratio
	var high_speed_range := maxf(high_speed_target_kmh - reference_driving_speed_kmh, 0.001)
	var high_speed_progress := clampf((_driving_speed_kmh - reference_driving_speed_kmh) / high_speed_range, 0.0, 1.0)
	return world_scroll_speed * lerpf(1.0, maximum_speed_multiplier, high_speed_progress)


func road_to_visual_progress(road_distance: float) -> float:
	var t := clampf(road_distance, 0.0, 1.0)
	var far_distance := maxf(far_to_near_distance_ratio, 1.01)
	# Pinhole perspective on a flat road. Physical road progress is constant, while
	# apparent screen speed rises as 1 / distance^2 toward the camera.
	return t / (far_distance - (far_distance - 1.0) * t)


func slot_to_lateral_offset(slot: int) -> float:
	return _slot_value_to_lateral_offset(float(slot))


func project_flat_quad(slot: int, road_distance: float, road_length: float, half_width_in_slots: float) -> PackedVector2Array:
	var far_distance := clampf(road_distance, 0.0, 1.0)
	var near_distance := clampf(road_distance + road_length, 0.0, 1.0)
	var lane_offset := _slot_value_to_lateral_offset(float(slot))
	# A ground marking is not a screen-facing card. Its sideways width is
	# foreshortened after the lane has turned away from the viewer. This is the
	# same as applying local X scale after its path rotation.
	var lane_angle := _lane_angle_degrees(lane_offset)
	var sideways_scale := maxf(0.08, absf(cos(deg_to_rad(lane_angle))))
	var projected_half_width := half_width_in_slots * sideways_scale
	var left_offset := _slot_value_to_lateral_offset(float(slot) - projected_half_width)
	var right_offset := _slot_value_to_lateral_offset(float(slot) + projected_half_width)
	var far_progress := road_to_visual_progress(far_distance)
	var near_progress := road_to_visual_progress(near_distance)
	return PackedVector2Array([
		project_position(left_offset, far_progress),
		project_position(right_offset, far_progress),
		project_position(right_offset, near_progress),
		project_position(left_offset, near_progress),
	])


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
	var lateral_offset := slot_to_lateral_offset(element.slot)
	if element.uses_flat_ground_projection():
		element.apply_flat_ground_projection(
			project_flat_quad(element.slot, element.road_distance, element.flat_road_length, element.flat_half_width_in_slots),
			element_z_index + element.render_order_offset,
			lateral_offset,
		)
		return
	var visual_progress := road_to_visual_progress(element.road_distance)
	# Near Offset affects scale only: the element keeps traveling to the camera,
	# but its size freezes before the final perspective-growth slice.
	var scale_road_distance := minf(element.road_distance, 1.0 - element.near_offset)
	var scale_visual_progress := road_to_visual_progress(scale_road_distance)
	element.apply_projection(
		project_position(lateral_offset, visual_progress),
		layout_scale() * project_scale(scale_visual_progress),
		project_rotation(lateral_offset, visual_progress),
		element_z_index + element.render_order_offset,
		lateral_offset,
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
	var angle_degrees := _lane_angle_degrees(lateral_offset)
	var ray := Vector2(sin(deg_to_rad(angle_degrees)), cos(deg_to_rad(angle_degrees)))
	return perspective_point + ray * scroll_window.size.y * near_path_extension


func _slot_value_to_lateral_offset(slot_value: float) -> float:
	# Lanes are intentionally unbounded. With origin -2, lane 12 maps to the
	# physical rightmost lane 10; higher values may extend beyond it on purpose.
	return (slot_value + float(slot_origin)) * slot_lateral_spacing


func _lane_angle_degrees(lateral_offset: float) -> float:
	return max_angle_left * absf(lateral_offset) if lateral_offset < 0.0 else max_angle_right * absf(lateral_offset)


func _connect_game_state_signalist() -> void:
	if not use_game_state_speed:
		return
	_signalist = get_tree().get_first_node_in_group(&"game_state_signalist") as GameStateSignalist
	if _signalist == null:
		push_warning("ScrollManager2D could not find GameStateSignalist; using World Scroll Speed.")
		return
	_driving_speed_kmh = _signalist.current_speed_kmh
	if not _signalist.driving_speed_changed.is_connected(_on_driving_speed_changed):
		_signalist.driving_speed_changed.connect(_on_driving_speed_changed)


func _on_driving_speed_changed(speed_kmh: float) -> void:
	_driving_speed_kmh = maxf(0.0, speed_kmh)


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
	for slot in [-10, -5, 0, 5, 10]:
		var points := PackedVector2Array()
		for step in 33:
			points.append(project_position(slot_to_lateral_offset(slot), float(step) / 32.0))
		draw_polyline(points, Color(0.42, 0.7, 1.0, 0.3), 1.0)
