extends CanvasLayer
## Ana menü, duraklatma menüsü ve ayarlar ekranı.

const Settings = preload("res://scripts/settings.gd")

var main
var root: Control
var title_box: VBoxContainer
var main_panel: VBoxContainer
var pause_panel: VBoxContainer
var settings_panel: VBoxContainer
var help_panel: PanelContainer
var slots_panel: VBoxContainer
var slots_title: Label
var slots_box: VBoxContainer
var diff_row: HBoxContainer
var diff_desc: Label
var diff_btns: Array = []
var new_diff := 1
## "new": yeni oyun için yuva seçimi, "load": kayıt yükleme
var slots_mode := "new"
var confirm_slot := 0
var confirm_del := 0
var pause_info: Label
var continue_btn: Button
var dim: ColorRect
var mode := "main"  # main | pause | settings | help | slots | none
var back_to := "main"


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	dim = ColorRect.new()
	dim.color = Color(0.0, 0.03, 0.06, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	title_box = VBoxContainer.new()
	root.add_child(title_box)
	title_box.anchor_left = 0.06
	title_box.anchor_top = 0.14
	title_box.anchor_right = 0.6
	title_box.anchor_bottom = 0.4
	var title := _label("SaLda", 72, Color(1, 0.97, 0.9))
	title_box.add_child(title)
	title_box.add_child(_label("Okyanusta tek başına hayatta kal.", 22, Color(0.8, 0.9, 1.0, 0.9)))

	main_panel = _panel()
	continue_btn = _button(main_panel, "Devam Et", func(): main.load_slot(main.latest_slot()))
	_button(main_panel, "Yeni Oyun", func(): _show_slots("new"))
	_button(main_panel, "Kayıtlar", func(): _show_slots("load"))
	_button(main_panel, "Oynanış", func(): _show_help("main"))
	_button(main_panel, "Ayarlar", func(): _show_settings("main"))
	_button(main_panel, "Çıkış", func(): get_tree().quit())

	pause_panel = _panel()
	pause_panel.add_child(_label("DURAKLATILDI", 30, Color.WHITE))
	pause_info = _label("", 16, Color(1, 1, 1, 0.7))
	pause_panel.add_child(pause_info)
	_button(pause_panel, "Devam", func(): main.resume())
	_button(pause_panel, "Oyunu Kaydet", func():
		main.save_game()
		main.hud.toast("Oyun %d. yuvaya kaydedildi" % main.slot))
	_button(pause_panel, "Oynanış", func(): _show_help("pause"))
	_button(pause_panel, "Ayarlar", func(): _show_settings("pause"))
	_button(pause_panel, "Ana Menü", func():
		main.save_game()
		main.to_main_menu())
	_button(pause_panel, "Kaydet ve Çık", func():
		main.save_game()
		get_tree().quit())

	settings_panel = _panel()
	settings_panel.custom_minimum_size = Vector2(460, 0)
	settings_panel.add_child(_label("AYARLAR", 30, Color.WHITE))
	_slider("Fare hassasiyeti", 0.0005, 0.006, Settings.sensitivity, func(v): Settings.sensitivity = v)
	_slider("Görüş açısı", 60.0, 100.0, Settings.fov, func(v):
		Settings.fov = v
		Settings.apply(main))
	_slider("Ana ses", 0.0, 1.0, Settings.master, func(v):
		Settings.master = v
		Settings.apply(main))
	_slider("Efektler", 0.0, 1.0, Settings.sfx, func(v):
		Settings.sfx = v
		Settings.apply(main))
	_slider("Ortam sesi", 0.0, 1.0, Settings.ambience, func(v):
		Settings.ambience = v
		Settings.apply(main))
	var qrow := HBoxContainer.new()
	qrow.add_child(_label("Grafik kalitesi", 18, Color.WHITE, 200))
	var q := OptionButton.new()
	for n in Settings.QUALITY_NAMES:
		q.add_item(n)
	q.selected = Settings.quality
	q.item_selected.connect(func(i):
		Settings.quality = i
		Settings.apply(main))
	qrow.add_child(q)
	settings_panel.add_child(qrow)
	var fs := CheckBox.new()
	fs.text = "Tam ekran"
	fs.button_pressed = Settings.fullscreen
	fs.add_theme_font_size_override("font_size", 18)
	fs.toggled.connect(func(on):
		Settings.fullscreen = on
		Settings.apply(main))
	settings_panel.add_child(fs)
	var fpsb := CheckBox.new()
	fpsb.text = "FPS sayacı"
	fpsb.button_pressed = Settings.show_fps
	fpsb.add_theme_font_size_override("font_size", 18)
	fpsb.toggled.connect(func(on): Settings.show_fps = on)
	settings_panel.add_child(fpsb)
	_button(settings_panel, "Geri", func():
		Settings.save_settings()
		show_mode(back_to))
	_build_help()
	_build_slots()
	show_mode("main")


const CONTROLS := [
	["W A S D", "Yürü / yüz"], ["Shift", "Koş"], ["Boşluk", "Zıpla · suda yukarı çık · sala tırman"],
	["Ctrl / C", "Dal"], ["Fare", "Etrafa bak"], ["Sol tık", "Aleti kullan (kancayı basılı tutup bırak)"],
	["Sağ tık", "Geri al / iptal"], ["1 - 0 · tekerlek", "Alet çubuğundan seç"], ["E", "Etkileşim · suda malzeme topla"],
	["R", "Yapıyı sök (malzeme geri gelir)"], ["T", "Yapıyı içindekilerle taşı"], ["Tab / I", "Envanter ve üretim"],
	["M", "Harita"], ["J", "Seyir defteri (görevler, başarımlar)"], ["Esc", "Menü"],
]
const TIPS := [
	"Kancayla denizdeki tahta, plastik, yaprak ve varilleri topla. Suya atlayıp E ile de toplayabilirsin.",
	"Zemin, duvar, kapı, pencere ve çatıyı Tab → Yapı sekmesinden seç, çekiçle kur.",
	"Su Arıtıcı tuzlu suyu içilebilir hâle getirir; Izgarada balık ve patates pişir.",
	"Olta: sol tıkı basılı tutup bırakarak at. Şamandıra batınca çek, sonra gerginliğe bakarak sar; balık kaçarken bırak.",
	"Açlık ya da susuzluk biterse canın azalır. Su altında oksijenine dikkat et.",
	"Köpekbalığı salına saldırır: mızrakla vur, hasar gören karoları çekiçle onar.",
	"Yağmurda uyumak için yatağın üstünde çatı olmalı. Gece fener ve tavan lambası yanar.",
	"Ege'de rüzgâr döner: Poyraz, Lodos, İmbat... Yelken rüzgâr arkadan ya da yandan eserken iyi çeker; rüzgâra karşı gidilmez. Pusula yönü ve rüzgârı gösterir, gece Kutup Yıldızı kuzeydedir.",
	"Adalar farklıdır: kayalıkta kazmayla taş ve demir, zeytinlikte zeytin, fener adasında onarılacak eski bir fener bulunur.",
	"Telsiz sönmüş fenerlerin sinyalini yakalar. Yanan fener geceleri yolu gösterir, çevresinde köpekbalığı saldırmaz. Dümen ve motorla rüzgârsız da gidersin.",
	"Adaların eteğinde resif var: dal (Ctrl), yosun topla, istiridye aç; bazılarından inci çıkar. Oksijen tüpü ve paletle derine inersin.",
	"Sonar açık denizdeki batıkları bulur (12-20 m derin): çapa at, tüple dal; antik sikke ve bronz heykel Rıza Kaptan'da çok değerli.",
	"Köpekbalığı yemi onu yarım dakika oyalar; diken tuzağı kenar karolarını korur. Batık kadırga koylarında sandık arayın.",
	"Çan sesi duyarsan Rıza Kaptan'ın teknesi yanaşıyordur: takas et, söylenti al; nazar boncuğu köpekbalığını savuşturur.",
	"Adalarda ıslak sokak kedileri bulunur: sev, sala al. Balık verirsen mutlu olur, hediye getirir, köpekbalığı gelince tıslayarak uyarır.",
	"Toplama Ağı enkazı kendisi yakalar; Eritme Ocağı hurdadan metal külçe yapar.",
]


func _build_help() -> void:
	help_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.06, 0.09, 0.82)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(26)
	help_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(help_panel)
	help_panel.anchor_left = 0.06
	help_panel.anchor_right = 0.94
	help_panel.anchor_top = 0.07
	help_panel.anchor_bottom = 0.93
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	help_panel.add_child(v)
	v.add_child(_label("Oynanış", 38, Color(1, 0.97, 0.9)))
	# Uzun metin: kaydırılabilir alan (fare tekerleği ya da sağdaki çubuk)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 48)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	left.add_child(_label("Kontroller", 24, Color(0.95, 0.75, 0.35)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 6)
	left.add_child(grid)
	for c in CONTROLS:
		grid.add_child(_label(c[0], 18, Color(1, 0.9, 0.6), 170))
		grid.add_child(_label(c[1], 18, Color(0.92, 0.95, 1.0)))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(_label("Hayatta kalma", 24, Color(0.95, 0.75, 0.35)))
	for t in TIPS:
		var l := _label("•  " + t, 18, Color(0.92, 0.95, 1.0))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(380, 0)
		right.add_child(l)
	var back := _button(v, "Geri", func(): show_mode(back_to))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


## Kayıt yuvaları ekranı: yeni oyunda önce zorluk seçilir, sonra yuva; yüklemede dolu yuvaya tıklanır.
func _build_slots() -> void:
	slots_panel = _panel()
	slots_panel.custom_minimum_size = Vector2(620, 0)
	slots_title = _label("", 30, Color.WHITE)
	slots_panel.add_child(slots_title)
	diff_row = HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 8)
	slots_panel.add_child(diff_row)
	for i in 3:
		var b := Button.new()
		b.text = main.DIFF_NAMES[i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(150, 44)
		b.add_theme_font_size_override("font_size", 20)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			new_diff = i
			confirm_slot = 0
			main.audio.play("click", -4.0, "Arayuz")
			_refresh_slots())
		diff_row.add_child(b)
		diff_btns.append(b)
	diff_desc = _label("", 16, Color(0.9, 0.93, 1.0, 0.85))
	diff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diff_desc.custom_minimum_size = Vector2(600, 0)
	slots_panel.add_child(diff_desc)
	slots_box = VBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 10)
	slots_panel.add_child(slots_box)
	_button(slots_panel, "Geri", func(): show_mode("main"))


func _show_slots(m: String) -> void:
	slots_mode = m
	confirm_slot = 0
	new_diff = 1
	show_mode("slots")
	_refresh_slots()


func _refresh_slots() -> void:
	slots_title.text = "YENİ OYUN" if slots_mode == "new" else "KAYITLAR"
	diff_row.visible = slots_mode == "new"
	diff_desc.visible = slots_mode == "new"
	for i in 3:
		(diff_btns[i] as Button).button_pressed = i == new_diff
	diff_desc.text = main.DIFF_DESC[new_diff]
	for c in slots_box.get_children():
		c.queue_free()
	for s in range(1, main.SLOTS + 1):
		var info: Dictionary = main.slot_info(s)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		slots_box.add_child(row)
		var txt := "Yuva %d  ·  Boş" % s
		if not info.is_empty():
			var dt := Time.get_datetime_dict_from_unix_time(int(info["time"]) + int(Time.get_time_zone_from_system()["bias"]) * 60)
			txt = "Yuva %d  ·  Gün %d  ·  %s  ·  %d karo%s  ·  %02d.%02d %02d:%02d" % [s, info["day"], main.DIFF_NAMES[clampi(info["diff"], 0, 2)], info["tiles"],
				("  ·  " + info["quest"]) if info["quest"] != "" else "", dt["day"], dt["month"], dt["hour"], dt["minute"]]
		if slots_mode == "new" and confirm_slot == s:
			txt = "Yuva %d dolu: üzerine yazmak için tekrar tıkla" % s
		var b := _button(row, txt, func(): _on_slot(s, info.is_empty()))
		b.custom_minimum_size = Vector2(520, 52)
		b.add_theme_font_size_override("font_size", 17)
		b.disabled = slots_mode == "load" and info.is_empty()
		if not info.is_empty():
			var del := _button(row, "Emin misin?" if confirm_del == s else "Sil", func():
				if confirm_del != s:
					confirm_del = s
				else:
					confirm_del = 0
					main.delete_slot(s)
				_refresh_slots())
			del.custom_minimum_size = Vector2(130, 52)
			del.add_theme_font_size_override("font_size", 17)


func _on_slot(s: int, empty: bool) -> void:
	if slots_mode == "load":
		if not empty:
			main.load_slot(s)
		return
	if not empty and confirm_slot != s:
		confirm_slot = s
		_refresh_slots()
		return
	main.start_new(s, new_diff)


func _show_help(from: String) -> void:
	back_to = from
	show_mode("help")


func _label(t: String, size: int, c: Color, min_w := 0) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	if min_w > 0:
		l.custom_minimum_size = Vector2(min_w, 0)
	return l


func _panel() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	root.add_child(v)
	v.anchor_left = 0.06
	v.anchor_top = 0.42
	v.anchor_right = 0.06
	v.anchor_bottom = 0.42
	v.custom_minimum_size = Vector2(320, 0)
	return v


func _button(parent: Control, t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(320, 52)
	b.add_theme_font_size_override("font_size", 22)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.08, 0.12, 0.65)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18
	var hv := sb.duplicate() as StyleBoxFlat
	hv.bg_color = Color(0.95, 0.75, 0.35, 0.85)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", sb)
	b.pressed.connect(func():
		main.audio.play("click", -4.0, "Arayuz")
		cb.call())
	parent.add_child(b)
	return b


func _slider(t: String, lo: float, hi: float, val: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_child(_label(t, 18, Color.WHITE, 200))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 100.0
	s.value = val
	s.custom_minimum_size = Vector2(220, 24)
	s.value_changed.connect(cb)
	row.add_child(s)
	settings_panel.add_child(row)


func _show_settings(from: String) -> void:
	back_to = from
	show_mode("settings")


func show_mode(m: String) -> void:
	mode = m
	root.visible = m != "none"
	title_box.visible = m == "main" or (m == "settings" and back_to == "main") or m == "slots"
	help_panel.visible = m == "help"
	main_panel.visible = m == "main"
	slots_panel.visible = m == "slots"
	if m == "pause":
		pause_info.text = "Yuva %d  ·  %s" % [main.slot, main.DIFF_NAMES[main.difficulty]]
	pause_panel.visible = m == "pause"
	settings_panel.visible = m == "settings"
	dim.color.a = 0.25 if m == "main" or back_to == "main" else 0.55
	if m == "help":
		dim.color.a = 0.4
	continue_btn.visible = main.latest_slot() > 0
	if m != "none":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
