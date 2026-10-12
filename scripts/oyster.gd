extends StaticBody3D
## Deniz tabanında istiridye: E ile açılır; istiridye eti verir, üçte birinde inci de çıkar.

const ToolModels = preload("res://scripts/tool_models.gd")

var main
var opened := false
var lid: Node3D
static var _shell: StandardMaterial3D
static var _inner: StandardMaterial3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	set_meta("target", self)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.4
	cs.shape = sh
	cs.position.y = 0.15
	add_child(cs)
	add_child(model())
	lid = get_child(get_child_count() - 1).get_node("Kapak")


## İstiridye modeli: dalgalı kenarlı iki kabuk; üstteki "Kapak" adlı düğüm açılır.
static func model() -> Node3D:
	if _shell == null:
		_shell = StandardMaterial3D.new()
		_shell.albedo_color = Color(0.48, 0.45, 0.4)
		_shell.roughness = 1.0
		_inner = StandardMaterial3D.new()
		_inner.albedo_color = Color(0.92, 0.9, 0.95)
		_inner.roughness = 0.2
		_inner.metallic_specular = 0.9
	var root := Node3D.new()
	var prof: Array = []
	for k in 9:
		var t := k / 8.0
		prof.append(Vector2(0.17 * sin(t * PI * 0.5), 0.05 * (1.0 - t * t)))
	var bottom := ToolModels._mi(root, ToolModels.lathe(prof, 14), _shell, Vector3(0, 0.05, 0), Vector3(PI, 0, 0))
	bottom.scale = Vector3(1.0, 1.0, 0.8)
	var inner := CylinderMesh.new()
	inner.top_radius = 0.15
	inner.bottom_radius = 0.15
	inner.height = 0.01
	var im := ToolModels._mi(root, inner, _inner, Vector3(0, 0.05, 0))
	im.scale = Vector3(1.0, 1.0, 0.8)
	var hinge := Node3D.new()
	hinge.name = "Kapak"
	hinge.position = Vector3(-0.16, 0.05, 0)
	root.add_child(hinge)
	var top := ToolModels._mi(hinge, ToolModels.lathe(prof, 14), _shell, Vector3(0.16, 0.0, 0))
	top.scale = Vector3(1.0, 0.8, 0.8)
	for k in 5:
		var rib := ToolModels._mi(hinge, ToolModels.tube([Vector3(0.16, 0.04, 0), Vector3(0.16 + cos(k * 0.6 - 1.2) * 0.15, 0.005, sin(k * 0.6 - 1.2) * 0.12)], 0.008, 4), _shell)
		rib.position = Vector3.ZERO
	return root


func prompt(_player) -> String:
	return "" if opened else "E: İstiridyeyi aç"


func interact(player) -> void:
	if opened:
		return
	opened = true
	lid.rotation.z = 1.1
	player.give("istiridye", 1)
	if randf() < 0.35:
		player.give("inci", 1)
		main.hud.toast("İstiridyenin içinden bir inci çıktı!", 3.0)
		main.audio.play("chest_open", -8.0, "Arayuz")
	else:
		main.audio.play("pickup", -6.0)
