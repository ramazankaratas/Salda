extends Node
## Ses yöneticisi: ses veri yolları (Ambiyans / Efekt / Arayüz), tek seferlik 2B-3B sesler ve döngüler.
## Su altına inince Ambiyans ve Efekt yollarına alçak geçiren filtre uygulanır (boğuk ses).

const AUDIO := "res://assets/audio/"
const SOUNDS := {
	"step": ["player/step_1.ogg", "player/step_2.ogg", "player/step_3.ogg", "player/step_4.ogg", "player/step_5.ogg"],
	"splash": ["player/splash_1.ogg", "player/splash_2.ogg"],
	"hurt": ["player/hurt_1.ogg", "player/hurt_2.ogg", "player/hurt_3.ogg"],
	"eat": ["player/eat_1.ogg", "player/eat_2.ogg", "player/eat_3.ogg"],
	"drink": ["player/drink.wav"],
	"hook_throw": ["tools/hook_throw.ogg"],
	"reel": ["tools/reel_1.ogg", "tools/reel_2.ogg", "tools/reel_3.ogg"],
	"build": ["tools/build_1.ogg", "tools/build_2.ogg"],
	"tile_break": ["tools/tile_break.ogg"],
	"pickup": ["tools/pickup.ogg"],
	"spear_swing": ["tools/spear_swing.ogg"],
	"spear_hit": ["tools/spear_hit.ogg"],
	"fish_bite": ["tools/fish_bite.wav"],
	"cloth": ["tools/cloth.ogg"],
	"metal": ["tools/metal.ogg"],
	"chest_open": ["tools/chest_open.ogg"],
	"chest_close": ["tools/chest_close.ogg"],
	"craft": ["tools/craft.ogg"],
	"click": ["ui/click.ogg"],
	"ui_open": ["ui/open.ogg"],
	"ui_close": ["ui/close.ogg"],
	"shark_bite": ["world/shark_bite_1.ogg", "world/shark_bite_2.ogg", "world/shark_bite_3.ogg"],
	"seagull": ["ambient/seagull_1.wav", "ambient/seagull_2.wav"],
	"chop": ["tools/chop_1.ogg", "tools/chop_2.ogg", "tools/chop_3.ogg"],
	"tree_creak": ["world/tree_creak.ogg"],
	"tree_fall": ["world/tree_fall_1.ogg", "world/tree_fall_2.ogg"],
	"meow": ["cat/meow_1.ogg", "cat/meow_2.ogg", "cat/meow_3.ogg"],
	"cat_eat": ["cat/eat.ogg"],
	"mewpurr": ["cat/mewpurr.ogg"],
	"hiss": ["cat/hiss.ogg"],
	"mine": ["tools/mine_1.ogg", "tools/mine_2.ogg", "tools/mine_3.ogg"],
	"radio": ["ui/radio.ogg"],
	"bell": ["world/bell.ogg"],
	"sonar": ["world/sonar.ogg"],
	"thunder": ["world/thunder_1.ogg", "world/thunder_2.ogg"],
}
## Dosyalar -20 dB RMS'e eşitlendi; her sesin karışımdaki payı buradan ayarlanır (dB).
const MIX := {
	"step": -4.0, "click": -10.0, "ui_open": -10.0, "ui_close": -10.0, "build": -8.0, "craft": -6.0,
	"pickup": -6.0, "hurt": -6.0, "eat": -9.0, "drink": -8.0, "splash": -4.0, "spear_swing": -6.0,
	"spear_hit": -8.0, "hook_throw": -6.0, "reel": -4.0, "fish_bite": -12.0, "shark_bite": -6.0,
	"tile_break": -6.0, "metal": -9.0, "cloth": -6.0, "chest_open": -8.0, "chest_close": -8.0, "seagull": -8.0,
	"chop": -6.0, "mine": -6.0, "radio": -8.0, "bell": -6.0, "sonar": -8.0, "meow": -6.0, "cat_eat": -6.0, "mewpurr": -6.0, "hiss": -4.0, "tree_creak": -6.0, "tree_fall": -4.0,
}
## Aynı ses bu süreden (sn) sık çalınmaz; üst üste binen tekrarlar kulağı yormasın.
const MIN_GAP := 0.07
const MAX_VOICES := 3
const LOOPS := {
	"ocean_1": "ambient/ocean_1.ogg",
	"ocean_2": "ambient/ocean_2.ogg",
	"wind": "ambient/wind.ogg",
	"rain": "ambient/rain.ogg",
	"underwater": "ambient/underwater.ogg",
	"fire": "world/fire.ogg",
	"boil": "world/boil.ogg",
	"engine": "world/engine.ogg",
	"purr": "cat/purr.ogg",
}

var streams := {}
var loops := {}
var ambient_players := {}
var underwater := false
var lowpass: AudioEffectLowPassFilter
var last_played := {}
var voices := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Ambiyans", "Efekt", "Arayuz"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	# Ana çıkış: ani tepeleri yumuşatan kompresör ve patlamayı önleyen sınırlayıcı.
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var comp := AudioEffectCompressor.new()
		comp.threshold = -18.0
		comp.ratio = 3.0
		comp.attack_us = 8000.0
		comp.release_ms = 220.0
		AudioServer.add_bus_effect(master, comp)
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(master, lim)
	lowpass = AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = 900.0
	for bus in ["Ambiyans", "Efekt"]:
		var i := AudioServer.get_bus_index(bus)
		AudioServer.add_bus_effect(i, lowpass.duplicate())
		AudioServer.set_bus_effect_enabled(i, 0, false)
	for k in SOUNDS:
		var r := AudioStreamRandomizer.new()
		r.random_pitch = 1.05
		r.random_volume_offset_db = 1.5
		for p in SOUNDS[k]:
			r.add_stream(-1, load(AUDIO + p))
		streams[k] = r
	for k in LOOPS:
		var s = load(AUDIO + LOOPS[k])
		if s is AudioStreamOggVorbis:
			s.loop = true
		elif s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = s.get_length() * s.mix_rate
		loops[k] = s
	for k in ["ocean_1", "ocean_2", "wind", "rain", "underwater"]:
		var p := AudioStreamPlayer.new()
		p.stream = loops[k]
		p.bus = "Ambiyans"
		p.volume_db = -80.0
		add_child(p)
		p.play()
		ambient_players[k] = p


func set_bus_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))


## Ambiyans döngüsünün hedef ses düzeyi (doğrusal 0..1), yumuşak geçişle.
func ambient(name: String, level: float, delta: float) -> void:
	var p: AudioStreamPlayer = ambient_players[name]
	var target := linear_to_db(maxf(level, 0.0001))
	p.volume_db = lerpf(p.volume_db, target, minf(1.0, delta * 2.0))


func set_underwater(on: bool) -> void:
	if on == underwater:
		return
	underwater = on
	for bus in ["Ambiyans", "Efekt"]:
		AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(bus), 0, on)


## Çalınabilir mi: çok sık ya da çok sayıda üst üste aynı ses engellenir.
func _allow(name: String) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last_played.get(name, -10.0)) < MIN_GAP or int(voices.get(name, 0)) >= MAX_VOICES:
		return false
	last_played[name] = now
	voices[name] = int(voices.get(name, 0)) + 1
	return true


func _done(name: String, p: Node) -> void:
	voices[name] = maxi(0, int(voices.get(name, 1)) - 1)
	p.queue_free()


func play(name: String, volume_db := 0.0, bus := "Efekt") -> void:
	if not streams.has(name) or not _allow(name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = streams[name]
	p.volume_db = volume_db + float(MIX.get(name, 0.0))
	p.bus = bus
	add_child(p)
	p.play()
	p.finished.connect(_done.bind(name, p))


func play_at(name: String, pos: Vector3, volume_db := 0.0, unit := 6.0) -> void:
	if not streams.has(name) or not _allow(name):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[name]
	p.volume_db = volume_db + float(MIX.get(name, 0.0))
	p.attenuation_filter_cutoff_hz = 9000.0
	p.unit_size = unit
	p.bus = "Efekt"
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(_done.bind(name, p))


## Bir yapıya bağlı 3B döngü sesi (ızgara ateşi, arıtıcı kaynaması).
func loop_player(name: String, parent: Node3D, volume_db := -6.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = loops[name]
	p.volume_db = volume_db
	p.unit_size = 4.0
	p.bus = "Efekt"
	parent.add_child(p)
	return p
