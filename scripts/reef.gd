extends RefCounted
## Ada çevresindeki resif (koddan): dallı mercanlar, beyin mercanı, yelpaze mercanı, tüp süngerler,
## dalgada salınan yosun, deniz yıldızı, deniz kestanesi; toplanan deniz yosunu ve açılan istiridyeler (inci).
## Resif adanın sığ eteğinde, 16-40 m arasında; derin yerde mercan seyrekleşir.

const ToolModels = preload("res://scripts/tool_models.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const OysterScript = preload("res://scripts/oyster.gd")
const FishSchool = preload("res://scripts/fish_school.gd")
const Merge = preload("res://scripts/merge.gd")

const CORAL_COLORS := [Color(0.95, 0.45, 0.3), Color(0.9, 0.35, 0.55), Color(0.65, 0.35, 0.8), Color(0.98, 0.7, 0.25),
	Color(0.35, 0.75, 0.7), Color(0.95, 0.85, 0.55)]

static var _mats := {}
static var _kelp_shader: Shader


static func _m(c: Color, rough := 0.85) -> StandardMaterial3D:
	var key := "%s_%.2f" % [c.to_html(), rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	_mats[key] = m
	return m


## Adanın etrafını doldurur.
static func populate(island) -> void:
	var root := Node3D.new()
	root.name = "Resif"
	island.add_child(root)
	# Mercan kümeleri: her kümede birkaç türden 6-10 mercan, araları kum
	var spots: Array = []
	for c in 12:
		spots.append(Vector2(randf() * TAU, randf_range(17.0, 36.0)))
	for i in 110:
		var sp: Vector2 = spots[i % spots.size()]
		var off := Vector2(randf_range(-3.5, 3.5), randf_range(-3.5, 3.5))
		var g: Vector3 = island._ground(cos(sp.x) * sp.y + off.x, sin(sp.x) * sp.y + off.y)
		var r: float = sp.y
		if g.y > -1.3:
			continue
		var n: Node3D
		var pick := randi() % 10
		if pick < 3:
			n = staghorn(CORAL_COLORS.pick_random())
		elif pick < 5:
			n = brain(CORAL_COLORS.pick_random())
		elif pick < 7:
			n = fan(CORAL_COLORS.pick_random())
		else:
			n = sponges(CORAL_COLORS.pick_random())
		n.position = g - Vector3(0, 0.05, 0)
		n.rotation.y = randf() * TAU
		n.scale = Vector3.ONE * randf_range(0.8, 1.4) * (1.0 if r < 30.0 else 0.75)
		root.add_child(n)
	# Salınan yosun tarlaları
	for i in 8:
		var a := randf() * TAU
		var r := randf_range(17.0, 34.0)
		for k in randi_range(5, 9):
			var o := Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
			var g: Vector3 = island._ground(cos(a) * r + o.x, sin(a) * r + o.y)
			if g.y > -1.5:
				continue
			var kelp_node := kelp(randf_range(1.2, minf(3.2, -g.y - 0.4)))
			kelp_node.position = g
			kelp_node.rotation.y = randf() * TAU
			root.add_child(kelp_node)
	# Deniz yıldızı ve deniz kestanesi
	for i in 12:
		var a := randf() * TAU
		var r := randf_range(14.0, 32.0)
		var g: Vector3 = island._ground(cos(a) * r, sin(a) * r)
		if g.y > -0.8:
			continue
		var d := starfish() if i % 2 == 0 else urchin()
		d.position = g
		d.rotation.y = randf() * TAU
		root.add_child(d)
	# Durağan resif tek ağda birleşir (yüzlerce çizim çağrısı yerine birkaç); 110 m ötesinde çizilmez
	var baked := Merge.bake(root, false, 110.0)
	if baked != null:
		baked.set_meta("nomerge", true)
	# Toplanan deniz yosunu
	for i in 6:
		var a := randf() * TAU
		var r := randf_range(16.0, 30.0)
		var g: Vector3 = island._ground(cos(a) * r, sin(a) * r)
		if g.y > -1.2:
			continue
		var p = PickupScript.new()
		p.main = island.main
		p.item = "deniz_yosunu"
		p.amount = 2
		p.position = g
		island.add_child(p)
		var kn := kelp(1.0, Color(0.45, 0.55, 0.18))
		p.add_child(kn)
	# İstiridyeler (bazılarında inci)
	for i in randi_range(4, 7):
		var a := randf() * TAU
		var r := randf_range(18.0, 36.0)
		var g: Vector3 = island._ground(cos(a) * r, sin(a) * r)
		if g.y > -1.6:
			continue
		var o = OysterScript.new()
		o.main = island.main
		o.position = g
		o.rotation.y = randf() * TAU
		island.add_child(o)
	# Balık sürüleri
	for i in 2:
		var a := randf() * TAU
		var r := randf_range(20.0, 30.0)
		var g: Vector3 = island._ground(cos(a) * r, sin(a) * r)
		var fs = FishSchool.new()
		fs.main = island.main
		fs.position = Vector3(g.x, minf(-1.2, g.y * 0.5), g.z)
		fs.color = [Color(0.95, 0.75, 0.2), Color(0.6, 0.75, 0.9), Color(0.95, 0.45, 0.3)].pick_random()
		island.add_child(fs)


## Geyik boynuzu mercanı: dallanan tüpler, uçları açık renk.
static func staghorn(c: Color) -> Node3D:
	var root := Node3D.new()
	var m := _m(c, 0.8)
	var tip := _m(c.lightened(0.35), 0.7)
	for b in randi_range(4, 7):
		var a := randf() * TAU
		var tilt := randf_range(0.15, 0.6)
		var pts := [Vector3.ZERO]
		var p := Vector3.ZERO
		var d := Vector3(cos(a) * sin(tilt), cos(tilt), sin(a) * sin(tilt))
		for k in 4:
			p += d * randf_range(0.14, 0.22)
			d = (d + Vector3(randf_range(-0.3, 0.3), 0.15, randf_range(-0.3, 0.3))).normalized()
			pts.append(p)
		ToolModels._mi(root, ToolModels.tube(pts, 0.04, 6, 0.55), m)
		var s := SphereMesh.new()
		s.radial_segments = 20
		s.rings = 10
		s.radius = 0.025
		s.height = 0.05
		ToolModels._mi(root, s, tip, p)
		# Yan dal
		var mid: Vector3 = pts[2]
		var side := (d.cross(Vector3.UP).normalized() * 0.6 + Vector3.UP).normalized()
		ToolModels._mi(root, ToolModels.tube([mid, mid + side * 0.18, mid + side * 0.3 + Vector3(0, 0.08, 0)], 0.025, 5, 0.5), m)
	return root


## Beyin mercanı: yassı küre, kıvrımlı desen (gürültü dokusu).
static func brain(c: Color) -> Node3D:
	var root := Node3D.new()
	var key := "brain_" + c.to_html()
	if not _mats.has(key):
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
		n.frequency = 0.05
		var tex := NoiseTexture2D.new()
		tex.width = 128
		tex.height = 128
		tex.seamless = true
		tex.noise = n
		var g := Gradient.new()
		g.set_color(0, c.darkened(0.45))
		g.set_color(1, c.lightened(0.15))
		tex.color_ramp = g
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(3, 3, 3)
		m.roughness = 0.9
		_mats[key] = m
	var sm := SphereMesh.new()
	sm.radial_segments = 20
	sm.rings = 10
	sm.radius = randf_range(0.25, 0.4)
	sm.height = sm.radius * 2.0
	var mi := ToolModels._mi(root, sm, _mats[key], Vector3(0, sm.radius * 0.35, 0))
	mi.scale = Vector3(1.0, 0.6, 1.0)
	return root


## Yelpaze mercanı: delikli, iki yüzlü yassı yelpaze (alfa kesimli gürültü).
static func fan(c: Color) -> Node3D:
	var root := Node3D.new()
	var key := "fan_" + c.to_html()
	if not _mats.has(key):
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.frequency = 0.08
		var tex := NoiseTexture2D.new()
		tex.width = 128
		tex.height = 128
		tex.noise = n
		var g := Gradient.new()
		g.set_color(0, Color(c, 1.0))
		g.add_point(0.42, Color(c.lightened(0.1), 1.0))
		g.add_point(0.46, Color(c, 0.0))
		g.set_color(g.get_point_count() - 1, Color(c, 0.0))
		tex.color_ramp = g
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.9
		_mats[key] = m
	var pts: Array = [Vector2(0, 0)]
	for k in 13:
		var a := lerpf(0.25, PI - 0.25, k / 12.0)
		pts.append(Vector2(cos(a) * 0.55, 0.12 + sin(a) * 0.65))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(1, pts.size() - 1):
		for v in [pts[0], pts[k], pts[k + 1]]:
			var vv: Vector2 = v
			st.set_normal(Vector3(0, 0, 1))
			st.set_uv(Vector2(vv.x + 0.6, 1.0 - vv.y) * 0.9)
			st.add_vertex(Vector3(vv.x, vv.y, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mats[key]
	root.add_child(mi)
	ToolModels._mi(root, ToolModels.tube([Vector3.ZERO, Vector3(0, 0.18, 0)], 0.025, 5), _m(c.darkened(0.3)))
	return root


## Tüp süngerler: farklı boylarda, ağzı açık borular.
static func sponges(c: Color) -> Node3D:
	var root := Node3D.new()
	var m := _m(c, 0.95)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in randi_range(3, 5):
		var h := randf_range(0.25, 0.6)
		var r := randf_range(0.06, 0.1)
		var prof := [Vector2(r * 0.8, 0.0), Vector2(r, h * 0.5), Vector2(r * 1.15, h), Vector2(r * 0.8, h), Vector2(r * 0.7, h * 0.3)]
		var off := Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15))
		var t := ToolModels._mi(root, ToolModels.lathe(prof, 10), m, off)
		t.rotation = Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
	return root


## Yosun: dalgaya göre salınan şeritler (tepe noktaları daha çok oynar).
static func kelp(h: float, col := Color(0.22, 0.45, 0.2)) -> Node3D:
	if _kelp_shader == null:
		_kelp_shader = Shader.new()
		_kelp_shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform vec4 col : source_color;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = UV.y;
	float k = h * h * 0.12;
	VERTEX.x += sin(TIME * 1.1 + w.x * 0.15 + w.z * 0.1 + h * 1.3) * k;
	VERTEX.z += cos(TIME * 0.9 + w.z * 0.15 - w.x * 0.1 + h) * k * 0.7;
}
void fragment() {
	ALBEDO = col.rgb * (0.75 + 0.25 * clamp(UV.y / 2.5, 0.0, 1.0));
	ROUGHNESS = 0.7;
}
"""
	var root := Node3D.new()
	var mkey := "kelp_" + col.to_html()
	if not _mats.has(mkey):
		var nm := ShaderMaterial.new()
		nm.shader = _kelp_shader
		nm.set_shader_parameter("col", col)
		_mats[mkey] = nm
	var sm: ShaderMaterial = _mats[mkey]
	for k in randi_range(2, 4):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var hh := h * randf_range(0.7, 1.0)
		var n := 8
		var w := randf_range(0.06, 0.1)
		var ox := randf_range(-0.12, 0.12)
		var oz := randf_range(-0.12, 0.12)
		var turn := randf() * TAU
		for i in n:
			var y0 := hh * i / n
			var y1 := hh * (i + 1) / n
			var w0 := w * (1.0 - 0.6 * float(i) / n)
			var w1 := w * (1.0 - 0.6 * float(i + 1) / n)
			var a0 := turn + i * 0.35
			var a1 := turn + (i + 1) * 0.35
			var p00 := Vector3(ox + cos(a0) * w0, y0, oz + sin(a0) * w0)
			var p01 := Vector3(ox - cos(a0) * w0, y0, oz - sin(a0) * w0)
			var p10 := Vector3(ox + cos(a1) * w1, y1, oz + sin(a1) * w1)
			var p11 := Vector3(ox - cos(a1) * w1, y1, oz - sin(a1) * w1)
			for q in [[p00, 0.0, y0], [p10, 0.0, y1], [p11, 1.0, y1], [p00, 0.0, y0], [p11, 1.0, y1], [p01, 1.0, y0]]:
				st.set_uv(Vector2(q[1], float(q[2])))
				st.add_vertex(q[0])
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = sm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root


## Deniz yıldızı: beş kollu yassı yıldız.
static func starfish() -> Node3D:
	var root := Node3D.new()
	var m := _m([Color(0.95, 0.45, 0.2), Color(0.85, 0.25, 0.3), Color(0.95, 0.7, 0.3)].pick_random(), 0.9)
	for k in 5:
		var a := TAU * k / 5.0
		ToolModels._mi(root, ToolModels.tube([Vector3(0, 0.03, 0), Vector3(cos(a) * 0.17, 0.02, sin(a) * 0.17)], 0.035, 6, 0.3), m)
	var c := SphereMesh.new()
	c.radial_segments = 20
	c.rings = 10
	c.radius = 0.05
	c.height = 0.05
	ToolModels._mi(root, c, m, Vector3(0, 0.03, 0))
	return root


## Deniz kestanesi: koyu küre, sivri dikenler.
static func urchin() -> Node3D:
	var root := Node3D.new()
	var m := _m(Color(0.12, 0.08, 0.14), 0.5)
	var s := SphereMesh.new()
	s.radial_segments = 20
	s.rings = 10
	s.radius = 0.09
	s.height = 0.14
	ToolModels._mi(root, s, m, Vector3(0, 0.06, 0))
	for k in 22:
		var d := Vector3(randf_range(-1, 1), randf_range(0.0, 1.0), randf_range(-1, 1)).normalized()
		ToolModels._mi(root, ToolModels.tube([Vector3(0, 0.06, 0) + d * 0.07, Vector3(0, 0.06, 0) + d * 0.2], 0.008, 4, 0.1), m)
	return root
