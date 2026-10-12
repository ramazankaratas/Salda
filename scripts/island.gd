extends Node3D
## Koddan üretilen ada: kumsal tepe, ağaçlar, kayalar, sığ deniz tabanı ve toplanabilir nesneler.
## Türler: "palmiye" (palmiyeler, hindistan cevizi), "kayalik" (yüksek kayalık, kazılacak taş ve demir),
## "zeytinlik" (zeytin ağaçları), "fener" (yıkık deniz feneri; onarılır). Hepsinde yengeç, martı yuvası, kum.

const Props = preload("res://scripts/props.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const PalmScript = preload("res://scripts/palm.gd")
const RockScript = preload("res://scripts/rock.gd")
const OliveScript = preload("res://scripts/olive.gd")
const CrabScript = preload("res://scripts/crab.gd")
const LighthouseScript = preload("res://scripts/lighthouse.gd")
const Crops = preload("res://scripts/crops.gd")
const Reef = preload("res://scripts/reef.gd")
const WreckScript = preload("res://scripts/wreck.gd")
const WishTreeScript = preload("res://scripts/wish_tree.gd")
const TraderScript = preload("res://scripts/trader.gd")
const ToolModels = preload("res://scripts/tool_models.gd")
const Merge = preload("res://scripts/merge.gd")

const NAMES := {"palmiye": "Palmiye adası", "kayalik": "Kayalık ada", "zeytinlik": "Zeytinlik ada", "fener": "Fener adası", "batik": "Batık kadırga koyu", "efsanevi": "Hıdırellez Adası"}

const RINGS := 56
const SEGMENTS := 72
const OUTER := 62.0

var main
var shore_radius := 13.0
var seed_value := 0
var noise: FastNoiseLite
var gull_timer := 4.0
var kind := "palmiye"
## Fener adası için kalıcı kayıt (main.landmarks içindeki sözlük)
var landmark: Dictionary = {}
var lighthouse
var wreck


func height_at(r: float, a: float) -> float:
	var n := noise.get_noise_2d(cos(a) * r, sin(a) * r)
	var peak := 3.2
	var rough := 0.5
	if kind == "kayalik":
		peak = 5.5
		rough = 1.4
	elif kind == "fener":
		peak = 4.0
		rough = 0.9
	elif kind == "batik":
		peak = 2.2
		rough = 1.1
	elif kind == "efsanevi":
		peak = 3.0
		rough = 0.35
	var h := peak * exp(-pow(r / 10.0, 2.0)) - 0.6 + n * rough * (1.0 - smoothstep(10.0, 30.0, r))
	# Fener adasında ve Hıdırellez Adası'nda tepe düzleşir
	if kind == "fener" or kind == "efsanevi":
		h = lerpf(h, peak - 0.6, 1.0 - smoothstep(2.5, 4.0, r))
	h -= 12.0 * smoothstep(13.0, 58.0, r)
	return h


func _ready() -> void:
	noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.08
	seed(seed_value)
	_build_terrain()
	_build_props()
	randomize()
	_bake_decor()
	_limit_small.call_deferred()


## Adanın betiksiz, duran süsleri (kaya yığınları, kabuklar, kamp, iskele...) tek ağa birleşir.
## Ağaçlar, fener, yengeç ve toplanabilirler betikli olduğu için ayrı kalır; daha önce birleştirilmiş
## (resif, batık) ağlar kendi görünürlük mesafeleriyle korunur.
func _bake_decor() -> void:
	for n in find_children("Birlesik", "MeshInstance3D", true, false):
		n.set_meta("nomerge", true)
	for n in find_children("*", "GeometryInstance3D", true, false):
		if (n as GeometryInstance3D).visibility_range_end > 0.0:
			n.set_meta("nomerge", true)
	if lighthouse != null:
		(lighthouse as Node).set_meta("nomerge", true)
	if wreck != null:
		(wreck as Node).set_meta("nomerge", true)
	Merge.bake(self, true)


## Küçük süs ve toplanabilirler (taş, yengeç, kabuk, eşya...) 110 m'den uzakta çizilmez.
func _limit_small() -> void:
	for n in find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if gi.visibility_range_end > 0.0:
			continue
		var sz: Vector3 = gi.get_aabb().size * gi.global_transform.basis.get_scale()
		if maxf(sz.x, maxf(sz.y, sz.z)) < 1.6:
			gi.visibility_range_end = 110.0
			gi.visibility_range_end_margin = 10.0
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for i in RINGS + 1:
		var r := OUTER * pow(float(i) / RINGS, 1.6)
		var ring: Array = []
		for j in SEGMENTS:
			var a := TAU * j / SEGMENTS
			var p := Vector3(cos(a) * r, height_at(r, a), sin(a) * r)
			ring.append(p)
		pts.append(ring)
	for i in RINGS:
		for j in SEGMENTS:
			var j2 := (j + 1) % SEGMENTS
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][j2]
			var c: Vector3 = pts[i + 1][j2]
			var d: Vector3 = pts[i + 1][j]
			for v in [a, d, b, b, d, c]:
				var vv: Vector3 = v
				# Kuru kum → ıslak kum → koyu deniz tabanı
				var col := Color(1, 1, 1)
				if kind == "efsanevi" and vv.y > 0.9:
					# Çimenli tepe
					col = Color(0.52, 0.7, 0.36).lerp(Color(0.85, 0.82, 0.62), smoothstep(1.6, 0.9, vv.y))
				if vv.y < 0.35:
					col = Color(0.72, 0.68, 0.6).lerp(Color(0.35, 0.42, 0.38), smoothstep(0.0, -6.0, vv.y))
				st.set_color(col)
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
	m.vertex_color_use_as_albedo = true
	m.normal_enabled = true
	m.normal_texture = load(base + "nor_gl_1k.jpg")
	var arm: Texture2D = load(base + "arm_1k.jpg")
	m.roughness_texture = arm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.ao_enabled = true
	m.ao_texture = arm
	m.uv1_scale = Vector3(1.0, 1.0, 1.0)
	mi.material_override = m
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)


func _ground(x: float, z: float) -> Vector3:
	var r := Vector2(x, z).length()
	var a := atan2(z, x)
	return Vector3(x, height_at(r, a), z)


func _pickup(item: String, amount: int, pos: Vector3, visual: Callable) -> void:
	var p = PickupScript.new()
	p.main = main
	p.item = item
	p.amount = amount
	p.position = pos
	add_child(p)
	visual.call(p)


## Türe özel içerik, sonra her adada ortak olanlar.
func _build_kind() -> void:
	match kind:
		"kayalik":
			for i in randi_range(6, 9):
				var a := randf() * TAU
				var r := randf_range(2.5, 10.5)
				_rock("demir" if randf() < 0.4 else "tas", _ground(cos(a) * r, sin(a) * r))
		"zeytinlik":
			for i in randi_range(4, 6):
				var a := randf() * TAU
				var r := randf_range(2.0, 9.0)
				var o = OliveScript.new()
				o.main = main
				o.position = _ground(cos(a) * r, sin(a) * r) - Vector3(0, 0.05, 0)
				add_child(o)
			for i in 2:
				var a := randf() * TAU
				var r := randf_range(4.0, 10.0)
				_rock("tas", _ground(cos(a) * r, sin(a) * r))
		"batik":
			# Koyun açığında, 5-6 m derinde yan yatmış kadırga
			var wa := randf() * TAU
			var wg := _ground(cos(wa) * 31.0, sin(wa) * 31.0)
			wreck = WreckScript.new()
			wreck.main = main
			wreck.position = wg
			wreck.rotation.y = -wa + PI / 2.0 + randf_range(-0.4, 0.4)
			add_child(wreck)
			for i in 3:
				var a := randf() * TAU
				_rock("tas", _ground(cos(a) * randf_range(3.0, 8.0), sin(a) * randf_range(3.0, 8.0)))
		"efsanevi":
			_build_legend()
		"fener":
			lighthouse = LighthouseScript.new()
			lighthouse.main = main
			lighthouse.island = self
			lighthouse.landmark = landmark
			lighthouse.position = _ground(0.0, 0.0) - Vector3(0, 0.1, 0)
			add_child(lighthouse)
			for i in 4:
				var a := randf() * TAU
				var r := randf_range(5.5, 10.5)
				_rock("demir" if i == 0 else "tas", _ground(cos(a) * r, sin(a) * r))
	# Henüz kedin yoksa palmiye ya da zeytinlik adada ıslak bir sokak kedisi bekleyebilir
	if (kind == "palmiye" or kind == "zeytinlik") and main.cat == null and randf() < 0.5:
		var kc = main.make_cat(false)
		kc.island = self
		var ka := randf() * TAU
		kc.position = _ground(cos(ka) * 7.0, sin(ka) * 7.0)
		kc.rotation.y = randf() * TAU
		add_child(kc)
	# Her adada: yengeç, martı yuvası, kum yığını
	for i in randi_range(1, 3):
		var a := randf() * TAU
		var c = CrabScript.new()
		c.main = main
		c.island = self
		c.position = _ground(cos(a) * 10.0, sin(a) * 10.0)
		add_child(c)
	var nest_mat := StandardMaterial3D.new()
	nest_mat.albedo_color = Color(0.5, 0.38, 0.22)
	var egg_mat := StandardMaterial3D.new()
	egg_mat.albedo_color = Color(0.86, 0.82, 0.7)
	for i in randi_range(1, 2):
		var a := randf() * TAU
		var r := randf_range(6.0, 10.0)
		_pickup("marti_yumurtasi", 2, _ground(cos(a) * r, sin(a) * r), func(p):
			var ring := TorusMesh.new()
			ring.rings = 24
			ring.ring_segments = 10
			ring.inner_radius = 0.1
			ring.outer_radius = 0.2
			var n := MeshInstance3D.new()
			n.mesh = ring
			n.material_override = nest_mat
			n.scale = Vector3(1, 0.5, 1)
			n.position.y = 0.04
			p.add_child(n)
			for k in 2:
				var e := MeshInstance3D.new()
				var em := SphereMesh.new()
				em.radial_segments = 20
				em.rings = 10
				em.radius = 0.045
				em.height = 0.11
				e.mesh = em
				e.material_override = egg_mat
				e.position = Vector3((k - 0.5) * 0.08, 0.07, 0.0)
				e.rotation.z = (k - 0.5) * 0.6
				p.add_child(e))
	var sand := StandardMaterial3D.new()
	sand.albedo_color = Color(0.86, 0.78, 0.6)
	sand.roughness = 1.0
	for i in 2:
		var a := randf() * TAU
		var r := randf_range(10.0, 12.0)
		_pickup("kum", 3, _ground(cos(a) * r, sin(a) * r), func(p):
			var m := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radial_segments = 20
			sm.rings = 10
			sm.radius = 0.45
			sm.height = 0.5
			m.mesh = sm
			m.material_override = sand
			m.scale = Vector3(1, 0.35, 1)
			p.add_child(m))


## Hıdırellez Adası: tepede dilek çınarı, gül çalıları, Hıdırellez ateşi, taş halka, fenerler;
## kıyıda Rıza Kaptan'ın Mavi Yolcu'su demirli.
func _build_legend() -> void:
	var tree = WishTreeScript.new()
	tree.main = main
	tree.position = _ground(0.0, 0.0) - Vector3(0, 0.05, 0)
	add_child(tree)
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.22, 0.42, 0.18)
	leaf.roughness = 0.9
	var rose := StandardMaterial3D.new()
	rose.albedo_color = Color(0.85, 0.1, 0.18)
	rose.roughness = 0.6
	for i in 7:
		var a := TAU * i / 7.0 + 0.2
		var g := _ground(cos(a) * 6.5, sin(a) * 6.5)
		var bush := Node3D.new()
		bush.position = g
		add_child(bush)
		for k in 4:
			var sm := SphereMesh.new()
			sm.radial_segments = 12
			sm.rings = 6
			sm.radius = randf_range(0.3, 0.45)
			sm.height = sm.radius * 1.6
			ToolModels._mi(bush, sm, leaf, Vector3(randf_range(-0.3, 0.3), 0.3, randf_range(-0.3, 0.3)))
		for k in 6:
			var rs := SphereMesh.new()
			rs.radial_segments = 8
			rs.rings = 4
			rs.radius = 0.06
			rs.height = 0.1
			ToolModels._mi(bush, rs, rose, Vector3(randf_range(-0.4, 0.4), randf_range(0.4, 0.75), randf_range(-0.4, 0.4)))
	# Hıdırellez ateşi: odun yığını ve alev, çevresinde taş halka
	var fa := 2.4
	var fg := _ground(cos(fa) * 8.5, sin(fa) * 8.5)
	var fire := Node3D.new()
	fire.position = fg
	add_child(fire)
	var log_m := StandardMaterial3D.new()
	log_m.albedo_color = Color(0.3, 0.2, 0.12)
	for k in 5:
		var a := TAU * k / 5.0
		ToolModels._mi(fire, ToolModels.tube([Vector3(cos(a) * 0.5, 0.05, sin(a) * 0.5), Vector3(0, 0.6, 0)], 0.06, 6), log_m)
	fire.add_child(ToolModels.fire_fx(0.25, 1.4))
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.6, 0.25)
	fl.light_energy = 2.5
	fl.omni_range = 9.0
	fl.position.y = 0.8
	fire.add_child(fl)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.55, 0.53, 0.5)
	stone.roughness = 1.0
	for k in 10:
		var a := TAU * k / 10.0
		var sm := SphereMesh.new()
		sm.radial_segments = 8
		sm.rings = 4
		sm.radius = 0.18
		sm.height = 0.24
		ToolModels._mi(fire, sm, stone, Vector3(cos(a) * 1.0, 0.05, sin(a) * 1.0))
	# Tepeyi çevreleyen küçük fenerler (gece yanar)
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(1.0, 0.85, 0.5)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.7, 0.35)
	lamp.emission_energy_multiplier = 2.0
	var post := StandardMaterial3D.new()
	post.albedo_color = Color(0.35, 0.25, 0.16)
	for k in 5:
		var a := TAU * k / 5.0 + 0.6
		var g := _ground(cos(a) * 9.5, sin(a) * 9.5)
		ToolModels._mi(self, ToolModels.tube([g, g + Vector3(0, 1.4, 0)], 0.04, 6), post)
		var ls := SphereMesh.new()
		ls.radial_segments = 10
		ls.rings = 5
		ls.radius = 0.12
		ls.height = 0.24
		ToolModels._mi(self, ls, lamp, g + Vector3(0, 1.5, 0))
	# Kıyıda demirli Mavi Yolcu ve çınarın yanında beklemeye çıkmış Rıza Kaptan
	var ba := 4.0
	var boat = TraderScript.new()
	boat.main = main
	boat.fixed = true
	boat.position = Vector3(cos(ba) * 17.0, 0.0, sin(ba) * 17.0)
	boat.rotation.y = -ba
	add_child(boat)


func _rock(k: String, g: Vector3) -> void:
	var rk = RockScript.new()
	rk.main = main
	rk.island = self
	rk.kind = k
	rk.position = g
	add_child(rk)


func _build_props() -> void:
	_build_kind()
	var coconut_mat := StandardMaterial3D.new()
	coconut_mat.albedo_color = Color(0.36, 0.24, 0.14)
	coconut_mat.roughness = 0.8
	var palms: int = randi_range(3, 5) if kind == "palmiye" else (randi_range(1, 2) if kind != "fener" else 1)
	for i in palms:
		var a := randf() * TAU
		var r := randf_range(2.0 if kind != "fener" else 6.0, 8.5)
		var g := _ground(cos(a) * r, sin(a) * r)
		var palm = PalmScript.new()
		palm.main = main
		palm.island = self
		palm.position = g - Vector3(0, 0.05, 0)
		palm.rotation.y = randf() * TAU
		palm.scale = Vector3.ONE * randf_range(0.9, 1.15)
		add_child(palm)
		for k in 2:
			var ca := randf() * TAU
			var cp := _ground(g.x + cos(ca) * 1.4, g.z + sin(ca) * 1.4)
			_pickup("hindistan_cevizi", 1, cp, func(p):
				var s := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radial_segments = 20
				sm.rings = 10
				sm.radius = 0.12
				sm.height = 0.22
				s.mesh = sm
				s.material_override = coconut_mat
				s.position.y = 0.1
				p.add_child(s))
	for i in 4:
		var a := randf() * TAU
		var r := randf_range(3.0, 10.0)
		var g := _ground(cos(a) * r, sin(a) * r)
		_pickup("yaprak", 2, g, func(p):
			var b := PalmScript.frond_bundle(3, 1.1)
			b.rotation.y = randf() * TAU
			b.position.y = 0.05
			p.add_child(b))
	for i in 2:
		var a := randf() * TAU
		var g := _ground(cos(a) * 11.0, sin(a) * 11.0)
		_pickup("plastik", 2, g, func(p): Props.place(p, "res://assets/models/plastic_crate_01/plastic_crate_01_1k.gltf", Vector3.ZERO, Vector3(0.2, randf() * TAU, 0.1), 1.2))
	var sack := StandardMaterial3D.new()
	sack.albedo_color = Color(0.62, 0.52, 0.34)
	for i in 2:
		var a := randf() * TAU
		var g := _ground(cos(a) * 5.0, sin(a) * 5.0)
		var sd: String = ["tohum", "domates_tohumu", "biber_tohumu", "karpuz_tohumu"].pick_random()
		_pickup(sd, 2, g, func(p):
			var pouch := Crops.seed_pouch(sd)
			pouch.scale = Vector3.ONE * 1.4
			pouch.rotation.y = randf() * TAU
			p.add_child(pouch))
	# Zeytinlikte zeytin fidanı
	if kind == "zeytinlik":
		for i in 2:
			var a := randf() * TAU
			var g := _ground(cos(a) * 6.0, sin(a) * 6.0)
			_pickup("zeytin_fidani", 1, g, func(p):
				var f := Crops.seed_pouch("zeytin_fidani")
				f.scale = Vector3.ONE * 1.6
				p.add_child(f))
	# Kayalar (kıyı ve su altı)
	for i in 6:
		var a := randf() * TAU
		var r := randf_range(9.0, 26.0)
		var g := _ground(cos(a) * r, sin(a) * r)
		var rock := Props.place(self, "res://assets/models/boulder_01/boulder_01_1k.gltf", g - Vector3(0, 0.3, 0), Vector3(0, randf() * TAU, 0), randf_range(1.0, 2.2))
		var rb := StaticBody3D.new()
		var rcs := CollisionShape3D.new()
		var rs := SphereShape3D.new()
		rs.radius = 0.7
		rcs.shape = rs
		rcs.position.y = 0.5
		rb.add_child(rcs)
		rock.add_child(rb)
	# Resif: mercanlar, yosun, istiridye, balık sürüleri
	Reef.populate(self)
	# Deniz tabanında hurda (dalış gerekir)
	var scrap := StandardMaterial3D.new()
	scrap.albedo_color = Color(0.35, 0.3, 0.27)
	scrap.metallic = 0.7
	scrap.roughness = 0.6
	for i in 6:
		var a := randf() * TAU
		var r := randf_range(17.0, 30.0)
		var g := _ground(cos(a) * r, sin(a) * r)
		_pickup("hurda", 2, g, func(p):
			var s := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.5, 0.2, 0.35)
			s.mesh = b
			s.material_override = scrap
			s.rotation = Vector3(0.2, randf() * TAU, 0.3)
			s.position.y = 0.1
			p.add_child(s))


func _process(delta: float) -> void:
	if main.paused:
		return
	gull_timer -= delta
	if gull_timer <= 0.0:
		gull_timer = randf_range(14.0, 30.0)
		if global_position.distance_to(main.player.global_position) < 80.0:
			main.audio.play_at("seagull", global_position + Vector3(randf_range(-8, 8), 10, randf_range(-8, 8)), -4.0, 25.0)
