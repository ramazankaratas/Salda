extends RefCounted
## Yuvalı envanter. Her yuva: null ya da {"id", "n", "dur"}.
## Oyuncu envanterinde ilk 10 yuva alet çubuğudur.

const Items = preload("res://scripts/items.gd")

signal changed

var slots: Array = []
## Oyuncu envanterinde alet çubuğu yuva sayısı (sandıklarda 0).
## Alet çubuğuna yalnızca yiyecek, su, alet ve yapılar girer; malzemeler çantada durur.
var hotbar_size := 0


func allowed(i: int, id: String) -> bool:
	return i >= hotbar_size or Items.info(id).get("type", "") != "material"


func _init(size: int) -> void:
	slots.resize(size)


func count(id: String) -> int:
	var n := 0
	for s in slots:
		if s != null and s["id"] == id:
			n += s["n"]
	return n


func has_all(cost: Dictionary) -> bool:
	for k in cost:
		if count(k) < cost[k]:
			return false
	return true


## Ekleyebildiği kadarını ekler, sığmayan miktarı döndürür.
func add(id: String, n: int, dur := -1) -> int:
	var info := Items.info(id)
	var stack: int = info["stack"]
	if stack > 1:
		for i in slots.size():
			if n <= 0:
				break
			var s = slots[i]
			if s != null and s["id"] == id and s["n"] < stack and allowed(i, id):
				var take: int = mini(n, stack - s["n"])
				s["n"] += take
				n -= take
	var order: Array = range(slots.size())
	if hotbar_size > 0 and info.get("type", "") == "material":
		order = range(hotbar_size, slots.size())
	elif hotbar_size > 0 and info.get("type", "") == "seed":
		order = range(hotbar_size, slots.size()) + range(hotbar_size)
	for i in order:
		if n <= 0:
			break
		if slots[i] == null:
			var take: int = mini(n, stack)
			var d: int = dur if dur >= 0 else int(info.get("dur", 0))
			slots[i] = {"id": id, "n": take, "dur": d}
			n -= take
	changed.emit()
	return n


## Üretilen eşyayı alet çubuğuna koyar ve yuva numarasını döndürür (-1: yer yok).
## Tercih sırası: aynı eşyanın yığını, boş yuva, sonra seçili yuvadaki eşya çantaya kaydırılır.
func add_to_hotbar(id: String, n: int, selected: int) -> int:
	var info := Items.info(id)
	var stack: int = info["stack"]
	var rest := maxi(0, n - stack)
	n -= rest
	var slot := -1
	for i in hotbar_size:
		var s = slots[i]
		if s != null and s["id"] == id and s["n"] + n <= stack:
			slot = i
			break
	if slot < 0:
		for i in hotbar_size:
			if slots[i] == null:
				slot = i
				break
	if slot < 0:
		var bag := -1
		for i in range(hotbar_size, slots.size()):
			if slots[i] == null:
				bag = i
				break
		if bag < 0:
			return -1
		slots[bag] = slots[selected]
		slots[selected] = null
		slot = selected
	if slots[slot] == null:
		slots[slot] = {"id": id, "n": n, "dur": int(info.get("dur", 0))}
	else:
		slots[slot]["n"] += n
	if rest > 0:
		add(id, rest)
	changed.emit()
	return slot


func remove(id: String, n: int) -> bool:
	if count(id) < n:
		return false
	for i in range(slots.size() - 1, -1, -1):
		if n <= 0:
			break
		var s = slots[i]
		if s != null and s["id"] == id:
			var take: int = mini(n, s["n"])
			s["n"] -= take
			n -= take
			if s["n"] <= 0:
				slots[i] = null
	changed.emit()
	return true


func spend(cost: Dictionary) -> bool:
	if not has_all(cost):
		return false
	for k in cost:
		remove(k, cost[k])
	return true


func take_slot(i: int, n: int) -> void:
	var s = slots[i]
	if s == null:
		return
	s["n"] -= n
	if s["n"] <= 0:
		slots[i] = null
	changed.emit()


func swap(a: int, b: int) -> void:
	var t = slots[a]
	slots[a] = slots[b]
	slots[b] = t
	changed.emit()


## Aynı türse birleştirir, değilse yer değiştirir (iki ayrı envanter arasında da çalışır).
## Malzeme alet çubuğuna gidecekse taşımaz ve false döndürür.
static func move_between(src, a: int, dst, b: int) -> bool:
	var s = src.slots[a]
	var d = dst.slots[b]
	if s == null:
		return true
	if not dst.allowed(b, s["id"]) or (d != null and d["id"] != s["id"] and not src.allowed(a, d["id"])):
		return false
	if d != null and d["id"] == s["id"] and Items.info(s["id"])["stack"] > 1:
		var stack: int = Items.info(s["id"])["stack"]
		var take: int = mini(s["n"], stack - d["n"])
		d["n"] += take
		s["n"] -= take
		if s["n"] <= 0:
			src.slots[a] = null
	else:
		src.slots[a] = d
		dst.slots[b] = s
	src.changed.emit()
	if dst != src:
		dst.changed.emit()
	return true


func to_data() -> Array:
	return slots.duplicate(true)


func from_data(data: Array) -> void:
	for i in slots.size():
		slots[i] = data[i] if i < data.size() and data[i] != null else null
		if slots[i] != null:
			if slots[i]["id"] == "balik_agi":
				slots[i]["id"] = "toplayici"
			slots[i]["n"] = int(slots[i]["n"])
			slots[i]["dur"] = int(slots[i].get("dur", 0))
	# Eski kayıtlarda alet çubuğunda kalan malzemeler çantaya taşınır.
	for i in hotbar_size:
		var s = slots[i]
		if s != null and not allowed(i, s["id"]):
			slots[i] = null
			var left := add(s["id"], s["n"], s["dur"])
			if left > 0:
				s["n"] = left
				slots[i] = s
	changed.emit()
