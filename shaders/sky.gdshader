shader_type sky;
render_mode use_debanding;

// Gündüz/gece gökyüzü: renk geçişi, gün batımı, güneş, ay, yıldızlar ve hareketli bulutlar.
uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;
uniform float cloud_cover = 0.45;
uniform float cloud_dark = 0.0;
uniform float time = 0.0;
uniform vec3 moon_dir = vec3(0.0, 1.0, 0.0);
// Kutup Yıldızı: kuzeyde (-Z), Ege enlemine göre ufkun ~38° üstünde
uniform vec3 polaris_dir = vec3(0.0, 0.616, -0.788);
uniform float flash = 0.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 sun = LIGHT0_ENABLED ? LIGHT0_DIRECTION : vec3(0.0, -1.0, 0.0);
	float day = smoothstep(-0.18, 0.22, sun.y);
	float night = 1.0 - day;
	float h = clamp(d.y, 0.0, 1.0);

	vec3 zenith = mix(vec3(0.004, 0.008, 0.025), vec3(0.16, 0.38, 0.74), day);
	vec3 horizon = mix(vec3(0.025, 0.04, 0.075), vec3(0.62, 0.77, 0.9), day);
	vec3 col = mix(horizon, zenith, pow(h, 0.45));

	// Gün doğumu / batımı: güneşe yakın ufuk turuncuya döner.
	float dusk = 1.0 - smoothstep(0.0, 0.32, abs(sun.y));
	vec3 dusk_col = vec3(1.0, 0.42, 0.16);
	float toward = max(dot(d, sun), 0.0);
	col += dusk_col * dusk * pow(toward, 3.0) * (1.0 - h) * 0.95;
	col = mix(col, col * vec3(1.0, 0.85, 0.8), dusk * 0.3);

	// Ufkun altı (deniz yansıması için)
	if (d.y < 0.0) {
		col = mix(horizon, horizon * 0.55, clamp(-d.y * 3.0, 0.0, 1.0));
	}

	// Güneş diski ve parıltısı
	float sd = dot(d, sun);
	col += vec3(1.0, 0.92, 0.75) * smoothstep(0.99935, 0.99965, sd) * 18.0 * day;
	col += vec3(1.0, 0.8, 0.6) * pow(max(sd, 0.0), 220.0) * 1.2 * day;
	col += vec3(1.0, 0.7, 0.45) * pow(max(sd, 0.0), 12.0) * 0.12 * day;

	// Ay ve yıldızlar
	float md = dot(d, normalize(moon_dir));
	col += vec3(0.82, 0.86, 1.0) * smoothstep(0.9991, 0.9995, md) * night * 2.5;
	col += vec3(0.5, 0.6, 0.9) * pow(max(md, 0.0), 300.0) * night * 0.3;
	if (d.y > 0.0) {
		vec3 sp = floor(d * 380.0);
		float s = hash(sp);
		float twinkle = 0.6 + 0.4 * sin(time * 3.0 + s * 50.0);
		col += vec3(1.0) * step(0.9975, s) * night * twinkle * smoothstep(0.0, 0.2, d.y) * (1.0 - cloud_dark);
	}

	// Kutup Yıldızı: diğerlerinden parlak, hafif ışıltılı; kuzeyi gösterir
	float pd = dot(d, normalize(polaris_dir));
	col += vec3(0.92, 0.95, 1.0) * (smoothstep(0.999985, 0.999995, pd) * 3.0 + pow(max(pd, 0.0), 40000.0) * 0.5) * night * (1.0 - cloud_dark);

	// Bulutlar: gökyüzü düzlemine yansıtılmış iki katmanlı gürültü.
	if (d.y > 0.0) {
		vec2 uv = d.xz / (d.y + 0.12) * 0.07;
		vec2 drift = vec2(time * 0.004, time * 0.0015);
		float n = texture(cloud_noise, uv + drift).r * 0.65 + texture(cloud_noise, uv * 2.6 + drift * 1.7 + 0.37).r * 0.35;
		float c = smoothstep(1.0 - cloud_cover - 0.12, 1.0 - cloud_cover + 0.28, n);
		c *= smoothstep(0.0, 0.12, d.y);
		vec3 lit = mix(vec3(0.04, 0.05, 0.07), vec3(1.0, 0.99, 0.97), day);
		lit = mix(lit, dusk_col * 1.25, dusk * 0.55 * pow(toward, 1.5));
		lit *= mix(1.0, 0.5, smoothstep(0.55, 1.0, n));
		lit = mix(lit, lit * vec3(0.38, 0.4, 0.45), cloud_dark);
		col = mix(col, lit, c * 0.96);
		col = mix(col, col * 0.55, cloud_dark * 0.6);
	}
	// Şimşek: gökyüzü ve bulutlar bir an aydınlanır
	col += vec3(0.75, 0.8, 1.0) * flash * (0.6 + 0.4 * max(d.y, 0.0));
	COLOR = col;
}
