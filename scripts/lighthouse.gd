extends StaticBody3D
## Ege adalarındaki eski deniz feneri. Yıkık bulunur; dört adımda onarılır:
## 1) duvarları ör (taş), 2) fener odasını camla (cam), 3) merceği yerleştir, 4) kandili zeytinyağıyla doldurup yak.
## Yanan fener geceleri dönen ışık huzmesiyle denizi tarar, haritada görünür ve çevresinde köpekbalığı salı ısırmaz.

const ToolModels = preload("res://scripts/tool_models.gd")

const STAGES := [
	{"need": {"tas": 10}, "text": "Yıkık duvarları ör"},
	{"need": {"cam": 4}, "text": "Fener odasını camla"},
	{"need": {"mercek": 1}, "text": "Merceği yerleştir"},
	{"need": {"zeytinyagi": 2}, "text": "Kandili zeytinyağıyla doldur ve yak"},
]
const H := 8.0

var main
var island
## main.landmarks içindeki kayıt (kalıcı): {"kind", "x", "z", "seed", "stage", "name"}
var landmark: Dictionary = {}
var visual: Node3D
var beam_pivot: Node3D
var beam_light: SpotLight3D
var lamp: OmniLight3D
var beam_mats: Array = []
var door: StaticBody3D
static var _stone: StandardMaterial3D
static var _white: StandardMaterial3D
static var _iron: StandardMaterial3D
static var _glass: StandardMaterial3D
static var _red: StandardMaterial3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_materials()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.45
	cyl.height = H
	cs.shape = cyl
	cs.position.y = H / 2.0
	add_child(cs)
	# Etkileşim: kapının önü
	door = StaticBody3D.new()
	door.collision_layer = 4
	door.collision_mask = 0
	door.set_meta("target", self)
	var dcs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 2.2, 0.6)
	dcs.shape = box
	dcs.position = Vector3(0, 1.1, 1.45)
	door.add_child(dcs)
	add_child(door)
	_rebuild()


func stage() -> int:
	return int(landmark.get("stage", 0))


func is_lit() -> bool:
	return stage() >= STAGES.size()


static func _materials() -> void:
	if _stone != null:
		return
	var base := "res://assets/textures/damp_beach_sand/damp_beach_sand_"
	_stone = StandardMaterial3D.new()
	_stone.albedo_texture = load(base + "diff_1k.jpg")
	_stone.albedo_color = Color(0.72, 0.7, 0.66)
	_stone.normal_enabled = true
	_stone.normal_texture = load(base + "nor_gl_1k.jpg")
	_stone.normal_scale = 1.5
	_stone.uv1_triplanar = true
	_stone.uv1_scale = Vector3(1.2, 1.2, 1.2)
	_stone.roughness = 0.95
	# Ege fenerleri: kireç badanalı beyaz gövde
	_white = _stone.duplicate()
	_white.albedo_color = Color(0.95, 0.94, 0.9)
	_iron = StandardMaterial3D.new()
	_iron.albedo_color = Color(0.18, 0.19, 0.2)
	_iron.metallic = 0.8
	_iron.roughness = 0.45
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(0.75, 0.88, 0.95, 0.25)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.roughness = 0.05
	_glass.metallic_specular = 1.0
	_red = StandardMaterial3D.new()
	_red.albedo_color = Color(0.62, 0.12, 0.1)
	_red.roughness = 0.6


func _mi(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	return ToolModels._mi(parent, mesh, m, pos, rot)


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


## Aşamaya göre görünümü yeniden kurar.
func _rebuild() -> void:
	if visual != null:
		visual.queue_free()
	beam_mats.clear()
	beam_pivot = null
	beam_light = null
	lamp = null
	visual = Node3D.new()
	add_child(visual)
	var st := stage()
	# Taş kaide
	for i in 14:
		var a := TAU * i / 14.0
		_mi(visual, _box(Vector3(0.75, 0.35, 0.5)), _stone, Vector3(cos(a) * 2.0, 0.17, sin(a) * 2.0), Vector3(0, -a, 0))
	_mi(visual, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(2.1, 0.0), Vector2(2.1, 0.3), Vector2(0.0, 0.3)], 28), _stone)
	if st == 0:
		# Yıkık gövde: yarıda kırılmış, üstü dişli; çevrede düşmüş taşlar
		var h := 4.6
		_mi(visual, ToolModels.lathe([Vector2(0.0, 0.3), Vector2(1.4, 0.3), Vector2(1.25, h), Vector2(0.0, h)], 24), _stone)
		for i in 9:
			var a := TAU * i / 9.0
			var hh := randf_range(0.2, 0.9)
			_mi(visual, _box(Vector3(0.5, hh, 0.35)), _stone, Vector3(cos(a) * 1.15, h + hh / 2.0, sin(a) * 1.15), Vector3(0, -a, 0))
		for i in 8:
			var a := randf() * TAU
			var r := randf_range(2.4, 4.0)
			_mi(visual, _box(Vector3(0.45, 0.3, 0.35)), _stone, Vector3(cos(a) * r, 0.15, sin(a) * r), Vector3(randf(), randf() * TAU, randf()))
	else:
		# Badanalı tam gövde, kırmızı kuşak, balkon ve korkuluk
		_mi(visual, ToolModels.lathe([Vector2(0.0, 0.3), Vector2(1.4, 0.3), Vector2(1.0, H), Vector2(0.0, H)], 28), _white)
		_mi(visual, ToolModels.lathe([Vector2(1.31, 3.4), Vector2(1.33, 3.4), Vector2(1.29, 4.0), Vector2(1.27, 4.0)], 28), _red)
		_mi(visual, ToolModels.lathe([Vector2(0.0, H), Vector2(1.45, H), Vector2(1.45, H + 0.15), Vector2(0.0, H + 0.15)], 28), _stone)
		for i in 16:
			var a := TAU * i / 16.0
			_mi(visual, ToolModels.tube([Vector3(cos(a) * 1.38, H + 0.15, sin(a) * 1.38), Vector3(cos(a) * 1.38, H + 0.85, sin(a) * 1.38)], 0.02, 6), _iron)
		var rail := TorusMesh.new()
		rail.inner_radius = 1.36
		rail.outer_radius = 1.4
		rail.rings = 32
		_mi(visual, rail, _iron, Vector3(0, H + 0.85, 0))
	# Kapı ve pencereler
	_mi(visual, _box(Vector3(0.8, 1.7, 0.2)), _iron, Vector3(0, 1.15, 1.36))
	for y in [2.6, 5.2]:
		if st == 0 and y > 4.0:
			continue
		_mi(visual, _box(Vector3(0.35, 0.6, 0.2)), _iron, Vector3(0, y, 1.3 - (y - 0.3) * 0.05), Vector3(-0.05, 0, 0))
	if st >= 2:
		# Camlı fener odası, demir çerçeve, kırmızı kubbe
		_mi(visual, ToolModels.lathe([Vector2(0.0, H + 0.15), Vector2(0.8, H + 0.15), Vector2(0.8, H + 1.45), Vector2(0.0, H + 1.45)], 20), _glass)
		for i in 8:
			var a := TAU * i / 8.0
			_mi(visual, ToolModels.tube([Vector3(cos(a) * 0.81, H + 0.15, sin(a) * 0.81), Vector3(cos(a) * 0.81, H + 1.45, sin(a) * 0.81)], 0.03, 6), _iron)
		_mi(visual, ToolModels.lathe([Vector2(0.0, H + 1.45), Vector2(0.9, H + 1.45), Vector2(0.75, H + 1.75), Vector2(0.35, H + 2.0), Vector2(0.06, H + 2.15), Vector2(0.0, H + 2.4)], 20), _red)
	if st >= 3:
		# Mercek: yaldızlı halkalar içinde cam küre
		var lens := StandardMaterial3D.new()
		lens.albedo_color = Color(0.95, 0.9, 0.7, 0.55)
		lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		lens.emission_enabled = true
		lens.emission = Color(1.0, 0.85, 0.5)
		lens.emission_energy_multiplier = 0.0
		var sm := SphereMesh.new()
		sm.radial_segments = 20
		sm.rings = 10
		sm.radius = 0.4
		sm.height = 0.8
		_mi(visual, sm, lens, Vector3(0, H + 0.8, 0))
		beam_mats.append(lens)
		var brass := StandardMaterial3D.new()
		brass.albedo_color = Color(0.8, 0.62, 0.3)
		brass.metallic = 0.9
		brass.roughness = 0.3
		for k in 3:
			var ring := TorusMesh.new()
			ring.rings = 24
			ring.ring_segments = 10
			ring.inner_radius = 0.38
			ring.outer_radius = 0.43
			_mi(visual, ring, brass, Vector3(0, H + 0.5 + k * 0.3, 0))
	if st >= 4:
		lamp = OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.85, 0.6)
		lamp.omni_range = 18.0
		lamp.light_energy = 0.0
		lamp.position.y = H + 0.8
		visual.add_child(lamp)
		# Dönen huzme: iki karşılıklı ışık konisi + spot ışık
		beam_pivot = Node3D.new()
		beam_pivot.position.y = H + 0.8
		visual.add_child(beam_pivot)
		for s in [1.0, -1.0]:
			var cone := CylinderMesh.new()
			# Dar uç fenerde, geniş uç uzakta (silindirin üstü dönüşle uzağa bakar)
			cone.top_radius = 4.5
			cone.bottom_radius = 0.25
			cone.height = 60.0
			cone.cap_top = false
			cone.cap_bottom = false
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.albedo_color = Color(1.0, 0.88, 0.6, 0.0)
			m.albedo_texture = _beam_gradient()
			var mi := _mi(beam_pivot, cone, m, Vector3(0, 0, s * 30.0), Vector3(s * PI / 2.0, 0, 0))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			beam_mats.append(m)
		beam_light = SpotLight3D.new()
		beam_light.light_color = Color(1.0, 0.88, 0.6)
		beam_light.spot_range = 120.0
		beam_light.spot_angle = 8.0
		beam_light.light_energy = 0.0
		beam_pivot.add_child(beam_light)


## Huzme konisi: uca doğru solan doku.
static func _beam_gradient() -> GradientTexture2D:
	var g := Gradient.new()
	# Fenere yakın uç (v=1) parlak, uzak uç (v=0) sönük
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 1.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 8
	t.height = 64
	return t


func prompt(player) -> String:
	if is_lit():
		return "%s  ·  yanıyor" % landmark.get("name", "Fener")
	var s: Dictionary = STAGES[stage()]
	var parts: Array = []
	var ok := true
	for k in s["need"]:
		var have: int = player.inv.count(k)
		parts.append("%d/%d %s" % [mini(have, s["need"][k]), s["need"][k], main.quests.Items.name_of(k)])
		if have < s["need"][k]:
			ok = false
	return "%s  ·  %d/%d: %s (%s)%s" % [landmark.get("name", "Fener"), stage() + 1, STAGES.size(), s["text"], ", ".join(parts), "  ·  E: yap" if ok else ""]


func interact(player) -> void:
	if is_lit():
		return
	var s: Dictionary = STAGES[stage()]
	if not player.inv.spend(s["need"]):
		main.hud.toast("Malzeme eksik: " + main.quests.Items.cost_text(s["need"]), 3.0)
		return
	landmark["stage"] = stage() + 1
	main.audio.play("build", 0.0)
	_rebuild()
	if is_lit():
		main.quests.event("repair_lighthouse")
		main.audio.play("chest_open", -2.0)
		main.hud.toast("%s yeniden yandı! Geceleri yolunu gösterecek; çevresinde köpekbalığı salına saldırmaz." % landmark.get("name", "Fener"), 6.0)
	else:
		main.hud.notify("Fener onarımı: %d/%d" % [stage(), STAGES.size()], Color(1.0, 0.85, 0.4))


func _process(delta: float) -> void:
	if beam_pivot == null or main.paused:
		return
	var on: bool = main.world.is_night() or main.world.rain > 0.5 or main.world.hour < 6.5 or main.world.hour > 19.5
	beam_pivot.rotation.y += delta * 0.9
	var k := 1.0 if on else 0.0
	for m in beam_mats:
		var sm := m as StandardMaterial3D
		if sm.emission_enabled:
			sm.emission_energy_multiplier = lerpf(sm.emission_energy_multiplier, 4.0 * k, delta * 2.0)
		else:
			sm.albedo_color.a = lerpf(sm.albedo_color.a, 0.09 * k, delta * 2.0)
	if lamp != null:
		lamp.light_energy = lerpf(lamp.light_energy, 2.5 * k, delta * 2.0)
	if beam_light != null:
		beam_light.light_energy = lerpf(beam_light.light_energy, 6.0 * k, delta * 2.0)
