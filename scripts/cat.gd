extends StaticBody3D
## Salda yaşayan kedi yoldaş (koddan model). Önce bir adada ıslak bir sokak kedisi olarak bulunur;
## E ile sevilince sala gelir ve bir ad alır. Salda dolaşır, oturur, güneşlenir, gece uyur (varsa kendi yatağında).
## Sevilir, balık verilince yer; tok ve mutluyken hediye getirir. Köpekbalığı sala yönelince tüyleri kabarır, tıslar.

enum S { WALK, SIT, SLEEP, EAT }

const NAMES := ["Tarçın", "Pamuk", "Duman", "Minnoş", "Boncuk", "Zeytin", "Lokum", "Fıstık", "Karamel", "Paşa"]
const COATS := {
	"tekir": [Color(0.86, 0.52, 0.22), Color(0.62, 0.32, 0.12), Color(0.95, 0.85, 0.7)],
	"duman": [Color(0.55, 0.56, 0.58), Color(0.38, 0.39, 0.41), Color(0.82, 0.82, 0.84)],
	"pamuk": [Color(0.95, 0.94, 0.9), Color(0.85, 0.82, 0.76), Color(0.98, 0.97, 0.95)],
	"kara": [Color(0.12, 0.11, 0.11), Color(0.08, 0.08, 0.08), Color(0.95, 0.94, 0.9)],
}
const FEEDS := ["pismis_balik", "ham_balik", "pismis_yengec", "yengec_eti"]

var main
## true: salın yoldaşı; false: adada bekleyen sokak kedisi
var adopted := false
var island
var cat_name := "Tarçın"
var coat := "tekir"
var hunger := 70.0
var affection := 20.0

var state := S.SIT
var state_t := 3.0
var target := Vector3.ZERO
var walk_t := 0.0
var meow_t := 20.0
var gift_t := 240.0
var purr_t := 0.0
var puff := 0.0
var warned_attack := false

var body: Node3D
var head: Node3D
var tail: Array = []
var legs: Array = []
var purr: AudioStreamPlayer3D
var hearts: GPUParticles3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	set_meta("target", self)
	_build()
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.3
	cs.shape = sh
	cs.position.y = 0.2
	add_child(cs)
	purr = main.audio.loop_player("purr", self, -10.0)
	purr.unit_size = 2.0
	hearts = _hearts()
	add_child(hearts)


# --- Model ------------------------------------------------------------------------

func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _fur(base: Color, stripe: Color) -> StandardMaterial3D:
	# Tekir çizgileri: yanlara doğru dalgalı koyu bantlar
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var w := sin(x * 0.45 + sin(y * 0.2) * 1.5)
			img.set_pixel(x, y, stripe if (coat == "tekir" or coat == "duman") and w > 0.55 else base)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(3, 3, 3)
	m.roughness = 0.95
	return m


func _mesh(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = sc
	parent.add_child(mi)
	return mi


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s


func _build() -> void:
	var c: Array = COATS[coat]
	var fur := _fur(c[0], c[1])
	var light := _mat(c[2])
	body = Node3D.new()
	add_child(body)
	# Gövde: uzun yumuşak kapsül; göğüs açık renk
	var cap := CapsuleMesh.new()
	cap.radius = 0.085
	cap.height = 0.36
	_mesh(body, cap, fur, Vector3(0, 0.17, 0), Vector3(PI / 2.0, 0, 0))
	_mesh(body, _sphere(0.07), light, Vector3(0, 0.15, 0.12), Vector3.ZERO, Vector3(1.0, 0.9, 0.8))
	# Bacaklar (önde +Z)
	for p in [Vector3(-0.05, 0.0, 0.11), Vector3(0.05, 0.0, 0.11), Vector3(-0.055, 0.0, -0.11), Vector3(0.055, 0.0, -0.11)]:
		var hip := Node3D.new()
		hip.position = p + Vector3(0, 0.13, 0)
		body.add_child(hip)
		var leg := CylinderMesh.new()
		leg.top_radius = 0.02
		leg.bottom_radius = 0.016
		leg.height = 0.13
		_mesh(hip, leg, fur, Vector3(0, -0.065, 0))
		_mesh(hip, _sphere(0.02), light, Vector3(0, -0.13, 0.008), Vector3.ZERO, Vector3(1.0, 0.6, 1.3))
		legs.append(hip)
	# Baş
	head = Node3D.new()
	head.position = Vector3(0, 0.27, 0.2)
	body.add_child(head)
	_mesh(head, _sphere(0.075), fur, Vector3.ZERO, Vector3.ZERO, Vector3(1.05, 0.92, 0.95))
	_mesh(head, _sphere(0.035), light, Vector3(0, -0.02, 0.055), Vector3.ZERO, Vector3(1.2, 0.8, 0.8))
	_mesh(head, _sphere(0.009), _mat(Color(0.9, 0.5, 0.55), 0.6), Vector3(0, -0.005, 0.083))
	var eye_col := Color(0.55, 0.75, 0.25) if coat != "pamuk" else Color(0.35, 0.6, 0.9)
	for sx in [-1.0, 1.0]:
		_mesh(head, _sphere(0.014), _mat(eye_col, 0.2), Vector3(sx * 0.028, 0.018, 0.062))
		_mesh(head, _sphere(0.006), _mat(Color(0.02, 0.02, 0.02), 0.2), Vector3(sx * 0.028, 0.018, 0.074), Vector3.ZERO, Vector3(0.45, 1.3, 0.5))
		var ear := PrismMesh.new()
		ear.size = Vector3(0.05, 0.06, 0.018)
		_mesh(head, ear, fur, Vector3(sx * 0.04, 0.072, -0.005), Vector3(0, 0, sx * -0.25))
		_mesh(head, ear, _mat(Color(0.85, 0.6, 0.6)), Vector3(sx * 0.04, 0.068, 0.004), Vector3(0, 0, sx * -0.25), Vector3(0.6, 0.6, 0.5))
		# Bıyıklar
		for k in 2:
			var wh := CylinderMesh.new()
			wh.top_radius = 0.0012
			wh.bottom_radius = 0.0012
			wh.height = 0.08
			_mesh(head, wh, _mat(Color(0.95, 0.95, 0.95)), Vector3(sx * 0.05, -0.02 + k * 0.01, 0.06), Vector3(0, 0, PI / 2.0 + sx * (0.1 - k * 0.15)))
	# Kuyruk: zincirleme parçalar (dalgalanır)
	var parent: Node3D = body
	var pos := Vector3(0, 0.2, -0.2)
	for i in 7:
		var seg := Node3D.new()
		seg.position = pos
		parent.add_child(seg)
		var tc := CylinderMesh.new()
		tc.top_radius = 0.018 - i * 0.0012
		tc.bottom_radius = 0.019 - i * 0.0012
		tc.height = 0.05
		_mesh(seg, tc, fur if i < 6 else (light if coat == "kara" else fur), Vector3(0, 0.025, 0))
		tail.append(seg)
		parent = seg
		pos = Vector3(0, 0.048, 0)
	tail[0].rotation.x = -0.9


func _hearts() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 6
	p.lifetime = 1.4
	p.emitting = false
	p.position = Vector3(0, 0.45, 0.1)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.4
	pm.gravity = Vector3.ZERO
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Kalp dokusu
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var u := (x - 16.0) / 13.0
			var v := (16.0 - y) / 13.0 + 0.25
			var inside := pow(u * u + v * v - 1.0, 3.0) - u * u * v * v * v < 0.0
			img.set_pixel(x, y, Color(0.95, 0.3, 0.4, 1.0) if inside else Color(0, 0, 0, 0))
	m.albedo_texture = ImageTexture.create_from_image(img)
	q.material = m
	p.draw_pass_1 = q
	return p


# --- Etkileşim ----------------------------------------------------------------------

func prompt(player) -> String:
	if not adopted:
		return "E: Islak kediyi sev (sala gelsin)"
	if FEEDS.has(player.held_id()):
		return "E: %s'a %s ver  ·  tokluk %%%d" % [cat_name, main.quests.Items.name_of(player.held_id()), int(hunger)]
	return "E: %s'ı sev  ·  tokluk %%%d · sevgi %%%d" % [cat_name, int(hunger), int(affection)]


func interact(player) -> void:
	if not adopted:
		main.adopt_cat(self)
		return
	var held: String = player.held_id()
	if FEEDS.has(held):
		player.inv.take_slot(player.selected, 1)
		hunger = 100.0
		affection = minf(100.0, affection + 8.0)
		state = S.EAT
		state_t = 2.5
		main.audio.play_at("cat_eat", global_position, 0.0, 3.0)
		main.quests.event("feed_cat")
		return
	affection = minf(100.0, affection + 4.0)
	purr_t = 4.0
	hearts.restart()
	hearts.emitting = true
	if state == S.WALK:
		state = S.SIT
		state_t = 4.0
	_face(player.global_position)
	main.audio.play_at("mewpurr", global_position, -2.0, 3.0)
	main.quests.event("pet_cat")


func _face(world_pos: Vector3) -> void:
	var d: Vector3 = (get_parent() as Node3D).to_local(world_pos) - position
	rotation.y = atan2(d.x, d.z)


# --- Davranış ----------------------------------------------------------------------------

func _raft_spot() -> Vector3:
	var raft = main.raft
	var cells: Array = []
	for c in raft.tiles:
		if not raft.buildings.has(c):
			cells.append(c)
	if cells.is_empty():
		cells = raft.tiles.keys()
	var c: Vector2i = cells.pick_random()
	return raft.cell_pos(c) + Vector3(randf_range(-0.5, 0.5), raft.top_y(), randf_range(-0.5, 0.5))


func _bed_spot():
	for c in main.raft.buildings:
		if main.raft.buildings[c].kind == "kedi_yatagi":
			return main.raft.cell_pos(c) + Vector3(0, main.raft.top_y() + 0.08, 0)
	return null


func _choose() -> void:
	var night: bool = main.world.is_night()
	var bed = _bed_spot()
	if night and randf() < 0.75:
		if bed != null and position.distance_to(bed) > 0.3:
			target = bed
			state = S.WALK
		else:
			state = S.SLEEP
			state_t = randf_range(30.0, 70.0)
		return
	var p = main.player
	var near_player: bool = not p.in_water and p.global_position.distance_to(global_position) < 6.0
	var r := randf()
	if near_player and r < 0.3:
		# Oyuncunun yanına gel
		var pl: Vector3 = main.raft.to_local(p.global_position)
		target = Vector3(pl.x, main.raft.top_y(), pl.z) + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
		state = S.WALK
	elif r < 0.65:
		target = _raft_spot()
		state = S.WALK
	elif r < 0.85:
		state = S.SIT
		state_t = randf_range(4.0, 10.0)
	else:
		# Güneşlenme / şekerleme
		state = S.SLEEP
		state_t = randf_range(10.0, 25.0)


func _process(delta: float) -> void:
	if main.paused:
		return
	walk_t += delta
	# Kuyruk dalgalanması
	var sway := sin(walk_t * (3.0 if state == S.WALK else 1.4)) * (0.25 if state != S.SLEEP else 0.05)
	for i in tail.size():
		(tail[i] as Node3D).rotation.z = sway * (0.4 + i * 0.12)
		if i > 0:
			(tail[i] as Node3D).rotation.x = (0.18 if state != S.SLEEP else 0.5) + puff * 0.15
	tail[0].rotation.x = lerpf(tail[0].rotation.x, -0.2 - puff * 0.9 if state != S.SLEEP else 1.3, delta * 4.0)
	# Tüy kabarması (köpekbalığı uyarısı)
	puff = maxf(0.0, puff - delta * 0.4)
	body.scale = Vector3.ONE * (1.0 + puff * 0.18)
	if purr_t > 0.0:
		purr_t -= delta
		if not purr.playing:
			purr.play()
	elif purr.playing and state != S.SLEEP:
		purr.stop()
	if not adopted:
		_wild(delta)
		return
	_shark_watch()
	hunger = maxf(0.0, hunger - delta * 100.0 / 1200.0)
	meow_t -= delta
	if meow_t <= 0.0:
		meow_t = randf_range(45.0, 110.0) * (0.5 if hunger < 30.0 else 1.0)
		if state != S.SLEEP:
			main.audio.play_at("meow", global_position, -6.0, 4.0)
	gift_t -= delta
	if gift_t <= 0.0:
		gift_t = randf_range(200.0, 340.0)
		if hunger > 50.0 and affection > 30.0:
			_gift()
	match state:
		S.WALK:
			var to := target - position
			to.y = 0.0
			if to.length() < 0.08:
				state = S.SIT
				state_t = randf_range(2.0, 5.0)
				if _bed_spot() != null and position.distance_to(_bed_spot()) < 0.3 and main.world.is_night():
					state = S.SLEEP
					state_t = 60.0
			else:
				var step := to.normalized() * minf(to.length(), 0.55 * delta)
				position += step
				position.y = main.raft.top_y() if _bed_spot() == null or position.distance_to(_bed_spot()) > 0.4 else _bed_spot().y
				rotation.y = lerp_angle(rotation.y, atan2(step.x, step.z), minf(1.0, delta * 8.0))
		_:
			state_t -= delta
			if state_t <= 0.0:
				_choose()
	_pose(delta)


## Adada bekleyen sokak kedisi: yerinde oturur, ara sıra miyavlar.
func _wild(delta: float) -> void:
	state = S.SIT
	meow_t -= delta
	if meow_t <= 0.0:
		meow_t = randf_range(6.0, 12.0)
		if main.player.global_position.distance_to(global_position) < 25.0:
			main.audio.play_at("meow", global_position, -2.0, 6.0)
	_pose(delta)


func _pose(delta: float) -> void:
	var k := minf(1.0, delta * 6.0)
	match state:
		S.WALK:
			for i in legs.size():
				(legs[i] as Node3D).rotation.x = sin(walk_t * 12.0 + (PI if i % 2 == 0 else 0.0) + (PI / 2.0 if i > 1 else 0.0)) * 0.5
			body.rotation.x = lerpf(body.rotation.x, 0.0, k)
			body.position.y = lerpf(body.position.y, 0.0, k)
			head.rotation.x = lerpf(head.rotation.x, 0.0, k)
		S.SIT:
			# Oturuş: gövde arkaya yaslanır, ön ayaklar dik
			body.rotation.x = lerpf(body.rotation.x, -0.55, k)
			body.position.y = lerpf(body.position.y, 0.04, k)
			head.rotation.x = lerpf(head.rotation.x, 0.45, k)
			for i in legs.size():
				(legs[i] as Node3D).rotation.x = lerpf((legs[i] as Node3D).rotation.x, 0.55 if i < 2 else -1.2, k)
		S.SLEEP:
			# Kıvrılmış uyku: alçalır, baş öne düşer
			body.rotation.x = lerpf(body.rotation.x, 0.0, k)
			body.position.y = lerpf(body.position.y, -0.1, k)
			head.rotation.x = lerpf(head.rotation.x, 0.6, k)
			for l in legs:
				(l as Node3D).rotation.x = lerpf((l as Node3D).rotation.x, 1.45, k)
		S.EAT:
			body.rotation.x = lerpf(body.rotation.x, 0.25, k)
			head.rotation.x = lerpf(head.rotation.x, 0.9 + sin(walk_t * 14.0) * 0.08, k)
			body.position.y = lerpf(body.position.y, 0.0, k)


## Köpekbalığı sala yönelince bir kez uyarır: tüyler kabarır, tıslar.
func _shark_watch() -> void:
	var sh = main.shark
	var attacking: bool = sh.state == sh.S.TO_RAFT and sh.global_position.distance_to(main.raft.center_global()) < 35.0
	if attacking and not warned_attack:
		warned_attack = true
		puff = 1.0
		state = S.SIT
		state_t = 4.0
		_face(sh.global_position)
		main.audio.play_at("hiss", global_position, 2.0, 5.0)
		main.hud.toast("%s tıslıyor: köpekbalığı sala geliyor!" % cat_name, 4.0)
		main.quests.event("cat_warn")
	elif not attacking and sh.state != sh.S.BITE_RAFT:
		warned_attack = false


## Hediye: oyuncunun yakınına ağzında balık (ya da yengeç, hurda) bırakır.
func _gift() -> void:
	var item: String = ["ham_balik", "ham_balik", "yengec_eti", "hurda", "ip"].pick_random()
	var p = load("res://scripts/pickup.gd").new()
	p.main = main
	p.item = item
	p.amount = 1
	main.raft.add_child(p)
	p.position = position + Vector3(0, 0.0, 0.3).rotated(Vector3.UP, rotation.y)
	var vis := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radial_segments = 20
	sm.rings = 10
	sm.radius = 0.08
	sm.height = 0.12
	vis.mesh = sm
	vis.material_override = _mat(main.quests.Items.info(item)["color"])
	vis.position.y = 0.05
	p.add_child(vis)
	main.audio.play_at("meow", global_position, 0.0, 4.0)
	main.hud.toast("%s sana bir hediye getirdi: %s" % [cat_name, main.quests.Items.name_of(item)], 4.0)


func to_data() -> Dictionary:
	return {"name": cat_name, "coat": coat, "hunger": hunger, "affection": affection, "pos": [position.x, position.z]}


func from_data(d: Dictionary) -> void:
	cat_name = d.get("name", cat_name)
	hunger = float(d.get("hunger", 70.0))
	affection = float(d.get("affection", 20.0))
