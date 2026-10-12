extends StaticBody3D
## Kazma ile kırılan kaya. "tas": gri kaya (taş verir); "demir": pas renkli damarlı kaya (demir cevheri + taş).
## Her vuruşta taş kırıntısı saçılır ve kaya sarsılır; son vuruşta parçalanır, parçalar E ile toplanır.

const Props = preload("res://scripts/props.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const ToolModels = preload("res://scripts/tool_models.gd")
const HITS := 4

var main
var island
var kind := "tas"
var hp := HITS
var model: Node3D
var shake := 0.0
var broken := false


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	set_meta("target", self)
	model = Props.place(self, "res://assets/models/boulder_01/boulder_01_1k.gltf", Vector3(0, -0.15, 0), Vector3(0, randf() * TAU, 0), randf_range(1.0, 1.3))
	if kind == "demir":
		Props.tint(model, Color(0.85, 0.62, 0.48))
		# Pas renkli cevher damarları
		var ore := StandardMaterial3D.new()
		ore.albedo_color = Color(0.55, 0.25, 0.12)
		ore.metallic = 0.6
		ore.roughness = 0.5
		for i in 7:
			var a := TAU * i / 7.0 + randf() * 0.4
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radial_segments = 20
			sm.rings = 10
			sm.radius = randf_range(0.08, 0.14)
			sm.height = sm.radius * 1.3
			mi.mesh = sm
			mi.material_override = ore
			mi.position = Vector3(cos(a) * 0.55, randf_range(0.25, 0.7), sin(a) * 0.55)
			model.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.75
	cs.shape = sh
	cs.position.y = 0.45
	add_child(cs)


func prompt(player) -> String:
	if broken:
		return ""
	var name := "Demirli kaya" if kind == "demir" else "Kaya"
	if player.held_id() == "kazma":
		return "Sol tık: %s kaz (%d/%d)" % [name, HITS - hp, HITS]
	return "%s: kazmak için kazma gerekli (Tab → Araç)" % name


func interact(_player) -> void:
	pass


func mine(player) -> void:
	if broken:
		return
	hp -= 1
	shake = 0.25
	var hit: Vector3 = global_position + Vector3(0, 0.6, 0) + (player.global_position - global_position).normalized() * 0.6
	main.audio.play_at("mine", hit, 0.0, 8.0)
	_chips(hit)
	if hp <= 0:
		_break()


func _chips(at: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.8
	p.explosiveness = 0.95
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 60.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.angular_velocity_min = -500.0
	pm.angular_velocity_max = 500.0
	p.process_material = pm
	var bm := BoxMesh.new()
	bm.size = Vector3(0.04, 0.03, 0.04)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.3, 0.2) if kind == "demir" else Color(0.55, 0.53, 0.5)
	bm.material = m
	p.draw_pass_1 = bm
	get_tree().current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


## Kaya parçalanır: taş (ve cevher) parçaları yere saçılır, E ile toplanır.
func _break() -> void:
	broken = true
	collision_layer = 0
	main.quests.event("mine", kind)
	var drops: Array = [["tas", 2], ["tas", 1]]
	if kind == "demir":
		drops = [["demir_cevheri", 2], ["demir_cevheri", 1], ["tas", 1]]
	for i in drops.size():
		var a := TAU * i / drops.size() + randf() * 0.5
		var local: Vector3 = island.to_local(global_position + Vector3(cos(a), 0, sin(a)) * 0.9)
		var g: Vector3 = island._ground(local.x, local.z)
		var p = PickupScript.new()
		p.main = main
		p.item = drops[i][0]
		p.amount = drops[i][1]
		island.add_child(p)
		p.position = g
		var vis := Props.place(p, "res://assets/models/boulder_01/boulder_01_1k.gltf", Vector3(0, 0.05, 0), Vector3(randf(), randf() * TAU, 0), 0.25)
		if drops[i][0] == "demir_cevheri":
			Props.tint(vis, Color(0.75, 0.45, 0.3))
	var tw := create_tween()
	tw.tween_property(model, "scale", Vector3.ONE * 0.05, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	if shake > 0.0 and not broken:
		shake -= delta
		model.position.x = sin(shake * 90.0) * 0.03
