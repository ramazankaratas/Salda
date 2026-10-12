extends Node3D
## Açılış ekranı vitrini: bütün geliştirmeleri tamamlanmış büyük bir sal, kapalı bir ev
## ve üstünde yaşayan kazazede. Oyun başlayınca silinir.
## Aynı düzen (furnish) "tam bitmiş kayıt" üretmek için oyuncunun salına da uygulanır.

const RaftScript = preload("res://scripts/raft.gd")
const CastawayScript = preload("res://scripts/castaway.gd")

var main
var raft


func build(at: Vector3) -> void:
	raft = RaftScript.new()
	raft.name = "VitrinSal"
	raft.main = main
	add_child(raft)
	raft.reset_raft()
	for bd in furnish(raft, true):
		bd.showcase = true
	var man := CastawayScript.new()
	man.position = raft.cell_pos(Vector2i(0, 2)) + Vector3(0.0, raft.top_y(), 0.1)
	raft.add_child(man)
	raft.lift = 0.3
	raft.base_pos = at
	raft.teleport(Transform3D(Basis.IDENTITY, at))


## Salı tam donatır: 8 x 7 güçlendirilmiş zemin, kapalı ev ve bütün yapılar.
## live=true: vitrin (ateşler yanar, ızgarada balık pişer); false: oyunda alınmaya hazır ürünler.
static func furnish(r, live: bool) -> Array:
	for x in range(-3, 5):
		for y in range(-2, 5):
			if not r.tiles.has(Vector2i(x, y)):
				r.add_tile(Vector2i(x, y))
			r.reinforce(Vector2i(x, y))
	_house(r, Vector2i(0, -1), Vector2i(2, 1))
	var b := {
		Vector2i(0, -1): ["yatak", PI / 2.0],
		Vector2i(1, -1): ["masa", 0.0],
		Vector2i(1, 0): ["sandalye", PI],
		Vector2i(0, 0): ["hali", 0.0],
		Vector2i(2, -1): ["sandik", PI],
		Vector2i(2, 1): ["sandik", -PI / 2.0],
		Vector2i(2, 0): ["fener", 0.0],
		Vector2i(-2, 0): ["yelken", 0.0],
		Vector2i(-1, 2): ["aritici", PI / 2.0],
		Vector2i(-1, 3): ["izgara", PI / 2.0],
		Vector2i(-3, -2): ["saksi", 0.0],
		Vector2i(-2, -2): ["saksi", 0.0],
		Vector2i(-1, -2): ["yagmur_toplayici", 0.0],
		Vector2i(4, -2): ["ocak", -PI / 2.0],
		Vector2i(4, 4): ["capa", 0.0],
		Vector2i(-3, 1): ["toplayici", -PI / 2.0],
		Vector2i(-3, 3): ["toplayici", -PI / 2.0],
		Vector2i(4, 1): ["toplayici", PI / 2.0],
		Vector2i(0, 4): ["fener", 0.0],
		Vector2i(3, 4): ["fener", 0.0],
		Vector2i(4, 2): ["saksi", 0.0],
		Vector2i(-2, 2): ["dumen", 0.0],
		Vector2i(1, 4): ["motor", PI],
		Vector2i(3, 0): ["telsiz", -PI / 2.0],
		Vector2i(3, 3): ["nazar", 0.0],
		Vector2i(1, 1): ["kedi_yatagi", 0.0],
		Vector2i(-3, 4): ["diken_tuzagi", 0.0],
		Vector2i(4, -1): ["diken_tuzagi", 0.0],
	}
	var placed: Array = []
	for c in b:
		var kind: String = b[c][0]
		var rot: float = b[c][1]
		if kind in ["capa", "toplayici"]:
			rot = r.outward_angle(c)
		var data := {"rot": rot, "cell": [c.x, c.y], "kind": kind}
		match kind:
			"saksi":
				data["planted"] = true
				data["growth"] = 1.0
				data["cooking"] = ["domates_tohumu", "biber_tohumu", "karpuz_tohumu", "zeytin_fidani"][(c.x + c.y + 8) % 4]
			"aritici":
				if live:
					data["busy"] = true
					data["timer"] = 1.0e9
				else:
					data["output"] = "temiz_su"
			"ocak":
				if live:
					data["busy"] = true
					data["timer"] = 1.0e9
				else:
					data["output"] = "metal_kulce"
			"izgara":
				if live:
					data["busy"] = true
					data["timer"] = 1.0e9
					data["cooking"] = "ham_balik"
				else:
					data["output"] = "pismis_balik"
			"yagmur_toplayici":
				data["stock"] = 3
			"yelken":
				data["open"] = true
				data["dir"] = [0.6, -0.8]
		var bd = r.place_building(kind, c, data)
		if bd != null:
			placed.append(bd)
	return placed


## Dört duvarı, kapısı, pencereleri ve tam çatısıyla kapalı bir ev.
static func _house(r, a: Vector2i, b: Vector2i) -> void:
	for x in range(a.x, b.x + 1):
		r.add_structure("pencere" if x == a.x + 1 else "duvar", Vector2i(x, a.y), "N")
		r.add_structure("kapi" if x == a.x else ("pencere" if x == b.x else "duvar"), Vector2i(x, b.y), "S")
	for y in range(a.y, b.y + 1):
		r.add_structure("pencere" if y == a.y + 1 else "duvar", Vector2i(a.x, y), "W")
		r.add_structure("pencere" if y == a.y + 1 else "duvar", Vector2i(b.x, y), "E")
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			r.add_structure("cati", Vector2i(x, y), "N", Vector2i(x, y) == Vector2i((a.x + b.x) / 2, (a.y + b.y) / 2) or (x != (a.x + b.x) / 2 and y == a.y))


func center_global() -> Vector3:
	return raft.center_global()
