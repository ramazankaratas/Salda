extends RefCounted
## Aletlerin, balığın ve çapanın koddan üretilen ayrıntılı modelleri.
## Elde tutulan aletler ve envanter ikonları aynı modelleri kullanır.
## Her alet +Y ekseni boyunca kurulur: sapın ucu y=0'da, aletin başı yukarıda.

const SEGS := 18

static var _mats := {}


# --- Malzemeler --------------------------------------------------------------

static func mat(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	match kind:
		"wood":
			var base := "res://assets/textures/rough_wood/rough_wood_"
			m.albedo_texture = load(base + "diff_1k.jpg")
			m.albedo_color = Color(0.95, 0.82, 0.68)
			m.normal_enabled = true
			m.normal_texture = load(base + "nor_gl_1k.jpg")
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(4, 4, 4)
			m.roughness = 0.75
		"dark_wood":
			var base := "res://assets/textures/rough_wood/rough_wood_"
			m.albedo_texture = load(base + "diff_1k.jpg")
			m.albedo_color = Color(0.55, 0.4, 0.3)
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(4, 4, 4)
			m.roughness = 0.7
		"steel":
			m.albedo_color = Color(0.72, 0.74, 0.78)
			m.metallic = 0.95
			m.roughness = 0.28
		"iron":
			m.albedo_color = Color(0.22, 0.23, 0.25)
			m.metallic = 0.85
			m.roughness = 0.5
		"rust":
			m.albedo_color = Color(0.45, 0.28, 0.18)
			m.metallic = 0.5
			m.roughness = 0.8
		"plastic":
			m.albedo_color = Color(0.95, 0.55, 0.12)
			m.roughness = 0.4
		"plastic_blue":
			m.albedo_color = Color(0.2, 0.45, 0.85)
			m.roughness = 0.4
		"rope":
			m.albedo_color = Color(0.78, 0.66, 0.44)
			m.roughness = 0.95
		"leather":
			m.albedo_color = Color(0.35, 0.22, 0.13)
			m.roughness = 0.85
		"glass":
			m.albedo_color = Color(0.4, 0.55, 0.65, 0.5)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.metallic = 0.3
			m.roughness = 0.05
		"red":
			m.albedo_color = Color(0.85, 0.12, 0.1)
			m.roughness = 0.4
		"white":
			m.albedo_color = Color(0.95, 0.95, 0.93)
			m.roughness = 0.4
		"fish":
			m.vertex_color_use_as_albedo = true
			m.roughness = 0.3
			m.metallic_specular = 0.8
		"fish_cooked":
			m.vertex_color_use_as_albedo = true
			m.albedo_color = Color(0.85, 0.55, 0.3)
			m.roughness = 0.7
	_mats[kind] = m
	return m


# --- Geometri yardımcıları ---------------------------------------------------

static func _mi(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Torna: profil [Vector2(yarıçap, y)] Y ekseni etrafında döndürülür (pürüzsüz yüzey).
static func lathe(profile: Array, segs := SEGS) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		var p0: Vector2 = profile[i]
		var p1: Vector2 = profile[i + 1]
		var slope := Vector2(p1.y - p0.y, -(p1.x - p0.x)).normalized()
		for j in segs:
			var a0 := TAU * j / segs
			var a1 := TAU * (j + 1) / segs
			# Godot ön yüzü saat yönünde: dışarıdan bakınca alt-sol → üst-sağ → alt-sağ
			var quad := [[p0, a0], [p1, a1], [p0, a1], [p0, a0], [p1, a0], [p1, a1]]
			for q in quad:
				var pp: Vector2 = q[0]
				var a: float = q[1]
				var dir := Vector3(sin(a), 0, cos(a))
				st.set_normal((dir * slope.x + Vector3.UP * slope.y).normalized())
				st.set_uv(Vector2(a / TAU, pp.y))
				st.add_vertex(Vector3(dir.x * pp.x, pp.y, dir.z * pp.x))
	return st.commit()


## Boru: noktalar boyunca dairesel kesitli tüp (kanca çatalı, çapa kolu, makara sapı).
static func tube(points: Array, radius: float, segs := 10, end_scale := 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var norms: Array = []
	var n := points.size()
	for i in n:
		var p: Vector3 = points[i]
		var t: Vector3 = (points[mini(i + 1, n - 1)] - points[maxi(i - 1, 0)]).normalized()
		var side := t.cross(Vector3.UP)
		if side.length() < 0.01:
			side = t.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(t).normalized()
		var r := radius * lerpf(1.0, end_scale, float(i) / maxf(1.0, n - 1))
		var ring: Array = []
		var nr: Array = []
		for j in segs:
			var a := TAU * j / segs
			var d := side * cos(a) + up * sin(a)
			ring.append(p + d * r)
			nr.append(d)
		rings.append(ring)
		norms.append(nr)
	for i in n - 1:
		for j in segs:
			var j2 := (j + 1) % segs
			for k in [[i, j], [i, j2], [i + 1, j2], [i, j], [i + 1, j2], [i + 1, j]]:
				st.set_normal(norms[k[0]][k[1]])
				st.add_vertex(rings[k[0]][k[1]])
	return st.commit()


## Kalınlığı ve pahlı kenarı olan düz parça (bıçak, balta ağzı, yüzgeç).
## outline: (u, v) noktaları; u, v yönlerinde, n normal yönünde kalınlık.
static func plate(outline: Array, u: Vector3, v: Vector3, thick: float, edge := 0.35) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := u.cross(v).normalized()
	var c := Vector2.ZERO
	for p in outline:
		c += p
	c /= outline.size()
	var cpt := u * c.x + v * c.y
	var cnt := outline.size()
	for i in cnt:
		var p0: Vector2 = outline[i]
		var p1: Vector2 = outline[(i + 1) % cnt]
		var a := u * p0.x + v * p0.y
		var b := u * p1.x + v * p1.y
		for s in [1.0, -1.0]:
			# Yüz (ortası kalın, kenarı ince: keskin ağız hissi)
			st.set_normal((n * s).normalized())
			st.add_vertex(cpt + n * thick * s)
			st.add_vertex(a + n * thick * edge * s)
			st.add_vertex(b + n * thick * edge * s)
		var en := ((a + b) * 0.5 - cpt).normalized()
		for q in [a + n * thick * edge, a - n * thick * edge, b + n * thick * edge, b + n * thick * edge, a - n * thick * edge, b - n * thick * edge]:
			st.set_normal(en)
			st.add_vertex(q)
	return st.commit()


## İp sargısı: yan yana birkaç halka.
static func wraps(parent: Node3D, y0: float, y1: float, r: float, count: int, m: Material) -> void:
	for i in count:
		var t := TorusMesh.new()
		t.inner_radius = r * 0.92
		t.outer_radius = r * 1.32
		t.rings = 14
		t.ring_segments = 8
		_mi(parent, t, m, Vector3(0, lerpf(y0, y1, float(i) / maxf(1, count - 1)), 0))


# --- Aletler -----------------------------------------------------------------

static func _handle(parent: Node3D, length: float, r: float, m: Material) -> void:
	_mi(parent, lathe([Vector2(0.0, 0.0), Vector2(r * 1.15, 0.01), Vector2(r * 1.2, 0.04), Vector2(r, 0.08),
		Vector2(r * 0.95, length * 0.5), Vector2(r * 0.9, length - 0.02), Vector2(0.0, length)]), m)


static func hook(metal := false) -> Node3D:
	var root := Node3D.new()
	_handle(root, 0.62, 0.022, mat("iron") if metal else mat("wood"))
	wraps(root, 0.06, 0.2, 0.024, 6, mat("leather") if metal else mat("rope"))
	var prong_mat := mat("steel") if metal else mat("plastic")
	_mi(root, lathe([Vector2(0.0, 0.6), Vector2(0.04, 0.6), Vector2(0.045, 0.66), Vector2(0.03, 0.72), Vector2(0.0, 0.73)]), prong_mat)
	var prongs := 4 if metal else 3
	for k in prongs:
		var a := TAU * k / prongs
		var dir := Vector3(sin(a), 0, cos(a))
		var pts: Array = []
		for i in 9:
			var t := float(i) / 8.0
			var out := sin(t * PI * 0.85) * 0.11
			var y := 0.68 + t * 0.12 - pow(t, 3.0) * 0.16
			pts.append(dir * (0.025 + out) + Vector3(0, y, 0))
		_mi(root, tube(pts, 0.012, 8, 0.45), prong_mat)
	var coil := TorusMesh.new()
	coil.rings = 24
	coil.ring_segments = 10
	coil.inner_radius = 0.045
	coil.outer_radius = 0.085
	_mi(root, coil, mat("rope"), Vector3(0, 0.3, 0), Vector3(PI / 2.0, 0, 0))
	return root


static func hammer_proc() -> Node3D:
	var root := Node3D.new()
	_handle(root, 0.42, 0.018, mat("wood"))
	wraps(root, 0.03, 0.13, 0.02, 5, mat("leather"))
	var head := Node3D.new()
	head.position = Vector3(0, 0.4, 0)
	head.rotation.z = PI / 2.0
	root.add_child(head)
	_mi(head, lathe([Vector2(0.0, -0.1), Vector2(0.03, -0.1), Vector2(0.032, -0.09), Vector2(0.026, -0.03), Vector2(0.03, 0.0), Vector2(0.024, 0.03)]), mat("steel"))
	# Pençe (çivi sökme ucu)
	for s in [-1.0, 1.0]:
		var pts: Array = []
		for i in 7:
			var t := float(i) / 6.0
			pts.append(Vector3(s * 0.008, 0.02 + t * 0.09, -sin(t * 1.2) * 0.035))
		_mi(head, tube(pts, 0.009, 6, 0.4), mat("steel"))
	return root


static func spear(metal := false) -> Node3D:
	var root := Node3D.new()
	_handle(root, 1.5, 0.017, mat("dark_wood") if metal else mat("wood"))
	wraps(root, 0.45, 0.6, 0.019, 7, mat("leather"))
	wraps(root, 1.46, 1.52, 0.019, 4, mat("iron") if metal else mat("rope"))
	var tip_len := 0.32 if metal else 0.22
	var blade := [Vector2(0.0, 0.0), Vector2(0.028, 0.05), Vector2(0.034 if metal else 0.03, tip_len * 0.45), Vector2(0.0, tip_len), Vector2(-0.034 if metal else -0.03, tip_len * 0.45), Vector2(-0.028, 0.05)]
	_mi(root, plate(blade, Vector3.RIGHT, Vector3.UP, 0.007, 0.25), mat("steel") if metal else mat("rust"), Vector3(0, 1.5, 0))
	if metal:
		_mi(root, lathe([Vector2(0.0, 1.47), Vector2(0.022, 1.47), Vector2(0.024, 1.52), Vector2(0.0, 1.53)]), mat("iron"))
	return root


static func rod() -> Node3D:
	var root := Node3D.new()
	_mi(root, lathe([Vector2(0.0, 0.0), Vector2(0.02, 0.01), Vector2(0.018, 0.3), Vector2(0.012, 0.8), Vector2(0.006, 1.35), Vector2(0.0, 1.37)], 12), mat("dark_wood"))
	wraps(root, 0.03, 0.22, 0.02, 7, mat("leather"))
	for y in [0.55, 0.85, 1.15, 1.34]:
		var g := TorusMesh.new()
		g.rings = 24
		g.ring_segments = 10
		g.inner_radius = 0.008
		g.outer_radius = 0.013
		_mi(root, g, mat("steel"), Vector3(0, y, 0.016), Vector3(0, 0, PI / 2.0))
	var reel := Node3D.new()
	reel.position = Vector3(0, 0.3, 0.05)
	root.add_child(reel)
	_mi(reel, lathe([Vector2(0.0, -0.025), Vector2(0.045, -0.025), Vector2(0.05, -0.015), Vector2(0.05, 0.015), Vector2(0.045, 0.025), Vector2(0.0, 0.025)]), mat("iron"), Vector3.ZERO, Vector3(0, 0, PI / 2.0))
	_mi(reel, tube([Vector3(0.03, 0, 0), Vector3(0.03, 0.045, 0.02), Vector3(0.035, 0.05, 0.05)], 0.005, 6), mat("steel"))
	var line := TorusMesh.new()
	line.rings = 24
	line.ring_segments = 10
	line.inner_radius = 0.03
	line.outer_radius = 0.042
	_mi(reel, line, mat("white"), Vector3.ZERO, Vector3(0, 0, PI / 2.0))
	return root


## Kazma: düz ahşap sap, iki yana uzanan kavisli demir baş (bir ucu sivri, bir ucu yassı).
static func pickaxe() -> Node3D:
	var root := Node3D.new()
	_handle(root, 0.68, 0.019, mat("wood"))
	wraps(root, 0.05, 0.2, 0.02, 6, mat("leather"))
	var head := Node3D.new()
	head.position.y = 0.62
	root.add_child(head)
	var pts: Array = []
	for i in 9:
		var t := float(i) / 8.0 * 2.0 - 1.0
		pts.append(Vector3(t * 0.24, -absf(t) * absf(t) * 0.06, 0))
	_mi(head, tube(pts, 0.022, 8, 0.35), mat("iron"))
	var eye := CylinderMesh.new()
	eye.top_radius = 0.03
	eye.bottom_radius = 0.03
	eye.height = 0.07
	_mi(head, eye, mat("iron"))
	_mi(head, plate([Vector2(-0.25, -0.05), Vector2(-0.2, -0.03), Vector2(-0.2, 0.0), Vector2(-0.26, -0.02)], Vector3.RIGHT, Vector3.UP, 0.02, 0.6), mat("steel"))
	return root


## Pusula: pirinç kutu, cam kapak, yön kartı (kuzey kırmızı) ve iğne ("Igne" düğümü dönerek kuzeyi gösterir).
## Kart yerel XZ düzleminde yatar; yerel -Z kartın kuzey işaretidir.
static func compass() -> Node3D:
	var root := Node3D.new()
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.78, 0.6, 0.3)
	brass.metallic = 0.9
	brass.roughness = 0.3
	_mi(root, lathe([Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.066, 0.008), Vector2(0.066, 0.024), Vector2(0.058, 0.028), Vector2(0.055, 0.012), Vector2(0.0, 0.012)], 28), brass)
	var card := StandardMaterial3D.new()
	card.albedo_color = Color(0.94, 0.91, 0.82)
	card.roughness = 0.8
	var cm := CylinderMesh.new()
	cm.top_radius = 0.054
	cm.bottom_radius = 0.054
	cm.height = 0.002
	_mi(root, cm, card, Vector3(0, 0.0135, 0))
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color(0.15, 0.12, 0.1)
	for i in 8:
		var a := TAU * i / 8.0
		var len := 0.012 if i % 2 == 0 else 0.007
		var bm := BoxMesh.new()
		bm.size = Vector3(0.002, 0.001, len)
		_mi(root, bm, ink, Vector3(sin(a) * (0.048 - len / 2.0), 0.0148, -cos(a) * (0.048 - len / 2.0)), Vector3(0, -a, 0))
	# Kuzey işareti (kırmızı üçgen)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.8, 0.12, 0.1)
	_mi(root, plate([Vector2(-0.006, -0.036), Vector2(0.006, -0.036), Vector2(0.0, -0.05)], Vector3.RIGHT, Vector3.BACK, 0.0008, 1.0), red, Vector3(0, 0.0152, 0))
	var needle := Node3D.new()
	needle.name = "Igne"
	needle.position.y = 0.017
	root.add_child(needle)
	_mi(needle, plate([Vector2(-0.004, 0.0), Vector2(0.0, -0.042), Vector2(0.004, 0.0)], Vector3.RIGHT, Vector3.BACK, 0.0012, 1.0), red)
	_mi(needle, plate([Vector2(-0.004, 0.0), Vector2(0.0, 0.042), Vector2(0.004, 0.0)], Vector3.RIGHT, Vector3.BACK, 0.0012, 1.0), mat("steel"))
	var pin := CylinderMesh.new()
	pin.top_radius = 0.004
	pin.bottom_radius = 0.004
	pin.height = 0.004
	_mi(needle, pin, brass, Vector3(0, 0.002, 0))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.8, 0.9, 1.0, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	var gm := CylinderMesh.new()
	gm.top_radius = 0.056
	gm.bottom_radius = 0.056
	gm.height = 0.002
	_mi(root, gm, glass, Vector3(0, 0.025, 0))
	return root


## Balta: hafif kavisli, alta doğru kalınlaşan, topuzlu dişbudak sap; demir göz, çelik ağız.
static func axe_proc() -> Node3D:
	var root := Node3D.new()
	var pts: Array = []
	var radii: Array = []
	for i in 17:
		var t := float(i) / 16.0
		# Sap hafifçe S kıvrımlı: altta geriye, üstte öne.
		pts.append(Vector3(0.018 * sin(t * PI * 1.4 + 0.3) - 0.008, t * 0.7, 0))
		radii.append(lerpf(0.0185, 0.014, t) + 0.004 * exp(-pow((t - 0.12) / 0.08, 2.0)))
	for i in 16:
		_mi(root, tube([pts[i], pts[i + 1]], radii[i], 12, radii[i + 1] / radii[i]), mat("wood"))
	# Topuz
	_mi(root, lathe([Vector2(0.0, -0.02), Vector2(0.02, -0.018), Vector2(0.026, -0.006), Vector2(0.024, 0.008), Vector2(0.019, 0.022), Vector2(0.0, 0.024)], 14), mat("dark_wood"), pts[0] + Vector3(0, 0.0, 0))
	wraps(root, 0.05, 0.19, 0.0195, 6, mat("leather"))
	var top: Vector3 = pts[15]
	# Demir göz (sapı saran blok) ve sırt
	var eye := CylinderMesh.new()
	eye.top_radius = 0.026
	eye.bottom_radius = 0.026
	eye.height = 0.075
	eye.radial_segments = 16
	_mi(root, eye, mat("iron"), top + Vector3(0, -0.02, 0))
	_mi(root, plate([Vector2(-0.02, -0.03), Vector2(-0.065, -0.022), Vector2(-0.07, 0.022), Vector2(-0.02, 0.03)], Vector3.RIGHT, Vector3.UP, 0.02, 0.9), mat("iron"), top + Vector3(0, -0.02, 0))
	# Ağız: boyuna doğru incelir, uca doğru sakal gibi aşağı açılır
	var blade := [Vector2(0.02, -0.03), Vector2(0.08, -0.04), Vector2(0.14, -0.075), Vector2(0.175, -0.085), Vector2(0.19, -0.03),
		Vector2(0.192, 0.02), Vector2(0.18, 0.055), Vector2(0.12, 0.04), Vector2(0.02, 0.03)]
	_mi(root, plate(blade, Vector3.RIGHT, Vector3.UP, 0.014, 0.12), mat("steel"), top + Vector3(0, -0.02, 0))
	# Sapın göze çakılan kama ucu
	_mi(root, lathe([Vector2(0.0, 0.0), Vector2(0.012, 0.0), Vector2(0.01, 0.012), Vector2(0.0, 0.014)], 10), mat("dark_wood"), top + Vector3(0, 0.02, 0))
	return root


static func binoculars_proc() -> Node3D:
	var root := Node3D.new()
	for s in [-1.0, 1.0]:
		var tb := Node3D.new()
		tb.position = Vector3(s * 0.035, 0, 0)
		root.add_child(tb)
		_mi(tb, lathe([Vector2(0.0, 0.0), Vector2(0.024, 0.0), Vector2(0.026, 0.02), Vector2(0.03, 0.06), Vector2(0.032, 0.14), Vector2(0.034, 0.16), Vector2(0.0, 0.16)]), mat("iron"))
		_mi(tb, lathe([Vector2(0.0, 0.158), Vector2(0.028, 0.158), Vector2(0.0, 0.161)]), mat("glass"))
		wraps(tb, 0.05, 0.11, 0.031, 4, mat("leather"))
	_mi(root, tube([Vector3(-0.035, 0.08, 0), Vector3(0.035, 0.08, 0)], 0.01, 8), mat("iron"))
	return root


## Pürüzsüz balık (uskumru desenli). Burun +Y yönünde.
static func fish(cooked := false) -> Node3D:
	var root := Node3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var L := 0.42
	var stations := 24
	var segs := 16
	var rings: Array = []
	var norms: Array = []
	var cols: Array = []
	for i in stations + 1:
		var t := float(i) / stations
		var r := 0.012 + 0.055 * pow(sin(PI * pow(t, 0.8)), 0.8)
		var ring: Array = []
		var nr: Array = []
		var cr: Array = []
		for j in segs:
			var a := TAU * j / segs
			var x := sin(a) * r * 0.55
			var z := cos(a) * r * 1.05
			ring.append(Vector3(x, t * L, z))
			nr.append(Vector3(sin(a) / 0.55, 0, cos(a) / 1.05).normalized())
			var top := cos(a)
			var c := Color(0.85, 0.88, 0.9).lerp(Color(0.12, 0.32, 0.4), smoothstep(-0.1, 0.4, top))
			if top > 0.25 and fmod(t * 14.0 + top * 2.0, 1.0) < 0.35:
				c = c.darkened(0.45)
			if cooked:
				c = c.lerp(Color(0.55, 0.3, 0.12), 0.65)
			cr.append(c)
		rings.append(ring)
		norms.append(nr)
		cols.append(cr)
	for i in stations:
		for j in segs:
			var j2 := (j + 1) % segs
			for k in [[i, j], [i, j2], [i + 1, j2], [i, j], [i + 1, j2], [i + 1, j]]:
				st.set_color(cols[k[0]][k[1]])
				st.set_normal(norms[k[0]][k[1]])
				st.add_vertex(rings[k[0]][k[1]])
	_mi(root, st.commit(), mat("fish_cooked") if cooked else mat("fish"))
	var fin_m := mat("iron") if not cooked else mat("rust")
	var tail := [Vector2(0.0, 0.02), Vector2(-0.06, -0.06), Vector2(-0.03, -0.01), Vector2(0.0, -0.03), Vector2(0.03, -0.01), Vector2(0.06, -0.06)]
	_mi(root, plate(tail, Vector3.BACK, Vector3.UP, 0.003, 0.4), fin_m)
	_mi(root, plate([Vector2(0.0, 0.0), Vector2(0.04, 0.06), Vector2(0.0, 0.1)], Vector3.BACK, Vector3.UP, 0.003, 0.4), fin_m, Vector3(0, 0.18, 0.05))
	for s in [-1.0, 1.0]:
		var e := SphereMesh.new()
		e.radial_segments = 20
		e.rings = 10
		e.radius = 0.008
		e.height = 0.016
		_mi(root, e, mat("iron") if cooked else mat("white"), Vector3(s * 0.026, 0.37, 0.012))
	return root


# --- Çapa --------------------------------------------------------------------

## Demir çapa: gövde, üst halka, enine çubuk, kavisli kollar ve sivri tırnaklar.
static func anchor() -> Node3D:
	var root := Node3D.new()
	var iron := mat("iron")
	_mi(root, lathe([Vector2(0.0, 0.0), Vector2(0.035, 0.02), Vector2(0.03, 0.1), Vector2(0.025, 0.85), Vector2(0.03, 0.9), Vector2(0.0, 0.92)], 14), iron)
	var ring := TorusMesh.new()
	ring.rings = 24
	ring.ring_segments = 10
	ring.inner_radius = 0.05
	ring.outer_radius = 0.075
	_mi(root, ring, iron, Vector3(0, 0.98, 0), Vector3(0, 0, PI / 2.0))
	_mi(root, tube([Vector3(-0.22, 0.78, 0), Vector3(0.22, 0.78, 0)], 0.018, 8), iron)
	for s in [-1.0, 1.0]:
		var pts: Array = []
		for i in 11:
			var a := float(i) / 10.0 * PI * 0.48
			pts.append(Vector3(s * sin(a) * 0.32, 0.32 - cos(a) * 0.32, 0))
		_mi(root, tube(pts, 0.03, 10, 0.75), iron)
		var tip := Vector3(s * 0.32, 0.3, 0)
		_mi(root, plate([Vector2(0.0, -0.06), Vector2(0.07, 0.0), Vector2(0.0, 0.12), Vector2(-0.07, 0.0)], Vector3.BACK, Vector3.UP, 0.012, 0.3), iron, tip, Vector3(0, 0, -s * 0.5))
	return root


## Meşale: ahşap sap, kumaş sarılı baş ve parlayan alev.
static func torch() -> Node3D:
	var root := Node3D.new()
	_handle(root, 0.5, 0.02, mat("wood"))
	var char_m := StandardMaterial3D.new()
	char_m.albedo_color = Color(0.12, 0.09, 0.07)
	char_m.roughness = 1.0
	_mi(root, lathe([Vector2(0.0, 0.42), Vector2(0.026, 0.42), Vector2(0.036, 0.46), Vector2(0.038, 0.53), Vector2(0.03, 0.57), Vector2(0.0, 0.58)], 14), char_m)
	wraps(root, 0.44, 0.54, 0.034, 4, mat("leather"))
	root.add_child(fire_fx(0.58, 0.075))
	return root


## Yumuşak kenarlı ışık lekesi dokusu (alev ve kıvılcımlar için).
static func glow_texture() -> Texture2D:
	if _mats.has("_glow_tex"):
		return _mats["_glow_tex"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	_mats["_glow_tex"] = t
	return t


## Canlı ateş: yukarı süzülen, büyüyüp sönen alev parçacıkları + birkaç kıvılcım.
static func fire_fx(y: float, size: float) -> Node3D:
	var root := Node3D.new()
	root.position.y = y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = glow_texture()
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.55, 0.9))
	ramp.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	ramp.add_point(0.4, Color(1.0, 0.5, 0.12, 0.7))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(0.35, 1.0))
	curve.add_point(Vector2(1.0, 0.15))
	var ct := CurveTexture.new()
	ct.curve = curve
	for kind in ["flame", "spark"]:
		var p := GPUParticles3D.new()
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3.UP
		pm.color_ramp = rt
		pm.scale_curve = ct
		if kind == "flame":
			p.amount = 24
			p.lifetime = 0.42
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = size * 0.25
			pm.spread = 12.0
			pm.initial_velocity_min = size * 2.0
			pm.initial_velocity_max = size * 3.5
			pm.gravity = Vector3.ZERO
			pm.scale_min = 0.7
			pm.scale_max = 1.2
		else:
			p.amount = 6
			p.lifetime = 1.1
			pm.spread = 25.0
			pm.initial_velocity_min = size * 4.0
			pm.initial_velocity_max = size * 7.0
			pm.gravity = Vector3(0, 0.3, 0)
			pm.scale_min = 0.12
			pm.scale_max = 0.2
		p.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(size, size)
		q.material = m
		p.draw_pass_1 = q
		root.add_child(p)
	return root


## Nazar boncuğu: lacivert cam disk, üstünde beyaz, açık mavi ve siyah halkalar (iki yüzde). Disk yerel +Z'ye bakar.
static func nazar(r: float) -> Node3D:
	var root := Node3D.new()
	var rings := [[1.0, Color(0.06, 0.2, 0.62)], [0.62, Color(0.97, 0.97, 0.95)], [0.45, Color(0.35, 0.7, 0.95)], [0.22, Color(0.03, 0.03, 0.05)]]
	for i in rings.size():
		var m := StandardMaterial3D.new()
		m.albedo_color = rings[i][1]
		m.roughness = 0.12
		m.metallic_specular = 0.8
		var c := CylinderMesh.new()
		c.top_radius = r * float(rings[i][0])
		c.bottom_radius = c.top_radius
		c.height = r * (0.28 + i * 0.03)
		c.radial_segments = 24
		_mi(root, c, m, Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
	var loop := TorusMesh.new()
	loop.rings = 24
	loop.ring_segments = 10
	loop.inner_radius = r * 0.12
	loop.outer_radius = r * 0.2
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.06, 0.2, 0.62)
	lm.roughness = 0.15
	_mi(root, loop, lm, Vector3(0, r * 1.12, 0), Vector3(0, 0, PI / 2.0))
	return root


## Poly Haven (CC0) modeli: sahne örneklenir, `offset` ve `rot` ile aletin yerel düzenine oturtulur
## (sap +Y boyunca, alt ucu orijinde; balta ağzı / çekiç başı +X).
static func _ph(name: String, offset: Vector3, rot: Vector3, scl := 1.0) -> Node3D:
	var root := Node3D.new()
	root.scale = Vector3.ONE * scl
	var holder := Node3D.new()
	holder.rotation = rot
	root.add_child(holder)
	var m: Node3D = (load("res://assets/models/%s/%s_1k.gltf" % [name, name]) as PackedScene).instantiate()
	m.position = offset
	holder.add_child(m)
	return root


## Balta: Poly Haven "Wooden Axe 02" (sap 70 cm, ağız +Z → +X'e çevrilir).
static func axe() -> Node3D:
	return _ph("wooden_axe_02", Vector3(0, 0.282, 0), Vector3(0, PI / 2.0, 0))


## Çekiç: Poly Haven "Wooden Hammer 01" (sap +Y, baş X ekseninde; 180° çevrili, 1.45 kat büyük).
static func hammer() -> Node3D:
	return _ph("wooden_hammer_01", Vector3(0, 0.124, 0), Vector3(0, PI, 0), 1.45)


## Dürbün: Poly Haven "Binoculars" (tüpler Z boyunca → +Y'ye çevrilir; göz merceği altta).
static func binoculars() -> Node3D:
	return _ph("binoculars", Vector3(0, 0.0, -0.055), Vector3(PI / 2.0, 0, 0))


## Elde tutulan / ikonlanan aletin modeli (yoksa null).
static func make(id: String) -> Node3D:
	match id:
		"kanca":
			return hook(false)
		"metal_kanca":
			return hook(true)
		"cekic":
			return hammer()
		"mizrak":
			return spear(false)
		"metal_mizrak":
			return spear(true)
		"olta":
			return rod()
		"balta":
			return axe()
		"kazma":
			return pickaxe()
		"durbun":
			return binoculars()
		"mesale":
			return torch()
		"pusula":
			return compass()
		"ham_balik":
			return fish(false)
		"pismis_balik":
			return fish(true)
	return null
