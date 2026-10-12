extends Node3D
## Sala yerleştirilen yapılar: su arıtıcı, ızgara, depo sandığı, ekim saksısı, yatak, yelken, çapa.
## Her yapı E ile kullanılır; çekiçle bakıp R'ye basılırsa sökülür (eşya geri gelir).

const Props = preload("res://scripts/props.gd")
const Items = preload("res://scripts/items.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Crops = preload("res://scripts/crops.gd")
const ToolModels = preload("res://scripts/tool_models.gd")

const BOIL_TIME := 20.0
const COOK_TIME := 18.0
const GROW_TIME := 150.0
const SMELT_TIME := 25.0

## Engel kutusu boyutları (sal üstünde oyuncuyu durdurur ve etkileşim için hedef olur).
const SIZES := {
	"aritici": Vector3(0.75, 1.15, 0.85),
	"toplayici": Vector3(1.4, 0.1, 0.8),
	"izgara": Vector3(0.8, 0.9, 0.6),
	"sandik": Vector3(1.0, 0.34, 0.42),
	"saksi": Vector3(1.1, 0.45, 1.1),
	"yatak": Vector3(0.95, 0.5, 1.4),
	"sandalye": Vector3(0.5, 0.5, 0.5),
	"masa": Vector3(1.0, 0.8, 0.7),
	"hali": Vector3(1.3, 0.05, 1.3),
	"yelken": Vector3(0.3, 3.2, 0.3),
	"capa": Vector3(0.8, 0.7, 0.7),
	"ocak": Vector3(0.9, 1.4, 0.9),
	"dumen": Vector3(0.9, 1.3, 0.5),
	"kedi_yatagi": Vector3(0.6, 0.15, 0.6),
	"nazar": Vector3(0.35, 1.5, 0.35),
	"diken_tuzagi": Vector3(1.2, 0.5, 1.2),
	"sonar": Vector3(0.7, 1.1, 0.6),
	"motor": Vector3(0.7, 0.8, 0.8),
	"telsiz": Vector3(0.6, 1.0, 0.5),
	"yagmur_toplayici": Vector3(0.9, 1.1, 0.9),
	"balik_agi": Vector3(1.4, 0.1, 0.8),
	"fener": Vector3(0.35, 1.6, 0.35),
}

const Merge = preload("res://scripts/merge.gd")
var main
var kind := ""
var cell := Vector2i.ZERO
var block_shape: CollisionShape3D
var target_body: StaticBody3D

# Durumlar
var busy := false
var timer := 0.0
var output := ""
var cooking := ""
var growth := 0.0
## Açılış ekranı vitrinindeki yapılar menüde de canlı görünür.
var showcase := false
## İstif katı (0: zeminde; sandıklar üst üste konabilir).
var level := 0
## Sandık türü: hızlı eklemede yalnızca bu türdeki eşyalar sandığa gider.
var ctype := "karisik"
var type_label: Label3D
## Dümen tekeri, motor pervanesi
var wheel: Node3D
var prop: Node3D
var radio_led: StandardMaterial3D
const CHEST_TYPES := [["karisik", "Karışık"], ["malzeme", "Malzeme"], ["yiyecek", "Yiyecek"], ["tohum", "Tohum"], ["alet", "Alet"], ["yapi", "Yapı"]]
var planted := false
var open := false
var dir := Vector3.FORWARD
var storage
var stock := 0
var lamp: OmniLight3D
var lamp_mat: StandardMaterial3D
var water_mesh: MeshInstance3D
## Ağ bölmesinin üstünde, yakalanan malzemelerin küçük modelleri.
var catch_display: Node3D

# Görseller
var fx: GPUParticles3D
var light: OmniLight3D
var loop_snd: AudioStreamPlayer3D
var food_visual: Node3D
var coal_mat: StandardMaterial3D
var ember_mat: StandardMaterial3D
var molten_mat: StandardMaterial3D
var ingot_node: Node3D
var fuel: Node3D
var plant: Node3D
var sail_cloth: MeshInstance3D
var sail_pivot: Node3D
var rope: MeshInstance3D
var lid: Node3D


func _ready() -> void:
	# Eski kayıtlardaki ayrı balık ağı artık tek "Ağ"dır.
	if kind == "balik_agi":
		kind = "toplayici"
	match kind:
		"aritici":
			_build_purifier()
		"toplayici":
			_build_collector_net()
		"izgara":
			_build_grill()
		"sandik":
			_build_chest()
			storage = Inventory.new(20)
		"saksi":
			_build_planter()
		"yatak":
			_build_bed()
		"sandalye":
			_build_chair()
		"masa":
			_build_table()
		"hali":
			_build_rug()
		"yelken":
			_build_sail()
		"capa":
			_build_anchor()
		"ocak":
			_build_smelter()
		"yagmur_toplayici":
			_build_collector()
		"fener":
			_build_lantern()
		"dumen":
			_build_helm()
		"kedi_yatagi":
			_build_cat_bed()
		"nazar":
			_build_nazar()
		"sonar":
			_build_sonar()
		"diken_tuzagi":
			_build_spikes()
			if stock <= 0:
				stock = 3
		"motor":
			_build_motor()
		"telsiz":
			_build_radio()

	_bake_static()
	target_body = StaticBody3D.new()
	target_body.collision_layer = 4
	target_body.collision_mask = 0
	target_body.set_meta("target", self)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZES[kind] + Vector3(0.1, 0.1, 0.1)
	cs.shape = box
	cs.position.y = SIZES[kind].y / 2.0
	if kind == "toplayici":
		cs.position.z = 0.35
	target_body.add_child(cs)
	add_child(target_body)


func _mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _mesh(mesh: Mesh, pos: Vector3, mat: Material, parent: Node3D = null, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	(parent if parent != null else self).add_child(mi)
	return mi


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _cyl(r: float, h: float, r2 := -1.0) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r if r2 < 0.0 else r2
	c.height = h
	return c


func _particles(pos: Vector3, col: Color, size: float, vel: float, grav: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 1.4
	p.emitting = false
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 18.0
	pm.initial_velocity_min = vel * 0.6
	pm.initial_velocity_max = vel
	pm.gravity = grav
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	# Yumuşak yuvarlak duman/buhar tanesi; zamanla genişleyip solar.
	m.albedo_texture = ToolModels.glow_texture()
	m.vertex_color_use_as_albedo = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	q.material = m
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.add_point(0.2, Color(1, 1, 1, 1.0))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.6))
	var gt := CurveTexture.new()
	gt.curve = grow
	pm.scale_curve = gt
	p.draw_pass_1 = q
	add_child(p)
	return p


## Su arıtıcı: taş ateş çukuru, üç ayak üstünde metal kazan, kumaş süzgeçli huni,
## kapaktan inen dağıtma borusu ve temiz suyun damladığı toplama kabı.
## Yakıt yığını: atılan tahtalar (uzun ince kalaslar), uçları kömürleşmiş ve korlu, üstünde alev.
## Yalnızca yanarken görünür. "teepee": ortaya yaslanmış kamp ateşi; "flat": üst üste çapraz istif.
func _fuel(pos: Vector3, s := 1.0, style := "teepee", yaw := 0.0) -> Node3D:
	var pile := Node3D.new()
	pile.name = "Yakit"
	pile.position = pos
	pile.rotation.y = yaw
	pile.scale = Vector3.ONE * s
	pile.visible = false
	add_child(pile)
	if ember_mat == null:
		ember_mat = _mat(Color(0.1, 0.05, 0.03), 0.9)
		ember_mat.emission_enabled = true
		ember_mat.emission = Color(1.0, 0.32, 0.06)
		ember_mat.emission_energy_multiplier = 2.0
	var L := 0.42
	if style == "teepee":
		# Altta iki çapraz kalas, üstte ortaya yaslanmış beş kalas
		for i in 2:
			_plank(pile, Vector3(0, 0.015, 0), Vector3(0, i * PI / 2.0 + 0.4, 0), L)
		for i in 5:
			var ang := TAU * i / 5.0 + 0.3
			var tilt := 0.95
			var c := Vector3(cos(ang), 0, sin(ang)) * (L * 0.5 * cos(tilt) - 0.02)
			_plank(pile, c + Vector3(0, L * 0.5 * sin(tilt), 0), Vector3(0, PI - ang, tilt), L)
		pile.add_child(ToolModels.fire_fx(0.12, 0.11))
	else:
		# Alt kat: uzunlamasına üç kalas; üst kat: çapraz iki kalas
		for i in 3:
			_plank(pile, Vector3(0, 0.0, (i - 1) * 0.1), Vector3(0, (i - 1) * 0.08, 0), L * 1.15)
		for i in 2:
			_plank(pile, Vector3((i - 0.5) * 0.24, 0.03, 0), Vector3(0, PI / 2.0 + (i - 0.5) * 0.2, 0), L * 0.7)
		pile.add_child(ToolModels.fire_fx(0.06, 0.1))
	return pile


## Tek kalas: tahta dokulu gövde, iki ucunda kömürleşmiş korlu şerit.
func _plank(parent: Node3D, pos: Vector3, rot: Vector3, length: float) -> void:
	var piece := Node3D.new()
	piece.position = pos
	piece.rotation = rot
	parent.add_child(piece)
	var w := 0.085
	var t := 0.022
	_mesh(_box(Vector3(length - 0.06, t, w)), Vector3.ZERO, main.raft.mat_plank, piece)
	for e in [-1.0, 1.0]:
		_mesh(_box(Vector3(0.03, t * 1.04, w * 1.02)), Vector3(e * (length * 0.5 - 0.015), 0, 0), ember_mat, piece)


func _build_purifier() -> void:
	var wood: StandardMaterial3D = main.raft.mat_log
	var stone := _mat(Color(0.42, 0.4, 0.38), 0.95)
	var iron := ToolModels.mat("iron")
	var steel := ToolModels.mat("steel")
	var copper := _mat(Color(0.72, 0.42, 0.26), 0.35, 0.9)
	var cloth := _mat(Color(0.86, 0.82, 0.68), 0.95)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(_box(Vector3(0.72, 0.05, 0.82)), Vector3(0, 0.025, 0), wood)
	# Ateş çukuru
	for i in 9:
		var a := TAU * i / 9.0
		_mesh(_box(Vector3(0.1, 0.08, 0.07)), Vector3(cos(a) * 0.2, 0.09, sin(a) * 0.2 - 0.08), stone, null, Vector3(0.1 * sin(i), -a, 0.1))
	_mesh(_cyl(0.15, 0.012), Vector3(0, 0.058, -0.08), _mat(Color(0.18, 0.17, 0.16), 1.0))
	fuel = _fuel(Vector3(0, 0.07, -0.08), 1.15, "flat", 0.6)
	# Üç ayak ve kazan
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		ToolModels._mi(self, ToolModels.tube([Vector3(cos(a) * 0.27, 0.05, sin(a) * 0.27 - 0.08), Vector3(cos(a) * 0.17, 0.4, sin(a) * 0.17 - 0.08)], 0.012, 6), iron)
	ToolModels._mi(self, ToolModels.lathe([Vector2(0.0, 0.3), Vector2(0.12, 0.3), Vector2(0.17, 0.36), Vector2(0.18, 0.5), Vector2(0.17, 0.58), Vector2(0.15, 0.6), Vector2(0.0, 0.6)], 20), steel, Vector3(0, 0, -0.08))
	ToolModels._mi(self, ToolModels.lathe([Vector2(0.0, 0.6), Vector2(0.16, 0.6), Vector2(0.1, 0.66), Vector2(0.03, 0.68), Vector2(0.0, 0.68)], 20), steel, Vector3(0, 0, -0.08))
	# Kumaş süzgeçli huni (deniz suyu buradan dökülür)
	ToolModels._mi(self, ToolModels.lathe([Vector2(0.025, 0.68), Vector2(0.05, 0.75), Vector2(0.17, 0.92), Vector2(0.19, 0.95)], 18), cloth, Vector3(0, 0, -0.08))
	ToolModels.wraps(self, 0.77, 0.79, 0.055, 2, ToolModels.mat("rope"))
	# Dağıtma borusu: kazandan toplama kabına
	ToolModels._mi(self, ToolModels.tube([Vector3(0.12, 0.62, -0.08), Vector3(0.2, 0.7, 0.0), Vector3(0.24, 0.62, 0.15), Vector3(0.24, 0.42, 0.25)], 0.014, 8), copper)
	_mesh(_box(Vector3(0.16, 0.18, 0.16)), Vector3(0.24, 0.09, 0.28), wood)
	var cup := _mat(Color(0.75, 0.88, 0.95, 0.55), 0.05, 0.1)
	cup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ToolModels._mi(self, ToolModels.lathe([Vector2(0.0, 0.18), Vector2(0.055, 0.18), Vector2(0.065, 0.33), Vector2(0.06, 0.33), Vector2(0.05, 0.19), Vector2(0.0, 0.19)], 16), cup, Vector3(0.24, 0, 0.28))
	var wm := _mat(Color(0.35, 0.65, 0.9, 0.75), 0.05)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mesh = _mesh(_cyl(0.05, 0.1), Vector3(0.24, 0.24, 0.28), wm)
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.omni_range = 2.5
	light.light_energy = 0.0
	light.position = Vector3(0, 0.2, -0.08)
	add_child(light)
	fx = _particles(Vector3(0, 0.72, -0.08), Color(1, 1, 1, 0.22), 0.16, 0.5, Vector3(0, 0.25, 0))
	loop_snd = main.audio.loop_player("boil", self, -17.0)


## Ağ dokusu: saydam zeminde ip ilmekleri (eşkenar dörtgen ya da kare göz).
func _net_mat(diamond: bool, tiles: Vector2) -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 64:
		for j in 64:
			var on := ((i + j) % 11 == 0 or (i - j + 64) % 11 == 0) if diamond else (i % 8 == 0 or j % 8 == 0)
			if on:
				img.set_pixel(i, j, Color(0.88, 0.85, 0.74, 1))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_scale = Vector3(tiles.x, tiles.y, 1)
	return m


## Sal kenarından suya sarkan ağ: güvertede yalnızca zeminle bir hizada ince bir çerçeve,
## ağın kendisi karonun dış kenarından aşağı ve dışarı doğru kepçe gibi iner. Yürümeyi engellemez.
## Yerel +Z salın dışına bakar (yerleştirirken dışa döndürülür).
func _hanging_net(diamond: bool, drop: float, reach: float) -> void:
	var wood: StandardMaterial3D = main.raft.mat_log
	var plank: StandardMaterial3D = main.raft.mat_plank
	var edge := 0.74
	# Güvertedeki ağ bölmesi: zeminle bir hizada çerçeve, içinde altından deniz görünen gergin ağ.
	# Karo altta sağlam kaldığı için üstünden yürünür, düşülmez.
	var depth := 0.9
	var zc := edge - depth / 2.0
	for x in [-0.66, 0.66]:
		_mesh(_box(Vector3(0.09, 0.025, depth)), Vector3(x, 0.012, zc), plank)
	for z in [edge - depth + 0.04, edge - 0.04]:
		_mesh(_box(Vector3(1.4, 0.025, 0.09)), Vector3(0, 0.012, z), plank)
	var sea := _mat(Color(0.03, 0.16, 0.2), 0.2)
	_mesh(_box(Vector3(1.24, 0.004, depth - 0.16)), Vector3(0, 0.004, zc), sea)
	var deck_net := QuadMesh.new()
	deck_net.size = Vector2(1.24, depth - 0.16)
	_mesh(deck_net, Vector3(0, 0.014, zc), _net_mat(diamond, Vector2(5, 4)), null, Vector3(-PI / 2.0, 0, 0))
	catch_display = Node3D.new()
	catch_display.position = Vector3(0, 0.016, zc)
	add_child(catch_display)
	# Kenardaki menteşe kirişi ve sudaki alt kiriş
	_mesh(_cyl(0.035, 1.36), Vector3(0, -0.04, edge + 0.02), wood, null, Vector3(0, 0, PI / 2.0))
	var bottom := Vector3(0, -drop, edge + reach)
	_mesh(_cyl(0.03, 1.3), bottom, wood, null, Vector3(0, 0, PI / 2.0))
	# Yan kollar: kenardan alt kirişe inen iki sırık
	for x in [-0.64, 0.64]:
		ToolModels._mi(self, ToolModels.tube([Vector3(x, -0.04, edge + 0.02), Vector3(x, -drop * 0.6, edge + reach * 0.55), Vector3(x, -drop, edge + reach)], 0.025, 8), wood)
	# Ağ: iki parçalı kepçe (iniş + dibe doğru kıvrım)
	var m := _net_mat(diamond, Vector2(4, 3))
	var a := Vector3(0, -0.04, edge + 0.02)
	var mid := Vector3(0, -drop * 0.85, edge + reach * 0.45)
	for seg in [[a, mid], [mid, bottom]]:
		var p0: Vector3 = seg[0]
		var p1: Vector3 = seg[1]
		var q := QuadMesh.new()
		q.size = Vector2(1.28, p0.distance_to(p1))
		var d := p1 - p0
		_mesh(q, (p0 + p1) * 0.5, m, null, Vector3(atan2(d.z, d.y), 0, 0))
	for x in [-0.64, 0.64]:
		var tri := ImmediateMesh.new()
		tri.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in [a, mid, bottom]:
			tri.surface_set_uv(Vector2(v.z * 2.0, v.y * 2.0))
			tri.surface_add_vertex(Vector3(x, v.y, v.z))
		tri.surface_end()
		var mi := MeshInstance3D.new()
		mi.mesh = tri
		mi.material_override = m
		add_child(mi)


func _build_collector_net() -> void:
	_hanging_net(true, 1.0, 0.75)
	storage = Inventory.new(10)
	storage.changed.connect(_refresh_catch)


## Ağın içeriği yalnız veri olarak tutulur; ağ açıkken (ekranı açıkken) bölmenin üstünde modelleri çizilir.
var catch_shown := false
func show_catch(on: bool) -> void:
	catch_shown = on
	_refresh_catch()


func _refresh_catch() -> void:
	if catch_display == null or main.icons == null or not main.icons.has_method("build_model"):
		return
	for c in catch_display.get_children():
		c.queue_free()
	if not catch_shown:
		return
	var slot := 0
	for st in storage.slots:
		if st == null or slot >= 6:
			continue
		var m: Node3D = main.icons.build_model(st["id"], 0.55 if st["id"] == "yaprak" else 0.32)
		var col := slot % 3
		var row := slot / 3
		m.position = Vector3(-0.4 + col * 0.4, 0.07, -0.17 + row * 0.34)
		m.rotation.y = randf_range(-0.6, 0.6)
		catch_display.add_child(m)
		slot += 1


## Izgara: çapraz ahşap ayaklar üstünde boyuna kesilmiş varil, içinde kor, üstünde ızgara teli.
## Pişen yiyecek ızgaranın üstünde görünür.
func _build_grill() -> void:
	var wood: StandardMaterial3D = main.raft.mat_log
	var drum := _mat(Color(0.55, 0.16, 0.1), 0.6, 0.55)
	var inner := _mat(Color(0.12, 0.09, 0.08), 0.95, 0.2)
	var steel := ToolModels.mat("steel")
	var iron := ToolModels.mat("iron")
	# Çapraz ayaklar ve aradaki bağlantı kirişi
	for x in [-0.3, 0.3]:
		for s in [-1.0, 1.0]:
			_mesh(_cyl(0.025, 0.62), Vector3(x, 0.27, 0), wood, null, Vector3(s * 0.5, 0, 0))
	_mesh(_cyl(0.022, 0.66), Vector3(0, 0.3, 0), wood, null, Vector3(0, 0, PI / 2.0))
	# Yarım varil: yarım daire boyunca dizilmiş sac şeritler
	var r := 0.27
	var cy := 0.72
	for i in 10:
		var ang := PI * (float(i) + 0.5) / 10.0
		var y := cy - sin(ang) * r
		var z := cos(ang) * r
		_mesh(_box(Vector3(0.78, 0.014, r * PI / 10.0 + 0.012)), Vector3(0, y, z), drum, null, Vector3(-(ang - PI / 2.0), 0, 0))
		_mesh(_box(Vector3(0.76, 0.006, r * PI / 10.0 + 0.012)), Vector3(0, y + 0.012 * sin(ang), z - 0.012 * cos(ang)), inner, null, Vector3(-(ang - PI / 2.0), 0, 0))
	# Uç kapakları (yarım disk) ve kenar çemberleri
	var half: Array = []
	for i in 13:
		var ang := PI + PI * float(i) / 12.0
		half.append(Vector2(cos(ang) * r, sin(ang) * r))
	for x in [-0.39, 0.39]:
		ToolModels._mi(self, ToolModels.plate(half, Vector3.BACK, Vector3.UP, 0.008, 1.0), drum, Vector3(x, cy, 0))
		for zz in [-r, r]:
			_mesh(_box(Vector3(0.02, 0.025, 0.02)), Vector3(x, cy, zz), iron)
	for zz in [-r, r]:
		_mesh(_cyl(0.012, 0.8), Vector3(0, cy, zz), iron, null, Vector3(0, 0, PI / 2.0))
	# Kor yatağı (pişirirken parlar)
	coal_mat = _mat(Color(0.15, 0.08, 0.05), 0.9)
	coal_mat.emission_enabled = true
	coal_mat.emission = Color(1.0, 0.35, 0.08)
	coal_mat.emission_energy_multiplier = 0.0
	for i in 14:
		var px := randf_range(-0.3, 0.3)
		var pz := randf_range(-0.12, 0.12)
		var sm := SphereMesh.new()
		sm.radial_segments = 20
		sm.rings = 10
		sm.radius = randf_range(0.03, 0.05)
		sm.height = sm.radius * 1.4
		_mesh(sm, Vector3(px, cy - r + 0.08 + randf() * 0.03, pz), coal_mat)
	fuel = _fuel(Vector3(0, cy - r + 0.07, 0), 1.25, "flat")
	# Izgara teli
	for i in 9:
		_mesh(_cyl(0.005, 0.5), Vector3(-0.32 + i * 0.08, cy + 0.01, 0), steel, null, Vector3(PI / 2.0, 0, 0))
	for zz in [-0.2, 0.2]:
		_mesh(_cyl(0.007, 0.7), Vector3(0, cy + 0.015, zz), steel, null, Vector3(0, 0, PI / 2.0))
	# Izgaradaki yiyecek
	food_visual = Node3D.new()
	food_visual.position = Vector3(0, cy + 0.05, 0)
	food_visual.visible = false
	add_child(food_visual)
	var f := ToolModels.fish(false)
	f.name = "Balik"
	f.rotation = Vector3(0, 0, PI / 2.0)
	f.position = Vector3(0.2, 0, 0)
	food_visual.add_child(f)
	var potato := Node3D.new()
	potato.name = "Patates"
	food_visual.add_child(potato)
	for i in 3:
		var sm := SphereMesh.new()
		sm.radial_segments = 20
		sm.rings = 10
		sm.radius = 0.05
		sm.height = 0.075
		_mesh(sm, Vector3(-0.12 + i * 0.11, 0.0, 0.05 * sin(i * 2.0)), _mat(Color(0.62, 0.45, 0.25), 0.85), potato)
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.2)
	light.omni_range = 3.0
	light.light_energy = 0.0
	light.position = Vector3(0, cy + 0.1, 0)
	add_child(light)
	fx = _particles(Vector3(0, cy + 0.05, 0), Color(0.7, 0.7, 0.72, 0.3), 0.3, 0.5, Vector3(0, 0.35, 0))
	loop_snd = main.audio.loop_player("fire", self, -9.0)


func _build_chest() -> void:
	# Poly Haven "Wooden Military Crate" (CC0): gövde, mandal ve ayrı kapak. Ölçek 0.8 → 1.0 x 0.34 x 0.42 m.
	var k := 0.8
	var crate: Node3D = (load("res://assets/models/wooden_military_crate/wooden_military_crate_1k.gltf") as PackedScene).instantiate()
	crate.scale = Vector3.ONE * k
	crate.position = Vector3(0, 0.034 * k, 0)
	add_child(crate)
	# Kapak arka kenarındaki menteşeden açılır
	lid = Node3D.new()
	lid.position = Vector3(0, 0.384 * k, -0.26 * k)
	add_child(lid)
	var lid_mesh: Node3D = crate.find_child("*lid*", true, false)
	if lid_mesh != null:
		var gx: Transform3D = lid_mesh.global_transform
		lid_mesh.get_parent().remove_child(lid_mesh)
		lid.add_child(lid_mesh)
		lid_mesh.global_transform = gx
	# Önde tür etiketi: ahşap levha üstünde yazı
	_mesh(_box(Vector3(0.36, 0.1, 0.012)), Vector3(0, 0.17, 0.214), _mat(Color(0.85, 0.78, 0.6), 0.9))
	type_label = Label3D.new()
	type_label.font_size = 40
	type_label.pixel_size = 0.0022
	type_label.modulate = Color(0.2, 0.12, 0.06)
	type_label.outline_size = 0
	type_label.position = Vector3(0, 0.17, 0.222)
	type_label.double_sided = false
	add_child(type_label)
	_update_type_label()


## Telsiz: cızırtının arasından en yakın sönmüş fenerin sinyali çözülür ve hedef olarak işaretlenir.
func _radio_result(player) -> void:
	if radio_led != null:
		radio_led.emission_energy_multiplier = 0.2
	var lm: Dictionary = main.nearest_dark_lighthouse(player.global_position)
	main.nav_target = Vector3(float(lm["x"]), 0, float(lm["z"]))
	main.nav_name = lm["name"]
	var d: Vector3 = main.nav_target - player.global_position
	var deg := fposmod(rad_to_deg(atan2(d.x, -d.z)), 360.0)
	var names := ["Kuzey", "Kuzeydoğu", "Doğu", "Güneydoğu", "Güney", "Güneybatı", "Batı", "Kuzeybatı"]
	main.hud.toast("Telsiz: \"...%s... ışık sönük... yardım...\"  ·  %d m, %s. Hedef haritada işaretlendi." % [lm["name"], int(Vector2(d.x, d.z).length()), names[int(round(deg / 45.0)) % 8]], 7.0)
	main.quests.event("radio")


## Ocakta eritilecek: [girdi, çıktı]. Elde tutulan eritilebilirse o, yoksa ilk yeten.
const SMELT := [["hurda", "metal_kulce"], ["demir_cevheri", "metal_kulce"], ["kum", "cam"]]


func _smelt_choice(player) -> Array:
	if player.inv.count("tahta") < 1:
		return []
	var held: String = player.held_id()
	for s in SMELT:
		if s[0] == held and player.inv.count(s[0]) >= 2:
			return s
	for s in SMELT:
		if player.inv.count(s[0]) >= 2:
			return s
	return []


func type_name() -> String:
	if ctype.begins_with("item:"):
		return Items.name_of(ctype.substr(5))
	for t in CHEST_TYPES:
		if t[0] == ctype:
			return t[1]
	return "Karışık"


## Sandık türünü sıradakine çevirir (Karışık → Malzeme → Yiyecek → Tohum → Alet → Yapı).
func cycle_type() -> void:
	var i := 0
	for k in CHEST_TYPES.size():
		if CHEST_TYPES[k][0] == ctype:
			i = k
	ctype = CHEST_TYPES[(i + 1) % CHEST_TYPES.size()][0]
	_update_type_label()


func _update_type_label() -> void:
	if type_label != null:
		type_label.text = type_name().to_upper()


func set_type(k: String) -> void:
	ctype = k
	_update_type_label()


## Bu sandığın türü bu eşyayı kabul ediyor mu? (genel başlık ya da tek bir eşya: "item:tahta")
func accepts(id: String) -> bool:
	if ctype.begins_with("item:"):
		return id == ctype.substr(5)
	var t: String = Items.info(id).get("type", "")
	match ctype:
		"malzeme":
			return t == "material"
		"yiyecek":
			return t == "food"
		"tohum":
			return t == "seed"
		"alet":
			return t == "tool"
		"yapi":
			return t == "place" or t == "roof"
	return true


func _build_planter() -> void:
	var wood: StandardMaterial3D = main.raft.mat_plank
	_mesh(_box(Vector3(1.1, 0.35, 1.1)), Vector3(0, 0.175, 0), wood)
	_mesh(_box(Vector3(0.96, 0.05, 0.96)), Vector3(0, 0.34, 0), _mat(Color(0.18, 0.12, 0.07), 1.0))
	# Toprak üstünde birkaç kesek
	for i in 6:
		var a := TAU * i / 6.0
		var k := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radial_segments = 20
		sm.rings = 10
		sm.radius = 0.08
		sm.height = 0.06
		k.mesh = sm
		k.material_override = _mat(Color(0.22, 0.15, 0.09), 1.0)
		k.position = Vector3(cos(a) * 0.32, 0.36, sin(a) * 0.32)
		add_child(k)
	plant = Node3D.new()
	plant.position = Vector3(0, 0.36, 0)
	add_child(plant)
	plant.visible = false


## Saksıdaki bitkiyi ekilen tohuma göre yeniden kurar ("cooking" ekilen tohumu tutar).
func _set_crop(seed: String) -> void:
	cooking = seed
	for c in plant.get_children():
		c.queue_free()
	if seed != "":
		var pm: Node3D = Crops.plant(seed)
		plant.add_child(pm)
		Merge.bake(pm, true)


## Ekilecek tohum: elde tutulan tohum, yoksa çantadaki ilk tohum.
func _seed_choice(player) -> String:
	var held: String = player.held_id()
	if Crops.is_seed(held) and player.inv.count(held) > 0:
		return held
	for s in Crops.ORDER:
		if player.inv.count(s) > 0:
			return s
	return ""


## Yatak: dört direkli ahşap karyola, kalaslı başlık, kumaş şilte, çizgili battaniye ve yastık.
## Başlık yerel -Z tarafında.
func _build_bed() -> void:
	var wood: StandardMaterial3D = main.raft.mat_log
	var plank: StandardMaterial3D = main.raft.mat_plank
	var w := 0.92
	var l := 1.38
	# Yan ve uç kirişleri
	for sx in [-1.0, 1.0]:
		_mesh(_box(Vector3(0.06, 0.12, l)), Vector3(sx * (w / 2.0 - 0.03), 0.2, 0), wood)
	for sz in [-1.0, 1.0]:
		_mesh(_box(Vector3(w, 0.12, 0.06)), Vector3(0, 0.2, sz * (l / 2.0 - 0.03)), wood)
	# Direkler: başta yüksek, ayakta kısa
	for sx in [-1.0, 1.0]:
		_mesh(_cyl(0.035, 0.95), Vector3(sx * (w / 2.0 - 0.03), 0.475, -(l / 2.0 - 0.03)), wood)
		_mesh(_cyl(0.035, 0.45), Vector3(sx * (w / 2.0 - 0.03), 0.225, l / 2.0 - 0.03), wood)
		ToolModels._mi(self, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.045, 0.0), Vector2(0.05, 0.03), Vector2(0.0, 0.07)], 10), wood, Vector3(sx * (w / 2.0 - 0.03), 0.95, -(l / 2.0 - 0.03)))
	# Kalaslı başlık ve ayak tahtası
	for i in 4:
		_mesh(_box(Vector3(w - 0.08, 0.11, 0.03)), Vector3(0, 0.36 + i * 0.13, -(l / 2.0 - 0.03)), plank)
	_mesh(_box(Vector3(w - 0.08, 0.14, 0.03)), Vector3(0, 0.33, l / 2.0 - 0.03), plank)
	# Şilte (kenarları yumuşak) ve çizgili battaniye
	var mattress := _mat(Color(0.86, 0.82, 0.72), 0.95)
	_mesh(_box(Vector3(w - 0.12, 0.14, l - 0.12)), Vector3(0, 0.33, 0), mattress)
	for sx in [-1.0, 1.0]:
		_mesh(_cyl(0.07, l - 0.12), Vector3(sx * (w / 2.0 - 0.13), 0.33, 0), mattress, null, Vector3(PI / 2.0, 0, 0))
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var band := (y / 8) % 4
			var c: Color = [Color(0.62, 0.22, 0.16), Color(0.85, 0.78, 0.6), Color(0.2, 0.32, 0.45), Color(0.85, 0.78, 0.6)][band]
			img.set_pixel(x, y, c.darkened(0.05 * ((x + y) % 2)))
	var blanket := _mat(Color.WHITE, 0.95)
	blanket.albedo_texture = ImageTexture.create_from_image(img)
	_mesh(_box(Vector3(w - 0.06, 0.03, l * 0.62)), Vector3(0, 0.415, l * 0.17), blanket)
	for sx in [-1.0, 1.0]:
		_mesh(_box(Vector3(0.025, 0.14, l * 0.62)), Vector3(sx * (w / 2.0 - 0.04), 0.35, l * 0.17), blanket)
	# Yastık
	var pillow := SphereMesh.new()
	pillow.radial_segments = 20
	pillow.rings = 10
	pillow.radius = 0.2
	pillow.height = 0.4
	var pm := _mesh(pillow, Vector3(0, 0.44, -(l / 2.0 - 0.24)), _mat(Color(0.95, 0.93, 0.88), 0.95))
	pm.scale = Vector3(1.6, 0.35, 0.75)


## Sandalye: ahşap oturak, dört ayak, çıtalı sırtlık ve hasır minder. Önü yerel +Z.
func _build_chair() -> void:
	var wood: StandardMaterial3D = main.raft.mat_log
	var plank: StandardMaterial3D = main.raft.mat_plank
	for sx in [-0.18, 0.18]:
		for sz in [-0.18, 0.18]:
			_mesh(_cyl(0.022, 0.44, 0.026), Vector3(sx, 0.22, sz), wood)
	for sz in [-0.18, 0.18]:
		_mesh(_cyl(0.012, 0.36), Vector3(0, 0.12, sz), wood, null, Vector3(0, 0, PI / 2.0))
	_mesh(_box(Vector3(0.46, 0.04, 0.44)), Vector3(0, 0.46, 0), plank)
	var straw := _mat(Color(0.78, 0.66, 0.42), 1.0)
	_mesh(_box(Vector3(0.38, 0.03, 0.36)), Vector3(0, 0.495, 0.01), straw)
	# Sırtlık (arkada, yerel -Z)
	for sx in [-0.19, 0.19]:
		_mesh(_cyl(0.022, 0.55), Vector3(sx, 0.75, -0.2), wood, null, Vector3(-0.1, 0, 0))
	for i in 3:
		_mesh(_box(Vector3(0.38, 0.05, 0.02)), Vector3(0, 0.62 + i * 0.13, -0.21 - i * 0.013), plank, null, Vector3(-0.1, 0, 0))


## Masa: kalaslı tabla, dört ayak ve çapraz destekler; üstünde kupa ve harita.
func _build_table() -> void:
	var wood: StandardMaterial3D = main.raft.mat_log
	var plank: StandardMaterial3D = main.raft.mat_plank
	for i in 4:
		_mesh(_box(Vector3(1.0, 0.045, 0.17)), Vector3(0, 0.76, -0.255 + i * 0.17), plank)
	for sx in [-0.42, 0.42]:
		for sz in [-0.27, 0.27]:
			_mesh(_cyl(0.03, 0.74, 0.035), Vector3(sx, 0.37, sz), wood)
	for sx in [-0.42, 0.42]:
		_mesh(_cyl(0.015, 0.6), Vector3(sx, 0.2, 0), wood, null, Vector3(PI / 2.0, 0, 0))
	_mesh(_cyl(0.015, 0.84), Vector3(0, 0.2, 0), wood, null, Vector3(0, 0, PI / 2.0))
	# Kupa
	var enamel := _mat(Color(0.93, 0.93, 0.9), 0.25)
	ToolModels._mi(self, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.045, 0.1), Vector2(0.04, 0.1), Vector2(0.035, 0.008), Vector2(0.0, 0.008)], 18), enamel, Vector3(0.28, 0.785, -0.12))
	var handle := TorusMesh.new()
	handle.rings = 24
	handle.ring_segments = 10
	handle.inner_radius = 0.018
	handle.outer_radius = 0.026
	_mesh(handle, Vector3(0.33, 0.835, -0.12), enamel, null, Vector3(PI / 2.0, 0, 0))
	# Harita: açılmış eski kâğıt
	var paper := _mat(Color(0.86, 0.79, 0.62), 0.95)
	_mesh(_box(Vector3(0.42, 0.004, 0.3)), Vector3(-0.15, 0.785, 0.05), paper, null, Vector3(0, 0.25, 0))
	var ink := _mat(Color(0.35, 0.25, 0.18), 0.9)
	_mesh(_box(Vector3(0.12, 0.002, 0.08)), Vector3(-0.2, 0.788, 0.04), ink, null, Vector3(0, 0.6, 0))
	_mesh(_box(Vector3(0.05, 0.002, 0.05)), Vector3(-0.08, 0.788, 0.1), ink, null, Vector3(0, 0.2, 0))


## Halı: Türk kilimi desenli, iki karo boyunda (yerel +Z yönündeki komşu karoya uzanır).
## Zeminle bir hizada; üstünden yürünür. İki kısa ucunda saçak.
func _build_rug() -> void:
	var rug := Node3D.new()
	rug.position = Vector3(0, 0, 0.75)
	add_child(rug)
	var top := PlaneMesh.new()
	top.size = Vector2(1.36, 2.86)
	var m := _mat(Color.WHITE, 1.0)
	m.albedo_texture = _kilim_texture()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_mesh(top, Vector3(0, 0.013, 0), m, rug)
	_mesh(_box(Vector3(1.36, 0.01, 2.86)), Vector3(0, 0.006, 0), _mat(Color(0.22, 0.12, 0.08), 1.0), rug)
	var fringe := _mat(Color(0.9, 0.84, 0.68), 1.0)
	for sz in [-1.0, 1.0]:
		for i in 16:
			_mesh(_box(Vector3(0.018, 0.006, 0.08)), Vector3(-0.63 + i * 0.084, 0.006, sz * 1.47), fringe, rug, Vector3(0, randf_range(-0.15, 0.15), 0))


## Kilim dokusu (96 x 192 ilmek): kenarda su yolu zikzağı, göz motifi şeridi, ortada üç basamaklı
## göbek; göbeklerin uçlarında koçboynuzu, ortalarında elibelinde; aralarda küçük göz motifleri.
static func _kilim_texture() -> ImageTexture:
	var W := 96
	var H := 192
	var red := Color(0.58, 0.11, 0.09)
	var indigo := Color(0.12, 0.17, 0.36)
	var cream := Color(0.9, 0.84, 0.68)
	var saffron := Color(0.86, 0.6, 0.15)
	var brown := Color(0.24, 0.13, 0.08)
	var green := Color(0.2, 0.38, 0.28)
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	for y in H:
		for x in W:
			var bx := mini(x, W - 1 - x)
			var by := mini(y, H - 1 - y)
			var bd := mini(bx, by)
			var along := x if by < bx else y
			var c := red
			if bd < 2:
				c = brown
			elif bd < 10:
				# Su yolu: lacivert şerit üstünde krem zikzak
				c = indigo
				var zz := absi(along % 12 - 6)
				if absf(float(bd - 3) - zz * 0.75) < 0.9:
					c = cream
			elif bd < 12:
				c = saffron
			elif bd < 18:
				# Göz motifi şeridi: kırmızı zeminde krem eşkenar dörtgen, ortası lacivert nokta
				c = red
				var g := absi(along % 10 - 5) + absf(float(bd - 12) - 2.5)
				if g < 3.0:
					c = cream
				if g < 1.5:
					c = indigo
			elif bd < 20:
				c = saffron
			else:
				var fx := x - W / 2
				var cy := 48 if y < 72 else (96 if y < 120 else 144)
				var fy := y - cy
				var ax := absi(fx)
				var ay := absi(fy)
				var d := ax + ay * 1.2
				if d < 26.0:
					# Basamaklı göbek (katmanlar dıştan içe)
					if d >= 23.0:
						c = indigo
					elif d >= 21.0:
						c = cream
					elif d >= 13.0:
						c = red
						# İç kırmızı katmanda küçük göz noktaları
						if (ax + ay) % 6 == 0 and ax % 3 == 0:
							c = cream
					elif d >= 11.0:
						c = saffron
					else:
						c = indigo
						# Elibelinde: belde daralan gövde, kalçaya konmuş kollar, baş ve ayak
						if ay <= 6 and ax <= 1 + int(ay * 0.55):
							c = cream
						if ay >= 6 and ay <= 7 and ax <= 4:
							c = cream
						if ay <= 2 and ax >= 3 and ax <= 5:
							c = cream
						if ay == 0 and ax <= 1:
							c = saffron
				else:
					# Koçboynuzu: göbeğin üst ve alt uçlarında dışa kıvrılan boynuzlar
					if ax <= 1 and ay >= 21 and ay <= 24:
						c = indigo
					if ay >= 23 and ay <= 24 and ax >= 2 and ax <= 5:
						c = indigo
					if ax >= 4 and ax <= 5 and ay >= 21 and ay <= 22:
						c = indigo
					# Göbek aralarında küçük göz motifleri
					var gx := absi(ax - 19)
					var gy := absi(ay - 24)
					if gx + gy < 4:
						c = cream
					if gx + gy < 2:
						c = green
			# Doğal boya tonu farkı (abraş)
			c = c.darkened(0.05 * (0.5 + 0.5 * sin(y * 0.21)))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _build_sail() -> void:
	var wood: StandardMaterial3D = main.raft.mat_log
	_mesh(_cyl(0.07, 3.3, 0.09), Vector3(0, 1.65, 0), wood)
	sail_pivot = Node3D.new()
	sail_pivot.position = Vector3(0, 0, 0)
	add_child(sail_pivot)
	_mesh(_cyl(0.045, 2.2), Vector3(0, 3.05, 0.08), wood, sail_pivot, Vector3(0, 0, PI / 2.0))
	_mesh(_cyl(0.04, 2.0), Vector3(0, 0.9, 0.08), wood, sail_pivot, Vector3(0, 0, PI / 2.0))
	var cloth := PlaneMesh.new()
	cloth.size = Vector2(2.0, 2.1)
	cloth.subdivide_width = 8
	cloth.subdivide_depth = 8
	var cm := _mat(Color(0.86, 0.82, 0.7), 0.95)
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sail_cloth = _mesh(cloth, Vector3(0, 1.98, 0.12), cm, sail_pivot, Vector3(PI / 2.0, 0, 0))
	_update_sail()


## Çapa: ahşap vinç (ipi sarılı tambur ve kol) + demir çapa. Kalkıkken çapa vincin yanında asılı durur.
func _build_anchor() -> void:
	var wood: StandardMaterial3D = main.raft.mat_log
	var rope_m := ToolModels.mat("rope")
	var iron := ToolModels.mat("iron")
	_mesh(_box(Vector3(0.75, 0.08, 0.55)), Vector3(0, 0.04, 0), wood)
	for x in [-0.3, 0.3]:
		_mesh(_box(Vector3(0.07, 0.52, 0.1)), Vector3(x, 0.32, 0), wood)
		_mesh(_box(Vector3(0.07, 0.07, 0.42)), Vector3(x, 0.12, 0), wood, null, Vector3(0.6, 0, 0))
	var drum := Node3D.new()
	drum.position = Vector3(0, 0.5, 0)
	drum.rotation.z = PI / 2.0
	add_child(drum)
	_mesh(_cyl(0.07, 0.56), Vector3.ZERO, wood, drum)
	ToolModels.wraps(drum, -0.2, 0.2, 0.08, 9, rope_m)
	for y in [-0.25, 0.25]:
		_mesh(_cyl(0.12, 0.03), Vector3(0, y, 0), iron, drum)
	# Krank kolu
	ToolModels._mi(self, ToolModels.tube([Vector3(0.33, 0.5, 0), Vector3(0.4, 0.5, 0), Vector3(0.4, 0.5, 0.14), Vector3(0.48, 0.5, 0.14)], 0.014, 8), iron)
	var a := ToolModels.anchor()
	a.name = "AnchorModel"
	a.scale = Vector3.ONE * 0.55
	a.position = Vector3(0, 0.12, 0.38)
	a.rotation = Vector3(0.25, 0, 0)
	add_child(a)
	rope = _mesh(_cyl(0.012, 1.0), Vector3(0, 0, 0.4), rope_m)
	rope.visible = false


## Eritme ocağı: taş kaide içinde ateş haznesi, üstünde tuğla tuğla örülmüş kil baca gövdesi,
## tepede demir pota (eritirken içi kızarır), arkadan çıkan demir boru, yanda körük, önde külçe tablası.
func _build_smelter() -> void:
	var stones: Array = []
	for c in [Color(0.33, 0.31, 0.29), Color(0.27, 0.26, 0.25), Color(0.38, 0.35, 0.31)]:
		stones.append(_mat(c, 0.95))
	var bricks: Array = []
	for c in [Color(0.48, 0.3, 0.22), Color(0.4, 0.25, 0.19), Color(0.54, 0.36, 0.27)]:
		bricks.append(_mat(c, 0.95))
	var mortar := _mat(Color(0.7, 0.66, 0.6), 1.0)
	var soot := _mat(Color(0.05, 0.04, 0.035), 1.0)
	var iron := ToolModels.mat("iron")
	var leather := ToolModels.mat("leather")
	var wood: StandardMaterial3D = main.raft.mat_log
	# Taş kaide: iki sıra düzensiz taş, önde ateş ağzı boşluğu
	_mesh(_box(Vector3(0.66, 0.3, 0.66)), Vector3(0, 0.16, 0), soot)
	var n := 0
	for layer in 2:
		var y := 0.085 + layer * 0.16
		for side in 4:
			for k in 4:
				var t := -0.3 + k * 0.2 + (0.1 if layer == 1 else 0.0)
				if t > 0.31:
					continue
				var pos := Vector3(t, y, 0.36)
				if side == 1:
					pos = Vector3(t, y, -0.36)
				elif side == 2:
					pos = Vector3(-0.36, y, t)
				elif side == 3:
					pos = Vector3(0.36, y, t)
				if side == 0 and absf(t) < 0.14:
					continue
				n += 1
				var sz := Vector3(0.2, 0.15, 0.13) if side < 2 else Vector3(0.13, 0.15, 0.2)
				_mesh(_box(sz * (0.92 + 0.1 * sin(n * 1.7))), pos, stones[n % 3], null, Vector3(0.05 * sin(n), 0.12 * sin(n * 2.3), 0.05 * cos(n)))
	_mesh(_box(Vector3(0.82, 0.06, 0.82)), Vector3(0, 0.35, 0), stones[1])
	# Ateş ağzı: demir çerçeve ve üst lento
	_mesh(_box(Vector3(0.34, 0.04, 0.08)), Vector3(0, 0.3, 0.38), iron)
	for x in [-0.15, 0.15]:
		_mesh(_box(Vector3(0.04, 0.26, 0.08)), Vector3(x, 0.15, 0.38), iron)
	# Tuğla gövde: halka halka, her sırada yarım tuğla kaydırılmış
	ToolModels._mi(self, ToolModels.lathe([Vector2(0.0, 0.38), Vector2(0.33, 0.38), Vector2(0.2, 1.14), Vector2(0.0, 1.14)], 20), mortar)
	for k in 8:
		var y := 0.43 + k * 0.095
		var r := lerpf(0.35, 0.22, k / 7.0)
		var cnt := int(TAU * r / 0.125)
		for i in cnt:
			var ang := TAU * (i + (0.5 if k % 2 == 1 else 0.0)) / cnt
			_mesh(_box(Vector3(TAU * r / cnt - 0.012, 0.085, 0.07)), Vector3(cos(ang) * r, y, sin(ang) * r),
				bricks[(i * 7 + k * 3) % 3], null, Vector3(-0.19, -ang - PI / 2.0, 0.0))
	# Tepe: taş bilezik ve demir pota
	var ring := TorusMesh.new()
	ring.inner_radius = 0.17
	ring.outer_radius = 0.25
	ring.rings = 20
	_mesh(ring, Vector3(0, 1.15, 0), stones[0])
	ToolModels._mi(self, ToolModels.lathe([Vector2(0.0, 1.06), Vector2(0.1, 1.06), Vector2(0.15, 1.12), Vector2(0.16, 1.24), Vector2(0.14, 1.24), Vector2(0.13, 1.13), Vector2(0.0, 1.11)], 18), iron)
	for sd in [-1.0, 1.0]:
		ToolModels._mi(self, ToolModels.tube([Vector3(sd * 0.15, 1.22, 0), Vector3(sd * 0.21, 1.27, 0), Vector3(sd * 0.15, 1.31, 0)], 0.01, 6), iron)
	molten_mat = _mat(Color(0.25, 0.1, 0.05), 0.4, 0.6)
	molten_mat.emission_enabled = true
	molten_mat.emission = Color(1.0, 0.45, 0.1)
	molten_mat.emission_energy_multiplier = 0.0
	_mesh(_cyl(0.135, 0.01), Vector3(0, 1.2, 0), molten_mat)
	# Arkadan çıkan demir baca borusu
	var pipe := [Vector3(0, 0.9, -0.24), Vector3(0, 0.94, -0.36), Vector3(0, 1.05, -0.4), Vector3(0, 1.6, -0.4)]
	ToolModels._mi(self, ToolModels.tube(pipe, 0.055, 14), iron)
	ToolModels._mi(self, ToolModels.lathe([Vector2(0.0, 1.66), Vector2(0.11, 1.62), Vector2(0.1, 1.6), Vector2(0.0, 1.63)], 14), iron, Vector3(0, 0, -0.4))
	# Körük: iki tahta kapak arasında deri, ucundan ateş haznesine giren boru
	var bel := Node3D.new()
	bel.position = Vector3(-0.56, 0.16, 0.12)
	bel.rotation = Vector3(0, 0.0, 0.0)
	add_child(bel)
	var board := [Vector2(-0.16, -0.1), Vector2(0.08, -0.06), Vector2(0.12, 0.0), Vector2(0.08, 0.06), Vector2(-0.16, 0.1)]
	for yy in [-0.06, 0.06]:
		ToolModels._mi(bel, ToolModels.plate(board, Vector3.BACK, Vector3.RIGHT, 0.012, 1.0), wood, Vector3(0, yy, 0))
	ToolModels._mi(bel, ToolModels.plate([Vector2(-0.14, -0.085), Vector2(0.1, -0.05), Vector2(0.1, 0.05), Vector2(-0.14, 0.085)], Vector3.BACK, Vector3.RIGHT, 0.05, 1.0), leather)
	_mesh(_cyl(0.012, 0.18), Vector3(0, 0.0, -0.24), wood, bel, Vector3(PI / 2.0, 0, 0))
	ToolModels._mi(self, ToolModels.tube([Vector3(-0.46, 0.16, 0.12), Vector3(-0.38, 0.14, 0.12), Vector3(-0.33, 0.14, 0.12)], 0.02, 8), iron)
	# Külçe tablası
	_mesh(_box(Vector3(0.26, 0.04, 0.18)), Vector3(0.36, 0.02, 0.52), wood)
	ingot_node = Node3D.new()
	ingot_node.position = Vector3(0.36, 0.045, 0.52)
	ingot_node.visible = false
	add_child(ingot_node)
	for i in 2:
		ToolModels._mi(ingot_node, ToolModels.plate([Vector2(-0.07, -0.035), Vector2(0.07, -0.035), Vector2(0.055, 0.035), Vector2(-0.055, 0.035)], Vector3.RIGHT, Vector3.BACK, 0.025, 0.7), ToolModels.mat("steel"), Vector3((i - 0.5) * 0.11, 0.0, 0.0), Vector3(0, 0.15 * i, 0))
	fuel = _fuel(Vector3(0, 0.07, 0.3), 0.9, "flat", PI / 2.0)
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.15)
	light.omni_range = 3.0
	light.light_energy = 0.0
	light.position = Vector3(0, 0.15, 0.62)
	add_child(light)
	fx = _particles(Vector3(0, 1.65, -0.4), Color(0.35, 0.33, 0.32, 0.4), 0.3, 0.8, Vector3(0, 0.3, 0))
	loop_snd = main.audio.loop_player("fire", self, -11.0)


func _build_collector() -> void:
	Props.place(self, "res://assets/models/Barrel_01/Barrel_01_1k.gltf", Vector3.ZERO, Vector3.ZERO, 1.0)
	var cloth := _mat(Color(0.8, 0.76, 0.62), 0.95)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	ToolModels._mi(self, ToolModels.lathe([Vector2(0.06, 0.86), Vector2(0.2, 0.92), Vector2(0.42, 1.02), Vector2(0.46, 1.06)], 16), cloth)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		_mesh(_cyl(0.015, 0.32), Vector3(cos(a) * 0.4, 0.92, sin(a) * 0.4), main.raft.mat_log, null, Vector3(0, 0, 0))
	var wm := _mat(Color(0.3, 0.55, 0.75, 0.8), 0.05)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mesh = _mesh(_cyl(0.22, 0.01), Vector3(0, 0.8, 0), wm)


## Kedi yatağı: örgü hasır sepet, içinde kırmızı minder.
func _build_cat_bed() -> void:
	var wicker := _mat(Color(0.72, 0.55, 0.32), 1.0)
	ToolModels._mi(self, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.26, 0.0), Vector2(0.3, 0.06), Vector2(0.31, 0.14), Vector2(0.27, 0.14), Vector2(0.25, 0.05), Vector2(0.0, 0.05)], 24), wicker)
	for i in 3:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.27 + i * 0.012
		ring.outer_radius = 0.3 + i * 0.012
		ring.rings = 24
		_mesh(ring, Vector3(0, 0.04 + i * 0.045, 0), _mat(Color(0.62, 0.46, 0.26), 1.0))
	var cushion := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radial_segments = 20
	sm.rings = 10
	sm.radius = 0.24
	sm.height = 0.12
	cushion.mesh = sm
	cushion.material_override = _mat(Color(0.7, 0.18, 0.15), 0.95)
	cushion.position.y = 0.07
	cushion.scale = Vector3(1.0, 0.6, 1.0)
	add_child(cushion)


## Sonar: ayaklı konsol, yeşil yuvarlak ekranda dönen tarama çizgisi, sudaki dönüştürücüye inen kablo.
func _build_sonar() -> void:
	var wood: StandardMaterial3D = main.raft.mat_log
	for sx in [-0.25, 0.25]:
		for sz in [-0.18, 0.18]:
			_mesh(_cyl(0.025, 0.55), Vector3(sx, 0.27, sz), wood)
	var case := _mat(Color(0.22, 0.26, 0.28), 0.5, 0.4)
	_mesh(_box(Vector3(0.62, 0.5, 0.44)), Vector3(0, 0.8, 0), case)
	var screen := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.17
	cm.bottom_radius = 0.17
	cm.height = 0.01
	cm.radial_segments = 32
	screen.mesh = cm
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float sweep = fract((a / 6.2831853) - TIME * 0.25);
	float beam = pow(1.0 - sweep, 8.0);
	float rings = smoothstep(0.03, 0.0, abs(fract(r * 3.0) - 0.5) - 0.47);
	float blip = smoothstep(0.06, 0.0, length(p - vec2(0.35, -0.3))) * (0.4 + beam);
	vec3 c = vec3(0.05, 0.25, 0.12) + vec3(0.2, 1.0, 0.45) * (beam * 0.7 + rings * 0.25 + blip);
	ALBEDO = c * step(r, 1.0);
	EMISSION = c * 1.6;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	screen.material_override = sm
	screen.position = Vector3(0, 0.82, 0.225)
	screen.rotation.x = PI / 2.0
	add_child(screen)
	var brass := _mat(Color(0.8, 0.62, 0.3), 0.3, 0.9)
	for i in 3:
		_mesh(_cyl(0.025, 0.03), Vector3(-0.2 + i * 0.2, 0.6, 0.225), brass, null, Vector3(PI / 2.0, 0, 0))
	# Kablo salın kenarından suya iner
	ToolModels._mi(self, ToolModels.tube([Vector3(0.0, 0.6, -0.22), Vector3(0.0, 0.3, -0.5), Vector3(0.0, -0.4, -0.8), Vector3(0.0, -1.2, -0.85)], 0.02, 5), _mat(Color(0.1, 0.1, 0.1), 0.7))
	_mesh(_cyl(0.08, 0.18), Vector3(0, -1.25, -0.85), case)


## Diken tuzağı: çapraz kütükler, uçları sivriltilmiş kazıklar dört yana, denize doğru eğik uzanır.
func _build_spikes() -> void:
	var wood: StandardMaterial3D = main.raft.mat_log
	var tipm := _mat(Color(0.75, 0.62, 0.45), 0.9)
	ToolModels._mi(self, ToolModels.tube([Vector3(-0.55, 0.15, -0.55), Vector3(0.55, 0.15, 0.55)], 0.07, 8), wood)
	ToolModels._mi(self, ToolModels.tube([Vector3(-0.55, 0.15, 0.55), Vector3(0.55, 0.15, -0.55)], 0.07, 8), wood)
	for k in 12:
		var a := TAU * k / 12.0 + 0.13
		var d := Vector3(cos(a), 0, sin(a))
		var base := d * 0.2 + Vector3(0, 0.15, 0)
		var tip := d * 0.85 + Vector3(0, 0.38 if k % 2 == 0 else 0.05, 0)
		ToolModels._mi(self, ToolModels.tube([base, base.lerp(tip, 0.75)], 0.035, 6), wood)
		ToolModels._mi(self, ToolModels.tube([base.lerp(tip, 0.75), tip], 0.035, 6, 0.05), tipm)
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		ToolModels._mi(self, ToolModels.tube([Vector3(cos(a) * 0.15, 0.1, sin(a) * 0.15), Vector3(cos(a + 0.6) * 0.15, 0.2, sin(a + 0.6) * 0.15)], 0.015, 4), _mat(Color(0.7, 0.6, 0.4), 1.0))


## Nazar direği: ahşap direk, kol ve ipte sallanan büyük nazar boncuğu.
var charm: Node3D


func _build_nazar() -> void:
	var wood: StandardMaterial3D = main.raft.mat_log
	ToolModels._mi(self, ToolModels.tube([Vector3(0, 0, 0), Vector3(0, 1.5, 0)], 0.04, 8), wood)
	ToolModels._mi(self, ToolModels.tube([Vector3(0, 1.42, 0), Vector3(0.38, 1.42, 0)], 0.025, 6), wood)
	charm = Node3D.new()
	charm.position = Vector3(0.36, 1.4, 0)
	add_child(charm)
	ToolModels._mi(charm, ToolModels.tube([Vector3.ZERO, Vector3(0, -0.3, 0)], 0.006, 4), _mat(Color(0.8, 0.15, 0.12)))
	var bead := ToolModels.nazar(0.13)
	bead.position = Vector3(0, -0.44, 0)
	charm.add_child(bead)


## Dümen: ahşap direk üstünde sekiz kollu dümen tekeri (tutamaklı). Teker yerel +Z'ye bakar; oyuncu önünde durur.
func _build_helm() -> void:
	var wood: StandardMaterial3D = main.raft.mat_log
	var plank: StandardMaterial3D = main.raft.mat_plank
	_mesh(_box(Vector3(0.5, 0.06, 0.4)), Vector3(0, 0.03, 0), plank)
	_mesh(_box(Vector3(0.22, 0.95, 0.22)), Vector3(0, 0.5, -0.05), plank)
	_mesh(_box(Vector3(0.28, 0.08, 0.28)), Vector3(0, 0.98, -0.05), wood)
	var brass := _mat(Color(0.8, 0.62, 0.3), 0.3, 0.9)
	_mesh(_cyl(0.035, 0.25), Vector3(0, 1.0, 0.1), brass, null, Vector3(PI / 2.0, 0, 0))
	wheel = Node3D.new()
	wheel.position = Vector3(0, 1.0, 0.22)
	add_child(wheel)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.36
	rim.outer_radius = 0.42
	rim.rings = 32
	_mesh(rim, Vector3.ZERO, wood, wheel, Vector3(PI / 2.0, 0, 0))
	_mesh(_cyl(0.07, 0.08), Vector3.ZERO, brass, wheel, Vector3(PI / 2.0, 0, 0))
	for i in 8:
		var a := TAU * i / 8.0
		var d := Vector3(cos(a), sin(a), 0)
		ToolModels._mi(wheel, ToolModels.tube([d * 0.05, d * 0.39], 0.018, 6), wood)
		ToolModels._mi(wheel, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.025, 0.0), Vector2(0.03, 0.06), Vector2(0.022, 0.12), Vector2(0.0, 0.14)], 8), wood, d * 0.41, Vector3(0, 0, a - PI / 2.0))


## Motor: dıştan takma deniz motoru; gövde, silindir kapağı, egzoz, yakıt deposu,
## salın arka kenarından suya inen şaft ve pervane. Motor yerel +Z'ye doğru iter.
func _build_motor() -> void:
	var body := _mat(Color(0.22, 0.32, 0.3), 0.45, 0.5)
	var iron := ToolModels.mat("iron")
	var red := _mat(Color(0.65, 0.12, 0.1), 0.5, 0.3)
	_mesh(_box(Vector3(0.6, 0.08, 0.6)), Vector3(0, 0.04, 0), main.raft.mat_plank)
	_mesh(_box(Vector3(0.42, 0.38, 0.5)), Vector3(0, 0.27, -0.05), body)
	ToolModels._mi(self, ToolModels.lathe([Vector2(0.0, 0.46), Vector2(0.17, 0.46), Vector2(0.15, 0.6), Vector2(0.0, 0.62)], 16), iron, Vector3(0, 0, -0.08))
	for i in 4:
		var fin := TorusMesh.new()
		fin.rings = 24
		fin.ring_segments = 10
		fin.inner_radius = 0.15
		fin.outer_radius = 0.18
		_mesh(fin, Vector3(0, 0.5 + i * 0.03, -0.08), iron)
	ToolModels._mi(self, ToolModels.tube([Vector3(0.15, 0.4, 0.1), Vector3(0.18, 0.7, 0.12), Vector3(0.18, 0.85, 0.12)], 0.03, 8), iron)
	_mesh(_cyl(0.1, 0.3), Vector3(-0.16, 0.25, 0.22), red, null, Vector3(0, 0, 0))
	_mesh(_cyl(0.03, 0.04), Vector3(-0.16, 0.42, 0.22), iron)
	# Şaft salın arka kenarından (-Z) suya iner
	ToolModels._mi(self, ToolModels.tube([Vector3(0, 0.15, -0.3), Vector3(0, 0.0, -0.72), Vector3(0, -0.55, -0.85)], 0.03, 8), iron)
	prop = Node3D.new()
	prop.position = Vector3(0, -0.6, -0.88)
	add_child(prop)
	for i in 3:
		var a := TAU * i / 3.0
		ToolModels._mi(prop, ToolModels.plate([Vector2(0.0, -0.02), Vector2(0.12, -0.04), Vector2(0.14, 0.02), Vector2(0.0, 0.02)], Vector3.RIGHT, Vector3.UP, 0.01, 0.6), _mat(Color(0.75, 0.62, 0.35), 0.3, 0.9), Vector3.ZERO, Vector3(0, 0, a))
	fx = _particles(Vector3(0.18, 0.88, 0.12), Color(0.3, 0.3, 0.3, 0.35), 0.25, 0.6, Vector3(0, 0.6, 0))
	loop_snd = main.audio.loop_player("engine", self, -8.0)


## Telsiz: ahşap sehpa üstünde kadranlı telsiz kutusu, hoparlör ızgarası, yeşil ışık ve anten.
func _build_radio() -> void:
	var wood: StandardMaterial3D = main.raft.mat_log
	var plank: StandardMaterial3D = main.raft.mat_plank
	for sx in [-0.22, 0.22]:
		for sz in [-0.16, 0.16]:
			_mesh(_cyl(0.02, 0.6), Vector3(sx, 0.3, sz), wood)
	_mesh(_box(Vector3(0.56, 0.04, 0.42)), Vector3(0, 0.6, 0), plank)
	# Cihaz: Poly Haven "Vintage Radio Transceiver" (CC0), masanın üstünde
	var radio: Node3D = (load("res://assets/models/vintage_radio_transceiver/vintage_radio_transceiver_1k.gltf") as PackedScene).instantiate()
	var k := 0.85
	radio.scale = Vector3.ONE * k
	radio.position = Vector3(-0.058 * k, 0.62 + 0.111 * k, 0.03 * k)
	add_child(radio)
	radio_led = _mat(Color(0.2, 0.9, 0.3), 0.5, 0.0)
	radio_led.emission_enabled = true
	radio_led.emission = Color(0.2, 1.0, 0.35)
	radio_led.emission_energy_multiplier = 0.2
	_mesh(_cyl(0.012, 0.01), Vector3(0.18, 0.95, 0.15), radio_led, null, Vector3(PI / 2.0, 0, 0))


func _build_lantern() -> void:
	var wood: StandardMaterial3D = main.raft.mat_log
	var iron := ToolModels.mat("iron")
	_mesh(_box(Vector3(0.3, 0.06, 0.3)), Vector3(0, 0.03, 0), wood)
	_mesh(_cyl(0.04, 1.2), Vector3(0, 0.6, 0), wood)
	ToolModels._mi(self, ToolModels.tube([Vector3(0, 1.15, 0), Vector3(0, 1.3, 0.05), Vector3(0, 1.32, 0.22)], 0.015, 8), iron)
	var lantern := Node3D.new()
	lantern.position = Vector3(0, 1.12, 0.22)
	add_child(lantern)
	ToolModels._mi(lantern, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.07, 0.0), Vector2(0.075, 0.02), Vector2(0.0, 0.025)], 12), iron)
	ToolModels._mi(lantern, ToolModels.lathe([Vector2(0.0, 0.16), Vector2(0.075, 0.16), Vector2(0.03, 0.22), Vector2(0.0, 0.23)], 12), iron)
	lamp_mat = _mat(Color(1.0, 0.85, 0.5, 0.6), 0.1)
	lamp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.7, 0.35)
	_mesh(_cyl(0.065, 0.14), Vector3(0, 0.09, 0), lamp_mat, lantern)
	for i in 4:
		var a := TAU * i / 4.0
		_mesh(_cyl(0.006, 0.15), Vector3(cos(a) * 0.068, 0.09, sin(a) * 0.068), iron, lantern)
	lamp = OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.72, 0.4)
	lamp.omni_range = 7.0
	lamp.shadow_enabled = true
	lamp.position = Vector3(0, 0.09, 0)
	lantern.add_child(lamp)
	open = true


func _update_sail() -> void:
	if sail_pivot == null:
		return
	var local_dir: Vector3 = (get_parent() as Node3D).global_transform.basis.inverse() * dir
	sail_pivot.rotation.y = atan2(local_dir.x, local_dir.z)
	sail_cloth.scale = Vector3(1, 1, 1) if open else Vector3(1, 1, 0.08)
	sail_cloth.position.y = 1.98 if open else 2.95


## Ağlar güverteyle bir hizadadır; üstünden yürünür, engel kutusu yoktur.
const FLAT := ["toplayici", "hali", "kedi_yatagi"]


## Yapının duran parçaları malzeme başına tek ağa birleşir. Betikte değişkenle tutulan düğümler
## (kapak, pervane, teker, bitki, alev, su, yelken...) hareket ettiği ya da gizlenip açıldığı için ayrı kalır.
func _bake_static() -> void:
	for p in get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var v = get(p["name"])
			if v is Node3D:
				(v as Node).set_meta("nomerge", true)
			elif v is Material:
				(v as Material).set_meta("unique", true)
	for n in ["AnchorModel", "Yakit", "Balik", "Patates"]:
		for c in find_children(n, "", true, false):
			c.set_meta("nomerge", true)
	Merge.bake(self, true)


func setup_collision() -> void:
	if kind in FLAT:
		return
	block_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZES[kind]
	block_shape.shape = box
	block_shape.position = position + Vector3(0, SIZES[kind].y / 2.0, 0)
	block_shape.rotation.y = rotation.y
	get_parent().add_child(block_shape)


func _exit_tree() -> void:
	if block_shape != null and is_instance_valid(block_shape):
		block_shape.queue_free()


func prompt(player) -> String:
	match kind:
		"aritici":
			if output != "":
				return "E: Temiz suyu al"
			if busy:
				return "Su arıtılıyor... %d sn" % int(ceil(timer))
			return "E: Arıtıcıyı yak (1 tahta)"
		"izgara":
			if output != "":
				return "E: Al (%s)" % Items.name_of(output)
			if busy:
				return "Pişiyor: %s... %d sn" % [Items.name_of(cooking), int(ceil(timer))]
			return "E: Pişir (çiğ balık / patates + 1 tahta)"
		"sandik":
			return "E: Sandığı aç (%s)" % type_name()
		"saksi":
			if not planted:
				var sd := _seed_choice(player)
				return "E: Ek: %s  ·  başka tohum için onu eline al" % Items.name_of(sd) if sd != "" else "Ekecek tohum yok (varillerden ve adalardan çıkar)"
			var crop: String = Crops.CROPS.get(cooking if cooking != "" else "tohum", Crops.CROPS["tohum"])["crop"]
			if growth >= 1.0:
				return "E: Hasat et (%s)" % Items.name_of(crop)
			return "%s büyüyor... %%%d" % [Items.name_of(crop), int(growth * 100.0)]
		"yatak":
			return "E: Uyu (gece) / Kaydet"
		"sandalye":
			return "E: Otur"
		"dumen":
			var names := ["Kuzey", "Kuzeydoğu", "Doğu", "Güneydoğu", "Güney", "Güneybatı", "Batı", "Kuzeybatı"]
			return "E: Dümene geç  ·  rota %03d° %s" % [int(main.raft.course), names[int(round(fposmod(main.raft.course, 360.0) / 45.0)) % 8]]
		"motor":
			var fuel_txt := "yakıt %d sn" % int(timer) if timer > 0.0 else "yakıt yok"
			if timer <= 0.0:
				return "Motor: %s  ·  E: yakıt koy (tahta ya da zeytinyağı)" % fuel_txt
			return "E: Motoru %s  ·  %s  ·  elinde tahta/zeytinyağı varken E: yakıt ekle" % ["durdur" if open else "çalıştır", fuel_txt]
		"telsiz":
			if main.nav_target != null:
				return "E: Dinle  ·  hedef: %s" % main.nav_name
			return "E: Telsizi dinle (sönmüş fenerlerin sinyalini arar)"
		"masa", "hali":
			return ""
		"yelken":
			if open:
				return "E: Yelkeni indir  ·  verim %%%d (%s)" % [int(main.raft.sail_efficiency(dir) * 100.0), main.world.wind_name()]
			return "E: Yelkeni aç (baktığın yöne)"
		"capa":
			return "E: Çapayı %s" % ("kaldır" if open else "at")
		"toplayici":
			var n := 0
			for s in storage.slots:
				if s != null:
					n += s["n"]
			return "E: Ağdakileri al (%d eşya)" % n if n > 0 else "Ağ boş — yanından geçen enkazı yakalar"
		"ocak":
			if output != "":
				return "E: %s al" % Items.name_of(output)
			if busy:
				return "Eritiliyor: %s... %d sn" % [Items.name_of(cooking), int(ceil(timer))]
			var sm = _smelt_choice(player)
			if sm.is_empty():
				return "Eritme ocağı: 2 hurda / 2 demir cevheri → metal külçe, 2 kum → cam (+1 tahta yakıt)"
			return "E: 2 %s erit → %s (+1 tahta)  ·  elindekine göre seçer" % [Items.name_of(sm[0]), Items.name_of(sm[1])]
		"yagmur_toplayici":
			if stock > 0:
				return "E: Temiz su al (%d/3)" % stock
			return "Yağmur bekleniyor... (boş)"
		"fener":
			return "E: Feneri %s" % ("söndür" if open else "yak")
		"nazar":
			return "Nazar boncuğu: köpekbalığı salı daha seyrek ısırır"
		"sonar":
			var found: int = main.wreck_sites.filter(func(s): return s.get("found", false)).size()
			return "Sonar: %d batık bulundu  ·  E: en yakın batığa hedef koy" % found
		"diken_tuzagi":
			return "Diken tuzağı: bu karoyu ve yanındakileri korur (%d/3)" % stock
	return ""


func interact(player) -> void:
	if kind == "sonar":
		main.sonar_target()
		return
	match kind:
		"aritici":
			if output != "":
				player.give(output, 1)
				output = ""
			elif not busy:
				if player.inv.spend({"tahta": 1}):
					busy = true
					timer = BOIL_TIME
				else:
					main.hud.toast("Yakıt için 1 tahta gerekli")
		"izgara":
			if output != "":
				player.give(output, 1)
				output = ""
			elif not busy:
				var raw := ""
				for id in ["ham_balik", "patates"]:
					if player.inv.count(id) > 0:
						raw = id
						break
				if raw == "":
					main.hud.toast("Pişirecek çiğ balık ya da patates yok")
				elif not player.inv.spend({"tahta": 1}):
					main.hud.toast("Yakıt için 1 tahta gerekli")
				else:
					player.inv.remove(raw, 1)
					cooking = raw
					busy = true
					timer = COOK_TIME
		"sandik":
			main.audio.play_at("chest_open", global_position)
			main.hud.open_chest(self)
		"saksi":
			if not planted:
				var sd := _seed_choice(player)
				if sd != "" and player.inv.remove(sd, 1):
					planted = true
					growth = 0.0
					_set_crop(sd)
					main.audio.play("cloth", -8.0)
				else:
					main.hud.toast("Ekecek tohum yok — varillerden ve adalardan çıkar")
			elif growth >= 1.0:
				var sd: String = cooking if cooking != "" else "tohum"
				var d: Dictionary = Crops.CROPS[sd]
				player.give(d["crop"], d["n"])
				if d["perennial"]:
					# Zeytin fidanı kalır, yeniden meyveye durur
					growth = 0.35
				else:
					player.give(sd, randi_range(1, 2))
					planted = false
					growth = 0.0
					_set_crop("")
				main.quests.event("harvest", d["crop"])
		"yatak":
			main.sleep(self)
		"sandalye":
			player.sit(self)
		"dumen":
			player.take_helm(self)
		"motor":
			var held: String = player.held_id()
			var adds := {"zeytinyagi": 180.0, "tahta": 40.0}
			if adds.has(held) or timer <= 0.0:
				var used := ""
				if adds.has(held) and player.inv.count(held) > 0:
					used = held
				else:
					for k in ["zeytinyagi", "tahta"]:
						if player.inv.count(k) > 0:
							used = k
							break
				if used == "":
					main.hud.toast("Motor için yakıt gerekli: tahta (40 sn) ya da zeytinyağı (3 dk)")
				else:
					player.inv.remove(used, 1)
					timer += adds[used]
					main.hud.toast("Motora %s kondu (+%d sn)" % [Items.name_of(used), int(adds[used])])
					main.audio.play("metal", -6.0)
			else:
				open = not open
				main.audio.play("metal", -4.0)
				main.hud.toast("Motor çalıştı" if open else "Motor durdu")
		"telsiz":
			main.audio.play_at("radio", global_position, 0.0, 6.0)
			radio_led.emission_energy_multiplier = 4.0
			get_tree().create_timer(1.6).timeout.connect(func(): _radio_result(player))
		"yelken":
			open = not open
			if open:
				var f: Vector3 = -player.camera.global_transform.basis.z
				f.y = 0.0
				dir = f.normalized()
			main.audio.play_at("cloth", global_position)
			_update_sail()
		"capa":
			open = not open
			main.audio.play_at("metal", global_position)
			main.hud.toast("Çapa atıldı, sal duruyor." if open else "Çapa kaldırıldı.")
		"toplayici":
			for i in storage.slots.size():
				var s = storage.slots[i]
				if s != null:
					player.give(s["id"], s["n"])
					storage.slots[i] = null
			# Ağ bölmesindeki görüntüler de temizlensin.
			storage.changed.emit()
		"ocak":
			if output != "":
				player.give(output, 1)
				output = ""
			elif not busy:
				var sm = _smelt_choice(player)
				if not sm.is_empty() and player.inv.spend({sm[0]: 2, "tahta": 1}):
					busy = true
					timer = SMELT_TIME
					cooking = sm[1]
				else:
					main.hud.toast("Eritmek için 2 hurda, 2 demir cevheri ya da 2 kum ve yakıt için 1 tahta gerekli")
		"yagmur_toplayici":
			if stock > 0:
				player.give("temiz_su", stock)
				stock = 0
				growth = 0.0
		"fener":
			open = not open
			main.audio.play("click", -6.0)


func _process(delta: float) -> void:
	if main.paused and not showcase:
		return
	if charm != null:
		var tt := Time.get_ticks_msec() * 0.001
		charm.rotation = Vector3(sin(tt * 1.3 + cell.x) * 0.12, sin(tt * 0.7) * 0.6, sin(tt * 1.1 + cell.y) * 0.15)
	if ember_mat != null and busy:
		ember_mat.emission_energy_multiplier = 1.8 + sin(Time.get_ticks_msec() * 0.009 + cell.x) * 0.6 + randf() * 0.3
	match kind:
		"aritici", "izgara":
			if kind == "aritici" and water_mesh != null:
				water_mesh.visible = output != ""
			if busy:
				timer -= delta
				if timer <= 0.0:
					busy = false
					output = "temiz_su" if kind == "aritici" else Items.info(cooking).get("cook", cooking)
					cooking = ""
			if fx != null:
				fx.emitting = busy
			if loop_snd != null:
				if busy and not loop_snd.playing:
					loop_snd.play()
				elif not busy and loop_snd.playing:
					loop_snd.stop()
			if light != null:
				light.light_energy = (1.4 + randf() * 0.4) if busy else 0.0
			if fuel != null:
				fuel.visible = busy
			if coal_mat != null:
				coal_mat.emission_energy_multiplier = (2.2 + randf() * 0.6) if busy else 0.0
			if kind == "izgara" and food_visual != null:
				var item := cooking if busy else output
				food_visual.visible = item != ""
				if item != "":
					var is_fish := item.contains("balik")
					var fish: Node3D = food_visual.get_node("Balik")
					fish.visible = is_fish
					(food_visual.get_node("Patates") as Node3D).visible = not is_fish
		"saksi":
			if planted and growth < 1.0:
				var mult: float = Crops.CROPS.get(cooking if cooking != "" else "tohum", Crops.CROPS["tohum"])["time"]
				growth = minf(1.0, growth + delta / (GROW_TIME * mult) * (2.0 if main.world.rain > 0.5 else 1.0))
			plant.visible = planted
			plant.scale = Vector3.ONE * lerpf(0.15, 1.0, growth)
		"sandik":
			var target := -1.1 if main.hud.chest == self else 0.0
			lid.rotation.x = lerpf(lid.rotation.x, target, minf(1.0, delta * 8.0))
		"yelken":
			if open and sail_cloth != null:
				sail_cloth.scale.y = 1.0 + sin(Time.get_ticks_msec() * 0.002) * 0.03
		"capa":
			rope.visible = open
			var am: Node3D = get_node("AnchorModel")
			am.visible = not open
			if open:
				rope.scale.y = 6.0
				rope.position = Vector3(0, -2.6, 0.4)
		"toplayici":
			if showcase:
				return
			# Ağın çevresinden ya da suya sarkan kepçesinin önünden geçen enkazı yakala.
			# Hangi yöne bakarsa baksın toplar.
			var catch_point := global_transform * Vector3(0, -0.3, 1.2)
			for d in main.debris.duplicate():
				if d.hooked or d.kind == "sise":
					continue
				var dd: Vector3 = d.global_position - catch_point
				dd.y = 0.0
				var dc: Vector3 = d.global_position - global_position
				dc.y = 0.0
				if dd.length() < 1.8 or dc.length() < 2.2:
					var l: Dictionary = d.loot()
					var full := false
					for k in l:
						if storage.add(k, l[k]) > 0:
							full = true
					if not full:
						main.remove_debris(d)
						main.audio.play_at("splash", catch_point, -12.0)
		"ocak":
			if busy:
				timer -= delta
				if timer <= 0.0:
					busy = false
					output = cooking if cooking != "" else "metal_kulce"
					cooking = ""
			fx.emitting = busy
			fuel.visible = busy
			light.light_energy = (1.0 + randf() * 0.35) if busy else 0.0
			molten_mat.emission_energy_multiplier = (2.5 + randf() * 0.5) if busy else 0.0
			ingot_node.visible = output != ""
			if busy and not loop_snd.playing:
				loop_snd.play()
			elif not busy and loop_snd.playing:
				loop_snd.stop()
		"yagmur_toplayici":
			if stock < 3 and main.world.rain > 0.4:
				growth += delta / 40.0 * main.world.rain
				if growth >= 1.0:
					growth = 0.0
					stock += 1
			water_mesh.position.y = 0.55 + 0.1 * stock + 0.1 * growth
			water_mesh.visible = stock > 0 or growth > 0.05
		"motor":
			var running: bool = open and timer > 0.0
			if running:
				timer = maxf(0.0, timer - delta)
				prop.rotation.z += delta * 25.0
				if timer <= 0.0:
					open = false
					main.hud.toast("Motorun yakıtı bitti.")
			fx.emitting = running
			if running and not loop_snd.playing:
				loop_snd.play()
			elif not running and loop_snd.playing:
				loop_snd.stop()
		"fener":
			var on: bool = open and (main.world.is_night() or main.world.rain > 0.5 or main.player.head_under)
			lamp.visible = on
			lamp.light_energy = 1.6 + sin(Time.get_ticks_msec() * 0.011) * 0.08
			lamp_mat.emission_energy_multiplier = 3.0 if on else 0.0


func to_data() -> Dictionary:
	var d := {"kind": kind, "cell": [cell.x, cell.y], "busy": busy, "timer": timer, "output": output,
		"cooking": cooking, "growth": growth, "planted": planted, "open": open, "dir": [dir.x, dir.z], "stock": stock, "rot": rotation.y,
		"level": level, "ctype": ctype}
	if storage != null:
		d["storage"] = storage.to_data()
	return d


func from_data(d: Dictionary) -> void:
	busy = d.get("busy", false)
	timer = float(d.get("timer", 0.0))
	output = d.get("output", "")
	cooking = d.get("cooking", "")
	growth = float(d.get("growth", 0.0))
	planted = d.get("planted", false)
	open = d.get("open", false)
	stock = int(d.get("stock", 0))
	if kind == "saksi" and planted:
		_set_crop(cooking if cooking != "" else "tohum")
	ctype = d.get("ctype", "karisik")
	_update_type_label()
	var dd: Array = d.get("dir", [0.0, -1.0])
	dir = Vector3(dd[0], 0, dd[1]).normalized()
	if storage != null and d.has("storage"):
		storage.from_data(d["storage"])
	_update_sail()
