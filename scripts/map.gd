extends Control
## Harita: kuzey yukarıda. Sal karoları, oyuncu (yön oku), adalar ve yakındaki enkaz.
## Menzil dışındaki adalar kenarda ok ve mesafeyle gösterilir. Altta konum ve en yakın ada.

const RaftMarker = preload("res://scripts/raft_marker.gd")

var main
var range_m := 90.0
var show_debris := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _to_map(w: Vector3, p: Vector3, c: Vector2, r: float) -> Vector2:
	return c + Vector2(w.x - p.x, w.z - p.z) / range_m * r


func _draw() -> void:
	if main == null or main.player == null:
		return
	var font := get_theme_default_font()
	var r: float = minf(size.x, size.y) * 0.5 - 4.0
	var c := Vector2(size.x * 0.5, r + 4.0)
	var p: Vector3 = main.player.global_position

	draw_circle(c, r, Color(0.02, 0.1, 0.17, 0.78))
	for k in [0.33, 0.66]:
		draw_arc(c, r * k, 0, TAU, 48, Color(1, 1, 1, 0.07), 1.0)
	draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(1, 1, 1, 0.05))
	draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(1, 1, 1, 0.05))

	# Enkaz
	if show_debris:
		for d in main.debris:
			var dp := _to_map(d.global_position, p, c, r)
			if dp.distance_to(c) < r - 2.0:
				var col := Color(1.0, 0.75, 0.3, 0.9) if d.kind == "varil" else Color(0.85, 0.85, 0.75, 0.7)
				draw_circle(dp, 1.8 if d.kind != "varil" else 2.6, col)

	# Adalar
	var nearest = null
	var nd := INF
	for isl in main.islands:
		var ip := _to_map(isl.global_position, p, c, r)
		var dist: float = Vector2(isl.global_position.x - p.x, isl.global_position.z - p.z).length()
		if dist < nd:
			nd = dist
			nearest = isl
		var rad: float = maxf(4.0, isl.shore_radius / range_m * r)
		if ip.distance_to(c) < r - rad:
			draw_circle(ip, rad + rad * 0.6, Color(0.2, 0.55, 0.6, 0.45))
			draw_circle(ip, rad, Color(0.85, 0.78, 0.5))
			draw_circle(ip, rad * 0.45, Color(0.3, 0.6, 0.25))
		else:
			var dir := (ip - c).normalized()
			var edge := c + dir * (r - 9.0)
			draw_circle(edge, 6.0, Color(0.85, 0.78, 0.5))
			draw_string(font, edge + Vector2(-16, 20), "%dm" % int(dist), HORIZONTAL_ALIGNMENT_CENTER, 32, 11, Color(1, 1, 1, 0.9))

	# Fenerler (yanan: sarı, sönmüş: gri) ve telsiz hedefi
	for lm in main.landmarks:
		var lw := Vector3(float(lm["x"]), 0, float(lm["z"]))
		var lp := _to_map(lw, p, c, r)
		var lit: bool = int(lm["stage"]) >= 4
		var lc := Color(1.0, 0.85, 0.35) if lit else Color(0.7, 0.72, 0.75)
		if lp.distance_to(c) < r - 6.0:
			draw_rect(Rect2(lp - Vector2(3, 7), Vector2(6, 14)), lc)
			draw_rect(Rect2(lp - Vector2(5, 9), Vector2(10, 4)), lc.darkened(0.3))
			if lit:
				draw_arc(lp, 10.0, 0, TAU, 20, Color(1, 0.85, 0.35, 0.5), 1.5)
	# Sonarla bulunan batıklar (mor halka + çapraz; ganimeti bitenler soluk)
	for st in main.wreck_sites:
		if not st.get("found", false):
			continue
		var sp := _to_map(Vector3(float(st["x"]), 0, float(st["z"])), p, c, r)
		if sp.distance_to(c) > r - 6.0:
			continue
		var done: bool = (st.get("looted", []) as Array).size() >= int(st.get("spots", 5))
		var sc := Color(0.7, 0.5, 1.0, 0.45 if done else 0.95)
		draw_arc(sp, 6.0, 0, TAU, 16, sc, 2.0)
		draw_line(sp + Vector2(-4, -4), sp + Vector2(4, 4), sc, 1.5)
		draw_line(sp + Vector2(-4, 4), sp + Vector2(4, -4), sc, 1.5)
	# Gezgin tüccar teknesi: mavi beyaz tekne işareti (menzil dışındaysa kenarda)
	if main.trader != null and is_instance_valid(main.trader):
		var bp := _to_map(main.trader.global_position, p, c, r)
		if bp.distance_to(c) > r - 10.0:
			bp = c + (bp - c).normalized() * (r - 10.0)
		draw_colored_polygon(PackedVector2Array([bp + Vector2(-8, -1), bp + Vector2(8, -1), bp + Vector2(5, 4), bp + Vector2(-5, 4)]), Color(0.95, 0.95, 0.92))
		draw_line(bp + Vector2(-7, 0), bp + Vector2(7, 0), Color(0.2, 0.45, 0.85), 2.0)
		draw_colored_polygon(PackedVector2Array([bp + Vector2(0, -11), bp + Vector2(0, -2), bp + Vector2(-6, -2)]), Color(0.95, 0.9, 0.78))
	if main.nav_target != null:
		var tw: Vector3 = main.nav_target
		var tp := _to_map(tw, p, c, r)
		var tdist := Vector2(tw.x - p.x, tw.z - p.z).length()
		if tp.distance_to(c) > r - 10.0:
			tp = c + (tp - c).normalized() * (r - 10.0)
		draw_colored_polygon(PackedVector2Array([tp + Vector2(0, -7), tp + Vector2(7, 0), tp + Vector2(0, 7), tp + Vector2(-7, 0)]), Color(0.5, 1.0, 0.7))
		draw_string(font, tp + Vector2(-22, -10), "%dm" % int(tdist), HORIZONTAL_ALIGNMENT_CENTER, 44, 11, Color(0.5, 1.0, 0.7))

	# Sal karoları; sal menzil dışındaysa kenarda işaret ve mesafe
	var raft = main.raft
	var cell_px: float = maxf(2.0, raft.CELL / range_m * r)
	for t in raft.tiles:
		var tp := _to_map(raft.to_global(raft.cell_pos(t)), p, c, r)
		if tp.distance_to(c) < r:
			draw_rect(Rect2(tp - Vector2(cell_px, cell_px) * 0.5, Vector2(cell_px, cell_px)), Color(0.7, 0.5, 0.3))
	var rc: Vector3 = raft.center_global()
	var rdist := Vector2(rc.x - p.x, rc.z - p.z).length()
	var rp := _to_map(rc, p, c, r)
	var away: bool = RaftMarker.away_from_raft(main)
	if rp.distance_to(c) >= r - 8.0:
		var dir := (rp - c).normalized()
		var edge := c + dir * (r - 10.0)
		draw_rect(Rect2(edge - Vector2(6, 6), Vector2(12, 12)), Color(0.75, 0.52, 0.3))
		draw_rect(Rect2(edge - Vector2(6, 6), Vector2(12, 12)), Color(1, 0.86, 0.45), false, 2.0)
		draw_string(font, edge + Vector2(-20, -10), "%dm" % int(rdist), HORIZONTAL_ALIGNMENT_CENTER, 40, 11, Color(1, 0.86, 0.45))
	elif away:
		# Yakında ama saldan ayrıyken salın çevresinde sarı halka
		draw_arc(rp, maxf(6.0, raft.radius() / range_m * r + 3.0), 0, TAU, 24, Color(1, 0.86, 0.45, 0.9), 1.5)

	# Oyuncu oku
	var yaw: float = main.player.rotation.y
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var side := Vector2(-fwd.y, fwd.x)
	var tip := c + fwd * 9.0
	draw_colored_polygon(PackedVector2Array([tip, c - fwd * 5.0 + side * 5.5, c - fwd * 2.0, c - fwd * 5.0 - side * 5.5]), Color(1, 0.95, 0.4))

	draw_arc(c, r, 0, TAU, 64, Color(1, 1, 1, 0.35), 2.0)
	# Rüzgâr oku: kenarda, rüzgârın estiği yerden haritanın içine doğru
	var wv: Vector3 = main.world.wind_vector()
	if wv.length() > 0.05:
		var wd := Vector2(wv.x, wv.z).normalized()
		var tail := c - wd * (r - 6.0)
		var head: Vector2 = tail + wd * (14.0 + 14.0 * main.world.wind_strength)
		draw_line(tail, head, Color(0.6, 0.85, 1.0, 0.9), 2.5)
		var sd := Vector2(-wd.y, wd.x)
		draw_colored_polygon(PackedVector2Array([head + wd * 6.0, head + sd * 4.5, head - sd * 4.5]), Color(0.6, 0.85, 1.0, 0.9))
	draw_string(font, c + Vector2(-6, -r + 16), "K", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.5, 0.4))

	var info := "X %d  ·  Z %d" % [int(p.x), int(p.z)]
	if away:
		var rdv: Vector3 = rc - p
		info += "
Sal: %d m · %s" % [int(rdist), _heading_name(int(fposmod(rad_to_deg(atan2(rdv.x, -rdv.z)), 360.0)))]
	if nearest != null:
		var dv: Vector3 = nearest.global_position - p
		var deg := int(fposmod(rad_to_deg(atan2(dv.x, -dv.z)), 360.0))
		info += "\nAda: %d m · %s" % [int(nd), _heading_name(deg)]
	draw_multiline_string(font, Vector2(0, c.y + r + 18), info, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, -1, Color(1, 1, 1, 0.85))


func _heading_name(deg: int) -> String:
	var names := ["Kuzey", "Kuzeydoğu", "Doğu", "Güneydoğu", "Güney", "Güneybatı", "Batı", "Kuzeybatı"]
	return names[int(round(deg / 45.0)) % 8]
