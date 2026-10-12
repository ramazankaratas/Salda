extends Node3D
## Açık denizde batık sahası: 12-20 m derinde kumlu bir sığlık ve üstünde bir batık (koddan).
## Türler: "antik" (antik ticaret gemisi: amfora yığını, sütun, bronz heykel), "balikci" (batık balıkçı teknesi),
## "yuk" (yük gemisinin kopmuş parçası ve paslı konteynerler). Ganimet noktaları sahanın kaydında tutulur.

const ToolModels = preload("res://scripts/tool_models.gd")
const Reef = preload("res://scripts/reef.gd")
const Merge = preload("res://scripts/merge.gd")
const LootScript = preload("res://scripts/loot_spot.gd")
const FishSchool = preload("res://scripts/fish_school.gd")

const NAMES := {"antik": "Antik ticaret gemisi", "balikci": "Batık balıkçı teknesi", "yuk": "Yük gemisi enkazı"}
const RADIUS := 55.0
const TOP := -13.0

var main
var site: Dictionary = {}
var kind := "antik"
var noise: FastNoiseLite
var decor: Node3D
var loot_i := 0


func height_at(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	return TOP - 9.0 * smoothstep(8.0, RADIUS, r) + noise.get_noise_2d(x, z) * 0.9


func _ready() -> void:
	kind = site.get("kind", "antik")
	noise = FastNoiseLite.new()
	noise.seed = int(site.get("seed", 1))
	noise.frequency = 0.05
	seed(int(site.get("seed", 1)))
	_build_floor()
	decor = Node3D.new()
	add_child(decor)
	match kind:
		"antik":
			_build_antique()
		"balikci":
			_build_fishing()
		_:
			_build_cargo()
	_growth()
	Merge.bake(decor, true, 150.0)
	var fs = FishSchool.new()
	fs.main = main
	fs.color = [Color(0.6, 0.75, 0.9), Color(0.95, 0.75, 0.2)].pick_random()
	fs.position = Vector3(randf_range(-8, 8), TOP + 3.0, randf_range(-8, 8))
	add_child(fs)
	randomize()


func g(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)


## Kumlu sığlık: dairesel ızgara, kenarlara doğru derinleşir.
func _build_floor() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 22
	var segs := 44
	var pts: Array = []
	for i in rings + 1:
		var r := RADIUS * pow(float(i) / rings, 1.3)
		var row: Array = []
		for j in segs:
			var a := TAU * j / segs
			row.append(g(cos(a) * r, sin(a) * r))
		pts.append(row)
	for i in rings:
		for j in segs:
			var j2 := (j + 1) % segs
			for v in [pts[i][j], pts[i + 1][j], pts[i][j2], pts[i][j2], pts[i + 1][j], pts[i + 1][j2]]:
				var vv: Vector3 = v
				st.set_uv(Vector2(vv.x, vv.z) * 0.15)
				st.add_vertex(vv)
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var base := "res://assets/textures/coast_sand_01/coast_sand_01_"
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(base + "diff_1k.jpg")
	m.albedo_color = Color(0.62, 0.62, 0.55)
	m.normal_enabled = true
	m.normal_texture = load(base + "nor_gl_1k.jpg")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)


## Ganimet noktası (açılmışsa açık hâliyle).
func _loot(k: String, x: float, z: float, yaw := 0.0) -> void:
	var l = LootScript.new()
	l.main = main
	l.site = site
	l.index = loot_i
	l.kind = k
	l.opened = (site.get("looted", []) as Array).has(loot_i)
	l.position = g(x, z) - Vector3(0, 0.08, 0)
	l.rotation.y = yaw
	add_child(l)
	loot_i += 1


func _m(c: Color, rough := 0.9, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Ahşap gövde kabuğu (U kesitli); `broken`: bir bordanın ortası çökmüş.
func _hull(parent: Node3D, length: float, beam: float, depth: float, broken: bool, mat: Material) -> Array:
	var ns := 20
	var nr := 12
	var grid: Array = []
	for i in ns + 1:
		var t := -1.0 + 2.0 * i / ns
		var b := maxf(beam * pow(maxf(1.0 - t * t, 0.0), 0.5), 0.02)
		var top := depth + 0.4 * t * t
		var row: Array = []
		for j in nr + 1:
			var phi := -PI / 2.0 + PI * j / nr
			row.append(Vector3(t * length * 0.5, top - top * cos(phi), b * sin(phi)))
		grid.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ns:
		for j in nr:
			if broken and j >= nr - 4 and i > 5 and i < ns - 4 and (j > nr - 3 or (i + j) % 3 != 0):
				continue
			for q in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]:
				st.add_vertex(grid[q[0]][q[1]])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return grid


func _wood() -> StandardMaterial3D:
	var w := StandardMaterial3D.new()
	w.albedo_texture = load("res://assets/textures/rough_wood/rough_wood_diff_1k.jpg")
	w.albedo_color = Color(0.38, 0.36, 0.3)
	w.uv1_triplanar = true
	w.uv1_scale = Vector3(0.6, 0.6, 0.6)
	w.roughness = 1.0
	w.cull_mode = BaseMaterial3D.CULL_DISABLED
	return w


## Antik ticaret gemisi: çürümüş omurga ve kaburgalar, amfora yığını, devrik sütunlar, bronz heykel, sandık.
func _build_antique() -> void:
	var wood := _wood()
	var base := g(0, 0)
	# Omurga ve kumdan çıkan kaburgalar
	ToolModels._mi(decor, ToolModels.tube([base + Vector3(-7, -0.1, 0), base + Vector3(0, 0.1, 0.3), base + Vector3(7, 0.2, 0)], 0.18, 6), wood)
	for k in 9:
		var x := -6.0 + k * 1.5
		var h := 1.2 + sin(k * 1.3) * 0.5
		for sd in [-1.0, 1.0]:
			var p0 := g(x, 0) + Vector3(0, -0.1, 0)
			ToolModels._mi(decor, ToolModels.tube([p0, p0 + Vector3(0, h * 0.5, sd * 1.2), p0 + Vector3(0.1, h, sd * 1.6)], 0.09, 5, 0.6), wood)
	# Amfora yığını (süs) ve kırılabilir amforalar
	var clay := _m(Color(0.6, 0.37, 0.24), 0.95)
	var prof := [Vector2(0.0, 0.0), Vector2(0.05, 0.02), Vector2(0.2, 0.3), Vector2(0.23, 0.52), Vector2(0.16, 0.78), Vector2(0.07, 0.88), Vector2(0.08, 1.0), Vector2(0.0, 1.0)]
	var amesh := ToolModels.lathe(prof, 12)
	for k in 34:
		var x := randf_range(-4.0, 4.0)
		var z := randf_range(-1.8, 1.8)
		var lay := k / 12
		var am := ToolModels._mi(decor, amesh, clay, g(x, z) + Vector3(0, 0.2 + lay * 0.35, 0), Vector3(PI / 2.0 + randf_range(-0.3, 0.3), randf() * TAU, 0))
		if k % 7 == 0:
			am.scale = Vector3(1.0, 0.5, 1.0)
	for k in 5:
		_loot("amfora", randf_range(-5.5, 5.5), randf_range(2.5, 4.5) * (1 if k % 2 == 0 else -1), randf() * TAU)
	# Devrik mermer sütunlar
	var marble := _m(Color(0.86, 0.84, 0.8), 0.6)
	for k in 3:
		var c := CylinderMesh.new()
		c.top_radius = 0.32
		c.bottom_radius = 0.34
		c.height = randf_range(1.6, 2.6)
		c.radial_segments = 16
		var x := randf_range(6.0, 9.0) * (1 if k % 2 == 0 else -1)
		ToolModels._mi(decor, c, marble, g(x, k * 1.5 - 1.5) + Vector3(0, 0.25, 0), Vector3(0, randf() * TAU, PI / 2.0))
	_loot("heykel", -8.0, -3.5, 0.6)
	_loot("sandik", 4.5, -3.0, 0.3)


## Batık balıkçı teknesi: yan yatmış küçük gövde, kırık direk, ağ yığınları, variller, sandık.
func _build_fishing() -> void:
	var wood := _wood()
	wood.albedo_color = Color(0.55, 0.48, 0.38)
	var hull := Node3D.new()
	hull.position = g(0, 0) + Vector3(0, 0.1, 0)
	hull.rotation = Vector3(0, 0.3, 0.45)
	decor.add_child(hull)
	var grid := _hull(hull, 8.0, 1.5, 1.4, false, wood)
	# Su hattının altı kırmızı boyalı (yarısı dökülmüş)
	var red := _m(Color(0.5, 0.16, 0.12), 0.95)
	var keel: Array = []
	for i in grid.size():
		keel.append((grid[i][grid[i].size() / 2] as Vector3) + Vector3(0, -0.02, 0))
	ToolModels._mi(hull, ToolModels.tube(keel, 0.12, 6), red)
	var paint := _m(Color(0.15, 0.32, 0.55), 0.8)
	var rail: Array = []
	for i in grid.size():
		rail.append((grid[i][0] as Vector3) + Vector3(0, 0.05, 0))
	ToolModels._mi(hull, ToolModels.tube(rail, 0.06, 5), paint)
	var cab := BoxMesh.new()
	cab.size = Vector3(1.4, 1.0, 1.4)
	ToolModels._mi(hull, cab, _m(Color(0.7, 0.7, 0.66), 0.9), Vector3(-1.5, 1.6, 0))
	# Kırık direk kumda
	ToolModels._mi(decor, ToolModels.tube([g(1.5, 2.5) + Vector3(0, 0.15, 0), g(6.0, 4.5) + Vector3(0, 0.15, 0)], 0.1, 6, 0.7), wood)
	# Sandıklar (süs)
	for k in 3:
		var b := BoxMesh.new()
		b.size = Vector3(0.5, 0.4, 0.5)
		ToolModels._mi(decor, b, ToolModels.mat("wood"), g(randf_range(-4, 4), randf_range(2.5, 4)) + Vector3(0, 0.15, 0), Vector3(0.2, randf() * TAU, 0.1))
	_loot("ag", 3.5, -2.8)
	_loot("ag", -3.0, 3.2)
	_loot("varil", 5.0, 1.5, 1.2)
	_loot("varil", -5.5, -1.5, 0.2)
	_loot("sandik", -2.0, -3.2, 0.5)


## Yük gemisinden kopan parça: paslı çelik borda duvarı, korkuluklar, dağılmış konteynerler.
func _build_cargo() -> void:
	var steel := _m(Color(0.32, 0.2, 0.15), 0.95, 0.35)
	var hullc := _m(Color(0.12, 0.18, 0.24), 0.85, 0.3)
	var wall := Node3D.new()
	wall.position = g(-2, -3) + Vector3(0, 1.5, 0)
	wall.rotation = Vector3(0.0, 0.25, 0.35)
	decor.add_child(wall)
	var plate := BoxMesh.new()
	plate.size = Vector3(14.0, 5.0, 0.25)
	ToolModels._mi(wall, plate, hullc, Vector3.ZERO)
	var band := BoxMesh.new()
	band.size = Vector3(14.05, 1.2, 0.27)
	ToolModels._mi(wall, band, _m(Color(0.5, 0.12, 0.08), 0.9, 0.3), Vector3(0, -1.9, 0))
	for k in 8:
		var rib := BoxMesh.new()
		rib.size = Vector3(0.2, 5.0, 0.6)
		ToolModels._mi(wall, rib, steel, Vector3(-6.5 + k * 1.85, 0, 0.35))
	var rail: Array = []
	for k in 12:
		rail.append(Vector3(-6.5 + k * 1.2, 2.9, 0.1 + sin(k) * 0.1))
	ToolModels._mi(wall, ToolModels.tube(rail, 0.04, 5), steel)
	for k in 12:
		ToolModels._mi(wall, ToolModels.tube([Vector3(-6.5 + k * 1.2, 2.5, 0.1), Vector3(-6.5 + k * 1.2, 2.9, 0.1)], 0.03, 4), steel)
	# Üst üste devrilmiş iki konteyner (süs)
	var cmat := _m(Color(0.5, 0.25, 0.12), 0.9, 0.3)
	for k in 2:
		var cn := Node3D.new()
		cn.position = g(6.0, 3.0) + Vector3(0, 1.1 + k * 2.2, 0)
		cn.rotation = Vector3(0, 0.4 + k * 0.5, k * 0.15)
		decor.add_child(cn)
		var cm: StandardMaterial3D = cmat if k == 0 else _m(Color(0.15, 0.35, 0.5), 0.9, 0.3)
		var b := BoxMesh.new()
		b.size = Vector3(4.8, 2.4, 2.4)
		ToolModels._mi(cn, b, cm)
		# Oluklu yan saclar ve köşe direkleri
		for r in 15:
			var rib := BoxMesh.new()
			rib.size = Vector3(0.09, 2.3, 2.48)
			ToolModels._mi(cn, rib, cm, Vector3(-2.3 + r * 0.33, 0, 0))
		for sx in [-2.38, 2.38]:
			for sz in [-1.18, 1.18]:
				var post := BoxMesh.new()
				post.size = Vector3(0.12, 2.45, 0.12)
				ToolModels._mi(cn, post, _m(Color(0.25, 0.18, 0.14), 0.9, 0.4), Vector3(sx, 0, sz))
	_loot("konteyner", -5.0, 4.0, 0.3)
	_loot("konteyner", 2.0, 6.5, 1.9)
	_loot("konteyner", 7.5, -4.0, -0.6)
	_loot("varil", -1.0, 2.0)
	_loot("sandik", 3.0, -1.0, 0.8)


## Batığı saran deniz hayatı: tüp süngerler, dallı mercanlar, yosun.
func _growth() -> void:
	for k in 26:
		var a := randf() * TAU
		var r := randf_range(3.0, 20.0)
		var n: Node3D
		match k % 4:
			0:
				n = Reef.sponges(Reef.CORAL_COLORS.pick_random())
			1:
				n = Reef.staghorn(Reef.CORAL_COLORS.pick_random())
			2:
				n = Reef.kelp(randf_range(1.0, 2.5))
			_:
				n = Reef.urchin() if k % 8 == 3 else Reef.starfish()
		n.position = g(cos(a) * r, sin(a) * r)
		n.rotation.y = randf() * TAU
		decor.add_child(n)
