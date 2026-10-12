extends RefCounted
## Model yerleştirme: modeli verilen noktaya ortalar (taban ya da merkez), ölçekler ve döndürür.

static var _cache := {}
static var _aabb := {}


static func scene(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


static func _merge(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var bb: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		if acc.is_empty():
			acc.append(bb)
		else:
			acc[0] = (acc[0] as AABB).merge(bb)
	for c in n.get_children():
		_merge(c, t, acc)


static func aabb_of(path: String, inst: Node) -> AABB:
	if not _aabb.has(path):
		var acc: Array = []
		_merge(inst, Transform3D.IDENTITY, acc)
		_aabb[path] = acc[0] if not acc.is_empty() else AABB()
	return _aabb[path]


## anchor: "bottom" taban pos'a oturur, "center" merkez pos'a gelir.
static func place(parent: Node, path: String, pos: Vector3, rot := Vector3.ZERO, scale := 1.0, anchor := "bottom") -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation = rot
	holder.scale = Vector3.ONE * scale
	parent.add_child(holder)
	var inst := scene(path).instantiate()
	holder.add_child(inst)
	var bb := aabb_of(path, inst)
	var c := bb.get_center()
	inst.position = -Vector3(c.x, bb.position.y if anchor == "bottom" else c.y, c.z)
	return holder


## Modelin tüm malzemelerini kopyalayıp rengini çarpar (ör. pişmiş balık için kahverengi ton).
static func tint(node: Node, color: Color) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m is StandardMaterial3D:
				var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.albedo_color = d.albedo_color * color
				mi.set_surface_override_material(i, d)
	for c in node.get_children():
		tint(c, color)
