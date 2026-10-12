extends RefCounted
## Durağan süs ağlarını birleştirir: bir düğümün altındaki yüzlerce küçük MeshInstance3D, malzeme başına
## tek yüzeyli tek bir ağa döner (yüzlerce çizim çağrısı yerine birkaç tane).
## Betik taşıyan, çarpışan ya da "nomerge" işaretli düğümlerin altındakilere dokunulmaz (hareket edenler, toplananlar).


## consume=false: kaynak ağlara dokunulmaz (gizli kaynaktan tekrar tekrar birleştirmek için), sonuç `parent`a eklenir.
static func bake(root: Node3D, shadows := false, vis_end := 0.0, consume := true, parent: Node3D = null) -> MeshInstance3D:
	var groups := {}
	var arr_cache := {}
	var mats := {}
	var used: Array = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not _static(mi, root):
			continue
		var xf := _rel(mi, root)
		for s in mi.mesh.get_surface_count():
			# Hazır şekiller (küre, silindir...) de dizilere çevrilip eklenir
			var ak := "%d_%d" % [mi.mesh.get_instance_id(), s]
			if not arr_cache.has(ak):
				arr_cache[ak] = mi.mesh.surface_get_arrays(s)
			var arrays: Array = arr_cache[ak]
			if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
				continue
			var mat: Material = mi.material_override
			if mat == null:
				mat = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			var fmt := ""
			for k in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV]:
				fmt += "1" if arrays[k] != null else "0"
			var key := "%s_%s" % [_mat_key(mat), fmt]
			if not groups.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = st
				mats[key] = mat
			var tmp := ArrayMesh.new()
			tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			(groups[key] as SurfaceTool).append_from(tmp, 0, xf)
		used.append(mi)
	if used.is_empty():
		return null
	var out := ArrayMesh.new()
	for key in groups:
		var st: SurfaceTool = groups[key]
		out = st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, mats[key])
	var merged := MeshInstance3D.new()
	merged.name = "Birlesik"
	merged.mesh = out
	merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_end > 0.0:
		merged.visibility_range_end = vis_end
		merged.visibility_range_end_margin = 10.0
		merged.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if parent != null:
		parent.add_child(merged)
	else:
		root.add_child(merged)
	if not consume:
		return merged
	for mi in used:
		var p: Node = mi.get_parent()
		p.remove_child(mi)
		mi.free()
		# İçi boşalan ara düğümleri de temizle
		while p != root and p.get_child_count() == 0 and p.get_script() == null:
			var pp: Node = p.get_parent()
			pp.remove_child(p)
			p.free()
			p = pp
	return merged


## Aynı görünen malzemeler (renk, doku, pürüzlülük...) tek yüzeyde birleşir. Sonradan değiştirilen
## malzemeler ("unique" işaretli: kor, lamba camı...) kendi yüzeyinde kalır.
static func _mat_key(mat: Material) -> String:
	if mat == null:
		return "0"
	if not (mat is StandardMaterial3D) or mat.has_meta("unique"):
		return str(mat.get_instance_id())
	var m := mat as StandardMaterial3D
	return "s%s|%s|%s|%s|%s|%s|%s|%s|%s|%d|%d|%s|%s" % [m.albedo_color, m.roughness, m.metallic,
		m.albedo_texture.get_instance_id() if m.albedo_texture else 0, m.normal_texture.get_instance_id() if m.normal_texture else 0,
		m.emission_enabled, m.emission, m.emission_energy_multiplier, m.uv1_scale, m.transparency, m.cull_mode,
		m.roughness_texture.get_instance_id() if m.roughness_texture else 0, m.shading_mode]


static func _static(n: Node, root: Node) -> bool:
	var cur: Node = n
	while cur != null and cur != root:
		if cur.has_meta("nomerge") or cur is CollisionObject3D:
			return false
		if cur.get_script() != null:
			return false
		cur = cur.get_parent()
	return cur == root


static func _rel(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != root:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf
