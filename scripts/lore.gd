extends Control
## Hikâye: şişelerden ve batık sandıklarından çıkan notlar, Hızır ve Hıdırellez anlatıları.
## Notlar kâğıt görünümlü bir panelde okunur; okunanlar seyir defterinde (J) "Notlar" bölümünde durur.
## Oyunun sonu da bu panelle anlatılır, ardından "Son" ekranı gelir ve serbest oyun sürer.

const NOTES := {
	"sise_1": {"title": "Şişedeki Not", "sign": "— Defne, Mavi Pusula",
		"text": "Kim bulursa,\n\nBiz Mavi Pusula araştırma ekibiyiz. Ege'nin eski deniz fenerlerini ve Hızır anlatılarını kayda geçiriyorduk. Bir lodos gecesi teknemiz ikiye bölündü.\n\nFenerlerin hepsi sönük. Geceleri deniz kuyu gibi karanlık; ne yıldıza ne kıyıya güvenebiliyoruz. Işığı kim yakarsa yolu o bulur. Lütfen fenerleri yakın."},
	"sise_2": {"title": "Hızır'ın Yolu", "sign": "— Selim'in notlarından",
		"text": "Yaşlı balıkçılar anlatır: Hızır denizde, İlyas karada dolaşır. Darda kalanın elinden tutarlar, kim olduklarını söylemezler.\n\nYılda bir kez, Hıdırellez gecesi bir gül dalının dibinde buluşurlar. O gece ateşler yakılır, üstünden atlanır; dilekler bir bez parçasına yazılıp ağaca bağlanır. Sabah olunca dilek yolunu bulur."},
	"sise_3": {"title": "Fenerlerin Çemberi", "sign": "— Defne",
		"text": "Fenerleri haritada birleştirince bir çember çıkıyor. Eski fenerciler buna \"Hızır'ın halkası\" dermiş.\n\nHalka yeniden yandığında ortadaki karanlıkta bir ada görünürmüş: üstünde koca bir çınar, dallarında yüzyılların kurdeleleri. Biz ortaya varamadan battık. Belki sen varırsın."},
	"sise_4": {"title": "Mavi Tirhandil", "sign": "— Selim",
		"text": "Bugün mavi bir tirhandil yanaştı. Yaşlı kaptan takas teklif etti, bize zeytinyağı ve tohum verdi.\n\nAdını sorduk, güldü: \"Ne zaman lazımsam oradayım.\" Defne inanmıyor ama yemin ederim, teknesinin gölgesi suya düşmüyordu."},
	"sise_5": {"title": "Dilek Kurdelesi", "sign": "— Defne",
		"text": "Hıdırellez'de dileğini bir kumaş parçasına bağlarsın: bir parça kumaş, bir parça ip, o kadar. Ağaç neredeyse dilek oraya gider.\n\nBizim ağacımız çemberin ortasındaki adada. Kurdeleni hazırla. Fenerler yanınca Hıdırellez gecesi o ada görünecek."},
	"defter_1": {"title": "Seyir Defteri — 3 Mayıs", "sign": "Mavi Pusula",
		"text": "Kadırgayı bulduk. Ambarındaki küplerde fener yağı, kaptan köşkünde bir harita: bütün fenerler bir çember çiziyor. Ortası boş... ya da bize öyle görünüyor."},
	"defter_2": {"title": "Seyir Defteri — 5 Mayıs", "sign": "Mavi Pusula",
		"text": "Rıza Kaptan haklıymış. Fenerler yandığında Hıdırellez gecesi ortada bir ada belirirmiş. Defne ve Selim dalışa çıktı; sandığı kıçta bıraktık, bulan alsın."},
	"defter_3": {"title": "Seyir Defteri — 6 Mayıs", "sign": "Mavi Pusula",
		"text": "Lodos başladı. Telsiz yalnızca cızırtı veriyor. Kim bulursa: fenerleri yakın. Işık olmadan kimse yolunu bulamaz."},
	"hizir": {"title": "Çınarın Dibinde", "sign": "",
		"text": "Rıza Kaptan çınarın dibinde, sanki seni bekliyormuş gibi duruyor.\n\n\"Fenerleri yaktın, evlat. Halka tamamlandı. Kurdeleni dala bağla; gerisini deniz bilir.\"\n\nBir an gözlerinin içi yeşil bir ışıkla parlıyor."},
}
const BOTTLE_ORDER := ["sise_1", "sise_2", "sise_3", "sise_4", "sise_5"]
const WRECK_ORDER := ["defter_1", "defter_2", "defter_3"]

const EPILOGUE := "Kurdeleyi çınarın en alçak dalına bağlıyorsun. Bir anlığına rüzgâr duruyor.\n\nUfukta, yaktığın fenerlerin huzmeleri tek tek bu adaya dönüyor; denizin üstünde ışıktan bir halka beliriyor. Adanın öbür yakasından bir fener ışığı yanıp sönüyor: Mavi Pusula'nın filikası. Defne ile Selim haftalardır bu kıyıda, birinin halkayı tamamlamasını bekliyormuş.\n\nRıza Kaptan'ı soruyorsun. Çınarın dibinde yalnızca ıslak bir ayak izi ve bir gül dalı var.\n\nSabah bir kurtarma gemisi geliyor. Ama sen salına dönüyorsun: Ege'nin daha görmediğin adaları, yakılacak başka fenerleri var."

var main
var read: Array = []
var panel: PanelContainer
var title_lbl: Label
var body_lbl: Label
var sign_lbl: Label
var hint_lbl: Label
var end_panel: PanelContainer
var end_stats: Label
var showing := false
## Panel kapanınca çalışacak iş (son ekranı için)
var after_close: Callable


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _paper())
	add_child(panel)
	_center(panel, 380, 300)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	title_lbl = _lbl("", 30, Color(0.32, 0.18, 0.08))
	v.add_child(title_lbl)
	var line := ColorRect.new()
	line.color = Color(0.45, 0.28, 0.12, 0.5)
	line.custom_minimum_size = Vector2(0, 2)
	v.add_child(line)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	body_lbl = _lbl("", 20, Color(0.18, 0.12, 0.07))
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.custom_minimum_size = Vector2(690, 0)
	scroll.add_child(body_lbl)
	sign_lbl = _lbl("", 18, Color(0.35, 0.22, 0.1))
	sign_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(sign_lbl)
	hint_lbl = _lbl("E / Esc: kapat  ·  okunan notlar seyir defterinde (J) durur", 14, Color(0.35, 0.25, 0.15, 0.8))
	v.add_child(hint_lbl)
	panel.visible = false
	_build_end()


func _paper() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.93, 0.87, 0.72)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(34)
	s.border_color = Color(0.62, 0.46, 0.26)
	s.set_border_width_all(3)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 18
	return s


func _center(c: Control, hw: float, hh: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = -hw
	c.offset_right = hw
	c.offset_top = -hh
	c.offset_bottom = hh


func _lbl(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l


## Son ekranı: karanlık zemin, başlık, istatistikler, devam düğmesi.
func _build_end() -> void:
	end_panel = PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.01, 0.03, 0.06, 0.96)
	s.set_content_margin_all(60)
	end_panel.add_theme_stylebox_override("panel", s)
	add_child(end_panel)
	end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	end_panel.add_child(v)
	var t := _lbl("HIDIRELLEZ", 64, Color(1.0, 0.84, 0.42))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var st := _lbl("Fenerler yandı, halka tamamlandı. Mavi Pusula ekibi kurtuldu.", 24, Color(0.9, 0.93, 1.0))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	end_stats = _lbl("", 20, Color(0.8, 0.86, 0.95, 0.9))
	end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_stats)
	var cr := _lbl("SaLda  ·  Godot 4 ile yapıldı  ·  Modeller, dokular ve sesler: Quaternius, Poly Haven, Kenney, OpenGameArt (CC0) ve koddan üretilenler", 15, Color(1, 1, 1, 0.55))
	cr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(cr)
	var b := Button.new()
	b.text = "Denizde kalmaya devam et"
	b.custom_minimum_size = Vector2(360, 56)
	b.add_theme_font_size_override("font_size", 22)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		end_panel.visible = false
		main.end_finished())
	v.add_child(b)
	end_panel.visible = false


func is_open() -> bool:
	return panel.visible or end_panel.visible


## Notu okur (ilk kezse kaydeder, görev olayı gönderir) ve paneli açar.
func read_note(id: String) -> void:
	if not NOTES.has(id):
		return
	if not read.has(id):
		read.append(id)
		main.quests.event("read_note", id)
		main.hud.notify("Yeni not: %s" % NOTES[id]["title"], Color(1.0, 0.9, 0.6))
	show_note(NOTES[id]["title"], NOTES[id]["text"], NOTES[id]["sign"])


func show_note(title: String, text: String, sign: String = "") -> void:
	title_lbl.text = title
	body_lbl.text = text
	sign_lbl.text = sign
	panel.visible = true
	main.hud.journal.book.visible = false
	main.hud.chest_opened_frame = Engine.get_process_frames()
	main.hud.menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main.audio.play("cloth", -6.0)


func close() -> void:
	if not panel.visible:
		return
	panel.visible = false
	main.hud.menu_open = false
	main.hud.menu_closed_frame = Engine.get_process_frames()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if after_close.is_valid():
		var cb := after_close
		after_close = Callable()
		cb.call()


## Sıradaki okunmamış şişe notu; hepsi okunduysa boş.
func next_bottle() -> String:
	for id in BOTTLE_ORDER:
		if not read.has(id):
			return id
	return ""


func next_wreck_page() -> String:
	for id in WRECK_ORDER:
		if not read.has(id):
			return id
	return WRECK_ORDER.pick_random()


func show_end(stats: String) -> void:
	end_stats.text = stats
	end_panel.visible = true
	main.hud.menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func to_data() -> Array:
	return read.duplicate()


func from_data(d: Array) -> void:
	read = []
	for id in d:
		read.append(String(id))


func _process(_delta: float) -> void:
	if panel.visible and Input.is_action_just_pressed("interact") and Engine.get_process_frames() != main.hud.chest_opened_frame:
		close()
