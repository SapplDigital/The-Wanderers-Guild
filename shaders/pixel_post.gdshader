shader_type canvas_item;
// Applied to the low-res SubViewportContainer: palette posterize + ordered (Bayer 4x4) dither
// in low-res pixel space, so dither dots are exactly one game pixel.

uniform bool enabled = true;
uniform float color_levels : hint_range(2.0, 32.0) = 14.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.2;

const float BAYER[16] = { 0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0 };

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (enabled) {
		ivec2 p = ivec2(floor(UV / TEXTURE_PIXEL_SIZE)) % 4;
		float b = BAYER[p.y * 4 + p.x] / 16.0 - 0.5;
		float n = color_levels - 1.0;
		c.rgb = clamp(floor(c.rgb * n + 0.5 + b * dither_strength) / n, 0.0, 1.0);
	}
	COLOR = c;
}
