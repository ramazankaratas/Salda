extends StaticBody3D
## Zeytin ağacı (koddan): boğumlu, ikiye ayrılan gövde; gümüşi yeşil yaprak kümeleri; dallarda zeytinler.
## E ile zeytin toplanır; zeytinler bir süre sonra yeniden olgunlaşır.

const ToolModels = preload("res://scripts/tool_models.gd")
const Merge = preload("res://scripts/merge.gd")
const REGROW := 300.0

var main
var ripe := true
var regrow := 0.0
var olives: Array = []
static var _bark: StandardMaterial3D
static var _leaf: StandardMaterial3D
static var _olive: StandardMaterial3D


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	set_meta("target", self)
	_materials()
	var s := randf_range(0.85, 1.15)
	var root := Node3D.new()
	root.scale = Vector3.ONE * s
	root.rotation.y = randf() * TAU
	add_child(root)
	# Boğumlu gövde: tabanda kalın, yukarıda iki kola ayrılır
	var trunk := [Vector3(0, 0, 0), Vector3(0.08, 0.5, 0.02), Vector3(-0.05, 1.0, 0.06), Vector3(0.05, 1.35, -0.02)]
	_tube(root, trunk, 0.22, 0.6)
	_tube(root, [Vector3(0.05, 1.3, -0.02), Vector3(0.5, 1.8, 0.1), Vector3(0.8, 2.3, 0.0)], 0.12, 0.5)
	_tube(root, [Vector3(0.0, 1.3, 0.0), Vector3(-0.45, 1.85, -0.2), Vector3(-0.7, 2.4, -0.1)], 0.11, 0.5)
	_tube(root, [Vector3(0.0, 1.5, 0.0), Vector3(0.1, 2.1, 0.45), Vector3(0.0, 2.6, 0.6)], 0.09, 0.5)
	# Gümüşi yeşil yaprak kümeleri
	var centers := [Vector3(0.8, 2.5, 0.0), Vector3(-0.7, 2.6, -0.1), Vector3(0.0, 2.8, 0.6), Vector3(0.1, 2.9, -0.3), Vector3(0.45, 2.75, 0.45), Vector3(-0.4, 2.7, 0.4)]
	for c in centers:
		# Her küme iç içe üç katman: dış katman seyrek, içi dolu (yaprak yoğunluğu)
		for layer in 3:
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radial_segments = 20
			sm.rings = 10
			sm.radius = randf_range(0.55, 0.75) * (1.0 - layer * 0.18)
			sm.height = sm.radius * 1.3
			mi.mesh = sm
			mi.material_override = _leaf
			mi.position = c + Vector3(randf_range(-0.1, 0.1), layer * 0.04, randf_range(-0.1, 0.1))
			mi.scale = Vector3(1.25, 0.72, 1.25)
			mi.rotation.y = randf() * TAU
			root.add_child(mi)
		# Zeytinler kümelerin altında
		for k in 4:
			var o := MeshInstance3D.new()
			var om := SphereMesh.new()
			om.radial_segments = 20
			om.rings = 10
			om.radius = 0.045
			om.height = 0.11
			o.mesh = om
			o.material_override = _olive
			var a := randf() * TAU
			o.position = c + Vector3(cos(a) * 0.55, -0.35 + randf() * 0.15, sin(a) * 0.55)
			o.set_meta("nomerge", true)
			root.add_child(o)
			olives.append(o)
	# Gövde ve yaprak kümeleri tek ağda (zeytinler toplanınca gizlendiği için ayrı kalır)
	Merge.bake(root, true)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.35
	cyl.height = 2.4
	cs.shape = cyl
	cs.position.y = 1.2
	add_child(cs)


static func _materials() -> void:
	if _bark != null:
		return
	_bark = StandardMaterial3D.new()
	_bark.albedo_texture = load("res://assets/textures/rough_wood/rough_wood_diff_1k.jpg")
	_bark.albedo_color = Color(0.55, 0.5, 0.42)
	_bark.uv1_triplanar = true
	_bark.uv1_scale = Vector3(2.5, 2.5, 2.5)
	_bark.roughness = 1.0
	# Yaprak kümesi: gürültü dokusuyla gümüşi yeşil, kenarları seyrek
	var n := FastNoiseLite.new()
	n.frequency = 0.09
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = n
	# Koyu yerler saydam: küme kenarı yapraklı ve seyrek görünür
	n.frequency = 0.16
	var g := Gradient.new()
	g.set_color(0, Color(0.3, 0.38, 0.25, 0.0))
	g.add_point(0.5, Color(0.3, 0.38, 0.25, 0.0))
	g.add_point(0.53, Color(0.34, 0.42, 0.28, 1.0))
	g.set_color(g.get_point_count() - 1, Color(0.66, 0.72, 0.6, 1.0))
	tex.color_ramp = g
	_leaf = StandardMaterial3D.new()
	_leaf.albedo_texture = tex
	_leaf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_leaf.alpha_scissor_threshold = 0.5
	_leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	_leaf.uv1_triplanar = true
	_leaf.uv1_scale = Vector3(2.2, 2.2, 2.2)
	_leaf.roughness = 0.9
	_olive = StandardMaterial3D.new()
	_olive.albedo_color = Color(0.22, 0.2, 0.15)
	_olive.roughness = 0.35


func _tube(parent: Node3D, pts: Array, r: float, end_scale: float) -> void:
	ToolModels._mi(parent, ToolModels.tube(pts, r, 10, end_scale), _bark)


func prompt(_player) -> String:
	if ripe:
		return "E: Zeytin topla"
	return "Zeytinler henüz olgunlaşmadı (%d sn)" % int(regrow)


func interact(player) -> void:
	if not ripe:
		return
	ripe = false
	regrow = REGROW
	player.give("zeytin", randi_range(4, 6))
	main.audio.play("cloth", -6.0)
	for o in olives:
		(o as Node3D).visible = false


func _process(delta: float) -> void:
	if ripe or main.paused:
		return
	regrow -= delta
	if regrow <= 0.0:
		ripe = true
		for o in olives:
			(o as Node3D).visible = true
