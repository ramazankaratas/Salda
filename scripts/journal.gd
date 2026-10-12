extends Control
## Görev takibi (sol üstte etkin görev ve adımları) ve J ile açılan seyir defteri:
## etkin görev, tamamlananlar ve başarımlar.

var main
var tracker: PanelContainer
var tracker_box: VBoxContainer
var book: PanelContainer
var book_left: VBoxContainer
var book_right: VBoxContainer

const GOLD := Color(1.0, 0.84, 0.42)
const DIM := Color(1, 1, 1, 0.55)
const DONE := Color(0.55, 0.95, 0.6)

var dirty := false
var rebuild_cd := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Sol üstte görev takibi
	tracker = PanelContainer.new()
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker.add_theme_stylebox_override("panel", _style(Color(0.03, 0.06, 0.08, 0.5), 8, 12))
	add_child(tracker)
	tracker.position = Vector2(20, 20)
	tracker.custom_minimum_size = Vector2(340, 0)
	tracker_box = VBoxContainer.new()
	tracker_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker_box.add_theme_constant_override("separation", 3)
	tracker.add_child(tracker_box)
	# Seyir defteri (J)
	book = PanelContainer.new()
	book.add_theme_stylebox_override("panel", _style(Color(0.13, 0.1, 0.07, 0.96), 10, 24))
	add_child(book)
	# Ekranın ortasında sabit 980 x 640
	book.anchor_left = 0.5
	book.anchor_right = 0.5
	book.anchor_top = 0.5
	book.anchor_bottom = 0.5
	book.offset_left = -490
	book.offset_right = 490
	book.offset_top = -320
	book.offset_bottom = 320
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	book.add_child(v)
	v.add_child(_lbl("SEYİR DEFTERİ  ·  J / Esc ile kapat  ·  fare tekerleğiyle kaydır", 24, GOLD))
	# Görev ve başarım listesi uzun: kaydırılabilir alan (fare tekerleği ya da sağdaki çubuk)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 540)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 34)
	scroll.add_child(cols)
	book_left = VBoxContainer.new()
	book_left.custom_minimum_size = Vector2(450, 0)
	book_left.add_theme_constant_override("separation", 6)
	cols.add_child(book_left)
	book_right = VBoxContainer.new()
	book_right.custom_minimum_size = Vector2(420, 0)
	book_right.add_theme_constant_override("separation", 4)
	cols.add_child(book_right)
	book.visible = false
	# Görev olayları sık gelir: yeniden kurulum en fazla saniyede dört kez yapılır
	main.quests.changed.connect(func(): dirty = true)
	_rebuild()


func _style(bg: Color, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.border_color = Color(1, 0.85, 0.5, 0.18)
	s.set_border_width_all(1)
	return s


func _lbl(t: String, size: int, c: Color, wrap_w := 0.0) -> Label:
	var l := Label.new()
	l.text = t
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	if wrap_w > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(wrap_w, 0)
	return l


func _bar(parent: Control, value: float, goal: float, w: float) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.custom_minimum_size = Vector2(w, 5)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var fill := ColorRect.new()
	fill.color = DONE if value >= goal else GOLD
	fill.size = Vector2(w * clampf(value / maxf(goal, 0.001), 0.0, 1.0), 5)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fill)


func _step_text(s: Array, p: float) -> String:
	var goal := float(s[2])
	if s[0] == "travel":
		return "%s  %d / %d m" % [s[3], int(p), int(goal)]
	return "%s  %d / %d" % [s[3], int(p), int(goal)]


func _rebuild() -> void:
	var q: Dictionary = main.quests.active()
	# Takip paneli
	for c in tracker_box.get_children():
		c.queue_free()
	if q.is_empty():
		tracker_box.add_child(_lbl("Bütün görevler tamam  ·  J: seyir defteri", 14, DONE))
	else:
		tracker_box.add_child(_lbl(q["chapter"].to_upper(), 11, DIM))
		tracker_box.add_child(_lbl(q["title"], 17, GOLD))
		for i in q["steps"].size():
			var s: Array = q["steps"][i]
			var p: float = main.quests.progress[i]
			tracker_box.add_child(_lbl(("• " if p < float(s[2]) else "✔ ") + _step_text(s, p), 13, DONE if p >= float(s[2]) else Color.WHITE))
		tracker_box.add_child(_lbl("J: seyir defteri", 11, DIM))
	if not book.visible:
		return
	# Seyir defteri: sol sütun görevler
	for c in book_left.get_children():
		c.queue_free()
	book_left.add_child(_lbl("GÖREVLER", 18, GOLD))
	if not q.is_empty():
		book_left.add_child(_lbl(q["chapter"], 13, DIM))
		book_left.add_child(_lbl(q["title"], 20, Color.WHITE))
		book_left.add_child(_lbl(q["desc"], 14, Color(0.92, 0.88, 0.8), 450))
		for i in q["steps"].size():
			var s: Array = q["steps"][i]
			var p: float = main.quests.progress[i]
			book_left.add_child(_lbl(_step_text(s, p), 14, DONE if p >= float(s[2]) else Color.WHITE))
			_bar(book_left, p, float(s[2]), 300)
		var parts: Array = []
		for k in q["reward"]:
			parts.append("%d %s" % [q["reward"][k], main.quests.Items.name_of(k)])
		book_left.add_child(_lbl("Ödül: " + ", ".join(parts), 13, GOLD))
	book_left.add_child(_lbl("Tamamlananlar", 15, DIM))
	var done_n: int = main.quests.current
	if done_n == 0:
		book_left.add_child(_lbl("Henüz yok", 13, DIM))
	for i in mini(done_n, main.quests.QUESTS.size()):
		book_left.add_child(_lbl("✔ " + main.quests.QUESTS[i]["title"], 13, DONE))
	# Okunan notlar: tıklayınca yeniden okunur
	var lore = main.hud.lore if main.hud != null else null
	if lore != null:
		book_left.add_child(_lbl("Notlar  %d / %d" % [lore.read.size(), lore.NOTES.size() - 1], 15, DIM))
		if lore.read.is_empty():
			book_left.add_child(_lbl("Denizde sürüklenen şişelere dikkat et.", 13, DIM))
		for id in lore.read:
			var b := Button.new()
			b.text = "✉  " + lore.NOTES[id]["title"]
			b.flat = true
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 14)
			b.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
			b.pressed.connect(func(): lore.read_note(id))
			book_left.add_child(b)
	# Sağ sütun başarımlar
	for c in book_right.get_children():
		c.queue_free()
	var got: int = main.quests.ach_done.size()
	book_right.add_child(_lbl("BAŞARIMLAR  %d / %d" % [got, main.quests.ACHIEVEMENTS.size()], 18, GOLD))
	for a in main.quests.ACHIEVEMENTS:
		var ok: bool = main.quests.ach_done.has(a[0])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		book_right.add_child(row)
		row.add_child(_lbl("★" if ok else "☆", 16, GOLD if ok else DIM))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		var val: float = float(main.quests.ach_count.get(a[0], 0.0))
		var goal := float(a[5])
		var extra := "" if ok or goal <= 1.0 else "  (%d / %d)" % [int(minf(val, goal)), int(goal)]
		col.add_child(_lbl(a[1] + extra, 14, Color.WHITE if ok else Color(1, 1, 1, 0.75)))
		col.add_child(_lbl(a[2], 11, DIM))


func toggle() -> void:
	book.visible = not book.visible
	# Açıkken fare serbest kalır (kaydırmak için), oyuncu durur
	main.hud.menu_open = book.visible
	if book.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_rebuild()
	else:
		main.hud.menu_closed_frame = Engine.get_process_frames()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	main.audio.play("ui_open" if book.visible else "ui_close", -6.0, "Arayuz")


func _process(delta: float) -> void:
	rebuild_cd -= delta
	if dirty and rebuild_cd <= 0.0:
		dirty = false
		rebuild_cd = 0.25
		_rebuild()
	tracker.visible = not main.hud.menu_open and not book.visible and not main.hud.bigmap_panel.visible and not main.paused
