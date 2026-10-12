shader_type spatial;
render_mode cull_disabled, depth_draw_always, diffuse_burley, specular_schlick_ggx;

// Dalga parametreleri: (yön.x, yön.y, genlik, dalga boyu). waves.gd ile aynı formül.
uniform vec4 w0;
uniform vec4 w1;
uniform vec4 w2;
uniform vec4 w3;
uniform float t;
uniform float wave_scale = 1.0;
uniform vec3 cam_pos;
uniform float fade_start = 55.0;
uniform float fade_end = 76.0;
uniform float dip = 0.0;

// Salın etrafında köpük
uniform vec3 raft_pos;
uniform float raft_radius = 2.5;
// Salın çevresinde dalgalar küçülür (waves.gd ile aynı formül)
uniform float calm_radius = 0.0;

uniform sampler2D detail_a : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D detail_b : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D foam_noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

uniform vec3 deep_color : source_color = vec3(0.008, 0.06, 0.12);
uniform vec3 shallow_color : source_color = vec3(0.03, 0.26, 0.32);
uniform vec3 sss_color : source_color = vec3(0.05, 0.55, 0.5);
uniform vec3 foam_color : source_color = vec3(0.93, 0.97, 1.0);
uniform float clarity = 0.28;

varying float vh;
varying vec3 wpos;
varying float vfade;
varying float vdist;

void add_wave(vec4 w, vec2 p, inout float h, inout vec2 g) {
	vec2 d = normalize(w.xy);
	float k = 6.2831853 / w.w;
	float c = sqrt(9.8 / k);
	float ph = k * dot(d, p) - c * k * t;
	h += w.z * sin(ph);
	g += w.z * k * d * cos(ph);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = 0.0;
	vec2 g = vec2(0.0);
	add_wave(w0, wp.xz, h, g);
	add_wave(w1, wp.xz, h, g);
	add_wave(w2, wp.xz, h, g);
	add_wave(w3, wp.xz, h, g);
	float dist = distance(wp.xz, cam_pos.xz);
	float f = wave_scale * (1.0 - smoothstep(fade_start, fade_end, dist));
	if (calm_radius > 0.0) {
		f *= mix(0.22, 1.0, smoothstep(calm_radius, calm_radius + 7.0, distance(wp.xz, raft_pos.xz)));
	}
	h *= f;
	g *= f;
	VERTEX.y += h - dip * (1.0 - smoothstep(78.0, 90.0, dist));
	NORMAL = normalize(vec3(-g.x, 1.0, -g.y));
	vh = h / max(wave_scale, 0.01);
	wpos = wp;
	vfade = f;
	vdist = dist;
}

void fragment() {
	// Uzak düzlem, yakın düzlemin kapladığı alanda çizilmez: su altından bakınca ikinci bir yüzey görünmesin.
	if (dip > 0.0 && vdist < 80.0) {
		discard;
	}
	// Kayan iki katman küçük dalgacık
	vec2 uv = wpos.xz * 0.07;
	vec3 na = texture(detail_a, uv + vec2(t * 0.018, t * 0.011)).rgb;
	vec3 nb = texture(detail_b, uv * 1.9 - vec2(t * 0.013, -t * 0.02)).rgb;
	NORMAL_MAP = normalize(mix(na, nb, 0.5));
	NORMAL_MAP_DEPTH = mix(0.35, 0.9, clamp(1.0 - length(VERTEX) / 120.0, 0.0, 1.0));

	// Derinlik: suyun altındaki nesneye olan mesafe -> berraklık
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 vpos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vpos.xyz /= vpos.w;
	float thickness = max(length(vpos.xyz) - length(VERTEX), 0.0);
	float see = exp(-thickness * clarity);

	vec2 distort = NORMAL.xz * 0.03;
	vec3 under = texture(screen_tex, SCREEN_UV + distort * (1.0 - see)).rgb;

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	vec3 body = mix(deep_color, shallow_color, clamp(vh * 1.2 + 0.4, 0.0, 1.0));
	// Dalga tepelerinden süzülen ışık
	body += sss_color * smoothstep(0.1, 0.45, vh) * 0.35;

	// Köpük: dalga tepeleri + salın kenarı
	float fn = texture(foam_noise, wpos.xz * 0.12 + vec2(t * 0.02, 0.0)).r;
	float crest = smoothstep(0.38, 0.56, vh + (fn - 0.5) * 0.25) * vfade;
	float rd = distance(wpos.xz, raft_pos.xz);
	float edge = (1.0 - smoothstep(raft_radius - 0.6, raft_radius + 0.8, rd)) * smoothstep(raft_radius - 2.5, raft_radius - 0.3, rd);
	float foam = clamp(crest * 0.7 + edge * smoothstep(0.45, 0.8, fn) * 0.5, 0.0, 1.0);

	vec3 col = mix(body, under * mix(vec3(1.0), shallow_color * 2.2, 0.55), see * 0.85);
	ALBEDO = mix(col * (1.0 - fres * 0.6), foam_color, foam);
	ROUGHNESS = mix(0.02, 0.5, foam);
	SPECULAR = 0.55;
	METALLIC = 0.0;
	ALPHA = 1.0;
}
