extends StaticBody3D
## Adadaki palmiye: koddan üretilir (kıvrık, halkalı gövde; tüylü yapraklar; hindistan cevizleri).
## Baltayla 3 vuruşta kesilir. Her vuruşta talaş saçılır, tepe sallanır, bazen hindistan cevizi düşer.
## Son vuruşta gövde kesikten kırılıp oyuncunun tersine devrilir; yere çarpınca toz kalkar,
## gövde kütüklere ayrılır (E ile toplanır). Geride gövdenin alt kısmı kütük olarak kalır.

const ToolModels = preload("res://scripts/tool_models.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const CUT_Y := 0.4
const SEGS := 14

var main
var island
var hp := 3
var falling := false
var height := 5.5
var bend := 0.8
## Kesik üstündeki her şey (gövde + taç) bu düğümde; devrilme ve sallanma bunun etrafında.
var upper: Node3D
var crown: Node3D
var coconuts: Array = []
var sway := 0.0
var sway_vel := 0.0
var sway_axis := Vector3.RIGHT

static var _frond_tex: Texture2D
static var _bark: StandardMaterial3D
static var _ring: StandardMaterial3D
static var _cut: StandardMaterial3D
static var _nut: StandardMaterial3D


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	set_meta("target", self)
	_materials()
	height = randf_range(4.6, 6.2)
	bend = randf_range(0.4, 1.2)
	_build()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3
	cyl.height = 2.6
	cs.shape = cyl
	cs.position.y = 1.3
	add_child(cs)


# --- Model --------------------------------------------------------------------

static func _materials() -> void:
	if _bark != null:
		return
	_bark = StandardMaterial3D.new()
	_bark.albedo_texture = load("res://assets/textures/rough_wood/rough_wood_diff_1k.jpg")
	_bark.albedo_color = Color(0.72, 0.62, 0.5)
	_bark.normal_enabled = true
	_bark.normal_texture = load("res://assets/textures/rough_wood/rough_wood_nor_gl_1k.jpg")
	_bark.uv1_triplanar = true
	_bark.uv1_scale = Vector3(2.0, 2.0, 2.0)
	_bark.roughness = 0.95
	_ring = StandardMaterial3D.new()
	_ring.albedo_color = Color(0.32, 0.26, 0.2)
	_ring.roughness = 1.0
	_cut = StandardMaterial3D.new()
	_cut.albedo_color = Color(0.9, 0.8, 0.6)
	_cut.roughness = 0.9
	_nut = StandardMaterial3D.new()
	_nut.albedo_color = Color(0.36, 0.42, 0.16)
	_nut.roughness = 0.7
	# Palmiye yaprağı dokusu: ortada damar, iki yana dizilmiş ince yaprakçıklar (arası saydam).
	var img := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		var v := (y / 127.0) * 2.0 - 1.0
		for x in 256:
			var u := x / 255.0
			var a := 0.0
			if absf(v) < 0.035:
				a = 1.0
			else:
				var k := fposmod(u * 34.0 - absf(v) * 2.6, 1.0)
				a = 1.0 if k < 0.58 else 0.0
			var g := lerpf(0.34, 0.5, absf(v)) + 0.05 * sin(u * 40.0)
			var col := Color(0.18 + 0.1 * absf(v), g, 0.1, a)
			if absf(v) < 0.035:
				col = Color(0.42, 0.45, 0.22, 1.0)
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	_frond_tex = ImageTexture.create_from_image(img)


func _trunk_point(t: float) -> Vector3:
	return Vector3(bend * t * t, height * t, 0.0)


func _trunk_radius(t: float) -> float:
	return 0.15 + 0.1 * exp(-t * 10.0) - 0.03 * t


func _build() -> void:
	var tc := CUT_Y / height
	var ts: Array = [0.0, tc * 0.5, tc]
	for i in range(1, SEGS + 1):
		ts.append(lerpf(tc, 1.0, float(i) / SEGS))
	var cut_p := _trunk_point(tc)
	upper = Node3D.new()
	upper.position = cut_p
	add_child(upper)
	for i in ts.size() - 1:
		var t0: float = ts[i]
		var t1: float = ts[i + 1]
		var lower := t1 <= tc + 0.0001
		var parent: Node3D = self if lower else upper
		var off := Vector3.ZERO if lower else cut_p
		var r0 := _trunk_radius(t0)
		var r1 := _trunk_radius(t1)
		ToolModels._mi(parent, ToolModels.tube([_trunk_point(t0) - off, _trunk_point(t1) - off], r0, 12, r1 / r0), _bark)
	# Gövde halkaları (palmiyenin yaprak izleri)
	var y := 0.55
	while y < height - 0.2:
		var t := y / height
		var ring := TorusMesh.new()
		ring.inner_radius = _trunk_radius(t) * 0.92
		ring.outer_radius = _trunk_radius(t) * 1.12
		ring.rings = 14
		ring.ring_segments = 6
		var mi := ToolModels._mi(upper, ring, _ring, _trunk_point(t) - cut_p)
		mi.scale = Vector3(1, 0.45, 1)
		y += randf_range(0.16, 0.24)
	# Taç
	var top := _trunk_point(1.0) - cut_p
	crown = Node3D.new()
	crown.position = top
	upper.add_child(crown)
	var knob := SphereMesh.new()
	knob.radial_segments = 20
	knob.rings = 10
	knob.radius = 0.2
	knob.height = 0.34
	ToolModels._mi(crown, knob, _ring)
	var n := 11
	for i in n:
		var ang := TAU * i / n + randf_range(-0.15, 0.15)
		var dead := i % 5 == 4
		_frond(ang, randf_range(2.1, 2.8) * (0.8 if dead else 1.0), dead)
	for i in randi_range(3, 5):
		var a := TAU * i / 4.0 + randf() * 0.5
		var nm := SphereMesh.new()
		nm.radial_segments = 20
		nm.rings = 10
		nm.radius = 0.11
		nm.height = 0.2
		var c := ToolModels._mi(crown, nm, _nut, Vector3(cos(a) * 0.2, -0.22 - randf() * 0.08, sin(a) * 0.2))
		coconuts.append(c)


## Tek palmiye yaprağı: dışa doğru kavislenip sarkan, V biçiminde yaprakçık şeridi.
func _frond(ang: float, length: float, dead: bool) -> void:
	var k1 := randf_range(0.45, 0.8)
	var k2 := randf_range(0.9, 1.3) + (0.9 if dead else 0.0)
	var mi := frond(length, k1, k2, dead)
	mi.rotation.y = -ang
	crown.add_child(mi)
	# Yaprak sapı
	var out := Vector3(cos(ang), 0, sin(ang))
	ToolModels._mi(crown, ToolModels.tube([Vector3.ZERO, out * length * 0.25 + Vector3.UP * length * (k1 * 0.25 - k2 * 0.0625)], 0.025, 6, 0.6), _ring)


## Tek palmiye yaprağı (+X yönünde uzanır): orta damar boyunca V biçiminde yaprakçık şeridi.
## k1 yukarı kalkışı, k2 sarkmayı belirler (yerde yatan yaprak için ikisi de küçük).
static func frond(length: float, k1: float, k2: float, dead := false) -> MeshInstance3D:
	_materials()
	var out := Vector3.RIGHT
	var side := out.cross(Vector3.UP).normalized()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 16
	var prev: Array = []
	for i in steps + 1:
		var s := float(i) / steps
		var p := out * length * s + Vector3.UP * length * (k1 * s - k2 * s * s)
		var w := 0.42 * (length / 2.4) * pow(sin(PI * minf(1.0, s * 1.08)), 0.7) * (1.0 - 0.35 * s)
		var droop := Vector3.DOWN * w * 0.45
		var cur := [p - side * w + droop, p, p + side * w + droop]
		if i > 0:
			for q in [[0, 1], [1, 2]]:
				var a0: Vector3 = prev[q[0]]
				var a1: Vector3 = prev[q[1]]
				var b0: Vector3 = cur[q[0]]
				var b1: Vector3 = cur[q[1]]
				var v0 := 0.0 if q[0] == 0 else 0.5
				var v1 := 0.5 if q[0] == 0 else 1.0
				var s0 := float(i - 1) / steps
				for vv in [[a0, s0, v0], [b0, s, v0], [b1, s, v1], [a0, s0, v0], [b1, s, v1], [a1, s0, v1]]:
					st.set_normal(Vector3.UP)
					st.set_uv(Vector2(vv[1], vv[2]))
					st.add_vertex(vv[0])
		prev = cur
	var m := StandardMaterial3D.new()
	m.albedo_texture = _frond_tex
	m.albedo_color = Color(0.75, 0.6, 0.35) if dead else Color(0.95, 1.0, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.8
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	return mi


## Yerde ya da suda yatan palmiye yaprağı demeti (toplanabilir yaprak, enkaz ve ikon için).
## Ortası düğümün merkezindedir.
static func frond_bundle(count: int, length: float) -> Node3D:
	_materials()
	var root := Node3D.new()
	for i in count:
		var f := frond(length * randf_range(0.85, 1.0), 0.12, 0.18)
		var holder := Node3D.new()
		holder.rotation.y = (i - (count - 1) / 2.0) * 0.35 + randf_range(-0.1, 0.1)
		holder.position.y = i * 0.012
		f.position.x = -length * 0.5
		holder.add_child(f)
		root.add_child(holder)
	# Saplar bir arada: demetin bir ucunda kısa kahverengi sap
	ToolModels._mi(root, ToolModels.tube([Vector3(-length * 0.5 - 0.12, 0.01, 0), Vector3(-length * 0.5 + 0.08, 0.01, 0)], 0.018, 6), _ring)
	return root


# --- Etkileşim ----------------------------------------------------------------

func prompt(player) -> String:
	if falling or hp <= 0:
		return ""
	if player.held_id() == "balta":
		return "Sol tık: Palmiyeyi kes (%d/3)" % (3 - hp)
	return "Palmiye kesmek için balta gerekli (Tab → Araç)"


func interact(_player) -> void:
	pass


func _dir_from(player) -> Vector3:
	var d: Vector3 = global_position - player.global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD


func chop(player) -> void:
	if falling or hp <= 0:
		return
	hp -= 1
	var dir := _dir_from(player)
	var hit := to_global(Vector3(0, CUT_Y, 0)) - dir * 0.2 * scale.x
	main.audio.play_at("chop", hit, 0.0, 8.0)
	_chips(hit, -dir)
	sway_axis = Vector3.UP.cross(dir).normalized()
	sway_vel += 0.5
	if hp > 0 and not coconuts.is_empty() and randf() < 0.6:
		_drop_coconut()
	if hp <= 0:
		_fell(dir)


## Tepeden bir hindistan cevizi düşer, yerde sekip toplanabilir olur.
func _drop_coconut() -> void:
	var c: MeshInstance3D = coconuts.pop_back()
	var from := c.global_position
	c.visible = false
	var local: Vector3 = island.to_local(from)
	var ground: Vector3 = island._ground(local.x + randf_range(-0.6, 0.6), local.z + randf_range(-0.6, 0.6))
	var p = PickupScript.new()
	p.main = main
	p.item = "hindistan_cevizi"
	island.add_child(p)
	p.position = ground
	var vis := MeshInstance3D.new()
	var nm := SphereMesh.new()
	nm.radial_segments = 20
	nm.rings = 10
	nm.radius = 0.12
	nm.height = 0.22
	vis.mesh = nm
	vis.material_override = _nut
	p.add_child(vis)
	vis.global_position = from
	var tw := p.create_tween()
	tw.tween_property(vis, "position", Vector3(0, 0.1, 0), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(vis, "position:y", 0.3, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(vis, "position:y", 0.1, 0.15).set_ease(Tween.EASE_IN)
	main.audio.play_at("tile_break", ground, -12.0, 6.0)


## Devrilme: gıcırtı, kısa bir duraksama, sonra hızlanarak oyuncunun tersine düşüş.
func _fell(dir: Vector3) -> void:
	falling = true
	main.quests.event("chop", "palmiye")
	collision_layer = 0
	main.audio.play_at("tree_creak", global_position + Vector3(0, 2, 0), -2.0, 10.0)
	var axis := Vector3.UP.cross(dir).normalized()
	# Devrilme ekseni palmiyenin kendi uzayına çevrilir.
	var laxis: Vector3 = (global_transform.basis.inverse() * axis).normalized()
	var tilt := func(a: float): upper.transform.basis = Basis(laxis, a)
	var tw := create_tween()
	tw.tween_method(tilt, 0.0, 0.1, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_method(tilt, 0.1, 1.45, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var land := global_position + dir * height * 0.6 * scale.x
		main.audio.play_at("tree_fall", land, 2.0, 14.0)
		_dust(land, dir))
	tw.tween_method(tilt, 1.45, 1.38, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_method(tilt, 1.38, 1.45, 0.16).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.6)
	tw.tween_callback(func(): _split(dir))
	tw.tween_property(upper, "scale", Vector3(0.9, 0.9, 0.9), 0.35)
	tw.tween_callback(upper.queue_free)
	_stump_top()


## Yatan gövde kütüklere ayrılır, taçtan da yaprak demetleri kalır. Hepsi E ile toplanır.
var spawned: Array = []


func _split(dir: Vector3) -> void:
	var base := global_position
	var trunk_len := (height - CUT_Y) * scale.x
	for i in 3:
		var f := 0.2 + i * 0.27
		var wp := base + dir * trunk_len * f
		var lp: Vector3 = island.to_local(wp)
		var g: Vector3 = island._ground(lp.x, lp.z)
		var p = _spawn_pickup("tahta", 2, g)
		var logn := Node3D.new()
		logn.rotation.y = atan2(dir.x, dir.z) + randf_range(-0.25, 0.25)
		p.add_child(logn)
		var r := _trunk_radius(f) * scale.x
		ToolModels._mi(logn, ToolModels.tube([Vector3(0, r, -0.45), Vector3(0, r, 0.45)], r, 12), _bark)
		for e in [-1.0, 1.0]:
			var cap := CylinderMesh.new()
			cap.top_radius = r * 0.97
			cap.bottom_radius = r * 0.97
			cap.height = 0.01
			ToolModels._mi(logn, cap, _cut, Vector3(0, r, e * 0.455), Vector3(PI / 2.0, 0, 0))
		_poof(g + Vector3(0, 0.2, 0))
	var tip := base + dir * trunk_len * 1.02
	for i in 2:
		var lp: Vector3 = island.to_local(tip + dir.cross(Vector3.UP) * (i - 0.5) * 1.2)
		var g: Vector3 = island._ground(lp.x, lp.z)
		var p = _spawn_pickup("yaprak", 2, g)
		var bundle := frond_bundle(3, 1.1)
		bundle.rotation.y = randf() * TAU
		bundle.position.y = 0.05
		p.add_child(bundle)

func _spawn_pickup(item: String, amount: int, local_pos: Vector3):
	var p = PickupScript.new()
	p.main = main
	p.item = item
	p.amount = amount
	island.add_child(p)
	p.position = local_pos
	spawned.append(p)
	return p


## Kesik yüzey: gövdenin kalan alt kısmının üstünde açık renkli halkalı yüzey.
func _stump_top() -> void:
	var r := _trunk_radius(CUT_Y / height)
	var top := CylinderMesh.new()
	top.top_radius = r * 0.98
	top.bottom_radius = r * 0.98
	top.height = 0.012
	ToolModels._mi(self, top, _cut, _trunk_point(CUT_Y / height))
	for i in 3:
		var ring := TorusMesh.new()
		ring.rings = 24
		ring.ring_segments = 10
		ring.inner_radius = r * (0.2 + i * 0.25)
		ring.outer_radius = r * (0.2 + i * 0.25) + 0.008
		var mi := ToolModels._mi(self, ring, _ring, _trunk_point(CUT_Y / height) + Vector3(0, 0.007, 0))
		mi.scale = Vector3(1, 0.05, 1)


# --- Efektler -------------------------------------------------------------------

func _chips(at: Vector3, out: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = 16
	p.lifetime = 0.9
	p.explosiveness = 0.95
	var pm := ParticleProcessMaterial.new()
	pm.direction = (out + Vector3(0, 0.6, 0)).normalized()
	pm.spread = 40.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, -9.0, 0)
	pm.angular_velocity_min = -600.0
	pm.angular_velocity_max = 600.0
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	p.process_material = pm
	var bm := BoxMesh.new()
	bm.size = Vector3(0.04, 0.01, 0.02)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.72, 0.5)
	bm.material = m
	p.draw_pass_1 = bm
	_spawn_fx(p, at, 1.5)


func _dust(at: Vector3, dir: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = 30
	p.lifetime = 1.6
	p.explosiveness = 0.9
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.4, 0.05, height * 0.4)
	pm.direction = Vector3.UP
	pm.spread = 70.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0, -0.3, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.add_point(0.15, Color(1, 1, 1, 1.0))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.7)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.79, 0.64, 0.4)
	m.albedo_texture = ToolModels.glow_texture()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	p.draw_pass_1 = q
	p.rotation.y = atan2(dir.x, dir.z)
	_spawn_fx(p, at - dir * height * 0.1, 2.5)


## Kütüğe ayrılırken küçük toz bulutu.
func _poof(at: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = 8
	p.lifetime = 0.8
	p.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 80.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3.ZERO
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.79, 0.64, 0.35)
	m.albedo_texture = ToolModels.glow_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	p.draw_pass_1 = q
	_spawn_fx(p, island.to_global(at), 1.2)


func _spawn_fx(p: GPUParticles3D, at: Vector3, life: float) -> void:
	get_tree().current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(life).timeout.connect(p.queue_free)


func _process(delta: float) -> void:
	if falling or (sway_vel == 0.0 and sway == 0.0):
		return
	# Vuruşta tepe yaylanır: gövde hafif, taç daha çok sallanır.
	sway_vel += (-sway * 40.0 - sway_vel * 4.0) * delta
	sway += sway_vel * delta
	if absf(sway) < 0.0005 and absf(sway_vel) < 0.001:
		sway = 0.0
		sway_vel = 0.0
	var laxis: Vector3 = (global_transform.basis.inverse() * sway_axis).normalized()
	upper.transform.basis = Basis(laxis, sway * 0.04)
	crown.transform.basis = Basis(laxis, sway * 0.12)
