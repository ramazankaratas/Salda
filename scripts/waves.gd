extends RefCounted
## Okyanus dalgaları. Shader (ocean.gdshader) ile birebir aynı formülü kullanır,
## böylece sal, enkaz, kanca ve köpekbalığı görünen su yüzeyine tam oturur.

## [yön, genlik (m), dalga boyu (m)]
const WAVES := [
	[Vector2(1.0, 0.25), 0.30, 18.0],
	[Vector2(0.6, -0.8), 0.16, 9.0],
	[Vector2(-0.3, 1.0), 0.09, 5.5],
	[Vector2(0.9, 0.5), 0.04, 3.1],
]

static var time := 0.0
## Dalga yüksekliği çarpanı (fırtınada büyür). Shader'daki wave_scale ile aynı değer.
static var amp := 1.0
## Salın çevresinde sakin su: sal yarıçapı içinde dalgalar küçülür (su güverteye çıkmasın).
## Shader'daki raft_pos / calm_radius ile aynı değerler.
static var calm_pos := Vector2(1.0e9, 1.0e9)
static var calm_r := 0.0
const CALM_MIN := 0.22
const CALM_FADE := 7.0


static func calm(x: float, z: float) -> float:
	if calm_r <= 0.0:
		return 1.0
	var d := Vector2(x, z).distance_to(calm_pos)
	return lerpf(CALM_MIN, 1.0, smoothstep(calm_r, calm_r + CALM_FADE, d))


static func height(x: float, z: float) -> float:
	var h := 0.0
	for w in WAVES:
		var d: Vector2 = (w[0] as Vector2).normalized()
		var k: float = TAU / float(w[2])
		var c: float = sqrt(9.8 / k)
		h += float(w[1]) * sin(k * (d.x * x + d.y * z) - c * k * time)
	return h * amp * calm(x, z)


static func normal(x: float, z: float) -> Vector3:
	var g := Vector2.ZERO
	for w in WAVES:
		var d: Vector2 = (w[0] as Vector2).normalized()
		var k: float = TAU / float(w[2])
		var c: float = sqrt(9.8 / k)
		g += float(w[1]) * k * d * cos(k * (d.x * x + d.y * z) - c * k * time)
	g *= amp * calm(x, z)
	return Vector3(-g.x, 1.0, -g.y).normalized()


## Shader'a gönderilecek dalga parametreleri: (yön.x, yön.y, genlik, dalga boyu).
static func shader_params() -> Array:
	var out: Array = []
	for w in WAVES:
		var d: Vector2 = w[0]
		out.append(Vector4(d.x, d.y, w[1], w[2]))
	return out
