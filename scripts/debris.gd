extends Node3D
## Denizde sürüklenen enkaz: tahta, plastik, palmiye yaprağı ya da (içinden ganimet çıkan) varil.

const Waves = preload("res://scripts/waves.gd")
const Props = preload("res://scripts/props.gd")
const Items = preload("res://scripts/items.gd")
const PalmScript = preload("res://scripts/palm.gd")
const ToolModels = preload("res://scripts/tool_models.gd")

const WEIGHTS := {"tahta": 34, "plastik": 30, "yaprak": 24, "varil": 12}

var main
var kind := "tahta"
var hooked := false
var bob := 0.0
var spin := 0.0


static func random_kind() -> String:
	var total := 0
	for k in WEIGHTS:
		total += WEIGHTS[k]
	var r := randi() % total
	for k in WEIGHTS:
		r -= WEIGHTS[k]
		if r < 0:
			return k
	return "tahta"


func _ready() -> void:
	bob = randf() * TAU
	spin = randf_range(-0.3, 0.3)
	rotation.y = randf() * TAU
	match kind:
		"tahta":
			for i in randi_range(1, 2):
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(1.1, 0.06, 0.22)
				mi.mesh = bm
				mi.position = Vector3(0, 0.03 * i, 0.25 * i)
				mi.rotation.y = 0.3 * i
				mi.material_override = main.raft.mat_plank
				add_child(mi)
		"plastik":
			Props.place(self, "res://assets/models/plastic_bottle_gallon/plastic_bottle_gallon_1k.gltf", Vector3.ZERO, Vector3(PI / 2.0, 0, randf()), 1.8, "center")
		"yaprak":
			# Suda yüzen palmiye yaprakları (adadaki palmiyelerle aynı)
			add_child(PalmScript.frond_bundle(2, 1.0))
		"varil":
			Props.place(self, "res://assets/models/Barrel_01/Barrel_01_1k.gltf", Vector3.ZERO, Vector3(0, 0, PI / 2.0), 1.0, "center")
		"sise":
			# Yeşil cam şişe, mantar tıpa, içinde dürülmüş kâğıt
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(0.25, 0.55, 0.32, 0.72)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.roughness = 0.05
			glass.metallic_specular = 0.9
			var b := ToolModels._mi(self, ToolModels.lathe([Vector2(0.0, 0.0), Vector2(0.07, 0.0), Vector2(0.075, 0.2), Vector2(0.03, 0.27), Vector2(0.025, 0.33), Vector2(0.0, 0.33)], 14), glass, Vector3(0, 0, -0.15), Vector3(PI / 2.0, 0, 0))
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var cork := StandardMaterial3D.new()
			cork.albedo_color = Color(0.62, 0.45, 0.28)
			var cm := CylinderMesh.new()
			cm.top_radius = 0.025
			cm.bottom_radius = 0.022
			cm.height = 0.05
			ToolModels._mi(self, cm, cork, Vector3(0, 0, 0.19), Vector3(PI / 2.0, 0, 0))
			scale = Vector3.ONE * 1.6
			var paper := StandardMaterial3D.new()
			paper.albedo_color = Color(0.92, 0.86, 0.7)
			var pm := CylinderMesh.new()
			pm.top_radius = 0.03
			pm.bottom_radius = 0.03
			pm.height = 0.16
			ToolModels._mi(self, pm, paper, Vector3(0, 0, -0.04), Vector3(PI / 2.0, 0, 0))


## Varil açılınca rastgele ganimet; diğerleri kendisi (tahta 1-2 adet).
func loot() -> Dictionary:
	match kind:
		"varil":
			var out := {}
			for i in randi_range(3, 5):
				var item: String = Items.BARREL_LOOT.pick_random()
				out[item] = out.get(item, 0) + 1
			return out
		"tahta":
			return {"tahta": get_child_count()}
		"sise":
			# Şişe açılınca notu okunur; şişe camı da işe yarar
			main.open_bottle()
			return {"cam": 1}
	return {kind: 1}


func _process(delta: float) -> void:
	if hooked or main.paused:
		return
	bob += delta
	position += main.DEBRIS_CURRENT * delta
	# Adaya çarpınca kıyı boyunca suda kalır (sığ suda toplanabilir).
	position = main.push_out_of_islands(position, 1.2)
	position.y = Waves.height(position.x, position.z) + sin(bob * 1.7) * 0.02
	rotation.y += spin * delta
