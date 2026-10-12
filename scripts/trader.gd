extends Node3D
## Gezgin tüccar: Rıza Kaptan ve tirhandil teknesi "Mavi Yolcu" (tekne koddan; kaptan Quaternius CC0 karakteri).
## Ara ara ufukta belirir, çan çalarak salın bir kenarına yanaşır, bir süre bekler; takas eder, söylenti satar,
## sonra yelken açıp gider. Takasta para yok: denizden ve adalardan topladığını verir, işine yarayanı alırsın.

const Waves = preload("res://scripts/waves.gd")
const Items = preload("res://scripts/items.gd")
const ToolModels = preload("res://scripts/tool_models.gd")
const BuildingScript = preload("res://scripts/building.gd")
const Merge = preload("res://scripts/merge.gd")
const MODEL := "res://assets/models/q_farmer/farmer.glb"

enum S { ARRIVE, DOCKED, LEAVE }

const STAY := 240.0
const SPEED := 6.0
const LENGTH := 7.0
## Yarım genişlik ve güverte yüksekliği (su üstünde)
const BEAM := 1.25
const DECK := 0.55
const KEEL := 0.6
## Baş kemiğine göre bıyık (metre)
const MUSTACHE_POS := Vector3(0, 0.07, 0.11)

## Takas listesi: [verdiğin, aldığın]. Her gelişte rastgele beşi, bir de söylenti çıkar.
const OFFERS := [
	[{"ham_balik": 3}, {"domates_tohumu": 2}],
	[{"hindistan_cevizi": 3}, {"karpuz_tohumu": 1}],
	[{"marti_yumurtasi": 3}, {"biber_tohumu": 2}],
	[{"zeytin": 10}, {"zeytin_fidani": 1}],
	[{"pismis_balik": 3}, {"metal_kulce": 2}],
	[{"zeytinyagi": 2}, {"mercek": 1}],
	[{"tas": 8}, {"cam": 2}],
	[{"hali": 1}, {"civi": 12}],
	[{"pismis_yengec": 2}, {"kumas": 3}],
	[{"hurda": 4}, {"konserve": 3}],
	[{"plastik": 6}, {"su_sise": 3}],
	[{"kumas": 2, "ip": 2}, {"nazar": 1}],
	[{"metal_kulce": 2}, {"pusula": 1}],
	[{"zeytin": 6}, {"cay": 3}],
	[{"yaprak": 10}, {"cay": 2}],
	[{"metal_kulce": 3, "cam": 2}, {"durbun": 1}],
	[{"demir_cevheri": 6}, {"zeytinyagi": 2}],
	[{"tahta": 12}, {"tohum": 3}],
	[{"inci": 2}, {"mercek": 1}],
	[{"inci": 1}, {"zeytin_fidani": 1}],
	[{"inci": 3}, {"oksijen_tupu": 1}],
	[{"deniz_yosunu": 8}, {"cay": 2}],
	[{"istiridye": 3}, {"kopekbaligi_yemi": 2}],
	[{"antik_sikke": 3}, {"mercek": 1}],
	[{"antik_sikke": 5}, {"oksijen_tupu": 1}],
	[{"antik_sikke": 4}, {"dalgic_feneri": 1}],
	[{"antik_sikke": 2}, {"cay": 3}],
	[{"bronz_heykel": 1}, {"metal_kulce": 6}],
	[{"bronz_heykel": 1}, {"durbun": 1}],
]
## Söylenti: en yakın sönmüş feneri haritada işaretler.
const RUMOR := [{"pismis_balik": 2}, {"ipucu": 1}]

const GREETINGS := [
	"Selamün aleyküm, kazazede! Rıza Kaptan derler bana. Ne var ne yok, bir bakalım.",
	"Hayırlı rüzgârlar! Mavi Yolcu'da her şeyden biraz var. Para geçmez bu denizde, takas ederiz.",
	"Bak sen, sal dediğin böyle olur! Gel, gel; teknede taze tohum da var, mercek de.",
	"Lodos çıkmadan iş görelim, evlat. Ne verirsen onu alırım, ne lazımsa onu veririm.",
]
const RUMORS := [
	"\"Hızır denize düşenin elinden tutar derler. Ama önce fenerler yanmalı, karanlıkta kimse yolunu bulamaz.\"",
	"\"Mavi Pusula'nın ekibini son gören benim. Bir feneri onarmaya gidiyorlardı... Işığı hâlâ sönük.\"",
	"\"Hıdırellez gecesi bir ada belirirmiş, dilek ağacı varmış üstünde. Fenerler yanarsa yol görünürmüş.\"",
	"\"Eski fenerciler kandile zeytinyağı koyardı. Taşla, camla, merceğle onarılır o kuleler.\"",
]

var main
var state := S.ARRIVE
var stay := STAY
## Salın yerel ekseninde yanaşılan kenarın yönü ve teknenin yerel konumu
var dock_dir := Vector3.RIGHT
var dock_local := Vector3.ZERO
var offers: Array = []
var trades := 0
var person: Node3D
var anim: AnimationPlayer
var wave_t := 0.0
var bob_t := 0.0
var flag_mat: ShaderMaterial
var speed := SPEED
var greeted := false
## Efsanevi adanın kıyısında demirli (gelip gitmez)
var fixed := false


func _ready() -> void:
	_build_boat()
	_build_captain()
	_pick_offers()


## Rastgele beş takas ve söylenti. Her takasın stoku 1-3.
func _pick_offers() -> void:
	offers.clear()
	var pool: Array = OFFERS.duplicate()
	pool.shuffle()
	for i in 5:
		offers.append({"give": pool[i][0], "get": pool[i][1], "stock": randi_range(1, 3)})
	offers.append({"give": RUMOR[0], "get": RUMOR[1], "stock": 2})


## Salın rastgele bir kenarı seçilir; tekne ufuktan, o kenarın açığından gelir.
func setup() -> void:
	dock_dir = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD].pick_random()
	_compute_dock()
	var dw := _dock_world_dir()
	var side := dw.cross(Vector3.UP)
	global_position = _dock_global() + dw * 110.0 + side * randf_range(-40.0, 40.0)
	global_position.y = 0.0
	var to := _dock_global() - global_position
	rotation.y = atan2(-to.z, to.x)


## Hemen yanaşık hâle getirir (test ve görsel kontrol için).
func dock_now() -> void:
	_compute_dock()
	_dock()


func _compute_dock() -> void:
	var raft = main.raft
	var ext := -INF
	for c in raft.tiles:
		ext = maxf(ext, (raft.cell_pos(c) as Vector3).dot(dock_dir))
	ext += raft.CELL * 0.5
	var ctr: Vector3 = raft.center_local()
	dock_local = ctr - dock_dir * ctr.dot(dock_dir) + dock_dir * (ext + BEAM + 0.3)
	dock_local.y = 0.0


func _dock_world_dir() -> Vector3:
	var d: Vector3 = main.raft.global_transform.basis * dock_dir
	d.y = 0.0
	return d.normalized()


func _dock_global() -> Vector3:
	var p: Vector3 = main.raft.to_global(dock_local)
	p.y = 0.0
	return p


## Yanaşıkken tekne boyu salın kenarına paralel, kaptanın tarafı (yerel -Z) sala dönük.
func _dock_yaw() -> float:
	var dw := _dock_world_dir()
	return atan2(dw.x, dw.z)


func _dock() -> void:
	state = S.DOCKED
	stay = STAY
	global_position = _dock_global()
	rotation.y = _dock_yaw()
	main.audio.play_at("bell", global_position, 0.0, 30.0)
	_play("Wave")
	wave_t = 2.6
	if not greeted:
		greeted = true
		main.hud.toast("Rıza Kaptan: \"%s\"  ·  E ile takas" % GREETINGS.pick_random(), 7.0)


func leave() -> void:
	if state == S.LEAVE:
		return
	state = S.LEAVE
	speed = 0.5
	main.audio.play_at("bell", global_position, -4.0, 30.0)
	main.hud.toast("Rıza Kaptan: \"Kısmetse yine görüşürüz! Rüzgârın bol olsun.\"", 5.0)
	_play("Wave")
	wave_t = 2.6
	if main.hud.trade == self:
		main.hud.close_menus()


func _process(delta: float) -> void:
	if main.paused:
		return
	bob_t += delta
	if wave_t > 0.0:
		wave_t -= delta
		if wave_t <= 0.0:
			_play("Idle")
	if fixed:
		state = S.DOCKED
	match -1 if fixed else state:
		S.ARRIVE:
			var tgt := _dock_global()
			var to := tgt - global_position
			to.y = 0.0
			var dist := to.length()
			if dist < 0.4:
				_dock()
			else:
				var sp := minf(SPEED, dist * 0.7 + 0.6)
				global_position += to / dist * minf(sp * delta, dist)
				# Uzaktan pruva hedefe, yaklaşınca yanaşma yönüne döner
				var yaw_move := atan2(-to.z, to.x)
				var k := clampf((dist - 3.0) / 12.0, 0.0, 1.0)
				var want := lerp_angle(_dock_yaw(), yaw_move, k)
				rotation.y = lerp_angle(rotation.y, want, minf(1.0, delta * 1.5))
		S.DOCKED:
			global_position = _dock_global()
			rotation.y = _dock_yaw()
			if main.hud.trade != self:
				stay -= delta
			if stay <= 0.0:
				leave()
		S.LEAVE:
			# Önce açığa çıkar, sonra pruva yönünde hızlanır
			speed = minf(SPEED, speed + delta * 1.2)
			var fwd := global_transform.basis.x
			fwd.y = 0.0
			var out := _dock_world_dir()
			global_position += (fwd.normalized() * 0.7 + out * 0.5).normalized() * speed * delta
			rotation.y = lerp_angle(rotation.y, atan2(-out.z, out.x), minf(1.0, delta * 0.25))
			if global_position.distance_to(main.raft.center_global()) > 160.0:
				main.trader_left(self)
				return
	# Dalgada sallanma
	var p := global_position
	global_position.y = Waves.height(p.x, p.z) * 0.7 + sin(bob_t * 1.3) * 0.03
	var n := Waves.normal(p.x, p.z)
	var lb := global_transform.basis.inverse() * n
	rotation.x = lerp_angle(rotation.x, clampf(lb.z, -0.12, 0.12) + sin(bob_t * 0.9) * 0.015, minf(1.0, delta * 2.0))
	rotation.z = lerp_angle(rotation.z, clampf(-lb.x, -0.08, 0.08), minf(1.0, delta * 2.0))
	if person != null and main.player != null and state == S.DOCKED:
		# Kaptan oyuncuya döner
		var lp := to_local(main.player.global_position)
		var face := atan2(lp.x, lp.z)
		person.rotation.y = lerp_angle(person.rotation.y, face, minf(1.0, delta * 3.0))


# --- Takas -------------------------------------------------------------------

func prompt(_player) -> String:
	if fixed:
		return "E: Rıza Kaptan ile konuş"
	match state:
		S.DOCKED:
			return "E: Rıza Kaptan ile takas"
		S.ARRIVE:
			return "Mavi Yolcu yanaşıyor..."
	return ""


func interact(_player) -> void:
	if fixed and not main.hud.lore.read.has("hizir"):
		main.hud.lore.read_note("hizir")
		return
	if state == S.DOCKED:
		main.hud.open_trade(self)
		_play("Interact")
		wave_t = 2.4


func can_trade(i: int) -> bool:
	var o: Dictionary = offers[i]
	return int(o["stock"]) > 0 and state == S.DOCKED and main.player.inv.has_all(o["give"])


## Takası yapar; söylentiyse en yakın sönmüş feneri işaretler. Dönen metin takas ekranında gösterilir.
func trade(i: int) -> String:
	if i < 0 or i >= offers.size() or not can_trade(i):
		return ""
	var o: Dictionary = offers[i]
	if not main.player.inv.spend(o["give"]):
		return ""
	o["stock"] = int(o["stock"]) - 1
	trades += 1
	stay = maxf(stay, 60.0)
	var said := ""
	var rumor := false
	for k in o["get"]:
		if k == "ipucu":
			rumor = true
			said = _rumor()
		else:
			main.player.give(k, int(o["get"][k]))
			said = "\"Hayırlı olsun! %d %s senin.\"" % [int(o["get"][k]), Items.name_of(k)]
	main.audio.play("chest_open", -6.0, "Arayuz")
	main.quests.event("trade", "ipucu" if rumor else "", 1)
	return said


func _rumor() -> String:
	var lm: Dictionary = main.nearest_dark_lighthouse(main.raft.center_global())
	main.nav_target = Vector3(float(lm["x"]), 0, float(lm["z"]))
	main.nav_name = lm["name"]
	var d: Vector3 = main.nav_target - main.raft.center_global()
	var deg := fposmod(rad_to_deg(atan2(d.x, -d.z)), 360.0)
	var names := ["kuzey", "kuzeydoğu", "doğu", "güneydoğu", "güney", "güneybatı", "batı", "kuzeybatı"]
	return "%s  %s %d m %s yönünde; haritana işaretledim." % [RUMORS.pick_random(), lm["name"], int(Vector2(d.x, d.z).length()), names[int(round(deg / 45.0)) % 8]]


func time_left() -> float:
	return stay


# --- Model -------------------------------------------------------------------

func _m(c: Color, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return ToolModels._mi(parent, b, mat, pos, rot)


## Kesit yarı genişliği ve küpeşte yüksekliği (t: -1 kıç, +1 pruva)
static func _half_beam(t: float) -> float:
	var k := 1.0 - t * t
	if t > 0.0:
		k = 1.0 - pow(t, 1.6)
	return BEAM * pow(maxf(k, 0.0), 0.55)


static func _sheer(t: float) -> float:
	return DECK + 0.32 * t * t + (0.12 * t if t > 0.0 else 0.0)


## Tirhandil: iki ucu sivri, uçları kalkık gövde. Kesit U biçimli; şeritler ayrı malzeme:
## mavi küpeşte şeridi, beyaz borda, su altında kırmızı zehirli boya.
func _build_boat() -> void:
	var hull := Node3D.new()
	add_child(hull)
	var bands := [SurfaceTool.new(), SurfaceTool.new(), SurfaceTool.new()]
	for st in bands:
		(st as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
	var NS := 28
	var NR := 18
	var grid: Array = []
	var norms: Array = []
	for i in NS + 1:
		var t := -1.0 + 2.0 * i / NS
		var x := t * LENGTH * 0.5
		var b := maxf(_half_beam(t), 0.015)
		var top := _sheer(t)
		var h := top + KEEL * (1.0 - pow(absf(t), 3.0) * 0.7)
		var row: Array = []
		var nrow: Array = []
		for j in NR + 1:
			var phi := -PI / 2.0 + PI * j / NR
			row.append(Vector3(x, top - h * cos(phi), b * sin(phi)))
			nrow.append(Vector3(0.0, -b * cos(phi), h * sin(phi)).normalized())
		grid.append(row)
		norms.append(nrow)
	for i in NS:
		for j in NR:
			var ph := absf(-PI / 2.0 + PI * (j + 0.5) / NR)
			var band := 0 if ph > 1.36 else (1 if ph > 1.05 else 2)
			var st: SurfaceTool = bands[band]
			for q in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]:
				st.set_normal(norms[q[0]][q[1]])
				st.add_vertex(grid[q[0]][q[1]])
	var cols := [Color(0.12, 0.33, 0.62), Color(0.93, 0.92, 0.88), Color(0.55, 0.16, 0.12)]
	for k in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = (bands[k] as SurfaceTool).commit()
		mi.material_override = _m(cols[k], 0.55 if k < 2 else 0.85)
		hull.add_child(mi)
	# Güverte: küpeştenin biraz altında tahta döşeme
	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in NS:
		var a0: Vector3 = grid[i][0]
		var a1: Vector3 = grid[i][NR]
		var b0: Vector3 = grid[i + 1][0]
		var b1: Vector3 = grid[i + 1][NR]
		for v in [a0, b0, b1, a0, b1, a1]:
			deck.set_normal(Vector3.UP)
			deck.add_vertex(v - Vector3(0, 0.07, 0))
	var dmi := MeshInstance3D.new()
	dmi.mesh = deck.commit()
	dmi.material_override = ToolModels.mat("wood")
	hull.add_child(dmi)
	# Küpeşte (ahşap tırabzan) iki yanda
	var port: Array = []
	var star: Array = []
	for i in NS + 1:
		port.append((grid[i][0] as Vector3) + Vector3(0, 0.03, 0))
		star.append((grid[i][NR] as Vector3) + Vector3(0, 0.03, 0))
	var rail := ToolModels.mat("dark_wood")
	ToolModels._mi(hull, ToolModels.tube(port, 0.05, 6), rail)
	ToolModels._mi(hull, ToolModels.tube(star, 0.05, 6), rail)
	# Pruva bodoslaması
	var stem: Vector3 = grid[NS][0]
	ToolModels._mi(hull, ToolModels.tube([stem + Vector3(-0.05, -0.6, 0), stem + Vector3(0.12, 0.25, 0)], 0.06, 6), rail)
	var bead := ToolModels.nazar(0.09)
	bead.position = stem + Vector3(0.05, -0.05, 0.0)
	bead.rotation.y = PI / 2.0
	hull.add_child(bead)
	# Ad: iki bordada MAVİ YOLCU
	for sd in [-1.0, 1.0]:
		var t := 0.62
		var lbl := Label3D.new()
		lbl.text = "MAVİ YOLCU"
		lbl.font_size = 64
		lbl.pixel_size = 0.0045
		lbl.modulate = Color(0.1, 0.22, 0.45)
		lbl.outline_size = 0
		lbl.position = Vector3(t * LENGTH * 0.5, _sheer(t) - 0.33, sd * (_half_beam(t) * 0.97 + 0.02))
		lbl.rotation.y = 0.0 if sd > 0.0 else PI
		hull.add_child(lbl)
	# Kamara: kıça yakın, beyaz duvarlı, mavi kapılı küçük oda
	var white := _m(Color(0.95, 0.94, 0.9), 0.7)
	var blue := _m(Color(0.15, 0.38, 0.7), 0.5)
	var cab_x := -1.55
	var cab_y := _sheer(cab_x / (LENGTH * 0.5)) - 0.07
	_box(hull, Vector3(1.5, 1.05, 1.5), Vector3(cab_x, cab_y + 0.52, 0), white)
	_box(hull, Vector3(1.7, 0.08, 1.75), Vector3(cab_x, cab_y + 1.08, 0), ToolModels.mat("wood"))
	_box(hull, Vector3(0.05, 0.8, 0.5), Vector3(cab_x + 0.76, cab_y + 0.42, 0.25), blue)
	for z in [-0.76, 0.76]:
		_box(hull, Vector3(0.45, 0.32, 0.04), Vector3(cab_x, cab_y + 0.66, z), _m(Color(0.1, 0.16, 0.22), 0.15))
		_box(hull, Vector3(0.53, 0.06, 0.05), Vector3(cab_x, cab_y + 0.48, z), blue)
	# Fener: kamara köşesinde asılı
	var glass := _m(Color(1.0, 0.85, 0.55))
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.7, 0.35)
	glass.emission_energy_multiplier = 1.4
	var lamp_pos := Vector3(cab_x + 0.8, cab_y + 0.9, -0.7)
	ToolModels._mi(hull, ToolModels.lathe([Vector2(0.0, -0.12), Vector2(0.07, -0.1), Vector2(0.08, 0.05), Vector2(0.04, 0.1), Vector2(0.0, 0.12)], 12), glass, lamp_pos)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.45)
	light.light_energy = 0.8
	light.omni_range = 6.0
	light.position = lamp_pos
	hull.add_child(light)
	# Direk, seren ve sarılı yelken
	var mast_x := 0.9
	var my := _sheer(mast_x / (LENGTH * 0.5)) - 0.07
	ToolModels._mi(hull, ToolModels.tube([Vector3(mast_x, my - 0.2, 0), Vector3(mast_x, my + 5.0, 0)], 0.075, 8, 0.6), rail)
	ToolModels._mi(hull, ToolModels.tube([Vector3(mast_x + 0.1, my + 1.5, 0), Vector3(-2.6, my + 1.25, 0)], 0.05, 6, 0.8), rail)
	ToolModels._mi(hull, ToolModels.tube([Vector3(mast_x - 0.15, my + 1.62, 0), Vector3(-0.6, my + 1.5, 0.02), Vector3(-2.4, my + 1.36, 0)], 0.13, 8, 0.6), _m(Color(0.93, 0.88, 0.76), 0.95))
	var rope := _m(Color(0.6, 0.5, 0.35), 0.9)
	var mtop := Vector3(mast_x, my + 4.9, 0)
	for p in [stem + Vector3(0.1, 0.2, 0), (grid[0][0] as Vector3) + Vector3(0, 0.2, 0), Vector3(mast_x - 0.3, my + 0.05, -BEAM * 0.92), Vector3(mast_x - 0.3, my + 0.05, BEAM * 0.92)]:
		ToolModels._mi(hull, ToolModels.tube([mtop, p], 0.01, 4), rope)
	# Kıçta bayrak direği ve dalgalanan Türk bayrağı
	var stern: Vector3 = grid[0][0]
	var pole_top := stern + Vector3(0.3, 1.6, 0)
	ToolModels._mi(hull, ToolModels.tube([stern + Vector3(0.3, 0.0, 0), pole_top], 0.025, 6), rail)
	var flag := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.75, 0.5)
	pm.subdivide_width = 10
	pm.orientation = PlaneMesh.FACE_Z
	flag.mesh = pm
	flag_mat = ShaderMaterial.new()
	flag_mat.shader = _flag_shader()
	flag_mat.set_shader_parameter("tex", _flag_texture())
	flag.material_override = flag_mat
	flag.set_meta("nomerge", true)
	flag.position = pole_top + Vector3(-0.38, -0.27, 0)
	hull.add_child(flag)
	# Yükler: sandıklar, küp, portakal sepeti, rulo kilim
	var crate := ToolModels.mat("wood")
	_box(hull, Vector3(0.5, 0.42, 0.5), Vector3(1.75, _sheer(0.5) + 0.15, 0.45), crate, Vector3(0, 0.2, 0))
	_box(hull, Vector3(0.42, 0.36, 0.42), Vector3(1.78, _sheer(0.5) + 0.54, 0.42), crate, Vector3(0, -0.3, 0))
	var clay := _m(Color(0.72, 0.42, 0.26), 0.9)
	var amph := ToolModels._mi(hull, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.06, 0.02), Vector2(0.17, 0.25), Vector2(0.19, 0.42),
		Vector2(0.13, 0.62), Vector2(0.06, 0.7), Vector2(0.07, 0.76), Vector2(0.0, 0.76)], 16), clay, Vector3(-0.35, _sheer(-0.1) - 0.07, 0.62))
	amph.rotation.z = 0.08
	var basket := _m(Color(0.7, 0.55, 0.32), 1.0)
	var bpos := Vector3(2.4, _sheer(0.69) - 0.07, -0.25)
	ToolModels._mi(hull, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.18, 0.0), Vector2(0.24, 0.2), Vector2(0.21, 0.2), Vector2(0.0, 0.03)], 14), basket, bpos)
	var orange := _m(Color(0.95, 0.5, 0.1), 0.6)
	for i in 6:
		var a := TAU * i / 6.0
		var sm := SphereMesh.new()
		sm.radial_segments = 20
		sm.rings = 10
		sm.radius = 0.06
		sm.height = 0.12
		ToolModels._mi(hull, sm, orange, bpos + Vector3(cos(a) * 0.1, 0.19 + (i % 2) * 0.04, sin(a) * 0.1))
	var rug := StandardMaterial3D.new()
	rug.albedo_texture = BuildingScript._kilim_texture()
	rug.roughness = 1.0
	var roll := CylinderMesh.new()
	roll.top_radius = 0.12
	roll.bottom_radius = 0.12
	roll.height = 1.1
	ToolModels._mi(hull, roll, rug, Vector3(0.1, _sheer(0.03) + 0.05, 0.7), Vector3(0, 0, PI / 2.0))
	# Gövdeye bakınca da takas (yalnız ışın; üstüne çıkılmaz)
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	body.set_meta("target", self)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(LENGTH * 0.85, 1.2, BEAM * 1.8)
	cs.shape = bs
	cs.position.y = DECK * 0.5
	body.add_child(cs)
	add_child(body)
	Merge.bake(hull, true)


## Rıza Kaptan: Quaternius karakteri, hasır şapkalı. Kamara önünde, salın tarafında durur.
func _build_captain() -> void:
	person = Node3D.new()
	person.position = Vector3(0.05, _sheer(0.0) - 0.07, -(BEAM - 0.5))
	person.rotation.y = PI
	add_child(person)
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	person.add_child(model)
	var aabb := _bounds(model)
	var h := 1.74
	if aabb.size.y > 0.01:
		model.scale = Vector3.ONE * (h / aabb.size.y)
		model.position.y = -aabb.position.y * model.scale.y
	anim = model.find_child("AnimationPlayer", true, false)
	if anim != null:
		for n in anim.get_animation_list():
			if n.ends_with("Idle"):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_play("Idle")
	_dress(model)
	var cs := CollisionShape3D.new()
	var cap_sh := CapsuleShape3D.new()
	cap_sh.radius = 0.35
	cap_sh.height = 1.8
	cs.shape = cap_sh
	cs.position.y = 0.9
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	body.set_meta("target", self)
	body.add_child(cs)
	person.add_child(body)


## Kaptanın kılığı: hasır şapka (lacivert bantlı), keten gömlek, lacivert tulum, kırlaşmış kaşlar ve kır bıyık.
## Bıyık baş kemiğine bağlıdır, animasyonla birlikte oynar.
func _dress(model: Node3D) -> void:
	var recolor := {"Brown": Color(0.72, 0.68, 0.58), "Beige": Color(0.88, 0.78, 0.52), "Red": Color(0.12, 0.17, 0.32),
		"LightBlue": Color(0.09, 0.13, 0.23), "Brown2": Color(0.2, 0.14, 0.1), "Eyebrows": Color(0.6, 0.59, 0.56)}
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m != null and recolor.has(m.resource_name):
				var nm := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				nm.albedo_color = recolor[m.resource_name]
				# Çizmeler koyu deri kalır
				if mi.name.ends_with("Feet"):
					nm.albedo_color = Color(0.2, 0.14, 0.1)
				mi.set_surface_override_material(i, nm)
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk := sks[0] as Skeleton3D
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	sk.add_child(att)
	var rig := Node3D.new()
	att.add_child(rig)
	rig.scale = Vector3.ONE / maxf(0.0001, att.global_transform.basis.get_scale().x)
	var grey := _m(Color(0.66, 0.65, 0.62), 1.0)
	for sd in [-1.0, 1.0]:
		var cap := CapsuleMesh.new()
		cap.radius = 0.011
		cap.height = 0.05
		ToolModels._mi(rig, cap, grey, MUSTACHE_POS + Vector3(sd * 0.022, -0.006, 0), Vector3(0, 0, sd * 1.25))


func _bounds(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "VisualInstance3D", true, false):
		var vi := c as VisualInstance3D
		var b := (n as Node3D).global_transform.affine_inverse() * vi.global_transform * vi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _play(anim_name: String) -> void:
	if anim == null:
		return
	for n in anim.get_animation_list():
		if n.ends_with("|" + anim_name) or n == anim_name:
			anim.play(n, 0.35)
			return


static func _flag_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
void vertex() {
	float k = 1.0 - UV.x;
	VERTEX.z += sin(VERTEX.x * 7.0 - TIME * 6.0) * 0.05 * k + sin(VERTEX.y * 5.0 + TIME * 3.0) * 0.015 * k;
}
void fragment() {
	ALBEDO = texture(tex, vec2(1.0 - UV.x, UV.y)).rgb;
	ROUGHNESS = 0.9;
}
"""
	return sh


## Al bayrak: ay ve yıldız (oranlar resmî ölçülere yakın).
static func _flag_texture() -> ImageTexture:
	var H := 80
	var W := 120
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var red := Color(0.86, 0.04, 0.09)
	var star: PackedVector2Array = []
	var sc := Vector2(H * 0.855, H * 0.5)
	for k in 10:
		var a := PI + TAU * k / 10.0
		var r := H * 0.125 if k % 2 == 0 else H * 0.125 * 0.382
		star.append(sc + Vector2(cos(a), sin(a)) * r)
	for y in H:
		for x in W:
			var p := Vector2(x + 0.5, y + 0.5)
			var outer := p.distance_to(Vector2(H * 0.5, H * 0.5)) < H * 0.25
			var inner := p.distance_to(Vector2(H * 0.5625, H * 0.5)) < H * 0.2
			var white := (outer and not inner) or Geometry2D.is_point_in_polygon(p, star)
			img.set_pixel(x, y, Color.WHITE if white else red)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
