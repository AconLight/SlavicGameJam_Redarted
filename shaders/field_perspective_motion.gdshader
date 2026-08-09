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
// Optional experiments: a road-like lateral sway and deliberately stepped
// pixel motion. Both default to zero, preserving the standard field.
uniform float lateral_sway : hint_range(0.0, 0.15, 0.001) = 0.0;
uniform vec2 pixel_snap_uv = vec2(0.0, 0.0);
uniform float radial_blur : hint_range(0.0, 0.08, 0.001) = 0.0;
uniform float heat_haze : hint_range(0.0, 0.04, 0.001) = 0.0;
uniform float grain_jitter : hint_range(0.0, 0.02, 0.0005) = 0.0;
uniform float peripheral_blur : hint_range(0.0, 3.0, 0.05) = 0.0;
uniform float row_warp : hint_range(0.0, 0.05, 0.001) = 0.0;
uniform float radial_ripple : hint_range(0.0, 0.05, 0.001) = 0.0;
uniform float chromatic_split : hint_range(0.0, 1.0, 0.01) = 0.0;

void fragment() {
	vec2 from_horizon = UV - vanishing_point;
	float below_horizon = max(UV.y - vanishing_point.y, 0.0);
	float available_depth = max(1.0 - vanishing_point.y, 0.001);
	float depth = pow(clamp(below_horizon / available_depth, 0.0, 1.0), depth_exponent);
	depth *= smoothstep(horizon_fade, horizon_fade + 0.06, below_horizon);

	// Repeating phase lets a static plate feel as if it advances away from the
	// horizon. The base image moves least near the horizon and most at the bottom.
	float phase = fract(travel);
	// Exact sin² crossfade over a full π phase. A second layer delayed by half
	// a cycle follows cos², so their visibility always adds up to one.
	float cycle_alpha = pow(sin(PI * phase), 2.0);
	float forward_push = phase * motion_strength * depth;
	float sideways_push = forward_push * lateral_expansion * abs(from_horizon.x);
	sideways_push += sin(travel * TAU) * lateral_sway * depth;
	vec2 source_uv = vanishing_point + from_horizon * vec2(
		1.0 - forward_push - sideways_push,
		1.0 - forward_push
	);
	source_uv += texture_uv_offset;
	// These distortions are depth-weighted, retaining a stable horizon while
	// making the near field feel less like a static painted plate.
	float wave = sin(UV.y * 72.0 + travel * TAU * 3.0) * cos(UV.x * 31.0 - travel * TAU * 1.7);
	source_uv.x += wave * heat_haze * depth;
	source_uv.x += sin(UV.y * 190.0 - travel * TAU * 7.0) * row_warp * depth;
	vec2 radial_direction = normalize(from_horizon + vec2(0.0001, 0.0001));
	float radial_wave = sin(length(from_horizon) * 52.0 - travel * TAU * 5.0);
	source_uv += radial_direction * radial_wave * radial_ripple * depth;
	float hash = fract(sin(dot(UV + vec2(travel), vec2(127.1, 311.7))) * 43758.5453);
	source_uv += (hash - 0.5) * grain_jitter * depth;
	if (pixel_snap_uv.x > 0.0 && pixel_snap_uv.y > 0.0) {
		source_uv = floor(source_uv / pixel_snap_uv) * pixel_snap_uv;
	}

	// Clamping avoids wrapping a field edge back across the road when the source
	// art does not tile perfectly.
	source_uv = clamp(source_uv, vec2(0.001), vec2(0.999));
	vec2 blur_direction = radial_direction;
	float edge_factor = pow(clamp(abs(UV.x - vanishing_point.x) * 2.0, 0.0, 1.0), 1.7);
	vec2 blur_offset = blur_direction * radial_blur * depth * (1.0 + peripheral_blur * edge_factor);
	vec4 center = texture(TEXTURE, source_uv);
	vec4 color = center * 0.4;
	color += texture(TEXTURE, clamp(source_uv - blur_offset, vec2(0.001), vec2(0.999))) * 0.2;
	color += texture(TEXTURE, clamp(source_uv + blur_offset, vec2(0.001), vec2(0.999))) * 0.2;
	color += texture(TEXTURE, clamp(source_uv + blur_offset * 2.0, vec2(0.001), vec2(0.999))) * 0.1;
	color += texture(TEXTURE, clamp(source_uv - blur_offset * 2.0, vec2(0.001), vec2(0.999))) * 0.1;
	if (chromatic_split > 0.0) {
		vec4 red_sample = texture(TEXTURE, clamp(source_uv + blur_offset * 2.0, vec2(0.001), vec2(0.999)));
		vec4 blue_sample = texture(TEXTURE, clamp(source_uv - blur_offset * 2.0, vec2(0.001), vec2(0.999)));
		color.rgb = mix(color.rgb, vec3(red_sample.r, color.g, blue_sample.b), chromatic_split);
	}
	COLOR = color;
	COLOR.a *= cycle_alpha;
}
