extends Control
## Ekranda sal işareti: oyuncu saldan ayrıyken (denizde ya da adada) salın üstünde mesafeyle görünür.
## Sal ekran dışında ya da arkadaysa, ekran kenarında sala dönük bir ok gösterilir.

var main


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


## Oyuncu saldan uzakta mı (suda ya da salın dışında)?
static func away_from_raft(main) -> bool:
	var p = main.player
	var rc: Vector3 = main.raft.center_global()
	var d := Vector2(p.global_position.x - rc.x, p.global_position.z - rc.z).length()
	return p.in_water or d > main.raft.radius() + 1.0


func _draw() -> void:
	if main == null or main.player == null or main.paused or main.hud.menu_open:
		return
	var cam: Camera3D = main.player.camera
	# Telsiz hedefi (yeşil)
	if main.nav_target != null:
		var nt: Vector3 = main.nav_target + Vector3(0, 12.0, 0)
		_marker(cam, nt, "%s  %d m" % [main.nav_name.to_upper(), int(Vector2(nt.x - cam.global_position.x, nt.z - cam.global_position.z).length())], Color(0.55, 1.0, 0.7))
	if not away_from_raft(main):
		return
	var target: Vector3 = main.raft.center_global() + Vector3(0, 2.2, 0)
	_marker(cam, target, "SAL  %d m" % int(cam.global_position.distance_to(target)), Color(1.0, 0.86, 0.45))


## Hedef ekrandaysa üstünde aşağı ok ve yazı; değilse ekran kenarında hedefe dönük ok.
func _marker(cam: Camera3D, target: Vector3, label: String, col: Color) -> void:
	var font := get_theme_default_font()
	# Ekran boyutu doğrudan görünüm alanından (kontrolün kendi boyutu ilk karelerde 0 olabilir).
	var vp := get_viewport_rect().size
	var margin := 48.0
	var shadow := Color(0, 0, 0, 0.6)
	var behind := cam.is_position_behind(target)
	var sp := cam.unproject_position(target)
	var inside := not behind and sp.x > margin and sp.x < vp.x - margin and sp.y > margin and sp.y < vp.y - margin
	if inside:
		# Salın üstünde aşağı bakan işaret ve mesafe
		var pts := PackedVector2Array([sp + Vector2(-9, -14), sp + Vector2(9, -14), sp])
		draw_colored_polygon(PackedVector2Array([pts[0] + Vector2(1, 2), pts[1] + Vector2(1, 2), pts[2] + Vector2(1, 2)]), shadow)
		draw_colored_polygon(pts, col)
		draw_string(font, sp + Vector2(-60, -22) + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, shadow)
		draw_string(font, sp + Vector2(-60, -22), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, col)
		return
	# Ekran dışında: merkezden sala doğru yön, kenara sabitlenmiş ok
	var center := vp * 0.5
	var dir: Vector2
	if behind:
		dir = (center - sp).normalized()
		if dir.length() < 0.1:
			dir = Vector2.DOWN
	else:
		dir = (sp - center).normalized()
	var half := center - Vector2(margin, margin)
	var k := minf(absf(half.x / maxf(absf(dir.x), 0.001)), absf(half.y / maxf(absf(dir.y), 0.001)))
	var pos := center + dir * k
	var side := Vector2(-dir.y, dir.x)
	var tip := pos + dir * 16.0
	var arrow := PackedVector2Array([tip, pos - dir * 6.0 + side * 11.0, pos - dir * 1.0, pos - dir * 6.0 - side * 11.0])
	var sh := PackedVector2Array()
	for a in arrow:
		sh.append(a + Vector2(1, 2))
	draw_colored_polygon(sh, shadow)
	draw_colored_polygon(arrow, col)
	var tp := pos - dir * 30.0 + Vector2(-60, 6)
	draw_string(font, tp + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, shadow)
	draw_string(font, tp, label, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, col)
