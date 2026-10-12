extends SubViewport
## Eşya ikonları: her eşyanın 3B görünümü küçük bir sahnede çekilip dokuya dönüştürülür.
## Oyun açılırken (menü arkasında) bir kez üretilir; hazır olana kadar renkli kare gösterilir.

const Items = preload("res://scripts/items.gd")
const OysterScript = preload("res://scripts/oyster.gd")
const Reef = preload("res://scripts/reef.gd")
const Props = preload("res://scripts/props.gd")
const BuildingScript = preload("res://scripts/building.gd")
const ToolModels = preload("res://scripts/tool_models.gd")
const PalmScript = preload("res://scripts/palm.gd")
const Crops = preload("res://scripts/crops.gd")

const SIZE := 128

static var cache := {}
static var ready_done := false

var main
var stage: Node3D
var cam: Camera3D


func _ready() -> void:
	size = Vector2i(SIZE, SIZE)
	transparent_bg = true
	own_world_3d = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	msaa_3d = Viewport.MSAA_4X
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, -35, 0)
	key.light_energy = 1.6
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.5
	add_child(fill)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(cam)
	stage = Node3D.new()
	add_child(stage)


static func get_icon(id: String) -> Texture2D:
	return cache.get(id, null)


func _mat(c: Color, metal := 0.0, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


func _mesh(mesh: Mesh, pos: Vector3, rot: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	stage.add_child(mi)


func _mesh_ret(mesh: Mesh, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	stage.add_child(mi)
	return mi


func _cyl(r: float, h: float, r2 := -1.0) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r if r2 < 0.0 else r2
	c.height = h
	return c


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _sphere(r: float, h: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radial_segments = 20
	s.rings = 10
	s.radius = r
	s.height = h
	return s


## Eşyanın ikon sahnesini kurar.
func _build(id: String) -> void:
	# Ayrıntılı alet / balık modeli varsa onu kullan (elde tutulanla aynı).
	var tm := ToolModels.make(id)
	if tm != null:
		stage.add_child(tm)
		if id.contains("balik"):
			tm.rotation = Vector3(0, 0, PI / 2.0)
		else:
			tm.rotation = Vector3(0, 0, -0.75)
		return
	var wood := _mat(Color(0.55, 0.38, 0.22))
	var metal := _mat(Color(0.55, 0.56, 0.6), 0.85, 0.35)
	var rope := _mat(Color(0.78, 0.66, 0.42), 0.0, 0.9)
	match id:
		"tahta":
			for i in 3:
				_mesh(_box(Vector3(1.0, 0.07, 0.2)), Vector3(0, i * 0.08, (i - 1) * 0.12), Vector3(0, 0.15 * (i - 1), 0), main.raft.mat_plank)
		"plastik":
			Props.place(stage, "res://assets/models/plastic_bottle_gallon/plastic_bottle_gallon_1k.gltf", Vector3.ZERO, Vector3.ZERO, 3.0, "center")
		"su_sise":
			var bottle := Props.place(stage, "res://assets/models/plastic_bottle_gallon/plastic_bottle_gallon_1k.gltf", Vector3.ZERO, Vector3.ZERO, 3.0, "center")
			Props.tint(bottle, Color(0.45, 0.72, 1.0))
		"yaprak":
			stage.add_child(PalmScript.frond_bundle(3, 1.0))
		"ip":
			for i in 3:
				var t := TorusMesh.new()
				t.rings = 24
				t.ring_segments = 10
				t.inner_radius = 0.18 - i * 0.04
				t.outer_radius = 0.26 - i * 0.04
				_mesh(t, Vector3(0, i * 0.05, 0), Vector3(0.2, 0, 0), rope)
		"hurda":
			_mesh(_box(Vector3(0.5, 0.12, 0.35)), Vector3.ZERO, Vector3(0.2, 0.4, 0.1), _mat(Color(0.42, 0.35, 0.3), 0.7, 0.6))
			_mesh(_cyl(0.06, 0.5), Vector3(0.1, 0.12, 0.05), Vector3(0, 0.6, PI / 2.0), metal)
			_mesh(_box(Vector3(0.22, 0.04, 0.22)), Vector3(-0.15, 0.1, -0.1), Vector3(0.4, 0.2, 0.0), _mat(Color(0.5, 0.3, 0.2), 0.6, 0.7))
		"tohum", "domates_tohumu", "biber_tohumu", "karpuz_tohumu", "zeytin_fidani":
			var pouch := Crops.seed_pouch(id)
			pouch.rotation.y = -0.4
			stage.add_child(pouch)
		"domates":
			var red := _mat(Color(0.85, 0.12, 0.08), 0.0, 0.3)
			for i in 2:
				var tom := _mesh_ret(_sphere(0.17, 0.3), Vector3((i - 0.5) * 0.3, 0.0, i * 0.06), Vector3.ZERO, red)
				tom.scale = Vector3(1.0, 0.85, 1.0)
				_mesh(_cyl(0.015, 0.05), Vector3((i - 0.5) * 0.3, 0.14, i * 0.06), Vector3.ZERO, _mat(Color(0.25, 0.45, 0.18), 0.0, 0.8))
		"biber":
			for i in 3:
				var col: Color = [Color(0.85, 0.15, 0.08), Color(0.2, 0.55, 0.15), Color(0.95, 0.75, 0.1)][i]
				var pm := _mesh_ret(_sphere(0.07, 0.4), Vector3((i - 1) * 0.15, 0.0, 0.0), Vector3(0, 0, 0.4 - i * 0.3), _mat(col, 0.0, 0.3))
				pm.scale = Vector3(1.0, 1.0, 1.0)
		"karpuz":
			var img := Image.create(32, 8, false, Image.FORMAT_RGB8)
			for x in 32:
				for y in 8:
					img.set_pixel(x, y, Color(0.15, 0.4, 0.15) if (x / 3) % 2 == 0 else Color(0.35, 0.6, 0.28))
			var mel := StandardMaterial3D.new()
			mel.albedo_texture = ImageTexture.create_from_image(img)
			var wm := _mesh_ret(_sphere(0.3, 0.6), Vector3.ZERO, Vector3(0, 0.4, PI / 2.0), mel)
			wm.scale = Vector3(1.0, 1.3, 1.0)
			var slice := _mesh_ret(_sphere(0.16, 0.32), Vector3(0.32, -0.12, 0.2), Vector3.ZERO, _mat(Color(0.9, 0.25, 0.25), 0.0, 0.5))
			slice.scale = Vector3(1.0, 0.25, 1.0)
		"hindistan_cevizi":
			_mesh(_sphere(0.3, 0.55), Vector3.ZERO, Vector3.ZERO, _mat(Color(0.38, 0.25, 0.14), 0.0, 0.9))
		"ham_balik", "pismis_balik":
			var f := Props.place(stage, "res://assets/models/q_fish_tuna/fish_tuna.glb", Vector3.ZERO, Vector3(0, PI / 2.0, 0), 0.5, "center")
			if id == "pismis_balik":
				Props.tint(f, Color(0.8, 0.5, 0.25))
		"patates", "pismis_patates":
			var col := Color(0.72, 0.58, 0.34) if id == "patates" else Color(0.55, 0.35, 0.16)
			for i in 2:
				_mesh(_sphere(0.17, 0.26), Vector3((i - 0.5) * 0.3, 0, i * 0.1), Vector3(0, i, 0.3), _mat(col, 0.0, 0.85))
		"civi":
			for i in 5:
				var n := Node3D.new()
				n.position = Vector3((i - 2) * 0.07, 0, sin(i * 1.7) * 0.05)
				n.rotation = Vector3(0.3 * sin(i), 0, 0.5 + i * 0.2)
				stage.add_child(n)
				ToolModels._mi(n, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.006, 0.03), Vector2(0.006, 0.22), Vector2(0.02, 0.22), Vector2(0.02, 0.235), Vector2(0.0, 0.24)], 10), ToolModels.mat("steel"))
		"kumas":
			for i in 3:
				_mesh(_box(Vector3(0.5, 0.04, 0.4)), Vector3(i * 0.02, i * 0.045, i * 0.03), Vector3(0, i * 0.15, 0), _mat(Color(0.86, 0.8, 0.64).darkened(i * 0.06), 0.0, 0.95))
			_mesh(_cyl(0.012, 0.42), Vector3(0, 0.14, 0), Vector3(0, 0, PI / 2.0), rope)
		"metal_kulce":
			for i in 3:
				var p := Vector3([-0.11, 0.11, 0.0][i], [0.0, 0.0, 0.09][i], [0.0, 0.0, 0.0][i])
				ToolModels._mi(stage, ToolModels.plate([Vector2(-0.1, -0.05), Vector2(0.1, -0.05), Vector2(0.08, 0.05), Vector2(-0.08, 0.05)], Vector3.RIGHT, Vector3.BACK, 0.04, 0.7), ToolModels.mat("steel"), p)
		"balik_corbasi":
			ToolModels._mi(stage, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.16, 0.0), Vector2(0.22, 0.08), Vector2(0.25, 0.16), Vector2(0.23, 0.16), Vector2(0.0, 0.16)], 20), _mat(Color(0.75, 0.72, 0.68), 0.0, 0.35))
			_mesh(_cyl(0.225, 0.01), Vector3(0, 0.145, 0), Vector3.ZERO, _mat(Color(0.85, 0.55, 0.25), 0.0, 0.3))
			for i in 4:
				_mesh(_sphere(0.03, 0.05), Vector3(cos(i * 1.6) * 0.1, 0.155, sin(i * 1.6) * 0.1), Vector3.ZERO, _mat(Color(0.9, 0.85, 0.7)))
		"konserve":
			_mesh(_cyl(0.18, 0.36), Vector3.ZERO, Vector3.ZERO, metal)
			_mesh(_cyl(0.185, 0.22), Vector3.ZERO, Vector3.ZERO, _mat(Color(0.8, 0.2, 0.15)))
		"temiz_su":
			# Emaye kamp kupası: beyaz gövde, lacivert kenar, kulp ve içinde temiz su.
			var enamel := _mat(Color(0.93, 0.93, 0.9), 0.0, 0.25)
			var rim := _mat(Color(0.12, 0.2, 0.42), 0.3, 0.3)
			ToolModels._mi(stage, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.14, 0.01), Vector2(0.15, 0.3),
				Vector2(0.135, 0.3), Vector2(0.125, 0.02), Vector2(0.0, 0.02)], 28), enamel, Vector3(0, -0.15, 0))
			var band := TorusMesh.new()
			band.inner_radius = 0.135
			band.outer_radius = 0.152
			band.rings = 28
			_mesh(band, Vector3(0, 0.15, 0), Vector3.ZERO, rim)
			var handle := TorusMesh.new()
			handle.rings = 24
			handle.ring_segments = 10
			handle.inner_radius = 0.05
			handle.outer_radius = 0.075
			_mesh(handle, Vector3(0.16, 0.0, 0), Vector3(PI / 2.0, 0, 0), enamel)
			var water := _mat(Color(0.3, 0.62, 0.9), 0.0, 0.05)
			water.metallic_specular = 0.9
			_mesh(_cyl(0.132, 0.01), Vector3(0, 0.1, 0), Vector3.ZERO, water)
		"kanca":
			_mesh(_cyl(0.03, 0.8), Vector3(0, -0.1, 0), Vector3(0, 0, 0.5), wood)
			var t1 := TorusMesh.new()
			t1.rings = 24
			t1.ring_segments = 10
			t1.inner_radius = 0.12
			t1.outer_radius = 0.18
			_mesh(t1, Vector3(0.2, 0.3, 0), Vector3(PI / 2.0, 0, 0), metal)
			var t2 := TorusMesh.new()
			t2.rings = 24
			t2.ring_segments = 10
			t2.inner_radius = 0.08
			t2.outer_radius = 0.14
			_mesh(t2, Vector3(-0.05, -0.05, 0), Vector3.ZERO, rope)
		"cekic":
			_mesh(_cyl(0.035, 0.75), Vector3.ZERO, Vector3(0, 0, -0.6), wood)
			_mesh(_box(Vector3(0.3, 0.12, 0.12)), Vector3(0.22, 0.3, 0), Vector3(0, 0, -0.6), metal)
		"mizrak":
			_mesh(_cyl(0.025, 1.3), Vector3.ZERO, Vector3(0, 0, -0.8), wood)
			_mesh(_cyl(0.0, 0.25, 0.05), Vector3(0.52, 0.37, 0), Vector3(0, 0, -0.8), metal)
		"olta":
			_mesh(_cyl(0.015, 1.3, 0.03), Vector3.ZERO, Vector3(0, 0, -0.7), wood)
			_mesh(_cyl(0.07, 0.08), Vector3(-0.25, -0.2, 0), Vector3(PI / 2.0, 0, 0), metal)
			_mesh(_sphere(0.06, 0.12), Vector3(0.55, -0.1, 0), Vector3.ZERO, _mat(Color(0.9, 0.15, 0.1)))
		"p_zemin":
			_mesh(_box(Vector3(1.5, 0.12, 1.5)), Vector3.ZERO, Vector3.ZERO, main.raft.mat_plank)
			for z in [-0.62, 0.62]:
				_mesh(_cyl(0.1, 1.5), Vector3(0, -0.14, z), Vector3(0, 0, PI / 2.0), main.raft.mat_log)
		"p_guclendir":
			_mesh(_box(Vector3(1.5, 0.12, 1.5)), Vector3.ZERO, Vector3.ZERO, main.raft.mat_plank)
			var ir := _mat(Color(0.36, 0.37, 0.4), 0.8, 0.45)
			for sd in [-1.0, 1.0]:
				_mesh(_box(Vector3(1.5, 0.03, 0.1)), Vector3(0, 0.07, sd * 0.7), Vector3.ZERO, ir)
				_mesh(_box(Vector3(0.1, 0.03, 1.5)), Vector3(sd * 0.7, 0.07, 0), Vector3.ZERO, ir)
			for sx in [-0.62, 0.62]:
				for sz in [-0.62, 0.62]:
					_mesh(_cyl(0.03, 0.03), Vector3(sx, 0.09, sz), Vector3.ZERO, _mat(Color(0.2, 0.2, 0.22), 0.85, 0.5))
		"p_duvar", "p_kapi", "p_pencere":
			var plank: StandardMaterial3D = main.raft.mat_plank
			var frame: StandardMaterial3D = main.raft.mat_frame
			if id == "p_duvar":
				_mesh(_box(Vector3(1.5, 2.4, 0.08)), Vector3(0, 1.2, 0), Vector3.ZERO, plank)
			elif id == "p_kapi":
				for sx in [-0.605, 0.605]:
					_mesh(_box(Vector3(0.29, 2.4, 0.08)), Vector3(sx, 1.2, 0), Vector3.ZERO, plank)
				_mesh(_box(Vector3(0.92, 0.36, 0.08)), Vector3(0, 2.22, 0), Vector3.ZERO, plank)
			else:
				_mesh(_box(Vector3(1.5, 1.0, 0.08)), Vector3(0, 0.5, 0), Vector3.ZERO, plank)
				_mesh(_box(Vector3(1.5, 0.5, 0.08)), Vector3(0, 2.15, 0), Vector3.ZERO, plank)
				for sx in [-0.525, 0.525]:
					_mesh(_box(Vector3(0.45, 0.9, 0.08)), Vector3(sx, 1.45, 0), Vector3.ZERO, plank)
				_mesh(_box(Vector3(0.04, 0.9, 0.05)), Vector3(0, 1.45, 0), Vector3.ZERO, frame)
				_mesh(_box(Vector3(0.6, 0.04, 0.05)), Vector3(0, 1.45, 0), Vector3.ZERO, frame)
			for sx in [-0.71, 0.71]:
				_mesh(_box(Vector3(0.12, 2.4, 0.14)), Vector3(sx, 1.2, 0), Vector3.ZERO, frame)
			_mesh(_box(Vector3(1.5, 0.1, 0.12)), Vector3(0, 2.35, 0), Vector3.ZERO, frame)
		"p_cati":
			var pm := PrismMesh.new()
			pm.size = Vector3(1.84, 0.62, 1.53)
			_mesh(pm, Vector3(0, 0.31, 0), Vector3(0, PI / 2.0, 0), main.raft.mat_thatch)
		"tas", "demir_cevheri":
			var stone := _mat(Color(0.55, 0.54, 0.52), 0.0, 0.95)
			for i in 3:
				var m := _mesh_ret(_sphere(0.17 - i * 0.03, 0.26 - i * 0.04), Vector3((i - 1) * 0.2, 0.0, (i % 2) * 0.1), Vector3(i, i * 2.0, 0), stone)
				m.scale = Vector3(1.2, 0.8, 1.0)
			if id == "demir_cevheri":
				var ore := _mat(Color(0.65, 0.3, 0.12), 0.6, 0.5)
				for i in 6:
					_mesh(_sphere(0.04, 0.06), Vector3(-0.25 + i * 0.1, 0.1 + 0.03 * sin(i), 0.08 * cos(i * 2.0)), Vector3.ZERO, ore)
		"kum":
			var sandm := _mat(Color(0.86, 0.78, 0.6), 0.0, 1.0)
			var mound := _mesh_ret(_sphere(0.35, 0.4), Vector3.ZERO, Vector3.ZERO, sandm)
			mound.scale = Vector3(1.0, 0.45, 1.0)
			var shell := _mat(Color(0.95, 0.88, 0.85), 0.0, 0.5)
			_mesh(_sphere(0.05, 0.03), Vector3(0.12, 0.13, 0.1), Vector3(0.4, 0, 0), shell)
		"cam":
			var glass := _mat(Color(0.7, 0.88, 0.95), 0.0, 0.05)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.albedo_color.a = 0.55
			for i in 2:
				_mesh(_box(Vector3(0.5, 0.35, 0.02)), Vector3(i * 0.08, i * 0.04, i * 0.06), Vector3(0, 0.2 * i, 0.05), glass)
		"zeytin":
			var olive := _mat(Color(0.22, 0.2, 0.15), 0.0, 0.35)
			var green := _mat(Color(0.35, 0.42, 0.22), 0.0, 0.5)
			for i in 5:
				var o := _mesh_ret(_sphere(0.06, 0.15), Vector3(cos(i * 1.3) * 0.12, 0.0, sin(i * 1.3) * 0.12), Vector3(0, 0, PI / 2.0), olive if i % 2 == 0 else green)
				o.scale = Vector3(1.0, 1.0, 1.0)
			var leafm := _mat(Color(0.55, 0.62, 0.48), 0.0, 0.8)
			for i in 2:
				var l := _mesh_ret(_sphere(0.05, 0.1), Vector3(-0.18 + i * 0.36, 0.06, -0.1), Vector3(0, i, 0.3), leafm)
				l.scale = Vector3(3.0, 0.25, 1.0)
		"zeytinyagi":
			var bottle := _mat(Color(0.35, 0.5, 0.25), 0.0, 0.1)
			bottle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bottle.albedo_color.a = 0.6
			ToolModels._mi(stage, ToolModels.lathe([Vector2(0.0, -0.25), Vector2(0.14, -0.25), Vector2(0.16, -0.1), Vector2(0.14, 0.08), Vector2(0.05, 0.16), Vector2(0.045, 0.26), Vector2(0.0, 0.26)], 20), bottle)
			var oil := _mat(Color(0.85, 0.7, 0.15), 0.0, 0.2)
			ToolModels._mi(stage, ToolModels.lathe([Vector2(0.0, -0.24), Vector2(0.13, -0.24), Vector2(0.15, -0.1), Vector2(0.13, 0.03), Vector2(0.0, 0.03)], 20), oil)
			_mesh(_cyl(0.04, 0.06), Vector3(0, 0.28, 0), Vector3.ZERO, _mat(Color(0.6, 0.45, 0.3), 0.0, 0.9))
		"mercek":
			var lens := _mat(Color(0.92, 0.9, 0.75), 0.0, 0.05)
			lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			lens.albedo_color.a = 0.6
			var lm := _mesh_ret(_sphere(0.25, 0.5), Vector3.ZERO, Vector3(PI / 2.0, 0, 0), lens)
			lm.scale = Vector3(1.0, 0.35, 1.0)
			var brass := _mat(Color(0.8, 0.62, 0.3), 0.9, 0.3)
			for k in 3:
				var ring := TorusMesh.new()
				ring.rings = 24
				ring.ring_segments = 10
				ring.inner_radius = 0.09 + k * 0.07
				ring.outer_radius = 0.105 + k * 0.07
				_mesh(ring, Vector3.ZERO, Vector3(PI / 2.0, 0, 0), brass)
		"yengec_eti", "pismis_yengec":
			var shellm := _mat(Color(0.72, 0.28, 0.14) if id == "yengec_eti" else Color(0.9, 0.22, 0.1), 0.0, 0.5)
			var cara := _mesh_ret(_sphere(0.2, 0.2), Vector3.ZERO, Vector3.ZERO, shellm)
			cara.scale = Vector3(1.3, 0.55, 1.0)
			for sd in [-1.0, 1.0]:
				var claw := _mesh_ret(_sphere(0.07, 0.1), Vector3(sd * 0.2, 0.0, 0.22), Vector3.ZERO, shellm)
				claw.scale = Vector3(1.0, 0.7, 1.6)
				for i in 3:
					_mesh(_cyl(0.012, 0.22), Vector3(sd * 0.25, -0.02, -0.08 + i * 0.09), Vector3(0, 0, sd * 1.1), shellm)
		"marti_yumurtasi":
			var egg := _mat(Color(0.86, 0.82, 0.7), 0.0, 0.6)
			for i in 2:
				_mesh(_sphere(0.1, 0.26), Vector3((i - 0.5) * 0.2, 0.0, 0.0), Vector3(0, 0, (i - 0.5) * 0.8), egg)
			var speck := _mat(Color(0.35, 0.3, 0.22), 0.0, 0.8)
			for i in 6:
				_mesh(_sphere(0.012, 0.02), Vector3(-0.15 + i * 0.06, 0.05 * sin(i * 2.0), 0.09), Vector3.ZERO, speck)
		"pismis_yumurta":
			var white := _mat(Color(0.97, 0.96, 0.92), 0.0, 0.5)
			var wm := _mesh_ret(_sphere(0.3, 0.1), Vector3.ZERO, Vector3.ZERO, white)
			wm.scale = Vector3(1.0, 0.3, 0.85)
			var yolk := _mat(Color(1.0, 0.7, 0.15), 0.0, 0.3)
			var ym := _mesh_ret(_sphere(0.1, 0.12), Vector3(0.04, 0.03, 0.0), Vector3.ZERO, yolk)
			ym.scale = Vector3(1.0, 0.6, 1.0)
		"cay":
			# İnce belli bardak, tavşan kanı çay, tabak, kaşık ve kesme şeker
			var glass := _mat(Color(0.95, 0.97, 1.0, 0.35), 0.0, 0.05)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var tea := _mat(Color(0.62, 0.16, 0.05), 0.0, 0.15)
			ToolModels._mi(stage, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.15, 0.08), Vector2(0.1, 0.25), Vector2(0.11, 0.33), Vector2(0.17, 0.5)], 24), glass, Vector3(0, 0.06, 0))
			ToolModels._mi(stage, ToolModels.lathe([Vector2(0.0, 0.01), Vector2(0.115, 0.01), Vector2(0.14, 0.08), Vector2(0.095, 0.25), Vector2(0.1, 0.33), Vector2(0.15, 0.45), Vector2(0.0, 0.45)], 24), tea, Vector3(0, 0.06, 0))
			_mesh(_cyl(0.3, 0.03, 0.22), Vector3(0, 0.03, 0), Vector3.ZERO, _mat(Color(0.95, 0.94, 0.9), 0.0, 0.3))
			_mesh(_cyl(0.29, 0.012), Vector3(0, 0.05, 0), Vector3.ZERO, _mat(Color(0.75, 0.12, 0.12), 0.0, 0.3))
			_mesh(_box(Vector3(0.07, 0.07, 0.07)), Vector3(0.22, 0.08, 0.05), Vector3(0, 0.4, 0), _mat(Color(0.98, 0.98, 0.98), 0.0, 0.8))
			_mesh(_cyl(0.008, 0.36), Vector3(0.06, 0.4, 0.0), Vector3(0, 0, 0.25), _mat(Color(0.8, 0.8, 0.82), 0.9, 0.3))
		"antik_sikke":
			var silver := _mat(Color(0.82, 0.8, 0.72), 0.9, 0.35)
			var gold := _mat(Color(0.95, 0.75, 0.3), 0.9, 0.3)
			for k in 5:
				var c := _mesh_ret(_cyl(0.13, 0.025), Vector3(randf_range(-0.12, 0.12), k * 0.028, randf_range(-0.1, 0.1)), Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15)), silver if k % 2 == 0 else gold)
				c.scale = Vector3.ONE
			_mesh(_cyl(0.13, 0.025), Vector3(0.18, 0.1, 0.05), Vector3(1.2, 0, 0.2), gold)
		"bronz_heykel":
			var bronze := _mat(Color(0.28, 0.45, 0.37), 0.7, 0.5)
			ToolModels._mi(stage, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.3, 0.0), Vector2(0.32, 0.25), Vector2(0.24, 0.42), Vector2(0.09, 0.48), Vector2(0.0, 0.48)], 16), bronze)
			_mesh(_sphere(0.15, 0.36), Vector3(0, 0.62, 0), Vector3.ZERO, bronze)
		"dalgic_feneri":
			var strap := _mat(Color(0.12, 0.12, 0.14), 0.0, 0.8)
			var band := TorusMesh.new()
			band.inner_radius = 0.2
			band.outer_radius = 0.24
			band.rings = 24
			band.ring_segments = 8
			_mesh(band, Vector3.ZERO, Vector3(0.3, 0, 0), strap)
			var body := _mat(Color(0.95, 0.8, 0.15), 0.3, 0.4)
			_mesh(_cyl(0.08, 0.14), Vector3(0, 0.0, 0.25), Vector3(PI / 2.0, 0, 0), body)
			var lens := _mat(Color(1.0, 0.97, 0.8), 0.0, 0.1)
			lens.emission_enabled = true
			lens.emission = Color(1.0, 0.95, 0.7)
			lens.emission_energy_multiplier = 2.0
			_mesh(_cyl(0.065, 0.02), Vector3(0, 0.0, 0.33), Vector3(PI / 2.0, 0, 0), lens)
		"kurdele":
			# Düğümlenmiş kırmızı, beyaz ve yeşil bez şeritler
			var cols := [Color(0.85, 0.12, 0.1), Color(0.95, 0.95, 0.92), Color(0.2, 0.55, 0.25)]
			for k in 3:
				var pts: Array = []
				for i in 8:
					pts.append(Vector3((k - 1) * 0.08 + sin(i * 0.8 + k) * 0.05, 0.3 - i * 0.09, cos(i * 0.6 + k) * 0.04))
				var rib := ToolModels._mi(stage, ToolModels.tube(pts, 0.03, 4), _mat(cols[k], 0.0, 0.85))
				rib.scale = Vector3(1.0, 1.0, 0.35)
			_mesh(_sphere(0.06, 0.1), Vector3(0, 0.32, 0), Vector3.ZERO, _mat(cols[0], 0.0, 0.85))
		"inci":
			var shell := _mat(Color(0.75, 0.72, 0.7), 0.0, 0.8)
			var sm := _mesh_ret(_sphere(0.3, 0.12), Vector3(0, 0, 0), Vector3.ZERO, shell)
			sm.scale = Vector3(1.0, 0.6, 0.85)
			var nacre := _mat(Color(0.95, 0.92, 1.0), 0.6, 0.15)
			var nm := _mesh_ret(_cyl(0.26, 0.02), Vector3(0, 0.035, 0), Vector3.ZERO, nacre)
			nm.scale = Vector3(1.0, 1.0, 0.85)
			_mesh(_sphere(0.09, 0.18), Vector3(0.02, 0.11, 0.0), Vector3.ZERO, _mat(Color(0.98, 0.96, 0.94), 0.3, 0.08))
		"istiridye":
			stage.add_child(OysterScript.model())
		"deniz_yosunu":
			var kn := Reef.kelp(0.9, Color(0.35, 0.5, 0.2))
			stage.add_child(kn)
		"oksijen_tupu":
			var yel := _mat(Color(0.95, 0.75, 0.15), 0.3, 0.35)
			ToolModels._mi(stage, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.14, 0.04), Vector2(0.14, 0.62), Vector2(0.1, 0.72), Vector2(0.04, 0.76), Vector2(0.0, 0.76)], 20), yel)
			var steel := _mat(Color(0.7, 0.72, 0.75), 0.9, 0.3)
			_mesh(_cyl(0.035, 0.1), Vector3(0, 0.8, 0), Vector3.ZERO, steel)
			_mesh(_cyl(0.05, 0.03), Vector3(0, 0.86, 0), Vector3(0, 0, PI / 2.0), steel)
			var hose := _mat(Color(0.1, 0.1, 0.12), 0.0, 0.6)
			ToolModels._mi(stage, ToolModels.tube([Vector3(0.03, 0.84, 0), Vector3(0.18, 0.9, 0), Vector3(0.22, 0.6, 0.05), Vector3(0.2, 0.35, 0.1)], 0.015, 6), hose)
			_mesh(_cyl(0.035, 0.08), Vector3(0.2, 0.32, 0.1), Vector3.ZERO, hose)
			var strap := _mat(Color(0.12, 0.13, 0.15), 0.0, 0.8)
			for y in [0.2, 0.5]:
				_mesh(_cyl(0.145, 0.04), Vector3(0, y, 0), Vector3.ZERO, strap)
		"nazar":
			var bead := ToolModels.nazar(0.3)
			stage.add_child(bead)
			ToolModels._mi(stage, ToolModels.tube([Vector3(0, 0.36, 0), Vector3(0.05, 0.6, 0)], 0.012, 4), _mat(Color(0.85, 0.15, 0.12), 0.0, 0.8))
		"palet":
			var blue := _mat(Color(0.2, 0.62, 1.0), 0.0, 0.35)
			var black := _mat(Color(0.95, 0.8, 0.2), 0.0, 0.5)
			for sd in [-1.0, 1.0]:
				var root := Node3D.new()
				root.position = Vector3(sd * 0.17, 0, 0)
				root.rotation = Vector3(-1.0, sd * 0.12, 0)
				stage.add_child(root)
				var fin := ToolModels._mi(root, ToolModels.plate([Vector2(-0.09, 0.0), Vector2(0.09, 0.0), Vector2(0.14, 0.55), Vector2(0.0, 0.5), Vector2(-0.14, 0.55)], Vector3.RIGHT, Vector3.FORWARD, 0.03, 0.4), blue)
				blue.cull_mode = BaseMaterial3D.CULL_DISABLED
				fin.position.y = 0.0
				var shoe := ToolModels._mi(root, _sphere(0.09, 0.16), black, Vector3(0, 0.04, -0.06))
				shoe.scale = Vector3(1.0, 0.6, 1.6)
		"kopekbaligi_yemi":
			var f := ToolModels.fish(false)
			f.rotation = Vector3(0, 0, PI / 2.0)
			stage.add_child(f)
			var bait_rope := _mat(Color(0.78, 0.66, 0.42), 0.0, 0.9)
			ToolModels._mi(stage, ToolModels.tube([Vector3(0, 0.2, 0), Vector3(0.05, 0.45, 0), Vector3(-0.05, 0.6, 0)], 0.012, 5), bait_rope)
			var blood := _mat(Color(0.55, 0.05, 0.05), 0.0, 0.3)
			for k in 3:
				_mesh(_sphere(0.03, 0.04), Vector3(randf_range(-0.05, 0.05), -0.05 - k * 0.05, 0.05), Vector3.ZERO, blood)
		"tavan_lambasi":
			var iron := _mat(Color(0.22, 0.23, 0.25), 0.85, 0.5)
			var glass := _mat(Color(1.0, 0.85, 0.55))
			glass.emission_enabled = true
			glass.emission = Color(1.0, 0.7, 0.35)
			glass.emission_energy_multiplier = 1.5
			_mesh(_cyl(0.008, 0.3), Vector3(0, 0.15, 0), Vector3.ZERO, iron)
			_mesh(_cyl(0.03, 0.08, 0.12), Vector3(0, -0.04, 0), Vector3.ZERO, iron)
			_mesh(_sphere(0.09, 0.2), Vector3(0, -0.12, 0), Vector3.ZERO, glass)
		_:
			if Items.info(id)["type"] == "place":
				var b = BuildingScript.new()
				b.main = main
				b.kind = id
				b.set_process(false)
				stage.add_child(b)
			else:
				_mesh(_box(Vector3(0.4, 0.4, 0.4)), Vector3.ZERO, Vector3.ZERO, _mat(Items.info(id)["color"]))


## Eşyanın ikondaki 3B modelini ayrı bir düğüm olarak kurar (elde tutmak için).
## Çarpışma, ses ve parçacıklar ayıklanır; model en uzun kenarı `fit` metre olacak biçimde ortalanır.
func build_model(id: String, fit: float) -> Node3D:
	var keep := stage
	stage = Node3D.new()
	add_child(stage)
	_build(id)
	var built := stage
	stage = keep
	remove_child(built)
	for n in built.find_children("*", "", true, false):
		if n is CollisionObject3D or n is AudioStreamPlayer3D or n is GPUParticlesCollisionBox3D:
			n.queue_free()
		elif n is GPUParticles3D:
			(n as GPUParticles3D).emitting = false
			(n as GPUParticles3D).visible = false
		elif n is Light3D:
			(n as Light3D).visible = false
		elif n is GeometryInstance3D:
			(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.set_process(false)
		n.set_physics_process(false)
	var acc: Array = []
	Props._merge(built, Transform3D.IDENTITY, acc)
	var root := Node3D.new()
	root.add_child(built)
	if not acc.is_empty():
		var bb: AABB = acc[0]
		var k := fit / maxf(0.001, maxf(bb.size.x, maxf(bb.size.y, bb.size.z)))
		built.scale = Vector3.ONE * k
		built.position = -bb.get_center() * k
	return root


func _frame(target: Node3D) -> void:
	# Kamerayı nesneyi dolduracak şekilde konumla.
	var acc: Array = []
	Props._merge(target, Transform3D.IDENTITY, acc)
	var bb: AABB = acc[0] if not acc.is_empty() else AABB(Vector3(-0.3, -0.3, -0.3), Vector3(0.6, 0.6, 0.6))
	var c := bb.get_center()
	var r := bb.size.length() * 0.5
	cam.size = r * 1.9
	var dir := Vector3(0.55, 0.65, 1.0).normalized()
	cam.position = c + dir * (r * 4.0 + 1.0)
	cam.look_at(c)


## Tüm ikonları sırayla üretir (her eşya için iki kare beklenir).
func generate() -> void:
	for id in Items.ITEMS:
		for ch in stage.get_children():
			ch.queue_free()
		await get_tree().process_frame
		_build(id)
		await get_tree().process_frame
		_frame(stage)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_texture().get_image()
		cache[id] = ImageTexture.create_from_image(img)
	for ch in stage.get_children():
		ch.queue_free()
	ready_done = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	if main.hud != null:
		main.hud.on_icons_ready()
