extends Node3D
## Dünya: gece-gündüz döngüsü, hava durumu (yağmur / fırtına), güneş ve ay ışığı, ortam ayarları.

const Waves = preload("res://scripts/waves.gd")

## Bir oyun günü = 24 gerçek dakika (1 oyun saati = 1 dakika).
const DAY_MINUTES := 24.0

var main
var env: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_mat: ShaderMaterial
var rain_fx: GPUParticles3D

var hour := 7.5
var day := 1
var rain := 0.0
var raining := false
var weather_timer := 360.0
var t := 0.0

## Ege rüzgârları. Yön pusula açısıdır (derece, kuzeyden saat yönünde) ve rüzgârın ESTİĞİ yeri gösterir.
## Kuzey dünyada -Z, doğu +X.
const WIND_NAMES := [["Yıldız", "Kuzey"], ["Poyraz", "Kuzeydoğu"], ["Gündoğusu", "Doğu"], ["Keşişleme", "Güneydoğu"],
	["Kıble", "Güney"], ["Lodos", "Güneybatı"], ["Batı", "Batı"], ["Karayel", "Kuzeybatı"]]
## Yaz meltemi gibi: çoğunlukla kuzeyden eser. [estiği açı, ağırlık]
const WIND_ODDS := [[0.0, 22], [45.0, 26], [90.0, 6], [135.0, 5], [180.0, 7], [225.0, 9], [270.0, 9], [315.0, 16]]
var wind_from := 30.0
var wind_strength := 0.55
var wind_target_from := 30.0
var wind_target_strength := 0.55
var wind_timer := 240.0
var flash := 0.0
var thunder_timer := 8.0


func _ready() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.008
	noise.fractal_octaves = 5
	var tex := NoiseTexture2D.new()
	tex.width = 1024
	tex.height = 1024
	tex.seamless = true
	tex.generate_mipmaps = true
	tex.noise = noise
	sky_mat.set_shader_parameter("cloud_noise", tex)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_REALTIME

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.05
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.fog_enabled = true
	env.fog_density = 0.0018
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.12
	# Hacimsel sis: gece lambaların, meşalenin ve fenerin etrafında ışık halesi oluşturur.
	env.volumetric_fog_density = 0.0
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_albedo = Color(0.9, 0.9, 0.95)
	env.volumetric_fog_ambient_inject = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_blur = 1.5
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.shadow_enabled = false
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moon)

	_build_rain()


func _build_rain() -> void:
	rain_fx = GPUParticles3D.new()
	rain_fx.amount = 3500
	rain_fx.lifetime = 1.2
	rain_fx.local_coords = false
	rain_fx.emitting = false
	rain_fx.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 1, 16)
	pm.direction = Vector3(0.15, -1, 0)
	pm.spread = 3.0
	pm.initial_velocity_min = 16.0
	pm.initial_velocity_max = 20.0
	pm.gravity = Vector3(0, -9.8, 0)
	# Çatılara çarpan damla kaybolur: çatı altı kuru kalır.
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	rain_fx.collision_base_size = 0.02
	rain_fx.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.015, 0.45)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.75, 0.8, 0.88, 0.35)
	q.material = m
	rain_fx.draw_pass_1 = q
	add_child(rain_fx)


func time_text() -> String:
	return "Gün %d  ·  %02d:%02d" % [day, int(hour), int(fmod(hour, 1.0) * 60.0)]


func is_night() -> bool:
	return hour < 6.0 or hour > 20.0


## Rüzgârın estiği yön (pusula açısından dünya vektörü, uzunluğu 1).
static func bearing_vec(deg: float) -> Vector3:
	var r := deg_to_rad(deg)
	return Vector3(sin(r), 0.0, -cos(r))


## Rüzgârın götürdüğü yön × güç (0..1). Yelken ve sürüklenme bunu kullanır.
func wind_vector() -> Vector3:
	return -bearing_vec(wind_from) * wind_strength


func wind_name() -> String:
	var i := int(round(fposmod(wind_from, 360.0) / 45.0)) % 8
	# Öğleden sonra denizden karaya esen batı-kuzeybatı rüzgârı: İmbat
	if not raining and hour > 12.0 and hour < 19.0 and (i == 6 or i == 7) and wind_strength < 0.75:
		return "İmbat"
	return WIND_NAMES[i][0]


func wind_dir_name() -> String:
	return WIND_NAMES[int(round(fposmod(wind_from, 360.0) / 45.0)) % 8][1]


func wind_force_name() -> String:
	return "hafif" if wind_strength < 0.35 else ("orta" if wind_strength < 0.7 else "sert")


func _pick_wind() -> void:
	if raining:
		# Fırtına lodosla gelir
		wind_target_from = 225.0 + randf_range(-15.0, 15.0)
		wind_target_strength = randf_range(0.85, 1.0)
		return
	var total := 0
	for w in WIND_ODDS:
		total += int(w[1])
	var r := randi() % total
	for w in WIND_ODDS:
		r -= int(w[1])
		if r < 0:
			wind_target_from = float(w[0]) + randf_range(-18.0, 18.0)
			break
	# Öğleden sonra İmbat (batı-kuzeybatı) eğilimi
	if hour > 12.0 and hour < 18.0 and randf() < 0.45:
		wind_target_from = 290.0 + randf_range(-20.0, 20.0)
	wind_target_strength = randf_range(0.25, 0.8)


## Uyuyunca sabah 7'ye atla.
func sleep_to_morning() -> void:
	if hour > 7.0:
		day += 1
	hour = 7.0


func _process(delta: float) -> void:
	t += delta
	var frozen: bool = main.paused and main.menu.mode != "main"
	if not frozen:
		hour += delta * 24.0 / (DAY_MINUTES * 60.0)
	if hour >= 24.0:
		hour -= 24.0
		day += 1

	# Güneş: 06:00'da doğar, 18:00'de batar.
	var ang := (hour - 6.0) / 12.0 * PI
	var sun_dir := Vector3(cos(ang) * 0.8, sin(ang), 0.45).normalized()
	sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.RIGHT)
	var daylight := clampf(sun_dir.y * 4.0 + 0.2, 0.0, 1.0)
	sun.light_energy = daylight * lerpf(1.35, 0.45, rain)
	sun.visible = sun.light_energy > 0.01
	var dusk := 1.0 - smoothstep(0.0, 0.35, absf(sun_dir.y))
	sun.light_color = Color(1.0, 0.95, 0.86).lerp(Color(1.0, 0.6, 0.35), dusk)
	# Ay da güneş gibi güney göğünde yay çizer (kuzeyde Kutup Yıldızı'nın yanına düşmez)
	var moon_dir := Vector3(-sun_dir.x, -sun_dir.y, sun_dir.z)
	moon.look_at_from_position(Vector3.ZERO, -moon_dir, Vector3.UP if absf(moon_dir.y) < 0.99 else Vector3.RIGHT)
	moon.light_energy = clampf(moon_dir.y * 3.0, 0.0, 1.0) * 0.28
	moon.visible = moon.light_energy > 0.01

	# Hava durumu: belirli aralıklarla yağmur / fırtına.
	if not frozen:
		weather_timer -= delta
	if weather_timer <= 0.0:
		raining = not raining
		weather_timer = randf_range(150.0, 300.0) if raining else randf_range(420.0, 840.0)
		if raining:
			main.hud.toast("Hava kararıyor... Yağmur başlıyor.")
	rain = move_toward(rain, 1.0 if raining else 0.0, delta / 25.0)
	# Rüzgâr: birkaç oyun saatinde bir yön değiştirir, yavaşça döner
	if not frozen:
		wind_timer -= delta
		if wind_timer <= 0.0:
			wind_timer = randf_range(180.0, 420.0)
			_pick_wind()
		wind_from = rad_to_deg(lerp_angle(deg_to_rad(wind_from), deg_to_rad(wind_target_from), minf(1.0, delta * 0.03)))
		wind_strength = move_toward(wind_strength, wind_target_strength, delta * 0.01)
	# Lodos fırtınasında şimşek ve gök gürültüsü
	flash = maxf(0.0, flash - delta * 3.5)
	if rain > 0.75 and not frozen:
		thunder_timer -= delta
		if thunder_timer <= 0.0:
			thunder_timer = randf_range(9.0, 26.0)
			flash = 1.0
			var dly := randf_range(0.4, 2.5)
			get_tree().create_timer(dly).timeout.connect(func(): main.audio.play("thunder", -2.0 - dly * 2.0, "Ambiyans"))
	Waves.amp = lerpf(1.0, 1.75, rain)
	rain_fx.emitting = rain > 0.3
	rain_fx.amount_ratio = clampf((rain - 0.3) / 0.7, 0.0, 1.0)
	if main.player != null:
		rain_fx.global_position = main.player.global_position + Vector3(0, 12, 0)

	sky_mat.set_shader_parameter("time", t)
	sky_mat.set_shader_parameter("cloud_cover", lerpf(0.42, 0.92, rain))
	sky_mat.set_shader_parameter("cloud_dark", rain * 0.85)
	sky_mat.set_shader_parameter("moon_dir", moon_dir)
	sky_mat.set_shader_parameter("flash", flash * (0.6 + 0.4 * sin(t * 40.0)))

	var night := 1.0 - daylight
	env.volumetric_fog_density = lerpf(0.0, 0.018, night) + rain * 0.006
	env.ambient_light_energy = lerpf(1.0, 0.35, night) + flash * 1.6
	env.tonemap_exposure = lerpf(1.0, 1.6, night) * lerpf(1.0, 1.15, rain)
	env.fog_density = lerpf(0.0018, 0.012, rain)
	env.fog_light_color = Color(0.68, 0.78, 0.88).lerp(Color(0.05, 0.07, 0.11), night).lerp(Color(0.35, 0.38, 0.42), rain * daylight)
	# Su altı: yoğun turkuaz sis, derinleştikçe kararan ışık.
	if main.player != null and main.player.head_under:
		var depth: float = clampf(-main.player.camera.global_position.y / 12.0, 0.0, 1.0)
		# Resif ve batık 20-25 m'den seçilir; sis gökyüzü rengine değil kendi turkuazına boyanır
		env.fog_density = lerpf(0.045, 0.08, depth)
		env.fog_light_color = Color(0.05, 0.32, 0.42).lerp(Color(0.02, 0.1, 0.16), depth) * lerpf(1.0, 0.3, night)
		env.fog_sky_affect = 1.0
		env.fog_aerial_perspective = 0.0
	else:
		env.fog_sky_affect = 0.12
		env.fog_aerial_perspective = 0.5
