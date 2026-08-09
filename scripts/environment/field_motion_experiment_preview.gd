class_name FieldMotionExperimentPreview
extends Node

## An isolated gallery for comparing fake forward-driving field treatments.
## It only changes preview shader materials; no gameplay scene uses this script.

@export var field_a_path: NodePath
@export var field_b_path: NodePath
@export var title_label_path: NodePath
@export var description_label_path: NodePath

const EXPERIMENTS := [
	{"title": "1 / 11  Quiet painted plate", "description": "Almost static: only a restrained forward pull.", "strength": 0.012, "depth": 1.2, "sway": 0.0, "snap": Vector2.ZERO, "offset": 0.0, "blur": 0.0, "haze": 0.0, "grain": 0.0},
	{"title": "2 / 11  Baseline forward drive", "description": "The clean default: slow horizon, stronger lower-screen movement.", "strength": 0.045, "depth": 1.8, "sway": 0.0, "snap": Vector2.ZERO, "offset": 0.0, "blur": 0.0, "haze": 0.0, "grain": 0.0},
	{"title": "3 / 11  Near-field rush", "description": "Motion stays distant at the horizon and accelerates hard near the car.", "strength": 0.10, "depth": 3.2, "sway": 0.0, "snap": Vector2.ZERO, "offset": 0.0, "blur": 0.0, "haze": 0.0, "grain": 0.0},
	{"title": "4 / 11  Gentle road sway", "description": "Forward motion plus a small cyclic side drift, like following a bend.", "strength": 0.055, "depth": 2.1, "sway": 0.026, "snap": Vector2.ZERO, "offset": 0.0, "blur": 0.0, "haze": 0.0, "grain": 0.0},
	{"title": "5 / 11  Offset double plate", "description": "The delayed plate is shifted slightly to hide duplicated-detail crossfades.", "strength": 0.055, "depth": 2.0, "sway": 0.0, "snap": Vector2.ZERO, "offset": 0.018, "blur": 0.0, "haze": 0.0, "grain": 0.0},
	{"title": "6 / 11  Pixel-stepped travel", "description": "Quantized UV motion: deliberately gamey rather than liquid-smooth.", "strength": 0.065, "depth": 2.2, "sway": 0.012, "snap": Vector2(0.0025, 0.0035), "offset": 0.0, "blur": 0.0, "haze": 0.0, "grain": 0.0},
	{"title": "7 / 11  Maximum kinetic", "description": "A dramatic test: strong near-field expansion and road sway.", "strength": 0.13, "depth": 2.8, "sway": 0.055, "snap": Vector2.ZERO, "offset": 0.012, "blur": 0.0, "haze": 0.0, "grain": 0.0},
	{"title": "8 / 11  Radial motion blur", "description": "A directional blur radiates from the horizon. Near pixels smear, horizon remains clear.", "strength": 0.075, "depth": 2.4, "sway": 0.0, "snap": Vector2.ZERO, "offset": 0.012, "blur": 0.025, "haze": 0.0, "grain": 0.0},
	{"title": "9 / 11  Heat-haze drive", "description": "A depth-limited shimmering warp makes the close field unstable while the horizon stays locked.", "strength": 0.070, "depth": 2.2, "sway": 0.01, "snap": Vector2.ZERO, "offset": 0.012, "blur": 0.006, "haze": 0.014, "grain": 0.0},
	{"title": "10 / 11  Grainy forward smear", "description": "Fine animated jitter and radial blur create a rough, high-speed analogue feel.", "strength": 0.095, "depth": 2.7, "sway": 0.018, "snap": Vector2.ZERO, "offset": 0.016, "blur": 0.032, "haze": 0.006, "grain": 0.005},
	{"title": "11 / 11  Turbo optical flow", "description": "The most distorted version: heavy near-field streaking, shimmer, sway and granular movement.", "strength": 0.14, "depth": 3.1, "sway": 0.05, "snap": Vector2.ZERO, "offset": 0.02, "blur": 0.055, "haze": 0.02, "grain": 0.008},
	{"title": "12 / 18  Peripheral speed tunnel", "description": "The centre stays readable while the screen edges pull into a high-speed tunnel.", "strength": 0.08, "depth": 2.5, "blur": 0.018, "offset": 0.012, "peripheral": 2.2},
	{"title": "13 / 18  Chromatic vector trails", "description": "Radial samples split slightly into coloured forward trails, exaggerating velocity.", "strength": 0.09, "depth": 2.6, "blur": 0.026, "offset": 0.015, "peripheral": 1.0, "chroma": 0.75},
	{"title": "14 / 18  Travelling field rows", "description": "Rapid horizontal row displacement adds terrain shimmer without moving the horizon.", "strength": 0.075, "depth": 2.3, "blur": 0.008, "offset": 0.01, "rows": 0.014},
	{"title": "15 / 18  Radial ground ripples", "description": "Circular bands run outward from the horizon like compressed roadside texture.", "strength": 0.08, "depth": 2.5, "blur": 0.012, "offset": 0.012, "ripple": 0.012},
	{"title": "16 / 18  Dusty peripheral rush", "description": "Side blur, heat shimmer and animated grain reserve the sharpest image for the horizon.", "strength": 0.10, "depth": 2.8, "blur": 0.026, "haze": 0.012, "grain": 0.006, "offset": 0.016, "peripheral": 1.8},
	{"title": "17 / 18  Pixel rally shake", "description": "Stepped pixel motion, rows and sway make a deliberately rough arcade driving treatment.", "strength": 0.09, "depth": 2.6, "sway": 0.035, "snap": Vector2(0.003, 0.004), "blur": 0.01, "offset": 0.012, "rows": 0.010},
	{"title": "18 / 18  Horizon sprint cocktail", "description": "All speed signals together: tunnel blur, vector trails, ripples, shimmer and grain.", "strength": 0.15, "depth": 3.2, "sway": 0.045, "blur": 0.045, "haze": 0.014, "grain": 0.006, "offset": 0.02, "peripheral": 2.3, "rows": 0.009, "ripple": 0.008, "chroma": 0.55},
	# Focus set: every one of these uses only smooth radial functions. No sway,
	# heat haze, row warping, pixel snapping or grain jitter.
	{"title": "19 / 27  Focus: soft radial pull", "description": "A restrained horizon-ray blur. The cleanest distorted driving option.", "strength": 0.06, "depth": 2.3, "blur": 0.012, "offset": 0.0},
	{"title": "20 / 27  Focus: wide radial pull", "description": "A broader smooth blur that makes the near field recede visibly faster.", "strength": 0.08, "depth": 2.6, "blur": 0.026, "offset": 0.0},
	{"title": "21 / 27  Focus: peripheral tunnel", "description": "Forward motion stays sharp in the middle while smooth peripheral streaks suggest speed.", "strength": 0.075, "depth": 2.5, "blur": 0.018, "offset": 0.0, "peripheral": 2.0},
	{"title": "22 / 27  Focus: subtle vector colour", "description": "Gentle chromatic trails follow the radial direction only, without horizontal motion.", "strength": 0.07, "depth": 2.4, "blur": 0.016, "offset": 0.0, "chroma": 0.32},
	{"title": "23 / 27  Focus: strong vector colour", "description": "Clear coloured forward trails, still locked strictly to the horizon ray.", "strength": 0.09, "depth": 2.7, "blur": 0.030, "offset": 0.0, "peripheral": 0.7, "chroma": 0.78},
	{"title": "24 / 27  Focus: soft ground ripples", "description": "Very subtle smooth ripples radiate outward from the horizon through the field.", "strength": 0.07, "depth": 2.4, "blur": 0.006, "offset": 0.0, "ripple": 0.004},
	{"title": "25 / 27  Focus: driving ground ripples", "description": "Stronger radial ripples and blur compress the field toward the vanishing point.", "strength": 0.085, "depth": 2.6, "blur": 0.015, "offset": 0.0, "ripple": 0.010},
	{"title": "26 / 27  Focus: balanced combination", "description": "Radial blur, a light vector trail and smooth ground ripples—no horizontal jumping ingredients.", "strength": 0.09, "depth": 2.7, "blur": 0.022, "offset": 0.0, "peripheral": 0.8, "ripple": 0.006, "chroma": 0.35},
	{"title": "27 / 27  Focus: smooth high speed", "description": "The strongest smooth-only recipe: tunnel blur, vector colour and radial ripples all converge on the horizon.", "strength": 0.125, "depth": 3.0, "blur": 0.044, "offset": 0.0, "peripheral": 1.8, "ripple": 0.010, "chroma": 0.62},
]

# Start directly at the curated smooth radial set.
var _experiment_index := 18
var _field_a: Sprite2D
var _field_b: Sprite2D
var _title_label: Label
var _description_label: Label


func _ready() -> void:
	_field_a = get_node_or_null(field_a_path) as Sprite2D
	_field_b = get_node_or_null(field_b_path) as Sprite2D
	_title_label = get_node_or_null(title_label_path) as Label
	_description_label = get_node_or_null(description_label_path) as Label
	_apply_experiment()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_RIGHT or event.keycode == KEY_D:
		_experiment_index = posmod(_experiment_index + 1, EXPERIMENTS.size())
		_apply_experiment()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_LEFT or event.keycode == KEY_A:
		_experiment_index = posmod(_experiment_index - 1, EXPERIMENTS.size())
		_apply_experiment()
		get_viewport().set_input_as_handled()


func _apply_experiment() -> void:
	if _field_a == null or _field_b == null:
		push_warning("[Field preview] Missing field sprites.")
		return
	var experiment: Dictionary = EXPERIMENTS[_experiment_index]
	_apply_to_material(_field_a.material as ShaderMaterial, experiment, Vector2.ZERO)
	_apply_to_material(_field_b.material as ShaderMaterial, experiment, Vector2(float(experiment.get("offset", 0.0)), 0.0))
	if _title_label != null:
		var suffix_start := String(experiment.title).find("  ")
		var title_suffix := String(experiment.title).substr(suffix_start + 2) if suffix_start >= 0 else String(experiment.title)
		_title_label.text = "%d / %d  %s" % [_experiment_index + 1, EXPERIMENTS.size(), title_suffix]
	if _description_label != null:
		_description_label.text = "%s\n\nLeft / A: previous     Right / D: next" % experiment.description


func _apply_to_material(material: ShaderMaterial, experiment: Dictionary, uv_offset: Vector2) -> void:
	if material == null:
		return
	material.set_shader_parameter("motion_strength", float(experiment.get("strength", 0.045)))
	material.set_shader_parameter("depth_exponent", float(experiment.get("depth", 1.8)))
	material.set_shader_parameter("lateral_sway", float(experiment.get("sway", 0.0)))
	material.set_shader_parameter("pixel_snap_uv", experiment.get("snap", Vector2.ZERO))
	material.set_shader_parameter("texture_uv_offset", uv_offset)
	material.set_shader_parameter("radial_blur", float(experiment.get("blur", 0.0)))
	material.set_shader_parameter("heat_haze", float(experiment.get("haze", 0.0)))
	material.set_shader_parameter("grain_jitter", float(experiment.get("grain", 0.0)))
	material.set_shader_parameter("peripheral_blur", float(experiment.get("peripheral", 0.0)))
	material.set_shader_parameter("row_warp", float(experiment.get("rows", 0.0)))
	material.set_shader_parameter("radial_ripple", float(experiment.get("ripple", 0.0)))
	material.set_shader_parameter("chromatic_split", float(experiment.get("chroma", 0.0)))
