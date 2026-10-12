extends RefCounted
## Koddan üretilen pürüzsüz köpekbalığı modeli (burun +Z yönünde, boy 3.2 m).
## Gövde: kesitler boyunca örülen yumuşak yüzey. Yüzgeçler: kalınlığı olan kavisli plakalar.
## Renk: sırt koyu gri-mavi, karın beyaz (köpekbalığı karşı gölgelemesi), solungaç ve ağız çizgileri.

const L := 3.2
const STATIONS := 64
const RING := 32
const TOP := Color(0.27, 0.31, 0.36)
const BELLY := Color(0.9, 0.9, 0.88)
const DARK := Color(0.08, 0.08, 0.09)


## t: 0 = kuyruk sapı, 1 = burun ucu
static func radius(t: float) -> float:
	var body := pow(sin(PI * pow(t, 0.78)), 0.72)
	return 0.05 + 0.31 * body * (1.0 - 0.75 * pow(t, 6.0))


static func _center_y(t: float) -> float:
	return 0.04 * sin(PI * t) + 0.05 * smoothstep(0.85, 1.0, t)


static func _z(t: float) -> float:
	return lerpf(-L * 0.5, L * 0.5, t)


static func surface_point(t: float, a: float) -> Vector3:
	var r := radius(t)
	var hx := r * 0.9
	var hy := r * 1.15
	var y := cos(a)
	return Vector3(sin(a) * hx, y * hy * (0.82 if y < 0.0 else 1.0) + _center_y(t), _z(t))


static func _color(t: float, a: float) -> Color:
	var y := cos(a)
	var side := absf(sin(a))
	var line := -0.22 + 0.07 * sin(t * 37.0) + 0.04 * sin(t * 91.0)
	var c := BELLY.lerp(TOP, smoothstep(line - 0.08, line + 0.08, y))
	# Solungaç yarıkları: başın arkasında, yanlarda 5 koyu şerit
	if t > 0.7 and t < 0.8 and side > 0.55 and y > -0.35 and y < 0.55:
		var k := fmod((t - 0.7) / 0.02, 1.0)
		if k > 0.62:
			c = c.lerp(DARK, 0.75)
	# Ağız çizgisi: burnun altında kavisli koyu çizgi
	var mouth_t := 0.9 - 0.035 * side
	if absf(t - mouth_t) < 0.008 and y < -0.35:
		c = c.lerp(DARK, 0.85)
	# Burun ucu biraz koyu
	c = c.lerp(TOP * 0.85, smoothstep(0.96, 1.0, t) * 0.5)
	return c


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


## Kalınlığı olan yüzgeç: outline (u, v) noktaları, origin, u ve v yönleri.
static func _fin(st: SurfaceTool, outline: Array, origin: Vector3, u: Vector3, v: Vector3, th: float, col: Color) -> void:
	var n := u.cross(v).normalized()
	var center := Vector2.ZERO
	for p in outline:
		center += p
	center /= outline.size()
	var maxv := 0.001
	for p in outline:
		maxv = maxf(maxv, absf(p.y))
	var cnt := outline.size()
	var cpt := origin + u * center.x + v * center.y
	for i in cnt:
		var p0: Vector2 = outline[i]
		var p1: Vector2 = outline[(i + 1) % cnt]
		var a := origin + u * p0.x + v * p0.y
		var b := origin + u * p1.x + v * p1.y
		var ca := col.darkened(0.35 * absf(p0.y) / maxv)
		var cb := col.darkened(0.35 * absf(p1.y) / maxv)
		var cc := col
		# Ön yüz ve arka yüz (ters sarım) + kenar şeridi
		_tri(st, cpt + n * th, a + n * th * 0.3, b + n * th * 0.3, cc, ca, cb)
		_tri(st, cpt - n * th, b - n * th * 0.3, a - n * th * 0.3, cc, cb, ca)
		_tri(st, a + n * th * 0.3, a - n * th * 0.3, b + n * th * 0.3, ca, ca, cb)
		_tri(st, b + n * th * 0.3, a - n * th * 0.3, b - n * th * 0.3, cb, ca, cb)


static func build() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var cols: Array = []
	for i in STATIONS + 1:
		var t := float(i) / STATIONS
		var ring: Array = []
		var cring: Array = []
		for j in RING:
			var a := TAU * j / RING
			ring.append(surface_point(t, a))
			cring.append(_color(t, a))
		rings.append(ring)
		cols.append(cring)
	for i in STATIONS:
		for j in RING:
			var j2 := (j + 1) % RING
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][j2]
			var c: Vector3 = rings[i + 1][j2]
			var d: Vector3 = rings[i + 1][j]
			_tri(st, a, b, d, cols[i][j], cols[i][j2], cols[i + 1][j])
			_tri(st, b, c, d, cols[i][j2], cols[i + 1][j2], cols[i + 1][j])
	# Uçları kapat: kuyruk sapı ve burun
	var tail := Vector3(0, _center_y(0.0), _z(0.0) - 0.04)
	var nose := Vector3(0, _center_y(1.0) + 0.01, _z(1.0) + 0.05)
	for j in RING:
		var j2 := (j + 1) % RING
		_tri(st, tail, rings[0][j2], rings[0][j], TOP, cols[0][j2], cols[0][j])
		_tri(st, nose, rings[STATIONS][j], rings[STATIONS][j2], TOP, cols[STATIONS][j], cols[STATIONS][j2])

	var fin_col := TOP.darkened(0.05)
	# Sırt yüzgeci
	var top_t := 0.56
	var top_p := surface_point(top_t, 0.0) - Vector3(0, 0.03, 0)
	_fin(st, [Vector2(0.24, 0.0), Vector2(0.16, 0.2), Vector2(0.04, 0.36), Vector2(-0.12, 0.47), Vector2(-0.1, 0.32), Vector2(-0.1, 0.14), Vector2(-0.16, 0.0)],
		top_p, Vector3(0, 0, 1), Vector3(0, 1, 0), 0.018, fin_col)
	# Yan (göğüs) yüzgeçleri
	for s in [-1.0, 1.0]:
		var p := surface_point(0.66, s * PI * 0.62)
		var out := Vector3(s * 0.88, -0.45, 0).normalized()
		_fin(st, [Vector2(0.14, 0.0), Vector2(0.04, 0.26), Vector2(-0.16, 0.52), Vector2(-0.2, 0.42), Vector2(-0.14, 0.18), Vector2(-0.12, 0.0)],
			p - out * 0.02, Vector3(0, 0, 1), out, 0.014, fin_col)
	# Kuyruk yüzgeci (hilal): üst lob büyük, alt lob küçük
	var tail_p := Vector3(0, _center_y(0.0), _z(0.0) + 0.02)
	_fin(st, [Vector2(0.06, 0.04), Vector2(-0.14, 0.26), Vector2(-0.46, 0.66), Vector2(-0.36, 0.34), Vector2(-0.26, 0.04),
		Vector2(-0.36, -0.36), Vector2(-0.16, -0.16), Vector2(0.06, -0.04)],
		tail_p, Vector3(0, 0, 1), Vector3(0, 1, 0), 0.016, fin_col)
	# İkinci sırt ve anal yüzgeçleri (küçük)
	_fin(st, [Vector2(0.05, 0.0), Vector2(-0.03, 0.09), Vector2(-0.07, 0.0)], surface_point(0.2, 0.0) - Vector3(0, 0.01, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), 0.01, fin_col)
	_fin(st, [Vector2(0.05, 0.0), Vector2(-0.03, -0.08), Vector2(-0.07, 0.0)], surface_point(0.18, PI) + Vector3(0, 0.01, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), 0.01, fin_col)

	st.index()
	st.generate_normals()
	return st.commit()


## Göz konumları (sol, sağ).
static func eye_positions() -> Array:
	return [surface_point(0.885, -PI * 0.36) * Vector3(0.97, 1, 1), surface_point(0.885, PI * 0.36) * Vector3(0.97, 1, 1)]
