extends Node3D
## Olta (gerçekçi balıkçılık):
## 1) Sol tık basılı tut: atış gücü dolar, bırakınca şamandıra atılır.
## 2) Bekle: şamandıra ara sıra titrer (balık yokluyor); erken çekersen balık ürker.
## 3) Şamandıra suya gömülünce (asıl vuruş) hemen sol tık: kancayı tak.
## 4) Mücadele: sol tık basılı = makarayı sar (misina gerilir), bırak = boşluk ver.
##    Balık kaçışa geçtiğinde sararsan misina kopar; çok gevşek bırakırsan balık kurtulur.
##    Balık yoruldukça yaklaşır; yanına gelince çekilir. Ege balıkları türüne ve ağırlığına göre farklı dövüşür.
## Sağ tık: oltayı topla.

const Waves = preload("res://scripts/waves.gd")
const HookScript = preload("res://scripts/hook.gd")
const ToolModels = preload("res://scripts/tool_models.gd")

enum F { IDLE, CHARGING, FLYING, WAITING, BITE, FIGHT }

## Ege balıkları: [ad, en az kg, en çok kg, güç, dayanıklılık, şans]
const SPECIES := [
	["İstavrit", 0.1, 0.35, 0.35, 3.0, 30],
	["Çipura", 0.3, 1.2, 0.55, 5.0, 24],
	["Levrek", 0.5, 2.5, 0.7, 6.5, 20],
	["Lüfer", 0.8, 3.0, 0.9, 7.5, 13],
	["Palamut", 1.0, 3.5, 1.0, 8.0, 10],
	["Orfoz", 4.0, 12.0, 1.35, 12.0, 3],
]

var main
var state := F.IDLE
var vel := Vector3.ZERO
var timer := 0.0
var power := 0.0
var bobber: Node3D
var line: MeshInstance3D
var splash: GPUParticles3D

# Bekleme ve vuruş
var nibble_t := 0.0
var dip := 0.0

# Mücadele
var fish: Array = []
var fish_kg := 0.0
var dist := 10.0
var side_ang := 0.0
var side_vel := 0.0
var cast_dir := Vector3.FORWARD
var tension := 0.0
var stamina := 1.0
var run_t := 0.0
var slack_t := 0.0
var reel_cd := 0.0
var leap_cd := 3.0
var leaper: Node3D
var leap_t := -1.0
var leap_from := Vector3.ZERO

# Arayüz (ilk kullanımda HUD'a eklenir)
var ui: Control
var ui_status: Label
var ui_bar_bg: ColorRect
var ui_bar: ColorRect
var ui_info: Label


func _ready() -> void:
	# Oyuncu hareket ettikten sonra güncellensin: misina oltanın ucundan kopuk görünmesin.
	process_priority = 10
	bobber = Node3D.new()
	add_child(bobber)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.12, 0.1)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.95, 0.95)
	for i in 2:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radial_segments = 20
		sm.rings = 10
		sm.radius = 0.06
		sm.height = 0.12 if i == 0 else 0.06
		s.mesh = sm
		s.position.y = 0.0 if i == 0 else 0.04
		s.material_override = white if i == 0 else red
		bobber.add_child(s)
	var stick := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.008
	cm.bottom_radius = 0.008
	cm.height = 0.12
	stick.mesh = cm
	stick.position.y = 0.1
	stick.material_override = red
	bobber.add_child(stick)
	line = MeshInstance3D.new()
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line.extra_cull_margin = 16384.0
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.9, 0.9, 0.9)
	line.material_override = lm
	line.top_level = true
	add_child(line)
	splash = HookScript.make_splash()
	add_child(splash)
	leaper = ToolModels.fish(false)
	leaper.top_level = true
	leaper.visible = false
	add_child(leaper)
	visible = false


func is_out() -> bool:
	return state != F.IDLE and state != F.CHARGING


func reset() -> void:
	state = F.IDLE
	visible = false
	tension = 0.0
	if leaper != null:
		leaper.visible = false
	leap_t = -1.0
	_ui_show(false)


# --- Arayüz -------------------------------------------------------------------

func _ui_make() -> void:
	if ui != null or main.hud == null or main.hud.root == null:
		return
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.anchor_left = 0.5
	ui.anchor_right = 0.5
	ui.anchor_top = 1.0
	ui.anchor_bottom = 1.0
	ui.offset_left = -170
	ui.offset_right = 170
	ui.offset_top = -200
	ui.offset_bottom = -120
	main.hud.root.add_child(ui)
	ui_status = Label.new()
	ui_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_status.add_theme_font_size_override("font_size", 16)
	ui_status.add_theme_constant_override("outline_size", 6)
	ui_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	ui_status.size = Vector2(340, 24)
	ui.add_child(ui_status)
	ui_bar_bg = ColorRect.new()
	ui_bar_bg.color = Color(0, 0, 0, 0.55)
	ui_bar_bg.position = Vector2(20, 30)
	ui_bar_bg.size = Vector2(300, 12)
	ui.add_child(ui_bar_bg)
	# Tehlike bölgesi (sağ uç kırmızı)
	var danger := ColorRect.new()
	danger.color = Color(0.8, 0.15, 0.1, 0.45)
	danger.position = Vector2(300 * 0.8, 0)
	danger.size = Vector2(300 * 0.2, 12)
	ui_bar_bg.add_child(danger)
	ui_bar = ColorRect.new()
	ui_bar.size = Vector2(0, 12)
	ui_bar_bg.add_child(ui_bar)
	ui_info = Label.new()
	ui_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_info.add_theme_font_size_override("font_size", 13)
	ui_info.add_theme_constant_override("outline_size", 5)
	ui_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	ui_info.position = Vector2(0, 46)
	ui_info.size = Vector2(340, 20)
	ui.add_child(ui_info)
	ui.visible = false


func _ui_show(on: bool, status := "", bar := -1.0, bar_col := Color.WHITE, info := "") -> void:
	if not on:
		if ui != null:
			ui.visible = false
		return
	_ui_make()
	if ui == null:
		return
	ui.visible = not main.hud.menu_open
	ui_status.text = status
	ui_bar_bg.visible = bar >= 0.0
	if bar >= 0.0:
		ui_bar.size.x = 300.0 * clampf(bar, 0.0, 1.0)
		ui_bar.color = bar_col
	ui_info.text = info


# --- Balık ----------------------------------------------------------------------

func _pick_species() -> Array:
	var total := 0
	for s in SPECIES:
		total += int(s[5])
	var r := randi() % total
	for s in SPECIES:
		r -= int(s[5])
		if r < 0:
			return s
	return SPECIES[0]


## Günün saati: şafak ve alacakaranlıkta balık daha çok vurur, gece az.
func _bite_wait() -> float:
	var h: float = main.world.hour
	var k := 1.0
	if (h > 5.0 and h < 8.5) or (h > 17.5 and h < 20.5):
		k = 0.6
	elif main.world.is_night():
		k = 1.35
	return randf_range(6.0, 16.0) * k


func _fish_pos(p) -> Vector3:
	var flat := Vector3(p.global_position.x, 0, p.global_position.z)
	var d := cast_dir.rotated(Vector3.UP, side_ang)
	var pos := flat + d * dist
	pos.y = Waves.height(pos.x, pos.z)
	return pos


# --- Döngü -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if main.paused:
		return
	var p = main.player
	var holding: bool = p.held_id() == "olta"
	var using: bool = holding and p.can_act()
	var tip: Vector3 = p.rod_tip()
	var bend := 0.0
	match state:
		F.IDLE:
			if using:
				_ui_show(true, "Sol tık basılı tut: atış gücü", -1.0)
				if Input.is_action_just_pressed("use"):
					state = F.CHARGING
					power = 0.0
			else:
				_ui_show(false)
		F.CHARGING:
			power = minf(1.0, power + delta * 0.8)
			_ui_show(true, "Bırak: at", power, Color(1.0, 0.85, 0.3), "%d m" % int(lerpf(5.0, 18.0, power)))
			if not using:
				state = F.IDLE
			elif not Input.is_action_pressed("use"):
				cast(p, power)
		F.FLYING:
			vel.y -= 9.8 * delta
			global_position += vel * delta
			if global_position.y <= Waves.height(global_position.x, global_position.z):
				state = F.WAITING
				timer = _bite_wait()
				nibble_t = randf_range(1.5, 4.0)
				splash.global_position = global_position
				splash.restart()
				main.audio.play_at("splash", global_position, -10.0)
		F.WAITING:
			timer -= delta
			nibble_t -= delta
			_ui_show(true, "Şamandırayı izle...", -1.0, Color.WHITE, "Titremesi yoklamadır; batınca çek")
			if nibble_t <= 0.0:
				# Yoklama: küçük titreme
				nibble_t = randf_range(1.5, 5.0)
				dip = 0.04
				main.audio.play_at("fish_bite", global_position, -14.0, 3.0)
			if timer <= 0.0:
				state = F.BITE
				timer = randf_range(0.7, 1.1)
				dip = 0.25
				splash.global_position = global_position
				splash.restart()
				main.audio.play_at("fish_bite", global_position, 2.0)
			elif using and Input.is_action_just_pressed("use"):
				main.hud.toast("Çok erken çektin; balık ürktü.", 2.0)
				timer = _bite_wait() + 4.0
				nibble_t = randf_range(3.0, 6.0)
		F.BITE:
			timer -= delta
			_ui_show(true, "ŞİMDİ! Sol tık: kancayı tak", -1.0)
			if using and Input.is_action_just_pressed("use"):
				start_fight(p)
			elif timer <= 0.0:
				main.hud.toast("Geç kaldın, balık yemi alıp kaçtı.", 2.0)
				state = F.WAITING
				timer = _bite_wait()
		F.FIGHT:
			bend = fight_step(delta, p, using and Input.is_action_pressed("use"))
	# Şamandıra suda: dalga ile iner çıkar, yoklama ve vuruşta batar
	if state == F.WAITING or state == F.BITE:
		dip = maxf(0.0, dip - delta * (0.6 if state == F.BITE else 0.4))
		var sink := dip if state == F.WAITING else 0.25 + sin(timer * 30.0) * 0.04
		global_position.y = Waves.height(global_position.x, global_position.z) - sink
	if is_out() and (Input.is_action_just_pressed("cancel") or not holding or global_position.distance_to(p.global_position) > 30.0):
		if state == F.FIGHT:
			main.hud.toast("Oltayı topladın; balık kaçtı.", 2.0)
		reset()
	_update_rod(p, bend)
	_update_line(tip)
	_update_leap(delta)


## Şamandırayı at (güç 0..1).
func cast(p, pw: float) -> void:
	global_position = p.rod_tip()
	var fwd: Vector3 = -p.camera.global_transform.basis.z
	var flat := Vector3(fwd.x, 0, fwd.z).normalized()
	vel = flat * lerpf(4.0, 11.0, pw) + Vector3.UP * lerpf(2.0, 4.0, pw)
	cast_dir = flat
	state = F.FLYING
	visible = true
	main.audio.play("hook_throw", -6.0)


func start_fight(p) -> void:
	fish = _pick_species()
	fish_kg = snappedf(randf_range(fish[1], fish[2]), 0.05)
	var to: Vector3 = global_position - p.global_position
	to.y = 0.0
	dist = maxf(to.length(), 4.0)
	cast_dir = to.normalized() if to.length() > 0.1 else cast_dir
	side_ang = 0.0
	side_vel = 0.0
	tension = 0.35
	stamina = 1.0
	run_t = 0.0
	slack_t = 0.0
	leap_cd = randf_range(2.0, 4.0)
	state = F.FIGHT
	splash.global_position = global_position
	splash.restart()
	main.audio.play_at("splash", global_position, -2.0)
	main.hud.toast("Kanca tuttu!", 1.5)


## Mücadele adımı: sararken gerginlik artar, bırakınca azalır. Kaçış sırasında sarmak misinayı koparabilir.
## Olta eğilme miktarını döndürür.
func fight_step(delta: float, p, reeling: bool) -> float:
	var strength: float = float(fish[3]) * (0.7 + fish_kg / maxf(float(fish[2]), 0.1) * 0.6)
	# Kaçışlar: balık ara sıra güçlü çeker (yorgunken daha seyrek)
	run_t -= delta
	var running := run_t > 0.0
	if run_t < -randf_range(1.5, 4.0) * (2.0 - stamina):
		run_t = randf_range(0.8, 1.8) * (0.5 + stamina)
		main.audio.play_at("splash", global_position, -8.0)
	var pull := strength * (1.8 if running else 0.55) * (0.35 + 0.65 * stamina)
	if reeling:
		tension += (0.35 + pull * 0.9) * delta
		dist -= maxf(0.2, 1.6 - pull * 0.9) * delta
		reel_cd -= delta
		if reel_cd <= 0.0:
			reel_cd = 0.2
			main.audio.play("reel", -14.0)
	else:
		tension -= (0.55 - pull * 0.25) * delta
		dist += pull * 1.1 * delta
	tension = clampf(tension, 0.0, 1.0)
	dist = clampf(dist, 0.0, 26.0)
	# Gergin misina balığı yorar
	stamina = maxf(0.0, stamina - delta * (0.15 + tension) * 1.2 / float(fish[4]))
	# Balık sağa sola kaçar
	side_vel += randf_range(-1.0, 1.0) * delta * (2.0 if running else 0.8)
	side_vel *= 0.98
	side_ang = clampf(side_ang + side_vel * delta, -0.9, 0.9)
	global_position = _fish_pos(p) - Vector3(0, 0.08 + 0.1 * tension, 0)
	# Sonuçlar
	if tension >= 1.0:
		main.hud.toast("Misina koptu! %s kaçtı." % fish[0], 2.5)
		main.audio.play("tile_break", -6.0)
		p.use_durability()
		p.use_durability()
		reset()
		return 0.0
	if tension < 0.05 and stamina > 0.15:
		slack_t += delta
		if slack_t > 2.5:
			main.hud.toast("Misina gevşedi, %s kurtuldu." % fish[0], 2.5)
			reset()
			return 0.0
	else:
		slack_t = 0.0
	if dist < 2.2:
		_land(p)
		return 0.0
	# Sıçrama
	leap_cd -= delta
	if leap_cd <= 0.0 and leap_t < 0.0 and dist > 4.0:
		leap_cd = randf_range(3.0, 7.0)
		if randf() < 0.5 + 0.3 * float(fish[3]):
			leap_t = 0.0
			leap_from = global_position
			main.audio.play_at("splash", global_position, -4.0)
	var col := Color(0.4, 0.9, 0.45) if tension < 0.6 else (Color(1.0, 0.8, 0.25) if tension < 0.8 else Color(1.0, 0.3, 0.25))
	var hint := "KAÇIYOR! Bırak, boşluk ver" if running and tension > 0.5 else "Sol tık basılı: sar  ·  bırak: gevşet"
	_ui_show(true, hint, tension, col, "%s  ·  %d m  ·  güç %d%%" % [fish[0], int(dist), int(stamina * 100.0)])
	return tension * (1.2 if running else 0.8)


func _land(p) -> void:
	var n := 1 + int(fish_kg / 1.2)
	p.give("ham_balik", n)
	p.use_durability()
	main.audio.play_at("splash", p.global_position + Vector3(0, 0.5, 0), -4.0)
	main.hud.notify("%s yakaladın! %.2f kg" % [fish[0], fish_kg], Color(0.6, 0.85, 1.0), "ham_balik")
	if fish[0] == "Orfoz":
		main.hud.toast("Koca bir orfoz! Ege'de az rastlanır.", 3.0)
	reset()


# --- Görünüm ------------------------------------------------------------------------

## Mücadelede olta eğilir ve titrer.
func _update_rod(p, bend: float) -> void:
	if not p.hand_models.has("olta"):
		return
	var pivot: Node3D = p.hand_models["olta"]
	var base_rot: Vector3 = p.HOLD["olta"][1]
	var shake := sin(Time.get_ticks_msec() * 0.05) * 0.02 * bend
	pivot.rotation = base_rot + Vector3(-bend * 0.45 + shake, 0, shake)


func _update_line(tip: Vector3) -> void:
	line.visible = is_out()
	if not line.visible:
		return
	# Misina gerginken düz, gevşekken sarkık.
	var a := tip
	var b := global_position + Vector3.UP * 0.06
	var slack := 0.01 if state == F.FLYING else (0.035 if state != F.FIGHT else 0.04 * (1.0 - tension))
	var sag := minf(0.8, a.distance_to(b) * slack)
	var pts: Array = []
	for i in 17:
		var t := i / 16.0
		pts.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	line.global_transform = Transform3D.IDENTITY
	line.mesh = ToolModels.tube(pts, 0.0035, 5)


## Balık sudan sıçrar: kısa bir yay çizip geri dalar.
func _update_leap(delta: float) -> void:
	if leap_t < 0.0:
		leaper.visible = false
		return
	leap_t += delta
	var dur := 0.75
	var k := leap_t / dur
	if k >= 1.0:
		leap_t = -1.0
		leaper.visible = false
		splash.global_position = global_position
		splash.restart()
		main.audio.play_at("splash", global_position, -6.0)
		return
	var size := clampf(0.6 + fish_kg * 0.25, 0.6, 2.2)
	leaper.visible = true
	leaper.scale = Vector3.ONE * size
	var pos := leap_from.lerp(global_position, k) + Vector3.UP * (sin(k * PI) * (0.6 + 0.2 * size))
	leaper.global_position = pos
	leaper.rotation = Vector3(0, atan2(cast_dir.x, cast_dir.z), PI / 2.0 + lerpf(0.6, -0.6, k))
