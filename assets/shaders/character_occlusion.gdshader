// HD-2D 前景遮挡：只在角色的屏幕位置附近挖出羽化透明孔。
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_burley, specular_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float effect_enabled : hint_range(0.0, 1.0) = 0.0;
uniform float effect_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 subject_uv_0 = vec2(-2.0, -2.0);
uniform vec2 subject_uv_1 = vec2(-2.0, -2.0);
uniform float hole_radius : hint_range(0.01, 0.4) = 0.095;
uniform float feather_width : hint_range(0.005, 0.3) = 0.07;
uniform float ellipse_height : hint_range(0.5, 2.5) = 1.45;

float ellipse_distance(vec2 from, vec2 to) {
	vec2 offset = from - to;
	offset.y /= ellipse_height;
	return length(offset);
}

void fragment() {
	vec4 base = texture(albedo_texture, UV) * albedo_tint;
	float alpha = base.a;
	if (effect_enabled > 0.5) {
		float nearest_subject = min(
			ellipse_distance(SCREEN_UV, subject_uv_0),
			ellipse_distance(SCREEN_UV, subject_uv_1)
		);
		float hole_alpha = smoothstep(hole_radius, hole_radius + feather_width, nearest_subject);
		alpha *= mix(1.0, hole_alpha, effect_strength);
	}
	ALBEDO = base.rgb;
	ALPHA = alpha;
	ROUGHNESS = 0.9;
}
