extends AnimatableBody3D
## Sal: 1.5 m'lik zemin karoları. Rüzgârla sürüklenir; yelken yön verir, çapa durdurur.
## Dalgayla sallanır ve üstündeki oyuncuyu taşır. Köpekbalığı kenar karoları ısırabilir.

const Waves = preload("res://scripts/waves.gd")
const BuildingScript = preload("res://scripts/building.gd")

const CELL := 1.5
const TILE_H := 0.22
const MAX_HP := 100.0
const CORE := Vector2i(0, 0)
const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Rüzgârla sürüklenme (m/s) ve yelken başına ek hız.
## Deniz akıntısı; üstüne rüzgârın sürüklemesi eklenir.
const CURRENT := Vector3(0.3, 0.0, 0.05)
const LEEWAY := 0.4
const SAIL_SPEED := 2.4
const MOTOR_SPEED := 1.4
## Dümenle çizilen rota (pusula açısı, derece). Dümen varsa motor bu yöne iter.
var course := 0.0

var main
## Vector2i -> {shape, visual, hp, mat}
var tiles := {}
## Vector2i -> building
var buildings := {}
## Bir sandığın üstüne istiflenen sandıklar: karo → [2. kat, 3. kat]
var stacks := {}
## Bir sandığın üstüne en fazla 5 sandık daha (6 katlı kule)
const STACK_MAX := 5
const CHEST_H := 0.34
var mat_plank: StandardMaterial3D
## Karo görselleri 5x5'lik parçalarda gizli tutulur, her parça tek bir birleşik ağ olarak çizilir.
## Karo eklenince/sökülünce/hasar görünce yalnız o parça yeniden birleştirilir.
const CHUNK := 5
const Merge = preload("res://scripts/merge.gd")
var chunks := {}
## Salın merkezi/yarıçapı ve birleşik çarpışma kutuları yalnız karo değişince yeniden hesaplanır.
var _geom_dirty := true
var _center_cache := Vector3.ZERO
var _radius_cache := 0.0
var _shapes_dirty := false
var _floor_shapes: Array = []
var dirty_chunks := {}
var _meshes := {}
var _metal_mats: Array = []
var mat_log: StandardMaterial3D
var base_pos := Vector3.ZERO
var vel := Vector3.ZERO
var grounded := false
## Ek yüzerlik (açılış vitrini büyük sal dalgaya gömülmesin diye).
var lift := 0.0

## Duvar / kapı / pencere / çatı parçaları. Anahtar: "x,y,taraf" (taraf: N, W ya da roof)
var structures := {}
const WALL_H := 2.4
const ROOF_Y := 2.5
var mat_thatch: StandardMaterial3D
var mat_frame: StandardMaterial3D


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	mat_plank = _pbr("old_planks_02", 0.9)
	mat_log = _pbr("rough_wood", 1.2, Color(0.75, 0.65, 0.55))
	mat_frame = _pbr("rough_wood", 1.6, Color(0.55, 0.42, 0.32))
	var straw := FastNoiseLite.new()
	straw.frequency = 0.05
	var st := NoiseTexture2D.new()
	st.width = 256
	st.height = 256
	st.seamless = true
	st.noise = straw
	var g := Gradient.new()
	g.set_color(0, Color(0.42, 0.34, 0.18))
	g.set_color(1, Color(0.82, 0.72, 0.45))
	st.color_ramp = g
	mat_thatch = StandardMaterial3D.new()
	mat_thatch.albedo_texture = st
	mat_thatch.uv1_scale = Vector3(1, 10, 1)
	mat_thatch.roughness = 1.0
	mat_thatch.cull_mode = BaseMaterial3D.CULL_DISABLED


## Salı anında taşır. Fizikle eşzamanlı gövdede konum normalde bir sonraki fizik adımında uygulanır;
## yüklemede oyuncu salın eski yerine göre konumlanmasın diye eşitleme geçici kapatılır.
func teleport(t: Transform3D) -> void:
	sync_to_physics = false
	global_transform = t
	sync_to_physics = true


func reset_raft() -> void:
	for k in structures.keys():
		_remove_structure_key(k)
	for c in tiles.keys():
		remove_tile(c, false)
	base_pos = Vector3.ZERO
	vel = Vector3.ZERO
	teleport(Transform3D.IDENTITY)
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		add_tile(c)


func _pbr(tex: String, scale: float, tint := Color.WHITE) -> StandardMaterial3D:
	var base := "res://assets/textures/%s/%s_" % [tex, tex]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(base + "diff_1k.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(base + "nor_gl_1k.jpg")
	var arm: Texture2D = load(base + "arm_1k.jpg")
	m.ao_enabled = true
	m.ao_texture = arm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = 1.0
	m.roughness_texture = arm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	return m


func cell_pos(c: Vector2i) -> Vector3:
	return Vector3(c.x * CELL, 0.0, c.y * CELL)


func cell_from_local(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / CELL), roundi(p.z / CELL))


func top_y() -> float:
	return TILE_H / 2.0


func add_tile(c: Vector2i, hp := MAX_HP) -> void:
	var shape = null
	_geom_dirty = true
	_queue_floor()

	var visual := Node3D.new()
	visual.position = cell_pos(c)
	_chunk_root(c).add_child(visual)
	var mat := mat_plank.duplicate() as StandardMaterial3D
	# Hasar rengi bu karoya özgü: birleştirmede başka karonun malzemesiyle eşlenmesin
	mat.set_meta("unique", true)
	var top := MeshInstance3D.new()
	top.mesh = _box(Vector3(CELL - 0.03, TILE_H * 0.55, CELL - 0.03))
	top.position.y = TILE_H * 0.22
	top.material_override = mat
	visual.add_child(top)
	# Kenar kirişleri ve altta yüzdürücü kütükler
	for side in [-0.62, 0.62]:
		var beam := MeshInstance3D.new()
		beam.mesh = _box(Vector3(CELL - 0.02, 0.08, 0.12))
		beam.position = Vector3(0, -0.02, side)
		beam.material_override = mat_log
		visual.add_child(beam)
	for side in [-0.38, 0.38]:
		var log := MeshInstance3D.new()
		log.mesh = _cyl(0.15, 0.15, CELL - 0.06, 10)
		log.rotation.z = PI / 2.0
		log.position = Vector3(0, -0.15, side)
		log.material_override = mat_log
		visual.add_child(log)
	tiles[c] = {"shape": shape, "visual": visual, "hp": hp, "mat": mat, "metal": false, "top": top}
	_tint(c)


func remove_tile(c: Vector2i, fx := true) -> void:
	if not tiles.has(c):
		return
	# Üstündeki çatı ve artık hiçbir karoya değmeyen duvarlar da gider.
	_remove_structure_key(_key(c, "roof"))
	for side in ["N", "W", "S", "E"]:
		var e := edge_key(c, side)
		var other: Vector2i = e[0] + (Vector2i(0, -1) if e[1] == "N" else Vector2i(-1, 0))
		var owner_cell: Vector2i = e[0]
		var remaining := 0
		for cc in [owner_cell, other]:
			if cc != c and tiles.has(cc):
				remaining += 1
		if remaining == 0:
			_remove_structure_key(_key(e[0], e[1]))
	var t: Dictionary = tiles[c]
	(t["visual"] as Node).free()
	tiles.erase(c)
	_mark(c)
	_geom_dirty = true
	_queue_floor()
	remove_building(c)
	if fx and main != null:
		main.audio.play_at("tile_break", to_global(cell_pos(c)))


func has_tile(c: Vector2i) -> bool:
	return tiles.has(c)


func can_build(c: Vector2i) -> bool:
	if tiles.has(c):
		return false
	for n in NEIGHBORS:
		if tiles.has(c + n):
			return true
	return false


## Sökülebilir karo: çekirdek değil, üstünde yapı yok ve sal ikiye bölünmüyor.
func can_remove(c: Vector2i) -> bool:
	if c == CORE or not tiles.has(c) or buildings.has(c):
		return false
	var rest := tiles.keys()
	rest.erase(c)
	var seen := {CORE: true}
	var stack: Array = [CORE]
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for n in NEIGHBORS:
			var nb: Vector2i = cur + n
			if nb != c and tiles.has(nb) and not seen.has(nb):
				seen[nb] = true
				stack.append(nb)
	return seen.size() == rest.size()


func can_place_building(c: Vector2i) -> bool:
	return tiles.has(c) and not buildings.has(c)


func place_building(kind: String, c: Vector2i, data := {}, rot_y := 0.0):
	if not can_place_building(c):
		return null
	var b = BuildingScript.new()
	b.main = main
	b.kind = kind
	b.cell = c
	b.position = cell_pos(c) + Vector3(0, top_y(), 0)
	b.rotation.y = float(data.get("rot", rot_y))
	add_child(b)
	b.setup_collision()
	buildings[c] = b
	if not data.is_empty():
		b.from_data(data)
	return b


func remove_building(c: Vector2i) -> void:
	for s in stacks.get(c, []):
		(s as Node).queue_free()
	stacks.erase(c)
	if buildings.has(c):
		(buildings[c] as Node).queue_free()
		buildings.erase(c)


## Bu karodaki sandığın üstüne bir sandık daha konabilir mi (en fazla 6 kat)?
func can_stack(c: Vector2i) -> bool:
	return buildings.has(c) and buildings[c].kind == "sandik" and stacks.get(c, []).size() < STACK_MAX


## Sandığın üstüne sandık koyar; yeni sandık alttakiyle aynı yöne bakar.
func stack_chest(c: Vector2i, data := {}):
	if not can_stack(c):
		return null
	var level: int = stacks.get(c, []).size() + 1
	var b = BuildingScript.new()
	b.main = main
	b.kind = "sandik"
	b.cell = c
	b.level = level
	b.position = cell_pos(c) + Vector3(0, top_y() + CHEST_H * level, 0)
	b.rotation.y = float(data.get("rot", (buildings[c] as Node3D).rotation.y))
	add_child(b)
	b.setup_collision()
	if not stacks.has(c):
		stacks[c] = []
	stacks[c].append(b)
	if not data.is_empty():
		b.from_data(data)
	return b


## Kurulu bir yapıyı 90° çevirir. İstiflenmiş sandıklar birlikte döner.
func rotate_building(b) -> void:
	var group: Array = [buildings.get(b.cell)] + stacks.get(b.cell, []) if b.kind == "sandik" else [b]
	for x in group:
		if x == null:
			continue
		x.rotation.y = fposmod(x.rotation.y + PI / 2.0, TAU)
		# İki karo boyundaki halı denize taşmasın: uzandığı yönde karo olana kadar çevir.
		if x.kind == "hali":
			for i in 3:
				if tiles.has(x.cell + Vector2i(roundi(sin(x.rotation.y)), roundi(cos(x.rotation.y)))):
					break
				x.rotation.y = fposmod(x.rotation.y + PI / 2.0, TAU)
		if x.block_shape != null and is_instance_valid(x.block_shape):
			x.block_shape.rotation.y = x.rotation.y


## Belirli bir yapıyı söker. İstifte yalnızca en üstteki sandık sökülebilir.
func remove_building_node(b) -> bool:
	var c: Vector2i = b.cell
	var st: Array = stacks.get(c, [])
	if b.level > 0:
		if st.is_empty() or st.back() != b:
			return false
		st.pop_back()
		if st.is_empty():
			stacks.erase(c)
		b.queue_free()
		return true
	if not st.is_empty():
		return false
	remove_building(c)
	return true


# --- Duvar ve çatı ----------------------------------------------------------

func _key(c: Vector2i, side: String) -> String:
	return "%d,%d,%s" % [c.x, c.y, side]


## Kenarı kanonik hâle getirir: S → alttaki karonun N'si, E → sağdakinin W'si.
func edge_key(c: Vector2i, side: String) -> Array:
	match side:
		"S":
			return [c + Vector2i(0, 1), "N"]
		"E":
			return [c + Vector2i(1, 0), "W"]
	return [c, side]


func has_structure(c: Vector2i, side: String) -> bool:
	if side == "roof":
		return structures.has(_key(c, "roof"))
	var e := edge_key(c, side)
	return structures.has(_key(e[0], e[1]))


func can_build_structure(kind: String, c: Vector2i, side: String) -> bool:
	if kind == "cati":
		return tiles.has(c) and not structures.has(_key(c, "roof"))
	var e := edge_key(c, side)
	var cc: Vector2i = e[0]
	var other: Vector2i = cc + (Vector2i(0, -1) if e[1] == "N" else Vector2i(-1, 0))
	return (tiles.has(cc) or tiles.has(other)) and not structures.has(_key(cc, e[1]))


func has_roof_at(world_pos: Vector3) -> bool:
	var l := to_local(world_pos)
	if l.y < -0.5 or l.y > ROOF_Y:
		return false
	return structures.has(_key(cell_from_local(l), "roof"))


func _panel(node: Node3D, shapes: Array, size: Vector3, pos: Vector3, mat: Material, collide := true) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _box(size)
	mi.position = pos
	mi.material_override = mat
	node.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.transform = node.transform * Transform3D(Basis.IDENTITY, pos)
		add_child(cs)
		shapes.append(cs)


## Duvar yerel X ekseni boyunca kurulur (-0.75..0.75), y=0..2.4.
func _build_wall(kind: String, node: Node3D, shapes: Array) -> void:
	var w := CELL
	var t := 0.08
	match kind:
		"duvar":
			_panel(node, shapes, Vector3(w, WALL_H, t), Vector3(0, WALL_H / 2.0, 0), mat_plank)
		"kapi":
			# Kapı boşluğu 0.92 m: oyuncu (0.7 m genişlik) rahatça geçer.
			for s in [-1.0, 1.0]:
				_panel(node, shapes, Vector3(0.29, WALL_H, t), Vector3(s * 0.605, WALL_H / 2.0, 0), mat_plank)
			_panel(node, shapes, Vector3(0.92, 0.36, t), Vector3(0, WALL_H - 0.18, 0), mat_plank)
			for s in [-1.0, 1.0]:
				_panel(node, shapes, Vector3(0.06, 2.04, 0.12), Vector3(s * 0.46, 1.02, 0), mat_frame, false)
		"pencere":
			_panel(node, shapes, Vector3(w, 1.0, t), Vector3(0, 0.5, 0), mat_plank)
			_panel(node, shapes, Vector3(w, 0.5, t), Vector3(0, WALL_H - 0.25, 0), mat_plank)
			for s in [-1.0, 1.0]:
				_panel(node, shapes, Vector3(0.45, 0.9, t), Vector3(s * 0.525, 1.45, 0), mat_plank)
			_panel(node, shapes, Vector3(0.66, 0.06, 0.14), Vector3(0, 1.0, 0.02), mat_frame, false)
			_panel(node, shapes, Vector3(0.04, 0.9, 0.05), Vector3(0, 1.45, 0), mat_frame, false)
			_panel(node, shapes, Vector3(0.6, 0.04, 0.05), Vector3(0, 1.45, 0), mat_frame, false)
	# Uzun kenarlarda ahşap kirişler ve köşe direkleri
	_panel(node, shapes, Vector3(w, 0.1, 0.12), Vector3(0, 0.05, 0), mat_frame, false)
	_panel(node, shapes, Vector3(w, 0.1, 0.12), Vector3(0, WALL_H - 0.05, 0), mat_frame, false)
	for s in [-1.0, 1.0]:
		_panel(node, shapes, Vector3(0.12, WALL_H, 0.14), Vector3(s * (w / 2.0 - 0.04), WALL_H / 2.0, 0), mat_frame, false)


## Saman kaplı beşik çatı. Uçları kapalı üçgen gövde ve tavan sayesinde
## yan yana çatılar boşluksuz birleşir. Yağmur damlaları çatıya çarpıp kaybolur.
func _build_roof(node: Node3D, shapes: Array) -> void:
	# Tavan (direk yok: çatı duvarların üstüne oturur, ev içi açık kalır): duvarların üst kirişine oturur, içeriden bitmiş görünür.
	_panel(node, shapes, Vector3(CELL + 0.02, 0.1, CELL + 0.02), Vector3(0, WALL_H + 0.05, 0), mat_frame)
	var body := MeshInstance3D.new()
	if not _meshes.has("roof"):
		var pm := PrismMesh.new()
		pm.size = Vector3(CELL + 0.34, 0.62, CELL + 0.03)
		_meshes["roof"] = pm
	body.mesh = _meshes["roof"]
	body.rotation.y = PI / 2.0
	body.position.y = WALL_H + 0.1 + 0.31
	body.material_override = mat_thatch
	node.add_child(body)
	_panel(node, shapes, Vector3(CELL + 0.04, 0.09, 0.1), Vector3(0, WALL_H + 0.1 + 0.62, 0), mat_frame, false)
	var pc := GPUParticlesCollisionBox3D.new()
	pc.size = Vector3(CELL + 0.3, 0.6, CELL + 0.3)
	# Yağmur çarpışma kutusu gizli kaynağın dışında kalmalı: salın altına, çatı hizasına
	pc.transform = node.transform * Transform3D(Basis.IDENTITY, Vector3(0, ROOF_Y + 0.3, 0))
	add_child(pc)
	shapes.append(pc)


func add_structure(kind: String, c: Vector2i, side: String, lamp := false) -> void:
	var cc := c
	var s := side
	if kind == "cati":
		s = "roof"
	else:
		var e := edge_key(c, side)
		cc = e[0]
		s = e[1]
	var key := _key(cc, s)
	if structures.has(key):
		return
	var node := Node3D.new()
	var base := cell_pos(cc) + Vector3(0, top_y(), 0)
	var shapes: Array = []
	if kind == "cati":
		node.position = base
	else:
		node.position = base + (Vector3(0, 0, -CELL / 2.0) if s == "N" else Vector3(-CELL / 2.0, 0, 0))
		node.rotation.y = 0.0 if s == "N" else PI / 2.0
	# Ev parçaları da karolar gibi bölgenin birleşik ağına girer (gizli kaynak düğüm)
	_chunk_root(cc, true).add_child(node)
	if kind == "cati":
		_build_roof(node, shapes)
	else:
		_build_wall(kind, node, shapes)
	structures[key] = {"kind": kind, "cell": cc, "side": s, "node": node, "shapes": shapes, "lamp": null}
	if lamp:
		add_lamp(cc)


func _remove_structure_key(key: String) -> void:
	if not structures.has(key):
		return
	var st: Dictionary = structures[key]
	for cs in st["shapes"]:
		(cs as Node).queue_free()
	if st["lamp"] != null:
		(st["lamp"]["node"] as Node).queue_free()
	(st["node"] as Node).free()
	structures.erase(key)
	_mark(st["cell"])


## Kaldırılan parçanın türünü döndürür (iade için), yoksa "".
func remove_structure(c: Vector2i, side: String) -> String:
	var key := _key(c, "roof") if side == "roof" else _key(edge_key(c, side)[0], edge_key(c, side)[1])
	if not structures.has(key):
		return ""
	var kind: String = structures[key]["kind"]
	var had_lamp: bool = structures[key]["lamp"] != null
	_remove_structure_key(key)
	return kind + ("+lamba" if had_lamp else "")


## Çatıya asılan tavan lambası.
func add_lamp(c: Vector2i) -> bool:
	var key := _key(c, "roof")
	if not structures.has(key) or structures[key]["lamp"] != null:
		return false
	var node: Node3D = structures[key]["node"]
	# Lamba birleştirilmez (ışığı ve camı yanıp söner): salın altında, çatının hizasında durur
	var lamp := Node3D.new()
	lamp.transform = node.transform * Transform3D(Basis.IDENTITY, Vector3(0, WALL_H - 0.02, 0))
	add_child(lamp)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.22, 0.23, 0.25)
	iron.metallic = 0.85
	iron.roughness = 0.5
	var chain := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.008
	cm.bottom_radius = 0.008
	cm.height = 0.3
	chain.mesh = cm
	chain.position.y = -0.15
	chain.material_override = iron
	lamp.add_child(chain)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(1.0, 0.85, 0.55, 0.7)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.7, 0.35)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radial_segments = 20
	sm.rings = 10
	sm.radius = 0.09
	sm.height = 0.2
	bulb.mesh = sm
	bulb.position.y = -0.38
	bulb.material_override = glass
	lamp.add_child(bulb)
	var cap := MeshInstance3D.new()
	var capm := CylinderMesh.new()
	capm.top_radius = 0.03
	capm.bottom_radius = 0.12
	capm.height = 0.08
	cap.mesh = capm
	cap.position.y = -0.3
	cap.material_override = iron
	lamp.add_child(cap)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.42)
	light.omni_range = 6.5
	light.light_energy = 1.4
	light.shadow_enabled = true
	light.position.y = -0.4
	lamp.add_child(light)
	structures[key]["lamp"] = {"node": lamp, "light": light, "glass": glass}
	return true


func _update_lamps() -> void:
	var want: bool = main.world.is_night() or main.world.rain > 0.5
	var flick := 1.0 + sin(Time.get_ticks_msec() * 0.013) * 0.04 + sin(Time.get_ticks_msec() * 0.031) * 0.03
	for k in structures:
		var l = structures[k]["lamp"]
		if l == null:
			continue
		(l["light"] as OmniLight3D).visible = want
		(l["light"] as OmniLight3D).light_energy = 1.4 * flick
		(l["glass"] as StandardMaterial3D).emission_energy_multiplier = 3.0 if want else 0.0
	_shadow_t -= get_physics_process_delta_time()
	if _shadow_t <= 0.0:
		_shadow_t = 0.5
		_limit_lamp_shadows()


## Gölgeli nokta ışığı sahneyi yeniden çizdirir: yalnız kameraya en yakın birkaç lamba gölge düşürür.
const LAMP_SHADOWS := 3
var _shadow_t := 0.0
func _limit_lamp_shadows() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var lights: Array = []
	for k in structures:
		var l = structures[k]["lamp"]
		if l != null:
			lights.append(l["light"])
	for c in buildings:
		var b = buildings[c]
		if b.kind == "fener" and b.lamp != null:
			lights.append(b.lamp)
	var cp := cam.global_position
	lights.sort_custom(func(x, y): return (x as Node3D).global_position.distance_squared_to(cp) < (y as Node3D).global_position.distance_squared_to(cp))
	var n := 0
	for li in lights:
		var on: bool = (li as Light3D).visible and n < LAMP_SHADOWS
		(li as Light3D).shadow_enabled = on
		if on:
			n += 1


func is_anchored() -> bool:
	for c in buildings:
		var b = buildings[c]
		if b.kind == "capa" and b.open:
			return true
	return false


## Yelkenin verimi (0..1): rüzgâr arkadan tam, yandan iyi, önden hiç (rüzgâra karşı gidilmez).
func sail_efficiency(dir: Vector3) -> float:
	var w: Vector3 = main.world.wind_vector()
	if w.length() < 0.01:
		return 0.0
	var c := dir.normalized().dot(w.normalized())
	return pow(maxf(0.0, (1.0 + c) * 0.5), 0.8)


func sail_vector() -> Vector3:
	var v := Vector3.ZERO
	var strength: float = main.world.wind_strength if main != null and main.world != null else 0.0
	for c in buildings:
		var b = buildings[c]
		if b.kind == "yelken" and b.open:
			v += b.dir * sail_efficiency(b.dir) * strength
	return v.limit_length(1.5) * SAIL_SPEED


func course_vec() -> Vector3:
	var r := deg_to_rad(course)
	return Vector3(sin(r), 0.0, -cos(r))


func has_helm() -> bool:
	for c in buildings:
		if buildings[c].kind == "dumen":
			return true
	return false


## Çalışan motorların itişi: dümen varsa rotaya, yoksa motorun baktığı yöne.
func motor_vector() -> Vector3:
	var v := Vector3.ZERO
	var helm := has_helm()
	for c in buildings:
		var b = buildings[c]
		if b.kind == "motor" and b.open and b.timer > 0.0:
			var fwd: Vector3 = (b.global_transform.basis * Vector3(0, 0, 1))
			fwd.y = 0.0
			v += (course_vec() if helm else fwd.normalized()) * MOTOR_SPEED
	return v.limit_length(MOTOR_SPEED * 1.6)


## Sürüklenme: akıntı + rüzgâr.
func drift_vector() -> Vector3:
	return CURRENT + main.world.wind_vector() * LEEWAY


## Karodan salın dışına bakan yön (90°'ye yuvarlanmış açı).
func outward_angle(c: Vector2i) -> float:
	var best := 0.0
	var best_free := -1
	for d in NEIGHBORS:
		if not tiles.has(c + d):
			var score := 1
			if best_free < score:
				best_free = score
				best = atan2(float(d.x), float(d.y))
	if best_free < 0:
		var o := cell_pos(c) - center_local()
		best = snappedf(atan2(o.x, o.z), PI / 2.0)
	return best


## Komşu sayısı 4'ten az olan, çekirdek dışındaki karolar: köpekbalığının hedefleri.
func edge_tiles() -> Array:
	var out: Array = []
	for c in tiles:
		if c == CORE:
			continue
		var n := 0
		for d in NEIGHBORS:
			if tiles.has(c + d):
				n += 1
		if n < 4:
			out.append(c)
	return out


func center_local() -> Vector3:
	_update_geom()
	return _center_cache


func _update_geom() -> void:
	if not _geom_dirty:
		return
	_geom_dirty = false
	var s := Vector3.ZERO
	for c in tiles:
		s += cell_pos(c)
	_center_cache = s / maxf(1.0, tiles.size())
	var r := 0.0
	for c in tiles:
		r = maxf(r, cell_pos(c).distance_to(_center_cache))
	_radius_cache = r + CELL


func _queue_floor() -> void:
	if not _shapes_dirty:
		_shapes_dirty = true
		_rebuild_floor.call_deferred()


## Zemin çarpışması: bitişik karolar en büyük dikdörtgenlere birleştirilir (20x20 sal = tek kutu).
func _rebuild_floor() -> void:
	_shapes_dirty = false
	for s in _floor_shapes:
		if is_instance_valid(s):
			(s as Node).queue_free()
	_floor_shapes.clear()
	var left := {}
	for c in tiles:
		left[c] = true
	var cells: Array = tiles.keys()
	cells.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	for c in cells:
		if not left.has(c):
			continue
		var w := 1
		while left.has(c + Vector2i(w, 0)):
			w += 1
		var h := 1
		var grow := true
		while grow:
			for i in w:
				if not left.has(c + Vector2i(i, h)):
					grow = false
					break
			if grow:
				h += 1
		for j in h:
			for i in w:
				left.erase(c + Vector2i(i, j))
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(CELL * w, TILE_H, CELL * h)
		cs.shape = box
		cs.position = (cell_pos(c) + cell_pos(c + Vector2i(w - 1, h - 1))) / 2.0
		add_child(cs)
		_floor_shapes.append(cs)


func center_global() -> Vector3:
	var c := center_local()
	return Vector3(base_pos.x + c.x, 0.0, base_pos.z + c.z)


func radius() -> float:
	_update_geom()
	return _radius_cache


func _tint(c: Vector2i) -> void:
	var k: float = tiles[c]["hp"] / MAX_HP
	(tiles[c]["mat"] as StandardMaterial3D).albedo_color = Color(1.0, 0.45 + 0.55 * k, 0.45 + 0.55 * k)
	var want: Material = mat_plank if k >= 0.999 else tiles[c]["mat"]
	if tiles[c].has("top") and (tiles[c]["top"] as MeshInstance3D).material_override != want:
		(tiles[c]["top"] as MeshInstance3D).material_override = want
		_mark(c)


func damage(c: Vector2i, amount: float) -> void:
	if not tiles.has(c):
		return
	tiles[c]["hp"] = maxf(0.0, tiles[c]["hp"] - amount)
	_tint(c)
	if tiles[c]["hp"] <= 0.0 and c != CORE:
		remove_tile(c)
		main.hud.toast("Köpekbalığı bir sal parçasını kopardı!")


## Köpekbalığı ısırığı: normal zemin 3 ısırıkta kopar; güçlendirilmiş zemin hasar almaz.
## "metal", "hasar" ya da "koptu" döndürür.
func bite(c: Vector2i) -> String:
	if not tiles.has(c):
		return ""
	if tiles[c]["metal"]:
		return "metal"
	tiles[c]["hp"] = maxf(0.0, tiles[c]["hp"] - (MAX_HP / 3.0 + 0.1) * float(main.diff()["tile"]))
	_tint(c)
	if tiles[c]["hp"] <= 0.0 and c != CORE:
		remove_tile(c)
		main.hud.toast("Köpekbalığı bir sal parçasını kopardı!")
		return "koptu"
	return "hasar"


## Oyuncunun güvenle durabileceği yer (yerel): tercih edilen karoya en yakın, üstünde yapı olmayan karo.
func safe_spot(prefer: Vector2i) -> Vector3:
	var best := CORE
	var bd := INF
	for c in tiles:
		if buildings.has(c):
			continue
		var d := Vector2(c - prefer).length()
		if d < bd:
			bd = d
			best = c
	return cell_pos(best) + Vector3(0, top_y() + 0.5, 0)


## Karoyu ya da komşusunu koruyan diken tuzağı (yoksa null).
func trap_near(c: Vector2i):
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var b = buildings.get(c + d)
		if b != null and is_instance_valid(b) and b.kind == "diken_tuzagi":
			return b
	return null


## Salda bu türde kurulu yapı var mı?
func has_kind(k: String) -> bool:
	for c in buildings:
		var b = buildings[c]
		if is_instance_valid(b) and b.kind == k:
			return true
	return false


func is_metal(c: Vector2i) -> bool:
	return tiles.has(c) and tiles[c]["metal"]


## Zemini metal çerçeve, köşe levhaları, perçinler ve yüzdürücü kelepçeleriyle güçlendirir.
func reinforce(c: Vector2i) -> bool:
	if not tiles.has(c) or tiles[c]["metal"]:
		return false
	tiles[c]["metal"] = true
	tiles[c]["hp"] = MAX_HP
	_tint(c)
	if _metal_mats.is_empty():
		var im := StandardMaterial3D.new()
		im.albedo_color = Color(0.36, 0.37, 0.4)
		im.metallic = 0.8
		im.roughness = 0.45
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.2, 0.2, 0.22)
		dm.metallic = 0.85
		dm.roughness = 0.5
		_metal_mats = [im, dm]
	var iron: StandardMaterial3D = _metal_mats[0]
	var dark: StandardMaterial3D = _metal_mats[1]
	_mark(c)
	var v: Node3D = tiles[c]["visual"]
	var node := Node3D.new()
	node.name = "Metal"
	v.add_child(node)
	var top := TILE_H * 0.22 + TILE_H * 0.275
	var h := CELL - 0.03
	for s in [-1.0, 1.0]:
		_metal_box(node, Vector3(h, 0.012, 0.07), Vector3(0, top + 0.006, s * (h / 2.0 - 0.035)), iron)
		_metal_box(node, Vector3(0.07, 0.012, h), Vector3(s * (h / 2.0 - 0.035), top + 0.006, 0), iron)
		# Kenarı saran kıvrık sac (yandan görünür)
		_metal_box(node, Vector3(h + 0.01, TILE_H * 0.6, 0.012), Vector3(0, top - TILE_H * 0.3, s * (h / 2.0 + 0.004)), dark)
		_metal_box(node, Vector3(0.012, TILE_H * 0.6, h + 0.01), Vector3(s * (h / 2.0 + 0.004), top - TILE_H * 0.3, 0), dark)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_metal_box(node, Vector3(0.16, 0.014, 0.16), Vector3(sx * (h / 2.0 - 0.08), top + 0.008, sz * (h / 2.0 - 0.08)), dark)
			var rv := MeshInstance3D.new()
			rv.mesh = _cyl(0.012, 0.016, 0.012, 6)
			rv.material_override = iron
			rv.position = Vector3(sx * (h / 2.0 - 0.08), top + 0.02, sz * (h / 2.0 - 0.08))
			node.add_child(rv)
	# Yüzdürücü kütüklere metal kelepçeler
	for side in [-0.38, 0.38]:
		for x in [-0.5, 0.5]:
			var band := MeshInstance3D.new()
			if not _meshes.has("torus"):
				var tm := TorusMesh.new()
				tm.rings = 12
				tm.ring_segments = 6
				tm.inner_radius = 0.15
				tm.outer_radius = 0.175
				_meshes["torus"] = tm
			band.mesh = _meshes["torus"]
			band.rotation.z = PI / 2.0
			band.position = Vector3(x, -0.15, side)
			band.material_override = dark
			node.add_child(band)
	return true


func _metal_box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _box(size)
	mi.position = pos
	mi.material_override = m
	parent.add_child(mi)


## Aynı ölçüdeki karo parçaları tek ağ kaynağını paylaşır (birleştirirken dizi önbelleği işe yarar).
func _box(size: Vector3) -> BoxMesh:
	var k := "b%s" % size
	if not _meshes.has(k):
		var b := BoxMesh.new()
		b.size = size
		_meshes[k] = b
	return _meshes[k]


func _cyl(top: float, bottom: float, height: float, seg: int) -> CylinderMesh:
	var k := "c%s_%s_%s_%d" % [top, bottom, height, seg]
	if not _meshes.has(k):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = height
		m.radial_segments = seg
		_meshes[k] = m
	return _meshes[k]


func _chunk_key(c: Vector2i) -> Vector2i:
	return Vector2i(floori(c.x / float(CHUNK)), floori(c.y / float(CHUNK)))


## house=true: ev parçaları (gölge düşürür); false: karolar (gölgesiz; güverte suya yakın, gölge geçişleri pahalı).
func _chunk_root(c: Vector2i, house := false) -> Node3D:
	var k := _chunk_key(c)
	if not chunks.has(k):
		var r := Node3D.new()
		r.name = "KaroParca_%d_%d" % [k.x, k.y]
		r.visible = false
		add_child(r)
		var sr := Node3D.new()
		sr.name = "EvParca_%d_%d" % [k.x, k.y]
		sr.visible = false
		add_child(sr)
		chunks[k] = {"root": r, "sroot": sr, "mesh": null, "smesh": null}
	_mark(c)
	return chunks[k]["sroot" if house else "root"]


func _mark(c: Vector2i) -> void:
	dirty_chunks[_chunk_key(c)] = true


## Değişen parçaları yeniden birleştirir (karede bir kez).
func _process(_delta: float) -> void:
	if dirty_chunks.is_empty():
		return
	for k in dirty_chunks:
		if not chunks.has(k):
			continue
		var ch: Dictionary = chunks[k]
		for m in ["mesh", "smesh"]:
			if ch[m] != null:
				(ch[m] as Node).queue_free()
		ch["mesh"] = Merge.bake(ch["root"], false, 0.0, false, self)
		ch["smesh"] = Merge.bake(ch["sroot"], true, 0.0, false, self)
	dirty_chunks.clear()


func needs_repair(c: Vector2i) -> bool:
	return tiles.has(c) and tiles[c]["hp"] < MAX_HP


func repair(c: Vector2i) -> void:
	if tiles.has(c):
		tiles[c]["hp"] = MAX_HP
		_tint(c)


func speed() -> float:
	return vel.length()


var prof_usec := 0
func _physics_process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_physics_body(delta)
	prof_usec += Time.get_ticks_usec() - t0


func _physics_body(delta: float) -> void:
	if main == null:
		return
	_update_lamps()
	var target := Vector3.ZERO
	if not is_anchored() and not main.paused:
		target = drift_vector() + sail_vector() + motor_vector()
	# Ada kıyısına değince yalnız adaya doğru olan itiş kesilir; kıyı boyunca ve açığa doğru gidilebilir.
	grounded = false
	var ctr := center_global()
	for isl in main.islands:
		var d: Vector3 = isl.global_position - ctr
		d.y = 0.0
		if d.length() < isl.shore_radius + radius() and d.length() > 0.01:
			var dn := d.normalized()
			var inward := target.dot(dn)
			if inward > 0.0:
				target -= dn * inward
				grounded = true
	vel = vel.lerp(target, minf(1.0, delta * 0.35))
	if not main.paused:
		base_pos += vel * delta
		# Kıyıya oturunca adanın içine kayamaz: dışarı itilir, kıyıya doğru hız sıfırlanır.
		for isl in main.islands:
			var lc0 := center_local()
			var off: Vector3 = Vector3(base_pos.x + lc0.x, 0, base_pos.z + lc0.z) - isl.global_position
			off.y = 0.0
			var lim: float = isl.shore_radius + radius() - CELL
			if off.length() < lim:
				var n := off.normalized() if off.length() > 0.01 else Vector3(1, 0, 0)
				base_pos += n * (lim - off.length())
				var into := vel.dot(-n)
				if into > 0.0:
					vel += n * into
				grounded = true

	# Dalgayla sallanma: salın ortasındaki su yüksekliğine ve eğimine yumuşakça uyar.
	var lc := center_local()
	var wx := base_pos.x + lc.x
	var wz := base_pos.z + lc.z
	var h := Waves.height(wx, wz)
	var n := Waves.normal(wx, wz).lerp(Vector3.UP, 0.62).normalized()
	var up_basis := Basis(Quaternion(Vector3.UP, n))
	var cur := global_transform
	# Sal sakinleşmiş suyun üstünde tam yüzer (su güverteye çıkmaz).
	var target_xf := Transform3D(up_basis, Vector3(base_pos.x, h + 0.06 + lift, base_pos.z))
	var blended := cur.interpolate_with(target_xf, 0.15)
	blended.origin.x = base_pos.x
	blended.origin.z = base_pos.z
	global_transform = blended


func to_data() -> Dictionary:
	var t: Array = []
	for c in tiles:
		t.append([c.x, c.y, tiles[c]["hp"], tiles[c]["metal"]])
	var b: Array = []
	for c in buildings:
		b.append(buildings[c].to_data())
	for c in stacks:
		for st in stacks[c]:
			b.append(st.to_data())
	var s: Array = []
	for k in structures:
		var st: Dictionary = structures[k]
		s.append([st["cell"].x, st["cell"].y, st["side"], st["kind"], st["lamp"] != null])
	return {"pos": [base_pos.x, base_pos.z], "tiles": t, "buildings": b, "structures": s, "course": course}


func from_data(d: Dictionary) -> void:
	for k in structures.keys():
		_remove_structure_key(k)
	for c in tiles.keys():
		remove_tile(c, false)
	var p: Array = d.get("pos", [0.0, 0.0])
	base_pos = Vector3(p[0], 0, p[1])
	course = float(d.get("course", 0.0))
	vel = Vector3.ZERO
	teleport(Transform3D(Basis.IDENTITY, base_pos))
	for t in d.get("tiles", []):
		add_tile(Vector2i(int(t[0]), int(t[1])), float(t[2]))
		if t.size() > 3 and t[3]:
			reinforce(Vector2i(int(t[0]), int(t[1])))
	for sd in d.get("structures", []):
		add_structure(sd[3], Vector2i(int(sd[0]), int(sd[1])), "N" if sd[2] == "roof" else sd[2], sd[4])
	for bd in d.get("buildings", []):
		var c := Vector2i(int(bd["cell"][0]), int(bd["cell"][1]))
		if tiles.has(c) and int(bd.get("level", 0)) == 0:
			place_building("toplayici" if bd["kind"] == "balik_agi" else bd["kind"], c, bd)
	# İstiflenmiş sandıklar alttakilerden sonra, kat sırasıyla
	var upper: Array = d.get("buildings", []).filter(func(x): return int(x.get("level", 0)) > 0)
	upper.sort_custom(func(x, y): return int(x["level"]) < int(y["level"]))
	for bd in upper:
		stack_chest(Vector2i(int(bd["cell"][0]), int(bd["cell"][1])), bd)
