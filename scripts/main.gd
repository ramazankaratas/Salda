extends Node3D
## SaLda: okyanusta sal üzerinde hayatta kalma.
## Oyun akışını (menü, yeni oyun, kayıt), okyanusu, enkaz ve ada akışını, ortam seslerini
## ve hayatta kalma kurallarını yönetir.

const Waves = preload("res://scripts/waves.gd")
const Items = preload("res://scripts/items.gd")
const Settings = preload("res://scripts/settings.gd")
const AudioScript = preload("res://scripts/audio.gd")
const WorldScript = preload("res://scripts/world.gd")
const RaftScript = preload("res://scripts/raft.gd")
const PlayerScript = preload("res://scripts/player.gd")
const HookScript = preload("res://scripts/hook.gd")
const FishingScript = preload("res://scripts/fishing.gd")
const SharkScript = preload("res://scripts/shark.gd")
const DebrisScript = preload("res://scripts/debris.gd")
const IslandScript = preload("res://scripts/island.gd")
const HudScript = preload("res://scripts/hud.gd")
const MenuScript = preload("res://scripts/menu.gd")
const ShowcaseScript = preload("res://scripts/showcase.gd")
const QuestsScript = preload("res://scripts/quests.gd")
const CatScript = preload("res://scripts/cat.gd")
const TraderScript = preload("res://scripts/trader.gd")
const DeepWreckScript = preload("res://scripts/deep_wreck.gd")
const OliveScriptRef = preload("res://scripts/olive.gd")
const IconsScript = preload("res://scripts/icons.gd")

## Kayıt dosyası (otomatik test kendi dosyasını kullanır, oyuncunun kaydına dokunmaz).
var save_path := "user://kayit_1.json"
## Kayıt yuvaları (user://kayit_1..3.json) ve oyunun zorluğu
const SLOTS := 3
var slot := 1
var difficulty := 1
const DIFF_NAMES := ["Kolay", "Normal", "Zor"]
## Zorluk çarpanları: açlık/susuzluk hızı, köpekbalığı saldırı aralığı, ısırık gücü (oyuncu), karo hasarı,
## bayılınca çantadaki malzemelerden kaybedilen oran
const DIFF := [
	{"hunger": 0.6, "shark_cd": 1.6, "shark_dmg": 0.6, "tile": 0.75, "loss": 0.0},
	{"hunger": 1.0, "shark_cd": 1.0, "shark_dmg": 1.0, "tile": 1.0, "loss": 0.0},
	{"hunger": 1.4, "shark_cd": 0.7, "shark_dmg": 1.4, "tile": 1.6, "loss": 0.5},
]
const DIFF_DESC := [
	"Açlık ve susuzluk yavaş, köpekbalığı seyrek ve zayıf saldırır. Rahat keşif için.",
	"Dengeli hayatta kalma.",
	"Açlık hızlı, köpekbalığı sık saldırır, karoyu iki ısırıkta koparır; bayılınca çantadaki malzemelerin yarısı gider.",
]


func diff() -> Dictionary:
	return DIFF[clampi(difficulty, 0, 2)]


static func slot_path(i: int) -> String:
	return "user://kayit_%d.json" % i


## Yuvanın özeti (boşsa boş sözlük): gün, saat, zorluk, etkin görev, kayıt zamanı.
func slot_info(i: int) -> Dictionary:
	var p := slot_path(i)
	if not FileAccess.file_exists(p):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not (data is Dictionary):
		return {}
	var w: Dictionary = data.get("world", {})
	var qid: String = data.get("quests", {}).get("current_id", "")
	var qtitle := ""
	for q in quests.QUESTS:
		if q["id"] == qid:
			qtitle = q["title"]
	return {"day": int(w.get("day", 1)), "diff": int(data.get("difficulty", 1)), "quest": qtitle,
		"time": FileAccess.get_modified_time(p), "tiles": (data.get("raft", {}).get("tiles", []) as Array).size()}


## En son kaydedilen yuva (yoksa 0).
func latest_slot() -> int:
	var best := 0
	var bt := 0
	for i in range(1, SLOTS + 1):
		var p := slot_path(i)
		if FileAccess.file_exists(p) and FileAccess.get_modified_time(p) >= bt:
			bt = FileAccess.get_modified_time(p)
			best = i
	return best


## Seçilen yuvada seçilen zorlukla yeni oyun.
func start_new(s: int, d: int) -> void:
	slot = s
	difficulty = d
	save_path = slot_path(s)
	new_game()
	save_game()


func load_slot(s: int) -> void:
	slot = s
	save_path = slot_path(s)
	continue_game()


func delete_slot(s: int) -> void:
	if FileAccess.file_exists(slot_path(s)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(s)))
## Enkazın kendi akıntısı (sal rüzgârla daha hızlı ilerler, enkaz yanından geçer).
const DEBRIS_CURRENT := Vector3(-0.25, 0.0, 0.05)
const DEBRIS_COUNT := 34
const ISLAND_EVERY := 520.0
const HUNGER_RATE := 0.16
const THIRST_RATE := 0.24
const AUTOSAVE := 180.0

var audio
var world
var raft
var player
var hook
var fishing
var shark
var hud
## Görevler ve başarımlar (olaylar `quests.event()` ile bildirilir).
var quests
var last_day := 1
var icons
var menu
var menu_cam: Camera3D
## Ana menü arkasındaki tamamlanmış sal vitrini.
var showcase = null

var debris: Array = []
var islands: Array = []
## Kalıcı yer işaretleri (fener adaları): {"kind", "x", "z", "seed", "stage", "name"}.
## Uzaklaşınca ada silinir ama kayıt kalır; yaklaşınca aynı ada aynı hâliyle geri gelir.
var landmarks: Array = []
## Salda yaşayan kedi (yoksa null)
var cat = null
## Gezgin tüccar teknesi (yoksa null) ve bir sonraki gelişine kalan süre
var trader = null
var trader_t := 900.0
## Telsizle bulunan hedef (Vector3) ve adı; yoksa null.
var nav_target = null
var nav_name := ""
const LIGHTHOUSE_NAMES := ["Baba Burnu Feneri", "Sığacık Feneri", "Çandarlı Feneri", "Karaburun Feneri", "Dil Burnu Feneri",
	"Teke Burnu Feneri", "Mordoğan Feneri", "Kuşadası Feneri", "Bozcaada Feneri", "Gökçeada Feneri", "Ayvalık Feneri", "Foça Feneri"]
const ISLAND_ODDS := [["palmiye", 36], ["kayalik", 23], ["zeytinlik", 18], ["fener", 13], ["batik", 10]]
## Batık sandıklarından okunan seyir defteri sayfası sayısı
var wreck_pages := 0
## Denizde not taşıyan şişe çıkma süresi
var bottle_t := 90.0
## Hıdırellez Adası'nın yeri (görev açılınca belirir) ve hikâyenin bittiği
var legend := {}
var legend_island = null
var story_done := false
var ocean_near: MeshInstance3D
var ocean_far: MeshInstance3D
var ocean_mats: Array = []

var paused := true
var dead := false
var travel := 0.0
var last_raft_pos := Vector3.ZERO
var autosave_timer := AUTOSAVE
var menu_angle := 0.0
var spawn_cell := Vector2i(0, 0)
## Geliştirici komutu (ekran görüntüsü testleri için): "new_game", "inventory", "map", "items", "shark"
var debug_action := ""


func _ready() -> void:
	randomize()
	Settings.load_settings()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--debug=") or arg.begins_with("--shot=") or arg.begins_with("--perf="):
			dev_run = true
	# Eski sürümün tek kayıt dosyası (kayit.json) 1. yuvaya taşınır; 1. yuva doluysa o boş bir yuvaya kaydırılır
	if FileAccess.file_exists("user://kayit.json"):
		var g := func(p: String) -> String: return ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(slot_path(1)):
			for i in range(2, SLOTS + 1):
				if not FileAccess.file_exists(slot_path(i)):
					DirAccess.rename_absolute(g.call(slot_path(1)), g.call(slot_path(i)))
					break
		if FileAccess.file_exists(slot_path(1)):
			DirAccess.rename_absolute(g.call(slot_path(1)), g.call("user://kayit_eski_yuva1.json"))
		DirAccess.rename_absolute(g.call("user://kayit.json"), g.call(slot_path(1)))
	var ls := latest_slot()
	if ls > 0:
		slot = ls
		save_path = slot_path(ls)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):
			Settings.quality = clampi(int(arg.substr(10)), 0, 3)
	_setup_input()
	audio = AudioScript.new()
	add_child(audio)
	world = WorldScript.new()
	world.main = self
	add_child(world)
	_setup_ocean()

	raft = RaftScript.new()
	raft.name = "Raft"
	raft.main = self
	add_child(raft)
	hud = HudScript.new()
	hud.main = self
	player = PlayerScript.new()
	player.name = "Player"
	player.main = self
	hook = HookScript.new()
	hook.main = self
	fishing = FishingScript.new()
	fishing.main = self
	shark = SharkScript.new()
	shark.name = "Shark"
	shark.main = self
	add_child(player)
	add_child(hook)
	add_child(fishing)
	add_child(shark)
	quests = QuestsScript.new()
	quests.name = "Quests"
	quests.main = self
	add_child(quests)
	quests.changed.connect(_on_quests_changed)
	add_child(hud)
	player.inv.changed.connect(hud.on_inventory_changed)

	menu_cam = Camera3D.new()
	menu_cam.fov = 60.0
	menu_cam.far = 4000.0
	add_child(menu_cam)
	menu = MenuScript.new()
	menu.main = self
	add_child(menu)

	raft.reset_raft()
	player.global_position = raft.to_global(Vector3(0.75, 0.4, 0.75))
	player.give_starting_items()
	_reset_world_stream()
	Settings.apply(self)
	_enter_menu()
	# Eşya ikonları: menü arkasında bir kez üretilir.
	icons = IconsScript.new()
	icons.main = self
	add_child(icons)
	icons.generate()
	if "--fullsave" in OS.get_cmdline_user_args():
		_make_full_save()
	if "--loadtest" in OS.get_cmdline_user_args():
		_load_test()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bigraft="):
			_big_raft_slot(int(arg.substr(10)))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_screenshot(arg.substr(7))
	if "--autotest" in OS.get_cmdline_user_args():
		_autotest()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf="):
			_perf(arg.substr(7))


# --- Kurulum -----------------------------------------------------------------

func _setup_input() -> void:
	_add("move_forward", [KEY_W])
	_add("move_back", [KEY_S])
	_add("move_left", [KEY_A])
	_add("move_right", [KEY_D])
	_add("jump", [KEY_SPACE])
	_add("sprint", [KEY_SHIFT])
	_add("dive", [KEY_CTRL, KEY_C])
	_add("interact", [KEY_E])
	_add("remove", [KEY_R])
	_add("carry", [KEY_T])
	_add("quick_store", [KEY_Q])
	_add("inventory", [KEY_TAB, KEY_I])
	_add("map", [KEY_M])
	_add("journal", [KEY_J])
	_add("pause", [KEY_ESCAPE])
	var keys := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
	for i in 10:
		_add("slot_%d" % i, [keys[i]])
	_add_mouse("use", MOUSE_BUTTON_LEFT)
	_add_mouse("cancel", MOUSE_BUTTON_RIGHT)


func _add(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _add_mouse(action: String, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _normal_noise(freq: float, seed_v: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = 3
	n.seed = seed_v
	var t := NoiseTexture2D.new()
	t.width = 1024
	t.height = 1024
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = 6.0
	t.generate_mipmaps = true
	t.noise = n
	return t


func _ocean_material(dip: float, shared: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ocean.gdshader")
	var w: Array = Waves.shader_params()
	for i in 4:
		m.set_shader_parameter("w%d" % i, w[i])
	m.set_shader_parameter("dip", dip)
	for k in shared:
		m.set_shader_parameter(k, shared[k])
	ocean_mats.append(m)
	return m


func _setup_ocean() -> void:
	var foam := FastNoiseLite.new()
	foam.frequency = 0.03
	var ft := NoiseTexture2D.new()
	ft.width = 512
	ft.height = 512
	ft.seamless = true
	ft.noise = foam
	var shared := {"detail_a": _normal_noise(0.012, 1), "detail_b": _normal_noise(0.02, 7), "foam_noise": ft}
	ocean_near = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(170, 170)
	# Yakın deniz ağı: kaliteye göre 0.5 - 0.85 m aralık (dalga ayrıntısı normal haritalardan gelir)
	var sub: int = [199, 239, 289, 339][clampi(Settings.quality, 0, 3)]
	pm.subdivide_width = sub
	pm.subdivide_depth = sub
	ocean_near.mesh = pm
	ocean_near.material_override = _ocean_material(0.0, shared)
	ocean_near.extra_cull_margin = 4.0
	ocean_near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ocean_near)
	ocean_far = MeshInstance3D.new()
	ocean_far.mesh = _radial_ocean(70.0, 4000.0, 72, 192)
	ocean_far.material_override = _ocean_material(0.9, shared)
	ocean_far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ocean_far)


## Uzak deniz: halka biçimli ağ. Halkalar dışa doğru seyrekleşir (yakında ~5 m, ufukta ~150 m);
## eski düz ağın 1.3 milyon üçgeni yerine ~28 bin üçgen. 80 m içi gölgelendiricide atılır (yakın ağ orayı çizer).
func _radial_ocean(r0: float, r1: float, rings: int, segs: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in rings + 1:
		var r := r0 * pow(r1 / r0, float(i) / rings)
		for j in segs:
			var a := TAU * j / segs
			verts.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
			normals.append(Vector3.UP)
	for i in rings:
		for j in segs:
			var j2 := (j + 1) % segs
			var a0 := i * segs + j
			var a1 := i * segs + j2
			var b0 := (i + 1) * segs + j
			var b1 := (i + 1) * segs + j2
			idx.append_array([a0, a1, b0, a1, b1, b0])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.custom_aabb = AABB(Vector3(-r1, -20.0, -r1), Vector3(r1 * 2.0, 40.0, r1 * 2.0))
	return m


# --- Oyun akışı --------------------------------------------------------------

func _enter_menu() -> void:
	paused = true
	if showcase == null:
		showcase = ShowcaseScript.new()
		showcase.main = self
		add_child(showcase)
		# Açık denizde, oyuncunun salından uzakta.
		showcase.build(Vector3(raft.base_pos.x, 0.0, raft.base_pos.z - 600.0))
	menu_cam.current = true
	hud.set_visible_hud(false)
	menu.show_mode("main")


func _start_play() -> void:
	paused = false
	if showcase != null:
		showcase.queue_free()
		showcase = null
	dead = false
	player.camera.current = true
	player.controls = true
	hud.set_visible_hud(true)
	menu.show_mode("none")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.fade.color.a = 1.0
	hud.fade_to(0.0, 1.5)


## Adaya ayak basınca (suda değilken kıyının içinde) görev olayı; her ada bir kez sayılır.
func _check_island_visit() -> void:
	if player.in_water:
		return
	for isl in islands:
		if isl.get_meta("visited", false):
			continue
		var d := Vector2(player.global_position.x - isl.global_position.x, player.global_position.z - isl.global_position.z).length()
		if d < isl.shore_radius - 1.0:
			isl.set_meta("visited", true)
			quests.event("visit_island", isl.kind)


func new_game() -> void:
	quests.reset()
	if player != null:
		player.carry = []
	landmarks = []
	nav_target = null
	_clear_trader()
	trader_t = 900.0
	wreck_pages = 0
	hud.lore.from_data([])
	legend = {}
	legend_island = null
	story_done = false
	bottle_t = 90.0
	_clear_sites()
	wreck_sites = []
	site_travel = 200.0
	if cat != null and is_instance_valid(cat):
		cat.queue_free()
	cat = null
	last_day = 1
	raft.reset_raft()
	_clear_world_objects()
	world.hour = 7.5
	world.day = 1
	world.raining = false
	world.rain = 0.0
	world.weather_timer = 420.0
	player.give_starting_items()
	player.health = 100.0
	player.hunger = 100.0
	player.thirst = 100.0
	player.oxygen = 100.0
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.global_position = raft.to_global(Vector3(0.75, 0.4, 0.75))
	shark.hp = shark.MAX_HP
	shark.visible = true
	shark.global_position = Vector3(30, -1, 0)
	shark._back_to_circle()
	spawn_cell = Vector2i(0, 0)
	_reset_world_stream()
	_start_play()
	hud.toast("Okyanusun ortasında küçük bir saldasın. Kancayla (sol tık basılı tut) enkaz topla.", 8.0)


func continue_game() -> void:
	if load_game():
		_start_play()
		hud.toast("Kaldığın yerden devam ediyorsun.")
	else:
		new_game()


func resume() -> void:
	paused = false
	menu.show_mode("none")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func pause_game() -> void:
	paused = true
	if hud.menu_open:
		hud.close_menus()
	menu.show_mode("pause")


func to_main_menu() -> void:
	_enter_menu()


func _clear_world_objects() -> void:
	for d in debris:
		d.queue_free()
	debris.clear()
	for i in islands:
		i.queue_free()
	islands.clear()
	hook._retract(false)
	fishing.reset()


func _reset_world_stream() -> void:
	_clear_world_objects()
	last_raft_pos = raft.center_global()
	travel = ISLAND_EVERY - 160.0
	for i in DEBRIS_COUNT:
		_spawn_debris(true)


# --- Envanter yardımcıları ---------------------------------------------------

func craft(r: Dictionary) -> void:
	if Items.info(r["out"]).get("type", "") == "piece":
		player.choose_piece(int(Items.info(r["out"])["piece"]))
		return
	if not player.inv.spend(r["cost"]):
		return
	audio.play("craft", -4.0)
	var id: String = r["out"]
	quests.event("craft", id, r["n"])
	if Items.info(id).get("type", "") == "material":
		player.give(id, r["n"])
		return
	# Üretilen alet ve yapılar doğrudan ele gelir; yerleştirilecekse menü kapanır.
	var slot: int = player.inv.add_to_hotbar(id, r["n"], player.selected)
	if slot < 0:
		player.give(id, r["n"])
		return
	player.selected = slot
	hud.notify("+%d %s (elinde)" % [r["n"], Items.name_of(id)], Items.info(id)["color"], id)
	if Items.info(id).get("type", "") in ["place", "roof"] and hud.menu_open:
		hud.close_menus()


# --- Enkaz ve adalar ---------------------------------------------------------

## Noktayı adaların kıyısından `margin` metre dışarıda kalacak şekilde iter (kıyı boyunca kayar).
## Enkaz ve köpekbalığı adanın içine girmesin diye kullanılır.
func push_out_of_islands(p: Vector3, margin: float) -> Vector3:
	for isl in islands:
		var d: Vector3 = p - isl.global_position
		d.y = 0.0
		var lim: float = isl.shore_radius + margin
		if d.length() < lim:
			var n := d.normalized() if d.length() > 0.01 else Vector3(1, 0, 0)
			p.x = isl.global_position.x + n.x * lim
			p.z = isl.global_position.z + n.z * lim
	return p


func _stream_dir() -> Vector3:
	# Salın enkaza göre bağıl hareket yönü: yeni enkaz bu yönde, önde doğar.
	var rel: Vector3 = raft.vel - DEBRIS_CURRENT
	rel.y = 0.0
	return rel.normalized() if rel.length() > 0.1 else Vector3(1, 0, 0)


func _spawn_debris(anywhere: bool) -> void:
	var d = DebrisScript.new()
	d.main = self
	d.kind = DebrisScript.random_kind()
	add_child(d)
	var fwd := _stream_dir()
	var side := Vector3(-fwd.z, 0, fwd.x)
	var ahead := randf_range(-30.0, 60.0) if anywhere else randf_range(50.0, 70.0)
	var ctr: Vector3 = raft.center_global()
	d.position = ctr + fwd * ahead + side * randfn(0.0, 11.0)
	debris.append(d)


func remove_debris(d) -> void:
	debris.erase(d)
	d.queue_free()


func _spawn_island(kind := "") -> void:
	var fwd := _stream_dir()
	var side := Vector3(-fwd.z, 0, fwd.x) * (1.0 if randf() < 0.5 else -1.0)
	if kind == "":
		var total := 0
		for o in ISLAND_ODDS:
			total += int(o[1])
		var r := randi() % total
		for o in ISLAND_ODDS:
			r -= int(o[1])
			if r < 0:
				kind = o[0]
				break
	var pos: Vector3 = raft.center_global() + fwd * 150.0 + side * randf_range(18.0, 40.0)
	if kind == "fener":
		# Fener adası kalıcı yer işareti olur
		var lm := _new_landmark(pos)
		_spawn_landmark(lm)
	else:
		_make_island(kind, randi(), pos, {})
	hud.toast("Ufukta bir %s görünüyor!" % IslandScript.NAMES.get(kind, "ada").to_lower(), 6.0)


func _make_island(kind: String, seed_v: int, pos: Vector3, lm: Dictionary):
	var isl = IslandScript.new()
	isl.main = self
	isl.kind = kind
	isl.seed_value = seed_v
	isl.landmark = lm
	add_child(isl)
	isl.global_position = Vector3(pos.x, 0.0, pos.z)
	islands.append(isl)
	return isl


func _new_landmark(pos: Vector3) -> Dictionary:
	var used: Array = []
	for l in landmarks:
		used.append(l["name"])
	var name := "Fener"
	for n in LIGHTHOUSE_NAMES:
		if not n in used:
			name = n
			break
	var lm := {"kind": "fener", "x": pos.x, "z": pos.z, "seed": randi(), "stage": 0, "name": name}
	landmarks.append(lm)
	return lm


func _spawn_landmark(lm: Dictionary) -> void:
	_make_island("fener", int(lm["seed"]), Vector3(float(lm["x"]), 0, float(lm["z"])), lm)


func _landmark_spawned(lm: Dictionary) -> bool:
	for isl in islands:
		if is_instance_valid(isl) and isl.landmark == lm:
			return true
	return false


## Adada bekleyen sokak kedisi yaratır.
func make_cat(adopted: bool) -> Node:
	var c = CatScript.new()
	c.main = self
	c.coat = CatScript.COATS.keys().pick_random()
	c.cat_name = CatScript.NAMES.pick_random()
	c.adopted = adopted
	return c


## Kedi sala gelir: adanın kedisi salın çocuğu olur, oyuncunun yanına yerleşir.
func adopt_cat(c) -> void:
	c.adopted = true
	c.get_parent().remove_child(c)
	raft.add_child(c)
	var spot: Vector3 = raft.safe_spot(raft.cell_from_local(raft.to_local(player.global_position)))
	c.position = Vector3(spot.x, raft.top_y(), spot.z)
	c.state = c.S.SIT
	c.state_t = 5.0
	cat = c
	audio.play("meow", -2.0)
	hud.toast("Islak, aç bir sokak kedisi... Adı %s olsun. Artık salında yaşıyor." % c.cat_name, 6.0)
	quests.event("pet_cat")


## Açık denizdeki batık sahaları (kalıcı): {x, z, kind, seed, found, looted, spots}
var wreck_sites: Array = []
var site_nodes := {}
var site_travel := 0.0
var sonar_t := 3.0
const SITE_KINDS := ["antik", "balikci", "yuk"]
const SITE_SPOTS := {"antik": 7, "balikci": 5, "yuk": 5}


## Salın çevresinde yeni bir batık sahası; adalardan, fenerlerden ve öbür batıklardan uzak.
func _new_site(near: Vector3, kind := "") -> Dictionary:
	for attempt in 12:
		var a := randf() * TAU
		var d := randf_range(170.0, 300.0)
		var p := near + Vector3(cos(a), 0, sin(a)) * d
		var ok := true
		for isl in islands:
			if Vector2(p.x - isl.global_position.x, p.z - isl.global_position.z).length() < 140.0:
				ok = false
		for lm in landmarks:
			if Vector2(p.x - float(lm["x"]), p.z - float(lm["z"])).length() < 140.0:
				ok = false
		for st in wreck_sites:
			if Vector2(p.x - float(st["x"]), p.z - float(st["z"])).length() < 200.0:
				ok = false
		if ok:
			var k: String = kind if kind != "" else SITE_KINDS.pick_random()
			var site := {"x": p.x, "z": p.z, "kind": k, "seed": randi(), "found": false, "looted": [], "spots": SITE_SPOTS[k]}
			wreck_sites.append(site)
			return site
	return {}


func _stream_sites(moved: float) -> void:
	site_travel += moved
	if site_travel > 320.0:
		site_travel = 0.0
		if randf() < 0.55:
			_new_site(raft.center_global())
	var ctr: Vector3 = raft.center_global()
	for i in wreck_sites.size():
		var st: Dictionary = wreck_sites[i]
		var d := Vector2(ctr.x - float(st["x"]), ctr.z - float(st["z"])).length()
		var node = site_nodes.get(i)
		if d < 230.0 and (node == null or not is_instance_valid(node)):
			var w = DeepWreckScript.new()
			w.main = self
			w.site = st
			add_child(w)
			w.global_position = Vector3(float(st["x"]), 0, float(st["z"]))
			site_nodes[i] = w
		elif d > 330.0 and node != null and is_instance_valid(node):
			node.queue_free()
			site_nodes.erase(i)


## Sonar salda kuruluysa ara ara yankı yollar; menzildeki batıkları bulur.
func _sonar_step(delta: float) -> void:
	if not raft.has_kind("sonar"):
		return
	sonar_t -= delta
	if sonar_t > 0.0:
		return
	sonar_t = 6.0
	audio.play("sonar", -6.0)
	var ctr: Vector3 = raft.center_global()
	for st in wreck_sites:
		if st.get("found", false):
			continue
		var dv := Vector3(float(st["x"]) - ctr.x, 0, float(st["z"]) - ctr.z)
		if dv.length() > 260.0:
			continue
		st["found"] = true
		quests.event("sonar_find", st["kind"])
		var deg := fposmod(rad_to_deg(atan2(dv.x, -dv.z)), 360.0)
		var names := ["kuzey", "kuzeydoğu", "doğu", "güneydoğu", "güney", "güneybatı", "batı", "kuzeybatı"]
		hud.toast("Sonar: %d m %s yönünde güçlü yankı — %s! Haritada işaretlendi." % [int(dv.length()), names[int(round(deg / 45.0)) % 8], DeepWreckScript.NAMES[st["kind"]].to_lower()], 6.0)
		hud.notify("Batık bulundu: %s" % DeepWreckScript.NAMES[st["kind"]], Color(0.75, 0.6, 1.0))
		if nav_target == null:
			nav_target = Vector3(float(st["x"]), 0, float(st["z"]))
			nav_name = DeepWreckScript.NAMES[st["kind"]]


## Sonardan: ganimeti bitmemiş en yakın bulunmuş batığa hedef koyar.
func sonar_target() -> void:
	var ctr: Vector3 = raft.center_global()
	var best = null
	var bd := INF
	for st in wreck_sites:
		if not st.get("found", false) or (st.get("looted", []) as Array).size() >= int(st.get("spots", 5)):
			continue
		var d := Vector2(ctr.x - float(st["x"]), ctr.z - float(st["z"])).length()
		if d < bd:
			bd = d
			best = st
	if best == null:
		sonar_t = 0.0
		hud.toast("Sonar: menzilde bilinen batık yok. Yankı yollanıyor...", 3.0)
		return
	nav_target = Vector3(float(best["x"]), 0, float(best["z"]))
	nav_name = DeepWreckScript.NAMES[best["kind"]]
	hud.toast("Sonar hedefi: %s, %d m. Üstüne gelince çapa at ve dal (12-20 m)." % [nav_name, int(bd)], 5.0)


## Rıza Kaptan'ın teknesi ufukta belirir ve salın bir kenarına yanaşmaya gelir.
func spawn_trader() -> Node:
	if trader != null and is_instance_valid(trader):
		return trader
	var t = TraderScript.new()
	t.main = self
	add_child(t)
	t.setup()
	trader = t
	audio.play("bell", -4.0)
	hud.toast("Ufukta beyaz bir yelken... Çan sesi! Rıza Kaptan'ın Mavi Yolcu'su salına yanaşıyor.", 6.0)
	return t


func trader_left(t) -> void:
	if trader == t:
		trader = null
	trader_t = randf_range(1200.0, 1600.0)
	t.queue_free()


func _trader_step(delta: float) -> void:
	if trader != null and is_instance_valid(trader):
		return
	trader = null
	# "Mavi Yolcu" görevi açıksa tekne çok bekletmez
	if quests.active().get("id", "") == "mavi_yolcu":
		trader_t = minf(trader_t, 90.0)
	trader_t -= delta
	if trader_t <= 0.0 and not dead:
		trader_t = 9999.0
		spawn_trader()


func _clear_sites() -> void:
	for k in site_nodes:
		if is_instance_valid(site_nodes[k]):
			site_nodes[k].queue_free()
	site_nodes = {}


func _clear_trader() -> void:
	if trader != null and is_instance_valid(trader):
		trader.queue_free()
	trader = null


## Şişe açılınca sıradaki not okunur (hepsi okunduysa boş şişe).
func open_bottle() -> void:
	var id: String = hud.lore.next_bottle()
	if id == "":
		hud.toast("Şişe boş; içine deniz suyu dolmuş.", 3.0)
		return
	hud.lore.read_note(id)


## Hıdırellez görevi açılınca efsanevi ada salın uzağında, fenerlerin çemberinin ortasında belirir.
func _on_quests_changed() -> void:
	if not legend.is_empty() or quests.active().get("id", "") != "hidirellez":
		return
	var ctr: Vector3 = raft.center_global()
	var sx := 0.0
	var sz := 0.0
	var n := 0
	for lm in landmarks:
		sx += float(lm["x"])
		sz += float(lm["z"])
		n += 1
	var pos := Vector3(sx / n, 0, sz / n) if n >= 2 else ctr + Vector3(cos(randf() * TAU), 0, sin(randf() * TAU)) * 600.0
	if Vector2(pos.x - ctr.x, pos.z - ctr.z).length() < 250.0:
		var dir := Vector3(pos.x - ctr.x, 0, pos.z - ctr.z)
		dir = dir.normalized() if dir.length() > 1.0 else Vector3.FORWARD
		pos = ctr + dir * 400.0
	legend = {"x": pos.x, "z": pos.z, "seed": randi()}
	nav_target = Vector3(pos.x, 0, pos.z)
	nav_name = "Hıdırellez Adası"
	audio.play("bell", -2.0)
	hud.toast("Fenerlerin halkası tamamlandı! Çemberin ortasında bir ada belirdi: Hıdırellez Adası. Haritada işaretli.", 8.0)


func _stream_legend() -> void:
	if legend.is_empty():
		return
	if legend_island != null and is_instance_valid(legend_island):
		return
	legend_island = null
	var ctr: Vector3 = raft.center_global()
	if Vector2(ctr.x - float(legend["x"]), ctr.z - float(legend["z"])).length() < 330.0:
		legend_island = _make_island("efsanevi", int(legend["seed"]), Vector3(float(legend["x"]), 0, float(legend["z"])), {})


## Kurdele dilek ağacına bağlandı: son anlatısı, ardından "Son" ekranı; oyun serbest sürer.
func tie_ribbon(_tree) -> void:
	player.inv.remove("kurdele", 1)
	quests.event("tie_ribbon")
	story_done = true
	audio.play("bell", 0.0)
	await hud.fade_to(0.55, 1.2).finished
	hud.lore.show_note("Hıdırellez Gecesi", hud.lore.EPILOGUE, "")
	hud.lore.after_close = _show_end
	hud.fade_to(0.0, 1.5)


func _show_end() -> void:
	var lit := 0
	for lm in landmarks:
		if int(lm["stage"]) >= 4:
			lit += 1
	var stats := "Gün %d  ·  %d karoluk sal  ·  %d fener yandı  ·  %d / %d not  ·  %d başarım  ·  %s" % [world.day, raft.tiles.size(), lit,
		hud.lore.read.size(), hud.lore.NOTES.size() - 1, quests.ach_done.size(), DIFF_NAMES[difficulty]]
	hud.lore.show_end(stats)
	save_game()


func end_finished() -> void:
	hud.menu_open = false
	hud.menu_closed_frame = Engine.get_process_frames()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.toast("Serbest oyun: Ege seni bekliyor. Rıza Kaptan da ara ara uğrayacak.", 6.0)


## Yakınında yanan fener var mı? (köpekbalığı orada salı ısırmaz)
func near_lit_lighthouse(p: Vector3, r: float) -> bool:
	for lm in landmarks:
		if int(lm["stage"]) >= 4 and Vector2(p.x - float(lm["x"]), p.z - float(lm["z"])).length() < r:
			return true
	return false


## Sönmüş fenerlerin en yakını (yoksa yeni bir fener adası ufukta belirir).
func nearest_dark_lighthouse(p: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var bd := INF
	for lm in landmarks:
		if int(lm["stage"]) >= 4:
			continue
		var d := Vector2(p.x - float(lm["x"]), p.z - float(lm["z"])).length()
		if d < bd:
			bd = d
			best = lm
	if best.is_empty() or bd > 1500.0:
		var ang := randf() * TAU
		var dist := randf_range(450.0, 800.0)
		best = _new_landmark(p + Vector3(cos(ang), 0, sin(ang)) * dist)
	return best


func _stream_world(_delta: float) -> void:
	var ctr: Vector3 = raft.center_global()
	for d in debris.duplicate():
		if not d.hooked and d.position.distance_to(ctr) > 75.0:
			remove_debris(d)
	while debris.size() < DEBRIS_COUNT:
		_spawn_debris(false)
	var moved: float = ctr.distance_to(last_raft_pos)
	travel += moved
	# Yol olayı biriktirilip seyrek gönderilir (her kare göndermek görev panelini sürekli yeniden kurduruyordu)
	if moved < 50.0:
		travel_pending += moved
		_stream_sites(moved)
	if travel_pending >= 10.0:
		quests.event("travel", "", travel_pending)
		travel_pending = 0.0
	last_raft_pos = ctr
	# Yer işaretleri: yaklaşınca adası geri gelir
	for lm in landmarks:
		var d := Vector2(ctr.x - float(lm["x"]), ctr.z - float(lm["z"])).length()
		if d < 330.0 and not _landmark_spawned(lm):
			_spawn_landmark(lm)
	if nav_target != null and Vector2(ctr.x - nav_target.x, ctr.z - nav_target.z).length() < 25.0:
		hud.toast("%s yanındasın." % nav_name, 4.0)
		nav_target = null
	if travel > ISLAND_EVERY:
		travel = 0.0
		_spawn_island()
	for i in islands.duplicate():
		if i.global_position.distance_to(ctr) > 380.0:
			islands.erase(i)
			i.queue_free()


# --- Hayatta kalma -----------------------------------------------------------

func sleep(bed) -> void:
	if world.rain > 0.3 and not raft.has_structure(bed.cell, "roof"):
		hud.toast("Yağmur yağıyor! Uyumak için yatağın üstüne çatı yap (Tab → Yapı → Çatı).")
		return
	spawn_cell = bed.cell
	if not world.is_night():
		save_game()
		hud.toast("Doğma noktası ayarlandı ve oyun kaydedildi. Uyumak için gece olmalı.")
		return
	player.controls = false
	await hud.fade_to(1.0, 1.0).finished
	world.sleep_to_morning()
	quests.event("sleep")
	player.hunger = maxf(0.0, player.hunger - 15.0)
	player.thirst = maxf(0.0, player.thirst - 15.0)
	save_game()
	await get_tree().create_timer(0.5).timeout
	hud.fade_to(0.0, 1.0)
	hud.toast("Günaydın! Oyun kaydedildi.")
	player.controls = true


func on_player_died() -> void:
	if dead:
		return
	dead = true
	player.controls = false
	hud.show_center("Bayıldın...")
	await hud.fade_to(1.0, 1.0).finished
	var cell: Vector2i = spawn_cell if raft.has_tile(spawn_cell) else raft.CORE
	player.global_position = raft.to_global(raft.cell_pos(cell) + Vector3(0, raft.top_y() + 0.5, 0))
	player.velocity = Vector3.ZERO
	player.health = 60.0
	player.oxygen = 100.0
	player.hunger = maxf(player.hunger, 40.0)
	player.thirst = maxf(player.thirst, 40.0)
	var lost := 0
	var loss: float = diff()["loss"]
	if loss > 0.0:
		# Zor: çantadaki malzemelerin yarısı denize karışır (alet çubuğu ve aletler kalır)
		for i in range(player.inv.hotbar_size, player.inv.slots.size()):
			var sl = player.inv.slots[i]
			if sl != null and Items.info(sl["id"])["type"] == "material":
				var n: int = int(floor(sl["n"] * loss))
				if n > 0:
					player.inv.take_slot(i, n)
					lost += n
	await get_tree().create_timer(0.8).timeout
	hud.show_center("")
	hud.fade_to(0.0, 1.0)
	hud.toast("Salda uyandın. " + ("Çantadaki malzemelerden %d tanesi kayboldu." % lost if lost > 0 else "Envanterin duruyor."))
	player.controls = true
	dead = false


# --- Kayıt -------------------------------------------------------------------

func save_game() -> void:
	# Geliştirici çalıştırmaları (ekran görüntüsü, ölçüm) oyuncunun kayıt yuvalarına asla yazmaz
	if dev_run and save_path != "user://kayit_test.json":
		return
	var data := {
		"version": 1,
		"difficulty": difficulty,
		"raft": raft.to_data(),
		"player": player.to_data(),
		"world": {"hour": world.hour, "day": world.day, "raining": world.raining, "rain": world.rain, "weather": world.weather_timer,
			"wind_from": world.wind_from, "wind": world.wind_strength},
		"shark": shark.to_data(),
		"spawn": [spawn_cell.x, spawn_cell.y],
		"quests": quests.to_data(),
		"landmarks": landmarks,
		"cat": cat.to_data() if cat != null and is_instance_valid(cat) else {},
		"nav": [nav_target.x, nav_target.z, nav_name] if nav_target != null else [],
		"travel": travel,
		"trader_t": trader_t if trader == null else 600.0,
		"wreck_pages": wreck_pages,
		"notes": hud.lore.to_data(),
		"legend": legend,
		"wreck_sites": wreck_sites,
		"story_done": story_done,
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not (data is Dictionary):
		return false
	_clear_world_objects()
	difficulty = int(data.get("difficulty", 1))
	raft.from_data(data.get("raft", {}))
	player.from_data(data.get("player", {}))
	var w: Dictionary = data.get("world", {})
	world.hour = float(w.get("hour", 8.0))
	world.day = int(w.get("day", 1))
	world.raining = w.get("raining", false)
	world.rain = float(w.get("rain", 0.0))
	world.weather_timer = float(w.get("weather", 400.0))
	world.wind_from = float(w.get("wind_from", 30.0))
	world.wind_target_from = world.wind_from
	world.wind_strength = float(w.get("wind", 0.55))
	world.wind_target_strength = world.wind_strength
	shark.from_data(data.get("shark", {}))
	var sp: Array = data.get("spawn", [0, 0])
	spawn_cell = Vector2i(int(sp[0]), int(sp[1]))
	# Oyun her zaman salda başlar: kayıtta denizde ya da adadaysa yatağın yanına (doğma noktası) alınır.
	if not data.get("player", {}).get("on_raft", true):
		player.global_position = raft.to_global(raft.safe_spot(spawn_cell))
		player.velocity = Vector3.ZERO
	_reset_world_stream()
	travel = float(data.get("travel", 0.0))
	_clear_trader()
	trader_t = float(data.get("trader_t", 900.0))
	wreck_pages = int(data.get("wreck_pages", 0))
	hud.lore.from_data(data.get("notes", []))
	legend = data.get("legend", {})
	_clear_sites()
	wreck_sites = data.get("wreck_sites", [])
	for st in wreck_sites:
		st["looted"] = (st.get("looted", []) as Array).map(func(v): return int(v))
		st["seed"] = int(st.get("seed", 1))
		st["spots"] = int(st.get("spots", 5))
	story_done = data.get("story_done", false)
	legend_island = null
	landmarks = data.get("landmarks", [])
	if cat != null and is_instance_valid(cat):
		cat.queue_free()
	cat = null
	var cd: Dictionary = data.get("cat", {})
	if not cd.is_empty():
		var c = make_cat(true)
		c.coat = cd.get("coat", "tekir")
		c.from_data(cd)
		raft.add_child(c)
		var cp: Array = cd.get("pos", [0.75, 0.75])
		c.position = Vector3(float(cp[0]), raft.top_y(), float(cp[1]))
		cat = c
	var nv: Array = data.get("nav", [])
	nav_target = Vector3(float(nv[0]), 0, float(nv[1])) if nv.size() >= 2 else null
	nav_name = nv[2] if nv.size() >= 3 else ""
	quests.from_data(data.get("quests", {}))
	last_day = world.day
	return true


# --- Her kare ----------------------------------------------------------------

func _run_debug_action() -> void:
	var list := debug_action.split(",")
	debug_action = ""
	for a in list:
		_debug_one(a.strip_edges())


func _debug_one(a: String) -> void:
	# Bir yuvayı yalnız okuyarak açar (dev_run kaydı engeller) ve salın birkaç saniyelik hareketini yazar.
	if a.begins_with("slotprobe:"):
		load_slot(int(a.substr(10)))
		var p0: Vector3 = raft.base_pos
		for k in 4:
			await get_tree().create_timer(2.0).timeout
			print("SALPROBE t=%d pos=%s hiz=%.2f karada=%s" % [(k + 1) * 2, raft.base_pos, raft.speed(), raft.grounded])
		print("SALPROBE toplam yol=%.2f m sandik=%d istif=%s" % [raft.base_pos.distance_to(p0), raft.buildings.values().filter(func(b): return b.kind == "sandik").size(), raft.stacks.keys().map(func(k): return [k, raft.stacks[k].size()])])
		return
	# Kamerayı aya çevirir (gece gökyüzü kontrolü)
	if a == "lookmoon" or a == "looknorth":
		await get_tree().process_frame
		var md: Vector3 = world.moon.global_transform.basis.z if a == "lookmoon" else Vector3(0.0, 0.616, -0.788)
		player.frozen = true
		player.rotation.y = atan2(-md.x, -md.z)
		player.head.rotation.x = clampf(atan2(md.y, Vector2(md.x, md.z).length()) - 0.15, -1.4, 1.4)
		return
	# Oyuncuyu sal üzerinde bir karoya koyar ve bir yöne baktırır: "standat:x:y:yaw_derece"
	if a.begins_with("standat:"):
		var pr := a.split(":")
		await get_tree().create_timer(0.5).timeout
		player.frozen = true
		player.velocity = Vector3.ZERO
		player.global_position = raft.to_global(raft.cell_pos(Vector2i(int(pr[1]), int(pr[2]))) + Vector3(0, raft.top_y() + 0.1, 0))
		player.rotation.y = deg_to_rad(float(pr[3]))
		player.head.rotation.x = -0.1
		return
	if a == "fps":
		Settings.show_fps = true
		return
	if a == "scenestat":
		await get_tree().create_timer(1.5).timeout
		var by := {}
		var shadow := 0
		for n in find_children("*", "GeometryInstance3D", true, false):
			var gi := n as GeometryInstance3D
			if not gi.is_visible_in_tree():
				continue
			if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				shadow += 1
			var top: Node = gi
			while top.get_parent() != self and top.get_parent() != null:
				if top.get_parent() == raft:
					break
				top = top.get_parent()
			var key: String = (("sal/" + String(top.get("kind"))) if top.get("kind") != null else top.name.left(14)) if top.get_parent() == raft else (top.get_script().resource_path.get_file() if top.get_script() != null else top.name.left(14))
			by[key] = by.get(key, 0) + 1
		var arr: Array = by.keys()
		arr.sort_custom(func(x, y): return by[x] > by[y])
		var out := ""
		for k in arr.slice(0, 25):
			out += "%s=%d " % [k, by[k]]
		print("SCENESTAT gölgeli=", shadow, " ", out)
		return
	if a == "raftstat":
		await get_tree().create_timer(1.0).timeout
		var vis := 0
		var hid := 0
		for n in raft.find_children("*", "MeshInstance3D", true, false):
			if (n as MeshInstance3D).is_visible_in_tree():
				vis += 1
			else:
				hid += 1
		var by := {}
		for n in raft.find_children("*", "MeshInstance3D", true, false):
			if (n as MeshInstance3D).is_visible_in_tree():
				var top: Node = n
				while top.get_parent() != raft:
					top = top.get_parent()
				var key: String = top.get("kind") if top.get("kind") != null else top.name.left(10)
				by[key] = by.get(key, 0) + 1
		print("RAFTSTAT parça=", raft.chunks.size(), " birleşik=", raft.chunks.values().filter(func(c): return c["mesh"] != null).size(), " görünür ağ=", vis, " gizli=", hid, " ", by)
		return
	if a == "fishfight":
		player.inv.slots[0] = {"id": "olta", "n": 1, "dur": 50}
		player.selected = 0
		player.rotation.y = 0.0
		player.head.rotation.x = -0.12
		fishing.cast(player, 0.7)
		fishing.global_position = player.global_position + Vector3(0, 0, -11)
		fishing.start_fight(player)
		fishing.fish = fishing.SPECIES[3]
		fishing.fish_kg = 2.4
		fishing.tension = 0.55
		fishing.leap_cd = 1.5
		return
	if a.begins_with("isle:"):
		# Belirli türde adayı salın önüne kur, oyuncuyu kumsala koy, adaya baktır
		var k := a.substr(5)
		var ip: Vector3 = raft.center_global() + Vector3(0, 0, -45.0)
		var isl
		if k == "fener":
			var lmk: Dictionary = _new_landmark(ip)
			_spawn_landmark(lmk)
			isl = islands.back()
		else:
			isl = _make_island(k, 11, ip, {})
		var beach: Vector3 = isl.to_global(isl._ground(0.0, 11.0))
		player.global_position = beach + Vector3(0, 1.0, 0)
		player.velocity = Vector3.ZERO
		player.rotation.y = 0.0
		player.head.rotation.x = 0.12
		return
	if a.begins_with("lhstage:"):
		var lh = islands.back().lighthouse
		if lh != null:
			lh.landmark["stage"] = int(a.substr(8))
			lh._rebuild()
		return
	if a == "helmset":
		for c in [Vector2i(2, 0), Vector2i(2, 1)]:
			raft.add_tile(c)
		raft.place_building("dumen", Vector2i(0, 0), {"rot": PI})
		raft.place_building("motor", Vector2i(2, 0))
		raft.place_building("telsiz", Vector2i(2, 1), {"rot": -PI / 2.0})
		player.global_position = raft.to_global(Vector3(1.5, 0.5, 1.7))
		player.rotation.y = 0.0
		player.head.rotation.x = -0.3
		return
	if a.begins_with("pose:"):
		player.debug_pose = float(a.substr(5))
		return
	if a == "seeds":
		for k in ["tohum", "domates_tohumu", "biber_tohumu", "karpuz_tohumu", "zeytin_fidani", "domates", "biber", "karpuz"]:
			player.inv.add(k, 3)
		return
	if a == "trader" or a == "trade":
		var tr = spawn_trader()
		tr.dock_now()
		player.global_position = raft.to_global(tr.dock_local - tr.dock_dir * (tr.BEAM + 1.4) + Vector3(0, 0.4, 0))
		var lookp: Vector3 = tr.global_position + Vector3(0, 1.0, 0)
		var dd: Vector3 = lookp - player.global_position
		player.rotation.y = atan2(-dd.x, -dd.z)
		player.head.rotation.x = -0.05
		if a == "trade":
			for k in ["ham_balik", "zeytin", "pismis_balik", "tas", "kumas", "ip", "metal_kulce", "hindistan_cevizi"]:
				player.inv.add(k, 10)
			hud.open_trade(tr)
		return
	if a.begins_with("deepwreck:"):
		var dk := a.substr(10)
		var st := {"x": raft.center_global().x, "z": raft.center_global().z - 70.0, "kind": dk, "seed": 99, "found": true, "looted": [], "spots": SITE_SPOTS[dk]}
		wreck_sites.append(st)
		_stream_sites(0.0)
		await get_tree().process_frame
		var w = site_nodes[wreck_sites.size() - 1]
		var tp: Vector3 = w.global_position + Vector3(9.0, 0, 9.0)
		tp.y = w.height_at(9.0, 9.0) + 1.6
		player.global_position = tp
		player.velocity = Vector3.ZERO
		player.frozen = true
		player.gear["fener"] = "dalgic_feneri"
		player.gear["tup"] = "oksijen_tupu"
		player.tank_air = 100.0
		var lk: Vector3 = w.global_position + Vector3(0, -13.5, 0) - (tp + Vector3(0, 1.6, 0))
		player.rotation.y = atan2(-lk.x, -lk.z)
		player.head.rotation.x = atan2(lk.y, Vector2(lk.x, lk.z).length())
		return
	if a == "sonar":
		raft.add_tile(Vector2i(0, -1))
		raft.place_building("sonar", Vector2i(0, -1))
		_new_site(raft.center_global(), "antik")
		player.rotation.y = 0.0
		player.head.rotation.x = -0.45
		return
	if a == "radiodemo":
		raft.add_tile(Vector2i(0, -1))
		raft.place_building("telsiz", Vector2i(0, -1), {"rot": PI})
		player.rotation.y = 0.0
		player.head.rotation.x = -0.45
		return
	if a == "chestdemo" or a == "chestopen":
		raft.add_tile(Vector2i(0, -1))
		raft.add_tile(Vector2i(1, -1))
		var c1 = raft.place_building("sandik", Vector2i(0, -1), {"rot": PI})
		raft.place_building("sandik", Vector2i(1, -1), {"rot": PI})
		raft.stack_chest(Vector2i(1, -1))
		player.rotation.y = 0.0
		player.head.rotation.x = -0.5
		if a == "chestopen" and c1 != null:
			hud.chest = c1
		return
	if a == "newitems":
		for k in ["kurdele", "inci", "deniz_yosunu", "istiridye", "oksijen_tupu", "palet", "kopekbaligi_yemi", "diken_tuzagi", "nazar", "cay",
				"cam", "mercek", "zeytinyagi", "tas", "demir_cevheri", "kum", "zeytin", "yengec_eti", "marti_yumurtasi", "kedi_yatagi", "dumen", "motor", "telsiz", "kazma", "pusula"]:
			player.inv.add(k, 2)
		return
	if a == "allnotes":
		for id in hud.lore.NOTES:
			if id != "hizir":
				hud.lore.read.append(id)
		return
	if a == "endscreen":
		_show_end()
		return
	if a == "note":
		hud.lore.read_note("sise_1")
		return
	if a == "bottle":
		var b = DebrisScript.new()
		b.main = self
		b.kind = "sise"
		add_child(b)
		b.position = player.global_position + Vector3(0, 0, -2.5)
		debris.append(b)
		player.rotation.y = 0.0
		player.head.rotation.x = -0.6
		return
	if a == "legend" or a == "ending":
		var lisl = _make_island("efsanevi", 4242, raft.center_global() + Vector3(0, 0, -70), {})
		legend_island = lisl
		await get_tree().process_frame
		var tp: Vector3 = lisl.global_position + Vector3(4.5, 0, 6.5)
		tp.y = lisl._ground(4.5, 6.5).y + 0.3
		player.global_position = tp
		player.velocity = Vector3.ZERO
		player.frozen = true
		var lk: Vector3 = lisl.global_position + Vector3(0, 4.5, 0) - (tp + Vector3(0, 1.6, 0))
		player.rotation.y = atan2(-lk.x, -lk.z)
		player.head.rotation.x = atan2(lk.y, Vector2(lk.x, lk.z).length())
		if a == "ending":
			player.inv.add("kurdele", 1)
			for c in lisl.get_children():
				if c.get_script() == preload("res://scripts/wish_tree.gd"):
					c.interact(player)
		return
	if a == "slots" or a == "loadslots":
		menu._show_slots("new" if a == "slots" else "load")
		return
	if a == "nazar":
		raft.add_tile(Vector2i(0, -1))
		raft.place_building("nazar", Vector2i(0, -1))
		player.inv.add("nazar", 2)
		player.inv.add("cay", 3)
		player.rotation.y = 0.0
		player.head.rotation.x = -0.25
		return
	if a == "traderfar":
		var tf = spawn_trader()
		var df: Vector3 = tf.global_position - player.global_position
		player.rotation.y = atan2(-df.x, -df.z)
		player.head.rotation.x = 0.0
		return
	if a == "cat" or a == "catwild":
		var c = make_cat(a == "cat")
		if a == "cat":
			raft.add_child(c)
			raft.add_tile(Vector2i(0, -1))
			raft.add_tile(Vector2i(1, -1))
			c.position = Vector3(0.9, raft.top_y(), -0.9)
			c.rotation.y = 2.4
			cat = c
		else:
			add_child(c)
			c.global_position = player.global_position + Vector3(0, -0.3, -1.6)
		player.rotation.y = 0.0
		player.head.rotation.x = -0.42
		return
	if a.begins_with("catpose:"):
		if cat != null:
			cat.state = int(a.substr(8))
			cat.state_t = 999.0
			if a.substr(8) == "0":
				cat.target = cat.position + Vector3(0, 0, 50)
		return
	if a == "journal":
		hud.journal.toggle()
		return
	if a == "questdemo":
		player.give("tahta", 6)
		player.give("plastik", 2)
		return
	if a == "help":
		menu._show_help("main")
		return
	if a == "grill":
		raft.place_building("izgara", Vector2i(1, 0), {"busy": true, "timer": 1.0e9, "cooking": "ham_balik", "rot": 0.0})
		raft.place_building("aritici", Vector2i(1, 1), {"busy": true, "timer": 1.0e9, "rot": PI / 2.0})
		return
	if a == "reef" or a == "wreck":
		# Salın önüne ada kur, oyuncuyu resifin (ya da batığın) yanına dalgın koy
		var isl = _make_island("palmiye" if a == "reef" else "batik", randi(), raft.center_global() + Vector3(0, 0, -60), {})
		await get_tree().process_frame
		var tgt: Vector3
		if a == "wreck" and isl.wreck != null:
			tgt = isl.wreck.global_position + isl.wreck.global_transform.basis * Vector3(-5.5, 2.2, -5.0)
			player.global_position = tgt
			var lw: Vector3 = isl.wreck.global_position + Vector3(0, 0.6, 0) - (tgt + Vector3(0, 1.6, 0))
			player.rotation.y = atan2(-lw.x, -lw.z)
			player.head.rotation.x = clampf(atan2(lw.y, Vector2(lw.x, lw.z).length()), -1.2, 1.2)
		else:
			var dir: Vector3 = (raft.center_global() - isl.global_position).normalized()
			tgt = isl.global_position + dir * 22.0
			tgt.y = isl._ground(dir.x * 26.0, dir.z * 26.0).y + 0.6
			player.global_position = tgt
			player.rotation.y = atan2(-dir.x, -dir.z) + 0.6
			player.head.rotation.x = -0.25
		player.velocity = Vector3.ZERO
		player.frozen = true
		player.gear["tup"] = "oksijen_tupu"
		player.gear["palet"] = "palet"
		player.tank_air = 100.0
		return
	if a == "gear":
		player.inv.add("oksijen_tupu", 1)
		player.inv.add("palet", 1)
		player.inv.add("kopekbaligi_yemi", 3)
		player.inv.add("diken_tuzagi", 1)
		player.inv.add("inci", 4)
		player.inv.add("istiridye", 2)
		player.inv.add("deniz_yosunu", 5)
		return
	if a == "spikes":
		raft.add_tile(Vector2i(0, -1))
		raft.place_building("diken_tuzagi", Vector2i(0, -1))
		player.rotation.y = 0.0
		player.head.rotation.x = -0.5
		return
	if a == "underwater":
		player.global_position = raft.to_global(Vector3(0.75, -1.65, -5.0))
		player.velocity = Vector3.ZERO
		player.rotation.y = 0.0
		player.head.rotation.x = -0.15
		return
	if a == "decor":
		for c in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(3, 0), Vector2i(3, 1)]:
			raft.add_tile(c)
		raft.place_building("yatak", Vector2i(3, 0), {"rot": PI / 2.0})
		raft.place_building("masa", Vector2i(2, 0))
		raft.place_building("sandalye", Vector2i(2, 1), {"rot": PI})
		raft.place_building("hali", Vector2i(3, 1))
		player.global_position = raft.to_global(Vector3(0.2, 0.4, 0.75))
		player.rotation.y = -PI / 2.0
		player.head.rotation.x = -0.45
		return
	if a == "continue":
		continue_game()
		return
	if a == "metal":
		raft.reinforce(Vector2i(1, 0))
		raft.reinforce(Vector2i(1, 1))
		return
	if a == "nets":
		var net = raft.place_building("toplayici", Vector2i(1, 0), {"rot": PI / 2.0})
		for k in [["tahta", 3], ["plastik", 2], ["yaprak", 2], ["hurda", 1]]:
			net.storage.add(k[0], k[1])
		var net2 = raft.place_building("toplayici", Vector2i(1, 1), {"rot": PI / 2.0})
		net2.storage.add("plastik", 1)
		net2.storage.add("tahta", 2)
		return
	if a == "smelter":
		raft.add_tile(Vector2i(2, 0))
		raft.add_tile(Vector2i(2, 1))
		raft.place_building("ocak", Vector2i(2, 0), {"busy": true, "timer": 1.0e9, "rot": -PI / 2.0})
		raft.place_building("ocak", Vector2i(2, 1), {"output": "metal_kulce", "rot": -PI / 2.0})
		return
	if a == "lowstats":
		player.thirst = 18.0
		player.oxygen = 64.0
		return
	if a.begins_with("hold:"):
		var id := a.substr(5)
		player.inv.slots[2] = {"id": id, "n": 1, "dur": int(Items.info(id).get("dur", 0))}
		player.selected = 2
		player.inv.changed.emit()
		return
	if a.begins_with("hour:"):
		world.hour = float(a.substr(5))
		return
	if a.begins_with("look:"):
		var v := a.substr(5).split("/")
		player.rotation.y = float(v[0])
		player.head.rotation.x = float(v[1])
		return
	if a == "house":
		for c in [Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2)]:
			raft.add_tile(c)
		raft.add_structure("duvar", Vector2i(0, 0), "N")
		raft.add_structure("pencere", Vector2i(1, 0), "N")
		raft.add_structure("duvar", Vector2i(1, 0), "E")
		raft.add_structure("kapi", Vector2i(1, 1), "E")
		raft.add_structure("duvar", Vector2i(0, 0), "W")
		raft.add_structure("pencere", Vector2i(0, 1), "W")
		for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			raft.add_structure("cati", c, "roof")
		raft.add_lamp(Vector2i(0, 0))
		raft.add_lamp(Vector2i(1, 1))
		raft.place_building("yatak", Vector2i(0, 0))
		raft.place_building("sandik", Vector2i(1, 0))
		raft.place_building("aritici", Vector2i(0, 2))
		raft.place_building("ocak", Vector2i(1, 2))
		raft.place_building("fener", Vector2i(2, 1))
		raft.place_building("toplayici", Vector2i(2, 0), {}, raft.outward_angle(Vector2i(2, 0)))
		raft.place_building("capa", Vector2i(-1, 1))
		player.global_position = raft.to_global(Vector3(0.75, 0.4, 3.8))
		return
	if a.begins_with("cat:"):
		hud.craft_cat = a.substr(4)
		hud.selected_recipe = {}
		hud._refresh()
		return
	match a:
		"new_game":
			new_game()
		"inventory":
			hud.toggle_inventory()
		"map":
			hud.toggle_map()
		"island":
			_spawn_island()
		"chop", "chop1":
			# Adadaki ilk ağacın önüne geç, ona bak ve vur (chop1: tek vuruş, chop: devir).
			if not islands.is_empty():
				for n in islands[0].find_children("*", "StaticBody3D", true, false):
					if n.has_method("chop"):
						var tp: Vector3 = n.global_position
						player.global_position = tp + Vector3(1.7, 0.6, 0.8)
						player.velocity = Vector3.ZERO
						var d: Vector3 = tp - player.global_position
						player.rotation.y = atan2(-d.x, -d.z)
						player.head.rotation.x = -0.45
						for i in (1 if a == "chop1" else 3):
							# Ekran görüntüsü için vuruşlar 3 sn sonra, 0.6 sn arayla
							get_tree().create_timer(3.0 + i * 0.6).timeout.connect(func(): n.chop(player))
						break
		"face_island":
			if not islands.is_empty():
				var d: Vector3 = islands[0].global_position - player.global_position
				player.rotation.y = atan2(-d.x, -d.z)
				player.head.rotation.x = 0.0
		"items":
			for k in [["tahta", 14], ["plastik", 9], ["yaprak", 5], ["hurda", 2], ["konserve", 2], ["su_sise", 1], ["olta", 1], ["ham_balik", 3]]:
				player.give(k[0], k[1])
		"shark":
			shark.global_position = player.global_position + (-player.camera.global_transform.basis.z * Vector3(1, 0, 1)).normalized() * 6.0
			shark.global_position.y = -0.3


var prof_usec := 0
## `--debug`, `--shot`, `--perf` ile açılan geliştirici çalıştırması mı?
var dev_run := false
var travel_pending := 0.0
func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_process_body(delta)
	prof_usec += Time.get_ticks_usec() - t0


func _process_body(delta: float) -> void:
	if debug_action != "":
		_run_debug_action()
	Waves.time += delta
	var cam: Camera3D = get_viewport().get_camera_3d()
	var cp: Vector3 = cam.global_position if cam != null else Vector3.ZERO
	var rc: Vector3 = showcase.center_global() if showcase != null else raft.center_global()
	var calm_r: float = (showcase.raft.radius() if showcase != null else raft.radius())
	Waves.calm_pos = Vector2(rc.x, rc.z)
	Waves.calm_r = calm_r
	for m in ocean_mats:
		var sm: ShaderMaterial = m
		sm.set_shader_parameter("t", Waves.time)
		sm.set_shader_parameter("cam_pos", cp)
		sm.set_shader_parameter("wave_scale", Waves.amp)
		sm.set_shader_parameter("raft_pos", rc)
		sm.set_shader_parameter("raft_radius", (showcase.raft.radius() if showcase != null else raft.radius()) - 0.6)
		sm.set_shader_parameter("calm_radius", calm_r)
	ocean_near.global_position = Vector3(snappedf(cp.x, 0.5), 0.0, snappedf(cp.z, 0.5))
	ocean_far.global_position = Vector3(snappedf(cp.x, 10.0), 0.0, snappedf(cp.z, 10.0))

	# Ortam sesleri
	var under: bool = player.head_under and not paused
	audio.set_underwater(under)
	audio.ambient("ocean_1", 0.0 if under else 0.36, delta)
	audio.ambient("ocean_2", 0.0 if under else 0.26 + world.rain * 0.25, delta)
	audio.ambient("wind", 0.08 + world.rain * 0.35 + raft.sail_vector().length() * 0.05, delta)
	var sheltered: bool = raft.has_roof_at(player.global_position)
	audio.ambient("rain", world.rain * (0.18 if sheltered else 0.38), delta)
	audio.ambient("underwater", 0.7 if under else 0.0, delta)

	if paused:
		if menu.mode in ["main", "slots"] or (menu.mode in ["settings", "help"] and menu.back_to == "main"):
			menu_angle += delta * 0.05
			menu_cam.global_position = rc + Vector3(cos(menu_angle) * 15.0, 5.2, sin(menu_angle) * 15.0)
			menu_cam.look_at(rc + Vector3(0, 1.3, 0))
		elif Input.is_action_just_pressed("pause") and menu.mode == "pause":
			resume()
		elif Input.is_action_just_pressed("pause") and menu.mode in ["settings", "help"] and menu.back_to == "pause":
			menu.show_mode("pause")
		return

	if Input.is_action_just_pressed("pause"):
		if hud.lore.end_panel.visible:
			pass
		elif hud.menu_open:
			hud.close_menus()
		else:
			pause_game()
			return
	# Sandık E ile açılır, yine E ile kapanır.
	if Input.is_action_just_pressed("interact") and hud.menu_open and (hud.chest != null or hud.trade != null) and Engine.get_process_frames() != hud.chest_opened_frame:
		hud.close_menus()
	elif Input.is_action_just_pressed("quick_store") and hud.menu_open and hud.chest != null:
		hud.quick_store()
	elif Input.is_action_just_pressed("inventory") and not dead:
		hud.toggle_inventory()
	if Input.is_action_just_pressed("map") and not dead:
		hud.toggle_map()
	if Input.is_action_just_pressed("journal") and not dead and (not hud.menu_open or hud.journal.book.visible):
		hud.journal.toggle()
	if world.day != last_day:
		last_day = world.day
		quests.event("day", "", world.day)
	_check_island_visit()

	_stream_world(delta)
	_trader_step(delta)
	_stream_legend()
	_sonar_step(delta)
	# Denizde not taşıyan şişeler (okunmamış not kaldıkça)
	bottle_t -= delta
	if bottle_t <= 0.0:
		bottle_t = randf_range(150.0, 260.0)
		if hud.lore.next_bottle() != "":
			var b = DebrisScript.new()
			b.main = self
			b.kind = "sise"
			add_child(b)
			var fwd := _stream_dir()
			b.position = raft.center_global() + fwd * randf_range(35.0, 50.0) + Vector3(-fwd.z, 0, fwd.x) * randf_range(-6.0, 6.0)
			debris.append(b)

	if not dead:
		var hk: float = diff()["hunger"]
		player.hunger = maxf(0.0, player.hunger - HUNGER_RATE * hk * delta)
		player.thirst = maxf(0.0, player.thirst - THIRST_RATE * hk * delta)
		if player.hunger <= 0.0 or player.thirst <= 0.0:
			player.health -= 1.2 * delta
			if player.health <= 0.0:
				on_player_died()
		elif player.hunger > 50.0 and player.thirst > 50.0:
			player.health = minf(100.0, player.health + 0.4 * delta)

	autosave_timer -= delta
	if autosave_timer <= 0.0:
		autosave_timer = AUTOSAVE
		save_game()


# --- Tam bitmiş kayıt ---------------------------------------------------------

## `-- --fullsave`: bütün geliştirmeleri tamamlanmış bir kayıt yazar (user://kayit.json) ve çıkar.
## Güçlendirilmiş 8x7 sal, kapalı ev, bütün yapılar, dolu sandıklar, en iyi aletler.
func _make_full_save() -> void:
	new_game()
	raft.reset_raft()
	ShowcaseScript.furnish(raft, false)
	var chests: Array = []
	for c in raft.buildings:
		var b = raft.buildings[c]
		if b.kind == "sandik":
			chests.append(b)
	if chests.size() >= 2:
		for k in [["tahta", 120], ["plastik", 90], ["ip", 60], ["yaprak", 60], ["civi", 60], ["kumas", 20]]:
			chests[0].storage.add(k[0], k[1])
		for k in [["hurda", 40], ["metal_kulce", 20], ["tohum", 10], ["konserve", 10], ["hindistan_cevizi", 10], ["patates", 10], ["su_sise", 6]]:
			chests[1].storage.add(k[0], k[1])
	var inv = player.inv
	inv.from_data([])
	for id in ["metal_kanca", "cekic", "metal_mizrak", "balta", "olta", "durbun", "mesale"]:
		inv.add(id, 1)
	for k in [["pismis_balik", 10], ["temiz_su", 10], ["balik_corbasi", 5]]:
		inv.add(k[0], k[1])
	for k in [["tahta", 30], ["plastik", 30], ["ip", 20], ["civi", 20], ["metal_kulce", 6], ["hurda", 10], ["yaprak", 20], ["kumas", 6], ["tavan_lambasi", 2], ["toplayici", 1]]:
		inv.add(k[0], k[1])
	player.selected = 0
	player.health = 100.0
	player.hunger = 100.0
	player.thirst = 100.0
	player.oxygen = 100.0
	player.global_position = raft.to_global(raft.cell_pos(Vector2i(1, 2)) + Vector3(0, 0.6, 0))
	player.rotation.y = PI  # evin kapısına sırtını dönmüş, güverteye bakıyor
	world.day = 30
	world.hour = 9.0
	world.raining = false
	world.rain = 0.0
	save_game()
	print("TAM KAYIT yazıldı: ", ProjectSettings.globalize_path(save_path), " karo=", raft.tiles.size(), " yapı=", raft.buildings.size(), " duvar/çatı=", raft.structures.size())
	if not "--loadtest" in OS.get_cmdline_user_args():
		get_tree().quit()


## `-- --debug=new_game,journal --shot=dosya.png [--wait=4]`: geliştirici komutlarını çalıştırır,
## bekler, ekran görüntüsünü kaydeder ve çıkar (editör bağlantısı olmadan görsel kontrol için).
func _screenshot(path: String) -> void:
	var wait := 4.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--debug="):
			debug_action = arg.substr(8)
		if arg.begins_with("--wait="):
			wait = float(arg.substr(7))
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("EKRAN kaydedildi: ", path)
	get_tree().quit()


## `-- --perf=new_game,reef`: geliştirici komutlarını çalıştırır, 4 sn bekler, 5 sn boyunca kare hızını ve
## çizim yükünü ölçüp yazar (dikey eşitleme kapalı).
func _perf(actions: String) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var t := get_tree()
	# İkonlar açılışta üretilir; ölçüm onlar bittikten sonra başlar
	while not icons.ready_done:
		await t.process_frame
	debug_action = actions
	await t.create_timer(4.0).timeout
	# `--off=hud,debris,...`: bu parçaların her kare işlemesi kapatılır (hangi sistemin pahalı olduğunu bulmak için)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--off="):
			for k in arg.substr(6).split(","):
				var nodes: Array = []
				if k == "debris":
					nodes = debris
				elif k == "islands":
					nodes = islands
				elif k == "minimap":
					nodes = [hud.minimap]
				elif k == "targets":
					for bb in raft.find_children("*", "StaticBody3D", true, false):
						bb.queue_free()
				elif k == "buildings":
					nodes = raft.buildings.values()
					for c in raft.stacks:
						nodes.append_array(raft.stacks[c])
				elif k == "hudonly":
					hud.set_process(false)
				elif get(k) != null:
					nodes = [get(k)]
				for n in nodes:
					(n as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var frames := 0
	var start := Time.get_ticks_usec()
	var worst := 0.0
	var proc := 0.0
	var phys := 0.0
	var dc := 0.0
	var objs := 0.0
	var prims := 0.0
	var last := start
	prof_usec = 0
	raft.prof_usec = 0
	while Time.get_ticks_usec() - start < 5000000:
		await t.process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var secs := (Time.get_ticks_usec() - start) / 1000000.0
	print("PERF [", actions, "] fps=", snappedf(frames / secs, 0.1), " en kötü kare=", snappedf(worst, 0.1), " ms  process=", snappedf(proc / frames * 1000.0, 0.01),
		" ms  physics=", snappedf(phys / frames * 1000.0, 0.01), " ms  çizim çağrısı=", int(dc / frames), " nesne=", int(objs / frames), " üçgen=", int(prims / frames),
		" düğüm=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), " kalite=", Settings.quality, " ekran kartı=", RenderingServer.get_video_adapter_name(), " main._process=", snappedf(prof_usec / 1000.0 / frames, 0.01), " ms raft._physics=", snappedf(raft.prof_usec / 1000.0 / frames, 0.01), " ms")
	t.quit()


## `-- --bigraft=N`: N. yuvadaki kaydı açar; görevler, dünya ve envanter korunur, sal 20x20 güçlendirilmiş
## zemine, iki kapalı eve (yaşam + depo) ve bütün yapılara çevrilir; eski sandıklar içindekilerle depoya taşınır.
func _big_raft_slot(s: int) -> void:
	var t := get_tree()
	while not icons.ready_done:
		await t.process_frame
	slot = s
	save_path = slot_path(s)
	if not load_game():
		print("BUYUK SAL: kayıt açılamadı ", save_path)
		t.quit()
		return
	_start_play()
	await t.process_frame
	# Eski sandık kuleleri (alttan üste) içindekilerle saklanır
	var groups: Array = []
	for c in raft.buildings:
		var b = raft.buildings[c]
		if b.kind == "sandik":
			var g: Array = [b.to_data()]
			for st in raft.stacks.get(c, []):
				g.append(st.to_data())
			groups.append(g)
	var keep_pos: Vector3 = raft.base_pos
	var keep_course: float = raft.course
	raft.reset_raft()
	for x in range(-9, 11):
		for y in range(-9, 11):
			if not raft.tiles.has(Vector2i(x, y)):
				raft.add_tile(Vector2i(x, y))
			raft.reinforce(Vector2i(x, y))
	# Yaşam evi 4x3 (kapı güneyde, sol alt) ve depo evi 3x3
	ShowcaseScript._house(raft, Vector2i(0, -3), Vector2i(3, -1))
	ShowcaseScript._house(raft, Vector2i(-5, -3), Vector2i(-3, -1))
	var plan := {
		# Yaşam evi
		Vector2i(0, -3): ["yatak", PI / 2.0], Vector2i(3, -3): ["yatak", -PI / 2.0],
		Vector2i(1, -3): ["telsiz", 0.0], Vector2i(2, -3): ["sonar", 0.0],
		Vector2i(1, -2): ["masa", 0.0], Vector2i(1, -1): ["sandalye", PI], Vector2i(2, -2): ["hali", 0.0],
		Vector2i(3, -1): ["kedi_yatagi", 0.0], Vector2i(3, -2): ["sandik", -PI / 2.0],
		# Mutfak ve su
		Vector2i(-3, 1): ["aritici", PI / 2.0], Vector2i(-2, 1): ["aritici", PI / 2.0],
		Vector2i(-1, 1): ["izgara", PI / 2.0], Vector2i(0, 1): ["izgara", PI / 2.0],
		Vector2i(2, 1): ["ocak", 0.0], Vector2i(3, 1): ["ocak", 0.0],
		Vector2i(5, 1): ["yagmur_toplayici", 0.0], Vector2i(6, 1): ["yagmur_toplayici", 0.0], Vector2i(7, 1): ["yagmur_toplayici", 0.0],
		Vector2i(5, 3): ["masa", 0.0], Vector2i(5, 4): ["sandalye", PI], Vector2i(6, 3): ["sandalye", -PI / 2.0],
		# Seyir: dümen, motorlar, yelkenler, çapa
		Vector2i(0, 4): ["dumen", 0.0], Vector2i(-1, 10): ["motor", PI], Vector2i(1, 10): ["motor", PI],
		Vector2i(-6, 7): ["yelken", 0.0], Vector2i(6, 7): ["yelken", 0.0], Vector2i(0, 7): ["yelken", 0.0],
		Vector2i(10, 0): ["capa", 0.0], Vector2i(-9, 0): ["capa", 0.0],
		# Koruma ve süs
		Vector2i(2, 4): ["nazar", 0.0], Vector2i(-2, -6): ["nazar", 0.0], Vector2i(7, -6): ["nazar", 0.0],
	}
	# Bahçe: 5x3 saksı, olgun ürünlerle
	for x in range(-8, -3):
		for y in range(4, 7):
			plan[Vector2i(x, y)] = ["saksi", 0.0]
	# Köşe ve kenar fenerleri
	for c in [Vector2i(-9, -9), Vector2i(10, -9), Vector2i(-9, 10), Vector2i(10, 10), Vector2i(4, 4), Vector2i(-6, 0),
			Vector2i(5, -6), Vector2i(-3, 8), Vector2i(4, -2), Vector2i(-1, -4), Vector2i(8, 8), Vector2i(-7, -6)]:
		plan[c] = ["fener", 0.0]
	# Kenarlarda toplayıcı ağlar ve diken tuzakları
	for c in [Vector2i(-9, -5), Vector2i(-9, 5), Vector2i(10, -5), Vector2i(10, 5), Vector2i(-5, -9), Vector2i(5, -9),
			Vector2i(-5, 10), Vector2i(5, 10), Vector2i(0, -9), Vector2i(-9, 8), Vector2i(10, -2), Vector2i(3, 10)]:
		plan[c] = ["toplayici", 0.0]
	for c in [Vector2i(-9, -2), Vector2i(-9, 2), Vector2i(10, 2), Vector2i(10, -7), Vector2i(2, -9), Vector2i(-3, -9),
			Vector2i(-7, 10), Vector2i(7, 10)]:
		plan[c] = ["diken_tuzagi", 0.0]
	var crops := ["domates_tohumu", "biber_tohumu", "karpuz_tohumu", "zeytin_fidani", "tohum"]
	for c in plan:
		var kind: String = plan[c][0]
		var rot: float = plan[c][1]
		if kind in ["capa", "toplayici"]:
			rot = raft.outward_angle(c)
		var data := {"rot": rot, "cell": [c.x, c.y], "kind": kind}
		match kind:
			"saksi":
				data["planted"] = true
				data["growth"] = 1.0
				data["cooking"] = crops[(c.x + c.y + 20) % crops.size()]
			"aritici":
				data["output"] = "temiz_su"
			"izgara":
				data["output"] = "pismis_balik"
			"ocak":
				data["output"] = "metal_kulce"
			"yagmur_toplayici":
				data["stock"] = 3
			"yelken":
				data["open"] = false
				data["dir"] = [0.0, -1.0]
			"motor":
				data["open"] = false
				data["timer"] = 900.0
			"capa":
				data["open"] = c == Vector2i(10, 0)
		raft.place_building(kind, c, data)
	# Eski sandıklar depo evine: kuleler hâlinde
	var depot := [Vector2i(-5, -3), Vector2i(-4, -3), Vector2i(-3, -3), Vector2i(-5, -2), Vector2i(-3, -2), Vector2i(-3, -1)]
	var flat: Array = []
	for g in groups:
		flat.append_array(g)
	var di := 0
	while not flat.is_empty() and di < depot.size():
		var dc: Vector2i = depot[di]
		for k in raft.STACK_MAX + 1:
			if flat.is_empty():
				break
			var d: Dictionary = flat.pop_front()
			d["rot"] = 0.0
			d["cell"] = [dc.x, dc.y]
			if k == 0:
				raft.place_building("sandik", dc, d)
			else:
				raft.stack_chest(dc, d)
		di += 1
	# Sal adaların dışına alınır
	raft.course = keep_course
	var ctr_l: Vector3 = raft.center_local()
	var pos := keep_pos
	var rr: float = raft.radius()
	for pass_i in 3:
		var centers: Array = []
		for isl in islands:
			centers.append([isl.global_position, isl.shore_radius])
		for lm in landmarks:
			centers.append([Vector3(float(lm["x"]), 0, float(lm["z"])), 40.0])
		for ce in centers:
			var off: Vector3 = Vector3(pos.x + ctr_l.x, 0, pos.z + ctr_l.z) - ce[0]
			off.y = 0.0
			var need: float = float(ce[1]) + rr + 6.0
			if off.length() < need:
				var n := off.normalized() if off.length() > 0.1 else Vector3(1, 0, 0)
				pos += n * (need - off.length())
	raft.base_pos = pos
	raft.teleport(Transform3D(Basis.IDENTITY, pos))
	await t.process_frame
	player.health = 100.0
	player.hunger = 100.0
	player.thirst = 100.0
	player.oxygen = 100.0
	player.velocity = Vector3.ZERO
	player.global_position = raft.to_global(raft.cell_pos(Vector2i(1, 1)) + Vector3(0, raft.top_y() + 0.6, 0))
	player.rotation.y = 0.0
	await t.process_frame
	save_game()
	var nst := 0
	for c in raft.stacks:
		nst += raft.stacks[c].size()
	print("BUYUK SAL yazıldı: ", ProjectSettings.globalize_path(save_path), " karo=", raft.tiles.size(), " yapı=", raft.buildings.size(),
		" istif=", nst, " sandık grubu=", groups.size(), " duvar/çatı=", raft.structures.size(), " konum=", pos)
	t.quit()


## `-- --loadtest`: tam kaydı test dosyasına yazar, menüden "Devam Et" ile yükler ve oyuncunun salda kalıp kalmadığını izler.
func _load_test() -> void:
	save_path = "user://kayit_test.json"
	if not "--loadonly" in OS.get_cmdline_user_args():
		_make_full_save()
	var t := get_tree()
	new_game()
	to_main_menu()
	await t.create_timer(1.0).timeout
	continue_game()
	var rl: Vector3 = raft.to_local(player.global_position)
	print("YUKLEME ilk: yerel=", rl.snapped(Vector3(0.1, 0.1, 0.1)), " dünya=", player.global_position.snapped(Vector3(0.1, 0.1, 0.1)), " sal=", raft.center_global().snapped(Vector3(0.1, 0.1, 0.1)))
	for i in 10:
		await t.create_timer(2.0).timeout
		var lp: Vector3 = raft.to_local(player.global_position)
		print("YUKLEME t=", (i + 1) * 2, " yerel=", lp.snapped(Vector3(0.1, 0.1, 0.1)), " suda=", player.in_water, " sal hız=", snappedf(raft.speed(), 0.01))
	t.quit()


# --- Geliştirici testi -------------------------------------------------------

## `-- --autotest` ile tüm mekanikleri tuşa basmadan dener.
func _autotest() -> void:
	save_path = "user://kayit_test.json"
	var t := get_tree()
	new_game()
	await t.create_timer(1.0).timeout
	print("TEST başladı karo=", raft.tiles.size(), " kanca=", player.inv.count("kanca"))
	# 1) Kanca
	var best = null
	for d in debris:
		if best == null or d.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
			best = d
	var kind: String = best.kind
	hook.global_position = best.global_position
	hook.state = hook.H.WATER
	hook.visible = true
	hook.auto_reel = true
	for i in 40:
		await t.create_timer(0.5).timeout
		if hook.state == hook.H.HELD:
			break
	hook.auto_reel = false
	print("TEST kanca döndü=", hook.state == hook.H.HELD, " ", kind, " → tahta=", player.inv.count("tahta"), " plastik=", player.inv.count("plastik"), " yaprak=", player.inv.count("yaprak"))
	# 2) Üretim ve inşa
	player.give("tahta", 150)
	player.give("plastik", 30)
	player.give("yaprak", 30)
	player.give("hurda", 10)
	player.give("ip", 30)
	player.give("kumas", 14)
	player.give("civi", 10)
	for r in Items.RECIPES:
		craft(r)
	print("TEST üretim: olta=", player.inv.count("olta"), " mızrak=", player.inv.count("mizrak"), " arıtıcı=", player.inv.count("aritici"), " yelken=", player.inv.count("yelken"), " çapa=", player.inv.count("capa"))
	for c in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(-1, 0)]:
		if player.inv.spend(Items.FOUNDATION_COST):
			raft.add_tile(c)
	player.give("tahta", 10)
	var placed := 0
	for k in [["aritici", Vector2i(1, 1)], ["izgara", Vector2i(2, 1)], ["sandik", Vector2i(-1, 0)], ["saksi", Vector2i(2, 0)], ["yelken", Vector2i(0, 1)]]:
		if player.inv.remove(k[0], 1) and raft.place_building(k[0], k[1]) != null:
			placed += 1
	print("TEST karo=", raft.tiles.size(), " yapı=", placed)
	# 3) Arıtıcı, ızgara, saksı
	var pur = raft.buildings.get(Vector2i(1, 1))
	var grill = raft.buildings.get(Vector2i(2, 1))
	var pot = raft.buildings.get(Vector2i(2, 0))
	if pur != null:
		pur.interact(player)
	player.give("ham_balik", 1)
	if grill != null:
		grill.interact(player)
	player.give("tohum", 1)
	if pot != null:
		pot.interact(player)
	print("TEST arıtıcı=", pur != null and pur.busy, " ızgara=", grill != null and grill.busy, " saksı ekili=", pot != null and pot.planted)
	# 4) Yelken: salı hareket ettir
	var sail = raft.buildings.get(Vector2i(0, 1))
	if sail != null:
		sail.open = true
		sail.dir = Vector3(0, 0, 1)
	var p0: Vector3 = raft.center_global()
	player.global_position = raft.to_global(raft.safe_spot(Vector2i(0, 0)))
	await t.create_timer(0.5).timeout
	var pl0: Vector3 = raft.to_local(player.global_position)
	await t.create_timer(8.0).timeout
	var pl1: Vector3 = raft.to_local(player.global_position)
	print("TEST sal hızı=", snappedf(raft.speed(), 0.01), " yol=", snappedf(raft.center_global().distance_to(p0), 0.1),
		" oyuncu salda kaydı=", snappedf(Vector2(pl1.x - pl0.x, pl1.z - pl0.z).length(), 0.01), " suda=", player.in_water)
	# 5) Köpekbalığı
	shark.attack_cd = 0.0
	var bitten := false
	for i in 40:
		await t.create_timer(0.5).timeout
		for c in raft.tiles:
			if raft.tiles[c]["hp"] < raft.MAX_HP:
				bitten = true
		if bitten:
			break
	print("TEST köpekbalığı ısırdı=", bitten, " sonra=", shark.S.keys()[shark.state])
	var hit: bool = shark.try_hit(shark.global_position + Vector3(-1, 1.5, 0), Vector3(1, -1.0, 0).normalized(), 3.2)
	print("TEST mızrak isabet=", hit)
	await t.create_timer(14.0).timeout
	if pur != null:
		pur.interact(player)
	if grill != null:
		grill.interact(player)
	print("TEST temiz su=", player.inv.count("temiz_su"), " pişmiş balık=", player.inv.count("pismis_balik"))
	# 5b) Duvar, çatı, lamba, toplama ağı, ocak
	raft.add_structure("duvar", Vector2i(0, 0), "N")
	raft.add_structure("kapi", Vector2i(0, 0), "W")
	raft.add_structure("pencere", Vector2i(1, 0), "E")
	raft.add_structure("cati", Vector2i(0, 0), "roof")
	var lamp_ok: bool = raft.add_lamp(Vector2i(0, 0))
	print("TEST yapı parçası=", raft.structures.size(), " lamba=", lamp_ok, " çatı altı=", raft.has_roof_at(raft.to_global(Vector3(0, 0.5, 0))), " ortak kenar=", raft.has_structure(Vector2i(0, -1), "S"))
	player.give("tahta", 30)
	player.give("ip", 20)
	player.give("plastik", 20)
	player.give("civi", 20)
	player.give("hurda", 10)
	var extra := 0
	for r in Items.RECIPES:
		if r["out"] in ["ocak", "toplayici", "balta", "mesale", "kumas"]:
			if player.inv.has_all(r["cost"]):
				craft(r)
				extra += 1
	print("TEST yeni üretim=", extra, " balta=", player.inv.count("balta"), " meşale=", player.inv.count("mesale"))
	if player.inv.has_all(Items.FOUNDATION_COST):
		player.inv.spend(Items.FOUNDATION_COST)
		raft.add_tile(Vector2i(3, 0))
	var net = raft.place_building("toplayici", Vector2i(3, 0), {}, raft.outward_angle(Vector2i(3, 0)))
	var smelter = raft.place_building("ocak", Vector2i(-1, 0)) if not raft.buildings.has(Vector2i(-1, 0)) else null
	if net != null:
		var cp: Vector3 = net.global_transform * Vector3(0, -0.2, 0.9)
		var d = debris[0]
		d.global_position = cp
		await t.create_timer(0.5).timeout
		var n := 0
		for s in net.storage.slots:
			if s != null:
				n += s["n"]
		var shown_before: int = net.catch_display.get_child_count()
		net.interact(player)
		await t.process_frame
		await t.process_frame
		print("TEST toplama ağı yakaladı=", n, " görünen=", shown_before, " alınca görünen=", net.catch_display.get_child_count())
	# 6) Kayıt ve yükleme
	save_game()
	var tiles_before: int = raft.tiles.size()
	raft.reset_raft()
	var ok := load_game()
	print("TEST kayıt yüklendi=", ok, " karo ", tiles_before, "→", raft.tiles.size(), " yapı=", raft.buildings.size(), " duvar/çatı=", raft.structures.size())
	# 7) Ada
	_spawn_island()
	await t.create_timer(1.0).timeout
	var isl = islands[0]
	var picks := 0
	for c in isl.get_children():
		if c.has_method("interact"):
			picks += 1
	print("TEST ada toplanabilir=", picks)
	# Ada kıyısı: sal, enkaz ve köpekbalığı adanın içine giremez.
	var ic: Vector3 = isl.global_position
	var lc: Vector3 = raft.center_local()
	raft.base_pos = Vector3(ic.x - lc.x + 3.0, 0.0, ic.z - lc.z)
	var dd = debris.back()
	dd.position = ic + Vector3(0, 0, 3.0)
	shark.global_position = ic + Vector3(-6.0, -1.0, 0)
	shark._move_to(ic, 5.0, 0.1, -1.0)
	await t.create_timer(0.3).timeout
	var flat := func(p: Vector3) -> float: return Vector2(p.x - ic.x, p.z - ic.z).length()
	print("TEST ada dışında: sal=", snappedf(flat.call(raft.center_global()), 0.1), " enkaz=", snappedf(flat.call(dd.position), 0.1),
		" köpekbalığı=", snappedf(flat.call(shark.global_position), 0.1), " kıyı=", isl.shore_radius)
	# Ağaç kesme: üç vuruş, devrilme, kütük ve ödül
	var tree = null
	for n in isl.find_children("*", "StaticBody3D", true, false):
		if n.has_method("chop"):
			tree = n
			break
	if tree != null:
		var wood_before: int = player.inv.count("tahta")
		player.global_position = tree.global_position + Vector3(1.5, 0.5, 0)
		for i in 3:
			tree.chop(player)
			await t.create_timer(0.3).timeout
		await t.create_timer(3.4).timeout
		var logs := 0
		for p in tree.spawned:
			if is_instance_valid(p):
				logs += 1
				p.interact(player)
		print("TEST palmiye: devrildi=", tree.falling, " parça=", logs, " tahta +", player.inv.count("tahta") - wood_before)
	# 8) Su ve tırmanma (yelkeni indir, sal dursun). Sal önce adadan uzak açık denize alınır.
	raft.base_pos += Vector3(0, 0, 80.0)
	await t.create_timer(0.3).timeout
	if sail != null:
		sail.open = false
	raft.vel = Vector3.ZERO
	player.global_position = raft.to_global(Vector3(0.75, -1.4, -1.7))
	await t.create_timer(1.0).timeout
	print("TEST suda=", player.in_water)
	# Denizdeyken kaydedilen oyun yüklenince oyuncu salda başlamalı. Sal uzakta kayıtlıyken
	# yeni açılmış oyundaki gibi önce merkeze alınır: yükleme salı anında taşımalı.
	raft.base_pos += Vector3(900.0, 0, 0)
	raft.teleport(Transform3D(Basis.IDENTITY, raft.base_pos))
	await t.physics_frame
	save_game()
	raft.reset_raft()
	await t.physics_frame
	load_game()
	await t.create_timer(0.5).timeout
	var lpos: Vector3 = raft.to_local(player.global_position)
	print("TEST yükleyince salda=", not player.in_water and lpos.y > -0.5 and Vector2(lpos.x, lpos.z).length() < raft.radius())
	player.global_position = raft.to_global(Vector3(0.75, -1.4, -1.7))
	await t.create_timer(0.5).timeout
	player.global_position = raft.to_global(Vector3(0.75, -1.4, -1.7))
	player._try_climb()
	await t.create_timer(0.5).timeout
	print("TEST tırmandı suda=", player.in_water)
	# 9a) Kapı: oyuncunun gövdesi kapı boşluğuna sığmalı; çatıda içeride direk olmamalı
	var dc := Vector2i(-5, 0)
	while raft.has_tile(dc) or raft.has_tile(dc + Vector2i(0, 1)):
		dc.x -= 1
	raft.add_tile(dc)
	raft.add_tile(dc + Vector2i(0, 1))
	raft.add_structure("kapi", dc, "S")
	raft.add_structure("cati", dc, "N")
	await t.physics_frame
	await t.physics_frame
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	q.shape = cap
	q.collision_mask = 1
	var door_local: Vector3 = raft.cell_pos(dc) + Vector3(0, raft.top_y() + 0.875 + 0.05, raft.CELL / 2.0)
	q.transform = Transform3D(raft.global_transform.basis, raft.to_global(door_local))
	var door_hits := get_world_3d().direct_space_state.intersect_shape(q, 8).size()
	q.transform = Transform3D(raft.global_transform.basis, raft.to_global(raft.cell_pos(dc) + Vector3(0.55, raft.top_y() + 0.925, -0.55)))
	var corner_hits := get_world_3d().direct_space_state.intersect_shape(q, 8).size()
	print("TEST kapıdan geçiş engel=", door_hits, " çatı köşesinde direk=", corner_hits)
	# 9b) Sandık: E ile açılır, E ile kapanır (aynı basışta yeniden açılmaz)
	var box = null
	for c in raft.buildings:
		if raft.buildings[c].kind == "sandik":
			box = raft.buildings[c]
	if box != null:
		hud.open_chest(box)
		await t.create_timer(0.2).timeout
		var opened: bool = hud.menu_open
		# Gerçek tuş olayı gibi: bir sonraki karenin girdisi olarak işlenir.
		var ev := InputEventAction.new()
		ev.action = "interact"
		ev.pressed = true
		Input.parse_input_event(ev)
		await t.process_frame
		await t.process_frame
		ev = InputEventAction.new()
		ev.action = "interact"
		ev.pressed = false
		Input.parse_input_event(ev)
		await t.process_frame
		print("TEST sandık: açıldı=", opened, " E ile kapandı=", not hud.menu_open)
	# 9d) Sandık istifi, tür ve hızlı ekleme
	if box != null:
		var c2: Vector2i = box.cell
		var s2 = raft.stack_chest(c2)
		var s3 = raft.stack_chest(c2)
		var s4 = raft.stack_chest(c2)
		for _k in 2:
			raft.stack_chest(c2)
		var s7 = raft.stack_chest(c2)
		var lim_ok: bool = s4 != null and s7 == null
		s2.ctype = "malzeme"
		player.give("tahta", 7)
		player.give("pismis_balik", 2)
		hud.open_chest(s2)
		await t.process_frame
		hud.quick_store()
		var wood_in: int = s2.storage.count("tahta")
		var fish_in: int = s2.storage.count("pismis_balik")
		hud.close_menus()
		var base_blocked: bool = not raft.remove_building_node(box)
		var r0: float = box.rotation.y
		raft.rotate_building(s2)
		var turned: bool = absf(angle_difference(r0, box.rotation.y)) > 1.5 and absf(angle_difference(box.rotation.y, s3.rotation.y)) < 0.01
		print("TEST sandık döndür: istifle birlikte=", turned)
		# Tek eşya türü: yalnızca hurda alan sandık
		s3.set_type("item:hurda")
		print("TEST sandık eşya türü: hurda=", s3.accepts("hurda"), " tahta=", s3.accepts("tahta"), " ad=", s3.type_name(),
			" listede=", hud.chest_type_keys.has("item:metal_kulce") and hud.chest_type_keys.has("malzeme"))
		save_game()
		load_game()
		await t.process_frame
		var st: Array = raft.stacks.get(c2, [])
		print("TEST sandık istif: kat=", 1 + st.size(), " 6 kat sınırı=", lim_ok, " hızlı ekle tahta=", wood_in > 0, " balık girmedi=", fish_in == 0,
			" alttaki korundu=", base_blocked, " yüklenince kat=", 1 + st.size(), " tür=", st[0].ctype if st.size() > 0 else "-")
		# Taşıma modu: kule bütün olarak kaldırılır, kayıt/yükleme sırasında elde kalır, başka karoya içindekilerle konur
		var cbase = raft.buildings.get(c2)
		var cwood: int = st[0].storage.count("tahta") if st.size() > 0 else -1
		var inv_wood0: int = player.inv.count("tahta")
		player.pick_up(cbase)
		await t.process_frame
		var no_dup: bool = player.inv.count("tahta") == inv_wood0
		var cn: int = player.carry.size()
		var cgone: bool = not raft.buildings.has(c2) and not raft.stacks.has(c2)
		save_game()
		load_game()
		await t.process_frame
		var ckept: int = player.carry.size()
		var cdst := Vector2i(9, 9)
		for cc in raft.tiles:
			if raft.can_place_building(cc) and cc != c2:
				cdst = cc
				break
		player._put(cdst, PI / 2.0)
		player.carry = []
		var cst: Array = raft.stacks.get(cdst, [])
		print("TEST taşıma: kopyalanmadı=", no_dup, " alındı=", cn, " karo boşaldı=", cgone, " kayıtta elde=", ckept, " yeni kat=", 1 + cst.size(),
			" içerik=", cst.size() > 0 and cst[0].storage.count("tahta") == cwood, " tür=", cst[0].ctype if cst.size() > 0 else "-",
			" yön=", absf(angle_difference(raft.buildings[cdst].rotation.y, PI / 2.0)) < 0.01)
		player.pick_up(cst.back())
		player.drop_carry_back()
		print("TEST taşıma geri koy: kat=", 1 + raft.stacks.get(cdst, []).size(), " elde=", player.carry.size())
	# 9c) Dekor: sandalye, masa, halı kurulur; sandalyeye oturulup kalkılır
	var dcell := Vector2i(-5, 3)
	while raft.has_tile(dcell) or raft.has_tile(dcell + Vector2i(1, 0)) or raft.has_tile(dcell + Vector2i(2, 0)):
		dcell.x -= 1
	for i in 3:
		raft.add_tile(dcell + Vector2i(i, 0))
	var chair = raft.place_building("sandalye", dcell)
	var table = raft.place_building("masa", dcell + Vector2i(1, 0))
	var rug = raft.place_building("hali", dcell + Vector2i(2, 0))
	player.sit(chair)
	await t.create_timer(0.6).timeout
	var seated: bool = player.seat == chair and player.head.position.y < 1.3
	var on_chair: float = player.global_position.distance_to(chair.global_position)
	player.stand_up()
	await t.create_timer(0.6).timeout
	print("TEST dekor: kuruldu=", chair != null and table != null and rug != null, " oturdu=", seated, " sandalyede=", on_chair < 0.2,
		" kalktı=", player.seat == null and player.head.position.y > 1.5)
	# 9h) Adalar (C): kayalıkta kazma, zeytinlikte zeytin, yengeç; ocakta cam
	player.inv.from_data([])
	var far: Vector3 = raft.center_global() + Vector3(0, 0, 220.0)
	var rocky = _make_island("kayalik", 7, far, {})
	var olivei = _make_island("zeytinlik", 9, far + Vector3(60, 0, 0), {})
	await t.process_frame
	var rock = null
	for n in rocky.get_children():
		if n.has_method("mine"):
			rock = n
			break
	player.inv.slots[0] = {"id": "kazma", "n": 1, "dur": 60}
	player.selected = 0
	var rk_kind: String = rock.kind
	for i in 4:
		rock.mine(player)
	await t.process_frame
	var got_stone := 0
	for n in rocky.get_children():
		if n.has_method("interact") and n.get("item") in ["tas", "demir_cevheri"]:
			n.interact(player)
			got_stone += 1
	var olive = null
	for n in olivei.get_children():
		if n.has_method("interact") and n.get_script() == OliveScriptRef:
			olive = n
			break
	if olive != null:
		olive.interact(player)
	var crab = null
	for n in rocky.get_children() + olivei.get_children():
		if n.has_method("interact") and n.get("legs") != null:
			crab = n
			break
	if crab != null:
		crab.interact(player)
	# Vuruş zamanlaması: tıklayınca değil, alet indiğinde isabet
	var rock2 = null
	for n in rocky.get_children():
		if n.has_method("mine") and not n.broken:
			rock2 = n
			break
	var hp0: int = rock2.hp
	player.global_position = rock2.global_position + Vector3(1.5, 0.5, 0)
	player.tool_t = 0.0
	player.tool_hit_done = false
	player.tool_target = rock2
	player._tool_swing(0.1, rock2, "mine")
	var early: bool = rock2.hp == hp0
	for i in 6:
		player._tool_swing(0.1, rock2, "mine")
	print("TEST vuruş: tıklayınca isabet yok=", early, " indiğinde isabet=", rock2.hp == hp0 - 1, " yay bitti=", player.tool_t < 0.0)
	print("TEST adalar: kaya=", rk_kind, " parça=", got_stone, " taş=", player.inv.count("tas"), " cevher=", player.inv.count("demir_cevheri"),
		" zeytin=", player.inv.count("zeytin"), " yengeç=", player.inv.count("yengec_eti"))
	# Ocakta cam
	var ofree := Vector2i(-6, 0)
	while raft.has_tile(ofree):
		ofree.x -= 1
	raft.add_tile(ofree)
	var oven = raft.place_building("ocak", ofree)
	player.give("kum", 2)
	player.give("tahta", 1)
	oven.interact(player)
	oven.timer = 0.01
	await t.create_timer(0.2).timeout
	var made: String = oven.output
	# 9i) Fener (D): onarım adımları, yanma, kalıcılık, köpekbalığı koruması
	var lm: Dictionary = _new_landmark(raft.center_global() + Vector3(0, 0, -260.0))
	_spawn_landmark(lm)
	await t.process_frame
	var lh = islands.back().lighthouse
	for k in [["tas", 10], ["cam", 4], ["mercek", 1], ["zeytinyagi", 2]]:
		player.give(k[0], k[1])
	for i in 4:
		lh.interact(player)
	var lit: bool = lh.is_lit()
	var safe := near_lit_lighthouse(Vector3(float(lm["x"]), 0, float(lm["z"])) + Vector3(50, 0, 0), 200.0)
	save_game()
	landmarks = []
	load_game()
	var kept := false
	for l in landmarks:
		if l["name"] == lm["name"] and int(l["stage"]) >= 4:
			kept = true
	print("TEST fener: ocak çıktısı=", made, " yandı=", lit, " köpekbalığı koruması=", safe, " kayıtta=", kept)
	# 9j) Dümen, motor, telsiz (E)
	var hfree := Vector2i(-6, 2)
	while raft.has_tile(hfree) or raft.has_tile(hfree + Vector2i(-1, 0)) or raft.has_tile(hfree + Vector2i(-2, 0)):
		hfree.x -= 1
	for i in 3:
		raft.add_tile(hfree + Vector2i(-i, 0))
	var wheel_b = raft.place_building("dumen", hfree)
	var motor_b = raft.place_building("motor", hfree + Vector2i(-1, 0))
	var radio_b = raft.place_building("telsiz", hfree + Vector2i(-2, 0))
	for c in raft.buildings:
		if raft.buildings[c].kind == "yelken":
			raft.buildings[c].open = false
		if raft.buildings[c].kind == "capa":
			raft.buildings[c].open = false
	world.wind_strength = 0.0
	world.wind_target_strength = 0.0
	player.take_helm(wheel_b)
	raft.course = 90.0
	player.inv.from_data([])
	player.give("zeytinyagi", 1)
	motor_b.interact(player)
	motor_b.interact(player)
	raft.vel = Vector3.ZERO
	await t.create_timer(6.0).timeout
	var east: float = raft.vel.x
	player.helm = null
	nav_target = null
	radio_b.interact(player)
	await t.create_timer(2.0).timeout
	print("TEST dümen/motor/telsiz: motor çalışıyor=", motor_b.open, " rüzgârsız doğuya hız=", snappedf(east, 0.01), " telsiz hedefi=", nav_target != null, " ", nav_name)
	motor_b.open = false
	world.wind_strength = 0.55
	world.wind_target_strength = 0.55
	# 9k) Tohumlar: domates ek, hasat et, tohum geri gelsin; zeytin fidanı hasattan sonra kalsın
	player.inv.from_data([])
	var pfree := Vector2i(-6, 4)
	while raft.has_tile(pfree) or raft.has_tile(pfree + Vector2i(-1, 0)):
		pfree.x -= 1
	raft.add_tile(pfree)
	raft.add_tile(pfree + Vector2i(-1, 0))
	var pot1 = raft.place_building("saksi", pfree)
	var pot2 = raft.place_building("saksi", pfree + Vector2i(-1, 0))
	player.give("domates_tohumu", 1)
	pot1.interact(player)
	pot1.growth = 1.0
	pot1.interact(player)
	var tomato_seeds: int = player.inv.count("domates_tohumu")
	player.inv.remove("domates_tohumu", player.inv.count("domates_tohumu"))
	player.give("zeytin_fidani", 1)
	pot2.interact(player)
	pot2.growth = 1.0
	pot2.interact(player)
	print("TEST tohum: domates=", player.inv.count("domates"), " tohum geri=", tomato_seeds, " zeytin=", player.inv.count("zeytin"),
		" fidan kaldı=", pot2.planted, " fidan bitkisi=", pot2.plant.get_child_count() > 0)
	# 9l) Kedi (F): adada sokak kedisi, sev → sala gelir, balık ver, köpekbalığı uyarısı, hediye, kayıt
	var wild = make_cat(false)
	add_child(wild)
	wild.global_position = raft.center_global() + Vector3(0, 0, 30)
	await t.process_frame
	wild.interact(player)
	var on_raft: bool = wild.get_parent() == raft and cat == wild
	player.inv.from_data([])
	player.inv.slots[0] = {"id": "pismis_balik", "n": 2, "dur": 0}
	player.selected = 0
	wild.hunger = 10.0
	wild.interact(player)
	var fed: bool = wild.hunger >= 99.0 and player.inv.count("pismis_balik") == 1
	player.inv.slots[0] = null
	wild.interact(player)
	var petted: bool = wild.purr_t > 0.0
	shark.state = shark.S.TO_RAFT
	shark.global_position = raft.center_global() + Vector3(10, -1, 0)
	await t.process_frame
	await t.process_frame
	var warned: bool = wild.puff > 0.5
	shark._back_to_circle()
	var kids_before: int = raft.get_child_count()
	wild._gift()
	var gift_ok: bool = raft.get_child_count() > kids_before
	var cname: String = wild.cat_name
	save_game()
	load_game()
	await t.process_frame
	print("TEST kedi: sala geldi=", on_raft, " doydu=", fed, " sevildi=", petted, " uyardı=", warned, " hediye=", gift_ok,
		" kayıtta=", cat != null and is_instance_valid(cat) and cat.cat_name == cname, " (", cname, ")")
	# 9m) Gezgin tüccar (G): yanaşır, takas envanteri değiştirir, söylenti hedef koyar, sonra gider
	var tr = spawn_trader()
	var far_d: float = tr.global_position.distance_to(raft.center_global())
	tr.global_position = tr._dock_global() + tr._dock_world_dir() * 25.0
	for i in 200:
		if tr.state == tr.S.DOCKED:
			break
		await t.create_timer(0.1).timeout
	var docked: bool = tr.state == tr.S.DOCKED
	var gap: float = tr.global_position.distance_to(raft.center_global())
	player.inv.from_data([])
	tr.offers[0] = {"give": {"ham_balik": 3}, "get": {"domates_tohumu": 2}, "stock": 1}
	player.inv.add("ham_balik", 4)
	player.inv.add("pismis_balik", 2)
	var got: String = tr.trade(0)
	var traded: bool = got != "" and player.inv.count("ham_balik") == 1 and player.inv.count("domates_tohumu") == 2
	var again: bool = tr.trade(0) == ""
	nav_target = null
	tr.trade(tr.offers.size() - 1)
	var hinted: bool = nav_target != null
	hud.open_trade(tr)
	await t.process_frame
	var ui_rows: int = hud.trade_ui.rows.get_child_count()
	hud.close_menus()
	tr.stay = 0.0
	for i in 600:
		if not is_instance_valid(tr):
			break
		tr.global_position += tr._dock_world_dir() * 1.0
		await t.process_frame
	print("TEST tüccar: geldi=", docked, " (", int(far_d), " m → ", snappedf(gap, 0.1), " m) takas=", traded, " stok bitti=", again,
		" söylenti hedefi=", hinted, " ekran satırı=", ui_rows, " gitti=", trader == null, " sonraki=", int(trader_t), " sn")
	nav_target = null
	# 9n) Su altı (H): resif ve istiridye, tüp ve palet, derinlik, batık sandık, yem ve diken tuzağı
	var bisl = _make_island("batik", 777, raft.center_global() + Vector3(0, 0, 250), {})
	await t.process_frame
	var reef_n: int = bisl.get_node("Resif").get_child_count()
	var oysters: Array = bisl.find_children("*", "", false, false).filter(func(n): return n.get_script() == preload("res://scripts/oyster.gd"))
	player.inv.from_data([])
	var pearls := 0
	for o in oysters:
		o.interact(player)
	pearls = player.inv.count("inci")
	var oyster_ok: bool = player.inv.count("istiridye") == oysters.size() and oysters.size() > 0
	player.inv.add("oksijen_tupu", 1)
	player.inv.add("palet", 1)
	player.equip("oksijen_tupu")
	player.equip("palet")
	var geared: bool = player.gear["tup"] == "oksijen_tupu" and player.gear["palet"] == "palet" and player.inv.count("palet") == 0
	# Dalış: baş su altında, tüp harcanır, oksijen düşmez; palet hızı artırır
	player.global_position = bisl.global_position + Vector3(0, -6.0, 40.0)
	player.velocity = Vector3.ZERO
	player.oxygen = 100.0
	var depth_before: float = player.max_depth
	await t.create_timer(1.0).timeout
	var tank_used: bool = player.tank_air < 100.0 and player.oxygen >= 99.0
	var deeper: bool = player.max_depth > depth_before
	player.gear["palet"] = ""
	player.unequip("palet")
	var w = bisl.wreck
	var had_wreck: bool = w != null
	player.inv.from_data([])
	if w != null:
		w.interact(player)
	var wreck_loot: bool = player.inv.count("inci") >= 2 and player.inv.count("mercek") == 1
	player.global_position = raft.to_global(Vector3(0.75, 0.5, 0.75))
	player.velocity = Vector3.ZERO
	islands.erase(bisl)
	bisl.queue_free()
	# Yem: köpekbalığı oyalanır
	shark._back_to_circle()
	shark.visible = true
	shark.hp = shark.MAX_HP
	player.inv.add("kopekbaligi_yemi", 1)
	player.rotation.y = 0.0
	player.head.rotation.x = 0.2
	player.throw_bait()
	for i in 80:
		if shark.state == shark.S.DISTRACT:
			break
		await t.create_timer(0.05).timeout
	var distracted: bool = shark.state == shark.S.DISTRACT
	for b in get_children().filter(func(n): return n.get_script() == preload("res://scripts/bait.gd")):
		b.queue_free()
	await t.process_frame
	await t.process_frame
	# Diken tuzağı: ısırmaya gelen köpekbalığı çarpar
	var edge: Array = raft.edge_tiles()
	var tc: Vector2i = edge[0]
	var trap = raft.place_building("diken_tuzagi", tc)
	if trap == null:
		for e in edge:
			if raft.can_place_building(e):
				tc = e
				trap = raft.place_building("diken_tuzagi", e)
				break
	var hp_before: int = shark.hp
	var tile_hp: float = raft.tiles[tc]["hp"]
	shark.target_cell = tc
	shark.state = shark.S.BITE_RAFT
	shark.bite_timer = 0.0
	await t.process_frame
	await t.process_frame
	var trapped: bool = shark.hp < hp_before and raft.has_tile(tc) and raft.tiles[tc]["hp"] >= tile_hp
	shark._back_to_circle()
	shark.hp = shark.MAX_HP
	print("TEST su altı: resif=", reef_n, " istiridye=", oyster_ok, " (", oysters.size(), " açıldı, ", pearls, " inci) takım=", geared,
		" tüp harcandı=", tank_used, " derinlik=", deeper, " (", int(player.max_depth), " m) batık=", had_wreck, " sandık=", wreck_loot,
		" yem=", distracted, " tuzak=", trapped, " tuzak kaldı=", trap != null and is_instance_valid(trap) and trap.stock == 2)
	# 9o) Zorluk: zor modda karo iki ısırıkta kopar, kolayda dört; açlık hızı değişir
	var diff_bites := []
	for d in 3:
		difficulty = d
		var dtile := Vector2i(-9, 9)
		raft.add_tile(dtile)
		var nb := 0
		while raft.has_tile(dtile) and nb < 10:
			raft.bite(dtile)
			nb += 1
		diff_bites.append(nb)
	difficulty = 1
	print("TEST zorluk: kolay/normal/zor karo ısırığı=", diff_bites, " açlık çarpanı=", DIFF[0]["hunger"], "/", DIFF[2]["hunger"])
	# 9p) Hikâye (I): şişe notu, batık sayfası, Hıdırellez görevi → efsanevi ada, kurdele → son, kayıt
	hud.lore.from_data([])
	open_bottle()
	hud.lore.close()
	var first_note: bool = hud.lore.read.has("sise_1")
	var hq := -1
	for i in quests.QUESTS.size():
		if quests.QUESTS[i]["id"] == "hidirellez":
			hq = i
	legend = {}
	quests.current = hq
	quests._start_current()
	var legend_up: bool = not legend.is_empty() and nav_name == "Hıdırellez Adası"
	legend["x"] = raft.center_global().x
	legend["z"] = raft.center_global().z - 200.0
	_stream_legend()
	await t.process_frame
	var wtree = null
	if legend_island != null:
		for c in legend_island.get_children():
			if c.get_script() == preload("res://scripts/wish_tree.gd"):
				wtree = c
	player.inv.add("kurdele", 1)
	var had_tree: bool = wtree != null
	if wtree != null:
		wtree.interact(player)
	var ended: bool = story_done and player.inv.count("kurdele") == 0
	await t.create_timer(1.6).timeout
	var epilogue: bool = hud.lore.panel.visible
	hud.lore.close()
	var end_screen: bool = hud.lore.end_panel.visible
	hud.lore.end_panel.visible = false
	end_finished()
	save_game()
	hud.lore.from_data([])
	story_done = false
	load_game()
	await t.process_frame
	print("TEST hikâye: şişe notu=", first_note, " ada belirdi=", legend_up, " ağaç=", had_tree, " son=", ended, " anlatı=", epilogue,
		" son ekranı=", end_screen, " kayıtta notlar=", hud.lore.read.size(), " son kayıtta=", story_done)
	if legend_island != null and is_instance_valid(legend_island):
		islands.erase(legend_island)
		legend_island.queue_free()
	legend = {}
	nav_target = null
	# 9q) Sonar ve açık deniz batıkları: sonar bulur, ganimet açılır, açılmışlık kayıtta kalır, dalgıç feneri yanar
	wreck_sites = []
	_clear_sites()
	var sc := Vector2i(-9, -9)
	raft.add_tile(sc)
	var sonar_b = raft.place_building("sonar", sc)
	var tsite := {"x": raft.center_global().x + 150.0, "z": raft.center_global().z, "kind": "yuk", "seed": 5, "found": false, "looted": [], "spots": 5}
	wreck_sites.append(tsite)
	sonar_t = 0.0
	await t.process_frame
	await t.process_frame
	var sonar_found: bool = tsite["found"]
	_stream_sites(0.0)
	await t.process_frame
	var wnode = site_nodes.get(0)
	var lspots: Array = []
	if wnode != null:
		lspots = wnode.get_children().filter(func(n): return n.get_script() == preload("res://scripts/loot_spot.gd"))
	player.inv.from_data([])
	if lspots.size() > 0:
		lspots[0].interact(player)
	var looted_items := 0
	for sl in player.inv.slots:
		if sl != null:
			looted_items += int(sl["n"])
	save_game()
	load_game()
	await t.process_frame
	var site_kept: bool = wreck_sites.size() == 1 and (wreck_sites[0]["looted"] as Array).has(0)
	_stream_sites(0.0)
	await t.process_frame
	var reopened = site_nodes.get(0)
	var still_open := false
	if reopened != null:
		for n in reopened.get_children():
			if n.get_script() == preload("res://scripts/loot_spot.gd") and n.index == 0:
				still_open = n.opened
	player.inv.add("dalgic_feneri", 1)
	player.equip("dalgic_feneri")
	print("TEST sonar: buldu=", sonar_found, " saha=", wnode != null, " ganimet noktası=", lspots.size(), " ganimet=", looted_items,
		" kayıtta açık=", site_kept, " yeniden açık=", still_open, " fener kuşanıldı=", player.gear["fener"] == "dalgic_feneri")
	_clear_sites()
	wreck_sites = []
	nav_target = null
	if sonar_b != null:
		raft.remove_building(sc)
	# 9g) Rüzgâr: yelken verimi açıya bağlı, pusula kuzeyi gösterir, fırtınada şimşek
	world.wind_from = 0.0
	world.wind_target_from = 0.0
	world.wind_strength = 1.0
	world.wind_target_strength = 1.0
	world.wind_timer = 999.0
	var e_down: float = raft.sail_efficiency(Vector3(0, 0, 1))
	var e_beam: float = raft.sail_efficiency(Vector3(1, 0, 0))
	var e_up: float = raft.sail_efficiency(Vector3(0, 0, -1))
	player.inv.from_data([])
	player.inv.add("pusula", 1)
	player.selected = 0
	player.rotation.y = 1.3
	await t.create_timer(1.0).timeout
	var needle: Node3D = (player.hand_models["pusula"] as Node3D).find_child("Igne", true, false)
	var nd: Vector3 = -needle.global_transform.basis.z
	var north_ok := Vector2(nd.x, nd.z).normalized().dot(Vector2(0, -1)) > 0.9
	var ctext: String = player._compass_text()
	world.raining = true
	world.rain = 1.0
	world.thunder_timer = 0.0
	await t.process_frame
	await t.process_frame
	print("TEST rüzgâr: ", world.wind_name(), " arkadan=", snappedf(e_down, 0.01), " yandan=", snappedf(e_beam, 0.01), " önden=", snappedf(e_up, 0.01),
		" pusula kuzey=", north_ok, " şimşek=", world.flash > 0.0, " yazı=", ctext.substr(0, 40))
	world.raining = false
	world.rain = 0.0
	# 9f) Balıkçılık: atış, vuruş, mücadele (makul sarma yakalar; hep sarmak misinayı koparır; hiç sarmamak kaçırır)
	player.inv.from_data([])
	player.inv.add("olta", 1)
	player.selected = 0
	fishing.set_process(false)
	var results: Array = []
	for strategy in ["akıllı", "hep sar", "hiç sarma"]:
		var caught := 0
		var snapped := 0
		var lost := 0
		for trial in 6:
			player.inv.slots[0] = {"id": "olta", "n": 1, "dur": 50}
			var fish_before: int = player.inv.count("ham_balik")
			fishing.cast(player, 0.6)
			fishing.global_position = player.global_position + fishing.cast_dir * 10.0
			fishing.start_fight(player)
			var steps := 0
			while fishing.state == fishing.F.FIGHT and steps < 4000:
				var reel: bool = fishing.tension < 0.65 if strategy == "akıllı" else strategy == "hep sar"
				fishing.fight_step(0.05, player, reel)
				steps += 1
			if player.inv.count("ham_balik") > fish_before:
				caught += 1
			elif player.inv.count("olta") > 0 and fishing.state == fishing.F.IDLE and steps < 4000:
				# kopma olta dayanıklılığını 2 düşürür; kaçışta düşmez
				if int(player.inv.slots[0]["dur"]) < 50:
					snapped += 1
				else:
					lost += 1
			fishing.reset()
		results.append("%s: yakaladı %d, koptu %d, kaçtı %d" % [strategy, caught, snapped, lost])
	fishing.set_process(true)
	print("TEST balıkçılık: ", " | ".join(results))
	# 9e) Görevler: adımlar ilerler, ödül verilir, sıradaki görev açılır, başarım ve kayıt
	quests.reset()
	player.inv.from_data([])
	var ip_before: int = player.inv.count("ip")
	var tahta_before: int = player.inv.count("tahta")
	player.give("tahta", 5)
	player.give("plastik", 3)
	var q1_done: bool = quests.current == 1
	var reward_ok: bool = player.inv.count("tahta") >= tahta_before + 5 + 2
	player.give("yaprak", 4)
	for r in Items.RECIPES:
		if r["out"] == "ip":
			for i in 2:
				craft(r)
	var q2_done: bool = quests.current >= 2
	quests.event("build", "zemin")
	var ach_ok: bool = quests.ach_done.has("ilk_karo")
	hud.journal.toggle()
	var book_open: bool = hud.journal.book.visible
	hud.journal.toggle()
	var cur: int = quests.current
	save_game()
	quests.reset()
	load_game()
	print("TEST görev: ilk tamam=", q1_done, " ödül=", reward_ok, " ikinci tamam=", q2_done, " başarım=", ach_ok,
		" defter açıldı=", book_open, " kayıtta görev=", quests.current == cur and quests.ach_done.has("ilk_karo"),
		" etkin=", quests.active().get("title", "-"))
	# Önceden yapılmış iş görevi kilitlememeli: arıtıcı salda, temiz su çantada iken "Tatlı Su" geçmeli
	var ti := 0
	for i in quests.QUESTS.size():
		if quests.QUESTS[i]["id"] == "tatli_su":
			ti = i
	var free := Vector2i(0, 5)
	while raft.has_tile(free):
		free.y += 1
	raft.add_tile(free)
	raft.place_building("aritici", free)
	player.inv.add("temiz_su", 1)
	quests.current = ti
	quests._start_current()
	var tatli_gecti: bool = quests.current > ti
	print("TEST görev önceden yapılan: tatlı su geçti=", tatli_gecti, " şimdi=", quests.active().get("title", "-"))
	# 9) Zemin: normal karo 3 ısırıkta kopar, güçlendirilmiş karo dayanır
	var free_c := Vector2i(0, -1)
	while raft.has_tile(free_c):
		free_c.y -= 1
	raft.add_tile(free_c)
	var bites: Array = []
	for i in 3:
		bites.append(raft.bite(free_c))
	raft.add_tile(free_c)
	raft.reinforce(free_c)
	print("TEST zemin ısırık=", bites, " güçlendirilmiş=", raft.bite(free_c), " kayıtta metal=", raft.to_data()["tiles"].any(func(t): return t[3]))
	print("TEST bitti")
	t.quit()
