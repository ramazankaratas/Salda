extends PanelContainer
## Takas ekranı: Rıza Kaptan'ın teklifleri. Her satır: verdiğin → aldığın, kalan stok ve Takas düğmesi.
## Eksik malzeme kırmızı yazılır. E ya da Esc ile kapanır.

const Items = preload("res://scripts/items.gd")
const Icons = preload("res://scripts/icons.gd")

const GOLD := Color(1.0, 0.84, 0.42)
const DIM := Color(1, 1, 1, 0.55)
const BAD := Color(1.0, 0.45, 0.4)

var main
var trader = null
var rows: VBoxContainer
var say_lbl: Label
var time_lbl: Label
var tick := 0.0


func _ready() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.1, 0.15, 0.96)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(22)
	s.border_color = Color(0.45, 0.65, 1.0, 0.3)
	s.set_border_width_all(1)
	add_theme_stylebox_override("panel", s)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -470
	offset_right = 470
	offset_top = -330
	offset_bottom = 330
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(_lbl("MAVİ YOLCU  ·  Rıza Kaptan'ın takası", 24, GOLD))
	say_lbl = _lbl("", 15, Color(0.92, 0.9, 0.82))
	say_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	say_lbl.custom_minimum_size = Vector2(890, 44)
	v.add_child(say_lbl)
	var hdr := HBoxContainer.new()
	v.add_child(hdr)
	var a := _lbl("VERDİĞİN", 13, DIM)
	a.custom_minimum_size = Vector2(340, 0)
	hdr.add_child(a)
	var b := _lbl("ALDIĞIN", 13, DIM)
	b.custom_minimum_size = Vector2(330, 0)
	hdr.add_child(b)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	v.add_child(rows)
	time_lbl = _lbl("", 13, DIM)
	v.add_child(time_lbl)
	visible = false


func _lbl(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	return l


func open(t) -> void:
	trader = t
	say_lbl.text = "Rıza Kaptan: " + t.GREETINGS.pick_random()
	visible = true
	refresh()


func close() -> void:
	trader = null
	visible = false


## Eşya listesi: ikon + "adet Ad"; envanterde yetmeyen kırmızı.
func _items_box(cost: Dictionary, check: bool) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for k in cost:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = Icons.get_icon("pusula" if k == "ipucu" else k)
		h.add_child(icon)
		var nm := "Söylenti ve fener yeri" if k == "ipucu" else "%d %s" % [int(cost[k]), Items.name_of(k)]
		var have: int = main.player.inv.count(k) if check else 0
		var txt := nm + ("  (%d)" % have if check else "")
		h.add_child(_lbl(txt, 15, BAD if check and have < int(cost[k]) else Color.WHITE))
	return h


func refresh() -> void:
	if trader == null:
		return
	for c in rows.get_children():
		c.queue_free()
	for i in trader.offers.size():
		var o: Dictionary = trader.offers[i]
		var row := PanelContainer.new()
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color(1, 1, 1, 0.05)
		rs.set_corner_radius_all(6)
		rs.set_content_margin_all(6)
		row.add_theme_stylebox_override("panel", rs)
		rows.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		var give := _items_box(o["give"], true)
		give.custom_minimum_size = Vector2(330, 0)
		h.add_child(give)
		h.add_child(_lbl("→", 20, GOLD))
		var get_box := _items_box(o["get"], false)
		get_box.custom_minimum_size = Vector2(300, 0)
		h.add_child(get_box)
		h.add_child(_lbl("stok %d" % int(o["stock"]), 13, DIM))
		var btn := Button.new()
		btn.text = "TAKAS"
		btn.custom_minimum_size = Vector2(100, 36)
		btn.disabled = not trader.can_trade(i)
		btn.pressed.connect(_on_trade.bind(i))
		h.add_child(btn)
	_update_time()


func _on_trade(i: int) -> void:
	if trader == null:
		return
	var said: String = trader.trade(i)
	if said != "":
		say_lbl.text = "Rıza Kaptan: " + said
	refresh()


func _update_time() -> void:
	if trader == null:
		return
	time_lbl.text = "E / Esc: Kapat  ·  Tekne sen bu ekrandayken bekler; kapatınca %d sn sonra yelken açar." % int(trader.time_left())


func _process(delta: float) -> void:
	if not visible:
		return
	tick -= delta
	if tick <= 0.0:
		tick = 0.5
		_update_time()
