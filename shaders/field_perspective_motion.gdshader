shader_type canvas_item;
render_mode unshaded;

// Normalized horizon/road vanishing point shared by all field layers.
uniform vec2 vanishing_point = vec2(0.5, 0.0);
// Set by FieldMotionController from gameplay speed. Zero means no movement.
uniform float travel = 0.0;
// Keep this subtle: it distorts the source painting less than a conventional zoom.
uniform float motion_strength : hint_range(0.0, 0.18, 0.001) = 0.045;
uniform float depth_exponent : hint_range(0.5, 4.0, 0.05) = 1.8;
uniform float lateral_expansion : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float horizon_fade : hint_range(0.0, 0.3, 0.001) = 0.035;
// Lets duplicated field layers differ slightly during their future crossfade.
// Zero preserves the source image exactly.
uniform vec2 texture_uv_offset = vec2(0.0, 0.0);
// A second field layer uses 0.5. It resets while transparent, hiding the loop.
uniform float cycle_offset : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float cycle_fade_portion : hint_range(0.01, 0.45, 0.01) = 0.18;

void fragment() {
	vec2 from_horizon = UV - vanishing_point;
	float below_horizon = max(UV.y - vanishing_point.y, 0.0);
	float available_depth = max(1.0 - vanishing_point.y, 0.001);
	float depth = pow(clamp(below_horizon / available_depth, 0.0, 1.0), depth_exponent);
	depth *= smoothstep(horizon_fade, horizon_fade + 0.06, below_horizon);

	// Repeating phase lets a static plate feel as if it advances away from the
	// horizon. The base image moves least near the horizon and most at the bottom.
	float phase = fract(travel + cycle_offset);
	// The plate is invisible only at its reset boundaries. Two layers offset by
	// half a cycle therefore always leave a continuous visible field.
	float cycle_alpha = smoothstep(0.0, cycle_fade_portion, phase);
	cycle_alpha *= 1.0 - smoothstep(1.0 - cycle_fade_portion, 1.0, phase);
	float forward_push = phase * motion_strength * depth;
	float sideways_push = forward_push * lateral_expansion * abs(from_horizon.x);
	vec2 source_uv = vanishing_point + from_horizon * vec2(
		1.0 - forward_push - sideways_push,
		1.0 - forward_push
	);
	source_uv += texture_uv_offset;

	// Clamping avoids wrapping a field edge back across the road when the source
	// art does not tile perfectly.
	source_uv = clamp(source_uv, vec2(0.001), vec2(0.999));
	COLOR = texture(TEXTURE, source_uv);
	COLOR.a *= cycle_alpha;
}
