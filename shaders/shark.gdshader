shader_type spatial;
render_mode cull_disabled;

// Yüzme hareketi: gövde boyunca ilerleyen yanal dalga; kuyruğa doğru genlik artar.
uniform float swim_t = 0.0;
uniform float swim_amp = 0.1;
uniform float body_length = 3.2;
uniform float hurt = 0.0;

void vertex() {
	float u = clamp((VERTEX.z + body_length * 0.5) / body_length, 0.0, 1.0);
	float w = pow(1.0 - u, 1.8) + 0.04;
	float phase = VERTEX.z * 2.4 + swim_t;
	VERTEX.x += sin(phase) * swim_amp * w;
	// Normali dalganın eğimine göre hafifçe döndür
	float slope = cos(phase) * swim_amp * w * 2.4;
	NORMAL = normalize(NORMAL - vec3(0.0, 0.0, 1.0) * 0.0 + vec3(-slope * NORMAL.z, 0.0, 0.0));
}

void fragment() {
	ALBEDO = mix(COLOR.rgb, vec3(0.8, 0.15, 0.1), hurt);
	ROUGHNESS = 0.32;
	SPECULAR = 0.65;
	CLEARCOAT = 0.4;
	CLEARCOAT_ROUGHNESS = 0.2;
}
