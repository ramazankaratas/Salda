extends Node3D
## Açılış ekranındaki kazazede: Quaternius "Beach Character" (CC0) modeli.
## Bekler, arıtıcıyla uğraşır, ara sıra kameraya el sallar.

const MODEL := "res://assets/models/q_beach_character/beach_character.glb"
const HEIGHT := 1.78
## (animasyon, süre sn, bakış açısı): sırayla döner.
const PLAN := [
	["Idle", 5.0, 0.0],
	["Interact", 2.4, -1.35],
	["Idle", 3.5, -1.35],
	["Wave", 2.6, 0.0],
	["Idle_Neutral", 4.0, 0.6],
]

var anim: AnimationPlayer
var step := -1
var timer := 0.0
var face := 0.0
var model: Node3D


func _ready() -> void:
	model = (load(MODEL) as PackedScene).instantiate()
	add_child(model)
	var aabb := _bounds(model)
	if aabb.size.y > 0.01:
		model.scale = Vector3.ONE * (HEIGHT / aabb.size.y)
		model.position.y = -aabb.position.y * model.scale.y
	anim = model.find_child("AnimationPlayer", true, false)
	if anim != null:
		for n in anim.get_animation_list():
			var a := anim.get_animation(n)
			if n.ends_with("Idle") or n.ends_with("Idle_Neutral"):
				a.loop_mode = Animation.LOOP_LINEAR
	_next()


func _bounds(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "VisualInstance3D", true, false):
		var vi := c as VisualInstance3D
		var b := (n as Node3D).global_transform.affine_inverse() * vi.global_transform * vi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _play(name: String) -> void:
	if anim == null:
		return
	for n in anim.get_animation_list():
		if n.ends_with("|" + name) or n == name:
			anim.play(n, 0.35)
			return


func _next() -> void:
	step = (step + 1) % PLAN.size()
	var p: Array = PLAN[step]
	_play(p[0])
	timer = p[1]
	face = p[2]


func _process(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		_next()
	model.rotation.y = lerp_angle(model.rotation.y, face, minf(1.0, delta * 3.0))
