extends CanvasLayer
## Arayüz: durum barları, saat, mini harita, alet çubuğu, envanter + üretim ekranı (Tab),
## sandık ekranı, büyük harita (M), toplama bildirimleri, ipuçları ve ekran efektleri.

const Items = preload("res://scripts/items.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Icons = preload("res://scripts/icons.gd")
const BuildingScript = preload("res://scripts/building.gd")
const JournalScript = preload("res://scripts/journal.gd")
const MapScript = preload("res://scripts/map.gd")
const TradeScript = preload("res://scripts/trade_ui.gd")
const LoreScript = preload("res://scripts/lore.gd")
const Settings = preload("res://scripts/settings.gd")

var main
var menu_open := false
var chest = null

var root: Control
var bars := {}
var bar_vals := {}
var oxygen_row: Control
var time_lbl: Label
var status_lbl: Label
## Ayarlardan açılan FPS sayacı (sağ üst köşe)
var fps_lbl: Label
var fps_t := 0.0
var held_lbl: Label
var hotbar: Array = []
var prompt_lbl: Label
var toast_lbl: Label
var notes: VBoxContainer
var charge_bg: ColorRect
var charge_fill: ColorRect
var underwater: ColorRect
var hurt: ColorRect
var fade: ColorRect
var center_lbl: Label
var toast_time := 0.0
## Sağ üstteki küçük harita (radar). Kullanıcı isteğiyle kapalı; true yapınca geri gelir.
const SHOW_MINIMAP := false
var minimap: Control
var bigmap_panel: PanelContainer
var bigmap: Control

var inv_screen: PanelContainer
var inv_grid: GridContainer
var chest_grid: GridContainer
var chest_box: VBoxContainer
var journal
## Tüp çubuğunun satırı (tüp kuşanılınca görünür) ve envanterdeki ekipman yuvaları
var tank_row: Control
var gear_slots := {}
## Takas ekranı ve açık olan tüccar
var trade_ui
var lore
var trade = null
var chest_title: Label
var chest_type_btn: OptionButton
## Tür listesindeki seçeneklerin anahtarları (genel başlıklar + tek tek eşyalar).
var chest_type_keys: Array = []
var recipe_list: VBoxContainer
var craft_tabs: HBoxContainer
var detail_icon: TextureRect
var detail_name: Label
var detail_desc: Label
var detail_cost: VBoxContainer
var detail_missing: Label
var craft_btn: Button
var craft_cat := "Malzeme"
var selected_recipe := {}
var pick = null  # [inventory, index]
var style_slot: StyleBoxFlat
var style_selected: StyleBoxFlat


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	style_slot = _style(Color(0.05, 0.07, 0.09, 0.62), Color(1, 1, 1, 0.12), 2)
	style_selected = _style(Color(0.08, 0.1, 0.12, 0.75), Color(1, 0.85, 0.4), 3)

	underwater = _rect(root, Color(0.02, 0.22, 0.32, 0.0))
	hurt = _rect(root, Color(0.7, 0.0, 0.0, 0.0))

	# Sol altta durum paneli: can, açlık, su ve oksijen; değerler sayıyla da yazılır.
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psb := _style(Color(0.03, 0.06, 0.08, 0.55), Color(1, 1, 1, 0.08), 1)
	psb.set_corner_radius_all(8)
	psb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", psb)
	root.add_child(panel)
	_place(panel, 0, 1, 0, 1, 20, -150, 330, -20)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	for b in [["saglik", "CAN", Color(0.88, 0.27, 0.27)], ["aclik", "AÇLIK", Color(0.92, 0.62, 0.2)],
			["susuzluk", "SU", Color(0.28, 0.62, 0.97)], ["oksijen", "OKSİJEN", Color(0.72, 0.92, 1.0)], ["tup", "TÜP", Color(1.0, 0.82, 0.3)]]:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		col.add_child(row)
		var lbl := _label(row, 15, Color.WHITE)
		lbl.text = b[1]
		lbl.custom_minimum_size = Vector2(76, 0)
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.5)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.custom_minimum_size = Vector2(160, 14)
		bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bg)
		var fill := ColorRect.new()
		fill.color = b[2]
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.size = Vector2(160, 14)
		bg.add_child(fill)
		bars[b[0]] = fill
		var val := _label(row, 15, Color(1, 1, 1, 0.85))
		val.custom_minimum_size = Vector2(36, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bar_vals[b[0]] = val
		if b[0] == "tup":
			tank_row = row
			row.visible = false

	time_lbl = _label(root, 18, Color(1, 1, 1, 0.9))
	_place(time_lbl, 0.5, 0, 0.5, 0, -200, 16, 200, 40)
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl = _label(root, 14, Color(0.85, 0.95, 1.0, 0.85))
	_place(status_lbl, 0.5, 0, 0.5, 0, -260, 40, 260, 62)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_lbl = _label(root, 16, Color(0.75, 1.0, 0.75, 0.95))
	_place(fps_lbl, 1, 0, 1, 0, -150, 14, -18, 38)
	fps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_lbl.visible = false

	# Saldan ayrıyken ekranda sal işareti
	var marker = preload("res://scripts/raft_marker.gd").new()
	marker.main = main
	root.add_child(marker)
	minimap = MapScript.new()
	minimap.main = main
	root.add_child(minimap)
	_place(minimap, 1, 0, 1, 0, -236, 16, -16, 276)
	minimap.visible = SHOW_MINIMAP
	minimap.process_mode = Node.PROCESS_MODE_INHERIT if SHOW_MINIMAP else Node.PROCESS_MODE_DISABLED

	notes = VBoxContainer.new()
	notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notes)
	_place(notes, 0, 0.5, 0, 0.5, 24, -60, 340, 160)

	var cross := ColorRect.new()
	cross.color = Color(1, 1, 1, 0.75)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)
	_place(cross, 0.5, 0.5, 0.5, 0.5, -2, -2, 2, 2)

	charge_bg = ColorRect.new()
	charge_bg.color = Color(0, 0, 0, 0.5)
	charge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(charge_bg)
	_place(charge_bg, 0.5, 0.5, 0.5, 0.5, -60, 30, 60, 38)
	charge_fill = ColorRect.new()
	charge_fill.color = Color(1, 0.85, 0.3)
	charge_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charge_bg.add_child(charge_fill)
	charge_fill.size = Vector2(0, 8)

	prompt_lbl = _label(root, 19, Color.WHITE)
	_place(prompt_lbl, 0.15, 0.5, 0.85, 0.5, 0, 48, 0, 100)
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	toast_lbl = _label(root, 21, Color(1, 0.95, 0.7))
	_place(toast_lbl, 0.15, 0, 0.85, 0, 0, 120, 0, 175)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	held_lbl = _label(root, 17, Color(1, 0.95, 0.8))
	_place(held_lbl, 0.5, 1, 0.5, 1, -300, -104, 300, -80)
	held_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 10:
		var s := _slot_widget(root, 58)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(s, 0.5, 1, 0.5, 1, -322 + i * 64, -78, -264 + i * 64, -20)
		var k := _label(s, 11, Color(1, 1, 1, 0.6))
		k.text = str((i + 1) % 10)
		k.position = Vector2(5, 2)
		hotbar.append(s)

	center_lbl = _label(root, 34, Color.WHITE)
	center_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_build_inventory_screen()
	_build_bigmap()
	journal = JournalScript.new()
	journal.main = main
	root.add_child(journal)
	trade_ui = TradeScript.new()
	trade_ui.main = main
	root.add_child(trade_ui)
	lore = LoreScript.new()
	lore.main = main
	root.add_child(lore)
	fade = _rect(root, Color(0, 0, 0, 0))


# --- Yardımcılar -------------------------------------------------------------

func _rect(parent: Control, c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	return r


func _label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _place(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, orr: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob


func _style(bg: Color, border: Color, w := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(w)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _icon_rect(parent: Control, id: String, px: int) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture = Icons.get_icon(id)
	parent.add_child(t)
	return t


## Eşya yuvası: ikon (hazır değilse renkli kare + ad), adet ve dayanıklılık çubuğu.
func _slot_widget(parent: Control, size: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _style(Color(0.05, 0.07, 0.09, 0.62), Color(1, 1, 1, 0.12)))
	b.add_theme_stylebox_override("hover", _style(Color(0.12, 0.15, 0.18, 0.85), Color(1, 1, 1, 0.4)))
	b.add_theme_stylebox_override("pressed", _style(Color(0.12, 0.15, 0.18, 0.85), Color(1, 0.85, 0.4)))
	parent.add_child(b)
	var swatch := ColorRect.new()
	swatch.name = "Swatch"
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.set_anchors_preset(Control.PRESET_FULL_RECT)
	swatch.offset_left = 10
	swatch.offset_top = 10
	swatch.offset_right = -10
	swatch.offset_bottom = -10
	b.add_child(swatch)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 3
	icon.offset_top = 3
	icon.offset_right = -3
	icon.offset_bottom = -3
	b.add_child(icon)
	var name := _label(b, 10, Color.WHITE)
	name.name = "Name"
	name.set_anchors_preset(Control.PRESET_FULL_RECT)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var count := _label(b, 14, Color(1, 0.95, 0.75))
	count.name = "Count"
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -34
	count.offset_top = -22
	count.offset_right = -4
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var dur := ColorRect.new()
	dur.name = "Dur"
	dur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dur.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	dur.offset_left = 5
	dur.offset_top = -6
	dur.offset_bottom = -3
	b.add_child(dur)
	return b


func _fill_slot(w: Button, s, size: int) -> void:
	var swatch: ColorRect = w.get_node("Swatch")
	var icon: TextureRect = w.get_node("Icon")
	var name: Label = w.get_node("Name")
	var count: Label = w.get_node("Count")
	var dur: ColorRect = w.get_node("Dur")
	if s == null:
		swatch.visible = false
		icon.texture = null
		name.text = ""
		count.text = ""
		dur.visible = false
		w.tooltip_text = ""
		return
	var id: String = s["id"]
	var info := Items.info(id)
	var tex := Icons.get_icon(id)
	icon.texture = tex
	swatch.visible = tex == null
	swatch.color = info["color"]
	name.text = "" if tex != null else info["name"]
	count.text = str(s["n"]) if s["n"] > 1 else ""
	w.tooltip_text = "%s\n%s" % [info["name"], Items.desc_of(id)]
	var maxd: int = int(info.get("dur", 0))
	dur.visible = maxd > 0
	if maxd > 0:
		var k := float(s["dur"]) / maxd
		dur.offset_right = 5 + (size - 10) * k
		dur.color = Color(0.9, 0.3, 0.25).lerp(Color(0.4, 0.9, 0.4), k)


# --- Envanter ve üretim ekranı -----------------------------------------------

func _build_inventory_screen() -> void:
	inv_screen = PanelContainer.new()
	inv_screen.add_theme_stylebox_override("panel", _style(Color(0.035, 0.05, 0.07, 0.94), Color(1, 1, 1, 0.15)))
	root.add_child(inv_screen)
	_place(inv_screen, 0.5, 0.5, 0.5, 0.5, -640, -320, 640, 320)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	inv_screen.add_child(hb)

	# Sol: sandık + envanter
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	hb.add_child(left)
	chest_box = VBoxContainer.new()
	left.add_child(chest_box)
	var chest_head := HBoxContainer.new()
	chest_head.add_theme_constant_override("separation", 10)
	chest_box.add_child(chest_head)
	chest_title = _title("DEPO SANDIĞI", 16)
	chest_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chest_head.add_child(chest_title)
	# Tür seçimi: önce genel başlıklar, sonra tek tek eşyalar (Tahta, Hurda Metal, Metal Külçe...)
	chest_type_btn = OptionButton.new()
	chest_type_btn.focus_mode = Control.FOCUS_NONE
	chest_type_btn.custom_minimum_size = Vector2(190, 30)
	chest_type_btn.tooltip_text = "Sandığın türü: hızlı eklemede (Q) yalnızca bu türdeki eşyalar sandığa gider."
	_fill_chest_types()
	chest_type_btn.item_selected.connect(func(idx: int):
		if chest != null and idx >= 0 and idx < chest_type_keys.size() and chest_type_keys[idx] != "":
			chest.set_type(chest_type_keys[idx])
			main.audio.play("click", -8.0, "Arayuz")
			_refresh())
	chest_head.add_child(chest_type_btn)
	var quick := Button.new()
	quick.text = "Hızlı Ekle (Q)"
	quick.focus_mode = Control.FOCUS_NONE
	quick.custom_minimum_size = Vector2(150, 30)
	quick.tooltip_text = "Envanterdeki, sandığın türüne uyan bütün eşyaları sandığa koyar."
	quick.pressed.connect(quick_store)
	chest_head.add_child(quick)
	var chest_hint := _title("Tıkla: envantere al  ·  E: kapat", 12)
	chest_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	chest_box.add_child(chest_hint)
	chest_grid = GridContainer.new()
	chest_grid.columns = 10
	chest_box.add_child(chest_grid)
	for i in 20:
		var w := _slot_widget(chest_grid, 52)
		w.pressed.connect(_on_chest_slot.bind(i))
	var gear_row := HBoxContainer.new()
	gear_row.add_theme_constant_override("separation", 8)
	left.add_child(gear_row)
	gear_row.add_child(_title("ENVANTER", 18))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_row.add_child(spacer)
	var gl := _title("DALIŞ TAKIMI", 13)
	gl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	gl.tooltip_text = "Tüpü ya da paleti elde tutup sol tıkla kuşan; buradan tıklayınca çıkar."
	gl.mouse_filter = Control.MOUSE_FILTER_PASS
	gear_row.add_child(gl)
	for sl in ["tup", "palet", "fener"]:
		var gw := _slot_widget(gear_row, 44)
		gw.tooltip_text = {"tup": "Oksijen tüpü yuvası", "palet": "Palet yuvası", "fener": "Dalgıç feneri yuvası"}[sl]
		gw.pressed.connect(func():
			main.player.unequip(sl)
			_refresh())
		gear_slots[sl] = gw
	var hint := Label.new()
	hint.text = "Üst sıra alet çubuğudur (yiyecek, su, alet ve yapılar; malzemeler çantada durur). Bir eşyaya tıkla, sonra gideceği yuvaya tıkla. Üstüne gelince açıklaması çıkar."
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(540, 0)
	left.add_child(hint)
	inv_grid = GridContainer.new()
	inv_grid.columns = 10
	left.add_child(inv_grid)
	for i in 30:
		var w := _slot_widget(inv_grid, 52)
		w.pressed.connect(_on_inv_slot.bind(i))

	# Sağ: üretim
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	right.add_child(_title("ÜRETİM", 22))
	craft_tabs = HBoxContainer.new()
	right.add_child(craft_tabs)
	for c in Items.CATEGORIES:
		var b := Button.new()
		b.text = c
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 34)
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func():
			craft_cat = c
			selected_recipe = {}
			main.audio.play("click", -6.0, "Arayuz")
			_refresh())
		craft_tabs.add_child(b)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(230, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	recipe_list = VBoxContainer.new()
	recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(recipe_list)

	var detail := PanelContainer.new()
	detail.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.1)))
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(detail)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	detail.add_child(dv)
	var top := HBoxContainer.new()
	dv.add_child(top)
	detail_icon = _icon_rect(top, "", 96)
	detail_name = _title("", 22)
	detail_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(detail_name)
	detail_desc = Label.new()
	detail_desc.add_theme_font_size_override("font_size", 14)
	detail_desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_desc.custom_minimum_size = Vector2(300, 0)
	dv.add_child(detail_desc)
	dv.add_child(_title("GEREKEN MALZEMELER", 14))
	detail_cost = VBoxContainer.new()
	dv.add_child(detail_cost)
	detail_missing = Label.new()
	detail_missing.add_theme_font_size_override("font_size", 15)
	detail_missing.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
	detail_missing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(detail_missing)
	craft_btn = Button.new()
	craft_btn.text = "ÜRET"
	craft_btn.custom_minimum_size = Vector2(0, 46)
	craft_btn.add_theme_font_size_override("font_size", 20)
	craft_btn.focus_mode = Control.FOCUS_NONE
	craft_btn.pressed.connect(func():
		if not selected_recipe.is_empty():
			main.craft(selected_recipe)
			_refresh())
	dv.add_child(craft_btn)
	inv_screen.visible = false


func _title(t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	return l


func _on_inv_slot(i: int) -> void:
	var inv = main.player.inv
	main.audio.play("click", -8.0, "Arayuz")
	if chest != null and pick == null:
		var s = inv.slots[i]
		if s != null:
			var left: int = chest.storage.add(s["id"], s["n"], s["dur"])
			if left < s["n"]:
				inv.take_slot(i, s["n"] - left)
		_refresh()
		return
	if pick == null:
		if inv.slots[i] != null:
			pick = [inv, i]
	else:
		if not Inventory.move_between(pick[0], pick[1], inv, i):
			toast("Alet çubuğuna yalnızca yiyecek, su, alet ve yapılar konur.")
		pick = null
	_refresh()


func _on_chest_slot(i: int) -> void:
	if chest == null:
		return
	main.audio.play("click", -8.0, "Arayuz")
	var s = chest.storage.slots[i]
	if s != null:
		var left: int = main.player.inv.add(s["id"], s["n"], s["dur"])
		if left < s["n"]:
			chest.storage.take_slot(i, s["n"] - left)
	_refresh()


func _refresh() -> void:
	if not menu_open:
		return
	var inv = main.player.inv
	for i in 30:
		var w: Button = inv_grid.get_child(i)
		_fill_slot(w, inv.slots[i], 52)
		w.modulate = Color(1, 0.85, 0.4) if pick != null and pick[0] == inv and pick[1] == i else Color.WHITE
	for sl in gear_slots:
		var gid: String = main.player.gear[sl]
		_fill_slot(gear_slots[sl], {"id": gid, "n": 1, "dur": 0} if gid != "" else null, 44)
	chest_box.visible = chest != null
	if chest != null:
		chest_title.text = "DEPO SANDIĞI%s" % ("  ·  %d. kat" % (chest.level + 1) if chest.level > 0 else "")
		var ti := chest_type_keys.find(chest.ctype)
		if ti >= 0 and chest_type_btn.selected != ti:
			chest_type_btn.select(ti)
	if chest != null:
		for i in 20:
			_fill_slot(chest_grid.get_child(i), chest.storage.slots[i], 52)
	for b in craft_tabs.get_children():
		(b as Button).button_pressed = b.text == craft_cat

	for c in recipe_list.get_children():
		c.queue_free()
	for r in Items.RECIPES:
		if r["cat"] != craft_cat:
			continue
		if selected_recipe.is_empty():
			selected_recipe = r
		var ok: bool = inv.has_all(r["cost"])
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 52)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "          " + Items.name_of(r["out"])
		# Aynı eşyanın birden çok tarifi varsa ana malzeme yazılır: "İp (Deniz Yosunu)"
		var same := 0
		for r2 in Items.RECIPES:
			if r2["out"] == r["out"]:
				same += 1
		if same > 1:
			b.text += "  (%s)" % Items.name_of(r["cost"].keys()[0])
		b.add_theme_font_size_override("font_size", 16)
		var sel: bool = r == selected_recipe
		b.add_theme_stylebox_override("normal", _style(Color(1, 0.85, 0.4, 0.18) if sel else Color(1, 1, 1, 0.04), Color(1, 0.85, 0.4) if sel else Color(1, 1, 1, 0.08)))
		b.add_theme_color_override("font_color", Color.WHITE if ok else Color(1, 1, 1, 0.45))
		var ic := _icon_rect(b, r["out"], 44)
		ic.position = Vector2(4, 4)
		ic.size = Vector2(44, 44)
		if not ok:
			ic.modulate = Color(1, 1, 1, 0.45)
		b.pressed.connect(func():
			selected_recipe = r
			main.audio.play("click", -8.0, "Arayuz")
			_refresh())
		recipe_list.add_child(b)
	_refresh_detail()


func _refresh_detail() -> void:
	for c in detail_cost.get_children():
		c.queue_free()
	if selected_recipe.is_empty():
		return
	var inv = main.player.inv
	var out: String = selected_recipe["out"]
	detail_icon.texture = Icons.get_icon(out)
	detail_name.text = Items.name_of(out) + ("" if selected_recipe["n"] == 1 else "  x%d" % selected_recipe["n"])
	detail_desc.text = Items.desc_of(out)
	var cost: Dictionary = selected_recipe["cost"]
	for k in cost:
		var have: int = inv.count(k)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_icon_rect(row, k, 36)
		var nl := Label.new()
		nl.text = Items.name_of(k)
		nl.add_theme_font_size_override("font_size", 16)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nl)
		var cl := Label.new()
		cl.text = "%d / %d" % [have, cost[k]]
		cl.add_theme_font_size_override("font_size", 17)
		cl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.5) if have >= cost[k] else Color(1, 0.45, 0.4))
		row.add_child(cl)
		detail_cost.add_child(row)
	var miss := Items.missing(inv, cost)
	var piece: bool = Items.info(out).get("type", "") == "piece"
	if piece:
		# Ev parçaları malzeme eksik olsa da seçilebilir; kurarken harcanır.
		detail_missing.text = "" if miss.is_empty() else "Kurmak için eksik: " + ", ".join(miss.keys().map(func(k): return "%d %s" % [miss[k], Items.name_of(k)]))
		craft_btn.disabled = false
		craft_btn.text = "ÇEKİÇLE KUR"
	elif miss.is_empty():
		detail_missing.text = ""
		craft_btn.disabled = false
		craft_btn.text = "ÜRET"
	else:
		var parts: Array = []
		for k in miss:
			parts.append("%d %s" % [miss[k], Items.name_of(k)])
		detail_missing.text = "Eksik: " + ", ".join(parts)
		craft_btn.disabled = true
		craft_btn.text = "MALZEME YETERSİZ"


## Envanter ya da sandık içeriği değişince (main bağlar).
func on_inventory_changed() -> void:
	if trade != null:
		trade_ui.refresh.call_deferred()
	elif menu_open:
		_refresh.call_deferred()


func on_icons_ready() -> void:
	_chest_type_icons()
	if menu_open:
		_refresh()


func toggle_inventory() -> void:
	if menu_open:
		close_menus()
	else:
		chest = null
		_open()


## Sandığın açıldığı kare: aynı E basışı sandığı hemen kapatmasın.
var chest_opened_frame := -1
## Menünün kapandığı kare: kapatan E basışı aynı karede yeniden etkileşim yapmasın.
var menu_closed_frame := -1


func _fill_chest_types() -> void:
	chest_type_btn.clear()
	chest_type_keys.clear()
	chest_type_btn.add_separator("Genel")
	chest_type_keys.append("")
	for t in BuildingScript.CHEST_TYPES:
		chest_type_btn.add_item(t[1])
		chest_type_keys.append(t[0])
	for group in [["material", "Malzemeler"], ["food", "Yiyecekler"], ["seed", "Tohumlar"], ["tool", "Aletler"], ["place", "Yapılar"]]:
		chest_type_btn.add_separator(group[1])
		chest_type_keys.append("")
		for id in Items.ITEMS:
			var ty: String = Items.ITEMS[id]["type"]
			if ty == group[0] or (group[0] == "place" and ty == "roof"):
				chest_type_btn.add_item(Items.name_of(id))
				chest_type_keys.append("item:" + id)
	chest_type_btn.get_popup().max_size = Vector2i(320, 520)


## Eşya ikonları hazır olunca tür listesine eklenir.
func _chest_type_icons() -> void:
	for i in chest_type_keys.size():
		var k: String = chest_type_keys[i]
		if k.begins_with("item:"):
			var ic := Icons.get_icon(k.substr(5))
			if ic != null:
				chest_type_btn.set_item_icon(i, ic)
				chest_type_btn.get_popup().set_item_icon_max_width(i, 24)


## Envanterdeki, açık sandığın türüne uyan eşyaları sandığa aktarır.
## Elde tutulan eşya kalır; Karışık sandıkta alet çubuğuna dokunulmaz (yalnızca çanta).
func quick_store() -> void:
	if chest == null:
		return
	var inv = main.player.inv
	var moved := 0
	for i in inv.slots.size():
		var s = inv.slots[i]
		if s == null or i == main.player.selected:
			continue
		if chest.ctype == "karisik" and i < inv.hotbar_size:
			continue
		if not chest.accepts(s["id"]):
			continue
		var n: int = s["n"]
		var left: int = chest.storage.add(s["id"], n, s["dur"])
		if left < n:
			inv.take_slot(i, n - left)
			moved += n - left
	main.audio.play("chest_close" if moved > 0 else "click", -6.0, "Arayuz")
	toast("%d eşya sandığa kondu (%s)" % [moved, chest.type_name()] if moved > 0 else "Sandığa uygun eşya yok ya da sandık dolu", 2.5)
	_refresh()


func open_trade(t) -> void:
	bigmap_panel.visible = false
	inv_screen.visible = false
	chest = null
	trade = t
	chest_opened_frame = Engine.get_process_frames()
	menu_open = true
	pick = null
	trade_ui.open(t)
	main.audio.play("ui_open", -6.0, "Arayuz")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func open_chest(b) -> void:
	chest = b
	if b.has_method("show_catch"):
		b.show_catch(true)
	chest_opened_frame = Engine.get_process_frames()
	_open()


func _open() -> void:
	bigmap_panel.visible = false
	menu_open = true
	pick = null
	inv_screen.visible = true
	main.audio.play("ui_open", -6.0, "Arayuz")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close_menus() -> void:
	menu_closed_frame = Engine.get_process_frames()
	if chest != null:
		main.audio.play_at("chest_close", chest.global_position)
		if chest.has_method("show_catch"):
			chest.show_catch(false)
	menu_open = false
	chest = null
	trade = null
	trade_ui.close()
	pick = null
	inv_screen.visible = false
	bigmap_panel.visible = false
	journal.book.visible = false
	lore.close()
	main.audio.play("ui_close", -6.0, "Arayuz")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Büyük harita ------------------------------------------------------------

func _build_bigmap() -> void:
	bigmap_panel = PanelContainer.new()
	bigmap_panel.add_theme_stylebox_override("panel", _style(Color(0.02, 0.05, 0.08, 0.92), Color(1, 1, 1, 0.15)))
	root.add_child(bigmap_panel)
	_place(bigmap_panel, 0.5, 0.5, 0.5, 0.5, -380, -400, 380, 400)
	var v := VBoxContainer.new()
	bigmap_panel.add_child(v)
	v.add_child(_title("HARİTA  (600 m · M ile kapat)", 20))
	bigmap = MapScript.new()
	bigmap.main = main
	bigmap.range_m = 300.0
	bigmap.show_debris = false
	bigmap.custom_minimum_size = Vector2(720, 740)
	v.add_child(bigmap)
	bigmap_panel.visible = false


func toggle_map() -> void:
	if menu_open and not bigmap_panel.visible:
		return
	bigmap_panel.visible = not bigmap_panel.visible
	main.audio.play("ui_open" if bigmap_panel.visible else "ui_close", -6.0, "Arayuz")


# --- Bildirimler -------------------------------------------------------------

func set_prompt(t: String) -> void:
	if prompt_lbl.text != t:
		prompt_lbl.text = t


func toast(t: String, dur := 3.5) -> void:
	toast_lbl.text = t
	toast_time = dur


func notify(t: String, color: Color, id := "") -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes.add_child(row)
	if id != "" and Icons.get_icon(id) != null:
		_icon_rect(row, id, 30)
	var l := _label(row, 18, color.lightened(0.3))
	l.text = t
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(row, "modulate:a", 0.0, 0.8)
	tw.tween_callback(row.queue_free)
	if notes.get_child_count() > 7:
		notes.get_child(0).queue_free()


func flash_damage() -> void:
	hurt.color.a = 0.45


func show_center(t: String) -> void:
	center_lbl.text = t


func fade_to(a: float, dur: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", a, dur)
	return tw


func set_visible_hud(v: bool) -> void:
	root.visible = v


func _process(delta: float) -> void:
	fps_lbl.visible = Settings.show_fps
	if Settings.show_fps:
		fps_t -= delta
		if fps_t <= 0.0:
			fps_t = 0.25
			var f := Engine.get_frames_per_second()
			fps_lbl.text = "%d FPS" % f
			fps_lbl.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75) if f >= 55 else (Color(1.0, 0.9, 0.5) if f >= 30 else Color(1.0, 0.55, 0.5)))
	var p = main.player
	if p == null:
		return
	var vals := {"saglik": p.health, "aclik": p.hunger, "susuzluk": p.thirst, "oksijen": p.oxygen, "tup": p.tank_air}
	tank_row.visible = p.gear["tup"] != ""
	for k in vals:
		var v := clampf(float(vals[k]), 0.0, 100.0)
		(bars[k] as ColorRect).size.x = 1.6 * v
		(bar_vals[k] as Label).text = "%d" % int(round(v))
		# Kritik seviyede kırmızı yanıp söner.
		var blink := v < 25.0 and int(Time.get_ticks_msec() / 400) % 2 == 0
		(bar_vals[k] as Label).modulate = Color(1, 0.4, 0.35) if blink else Color.WHITE
	time_lbl.text = main.world.time_text()
	var raft = main.raft
	var st := "Sal demirli" if raft.is_anchored() else ("Sal karaya oturdu" if raft.grounded else "Sal sürükleniyor")
	if raft.sail_vector().length() > 0.1 and not raft.is_anchored():
		st = "Yelken açık"
	status_lbl.text = "%s · %.1f m/s · rüzgâr %s" % [st, raft.speed(), main.world.wind_force_name()]
	for i in 10:
		var w: Button = hotbar[i]
		_fill_slot(w, p.inv.slots[i], 58)
		w.add_theme_stylebox_override("normal", style_selected if p.selected == i else style_slot)
	var hid: String = p.held_id()
	held_lbl.text = Items.name_of(hid) if hid != "" else ""
	var h = main.hook
	charge_bg.visible = h.state == h.H.CHARGING
	charge_fill.size.x = 120.0 * h.charge
	underwater.color.a = 0.42 if p.head_under else 0.0
	hurt.color.a = maxf(0.0, hurt.color.a - delta * 1.2)
	toast_lbl.visible = not menu_open and not bigmap_panel.visible
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0.0:
			toast_lbl.text = ""
