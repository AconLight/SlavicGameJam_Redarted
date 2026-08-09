class_name FieldMotionController
extends Node

## Drives one or more static field Sprite2D layers from the shared driving speed.
## Add future far/mid/near field sprites to layer_paths and give each one a
## matching travel multiplier. The sky and the road stay outside this controller.

@export var layer_paths: Array[NodePath] = []
@export var layer_travel_multipliers := PackedFloat32Array([1.0])
## Phase position for each layer. A two-plate loop uses [0.0, 0.5], the
## greatest possible separation on a repeating cycle.
@export var layer_cycle_offsets := PackedFloat32Array([0.0])
@export_range(1.0, 300.0, 1.0) var reference_speed_kmh := 80.0
@export_range(0.01, 2.0, 0.01) var travel_units_per_second := 0.18
@export var vanishing_point := Vector2(0.5, 0.0)
## Used only when no GameStateSignalist exists, such as the standalone preview.
## Keep this at zero for gameplay scenes.
@export_range(0.0, 300.0, 1.0) var preview_speed_kmh := 0.0

var _travel := 0.0
var _signalist: GameStateSignalist
var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	_resolve_materials()
	call_deferred("_connect_signalist")


func _process(delta: float) -> void:
	var speed_kmh := _signalist.current_speed_kmh if _signalist != null else preview_speed_kmh
	var speed_ratio := maxf(speed_kmh, 0.0) / reference_speed_kmh
	if speed_ratio <= 0.0:
		return
	_travel += delta * travel_units_per_second * speed_ratio
	for index in _materials.size():
		var multiplier := layer_travel_multipliers[index] if index < layer_travel_multipliers.size() else 1.0
		var cycle_offset := layer_cycle_offsets[index] if index < layer_cycle_offsets.size() else 0.0
		var material := _materials[index]
		material.set_shader_parameter("travel", _travel * multiplier + cycle_offset)
		material.set_shader_parameter("vanishing_point", vanishing_point)


func _connect_signalist() -> void:
	_signalist = get_tree().get_first_node_in_group(&"game_state_signalist") as GameStateSignalist
	if _signalist == null:
		push_warning("FieldMotionController could not find GameStateSignalist; field motion will stay paused.")


func _resolve_materials() -> void:
	_materials.clear()
	for layer_path in layer_paths:
		var layer := get_node_or_null(layer_path) as CanvasItem
		if layer == null:
			push_warning("FieldMotionController could not find layer at %s." % layer_path)
			continue
		var material := layer.material as ShaderMaterial
		if material == null:
			push_warning("FieldMotionController layer %s has no ShaderMaterial." % layer.name)
			continue
		material.set_shader_parameter("vanishing_point", vanishing_point)
		material.set_shader_parameter("travel", 0.0)
		_materials.append(material)
