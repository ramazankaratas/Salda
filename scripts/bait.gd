extends Node3D
## Köpekbalığı yemi: ipe bağlı balık parçaları. Fırlatılır, suya düşünce yavaşça batar;
## köpekbalığı bir süre yemle oyalanır, salı ve oyuncuyu unutur. Yem bitince eriyip gider.

const Waves = preload("res://scripts/waves.gd")
const ToolModels = preload("res://scripts/tool_models.gd")

const LAST := 28.0

var main
var vel := Vector3.ZERO
var in_water := false
var life := LAST
var eaten := 0.0


func _ready() -> void:
	var m := ToolModels.fish(false)
	m.scale = Vector3.ONE * 0.7
	add_child(m)
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color(0.75, 0.65, 0.45)
	ToolModels._mi(self, ToolModels.tube([Vector3(0, 0.05, 0), Vector3(0, 0.4, 0)], 0.008, 4), rope)


func _process(delta: float) -> void:
	if main.paused:
		return
	var wh := Waves.height(global_position.x, global_position.z)
	if not in_water:
		vel.y -= 14.0 * delta
		global_position += vel * delta
		rotation.x += delta * 6.0
		if global_position.y < wh:
			in_water = true
			main.audio.play_at("splash", global_position, -4.0)
			main.shark.distract(self)
	else:
		global_position.y = lerpf(global_position.y, wh - 1.2, minf(1.0, delta * 0.8))
		rotation.x = lerp_angle(rotation.x, 0.0, minf(1.0, delta * 2.0))
		life -= delta
		if life <= 0.0:
			queue_free()
