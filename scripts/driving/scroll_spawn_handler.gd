class_name ScrollSpawnHandler
extends Node2D

const ScrollElementScript := preload("res://scripts/driving/scroll_element_2d.gd")

@export var content_scene: PackedScene
@export_enum("Flat", "Vertical") var projection_mode := 0
@export_enum("None", "Stripe", "Tree", "Car") var debug_visual := 0
@export var slot_choices := PackedInt32Array([0])
@export_range(-0.95, 3.0, 0.01) var relative_speed_min := 0.0
@export_range(-0.95, 3.0, 0.01) var relative_speed_max := 0.0
@export_range(0.01, 8.0, 0.01) var size_multiplier_min := 1.0
@export_range(0.01, 8.0, 0.01) var size_multiplier_max := 1.0
## Freezes vertical-element growth before the final near-camera perspective slice.
@export_range(0.0, 0.95, 0.01) var near_offset := 0.0
@export_group("Render Order")
## Added to ScrollManager2D's element depth. Higher values draw in front.
@export_range(-100, 100, 1) var render_order_offset := 0
@export_group("")
@export_range(0.001, 0.25, 0.001) var flat_road_length := 0.022
@export_range(0.01, 1.0, 0.01) var flat_half_width_in_slots := 0.14
@export_group("Lane Warp Shader")
@export var use_lane_warp_shader := false
@export_range(0.0, 0.8, 0.005) var lane_warp_strength := 0.14
@export_group("")
@export_range(0.05, 30.0, 0.01) var spawn_interval_seconds := 1.0
@export var derive_interval_from_road_spacing := false
@export_range(0.001, 1.0, 0.001) var road_spacing := 0.08
@export_range(1, 120, 1) var max_active_elements := 12
@export_range(0, 120, 1) var prewarm_count := 0
@export_range(0.0, 1.0, 0.01) var prewarm_start_distance := 0.0
@export_range(0.001, 1.0, 0.001) var prewarm_spacing := 0.08
@export var spawn_immediately := true

var _manager: ScrollManager2D
var _random := RandomNumberGenerator.new()
var _time_until_spawn := 0.0


func _ready() -> void:
	_manager = _find_manager()
	assert(_manager != null, "ScrollSpawnHandler must be below a ScrollManager2D node.")
	_random.randomize()
	for index in prewarm_count:
		_spawn(prewarm_start_distance + float(index) * prewarm_spacing)
	_time_until_spawn = 0.0 if spawn_immediately else _spawn_interval()


func _find_manager() -> ScrollManager2D:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is ScrollManager2D:
			return ancestor as ScrollManager2D
		ancestor = ancestor.get_parent()
	return null


func _process(delta: float) -> void:
	_update_active_elements(delta)
	_time_until_spawn -= delta
	if _time_until_spawn > 0.0:
		return
	if _active_count() < max_active_elements:
		_spawn(0.0)
	_time_until_spawn = _spawn_interval()


func _update_active_elements(delta: float) -> void:
	for child in get_children():
		var element := child as ScrollElement2D
		if element == null:
			continue
		element.road_distance += _manager.effective_world_scroll_speed() * maxf(0.0, 1.0 + element.relative_speed) * delta
		if element.road_distance > 1.0:
			element.queue_free()
			continue
		_manager.apply_projection(element)


func _spawn(road_distance: float) -> void:
	var element := ScrollElementScript.new()
	element.projection_mode = projection_mode
	element.debug_visual = debug_visual
	element.content_scene = content_scene
	element.slot = slot_choices[_random.randi_range(0, slot_choices.size() - 1)] if not slot_choices.is_empty() else 0
	element.relative_speed = _random.randf_range(relative_speed_min, relative_speed_max)
	element.size_multiplier = _random.randf_range(size_multiplier_min, size_multiplier_max)
	element.near_offset = near_offset
	element.render_order_offset = render_order_offset
	element.flat_road_length = flat_road_length
	element.flat_half_width_in_slots = flat_half_width_in_slots
	element.use_lane_warp_shader = use_lane_warp_shader
	element.lane_warp_strength = lane_warp_strength
	element.road_distance = road_distance
	add_child(element)
	_manager.apply_projection(element)


func _spawn_interval() -> float:
	if not derive_interval_from_road_spacing:
		return spawn_interval_seconds
	return road_spacing / maxf(_manager.effective_world_scroll_speed(), 0.001)


func _active_count() -> int:
	var count := 0
	for child in get_children():
		if child is ScrollElement2D and not child.is_queued_for_deletion():
			count += 1
	return count
