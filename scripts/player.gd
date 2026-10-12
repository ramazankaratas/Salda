extends CharacterBody3D
## Oyuncu: yürür, yüzer, dalar, sala tırmanır. Alet çubuğundaki (envanterin ilk 10 yuvası)
## seçili eşyaya göre davranır: kanca, çekiç, mızrak, olta, yiyecek ya da yerleştirilecek yapı.

const Waves = preload("res://scripts/waves.gd")
const Items = preload("res://scripts/items.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Settings = preload("res://scripts/settings.gd")
const BuildingScript = preload("res://scripts/building.gd")
const BaitScript = preload("res://scripts/bait.gd")

const ToolModels = preload("res://scripts/tool_models.gd")

## Elde tutulan modellerin konumu ve açısı (kameraya göre).
const HOLD := {
	"kanca": [Vector3(0.3, -0.5, -0.5), Vector3(-0.45, 0.2, -0.15)],
	"metal_kanca": [Vector3(0.3, -0.5, -0.5), Vector3(-0.45, 0.2, -0.15)],
	"cekic": [Vector3(0.3, -0.42, -0.42), Vector3(-0.35, 0.5, 0.15)],
	"mizrak": [Vector3(0.24, -0.28, 0.25), Vector3(-PI / 2.0 + 0.08, 0.04, 0.0)],
	"metal_mizrak": [Vector3(0.24, -0.28, 0.25), Vector3(-PI / 2.0 + 0.08, 0.04, 0.0)],
	"olta": [Vector3(0.26, -0.5, -0.3), Vector3(-0.75, 0.1, -0.05)],
	"balta": [Vector3(0.3, -0.5, -0.45), Vector3(-0.3, 0.6, 0.2)],
	"kazma": [Vector3(0.3, -0.5, -0.45), Vector3(-0.3, 0.6, 0.2)],
	"durbun": [Vector3(0.0, -0.22, -0.32), Vector3(-PI / 2.0 + 0.1, 0.0, 0.0)],
	"pusula": [Vector3(0.17, -0.2, -0.46), Vector3(1.1, 0.0, 0.0)],
	"mesale": [Vector3(0.28, -0.45, -0.45), Vector3(-0.15, 0.1, -0.1)],
	"ham_balik": [Vector3(0.24, -0.3, -0.45), Vector3(0.3, -0.2, PI / 2.3)],
	"pismis_balik": [Vector3(0.24, -0.3, -0.45), Vector3(0.3, -0.2, PI / 2.3)],
}

const WALK := 4.0
const SPRINT := 6.2
const SWIM := 3.3
const JUMP := 5.0
const GRAVITY := 16.0
const REACH := 3.0
const BUILD_REACH := 6.0
const SPEAR_REACH := 3.2
const HOTBAR := 10

var main
var head: Node3D
var camera: Camera3D
var ray: RayCast3D
var hands: Node3D
var hand_models := {}
var hand_generic: MeshInstance3D
var inv
var selected := 0

var in_water := false
var head_under := false
var controls := true
## Oturulan sandalye (yoksa null).
var seat = null
## Başında durulan dümen (yoksa null).
var helm = null
var health := 100.0
var hunger := 100.0
var thirst := 100.0
var oxygen := 100.0
## Kuşanılan dalış takımı: "tup" oksijen tüpü, "palet"
var gear := {"tup": "", "palet": "", "fener": ""}
var head_lamp: SpotLight3D
var tank_air := 0.0
const TANK_DRAIN := 1.25
## Bugüne dek inilen en derin nokta (tam metre)
var max_depth := 0.0
## Geliştirici: ekran görüntüsü için oyuncuyu yerinde dondurur
var frozen := false

var ghost: MeshInstance3D
## Taşıma modu: elde taşınan yapı(lar)ın kaydı; sandık kulesinde alttan üste sırayla. Boşsa taşınmıyor.
var carry: Array = []
var carry_rot := 0.0
var carry_from := Vector2i.ZERO
var ghost_mat: StandardMaterial3D
## Yerleştirirken R ile çevrilen yön (90° adımlar).
var place_turn := 0
var spear_cd := 0.0
var swing := 0.0
## Balta ve kazma vuruşu: kavrama noktasından dönen yay (geri kaldır → indir). Vuruş anında isabet olur.
const SWING_TOOLS := ["balta", "kazma"]
## Dik tutulup yukarıdan aşağı savrulan aletler (çekiç yalnız görsel vuruş yapar)
const UPRIGHT_TOOLS := ["balta", "kazma", "cekic"]
var hammer_t := -1.0
const SWING_DUR := 0.62
const HIT_AT := 0.36
var tool_t := -1.0
var tool_target = null
var tool_hit_done := true
var hold_rest := {}
## Geliştirici: ekran görüntüsü için vuruş pozunu dondurur (-1: kapalı).
var debug_pose := -1.0
var step_timer := 0.0
var bob_t := 0.0
var drown_cd := 0.0
var zoomed := false
var chop_cd := 0.0
## Çekiçte seçili yapı parçası (Items.PIECES sırası)
var build_piece := 0
var torch_light: OmniLight3D
var torch_burn := 0.0


func _ready() -> void:
	inv = Inventory.new(30)
	inv.hotbar_size = 10
	collision_layer = 2
	collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	col.shape = cap
	col.position.y = 0.875
	add_child(col)
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = 1.6
	add_child(head)
	camera = Camera3D.new()
	camera.fov = Settings.fov
	camera.near = 0.05
	camera.far = 4000.0
	head.add_child(camera)
	camera.current = true

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -BUILD_REACH)
	ray.collision_mask = 1 | 4
	ray.add_exception(self)
	camera.add_child(ray)

	_build_hands()
	# Dalgıç feneri: kuşanılınca su altında ve gece yanar
	head_lamp = SpotLight3D.new()
	head_lamp.light_color = Color(1.0, 0.95, 0.82)
	head_lamp.light_energy = 3.0
	head_lamp.spot_range = 28.0
	head_lamp.spot_angle = 32.0
	head_lamp.spot_attenuation = 0.8
	head_lamp.shadow_enabled = false
	head_lamp.position = Vector3(0.0, 0.1, 0.0)
	head_lamp.visible = false
	camera.add_child(head_lamp)
	ghost = MeshInstance3D.new()
	ghost_mat = StandardMaterial3D.new()
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.material_override = ghost_mat
	ghost.top_level = true
	ghost.visible = false
	add_child(ghost)


func give_starting_items() -> void:
	inv.from_data([])
	inv.add("kanca", 1)
	inv.add("cekic", 1)
	selected = 0


# --- Eşya yardımcıları -------------------------------------------------------

func held():
	return inv.slots[selected]


func held_id() -> String:
	var s = held()
	return s["id"] if s != null else ""


## Kancanın ve oltanın çıktığı el noktası (dünya koordinatı).
## Pusula: iğneyi kuzeye çevirir, yön ve rüzgâr bilgisini verir.
func _compass_text() -> String:
	var world = main.world
	var fwd: Vector3 = -camera.global_transform.basis.z
	var heading := fposmod(rad_to_deg(atan2(fwd.x, -fwd.z)), 360.0)
	var names := ["Kuzey", "Kuzeydoğu", "Doğu", "Güneydoğu", "Güney", "Güneybatı", "Batı", "Kuzeybatı"]
	var dir_name: String = names[int(round(heading / 45.0)) % 8]
	var sail_eff: float = main.raft.sail_efficiency(Vector3(fwd.x, 0, fwd.z).normalized())
	return "Yön: %s %d°  ·  Rüzgâr: %s (%s'den, %s)  ·  Bu yöne yelken verimi %%%d" % [dir_name, int(heading), world.wind_name(), world.wind_dir_name(), world.wind_force_name(), int(sail_eff * 100.0)]


## Elde tutulan oltanın ucundaki halka (dünya konumu); misina buradan çıkar.
func rod_tip() -> Vector3:
	if hand_models.has("olta"):
		return (hand_models["olta"] as Node3D).global_transform * Vector3(0, 1.36, 0.016)
	return hand_point()


func hand_point() -> Vector3:
	return camera.global_transform * Vector3(0.3, -0.15, -0.8)


func is_hook(id := "") -> bool:
	var i := id if id != "" else held_id()
	return i == "kanca" or i == "metal_kanca"


## Dümene geç: tekerin önünde durulur; A/D rotayı çevirir, açık yelkenler rotaya döner.
func take_helm(h) -> void:
	helm = h
	velocity = Vector3.ZERO
	rotation.y = h.global_rotation.y
	head.rotation.x = -0.05
	sit_frame = Engine.get_process_frames()


func _helm_step(delta: float) -> String:
	var raft = main.raft
	var turn := Input.get_axis("move_left", "move_right")
	if absf(turn) > 0.1:
		raft.course = fposmod(raft.course + turn * 35.0 * delta, 360.0)
		helm.wheel.rotation.z -= turn * delta * 2.5
	# Açık yelkenler rotaya döner
	var cv: Vector3 = raft.course_vec()
	for c in raft.buildings:
		var b = raft.buildings[c]
		if b.kind == "yelken" and b.open and b.dir.distance_to(cv) > 0.01:
			b.dir = cv
			b._update_sail()
	if Engine.get_process_frames() != sit_frame and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump") or absf(Input.get_axis("move_forward", "move_back")) > 0.5):
		var back: Vector3 = helm.global_transform * Vector3(0, 0.15, 1.2)
		helm = null
		global_position = back
		return ""
	var names := ["Kuzey", "Kuzeydoğu", "Doğu", "Güneydoğu", "Güney", "Güneybatı", "Batı", "Kuzeybatı"]
	var cname: String = names[int(round(raft.course / 45.0)) % 8]
	var eff: float = raft.sail_efficiency(cv)
	return "Dümen: rota %03d° %s  ·  A/D çevir  ·  E bırak  ·  rüzgâr %s, yelken verimi %%%d  ·  %.1f m/s" % [int(raft.course), cname, main.world.wind_name(), int(eff * 100.0), raft.speed()]


## Sandalyeye otur: önüne dönük, göz hizası alçalır.
func sit(chair) -> void:
	seat = chair
	velocity = Vector3.ZERO
	rotation.y = chair.global_rotation.y + PI
	head.rotation.x = -0.1
	sit_frame = Engine.get_process_frames()


## Kalk: sandalyenin önüne geç.
func stand_up() -> void:
	if Engine.get_process_frames() == sit_frame:
		return
	var front: Vector3 = seat.global_transform * Vector3(0, 0.15, 0.7)
	seat = null
	global_position = front


var sit_frame := -1


func can_act() -> bool:
	return controls and not main.hud.menu_open and not main.paused and Engine.get_process_frames() != main.hud.menu_closed_frame


func give(id: String, n: int) -> void:
	var left: int = inv.add(id, n)
	if n - left > 0:
		main.quests.event("pickup", id, n - left)
		main.hud.notify("+%d %s" % [n - left, Items.name_of(id)], Items.info(id)["color"], id)
		main.audio.play("pickup", -6.0)
	if left > 0:
		main.hud.toast("Envanter dolu! %d %s denize düştü." % [left, Items.name_of(id)])


func use_durability() -> void:
	var s = held()
	if s == null or int(s.get("dur", 0)) <= 0:
		return
	s["dur"] -= 1
	if s["dur"] <= 0:
		main.hud.toast("%s kırıldı!" % Items.name_of(s["id"]))
		inv.slots[selected] = null
		inv.changed.emit()


func damage(amount: float, reason := "") -> void:
	if main.dead:
		return
	health -= amount
	if reason != "":
		main.hud.toast(reason)
	main.hud.flash_damage()
	main.audio.play("hurt", -2.0)
	if health <= 0.0:
		main.on_player_died()


# --- El modelleri ------------------------------------------------------------

func _mat(c: Color, metal := 0.0, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)


func _cyl(r: float, h: float, r2 := -1.0) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r if r2 < 0.0 else r2
	c.height = h
	return c


func _boxm(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _build_hands() -> void:
	hands = Node3D.new()
	camera.add_child(hands)
	# Ayrıntılı alet modelleri (ikonlarla aynı modeller).
	for id in HOLD:
		var m := ToolModels.make(id)
		var pivot := Node3D.new()
		pivot.position = HOLD[id][0]
		pivot.rotation = HOLD[id][1]
		if id in UPRIGHT_TOOLS:
			# Sap dik ve hafif öne-içe eğik tutulur; ağız (yerel +X) ileri bakar. Dönme noktası sapın alt ucu (kavrama).
			# Sap dik ve hafif öne eğik; ağız / çekiç yüzü / kazma ucu ileri bakar: yay kameranın dikey düzleminde olur
			var b := Basis(Vector3(0, 0, 1), 0.12) * Basis(Vector3.RIGHT, -0.3) * Basis(Vector3.UP, PI / 2.0)
			pivot.transform = Transform3D(b, Vector3(0.3, -0.45, -0.52) if id == "cekic" else Vector3(0.32, -0.62, -0.58))
			hold_rest[id] = pivot.transform
		pivot.add_child(m)
		pivot.visible = false
		hands.add_child(pivot)
		hand_models[id] = pivot
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hand_generic = MeshInstance3D.new()
	hands.add_child(hand_generic)
	torch_light = OmniLight3D.new()
	torch_light.light_color = Color(1.0, 0.62, 0.3)
	torch_light.omni_range = 9.0
	torch_light.light_energy = 1.8
	torch_light.shadow_enabled = true
	torch_light.position = Vector3(0.3, -0.1, -0.5)
	torch_light.visible = false
	hands.add_child(torch_light)


## Kendi el modeli olmayan eşyalar (yiyecek, su, yapılar) ikondaki modelle, küçültülüp elde gösterilir.
func _make_hand_model(id: String) -> void:
	var type: String = Items.info(id)["type"]
	var big := type == "place" or type == "roof"
	var m: Node3D = main.icons.build_model(id, 0.2 if big else 0.11)
	var pivot := Node3D.new()
	pivot.position = Vector3(0.3, -0.26, -0.62) if big else Vector3(0.25, -0.24, -0.5)
	pivot.rotation = Vector3(0.25, -0.55, 0.0) if big else Vector3(0.2, -0.4, 0.0)
	pivot.add_child(m)
	pivot.visible = false
	hands.add_child(pivot)
	hand_models[id] = pivot


func _update_hands(delta: float) -> void:
	var id := held_id()
	if id == "pusula" and hand_models.has("pusula"):
		var needle: Node3D = (hand_models["pusula"] as Node3D).find_child("Igne", true, false)
		if needle != null:
			var parent_basis: Basis = (needle.get_parent() as Node3D).global_transform.basis
			var north: Vector3 = parent_basis.inverse() * Vector3(0, 0, -1)
			needle.rotation.y = lerp_angle(needle.rotation.y, atan2(-north.x, -north.z), minf(1.0, delta * 6.0))
	for k in hand_models:
		(hand_models[k] as Node3D).visible = k == id and not (is_hook(k) and main.hook.is_out())
	if id != "" and not hand_models.has(id) and main.icons != null:
		_make_hand_model(id)
		(hand_models[id] as Node3D).visible = true
	hand_generic.visible = id != "" and not hand_models.has(id)
	if hand_generic.visible:
		var info: Dictionary = Items.info(id)
		var food: bool = info["type"] == "food"
		hand_generic.mesh = _cyl(0.045, 0.1) if food else _boxm(Vector3(0.12, 0.12, 0.12))
		hand_generic.material_override = _mat(info["color"])
		hand_generic.position = Vector3(0.24, -0.25, -0.45)
	# Yürürken sallanma ve mızrak savurma
	var moving := Vector2(velocity.x, velocity.z).length() > 0.5 and is_on_floor()
	bob_t += delta * (9.0 if moving else 2.0)
	var bob := Vector3(sin(bob_t) * 0.012, absf(cos(bob_t)) * 0.015, 0) if moving else Vector3(0, sin(bob_t) * 0.004, 0)
	swing = maxf(0.0, swing - delta * 4.0)
	var swing_off := Vector3.ZERO
	if id == "mizrak" or id == "metal_mizrak":
		swing_off = Vector3(0, 0, -swing * 0.5)
	hands.position = bob + swing_off
	hands.rotation.x = 0.0
	# Balta / kazma yayı: 0–%45 geri kaldır, %45–%58 hızla indir (vuruş), sonra dinlenme konumuna dön
	if debug_pose >= 0.0:
		tool_t = debug_pose
	# Çekiç: her sol tıkta kısa bir aşağı vuruş (görsel)
	if id == "cekic":
		if hammer_t >= 0.0:
			hammer_t += delta
			if hammer_t >= 0.32:
				hammer_t = -1.0
		elif can_act() and Input.is_action_just_pressed("use"):
			hammer_t = 0.0
	if id in UPRIGHT_TOOLS and hold_rest.has(id):
		var ang := 0.0
		var tt := tool_t
		var dur := SWING_DUR
		if id == "cekic":
			tt = hammer_t
			dur = 0.32
		if debug_pose >= 0.0:
			tt = debug_pose * (dur / SWING_DUR)
		if tt >= 0.0:
			var k := tt / dur
			if k < 0.45:
				ang = 0.5 * ease(k / 0.45, 0.6)
			elif k < 0.58:
				ang = lerpf(0.5, -1.0, ease((k - 0.45) / 0.13, 1.8))
			else:
				ang = lerpf(-1.0, 0.0, ease((k - 0.58) / 0.42, 0.5))
		var rest: Transform3D = hold_rest[id]
		# Yay aletin kendi düzleminde döner (eksen: ağız levhasının normali): ağız ve kazma ucu hareketin önünde gider.
		var n: Vector3 = (rest.basis * Vector3(0, 0, 1)).normalized()
		var edge: Vector3 = (rest.basis * Vector3(1, 0, 0)).normalized()
		var lift: Vector3 = Vector3.UP * 0.18 * maxf(ang, 0.0) - edge * 0.06 * maxf(ang, 0.0) + edge * 0.12 * maxf(-ang, 0.0)
		(hand_models[id] as Node3D).transform = Transform3D(Basis(n, ang) * rest.basis, rest.origin + lift)
	var target_fov: float = 22.0 if zoomed and id == "durbun" else Settings.fov
	camera.fov = lerpf(camera.fov, target_fov, minf(1.0, delta * 10.0))
	hands.visible = not (zoomed and id == "durbun")
	# Meşale: titreyen sıcak ışık; yandıkça tükenir (dayanıklılık = saniye).
	torch_light.visible = id == "mesale"
	if id == "mesale":
		var tm := Time.get_ticks_msec()
		torch_light.light_energy = 1.8 + sin(tm * 0.021) * 0.18 + sin(tm * 0.047) * 0.12
		torch_burn += delta
		if torch_burn >= 1.0 and not main.paused:
			torch_burn = 0.0
			use_durability()


# --- Girdi -------------------------------------------------------------------

## _input: fare hareketi arayüz tarafından yutulmadan kameraya ulaşsın.
func _input(event: InputEvent) -> void:
	if main.hud.menu_open or main.paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and controls:
		rotate_y(-event.relative.x * Settings.sensitivity)
		head.rotate_x(-event.relative.y * Settings.sensitivity)
		head.rotation.x = clampf(head.rotation.x, -1.5, 1.5)
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			selected = (selected - 1 + HOTBAR) % HOTBAR
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			selected = (selected + 1) % HOTBAR


# --- Fizik -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if main.paused:
		return
	# Göz yüksekliği: otururken alçalır.
	head.position.y = lerpf(head.position.y, 1.12 if seat != null else 1.6, minf(1.0, 8.0 * delta))
	if helm != null:
		if not is_instance_valid(helm):
			helm = null
		else:
			global_position = helm.global_transform * Vector3(0, 0.0, 0.85)
			velocity = Vector3.ZERO
			return
	if seat != null:
		if not is_instance_valid(seat):
			seat = null
		else:
			# Sandalyeyle birlikte (sal sallanırken de) yerinde durur.
			global_position = seat.global_transform * Vector3(0, 0.0, 0.04)
			velocity = Vector3.ZERO
			return
	var wh := Waves.height(global_position.x, global_position.z)
	var was_in := in_water
	in_water = global_position.y + 1.1 < wh
	if in_water and not was_in and velocity.y < -2.0:
		main.audio.play_at("splash", global_position + Vector3(0, 1, 0), 0.0)
	head_under = camera.global_position.y < Waves.height(camera.global_position.x, camera.global_position.z)

	if frozen:
		velocity = Vector3.ZERO
		return
	var input := Vector2.ZERO
	if can_act():
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	if in_water:
		var fins: float = 1.7 if gear["palet"] != "" else 1.0
		var dir := camera.global_transform.basis * Vector3(input.x, 0, input.y)
		dir.y = clampf(dir.y, -0.6, 0.6) if head_under else minf(dir.y, 0.0) * 0.3
		var target_v := dir * SWIM * fins
		velocity.x = lerpf(velocity.x, target_v.x, 4.0 * delta)
		velocity.z = lerpf(velocity.z, target_v.z, 4.0 * delta)
		var surface_y := wh - 1.42
		if can_act() and Input.is_action_pressed("jump"):
			velocity.y = lerpf(velocity.y, 2.6, 6.0 * delta)
			if global_position.y > surface_y - 0.3:
				_try_climb()
		elif can_act() and Input.is_action_pressed("dive"):
			velocity.y = lerpf(velocity.y, -2.6 * fins, 4.0 * delta)
		elif global_position.y > surface_y - 1.2:
			# Yüzeye yakınken kaldırma kuvveti kafayı suyun üstünde tutar.
			velocity.y = lerpf(velocity.y, (surface_y - global_position.y) * 2.5 + target_v.y, 3.0 * delta)
		else:
			velocity.y = lerpf(velocity.y, 0.7 + target_v.y, 2.0 * delta)
	else:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		elif can_act() and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP
		var speed := SPRINT if Input.is_action_pressed("sprint") else WALK
		var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		if is_on_floor() and input.length() > 0.1:
			step_timer -= delta * (1.4 if speed > WALK else 1.0)
			if step_timer <= 0.0:
				step_timer = 0.42
				main.audio.play("step", -14.0)
	move_and_slide()

	head_lamp.visible = gear["fener"] != "" and (head_under or main.world.is_night())
	# Oksijen: tüp varsa önce tüpteki hava harcanır; yüzeyde tüp kendiliğinden dolar.
	if head_under:
		var depth: float = wh - camera.global_position.y
		var nd := floorf(depth)
		if nd > max_depth:
			main.quests.event("dive_depth", "", nd - max_depth)
			max_depth = nd
	if head_under and gear["tup"] != "" and tank_air > 0.0:
		tank_air = maxf(0.0, tank_air - delta * TANK_DRAIN)
		if tank_air <= 0.0:
			main.hud.toast("Tüpte hava bitti! Yüzeye çık.", 3.0)
	elif head_under:
		oxygen = maxf(0.0, oxygen - delta * 2.5)
		if oxygen <= 0.0:
			drown_cd -= delta
			if drown_cd <= 0.0:
				drown_cd = 1.0
				damage(10.0, "Boğuluyorsun! Yüzeye çık!")
	else:
		oxygen = minf(100.0, oxygen + delta * 30.0)
		if gear["tup"] != "":
			tank_air = minf(100.0, tank_air + delta * 8.0)


## Dalış takımını kuşanır; aynı yuvadaki eski parça envantere döner.
func equip(id: String) -> void:
	var slot: String = Items.info(id).get("slot", "")
	if slot == "" or inv.count(id) <= 0:
		return
	var old: String = gear[slot]
	inv.remove(id, 1)
	gear[slot] = id
	if old != "":
		give(old, 1)
	if slot == "tup":
		tank_air = 100.0
	main.audio.play("cloth", -4.0)
	main.hud.toast("%s kuşanıldı." % Items.name_of(id), 2.5)
	main.quests.event("equip", id)


## Envantere yer varsa dalış takımını çıkarır.
func unequip(slot: String) -> void:
	var id: String = gear[slot]
	if id == "":
		return
	if inv.add(id, 1) == 0:
		gear[slot] = ""
		main.audio.play("cloth", -6.0)
	else:
		main.hud.toast("Envanterde yer yok.")


## Elindeki yemi baktığın yöne fırlatır.
func throw_bait() -> void:
	if inv.count("kopekbaligi_yemi") <= 0:
		return
	inv.remove("kopekbaligi_yemi", 1)
	var b = BaitScript.new()
	b.main = main
	main.add_child(b)
	var fwd := -camera.global_transform.basis.z
	b.global_position = camera.global_position + fwd * 0.6
	b.vel = fwd * 11.0 + Vector3(0, 4.0, 0)
	main.audio.play("hook_throw", -4.0)


## Sudayken salın kenarına yeterince yakınsa üstüne çık.
func _try_climb() -> void:
	var raft = main.raft
	var local: Vector3 = raft.to_local(global_position)
	var best := Vector2i.ZERO
	var best_d := INF
	for c in raft.tiles:
		var cp: Vector3 = raft.cell_pos(c)
		var d: float = maxf(absf(local.x - cp.x), absf(local.z - cp.z)) - raft.CELL * 0.5
		if d < best_d:
			best_d = d
			best = c
	if best_d < 1.3 and local.y > -2.5:
		var p: Vector3 = raft.cell_pos(best)
		# Karonun içine (kenardan 0.25 m içeri) yerleş: kenarda duvar olsa da sala çıkılır.
		var inward := Vector3(p.x + clampf(local.x - p.x, -0.5, 0.5), 0, p.z + clampf(local.z - p.z, -0.5, 0.5))
		global_position = raft.to_global(Vector3(inward.x, raft.top_y() + 0.05, inward.z))
		velocity = Vector3.ZERO


# --- Her kare ----------------------------------------------------------------

func _process(delta: float) -> void:
	if main.paused:
		return
	_update_hands(delta)
	ghost.visible = false
	if not can_act():
		main.hud.set_prompt("")
		return
	for k in HOTBAR:
		if Input.is_action_just_pressed("slot_%d" % k):
			selected = k

	if helm != null:
		main.hud.set_prompt(_helm_step(delta))
		return
	if seat != null:
		var mv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump") or mv.length() > 0.5:
			stand_up()
		main.hud.set_prompt("E / Boşluk: Kalk")
		return

	if not carry.is_empty():
		main.hud.set_prompt(_carry_step())
		return
	var prompt := ""
	var target = _looked_target()
	var id := held_id()
	var info: Dictionary = Items.info(id) if id != "" else {}
	if id == "cekic":
		prompt = _hammer(target)
	elif id == "mizrak" or id == "metal_mizrak":
		_spear(delta, 2 if id == "metal_mizrak" else 1)
	elif id == "balta":
		prompt = _axe(delta, target)
	elif id == "kazma":
		prompt = _pickaxe(delta, target)
	elif id == "pusula":
		prompt = _compass_text()
	elif id == "kopekbaligi_yemi":
		prompt = "Sol tık: Yemi denize fırlat (köpekbalığı bir süre onunla oyalanır)"
		if Input.is_action_just_pressed("use"):
			throw_bait()
	elif id != "" and info["type"] == "gear":
		var cur: String = gear[info["slot"]]
		prompt = "Sol tık: Kuşan (%s)%s" % [Items.name_of(id), "  ·  %s çıkarılır" % Items.name_of(cur) if cur != "" else ""]
		if Input.is_action_just_pressed("use"):
			equip(id)
	elif id == "durbun":
		if Input.is_action_just_pressed("use"):
			zoomed = not zoomed
		prompt = "Sol tık: %s" % ("Uzaklaştır" if zoomed else "Yakınlaştır")
	elif id != "" and info["type"] == "place":
		prompt = _place(id)
	elif id != "" and info["type"] == "roof":
		prompt = _place_lamp(id)
	elif id != "" and info["type"] == "food":
		prompt = "Sol tık: %s" % ("İç" if float(info["water"]) > float(info["food"]) else "Ye")
		if Input.is_action_just_pressed("use"):
			_consume(id, info)
	if target != null and prompt == "":
		prompt = target.prompt(self)
		# Kurulu yapıyı (sandık, masa, yatak...) R ile 90° çevir; çekiç ve yerleştirme R'yi kendisi kullanır.
		if target.get("kind") != null and String(target.kind) != "" and target.kind != "yelken":
			prompt += ("  ·  " if prompt != "" else "") + "R: Döndür"
		if target.get("kind") != null and String(target.kind) != "" and target.get("showcase") != true and target.get_parent() == main.raft:
			prompt += ("  ·  " if prompt != "" else "") + "T: Taşı"
			if Input.is_action_just_pressed("carry"):
				pick_up(target)
				return
			if Input.is_action_just_pressed("remove"):
				main.raft.rotate_building(target)
				main.audio.play("build", -8.0)
	# Yakındaki enkazı E ile topla (suda, salda ya da adanın kıyısında).
	if target == null and prompt == "":
		var d = _nearby_debris()
		if d != null:
			prompt = "E: Topla (%s)" % ("Varil" if d.kind == "varil" else ("Şişedeki not" if d.kind == "sise" else Items.name_of(d.kind)))
			if Input.is_action_just_pressed("interact"):
				var l: Dictionary = d.loot()
				main.remove_debris(d)
				for k in l:
					give(k, l[k])
	if target != null and Input.is_action_just_pressed("interact"):
		target.interact(self)
	main.hud.set_prompt(prompt)


## Erişilebilen en yakın enkaz (2.8 m içinde, yüzünü döndüğün taraf öncelikli).
func _nearby_debris():
	var best = null
	var best_s := INF
	var fwd := -camera.global_transform.basis.z
	for d in main.debris:
		if d.hooked:
			continue
		var to: Vector3 = d.global_position - camera.global_position
		var dist := to.length()
		if dist > 2.8:
			continue
		var s := dist - fwd.dot(to / maxf(dist, 0.01)) * 1.5
		if s < best_s:
			best_s = s
			best = d
	return best


func _looked_target():
	if ray.is_colliding():
		var c = ray.get_collider()
		if c != null and c.has_meta("target"):
			var t = c.get_meta("target")
			if is_instance_valid(t) and camera.global_position.distance_to(ray.get_collision_point()) < REACH + 0.5:
				return t
	return null


func _consume(id: String, info: Dictionary) -> void:
	inv.take_slot(selected, 1)
	hunger = clampf(hunger + float(info["food"]), 0.0, 100.0)
	thirst = clampf(thirst + float(info["water"]), 0.0, 100.0)
	main.audio.play("drink" if float(info["water"]) > float(info["food"]) else "eat", -4.0)
	if id == "ham_balik":
		main.hud.toast("Çiğ balık midene dokundu. Izgarada pişirmek daha iyi.")


func _aim_cell() -> Dictionary:
	# Sal yüzeyine ya da su seviyesine bakılan nokta.
	var raft = main.raft
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	var hit := Vector3.ZERO
	if ray.is_colliding() and ray.get_collider() == raft:
		hit = ray.get_collision_point() - dir * 0.05
	elif dir.y < -0.05:
		var plane_y: float = raft.global_position.y
		var t: float = (plane_y - origin.y) / dir.y
		if t > 0.0 and t < BUILD_REACH:
			hit = origin + dir * t
		else:
			return {}
	else:
		return {}
	var local: Vector3 = raft.to_local(hit)
	return {"cell": raft.cell_from_local(local), "local": local}


func _show_ghost(size: Vector3, local_pos: Vector3, ok: bool, rot_y := 0.0) -> void:
	var b := BoxMesh.new()
	b.size = size
	ghost.mesh = b
	ghost.visible = true
	ghost.global_transform = main.raft.global_transform * Transform3D(Basis(Vector3.UP, rot_y), local_pos)
	ghost_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.35) if ok else Color(1.0, 0.3, 0.3, 0.35)


## Yapı sekmesinden seçilen ev parçası: çekiç ele alınır, parça seçilir, menü kapanır.
func choose_piece(i: int) -> void:
	var slot := -1
	for k in HOTBAR:
		var s = inv.slots[k]
		if s != null and s["id"] == "cekic":
			slot = k
			break
	if slot < 0:
		main.hud.toast("Önce alet çubuğunda bir Çekiç olmalı.")
		return
	selected = slot
	build_piece = i
	if main.hud.menu_open:
		main.hud.close_menus()
	main.hud.toast("%s seçildi: kurmak istediğin yere bakıp sol tık." % Items.PIECES[i][1], 5.0)


func _hammer(target) -> String:
	var raft = main.raft
	var piece: Array = Items.PIECES[build_piece]
	var pid: String = piece[0]
	var cost: Dictionary = piece[2]
	var hint := "Çekiç: %s (%s) · Sol tık inşa · E onar · R sök · Parça: Tab → Yapı" % [piece[1], Items.cost_text(cost)]
	# Yapı sökme
	if target != null and target.get("kind") != null and String(target.kind) != "":
		if Input.is_action_just_pressed("remove"):
			var k: String = target.kind
			# İçindekiler yalnız oyuncu söktüğünde ona geçer (taşıma, yükleme ve sıfırlamada değil)
			var contents: Array = target.storage.slots.duplicate(true) if target.get("storage") != null else []
			if not raft.remove_building_node(target):
				main.hud.toast("Önce üstteki sandığı kaldır.")
				return ""
			give(k, 1)
			for s in contents:
				if s != null:
					inv.add(s["id"], s["n"], s["dur"])
			main.audio.play("build", -4.0)
			return ""
		return "R: Sök (%s)  ·  %s" % [Items.name_of(target.kind), target.prompt(self)]
	var aim := _aim_cell()
	if aim.is_empty():
		return hint
	var c: Vector2i = aim["cell"]
	var local: Vector3 = aim["local"]
	var cp: Vector3 = raft.cell_pos(c)
	var off: Vector3 = local - cp
	var side := "N"
	if absf(off.x) > absf(off.z):
		side = "E" if off.x > 0.0 else "W"
	else:
		side = "S" if off.z > 0.0 else "N"
	# Duvar / çatı sökme (bakılan parça)
	if Input.is_action_just_pressed("remove"):
		var removed := ""
		if local.y > raft.ROOF_Y - 0.4 and raft.has_structure(c, "roof"):
			removed = raft.remove_structure(c, "roof")
		elif local.y > 0.35 and raft.has_structure(c, side):
			removed = raft.remove_structure(c, side)
		if removed != "":
			var base_kind := removed.replace("+lamba", "")
			for p in Items.PIECES:
				if p[0] == base_kind:
					for k in p[2]:
						give(k, p[2][k])
			if removed.ends_with("+lamba"):
				give("tavan_lambasi", 1)
			main.audio.play("build", -4.0)
			return hint
	if pid == "guclendir":
		if not raft.has_tile(c):
			return hint
		if raft.is_metal(c):
			return "Bu zemin zaten güçlendirilmiş  ·  " + hint
		_show_ghost(Vector3(raft.CELL, 0.04, raft.CELL), raft.cell_pos(c) + Vector3(0, raft.top_y(), 0), inv.has_all(cost))
		if Input.is_action_just_pressed("use"):
			if inv.spend(cost):
				raft.reinforce(c)
				main.quests.event("build", "guclendir")
				main.audio.play("metal", -2.0)
				main.audio.play("build", -4.0)
			else:
				main.hud.toast("Yetersiz malzeme: " + Items.cost_text(cost))
		return hint
	if pid != "zemin":
		return _build_piece(pid, cost, c, side, cp, hint)
	if raft.has_tile(c):
		if Input.is_action_just_pressed("remove"):
			if raft.can_remove(c):
				raft.remove_tile(c, false)
				give("tahta", 1)
				give("plastik", 1)
			else:
				main.hud.toast("Bu karo sökülemez (merkez, üstünde yapı var ya da salı böler)")
		if raft.needs_repair(c):
			if Input.is_action_just_pressed("interact"):
				if inv.spend(Items.REPAIR_COST):
					raft.repair(c)
					main.audio.play("build", -2.0)
				else:
					main.hud.toast("Onarım için 1 tahta gerekli")
			return "E: Onar (1 tahta)  ·  " + hint
		return hint
	if not raft.can_build(c):
		return hint
	var ok: bool = inv.has_all(Items.FOUNDATION_COST)
	_show_ghost(Vector3(raft.CELL - 0.03, raft.TILE_H, raft.CELL - 0.03), raft.cell_pos(c), ok)
	if Input.is_action_just_pressed("use"):
		if inv.spend(Items.FOUNDATION_COST):
			raft.add_tile(c)
			main.quests.event("build", "zemin")
			main.audio.play("build", 0.0)
		else:
			main.hud.toast("Yetersiz malzeme: " + Items.cost_text(Items.FOUNDATION_COST))
	return hint


## Duvar, kapılı duvar, pencereli duvar ya da çatı inşası (önizlemeli).
func _build_piece(pid: String, cost: Dictionary, c: Vector2i, side: String, cp: Vector3, hint: String) -> String:
	var raft = main.raft
	var ok: bool
	var size: Vector3
	var pos: Vector3
	var top: float = raft.top_y()
	if pid == "cati":
		ok = raft.can_build_structure("cati", c, "roof")
		size = Vector3(raft.CELL + 0.2, 0.5, raft.CELL + 0.2)
		pos = cp + Vector3(0, top + raft.ROOF_Y + 0.25, 0)
	else:
		ok = raft.can_build_structure(pid, c, side)
		var ns := side == "N" or side == "S"
		size = Vector3(raft.CELL, raft.WALL_H, 0.1) if ns else Vector3(0.1, raft.WALL_H, raft.CELL)
		var edge := {"N": Vector3(0, 0, -0.75), "S": Vector3(0, 0, 0.75), "W": Vector3(-0.75, 0, 0), "E": Vector3(0.75, 0, 0)}
		pos = cp + edge[side] + Vector3(0, top + raft.WALL_H / 2.0, 0)
	if not raft.has_tile(c) and pid == "cati":
		return hint
	var affordable: bool = inv.has_all(cost)
	_show_ghost(size, pos, ok and affordable)
	if ok and Input.is_action_just_pressed("use"):
		if inv.spend(cost):
			raft.add_structure(pid, c, side)
			main.quests.event("build", pid)
			main.audio.play("build", 0.0)
		else:
			main.hud.toast("Yetersiz malzeme: " + Items.cost_text(cost))
	return hint


## Tavan lambasını çatısı olan karoya as.
func _place_lamp(id: String) -> String:
	var raft = main.raft
	var aim := _aim_cell()
	var hint := "Sol tık: %s as (çatılı bir karoya bak)" % Items.name_of(id)
	if aim.is_empty():
		return hint
	var c: Vector2i = aim["cell"]
	if not raft.has_structure(c, "roof"):
		return hint
	_show_ghost(Vector3(0.25, 0.4, 0.25), raft.cell_pos(c) + Vector3(0, raft.top_y() + raft.ROOF_Y - 0.4, 0), true)
	if Input.is_action_just_pressed("use") and raft.add_lamp(c):
		inv.take_slot(selected, 1)
		main.audio.play("build", -2.0)
	return hint


func _place(id: String) -> String:
	var raft = main.raft
	var aim := _aim_cell()
	var hint := "Sol tık: %s yerleştir (sal karosunun üstüne)" % Items.name_of(id)
	if aim.is_empty() or not raft.has_tile(aim["cell"]):
		return hint
	var c: Vector2i = aim["cell"]
	# Sandık başka bir sandığın üstüne istiflenebilir (en fazla 6 kat).
	if id == "sandik" and raft.can_stack(c):
		var lvl: int = raft.stacks.get(c, []).size() + 1
		var base: Node3D = raft.buildings[c]
		var ssize: Vector3 = BuildingScript.SIZES["sandik"]
		_show_ghost(ssize, raft.cell_pos(c) + Vector3(0, raft.top_y() + raft.CHEST_H * lvl + ssize.y / 2.0, 0), true, base.rotation.y)
		if Input.is_action_just_pressed("use"):
			raft.stack_chest(c)
			main.quests.event("build", "sandik")
			inv.take_slot(selected, 1)
			main.audio.play("build", 0.0)
		return "Sol tık: Sandığı üstüne koy (%d. kat)" % (lvl + 1)
	var ok: bool = raft.can_place_building(c)
	var size: Vector3 = BuildingScript.SIZES[id]
	if Input.is_action_just_pressed("remove"):
		place_turn = (place_turn + 1) % 4
		main.audio.play("click", -8.0, "Arayuz")
	# Ağ önce dışa bakar; R her basışta 90° çevirir.
	var rot_y: float = (raft.outward_angle(c) if id == "toplayici" else 0.0) + place_turn * PI / 2.0
	var gpos: Vector3 = raft.cell_pos(c) + Vector3(0, raft.top_y() + size.y / 2.0, 0)
	if id == "toplayici":
		# Önizleme ağın sarktığı kenara doğru uzanır: yönü görünsün.
		size = Vector3(1.4, 0.06, 1.5)
		gpos += Basis(Vector3.UP, rot_y) * Vector3(0, -0.03, 0.4)
	elif id == "hali":
		# Halı iki karo boyunda: baktığı yöndeki komşu karo da olmalı.
		size = Vector3(1.4, 0.04, 2.9)
		gpos += Basis(Vector3.UP, rot_y) * Vector3(0, 0, 0.75)
		ok = ok and raft.has_tile(c + Vector2i(roundi(sin(rot_y)), roundi(cos(rot_y))))
	_show_ghost(size, gpos, ok, rot_y)
	hint += " · R: döndür"
	if ok and Input.is_action_just_pressed("use"):
		var b = raft.place_building(id, c, {}, rot_y)
		main.quests.event("build", id)
		if id == "yelken":
			var f: Vector3 = -camera.global_transform.basis.z
			f.y = 0.0
			b.dir = f.normalized()
			b._update_sail()
		inv.take_slot(selected, 1)
		main.audio.play("build", 0.0)
	return hint


## Kurulu yapıyı içindekiler ve ayarlarıyla kaldırır. Sandık kulesinde bakılan sandık ve üstündekiler birlikte gelir.
func pick_up(b) -> void:
	var raft = main.raft
	var c: Vector2i = b.cell
	var group: Array = []
	if b.level == 0:
		group.append(b)
	for s in raft.stacks.get(c, []):
		if s.level >= maxi(1, b.level):
			group.append(s)
	carry = []
	for g in group:
		carry.append(g.to_data())
	for i in range(group.size() - 1, -1, -1):
		raft.remove_building_node(group[i])
	carry_rot = float(carry[0].get("rot", 0.0))
	carry_from = c
	main.audio.play("build", -6.0)


## Taşınan yapıyı bırakır: boş karoya ya da (sandıksa) başka bir sandık kulesinin üstüne.
func _carry_step() -> String:
	var raft = main.raft
	var kind: String = carry[0]["kind"]
	var n := carry.size()
	var label := Items.name_of(kind) if n == 1 else "%d sandık" % n
	var hint := "Taşınıyor: %s · Sol tık: Bırak · R: Döndür · T / sağ tık: Geri koy" % label
	if Input.is_action_just_pressed("carry") or Input.is_action_just_pressed("cancel"):
		drop_carry_back()
		return ""
	if Input.is_action_just_pressed("remove"):
		carry_rot = wrapf(carry_rot + PI / 2.0, -PI, PI)
		main.audio.play("click", -8.0, "Arayuz")
	var aim := _aim_cell()
	if aim.is_empty() or not raft.has_tile(aim["cell"]):
		return hint
	var c: Vector2i = aim["cell"]
	var size: Vector3 = BuildingScript.SIZES[kind]
	# Sandık(lar) başka bir sandığın üstüne
	if kind == "sandik" and raft.buildings.has(c) and raft.buildings[c].kind == "sandik":
		var have: int = raft.stacks.get(c, []).size()
		var ok: bool = have + n <= raft.STACK_MAX
		var base: Node3D = raft.buildings[c]
		var h: float = size.y + raft.CHEST_H * (n - 1)
		_show_ghost(Vector3(size.x, h, size.z), raft.cell_pos(c) + Vector3(0, raft.top_y() + raft.CHEST_H * (have + 1) + h / 2.0, 0), ok, base.rotation.y)
		if ok and Input.is_action_just_pressed("use"):
			for d in carry:
				d["rot"] = base.rotation.y
				raft.stack_chest(c, d)
			_carry_done()
		return hint if ok else "Bu kule çok yüksek olur (en fazla %d kat)" % (raft.STACK_MAX + 1)
	var ok2: bool = raft.can_place_building(c)
	var h2: float = size.y + (raft.CHEST_H * (n - 1) if kind == "sandik" else 0.0)
	var gpos: Vector3 = raft.cell_pos(c) + Vector3(0, raft.top_y() + h2 / 2.0, 0)
	var gsize := Vector3(size.x, h2, size.z)
	if kind == "hali":
		gsize = Vector3(1.4, 0.04, 2.9)
		gpos += Basis(Vector3.UP, carry_rot) * Vector3(0, 0, 0.75)
		ok2 = ok2 and raft.has_tile(c + Vector2i(roundi(sin(carry_rot)), roundi(cos(carry_rot))))
	_show_ghost(gsize, gpos, ok2, carry_rot)
	if ok2 and Input.is_action_just_pressed("use"):
		_put(c, carry_rot)
		_carry_done()
	return hint


func _put(c: Vector2i, rot: float) -> void:
	var raft = main.raft
	for i in carry.size():
		var d: Dictionary = carry[i]
		d["rot"] = rot
		d["cell"] = [c.x, c.y]
		if i == 0:
			raft.place_building(d["kind"], c, d, rot)
		else:
			raft.stack_chest(c, d)


func _carry_done() -> void:
	carry = []
	main.audio.play("build", 0.0)


## Taşınan yapıyı geldiği yere geri koyar; orası dolduysa boş bir karoya, hiç yer yoksa envantere.
func drop_carry_back() -> void:
	if carry.is_empty():
		return
	var raft = main.raft
	# Kulenin üstünden alınan sandıklar yine kuleye döner
	if carry[0]["kind"] == "sandik" and raft.buildings.has(carry_from) and raft.buildings[carry_from].kind == "sandik" and raft.stacks.get(carry_from, []).size() + carry.size() <= raft.STACK_MAX:
		for d in carry:
			d["rot"] = raft.buildings[carry_from].rotation.y
			raft.stack_chest(carry_from, d)
		carry = []
		return
	var spot := Vector2i(9999, 9999)
	if raft.has_tile(carry_from) and raft.can_place_building(carry_from):
		spot = carry_from
	else:
		var best := INF
		for c in raft.tiles:
			if raft.can_place_building(c) and Vector2(c - carry_from).length() < best:
				best = Vector2(c - carry_from).length()
				spot = c
	if spot != Vector2i(9999, 9999):
		_put(spot, float(carry[0].get("rot", 0.0)))
	else:
		for d in carry:
			give(d["kind"], 1)
	carry = []


func _spear(delta: float, dmg: int) -> void:
	spear_cd -= delta
	if Input.is_action_just_pressed("use") and spear_cd <= 0.0:
		spear_cd = 0.6
		swing = 1.0
		main.audio.play("spear_swing", -6.0)
		if main.shark.try_hit(camera.global_position, -camera.global_transform.basis.z, SPEAR_REACH, dmg):
			use_durability()


## Balta: adadaki ağaca bakıp sol tıkla kes.
func _axe(delta: float, target) -> String:
	return _tool_swing(delta, target, "chop")


## Kazma: kayaya bakıp sol tıkla kaz.
func _pickaxe(delta: float, target) -> String:
	return _tool_swing(delta, target, "mine")


## Tıklayınca yay başlar; hedef, alet indiği anda (vuruş noktası) hâlâ menzildeyse isabet alır.
func _tool_swing(delta: float, target, method: String) -> String:
	if tool_t >= 0.0:
		tool_t += delta
		if not tool_hit_done and tool_t >= HIT_AT:
			tool_hit_done = true
			if tool_target != null and is_instance_valid(tool_target) and tool_target.has_method(method) 					and tool_target.global_position.distance_to(global_position) < REACH + 2.5:
				tool_target.call(method, self)
				use_durability()
			else:
				main.audio.play("spear_swing", -10.0)
		if tool_t >= SWING_DUR:
			tool_t = -1.0
	var valid: bool = target != null and target.has_method(method)
	if Input.is_action_just_pressed("use") and tool_t < 0.0:
		tool_t = 0.0
		tool_hit_done = false
		tool_target = target if valid else null
	return target.prompt(self) if valid else ""


func to_data() -> Dictionary:
	var lp: Vector3 = main.raft.to_local(global_position)
	return {"inv": inv.to_data(), "sel": selected, "hp": health, "food": hunger, "water": thirst,
		"gear": gear.duplicate(), "tank": tank_air, "depth": max_depth,
		"on_raft": not in_water and lp.y > -1.0 and lp.length() < 30.0, "local": [lp.x, lp.y, lp.z],
		"world": [global_position.x, global_position.y, global_position.z], "yaw": rotation.y,
		"carry": carry.duplicate(true), "carry_from": [carry_from.x, carry_from.y]}


func from_data(d: Dictionary) -> void:
	inv.from_data(d.get("inv", []))
	selected = int(d.get("sel", 0))
	health = float(d.get("hp", 100.0))
	hunger = float(d.get("food", 100.0))
	thirst = float(d.get("water", 100.0))
	var gd: Dictionary = d.get("gear", {})
	gear = {"tup": String(gd.get("tup", "")), "palet": String(gd.get("palet", "")), "fener": String(gd.get("fener", ""))}
	tank_air = float(d.get("tank", 0.0))
	max_depth = float(d.get("depth", 0.0))
	carry = d.get("carry", []).duplicate(true)
	var cf: Array = d.get("carry_from", [0, 0])
	carry_from = Vector2i(int(cf[0]), int(cf[1]))
	if not carry.is_empty():
		carry_rot = float(carry[0].get("rot", 0.0))
	rotation.y = float(d.get("yaw", 0.0))
	if d.get("on_raft", true):
		var l: Array = d.get("local", [0.75, 0.5, 0.75])
		global_position = main.raft.to_global(Vector3(l[0], maxf(l[1], 0.3), l[2]))
	else:
		var w: Array = d.get("world", [0.0, 1.0, 0.0])
		global_position = Vector3(w[0], w[1], w[2])
	velocity = Vector3.ZERO
