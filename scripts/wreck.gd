extends Node3D
## Batık kadırga (koddan): yan yatmış, yarısı kuma gömülü ahşap gövde; bir bordası çökmüş, kaburgaları açıkta.
## Kırık direk ve yırtık yelken, kürekler, küpler, pas tutmuş top. Kıç tarafında E ile açılan sandık:
## ganimet ve "Mavi Pusula" ekibinin seyir defterinden bir sayfa.

const ToolModels = preload("res://scripts/tool_models.gd")
const Reef = preload("res://scripts/reef.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const Merge = preload("res://scripts/merge.gd")

const LENGTH := 13.0
const BEAM := 2.3
const DEPTH := 1.9

const LOG_PAGES := [
	"Seyir defteri, Mavi Pusula — 3 Mayıs: \"Kadırgayı bulduk. Ambarındaki küplerde fener yağı, kaptan köşkünde bir harita: bütün fenerler bir çember çiziyor. Ortası boş... ya da bize öyle görünüyor.\"",
	"Seyir defteri, Mavi Pusula — 5 Mayıs: \"Rıza Kaptan haklıymış. Fenerler yandığında Hıdırellez gecesi ortada bir ada belirirmiş. Defne ve Selim dalışa çıktı, sandığı kıçta bıraktık.\"",
	"Seyir defteri, Mavi Pusula — 6 Mayıs: \"Lodos başladı. Telsiz yalnızca cızırtı veriyor. Kim bulursa: fenerleri yakın. Işık olmadan kimse yolunu bulamaz.\"",
]

var main
var opened := false
var chest_lid: Node3D
var chest_body: StaticBody3D
var wood: StandardMaterial3D
var dark: StandardMaterial3D


func _ready() -> void:
	wood = StandardMaterial3D.new()
	wood.albedo_texture = load("res://assets/textures/rough_wood/rough_wood_diff_1k.jpg")
	wood.albedo_color = Color(0.42, 0.4, 0.32)
	wood.uv1_triplanar = true
	wood.uv1_scale = Vector3(0.6, 0.6, 0.6)
	wood.roughness = 1.0
	wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	dark = wood.duplicate()
	dark.albedo_color = Color(0.25, 0.24, 0.2)
	_build_hull()
	_build_debris()
	_build_chest()
	Merge.bake(self, true, 140.0)


## Gövde kesiti: x boyunca istasyonlar, her kesit U biçimli. Sancak bordasının orta kısmı yok (çökmüş).
func _build_hull() -> void:
	var hull := Node3D.new()
	hull.rotation = Vector3(0.0, 0.0, 0.55)
	hull.position = Vector3(0, -0.6, 0)
	add_child(hull)
	var NS := 26
	var NR := 14
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for i in NS + 1:
		var t := -1.0 + 2.0 * i / NS
		var x := t * LENGTH * 0.5
		var b := maxf(BEAM * pow(maxf(1.0 - t * t, 0.0), 0.5), 0.02)
		var top := DEPTH + 0.5 * t * t
		var row: Array = []
		for j in NR + 1:
			var phi := -PI / 2.0 + PI * j / NR
			row.append(Vector3(x, top - top * cos(phi), b * sin(phi)))
		grid.append(row)
	for i in NS:
		for j in NR:
			# Çökmüş borda: sancak tarafı (j büyük), ortadaki istasyonlarda yok
			if j >= NR - 5 and i > 7 and i < NS - 6 and (j > NR - 4 or (i + j) % 3 != 0):
				continue
			for q in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]:
				st.add_vertex(grid[q[0]][q[1]])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = wood
	hull.add_child(mi)
	# Açıkta kalan kaburgalar
	for i in range(8, NS - 5, 2):
		var pts: Array = []
		for j in range(NR - 6, NR + 1):
			pts.append((grid[i][j] as Vector3) + Vector3(0, 0, 0.03))
		ToolModels._mi(hull, ToolModels.tube(pts, 0.07, 5), dark)
	# Küpeşte ve güverte kirişleri
	var port: Array = []
	for i in NS + 1:
		port.append(grid[i][0])
	ToolModels._mi(hull, ToolModels.tube(port, 0.09, 6), dark)
	for i in range(3, NS - 2, 3):
		var a: Vector3 = grid[i][0]
		var b: Vector3 = grid[i][NR]
		if i > 7 and i < NS - 6:
			b = a.lerp(b, 0.55)
		ToolModels._mi(hull, ToolModels.tube([a, b], 0.06, 5), dark)
	# Pruva bodoslaması ve mahmuz (kadırga burnu)
	var stem: Vector3 = grid[NS][0]
	ToolModels._mi(hull, ToolModels.tube([stem + Vector3(-0.2, -1.6, 0), stem + Vector3(0.2, 0.2, 0), stem + Vector3(1.4, -0.9, 0)], 0.12, 6, 0.4), dark)
	# Gövdeye yosun ve mercan tutunmuş
	for k in 10:
		var g: Vector3 = grid[randi_range(2, NS - 2)][randi_range(0, 6)]
		var c := Reef.sponges(Reef.CORAL_COLORS.pick_random()) if k % 2 == 0 else Reef.kelp(randf_range(0.8, 1.6))
		c.position = g
		hull.add_child(c)
	# Çarpışma: yan yatmış gövdeyi kaba bir kutu temsil eder
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(LENGTH * 0.8, 1.2, BEAM * 1.2)
	cs.shape = box
	cs.position = Vector3(0, 0.4, -0.6)
	body.add_child(cs)
	hull.add_child(body)


func _build_debris() -> void:
	# Kırık direk ve yırtık yelken kumda
	ToolModels._mi(self, ToolModels.tube([Vector3(-1.0, 0.15, 2.4), Vector3(4.5, 0.25, 4.6)], 0.16, 8, 0.7), dark)
	ToolModels._mi(self, ToolModels.tube([Vector3(0.5, 0.2, 2.9), Vector3(1.2, 0.3, 6.5)], 0.08, 6, 0.8), dark)
	var sail_m := StandardMaterial3D.new()
	var n := FastNoiseLite.new()
	n.frequency = 0.05
	var tex := NoiseTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.noise = n
	var g := Gradient.new()
	g.set_color(0, Color(0.7, 0.66, 0.55, 0.0))
	g.add_point(0.35, Color(0.7, 0.66, 0.55, 0.0))
	g.add_point(0.38, Color(0.72, 0.68, 0.56, 1.0))
	g.set_color(g.get_point_count() - 1, Color(0.6, 0.58, 0.48, 1.0))
	tex.color_ramp = g
	sail_m.albedo_texture = tex
	sail_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	sail_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	sail_m.roughness = 1.0
	var sail := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3.6, 2.4)
	sail.mesh = pm
	sail.material_override = sail_m
	sail.position = Vector3(1.8, 0.3, 4.6)
	sail.rotation = Vector3(0.1, 0.4, 0.15)
	add_child(sail)
	# Kürekler
	for k in 5:
		var p := Vector3(randf_range(-5.0, 5.0), 0.1, randf_range(-4.0, -2.2))
		var a := randf() * TAU
		ToolModels._mi(self, ToolModels.tube([p, p + Vector3(cos(a), 0.05, sin(a)) * 2.6], 0.04, 5), dark)
	# Küpler: bazıları kırık
	var clay := StandardMaterial3D.new()
	clay.albedo_color = Color(0.55, 0.36, 0.26)
	clay.roughness = 1.0
	clay.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in 7:
		var broken := k % 3 == 0
		var prof := [Vector2(0.0, 0.0), Vector2(0.06, 0.02), Vector2(0.2, 0.3), Vector2(0.22, 0.5), Vector2(0.15, 0.72), Vector2(0.07, 0.82), Vector2(0.08, 0.9)]
		if broken:
			prof = prof.slice(0, 4)
		var am := ToolModels._mi(self, ToolModels.lathe(prof, 12), clay, Vector3(randf_range(-4.0, 3.0), 0.12, randf_range(1.5, 3.5)))
		am.rotation = Vector3(PI / 2.0 * randf_range(0.6, 1.0), randf() * TAU, 0)
	# Pas tutmuş top
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.3, 0.2, 0.15)
	iron.roughness = 1.0
	var cannon := ToolModels._mi(self, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.22, 0.2), Vector2(0.15, 1.5), Vector2(0.17, 1.6), Vector2(0.09, 1.62), Vector2(0.08, 0.3), Vector2(0.0, 0.3)], 12), iron, Vector3(-4.6, 0.2, 2.6))
	cannon.rotation = Vector3(PI / 2.0, 0.6, 0)
	# Hurda ve bir iki inci
	var scrap := StandardMaterial3D.new()
	scrap.albedo_color = Color(0.35, 0.3, 0.27)
	scrap.metallic = 0.7
	for k in 3:
		var p = PickupScript.new()
		p.main = main
		p.item = "hurda"
		p.amount = 3
		p.position = Vector3(randf_range(-5.0, 5.0), 0.05, randf_range(1.0, 5.0))
		add_child(p)
		var s := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.5, 0.15, 0.35)
		s.mesh = b
		s.material_override = scrap
		s.rotation = Vector3(0.2, randf() * TAU, 0.3)
		p.add_child(s)


## Kıçta, kumun üstünde demir kuşaklı sandık.
func _build_chest() -> void:
	var root := Node3D.new()
	root.set_meta("nomerge", true)
	root.position = Vector3(-4.2, 0.0, -1.6)
	root.rotation = Vector3(0.12, 0.5, 0.08)
	add_child(root)
	var band := StandardMaterial3D.new()
	band.albedo_color = Color(0.28, 0.2, 0.14)
	band.metallic = 0.6
	band.roughness = 0.7
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.45, 0.55)
	ToolModels._mi(root, box, dark, Vector3(0, 0.22, 0))
	for x in [-0.3, 0.3]:
		var bb := BoxMesh.new()
		bb.size = Vector3(0.06, 0.47, 0.57)
		ToolModels._mi(root, bb, band, Vector3(x, 0.22, 0))
	chest_lid = Node3D.new()
	chest_lid.position = Vector3(0, 0.45, -0.27)
	root.add_child(chest_lid)
	var lid := CylinderMesh.new()
	lid.top_radius = 0.27
	lid.bottom_radius = 0.27
	lid.height = 0.9
	var lm := ToolModels._mi(chest_lid, lid, dark, Vector3(0, 0.0, 0.27), Vector3(0, 0, PI / 2.0))
	lm.scale = Vector3(1.0, 1.0, 0.5)
	# Parıltı: içindeki altın ve inciler kapak açılınca görünür
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.8, 0.35)
	gold.metallic = 1.0
	gold.roughness = 0.25
	gold.emission_enabled = true
	gold.emission = Color(0.6, 0.45, 0.15)
	for k in 7:
		var c := CylinderMesh.new()
		c.top_radius = 0.05
		c.bottom_radius = 0.05
		c.height = 0.015
		ToolModels._mi(root, c, gold, Vector3(randf_range(-0.3, 0.3), 0.45, randf_range(-0.15, 0.15)), Vector3(randf() * 0.4, 0, randf() * 0.4))
	chest_body = StaticBody3D.new()
	chest_body.collision_layer = 4
	chest_body.collision_mask = 0
	chest_body.set_meta("target", self)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, 0.8, 0.8)
	cs.shape = bs
	cs.position.y = 0.3
	chest_body.add_child(cs)
	root.add_child(chest_body)


func prompt(_player) -> String:
	return "Sandık boş" if opened else "E: Batık sandığı aç"


func interact(player) -> void:
	if opened:
		return
	opened = true
	chest_lid.rotation.x = -1.6
	main.audio.play("chest_open", -2.0, "Arayuz")
	var loot := {"inci": randi_range(2, 4), "metal_kulce": 3, "mercek": 1, "zeytinyagi": 2}
	for k in loot:
		player.give(k, loot[k])
	main.wreck_pages += 1
	main.quests.event("open_wreck")
	main.hud.lore.read_note(main.hud.lore.next_wreck_page())
	main.hud.chest_opened_frame = Engine.get_process_frames()
