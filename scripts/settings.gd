extends RefCounted
## Oyun ayarları: user://ayarlar.cfg dosyasında saklanır.

const PATH := "user://ayarlar.cfg"
const QUALITY_NAMES := ["Düşük", "Orta", "Yüksek", "Ultra"]

static var sensitivity := 0.0022
static var fov := 75.0
static var master := 0.8
static var sfx := 1.0
static var ambience := 0.9
static var quality := 2
static var fullscreen := false
## Sağ üst köşede FPS sayacı
static var show_fps := false


static func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	sensitivity = c.get_value("kontrol", "hassasiyet", sensitivity)
	fov = c.get_value("kontrol", "gorus_acisi", fov)
	master = c.get_value("ses", "ana", master)
	sfx = c.get_value("ses", "efekt", sfx)
	ambience = c.get_value("ses", "ambiyans", ambience)
	quality = c.get_value("grafik", "kalite", quality)
	fullscreen = c.get_value("grafik", "tam_ekran", fullscreen)
	show_fps = c.get_value("grafik", "fps_sayaci", show_fps)


static func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("kontrol", "hassasiyet", sensitivity)
	c.set_value("kontrol", "gorus_acisi", fov)
	c.set_value("ses", "ana", master)
	c.set_value("ses", "efekt", sfx)
	c.set_value("ses", "ambiyans", ambience)
	c.set_value("grafik", "kalite", quality)
	c.set_value("grafik", "tam_ekran", fullscreen)
	c.set_value("grafik", "fps_sayaci", show_fps)
	c.save(PATH)


## Grafik kalitesini ortama, güneşe ve görüntü alanına uygular.
static func apply(main) -> void:
	main.audio.set_bus_volume("Master", master)
	main.audio.set_bus_volume("Efekt", sfx)
	main.audio.set_bus_volume("Ambiyans", ambience)
	if main.player != null:
		main.player.camera.fov = fov
	var vp: Viewport = main.get_viewport()
	var env: Environment = main.world.env
	var sun: DirectionalLight3D = main.world.sun
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_4X][quality]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality >= 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = quality >= 3
	env.ssr_enabled = quality >= 2
	env.ssr_max_steps = 48 if quality >= 3 else 32
	env.ssao_enabled = quality >= 1
	env.ssil_enabled = quality >= 3
	env.glow_enabled = quality >= 1
	env.volumetric_fog_enabled = quality >= 2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = [30.0, 50.0, 80.0, 120.0][quality]
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 4096, 8192][quality], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([0, 2, 3, 4][quality])
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode and not Engine.is_embedded_in_editor():
		DisplayServer.window_set_mode(mode)
