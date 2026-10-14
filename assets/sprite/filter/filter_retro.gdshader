shader_type canvas_item;

// A restrained HD-2D grade: warm shadows, vivid light, soft bloom and a
// subtle lens finish. Keep the defaults gentle so pixel art remains crisp.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float exposure : hint_range(-0.2, 0.2) = 0.02;
uniform float contrast : hint_range(0.8, 1.3) = 1.08;
uniform float saturation : hint_range(0.7, 1.3) = 1.08;
uniform float warmth : hint_range(0.0, 0.12) = 0.035;
uniform float bloom_strength : hint_range(0.0, 0.5) = 0.18;
uniform float bloom_threshold : hint_range(0.3, 1.0) = 0.68;
uniform float vignette_strength : hint_range(0.0, 0.45) = 0.16;
uniform float grain_strength : hint_range(0.0, 0.04) = 0.008;
// 移轴焦平面：中间横带清晰，越靠上下边缘越模糊。
uniform float tilt_focus_center : hint_range(0.0, 1.0) = 0.54;
uniform float tilt_focus_half_width : hint_range(0.04, 0.45) = 0.13;
uniform float tilt_focus_transition : hint_range(0.02, 0.45) = 0.17;
uniform float tilt_blur_strength : hint_range(0.0, 1.0) = 0.78;
uniform float tilt_blur_mip_level : hint_range(0.0, 6.0) = 4.1;
uniform float edge_blur_strength : hint_range(0.0, 0.50) = 0.15;
uniform float foreground_blur_strength : hint_range(0.0, 1.0) = 0.42;
uniform float foreground_blur_start : hint_range(0.0, 1.0) = 0.67;

float luminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec3 bright_sample(vec2 uv) {
	vec3 color = texture(screen_texture, uv).rgb;
	return color * smoothstep(bloom_threshold, 1.0, luminance(color));
}

vec3 soft_sample(vec2 uv, vec2 texel) {
	vec3 color = texture(screen_texture, uv).rgb * 0.4;
	color += texture(screen_texture, uv + vec2(texel.x * 2.0, 0.0)).rgb * 0.15;
	color += texture(screen_texture, uv - vec2(texel.x * 2.0, 0.0)).rgb * 0.15;
	color += texture(screen_texture, uv + vec2(0.0, texel.y * 2.0)).rgb * 0.15;
	color += texture(screen_texture, uv - vec2(0.0, texel.y * 2.0)).rgb * 0.15;
	return color;
}

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	vec3 color = source.rgb + exposure;
	vec2 centered_uv = SCREEN_UV - 0.5;

	// Blur only bright pixels: lights, water and sunlit surfaces get a soft glow.
	vec2 texel = 1.0 / vec2(textureSize(screen_texture, 0));
	vec3 soft_focus = soft_sample(SCREEN_UV, texel);

	// mipmap 取样带来明显柔焦，不只是混合周围两三个像素。
	float vertical_distance = abs(SCREEN_UV.y - tilt_focus_center);
	float tilt_mask = smoothstep(tilt_focus_half_width, tilt_focus_half_width + tilt_focus_transition, vertical_distance);
	float edge_mask = smoothstep(0.38, 0.72, length(centered_uv)) * edge_blur_strength;
	// 下半屏代表贴近镜头的地面与前景物，额外虚化以加强微缩景深。
	float foreground_mask = smoothstep(foreground_blur_start, 1.0, SCREEN_UV.y) * foreground_blur_strength;
	float blur_mask = clamp(tilt_mask * tilt_blur_strength + edge_mask + foreground_mask, 0.0, 1.0);
	vec3 tilt_blurred = textureLod(screen_texture, SCREEN_UV, blur_mask * tilt_blur_mip_level).rgb;
	color = mix(color, mix(soft_focus, tilt_blurred, 0.88), blur_mask);

	vec3 bloom = bright_sample(SCREEN_UV) * 0.4;
	bloom += bright_sample(SCREEN_UV + vec2(texel.x * 3.0, 0.0)) * 0.15;
	bloom += bright_sample(SCREEN_UV - vec2(texel.x * 3.0, 0.0)) * 0.15;
	bloom += bright_sample(SCREEN_UV + vec2(0.0, texel.y * 3.0)) * 0.15;
	bloom += bright_sample(SCREEN_UV - vec2(0.0, texel.y * 3.0)) * 0.15;
	color += bloom * bloom_strength;

	color = (color - 0.5) * contrast + 0.5;
	float gray = luminance(color);
	color = mix(vec3(gray), color, saturation);

	// Warm highlights and barely cooler shadows create an illustrated palette.
	float lightness = clamp(luminance(color), 0.0, 1.0);
	color += vec3(warmth, warmth * 0.42, -warmth * 0.30) * lightness;
	color += vec3(-warmth * 0.20, 0.0, warmth * 0.24) * (1.0 - lightness);

	color *= 1.0 - dot(centered_uv, centered_uv) * vignette_strength;

	float grain = fract(sin(dot(SCREEN_UV * vec2(1280.0, 720.0), vec2(12.9898, 78.233))) * 43758.5453);
	color += (grain - 0.5) * grain_strength;

	COLOR = vec4(clamp(color, 0.0, 1.0), source.a);
}
