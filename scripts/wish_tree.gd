extends Node3D
## Efsanevi adadaki dilek ağacı: yaşlı bir çınar. Dallarında yüzyılların renkli kurdeleleri rüzgârda salınır,
## çevresinde ateş böcekleri uçar. Oyuncu dilek kurdelesini bağlayınca hikâyenin sonu gelir.

const ToolModels = preload("res://scripts/tool_models.gd")
const Merge = preload("res://scripts/merge.gd")

const RIBBON_COLORS := [Color(0.85, 0.12, 0.12), Color(0.95, 0.95, 0.92), Color(0.2, 0.55, 0.25), Color(0.95, 0.8, 0.2), Color(0.2, 0.4, 0.8)]

var main
var tied := false
var branch_tips: Array = []
static var _ribbon_shader: Shader
static var _ribbon_mats := {}


func _ready() -> void:
	var bark := StandardMaterial3D.new()
	bark.albedo_texture = load("res://assets/textures/rough_wood/rough_wood_diff_1k.jpg")
	bark.albedo_color = Color(0.62, 0.56, 0.48)
	bark.uv1_triplanar = true
	bark.uv1_scale = Vector3(1.2, 1.2, 1.2)
	bark.roughness = 1.0
	var tree := Node3D.new()
	add_child(tree)
	# Geniş kök tabanı ve kalın gövde
	ToolModels._mi(tree, ToolModels.lathe([Vector2(0.0, -0.3), Vector2(1.5, -0.3), Vector2(1.0, 0.2), Vector2(0.75, 0.8), Vector2(0.7, 3.2), Vector2(0.0, 3.4)], 18), bark)
	# Ana dallar: dört yana kalkan, uçlarda çatallanan kollar
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		var d := Vector3(cos(a), 0, sin(a))
		var p0 := Vector3(0, 2.8 + (k % 2) * 0.5, 0)
		var p1 := p0 + d * 2.2 + Vector3(0, 1.4, 0)
		var p2 := p1 + d * 2.0 + Vector3(0, 0.6, 0)
		ToolModels._mi(tree, ToolModels.tube([p0, p0.lerp(p1, 0.5) + Vector3(0, 0.2, 0), p1, p2], 0.36, 10, 0.35), bark)
		var side := d.cross(Vector3.UP)
		ToolModels._mi(tree, ToolModels.tube([p1, p1 + side * 1.4 + Vector3(0, 0.9, 0) + d * 0.6], 0.14, 7, 0.4), bark)
		branch_tips.append(p2)
		branch_tips.append(p1 + side * 1.4 + Vector3(0, 0.9, 0) + d * 0.6)
		for t in [0.45, 0.7, 0.9]:
			branch_tips.append(p0.lerp(p1, t) if t < 0.8 else p1.lerp(p2, t - 0.3))
	# Yaprak kümeleri (çınar yeşili, kenarı seyrek)
	var leaf := _leaf_mat()
	for p in branch_tips.slice(0, 12):
		for layer in 2:
			var sm := SphereMesh.new()
			sm.radial_segments = 16
			sm.rings = 8
			sm.radius = randf_range(1.6, 2.1) * (1.0 - layer * 0.2)
			sm.height = sm.radius * 1.2
			var mi := ToolModels._mi(tree, sm, leaf, (p as Vector3) + Vector3(0, 0.9 + layer * 0.2, 0))
			mi.scale = Vector3(1.2, 0.7, 1.2)
	Merge.bake(tree, true)
	# Kurdeleler: dallardan sarkan renkli bez şeritler
	var rib_root := Node3D.new()
	add_child(rib_root)
	for i in 70:
		var tip: Vector3 = branch_tips.pick_random()
		var pos := tip + Vector3(randf_range(-0.8, 0.8), randf_range(-0.6, -0.1), randf_range(-0.8, 0.8))
		_ribbon(rib_root, pos, RIBBON_COLORS.pick_random(), randf_range(0.5, 1.0))
	Merge.bake(rib_root, false)
	# Ateş böcekleri ve dalların altında sıcak bir ışık
	add_child(_fireflies())
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.85, 0.55)
	glow.light_energy = 1.2
	glow.omni_range = 11.0
	glow.position = Vector3(0, 3.5, 0)
	add_child(glow)
	# Hedef gövdesi
	var body := StaticBody3D.new()
	body.collision_layer = 1 | 4
	body.collision_mask = 0
	body.set_meta("target", self)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.9
	cyl.height = 3.6
	cs.shape = cyl
	cs.position.y = 1.8
	body.add_child(cs)
	add_child(body)


func _leaf_mat() -> StandardMaterial3D:
	var n := FastNoiseLite.new()
	n.frequency = 0.14
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = n
	var g := Gradient.new()
	g.set_color(0, Color(0.2, 0.36, 0.14, 0.0))
	g.add_point(0.47, Color(0.2, 0.36, 0.14, 0.0))
	g.add_point(0.5, Color(0.24, 0.42, 0.16, 1.0))
	g.set_color(g.get_point_count() - 1, Color(0.45, 0.62, 0.28, 1.0))
	tex.color_ramp = g
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(1.8, 1.8, 1.8)
	m.roughness = 0.9
	return m


## Asılı kurdele: üstten sabit, alta doğru rüzgârda salınan şerit (gölgelendiricide).
func _ribbon(parent: Node3D, top: Vector3, c: Color, length: float) -> MeshInstance3D:
	if _ribbon_shader == null:
		_ribbon_shader = Shader.new()
		_ribbon_shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform vec4 col : source_color;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = UV.y * UV.y;
	VERTEX.x += sin(TIME * 2.3 + w.x * 0.9 + w.z * 0.7) * 0.18 * k;
	VERTEX.z += cos(TIME * 1.9 + w.z * 0.8) * 0.12 * k;
}
void fragment() {
	ALBEDO = col.rgb;
	ROUGHNESS = 0.9;
}
"""
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.035
	var seg := 5
	var turn := randf() * TAU
	var side := Vector3(cos(turn), 0, sin(turn)) * w
	for i in seg:
		var y0 := -length * i / seg
		var y1 := -length * (i + 1) / seg
		var v0 := float(i) / seg
		var v1 := float(i + 1) / seg
		for q in [[-1, y0, v0], [1, y0, v0], [1, y1, v1], [-1, y0, v0], [1, y1, v1], [-1, y1, v1]]:
			st.set_uv(Vector2(0.5 + 0.5 * q[0], q[2]))
			st.add_vertex(top + side * float(q[0]) + Vector3(0, float(q[1]), 0))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var key := c.to_html()
	if not _ribbon_mats.has(key):
		var nm := ShaderMaterial.new()
		nm.shader = _ribbon_shader
		nm.set_shader_parameter("col", c)
		_ribbon_mats[key] = nm
	mi.material_override = _ribbon_mats[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _fireflies() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 6.0
	p.visibility_aabb = AABB(Vector3(-8, -1, -8), Vector3(16, 10, 16))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(6, 2.5, 6)
	pm.gravity = Vector3(0, 0.05, 0)
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	p.process_material = pm
	var dot := SphereMesh.new()
	dot.radius = 0.035
	dot.height = 0.07
	dot.radial_segments = 6
	dot.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.95, 0.5)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.9, 0.4)
	m.emission_energy_multiplier = 4.0
	dot.material = m
	p.draw_pass_1 = dot
	p.position.y = 3.0
	return p


func prompt(player) -> String:
	if tied:
		return "Senin kurdelen de dalda salınıyor"
	if player.inv.count("kurdele") > 0:
		return "E: Dilek kurdeleni çınarın dalına bağla"
	return "Dilek ağacı: bir Dilek Kurdelesi gerek (Tab → Malzeme: kumaş + ip)"


func interact(player) -> void:
	if tied or player.inv.count("kurdele") <= 0:
		return
	tied = true
	# Oyuncunun kurdelesi: en alçak dalda, göz hizasında, kırmızı
	var low := Vector3(1.2, 2.6, 0.4)
	var r := _ribbon(self, low, Color(0.9, 0.1, 0.1), 1.1)
	r.scale = Vector3(1.6, 1.0, 1.6)
	main.tie_ribbon(self)
