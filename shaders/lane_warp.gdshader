shader_type canvas_item;

// Positive shifts the texture's middle right; negative shifts it left.
uniform float warp_amount : hint_range(-0.35, 0.35, 0.001) = 0.0;

void fragment() {
	vec2 warped_uv = UV;
	warped_uv.x -= sin(UV.y * PI) * warp_amount;
	if (warped_uv.x < 0.0 || warped_uv.x > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, warped_uv) * COLOR;
	}
}
