class_name ScrollSpawnHandler
extends Node2D

const ScrollElementScript := preload("res://scripts/driving/scroll_element_2d.gd")

@export var content_scene: PackedScene
@export_enum("Flat", "Vertical", "Expand Right", "Expand Left") var projection_mode := 0
@export_enum("None", "Stripe", "Tree", "Car") var debug_visual := 0
@export var slot_choices := PackedInt32Array([0])
## Fine-tunes every selected integer slot, allowing placements such as -5.5.
@export_range(-1.0, 1.0, 0.1) var lane_offset := 0.0
## Keeps new elements hidden until this fraction of their road path has elapsed.
@export_range(0.0, 1.0, 0.01) var visibility_start_distance := 0.0
@export_range(-0.95, 3.0, 0.01) var relative_speed_min := 0.0
@export_range(-0.95, 3.0, 0.01) var relative_speed_max := 0.0
@export_range(0.01, 8.0, 0.01) var size_multiplier_min := 1.0
@export_range(0.01, 8.0, 0.01) var size_multiplier_max := 1.0
## Per-element perspective growth, independent of base size/randomization.
@export_range(0.0, 4.0, 0.01) var growth_factor := 1.0
## Absolute post-projection placement adjustment for spawned vertical elements.
@export var screen_offset_pixels := Vector2.ZERO
## 0 keeps a perfectly regular line. Higher values randomize the initial road
## progress and lateral placement of each spawned element.
@export_range(0.0, 1.0, 0.01) var randomizer_factor := 0.0
## Freezes vertical-element growth before the final near-camera perspective slice.
@export_range(0.0, 0.95, 0.01) var near_offset := 0.0
@export_group("Render Order")
## Added to ScrollManager2D's element depth. Higher values draw in front.
@export_range(-100, 100, 1) var render_order_offset := 0
@export_group("")
@export_range(0.001, 0.25, 0.001) var flat_road_length := 0.022
@export_range(0.01, 1.0, 0.01) var flat_half_width_in_slots := 0.14
## Optional textures for flat road decals. One is chosen per spawn.
@export var flat_texture_choices: Array[Texture2D] = []
@export_range(0.05, 30.0, 0.01) var spawn_interval_seconds := 1.0
@export var derive_interval_from_road_spacing := false
@export_range(0.001, 1.0, 0.001) var road_spacing := 0.08
## One multiplier is chosen for each upcoming timed spawn. Leave as [1] for
## a fixed interval; use [1, 2, 3] to make each spawn 1–3 times rarer.
@export var spawn_interval_multipliers := PackedInt32Array([1])
@export_range(1, 1000, 1) var max_active_elements := 12
@export_range(0, 1000, 1) var prewarm_count := 0
@export_range(0.0, 1.0, 0.01) var prewarm_start_distance := 0.0
@export_range(0.001, 1.0, 0.001) var prewarm_spacing := 0.08
@export var spawn_immediately := true
## Independent probability that a scheduled spawn produces an element.
@export_range(0.0, 1.0, 0.01) var spawn_chance := 0.4
## Keeps prewarmed elements fixed in place and prevents further spawns.
@export var freeze_spawned_elements := false
## Creates one stationary anchor before normal prewarmed and live spawns begin.
@export var spawn_frozen_first_element := false
@export_range(0.0, 1.0, 0.01) var frozen_first_spawn_distance := 0.5

@export_group("Signal Spawn")
## When enabled, this handler creates elements only in response to the shared
## speed-camera trigger; normal timer and road-distance spawn clocks are off.
@export var spawn_on_speed_camera_trigger := false
@export_range(0.0, 1.0, 0.01) var signal_spawn_start_distance := 0.0

var _manager: ScrollManager2D
var _signalist: GameStateSignalist
var _random := RandomNumberGenerator.new()
var _time_until_spawn := 0.0
var _spawn_distance_accumulator := 0.0


func _ready() -> void:
	_manager = _find_manager()
	assert(_manager != null, "ScrollSpawnHandler must be below a ScrollManager2D node.")
	_random.randomize()
	if spawn_frozen_first_element:
		var frozen_element := _spawn(frozen_first_spawn_distance)
		if frozen_element != null:
			frozen_element.motion_frozen = true
	for index in prewarm_count:
		_spawn(prewarm_start_distance + float(index) * prewarm_spacing)
	_time_until_spawn = 0.0 if spawn_immediately else _next_spawn_interval()
	if spawn_on_speed_camera_trigger:
		call_deferred("_connect_speed_camera_trigger")


func _find_manager() -> ScrollManager2D:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is ScrollManager2D:
			return ancestor as ScrollManager2D
		ancestor = ancestor.get_parent()
	return null


func _process(delta: float) -> void:
	if freeze_spawned_elements:
		return
	_update_active_elements(delta)
	if spawn_on_speed_camera_trigger:
		return
	if derive_interval_from_road_spacing:
		_spawn_by_road_distance(delta)
		return
	_time_until_spawn -= delta
	if _time_until_spawn > 0.0:
		return
	if _active_count() < max_active_elements:
		_spawn(0.0)
		_time_until_spawn = _next_spawn_interval()


func _spawn_by_road_distance(delta: float) -> void:
	# Keeping the spawn clock in road-distance space prevents gaps when the
	# accelerator changes the world-scroll speed. All elements in a configured
	# line are therefore separated by exactly road_spacing.
	var relative_speed := maxf(0.0, 1.0 + relative_speed_min)
	_spawn_distance_accumulator += _manager.effective_world_scroll_speed() * relative_speed * delta
	while _spawn_distance_accumulator >= road_spacing and _active_count() < max_active_elements:
		_spawn_distance_accumulator -= road_spacing
		# The new item has already travelled the leftover amount this frame, so it
		# lands on the same distance grid as every older item.
		_spawn(_spawn_distance_accumulator)


func _connect_speed_camera_trigger() -> void:
	_signalist = get_tree().get_first_node_in_group(&"game_state_signalist") as GameStateSignalist
	if _signalist == null:
		push_warning("Signal-spawn handler could not find GameStateSignalist.")
		return
	if not _signalist.speed_camera_trigger.is_connected(_on_speed_camera_trigger):
		_signalist.speed_camera_trigger.connect(_on_speed_camera_trigger)


func _on_speed_camera_trigger() -> void:
	if _active_count() < max_active_elements:
		_spawn(signal_spawn_start_distance)


func _update_active_elements(delta: float) -> void:
	for child in get_children():
		var element := child as ScrollElement2D
		if element == null:
			continue
		if not element.motion_frozen:
			element.road_distance += _manager.effective_world_scroll_speed() * maxf(0.0, 1.0 + element.relative_speed) * delta
			if element.road_distance > 1.0:
				element.queue_free()
				continue
		_manager.apply_projection(element)


## Reprojects existing elements after a live perspective/lane configuration edit.
## Zero delta deliberately preserves every element's current road distance.
func refresh_active_elements() -> void:
	_update_active_elements(0.0)


func _spawn(road_distance: float) -> ScrollElement2D:
	if _random.randf() > spawn_chance:
		return null
	var element := ScrollElementScript.new()
	element.projection_mode = projection_mode
	element.debug_visual = debug_visual
	element.content_scene = content_scene
	element.slot = slot_choices[_random.randi_range(0, slot_choices.size() - 1)] if not slot_choices.is_empty() else 0
	var lane_jitter := _random.randf_range(-0.5, 0.5) * randomizer_factor
	element.lane_offset = float(element.slot) + lane_offset + lane_jitter
	element.visibility_start_distance = visibility_start_distance
	element.relative_speed = _random.randf_range(relative_speed_min, relative_speed_max) + _outward_vegetation_speed_bonus()
	element.size_multiplier = _random.randf_range(size_multiplier_min, size_multiplier_max)
	element.growth_factor = growth_factor
	element.screen_offset_pixels = screen_offset_pixels
	element.near_offset = near_offset
	element.render_order_offset = render_order_offset
	element.flat_road_length = flat_road_length
	element.flat_half_width_in_slots = flat_half_width_in_slots
	if not flat_texture_choices.is_empty():
		element.flat_texture = flat_texture_choices[_random.randi_range(0, flat_texture_choices.size() - 1)]
	var distance_jitter := _random.randf_range(-road_spacing, road_spacing) * 0.5 * randomizer_factor
	element.road_distance = clampf(road_distance + distance_jitter, 0.0, 1.0)
	add_child(element)
	_manager.apply_projection(element)
	return element


func _outward_vegetation_speed_bonus() -> float:
	# The roadside vegetation tiers use growth factors 0.5 down to 0.1.
	# Each lower tier moves 1.1x slower than the previous tier.
	if growth_factor > 0.5:
		return 0.0
	var tier := roundi((0.5 - growth_factor) * 10.0) + 1
	return pow(1.0 / 1.1, tier) - 1.0


func _spawn_interval() -> float:
	if not derive_interval_from_road_spacing:
		return spawn_interval_seconds
	return road_spacing / maxf(_manager.effective_world_scroll_speed(), 0.001)


func _next_spawn_interval() -> float:
	var multiplier := 1
	if not spawn_interval_multipliers.is_empty():
		multiplier = maxi(1, spawn_interval_multipliers[_random.randi_range(0, spawn_interval_multipliers.size() - 1)])
	var timing_jitter := _random.randf_range(0.65, 1.35)
	return _spawn_interval() * float(multiplier) * lerpf(1.0, timing_jitter, randomizer_factor)


func _active_count() -> int:
	var count := 0
	for child in get_children():
		if child is ScrollElement2D and not child.is_queued_for_deletion():
			count += 1
	return count
