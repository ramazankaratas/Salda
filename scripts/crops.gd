extends RefCounted
## Tohumlar ve ekinler: tanımlar, tohum kesesi modeli ve saksıda büyüyen bitki görünümleri.
## Hasatta ürünün yanında 1–2 tohum da çıkar (tohum çoğalır). Zeytin fidanı kalıcıdır: hasattan sonra yeniden meyve verir.

const ToolModels = preload("res://scripts/tool_models.gd")

## tohum kimliği: ürün, adet, büyüme süresi çarpanı, kese etiket rengi, tohum rengi, kalıcı mı
const CROPS := {
	"tohum": {"crop": "patates", "n": 2, "time": 1.0, "tag": Color(0.75, 0.6, 0.3), "seed": Color(0.75, 0.65, 0.45), "perennial": false},
	"domates_tohumu": {"crop": "domates", "n": 3, "time": 1.2, "tag": Color(0.8, 0.2, 0.15), "seed": Color(0.9, 0.85, 0.6), "perennial": false},
	"biber_tohumu": {"crop": "biber", "n": 3, "time": 1.0, "tag": Color(0.25, 0.6, 0.2), "seed": Color(0.95, 0.9, 0.7), "perennial": false},
	"karpuz_tohumu": {"crop": "karpuz", "n": 1, "time": 1.6, "tag": Color(0.2, 0.45, 0.25), "seed": Color(0.12, 0.1, 0.08), "perennial": false},
	"zeytin_fidani": {"crop": "zeytin", "n": 6, "time": 2.0, "tag": Color(0.5, 0.55, 0.4), "seed": Color(0.3, 0.3, 0.2), "perennial": true},
}
const ORDER := ["tohum", "domates_tohumu", "biber_tohumu", "karpuz_tohumu", "zeytin_fidani"]


static func is_seed(id: String) -> bool:
	return CROPS.has(id)


static func _m(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _sphere(r: float, h: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radial_segments = 20
	s.rings = 10
	s.radius = r
	s.height = h
	return s


## Çuval bezinden tohum kesesi: büzgülü ağız, ip bağı, renkli etiket ve önüne dökülmüş birkaç tohum.
## Fidan için küçük toprak keseli zeytin fidanı.
static func seed_pouch(id: String) -> Node3D:
	var root := Node3D.new()
	var d: Dictionary = CROPS.get(id, CROPS["tohum"])
	if id == "zeytin_fidani":
		var pot := _m(Color(0.62, 0.4, 0.26))
		ToolModels._mi(root, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.13, 0.16), Vector2(0.11, 0.16), Vector2(0.0, 0.15)], 16), pot)
		ToolModels._mi(root, ToolModels.tube([Vector3(0, 0.14, 0), Vector3(0.02, 0.3, 0), Vector3(-0.01, 0.42, 0.01)], 0.012, 6, 0.6), _m(Color(0.4, 0.33, 0.25)))
		for i in 7:
			var a := TAU * i / 7.0
			var leaf := ToolModels._mi(root, _sphere(0.03, 0.06), _m(Color(0.5, 0.58, 0.44)), Vector3(cos(a) * 0.05, 0.3 + i * 0.018, sin(a) * 0.05))
			leaf.scale = Vector3(2.4, 0.3, 0.8)
			leaf.rotation.y = -a
		return root
	# Ağzı açık çuval: kıvrık kenar, içinde tohumlar; önünde ürünün küçük modeli ve renkli etiket.
	var burlap := _m(Color(0.58, 0.45, 0.29), 1.0)
	burlap.cull_mode = BaseMaterial3D.CULL_DISABLED
	ToolModels._mi(root, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.16, 0.05), Vector2(0.17, 0.14), Vector2(0.15, 0.22),
		Vector2(0.13, 0.26), Vector2(0.15, 0.29)], 16), burlap)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.12
	rim.outer_radius = 0.165
	rim.rings = 20
	rim.ring_segments = 8
	ToolModels._mi(root, rim, _m(Color(0.66, 0.54, 0.36), 1.0), Vector3(0, 0.285, 0))
	# İçi dolu tohum
	var fill := SphereMesh.new()
	fill.radial_segments = 16
	fill.rings = 8
	fill.radius = 0.13
	fill.height = 0.08
	ToolModels._mi(root, fill, _m(d["seed"], 0.7), Vector3(0, 0.27, 0))
	# İp bağı ve etiket
	var band := TorusMesh.new()
	band.inner_radius = 0.145
	band.outer_radius = 0.16
	band.rings = 20
	band.ring_segments = 6
	ToolModels._mi(root, band, _m(Color(0.55, 0.42, 0.25)), Vector3(0, 0.22, 0))
	var tag := ToolModels._mi(root, ToolModels.plate([Vector2(-0.07, -0.05), Vector2(0.07, -0.05), Vector2(0.07, 0.05), Vector2(-0.07, 0.05)], Vector3.RIGHT, Vector3.UP, 0.006, 1.0), _m(d["tag"], 0.6), Vector3(0, 0.12, 0.165), Vector3(-0.1, 0, 0))
	tag.scale = Vector3.ONE
	# Önde ürünün minyatürü
	var mini := _crop_mini(id)
	mini.position = Vector3(0.12, 0.0, 0.2)
	mini.scale = Vector3.ONE * 1.5
	root.add_child(mini)
	return root


## Torbanın önünde duran küçük ürün: patates, domates, biber, karpuz.
static func _crop_mini(id: String) -> Node3D:
	var n := Node3D.new()
	match id:
		"domates_tohumu":
			for i in 2:
				var t := ToolModels._mi(n, _sphere(0.055, 0.1), _m(Color(0.85, 0.12, 0.08), 0.35), Vector3(i * 0.09 - 0.04, 0.05, i * 0.02))
				for k in 5:
					var a := TAU * k / 5.0
					var leaf := ToolModels._mi(t, _sphere(0.012, 0.01), _m(Color(0.25, 0.5, 0.18)), Vector3(cos(a) * 0.018, 0.05, sin(a) * 0.018))
					leaf.scale = Vector3(1.6, 1.0, 0.6)
		"biber_tohumu":
			for i in 2:
				var p := ToolModels._mi(n, _sphere(0.03, 0.17), _m(Color(0.85, 0.15, 0.08) if i == 0 else Color(0.2, 0.55, 0.15), 0.3), Vector3(i * 0.07 - 0.03, 0.03, 0), Vector3(0, 0, PI / 2.0 - 0.2 + i * 0.4))
				ToolModels._mi(p, ToolModels.tube([Vector3(0, 0.08, 0), Vector3(0, 0.11, 0.01)], 0.008, 5), _m(Color(0.25, 0.45, 0.15)))
		"karpuz_tohumu":
			var img := Image.create(32, 8, false, Image.FORMAT_RGB8)
			for x in 32:
				for y in 8:
					img.set_pixel(x, y, Color(0.15, 0.4, 0.15) if (x / 3) % 2 == 0 else Color(0.35, 0.6, 0.28))
			var mel := StandardMaterial3D.new()
			mel.albedo_texture = ImageTexture.create_from_image(img)
			mel.roughness = 0.4
			var w := ToolModels._mi(n, _sphere(0.08, 0.16), mel, Vector3(0, 0.07, 0), Vector3(0, 0, PI / 2.0))
			w.scale = Vector3(1.0, 1.3, 1.0)
		_:
			for i in 3:
				var po := ToolModels._mi(n, _sphere(0.04, 0.06), _m(Color(0.72, 0.56, 0.34), 0.95), Vector3(i * 0.06 - 0.06, 0.03, (i % 2) * 0.03))
				po.scale = Vector3(1.4, 0.9, 1.0)
	return n


## Saksıdaki bitki (taban toprağın üstünde, 1 ölçekte olgun hâli).
static func plant(id: String) -> Node3D:
	var root := Node3D.new()
	var green := _m(Color(0.3, 0.52, 0.22), 0.8)
	var dark := _m(Color(0.22, 0.4, 0.17), 0.8)
	match id:
		"domates_tohumu":
			# Sırık, sarılan gövde, yapraklar ve kırmızı domatesler
			var stake := _m(Color(0.55, 0.42, 0.28))
			for x in [-0.22, 0.22]:
				ToolModels._mi(root, ToolModels.tube([Vector3(x, 0, 0), Vector3(x, 0.9, 0)], 0.012, 5), stake)
			for x in [-0.22, 0.22]:
				var pts: Array = []
				for i in 10:
					pts.append(Vector3(x + cos(i * 1.4) * 0.05, i * 0.085, sin(i * 1.4) * 0.05))
				ToolModels._mi(root, ToolModels.tube(pts, 0.012, 5, 0.6), green)
				for i in 6:
					var lf := ToolModels._mi(root, _sphere(0.06, 0.08), green if i % 2 == 0 else dark, Vector3(x + cos(i * 2.3) * 0.1, 0.15 + i * 0.12, sin(i * 2.3) * 0.1))
					lf.scale = Vector3(1.6, 0.4, 1.0)
				for i in 3:
					ToolModels._mi(root, _sphere(0.05, 0.09), _m(Color(0.85, 0.12, 0.08), 0.35), Vector3(x + cos(i * 2.0 + 1.0) * 0.08, 0.3 + i * 0.18, sin(i * 2.0 + 1.0) * 0.08))
		"biber_tohumu":
			for i in 9:
				var a := TAU * i / 9.0
				var lf := ToolModels._mi(root, _sphere(0.08, 0.1), green if i % 2 == 0 else dark, Vector3(cos(a) * 0.18, 0.18 + (i % 3) * 0.08, sin(a) * 0.18))
				lf.scale = Vector3(1.5, 0.45, 0.9)
				lf.rotation.y = -a
			ToolModels._mi(root, ToolModels.tube([Vector3(0, 0, 0), Vector3(0, 0.3, 0)], 0.02, 6), green)
			for i in 5:
				var a := TAU * i / 5.0 + 0.3
				var pep := ToolModels._mi(root, _sphere(0.035, 0.16), _m(Color(0.85, 0.15, 0.08) if i % 2 == 0 else Color(0.2, 0.55, 0.15), 0.3), Vector3(cos(a) * 0.14, 0.14, sin(a) * 0.14))
				pep.rotation.z = 0.3
		"karpuz_tohumu":
			# Yayılan sülükler, geniş yapraklar ve çizgili karpuz
			for i in 4:
				var a := TAU * i / 4.0
				ToolModels._mi(root, ToolModels.tube([Vector3.ZERO, Vector3(cos(a) * 0.25, 0.03, sin(a) * 0.25), Vector3(cos(a + 0.4) * 0.42, 0.02, sin(a + 0.4) * 0.42)], 0.01, 5), green)
				for k in 2:
					var lf := ToolModels._mi(root, _sphere(0.08, 0.06), dark, Vector3(cos(a + k * 0.3) * (0.22 + k * 0.16), 0.04, sin(a + k * 0.3) * (0.22 + k * 0.16)))
					lf.scale = Vector3(1.3, 0.3, 1.3)
			var img := Image.create(32, 8, false, Image.FORMAT_RGB8)
			for x in 32:
				for y in 8:
					img.set_pixel(x, y, Color(0.15, 0.4, 0.15) if (x / 3) % 2 == 0 else Color(0.35, 0.6, 0.28))
			var mel := StandardMaterial3D.new()
			mel.albedo_texture = ImageTexture.create_from_image(img)
			mel.roughness = 0.4
			var w := ToolModels._mi(root, _sphere(0.17, 0.34), mel, Vector3(0.12, 0.13, 0.05), Vector3(0, 0.4, PI / 2.0))
			w.scale = Vector3(1.0, 1.3, 1.0)
		"zeytin_fidani":
			var bark := _m(Color(0.42, 0.36, 0.28), 0.95)
			ToolModels._mi(root, ToolModels.tube([Vector3(0, 0, 0), Vector3(0.04, 0.25, 0), Vector3(-0.03, 0.5, 0.02), Vector3(0.02, 0.7, 0)], 0.04, 7, 0.5), bark)
			for i in 5:
				var a := TAU * i / 5.0
				var c := ToolModels._mi(root, _sphere(0.18, 0.2), _m(Color(0.5, 0.57, 0.44), 0.9), Vector3(cos(a) * 0.15, 0.72 + (i % 2) * 0.08, sin(a) * 0.15))
				c.scale = Vector3(1.2, 0.7, 1.2)
				for k in 2:
					ToolModels._mi(root, _sphere(0.025, 0.05), _m(Color(0.22, 0.2, 0.15), 0.35), Vector3(cos(a + k) * 0.22, 0.62, sin(a + k) * 0.22))
		_:
			# Patates: sık yapraklı alçak çalı ve beyaz çiçekler
			for i in 11:
				var a := TAU * i / 11.0
				var r := 0.1 + (i % 3) * 0.07
				var lf := ToolModels._mi(root, _sphere(0.07, 0.1), green if i % 2 == 0 else dark, Vector3(cos(a) * r, 0.1 + (i % 4) * 0.05, sin(a) * r))
				lf.scale = Vector3(1.4, 0.5, 1.0)
				lf.rotation.y = -a
			for i in 4:
				var a := TAU * i / 4.0 + 0.5
				ToolModels._mi(root, _sphere(0.025, 0.04), _m(Color(0.96, 0.95, 0.9)), Vector3(cos(a) * 0.12, 0.3, sin(a) * 0.12))
	return root
