extends Node3D
## Resifte küçük balık sürüsü: ortak bir yörüngede döner, her balık biraz sapar; oyuncu yaklaşınca dağılır.

const COUNT := 14

var color := Color(0.95, 0.75, 0.2)
var fish: Array = []
var offs: Array = []
var t := 0.0
var scatter := 0.0
var main


func _ready() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Yassı baklava gövde + kuyruk (+Z yönüne yüzer)
	var v := [Vector3(0, 0, 0.12), Vector3(0, 0.035, 0), Vector3(0.012, 0, 0), Vector3(0, -0.035, 0), Vector3(-0.012, 0, 0),
		Vector3(0, 0, -0.07), Vector3(0, 0.04, -0.12), Vector3(0, -0.04, -0.12)]
	for tri in [[0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 1], [5, 2, 1], [5, 3, 2], [5, 4, 3], [5, 1, 4], [5, 6, 7]]:
		for i in tri:
			st.add_vertex(v[i])
	st.generate_normals()
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.4
	m.roughness = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in COUNT:
		var f := MeshInstance3D.new()
		f.mesh = mesh
		f.material_override = m
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.scale = Vector3.ONE * randf_range(0.8, 1.4)
		add_child(f)
		fish.append(f)
		offs.append(Vector3(randf_range(-0.8, 0.8), randf_range(-0.4, 0.4), randf_range(-0.8, 0.8)))
	t = randf() * 10.0


func _process(delta: float) -> void:
	t += delta * 0.35
	if main != null and main.player != null:
		var d: float = main.player.global_position.distance_to(global_position)
		if d < 3.5:
			scatter = minf(1.0, scatter + delta * 3.0)
		else:
			scatter = maxf(0.0, scatter - delta * 0.5)
	for i in COUNT:
		var tt := t + i * 0.05
		var center := Vector3(cos(tt) * 3.0, sin(tt * 1.7) * 0.4, sin(tt) * 3.0)
		var o: Vector3 = offs[i] * (1.0 + scatter * 3.0)
		var wob := Vector3(sin(tt * 5.0 + i), cos(tt * 4.0 + i) * 0.5, cos(tt * 5.0 + i)) * 0.15
		var p := center + o + wob
		var f: MeshInstance3D = fish[i]
		var dir := p - f.position
		f.position = p
		if dir.length() > 0.0001:
			f.rotation.y = atan2(dir.x, dir.z)
