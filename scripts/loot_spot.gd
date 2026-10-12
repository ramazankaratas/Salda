extends StaticBody3D
## Açık deniz batıklarında E ile açılan ganimet: sandık, amfora, konteyner, balık ağı yığını.
## Açılınca içindekini verir; sahası kalıcı olduğu için açılmışlığı sahanın kaydında tutulur.

const ToolModels = preload("res://scripts/tool_models.gd")
const Items = preload("res://scripts/items.gd")

## Tür: ad, ganimet listesi ([eşya, en az, en çok, şans])
const KINDS := {
	"sandik": {"name": "Batık sandık", "verb": "Sandığı aç",
		"loot": [["antik_sikke", 2, 5, 1.0], ["metal_kulce", 1, 3, 0.7], ["inci", 1, 2, 0.4], ["mercek", 1, 1, 0.2], ["bronz_heykel", 1, 1, 0.25]]},
	"amfora": {"name": "Amfora", "verb": "Amforayı kır",
		"loot": [["zeytinyagi", 1, 2, 0.6], ["antik_sikke", 1, 3, 0.5], ["zeytin_fidani", 1, 1, 0.15], ["tohum", 2, 3, 0.25]]},
	"heykel": {"name": "Bronz heykel parçası", "verb": "Heykel parçasını al",
		"loot": [["bronz_heykel", 1, 1, 1.0]]},
	"konteyner": {"name": "Paslı konteyner", "verb": "Kapağı zorla",
		"loot": [["civi", 6, 14, 0.8], ["metal_kulce", 2, 4, 0.7], ["plastik", 4, 8, 0.6], ["konserve", 2, 4, 0.5], ["kumas", 2, 3, 0.4], ["su_sise", 2, 3, 0.4]]},
	"ag": {"name": "Balıkçı ağı yığını", "verb": "Ağı karıştır",
		"loot": [["ip", 3, 6, 0.9], ["hurda", 2, 4, 0.7], ["ham_balik", 1, 2, 0.4], ["kopekbaligi_yemi", 1, 2, 0.3], ["olta", 1, 1, 0.15]]},
	"varil": {"name": "Yakıt varili", "verb": "Varili aç",
		"loot": [["zeytinyagi", 1, 3, 0.6], ["hurda", 2, 3, 0.7], ["konserve", 1, 2, 0.4]]},
}

var main
var site: Dictionary = {}
var index := 0
var kind := "sandik"
var opened := false
var lid: Node3D
var bubbles: GPUParticles3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	set_meta("target", self)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.7
	cs.shape = sh
	cs.position.y = 0.4
	add_child(cs)
	add_child(_model())
	if opened:
		_show_opened()
	else:
		bubbles = _bubbles()
		add_child(bubbles)


func _m(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _model() -> Node3D:
	var root := Node3D.new()
	match kind:
		"sandik":
			var wood := ToolModels.mat("dark_wood")
			var band := _m(Color(0.35, 0.28, 0.18), 0.6, 0.6)
			var b := BoxMesh.new()
			b.size = Vector3(0.8, 0.42, 0.5)
			ToolModels._mi(root, b, wood, Vector3(0, 0.21, 0))
			for x in [-0.27, 0.27]:
				var bb := BoxMesh.new()
				bb.size = Vector3(0.05, 0.44, 0.52)
				ToolModels._mi(root, bb, band, Vector3(x, 0.21, 0))
			lid = Node3D.new()
			lid.position = Vector3(0, 0.42, -0.25)
			root.add_child(lid)
			var lm := CylinderMesh.new()
			lm.top_radius = 0.25
			lm.bottom_radius = 0.25
			lm.height = 0.8
			lm.radial_segments = 16
			var lmi := ToolModels._mi(lid, lm, wood, Vector3(0, 0, 0.25), Vector3(0, 0, PI / 2.0))
			lmi.scale = Vector3(1.0, 1.0, 0.45)
		"amfora":
			var clay := _m(Color(0.62, 0.38, 0.24), 0.95)
			var a := ToolModels._mi(root, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.05, 0.02), Vector2(0.2, 0.3), Vector2(0.23, 0.52), Vector2(0.16, 0.78),
				Vector2(0.07, 0.88), Vector2(0.08, 1.0), Vector2(0.0, 1.0)], 14), clay, Vector3(0, 0.22, 0), Vector3(PI / 2.0 - 0.25, randf() * TAU, 0))
			a.name = "Govde"
			for sd in [-1.0, 1.0]:
				ToolModels._mi(a, ToolModels.tube([Vector3(sd * 0.07, 0.86, 0), Vector3(sd * 0.17, 0.82, 0), Vector3(sd * 0.15, 0.68, 0)], 0.02, 5), clay)
		"heykel":
			# Yosun tutmuş bronz büst: göğüs, boyun, baş
			var bronze := _m(Color(0.25, 0.42, 0.35), 0.55, 0.7)
			ToolModels._mi(root, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.3, 0.0), Vector2(0.32, 0.25), Vector2(0.24, 0.42), Vector2(0.09, 0.48), Vector2(0.0, 0.48)], 14), bronze, Vector3.ZERO, Vector3(0.3, 0, 0.5))
			var head := SphereMesh.new()
			head.radius = 0.15
			head.height = 0.36
			head.radial_segments = 14
			head.rings = 8
			ToolModels._mi(root, head, bronze, Vector3(0.22, 0.4, 0.1))
		"konteyner":
			var rust := _m([Color(0.55, 0.22, 0.12), Color(0.18, 0.32, 0.45), Color(0.3, 0.42, 0.25)][randi() % 3], 0.9, 0.3)
			var b := BoxMesh.new()
			b.size = Vector3(2.4, 1.2, 1.2)
			ToolModels._mi(root, b, rust, Vector3(0, 0.6, 0))
			for k in 9:
				var r := BoxMesh.new()
				r.size = Vector3(0.05, 1.1, 1.24)
				ToolModels._mi(root, r, rust, Vector3(-1.1 + k * 0.275, 0.6, 0))
			lid = Node3D.new()
			lid.position = Vector3(1.22, 0.6, -0.6)
			root.add_child(lid)
			var door := BoxMesh.new()
			door.size = Vector3(0.04, 1.15, 1.18)
			ToolModels._mi(lid, door, rust, Vector3(0, 0, 0.59))
		"ag":
			var net := _m(Color(0.35, 0.42, 0.38), 1.0)
			for k in 4:
				var s := SphereMesh.new()
				s.radius = randf_range(0.3, 0.45)
				s.height = s.radius * 0.8
				s.radial_segments = 12
				s.rings = 6
				ToolModels._mi(root, s, net, Vector3(randf_range(-0.4, 0.4), 0.12, randf_range(-0.4, 0.4)))
			var fl := _m(Color(0.95, 0.5, 0.1), 0.6)
			for k in 4:
				var f := SphereMesh.new()
				f.radius = 0.06
				f.height = 0.12
				f.radial_segments = 8
				f.rings = 4
				ToolModels._mi(root, f, fl, Vector3(randf_range(-0.5, 0.5), 0.3, randf_range(-0.5, 0.5)))
		"varil":
			var drum := _m(Color(0.6, 0.15, 0.1), 0.7, 0.4)
			var c := CylinderMesh.new()
			c.top_radius = 0.3
			c.bottom_radius = 0.3
			c.height = 0.9
			c.radial_segments = 14
			ToolModels._mi(root, c, drum, Vector3(0, 0.3, 0), Vector3(PI / 2.0, randf(), 0))
	return root


func prompt(_player) -> String:
	if opened:
		return "%s (boş)" % KINDS[kind]["name"]
	return "E: %s" % KINDS[kind]["verb"]


func interact(player) -> void:
	if opened:
		return
	opened = true
	var got: Array = []
	for row in KINDS[kind]["loot"]:
		if randf() <= float(row[3]):
			var n := randi_range(int(row[1]), int(row[2]))
			player.give(row[0], n)
			got.append("%d %s" % [n, Items.name_of(row[0])])
	if got.is_empty():
		player.give("hurda", 1)
		got.append("1 Hurda Metal")
	var looted: Array = site.get("looted", [])
	if not looted.has(index):
		looted.append(index)
	site["looted"] = looted
	main.audio.play("chest_open" if kind != "amfora" else "chop", -4.0, "Arayuz")
	main.hud.toast("%s: %s" % [KINDS[kind]["name"], ", ".join(got)], 4.0)
	main.quests.event("loot_wreck", kind)
	_show_opened()


## Açılmamış ganimetin üstünden ince kabarcıklar yükselir (karanlıkta bulmayı kolaylaştırır).
func _bubbles() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 6
	p.lifetime = 3.5
	p.position.y = 0.5
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 10.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0, 0.2, 0)
	p.process_material = pm
	var s := SphereMesh.new()
	s.radius = 0.035
	s.height = 0.07
	s.radial_segments = 6
	s.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.95, 1.0, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.5, 0.75, 0.9)
	m.emission_energy_multiplier = 0.6
	s.material = m
	p.draw_pass_1 = s
	return p


func _show_opened() -> void:
	if bubbles != null:
		bubbles.queue_free()
		bubbles = null
	match kind:
		"amfora":
			var g := find_child("Govde", true, false)
			if g != null:
				(g as Node3D).scale = Vector3(1.0, 0.45, 1.0)
		"heykel":
			for c in get_children():
				if c is Node3D and not (c is CollisionShape3D):
					(c as Node3D).visible = false
		_:
			if lid != null:
				lid.rotation.x = -1.5 if kind == "sandik" else 0.0
				lid.rotation.y = 1.4 if kind == "konteyner" else 0.0
