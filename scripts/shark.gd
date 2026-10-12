extends Node3D
## Köpekbalığı: salın etrafında döner, ara ara kenardaki bir karoyu ısırır.
## Oyuncu suya girerse ona saldırır. Mızrakla 3 kez vurulunca bir süreliğine kaçar.

const Waves = preload("res://scripts/waves.gd")
const SharkMesh = preload("res://scripts/shark_mesh.gd")

enum S { CIRCLE, TO_RAFT, BITE_RAFT, CHASE, RETREAT, GONE, DISTRACT }

const SPEED_CIRCLE := 3.0
const SPEED_ATTACK := 5.0
const SPEED_CHASE := 6.2
## Bir karo ~15 saniyede kopar: oyuncunun fark edip müdahale edecek zamanı olur.
const BITE_DAMAGE_RAFT := 7.0
const BITE_DAMAGE_PLAYER := 25.0
const MAX_HP := 3

var main
var state := S.CIRCLE
var angle := 0.0
var target_cell := Vector2i.ZERO
var bite_timer := 0.0
var attack_cd := 30.0
var state_timer := 0.0
var hp := MAX_HP
var hurt_flash := 0.0
var body: MeshInstance3D
var mat: ShaderMaterial
var swim_t := 0.0
var swim_speed := 3.0
var wiggle := 0.0
var warned := false
## Oyalandığı yem
var bait = null
var bait_bite := 0.0


func _ready() -> void:
	body = MeshInstance3D.new()
	body.mesh = SharkMesh.build()
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/shark.gdshader")
	mat.set_shader_parameter("body_length", SharkMesh.L)
	body.material_override = mat
	add_child(body)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.02, 0.02, 0.02)
	eye_mat.roughness = 0.05
	eye_mat.metallic_specular = 1.0
	for p in SharkMesh.eye_positions():
		var e := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radial_segments = 20
		sm.rings = 10
		sm.radius = 0.028
		sm.height = 0.05
		e.mesh = sm
		e.material_override = eye_mat
		e.position = p
		add_child(e)
	global_position = Vector3(30, -1, 0)


func _raft_center() -> Vector3:
	return main.raft.to_global(main.raft.center_local())


func _move_to(target: Vector3, speed: float, delta: float, depth: float) -> float:
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	swim_speed = speed
	if dist > 0.05:
		var step := to / dist * minf(dist, speed * delta)
		var before := global_position
		# Köpekbalığı adanın sığ suyuna girmez, kıyı boyunca dolaşır.
		global_position = main.push_out_of_islands(global_position + step, 4.0)
		step = global_position - before
		var yaw := atan2(step.x, step.z)
		rotation.y = lerp_angle(rotation.y, yaw, minf(1.0, 3.0 * delta))
	var wh := Waves.height(global_position.x, global_position.z)
	global_position.y = lerpf(global_position.y, wh + depth, minf(1.0, 3.0 * delta))
	return dist


func try_hit(origin: Vector3, dir: Vector3, reach: float, dmg := 1) -> bool:
	if state == S.GONE:
		return false
	var to := global_position - origin
	var along := to.dot(dir)
	if along < 0.0 or along > reach + 1.6:
		return false
	if (to - dir * along).length() > 1.3:
		return false
	hp -= dmg
	hurt_flash = 0.35
	main.quests.event("hit_shark")
	main.audio.play_at("spear_hit", global_position, 2.0)
	if hp <= 0:
		main.quests.event("kill_shark")
		main.hud.toast("Köpekbalığı kaçtı! Bir süre rahatsın.")
		state = S.GONE
		state_timer = 90.0
		visible = false
	else:
		main.hud.toast("Köpekbalığına vurdun! (%d/%d)" % [MAX_HP - hp, MAX_HP])
		state = S.RETREAT
		state_timer = 5.0
	return true


func _process(delta: float) -> void:
	if main.paused:
		return
	wiggle += delta
	swim_t += delta * (1.6 + swim_speed * 0.9)
	mat.set_shader_parameter("swim_t", swim_t)
	mat.set_shader_parameter("swim_amp", 0.08 + swim_speed * 0.012)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	mat.set_shader_parameter("hurt", hurt_flash * 1.5)

	var ctr := _raft_center()
	var player = main.player
	var r: float = main.raft.radius() + 5.0

	match state:
		S.CIRCLE:
			angle += SPEED_CIRCLE / r * delta
			_move_to(ctr + Vector3(cos(angle), 0, sin(angle)) * r, SPEED_CIRCLE, delta, -0.42)
			attack_cd -= delta
			var deep_diver: bool = player.in_water and Waves.height(player.global_position.x, player.global_position.z) - player.global_position.y > 8.0
			if player.in_water and player.global_position.distance_to(global_position) < (75.0 if deep_diver else 30.0):
				state = S.CHASE
				main.hud.toast("Köpekbalığı sana doğru geliyor! Sala çık!")
			elif attack_cd <= 0.0 and main.near_lit_lighthouse(main.raft.center_global(), 200.0):
				attack_cd = 20.0
			elif attack_cd <= 0.0 and main.raft.has_kind("nazar") and randf() < 0.4:
				# Nazar boncuğu: saldırı bu sefer savuşur
				attack_cd = 18.0
			elif attack_cd <= 0.0:
				# Daha önce ısırdığı karo hâlâ duruyorsa ona döner; güçlendirilmiş karoları seçmez.
				var edges: Array = main.raft.edge_tiles().filter(func(e): return not main.raft.is_metal(e))
				if edges.is_empty():
					edges = main.raft.edge_tiles()
				if not edges.is_empty():
					if not (target_cell in edges):
						target_cell = edges.pick_random()
					state = S.TO_RAFT
		S.TO_RAFT:
			if not main.raft.has_tile(target_cell):
				_back_to_circle()
			else:
				var tile_pos: Vector3 = main.raft.to_global(main.raft.cell_pos(target_cell))
				var out := tile_pos - ctr
				out.y = 0.0
				out = out.normalized() if out.length() > 0.1 else Vector3.RIGHT
				if _move_to(tile_pos + out * 1.9, SPEED_ATTACK, delta, -0.5) < 0.4:
					state = S.BITE_RAFT
					bite_timer = 0.0
					if not warned:
						warned = true
						main.hud.toast("Köpekbalığı salı ısırıyor! Mızrakla vur ya da çekiçle onar.")
		S.BITE_RAFT:
			if not main.raft.has_tile(target_cell):
				_back_to_circle()
			else:
				var tile_pos: Vector3 = main.raft.to_global(main.raft.cell_pos(target_cell))
				var face := tile_pos - global_position
				rotation.y = lerp_angle(rotation.y, atan2(face.x, face.z), minf(1.0, 6.0 * delta))
				rotation.z = sin(wiggle * 12.0) * 0.2
				swim_speed = 6.0
				bite_timer -= delta
				var trap = main.raft.trap_near(target_cell)
				if trap != null and bite_timer <= 0.0:
					rotation.z = 0.0
					_hit_trap(trap)
				elif bite_timer <= 0.0:
					# Bir saldırı = bir ısırık. Aynı karo 3 ısırıkta kopar; metal karo dayanır.
					var bite_res: String = main.raft.bite(target_cell)
					if bite_res == "metal":
						main.audio.play_at("metal", global_position, 0.0)
						main.hud.toast("Güçlendirilmiş zemin ısırığa dayandı!")
					else:
						main.audio.play_at("shark_bite", global_position, -2.0)
					rotation.z = 0.0
					state = S.RETREAT
					state_timer = 3.0
				if player.in_water and player.global_position.distance_to(global_position) < 20.0:
					rotation.z = 0.0
					state = S.CHASE
		S.CHASE:
			if not player.in_water:
				_back_to_circle()
			else:
				var depth: float = clampf(player.global_position.y + 1.0 - Waves.height(global_position.x, global_position.z), -6.0, -0.4)
				var d := _move_to(player.global_position, SPEED_CHASE, delta, depth)
				if d < 1.8:
					main.audio.play_at("shark_bite", global_position, 2.0)
					player.damage(BITE_DAMAGE_PLAYER * float(main.diff()["shark_dmg"]), "Köpekbalığı ısırdı!")
					state = S.RETREAT
					state_timer = 3.5
		S.RETREAT:
			state_timer -= delta
			var away := global_position - ctr
			away.y = 0.0
			_move_to(global_position + away.normalized() * 5.0, SPEED_ATTACK, delta, -0.6)
			if state_timer <= 0.0:
				_back_to_circle()
		S.DISTRACT:
			if bait == null or not is_instance_valid(bait):
				bait = null
				_back_to_circle()
			else:
				var bp: Vector3 = bait.global_position
				angle += 2.2 * delta
				var depth: float = clampf(bp.y - Waves.height(global_position.x, global_position.z), -4.0, -0.5)
				var d := _move_to(bp + Vector3(cos(angle), 0, sin(angle)) * 1.4, SPEED_ATTACK, delta, depth)
				rotation.z = sin(wiggle * 10.0) * 0.15
				bait_bite -= delta
				if d < 2.0 and bait_bite <= 0.0:
					bait_bite = 2.5
					main.audio.play_at("shark_bite", global_position, -4.0)
		S.GONE:
			state_timer -= delta
			if state_timer <= 0.0:
				hp = MAX_HP
				visible = true
				global_position = ctr + Vector3(35, -1, 0)
				_back_to_circle()


## Yem suya düşünce köpekbalığı ona yönelir.
func distract(b) -> void:
	if state == S.GONE:
		return
	bait = b
	state = S.DISTRACT
	rotation.z = 0.0
	main.hud.toast("Köpekbalığı yemin peşine düştü!", 3.0)
	main.quests.event("bait")


## Isırmaya gelen köpekbalığı diken tuzağına çarpar: yaralanır, kaçar; tuzak körelir.
func _hit_trap(trap) -> void:
	hp -= 1
	hurt_flash = 0.4
	main.audio.play_at("spear_hit", global_position, 2.0)
	main.audio.play_at("shark_bite", global_position, -6.0)
	trap.stock -= 1
	main.quests.event("trap_hit")
	if trap.stock <= 0:
		main.raft.remove_building(trap.cell)
		main.hud.toast("Köpekbalığı dikenlere çarptı! Tuzak köreldi, yenisini kur.", 4.0)
	else:
		main.hud.toast("Köpekbalığı diken tuzağına çarptı! (%d/3)" % trap.stock, 3.0)
	if hp <= 0:
		main.quests.event("kill_shark")
		main.hud.toast("Köpekbalığı dikenlerden bıktı, kaçtı! Bir süre rahatsın.")
		state = S.GONE
		state_timer = 90.0
		visible = false
	else:
		state = S.RETREAT
		state_timer = 5.0


func _back_to_circle() -> void:
	rotation.z = 0.0
	state = S.CIRCLE
	attack_cd = randf_range(30.0, 55.0) * float(main.diff()["shark_cd"])
	var off := global_position - _raft_center()
	angle = atan2(off.z, off.x)


func to_data() -> Dictionary:
	return {"hp": hp, "gone": state == S.GONE, "timer": state_timer, "cd": attack_cd}


func from_data(d: Dictionary) -> void:
	hp = int(d.get("hp", MAX_HP))
	attack_cd = float(d.get("cd", 30.0))
	if d.get("gone", false):
		state = S.GONE
		state_timer = float(d.get("timer", 60.0))
		visible = false
