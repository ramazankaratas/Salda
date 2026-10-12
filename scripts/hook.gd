extends Node3D
## Kanca: sol tık basılı tutulup güç toplanır, bırakınca fırlatılır.
## Suya düşünce sol tık basılı tutularak çekilir; yolundaki enkaza takılır.
## Sağ tık: kancayı anında geri al. Her atış kancanın dayanıklılığını 1 azaltır.

const Waves = preload("res://scripts/waves.gd")
const ToolModels = preload("res://scripts/tool_models.gd")

enum H { HELD, CHARGING, FLYING, WATER }

const REEL_SPEED := 4.5
const CATCH_RADIUS := 1.1
const MAX_DIST := 34.0

var main
var state := H.HELD
var charge := 0.0
var vel := Vector3.ZERO
var caught: Array = []
var rope: MeshInstance3D
var head: MeshInstance3D
var splash: GPUParticles3D
var reel_snd_cd := 0.0
## Test için: true iken sudaki kanca tuşa basılmadan çekilir.
var auto_reel := false


func _ready() -> void:
	# Oyuncu hareket ettikten sonra güncellensin: ip elden kopuk görünmesin.
	process_priority = 10
	head = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.rings = 24
	tm.ring_segments = 10
	tm.inner_radius = 0.07
	tm.outer_radius = 0.11
	head.mesh = tm
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.45, 0.45, 0.48)
	hm.metallic = 0.8
	hm.roughness = 0.35
	head.material_override = hm
	add_child(head)

	rope = MeshInstance3D.new()
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rope.extra_cull_margin = 16384.0
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.75, 0.65, 0.45)
	rope.material_override = rm
	rope.top_level = true
	add_child(rope)

	splash = make_splash()
	add_child(splash)
	visible = false


static func make_splash() -> GPUParticles3D:
	var s := GPUParticles3D.new()
	s.amount = 30
	s.lifetime = 0.8
	s.one_shot = true
	s.explosiveness = 0.95
	s.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, -9.8, 0)
	s.process_material = pm
	var q := SphereMesh.new()
	q.radial_segments = 20
	q.rings = 10
	q.radius = 0.03
	q.height = 0.06
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.85, 0.95, 1.0)
	q.material = sm
	s.draw_pass_1 = q
	s.top_level = true
	return s


func is_out() -> bool:
	return state == H.FLYING or state == H.WATER


func _retract(collect: bool) -> void:
	if collect:
		var got := {}
		for d in caught:
			var l: Dictionary = d.loot()
			for k in l:
				got[k] = got.get(k, 0) + l[k]
			main.remove_debris(d)
		for k in got:
			main.player.give(k, got[k])
	else:
		for d in caught:
			d.hooked = false
	caught.clear()
	state = H.HELD
	visible = false


func _process(delta: float) -> void:
	if main.paused:
		return
	var p = main.player
	var hand: Vector3 = p.hand_point()
	var using: bool = p.is_hook() and p.can_act()
	var metal: bool = p.held_id() == "metal_kanca"

	match state:
		H.HELD:
			charge = 0.0
			if using and Input.is_action_just_pressed("use"):
				state = H.CHARGING
		H.CHARGING:
			charge = minf(1.0, charge + delta * 0.9)
			if not using:
				state = H.HELD
			elif Input.is_action_just_released("use"):
				var fwd: Vector3 = -p.camera.global_transform.basis.z
				global_position = hand
				vel = fwd * (5.0 + 13.0 * charge) + Vector3.UP * 2.0
				state = H.FLYING
				visible = true
				main.audio.play("hook_throw", -4.0)
				p.use_durability()
		H.FLYING:
			vel.y -= 9.8 * delta
			global_position += vel * delta
			var wh := Waves.height(global_position.x, global_position.z)
			if global_position.y <= wh:
				global_position.y = wh
				state = H.WATER
				splash.global_position = global_position
				splash.restart()
				main.audio.play_at("splash", global_position, -6.0)
		H.WATER:
			global_position += main.DEBRIS_CURRENT * delta
			if auto_reel or (using and Input.is_action_pressed("use")):
				var to: Vector3 = p.global_position - global_position
				to.y = 0.0
				if to.length() < 1.6:
					_retract(true)
					return
				global_position += to.normalized() * REEL_SPEED * (1.5 if metal else 1.0) * delta
				reel_snd_cd -= delta
				if reel_snd_cd <= 0.0:
					reel_snd_cd = 0.7
					main.audio.play("reel", -12.0)
				for d in main.debris:
					if not d.hooked and d.global_position.distance_to(global_position) < CATCH_RADIUS * (1.5 if metal else 1.0):
						d.hooked = true
						caught.append(d)
			global_position.y = Waves.height(global_position.x, global_position.z)

	if is_out() and Input.is_action_just_pressed("cancel") and p.is_hook():
		_retract(false)
		return
	if is_out() and (global_position.distance_to(p.global_position) > MAX_DIST or not p.is_hook()):
		_retract(false)
		return

	for i in caught.size():
		var d: Node3D = caught[i]
		d.global_position = global_position + Vector3(0.3 * (i % 3) - 0.3, -0.05, 0.3 * (i / 3))

	rope.visible = is_out()
	if rope.visible:
		# İp eldeki saptan kancaya, hafifçe sarkan tek parça bir halat olarak çizilir.
		var a: Vector3 = p.camera.global_transform * Vector3(0.24, -0.3, -0.5)
		var b := global_position + Vector3(0, 0.05, 0)
		var dist := a.distance_to(b)
		var sag := minf(0.8, dist * (0.015 if state == H.FLYING else 0.045))
		var pts: Array = []
		for i in 17:
			var t := i / 16.0
			pts.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
		rope.global_transform = Transform3D.IDENTITY
		rope.mesh = ToolModels.tube(pts, 0.007, 6)
