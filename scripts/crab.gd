extends StaticBody3D
## Kumsalda yan yan yürüyen yengeç (koddan). Yaklaşınca kaçar; E ile yakalanır (yengeç eti).

var main
var island
var heading := 0.0
var speed := 0.6
var turn_t := 0.0
var legs: Array = []
var t := 0.0
var body: Node3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	set_meta("target", self)
	heading = randf() * TAU
	body = Node3D.new()
	add_child(body)
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.72, 0.28, 0.14)
	shell.roughness = 0.6
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.35, 0.12, 0.06)
	var cara := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radial_segments = 20
	sm.rings = 10
	sm.radius = 0.12
	sm.height = 0.12
	cara.mesh = sm
	cara.scale = Vector3(1.25, 0.55, 1.0)
	cara.position.y = 0.08
	cara.material_override = shell
	body.add_child(cara)
	for s in [-1.0, 1.0]:
		# Kıskaçlar (önde, yerel +Z)
		var claw := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radial_segments = 20
		cm.rings = 10
		cm.radius = 0.045
		cm.height = 0.07
		claw.mesh = cm
		claw.scale = Vector3(1.0, 0.7, 1.5)
		claw.position = Vector3(s * 0.11, 0.08, 0.15)
		claw.material_override = shell
		body.add_child(claw)
		# Gözler
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radial_segments = 20
		em.rings = 10
		em.radius = 0.012
		em.height = 0.024
		eye.mesh = em
		eye.position = Vector3(s * 0.035, 0.13, 0.09)
		eye.material_override = dark
		body.add_child(eye)
		# Bacaklar
		for i in 3:
			var leg := MeshInstance3D.new()
			var lm := CylinderMesh.new()
			lm.top_radius = 0.008
			lm.bottom_radius = 0.006
			lm.height = 0.16
			leg.mesh = lm
			leg.material_override = shell
			leg.position = Vector3(s * 0.14, 0.05, -0.05 + i * 0.06)
			leg.rotation.z = s * 1.0
			body.add_child(leg)
			legs.append([leg, s, i])
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.25
	cs.shape = sh
	cs.position.y = 0.1
	add_child(cs)


func prompt(_player) -> String:
	return "E: Yengeç yakala"


func interact(player) -> void:
	player.give("yengec_eti", 1)
	main.audio.play("pickup", -4.0)
	queue_free()


func _process(delta: float) -> void:
	if main.paused or island == null:
		return
	t += delta
	var to_player: Vector3 = main.player.global_position - global_position
	to_player.y = 0.0
	var fleeing := to_player.length() < 3.0
	turn_t -= delta
	if fleeing:
		heading = atan2(-to_player.x, -to_player.z)
	elif turn_t <= 0.0:
		turn_t = randf_range(1.5, 4.0)
		heading += randf_range(-1.5, 1.5)
	var spd := 1.6 if fleeing else (speed if fmod(t, 5.0) < 3.0 else 0.0)
	# Yengeç yan yürür: gövde gidiş yönüne dik bakar
	var dir := Vector3(sin(heading), 0, cos(heading))
	var local: Vector3 = island.to_local(global_position + dir * spd * delta)
	# Kumsal şeridinde kal (kıyıdan çok uzaklaşma, suya girme)
	var r := Vector2(local.x, local.z).length()
	if r > island.shore_radius - 1.0 or r < 6.0:
		heading += PI
		local = island.to_local(global_position)
	var g: Vector3 = island._ground(local.x, local.z)
	position = g
	body.rotation.y = heading + PI / 2.0
	for l in legs:
		(l[0] as Node3D).rotation.x = sin(t * 18.0 + l[2] * 2.0 + l[1]) * 0.5 * (1.0 if spd > 0.0 else 0.0)
