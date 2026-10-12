extends Node
## Görevler ve başarımlar. Oyundaki olaylar `event(ad, kimlik, miktar)` ile bildirilir;
## etkin görevin adımları ve başarımlar buna göre ilerler. Görev zinciri sırayla açılır.
##
## Olaylar: pickup (eşya alındı), craft (üretildi), build (kuruldu: zemin, duvar, cati, yatak...),
## chop (palmiye), hit_shark, kill_shark, visit_island, sleep, travel (metre), day (gün sayısı).

const Items = preload("res://scripts/items.gd")

signal changed

## Görev zinciri. Her adım: [olay, kimlik ("" = hepsi), miktar, açıklama]
const QUESTS := [
	# Kolay: ilk dakikalar
	{"id": "ilk_enkaz", "title": "İlk Enkaz", "chapter": "Ege'de İlk Günler",
		"desc": "Dalgalar enkaz taşıyor. Kancayı fırlat (sol tık basılı tut, bırak) ve yüzen tahta ile plastiği topla.",
		"steps": [["pickup", "tahta", 5, "Tahta topla"], ["pickup", "plastik", 3, "Plastik topla"]],
		"reward": {"tahta": 2}},
	{"id": "el_emegi", "title": "El Emeği", "chapter": "Ege'de İlk Günler",
		"desc": "Palmiye yaprağından ip örülür. Yaprak topla, Tab ile üretim ekranını açıp ip ör.",
		"steps": [["pickup", "yaprak", 4, "Palmiye yaprağı topla"], ["craft", "ip", 2, "İp ör"]],
		"reward": {"yaprak": 4}},
	{"id": "sal_buyut", "title": "Salı Büyüt", "chapter": "Ege'de İlk Günler",
		"desc": "Dört kalaslık sal dar. Çekiçle salın kenarındaki suya bakıp iki zemin ekle (her biri 1 tahta + 1 plastik).",
		"steps": [["build", "zemin", 2, "Zemin ekle"]],
		"reward": {"plastik": 3}},
	{"id": "tatli_su", "title": "Tatlı Su", "chapter": "Ege'de İlk Günler",
		"desc": "Tuzlu su içilmez. Bir su arıtıcı kur, tahta yak ve ilk temiz suyunu al.",
		"steps": [["craft", "aritici", 1, "Su arıtıcı üret"], ["pickup", "temiz_su", 1, "Temiz su al"]],
		"reward": {"tahta": 4}},
	# Orta: hurda, balık, barınak
	{"id": "varillerin_ici", "title": "Varillerin İçi", "chapter": "Ege'de İlk Günler",
		"desc": "Yüzen variller hurda metal ve erzak saklar. Varilleri kancayla çek, içlerini aç.",
		"steps": [["pickup", "hurda", 3, "Hurda metal topla"]],
		"reward": {"ip": 2}},
	{"id": "ilk_balik", "title": "Ege'nin Balığı", "chapter": "Ege'de İlk Günler",
		"desc": "Bir olta yap. Şamandıra batınca kancayı tak, misinayı koparmadan balığı sar.",
		"steps": [["craft", "olta", 1, "Olta üret"], ["pickup", "ham_balik", 2, "Balık tut"]],
		"reward": {"hurda": 2}},
	{"id": "ates_izgara", "title": "Ateş ve Izgara", "chapter": "Ege'de İlk Günler",
		"desc": "Çiğ balık mideyi bozar. Bir ızgara kur ve balığını pişir.",
		"steps": [["craft", "izgara", 1, "Izgara üret"], ["pickup", "pismis_balik", 2, "Balık pişir"]],
		"reward": {"yaprak": 6}},
	{"id": "lodos_gelmeden", "title": "Lodos Gelmeden", "chapter": "Ege'de İlk Günler",
		"desc": "Lodos sağanakla gelir. Kumaş doku, başını sokacak bir çatı ve uyuyacak bir yatak yap.",
		"steps": [["build", "cati", 2, "Çatı kur"], ["craft", "kumas", 2, "Kumaş doku"], ["build", "yatak", 1, "Yatak kur"]],
		"reward": {"kumas": 2}},
	{"id": "sal_genisliyor", "title": "Sal Genişliyor", "chapter": "Ege'de İlk Günler",
		"desc": "Yapıların sığsın diye salı büyüt ve malzemelerin için bir sandık kur.",
		"steps": [["build", "zemin", 6, "Zemin ekle"], ["build", "sandik", 1, "Sandık kur"]],
		"reward": {"ip": 3, "tahta": 4}},
	# Zor: tehlike, yolculuk, demir
	{"id": "kopekbaligi", "title": "Kara Yüzgeç", "chapter": "Ege'de İlk Günler",
		"desc": "Salın etrafında dolaşan köpekbalığı karoları ısırıyor. Bir mızrak yap ve ona dersini ver.",
		"steps": [["craft", "mizrak", 1, "Mızrak üret"], ["hit_shark", "", 3, "Köpekbalığına mızrakla vur"]],
		"reward": {"hurda": 2}},
	{"id": "ufka_dogru", "title": "Ufka Doğru", "chapter": "Ege'de İlk Günler",
		"desc": "Bir pusula yap; elinde tutunca yönü ve esen rüzgârı gösterir. Yelkeni rüzgâr arkadan ya da yandan eserken aç, rüzgâra karşı gidilmez.",
		"steps": [["craft", "pusula", 1, "Pusula yap"], ["build", "yelken", 1, "Yelken kur"], ["travel", "", 300, "Salla 300 m yol al"]],
		"reward": {"kumas": 2}},
	{"id": "ufuktaki_ada", "title": "Ufuktaki Ada", "chapter": "Ege'de İlk Günler",
		"desc": "Haritada adalar beliriyor. Bir adaya ayak bas, bir balta yap ve bir palmiye kes.",
		"steps": [["visit_island", "", 1, "Bir adaya çık"], ["craft", "balta", 1, "Balta üret"], ["chop", "palmiye", 1, "Palmiye kes"]],
		"reward": {"tohum": 2}},
	{"id": "mavi_derinlik", "title": "Mavi Derinlik", "chapter": "Ege'de İlk Günler",
		"desc": "Adaların eteğinde rengârenk bir resif var. Dal (Ctrl), mercanların arasından deniz yosunu topla, bir istiridye aç.",
		"steps": [["dive_depth", "", 4, "4 metre derine dal"], ["pickup", "deniz_yosunu", 2, "Deniz yosunu topla"], ["pickup", "istiridye", 1, "İstiridye aç"]],
		"reward": {"ip": 3}},
	{"id": "tuylu_yoldas", "title": "Tüylü Yoldaş", "chapter": "Ege'de İlk Günler",
		"desc": "Adalarda ıslak, aç sokak kedileri dolaşıyor. Birini sev, salına al, karnını doyur ve ona bir yatak yap.",
		"steps": [["pet_cat", "", 1, "Bir adada kedi bul ve sev"], ["feed_cat", "", 2, "Kediye balık ver"], ["build", "kedi_yatagi", 1, "Kedi yatağı kur"]],
		"reward": {"kumas": 2}},
	{"id": "demirin_sirri", "title": "Demirin Sırrı", "chapter": "Ege'de İlk Günler",
		"desc": "Hurda metal eritilince işe yarar. Bir eritme ocağı kur ve metal külçe dök.",
		"steps": [["craft", "ocak", 1, "Eritme ocağı üret"], ["pickup", "metal_kulce", 2, "Metal külçe al"]],
		"reward": {"civi": 4}},
	{"id": "denizin_hakimi", "title": "Denizin Hâkimi", "chapter": "Ege'de İlk Günler",
		"desc": "Salının kenarlarını metal ile güçlendir ve köpekbalığını kovala. Artık açık denize hazırsın.",
		"steps": [["build", "guclendir", 4, "Zemin güçlendir"], ["kill_shark", "", 1, "Köpekbalığını yen"]],
		"reward": {"metal_kulce": 3}},
	# Bölüm 2: Sönmüş Fenerler
	{"id": "kazma_ve_tas", "title": "Taşın Dili", "chapter": "Sönmüş Fenerler",
		"desc": "Kayalık adalarda taş ve pas renkli demirli kayalar var. Bir kazma yap ve kır.",
		"steps": [["craft", "kazma", 1, "Kazma üret"], ["pickup", "tas", 6, "Taş topla"], ["pickup", "demir_cevheri", 2, "Demir cevheri topla"]],
		"reward": {"hurda": 3}},
	{"id": "camci", "title": "Kumdan Cam", "chapter": "Sönmüş Fenerler",
		"desc": "Adaların kumsalındaki kum yığınlarını topla, eritme ocağında cama çevir.",
		"steps": [["pickup", "kum", 6, "Kum topla"], ["pickup", "cam", 3, "Cam dök"]],
		"reward": {"tahta": 6}},
	{"id": "zeytin_dali", "title": "Zeytin Dalı", "chapter": "Sönmüş Fenerler",
		"desc": "Zeytinlik bir ada bul. Zeytin topla ve sık; zeytinyağı fenerlerin kandilini yakar.",
		"steps": [["visit_island", "zeytinlik", 1, "Zeytinlik adaya çık"], ["pickup", "zeytin", 10, "Zeytin topla"], ["craft", "zeytinyagi", 2, "Zeytinyağı sık"]],
		"reward": {"zeytinyagi": 1}},
	{"id": "mavi_yolcu", "title": "Mavi Yolcu", "chapter": "Sönmüş Fenerler",
		"desc": "Ufukta beyaz bir tirhandil: Rıza Kaptan'ın Mavi Yolcu'su. Çan çalınca yanına git, takas et; fenerlerle ilgili söylentileri de dinle.",
		"steps": [["trade", "", 1, "Rıza Kaptan ile takas yap"], ["trade", "ipucu", 1, "Ondan bir söylenti al"]],
		"reward": {"cay": 2, "domates_tohumu": 1}},
	{"id": "telsiz_sinyali", "title": "Cızırtıdaki Ses", "chapter": "Sönmüş Fenerler",
		"desc": "Bir telsiz kur ve dinle. Araştırma ekibinin sönmüş fenerlerden gelen sinyali hâlâ yayında olabilir.",
		"steps": [["craft", "telsiz", 1, "Telsiz üret"], ["build", "telsiz", 1, "Telsizi kur"], ["radio", "", 1, "Telsizi dinle"]],
		"reward": {"cam": 2}},
	{"id": "ilk_fener", "title": "Işığı Yak", "chapter": "Sönmüş Fenerler",
		"desc": "Telsizin gösterdiği fener adasına git. Duvarlarını ör, camla, merceğini tak ve kandilini zeytinyağıyla yak.",
		"steps": [["visit_island", "fener", 1, "Fener adasına çık"], ["craft", "mercek", 1, "Fener merceği yap"], ["repair_lighthouse", "", 1, "Feneri yak"]],
		"reward": {"metal_kulce": 4}},
	{"id": "kaptan_kosku", "title": "Kaptan Köşkü", "chapter": "Sönmüş Fenerler",
		"desc": "Rüzgâra muhtaç kalma. Bir dümen ve motor kur; dümene geçip rotanı çiz.",
		"steps": [["build", "dumen", 1, "Dümen kur"], ["build", "motor", 1, "Motor kur"], ["travel", "", 600, "600 m yol al"]],
		"reward": {"zeytinyagi": 2}},
	{"id": "fenerler_agi", "title": "Fenerler Ağı", "chapter": "Sönmüş Fenerler",
		"desc": "Ege'nin karanlığını dağıt: iki fener daha yak. Her fener geceleri yolunu gösterir.",
		"steps": [["repair_lighthouse", "", 2, "İki fener daha yak"]],
		"reward": {"metal_kulce": 6, "cam": 4}},
	# Derinlerin Sırrı: dalış takımı, inci, batık kadırga, köpekbalığına karşı yem ve tuzak
	{"id": "dalgic_takimi", "title": "Dalgıç Takımı", "chapter": "Derinlerin Sırrı",
		"desc": "Derinde nefes yetmez. Oksijen tüpü ve palet yap; elde tutup sol tıkla kuşan.",
		"steps": [["craft", "oksijen_tupu", 1, "Oksijen tüpü yap"], ["craft", "palet", 1, "Palet yap"], ["equip", "", 2, "İkisini de kuşan"]],
		"reward": {"inci": 1}},
	{"id": "inci_avcisi", "title": "İnci Avcısı", "chapter": "Derinlerin Sırrı",
		"desc": "Resifteki istiridyelerin bazılarında inci saklı. Üç inci bul; Rıza Kaptan inciye iyi takas verir.",
		"steps": [["pickup", "inci", 3, "İnci bul"]],
		"reward": {"metal_kulce": 2}},
	{"id": "batik_kadirga", "title": "Batık Kadırga", "chapter": "Derinlerin Sırrı",
		"desc": "Telsizde bir koy adı geçiyor: açığında yan yatmış bir kadırga. Batık koyu bul, dal ve kıçtaki sandığı aç.",
		"steps": [["visit_island", "batik", 1, "Batık kadırga koyuna çık"], ["open_wreck", "", 1, "Batık sandığı aç"]],
		"reward": {"zeytinyagi": 2}},
	{"id": "kara_yuzgece_karsi", "title": "Kara Yüzgece Karşı", "chapter": "Derinlerin Sırrı",
		"desc": "Köpekbalığını oyalamak için yem fırlat, salın kenarına diken tuzağı kur.",
		"steps": [["craft", "kopekbaligi_yemi", 1, "Köpekbalığı yemi yap"], ["bait", "", 1, "Yemi denize fırlat"], ["build", "diken_tuzagi", 1, "Diken tuzağı kur"]],
		"reward": {"civi": 6}},
	{"id": "derinden_gelen_yanki", "title": "Derinden Gelen Yankı", "chapter": "Derinlerin Sırrı",
		"desc": "Açık denizin dibinde batıklar yatıyor. Sala bir sonar kur, yankıyı izle; çapa at, dal ve batıktan ganimet çıkar. Derinde dalgıç feneri işe yarar.",
		"steps": [["build", "sonar", 1, "Sonar kur"], ["sonar_find", "", 1, "Sonarla bir batık bul"], ["loot_wreck", "", 3, "Batıktan ganimet çıkar"]],
		"reward": {"metal_kulce": 3, "antik_sikke": 2}},
	# Hıdırellez: notlar, kurdele, efsanevi ada ve dilek ağacı (oyunun sonu)
	{"id": "sisedeki_notlar", "title": "Şişedeki Notlar", "chapter": "Hıdırellez",
		"desc": "Denizde sürüklenen şişelerde ve batık sandıklarında Mavi Pusula ekibinin notları var. Notları topla, oku ve bir dilek kurdelesi hazırla.",
		"steps": [["read_note", "", 5, "Not oku"], ["craft", "kurdele", 1, "Dilek kurdelesi yap (kumaş + ip)"]],
		"reward": {"kumas": 2}},
	{"id": "hidirellez", "title": "Hıdırellez Gecesi", "chapter": "Hıdırellez",
		"desc": "Fenerlerin halkası tamamlandı; çemberin ortasında efsanevi ada belirdi. Haritadaki yeşil işarete git, çınarın dalına kurdeleni bağla.",
		"steps": [["visit_island", "efsanevi", 1, "Hıdırellez Adası'na çık"], ["tie_ribbon", "", 1, "Kurdeleni dilek ağacına bağla"]],
		"reward": {"inci": 3}},
]

## Başarımlar: [kimlik, ad, açıklama, olay, kimlik, hedef, en_yüksek_değer_mi]
const ACHIEVEMENTS := [
	["ilk_karo", "İlk Kalas", "Salına ilk zemini ekle.", "build", "zemin", 1, false],
	["marangoz", "Usta Marangoz", "40 zemin kur.", "build", "zemin", 40, false],
	["ev_sahibi", "Ev Sahibi", "6 çatı kur.", "build", "cati", 6, false],
	["ev_gibi_ev", "Ev Gibi Ev", "Bir kilim ser.", "build", "hali", 1, false],
	["depocu", "Depocu", "6 sandık kur.", "build", "sandik", 6, false],
	["balikci", "Balıkçı", "20 balık tut.", "pickup", "ham_balik", 20, false],
	["demirci", "Demirci", "10 metal külçe dök.", "pickup", "metal_kulce", 10, false],
	["oduncu", "Oduncu", "10 palmiye kes.", "chop", "palmiye", 10, false],
	["kasif", "Kâşif", "5 adaya ayak bas.", "visit_island", "", 5, false],
	["avci", "Köpekbalığı Avcısı", "Köpekbalığını yen.", "kill_shark", "", 1, false],
	["tatli_uyku", "Tatlı Uyku", "Yatağında sabaha kadar uyu.", "sleep", "", 1, false],
	["uzun_yol", "Uzun Yol", "Salla 2 km yol al.", "travel", "", 2000, false],
	["dayanikli", "Dayanıklı", "10. güne ulaş.", "day", "", 10, true],
	["madenci", "Madenci", "20 demir cevheri çıkar.", "pickup", "demir_cevheri", 20, false],
	["yengec", "Yengeç Avcısı", "5 yengeç yakala.", "pickup", "yengec_eti", 5, false],
	["fenerci", "Fenerci", "Bir feneri yeniden yak.", "repair_lighthouse", "", 1, false],
	["ege_isiklari", "Ege'nin Işıkları", "5 fener yak.", "repair_lighthouse", "", 5, false],
	["pazarlikci", "Pazarlıkçı", "Rıza Kaptan ile 10 takas yap.", "trade", "", 10, false],
	["derin_dalgic", "Derin Dalgıç", "12 metre derine dal.", "dive_depth", "", 12, false],
	["inci_avcisi", "İnci Avcısı", "10 inci bul.", "pickup", "inci", 10, false],
	["tuzakci", "Tuzakçı", "Köpekbalığı 3 kez diken tuzağına çarpsın.", "trap_hit", "", 3, false],
	["hidirellez_ach", "Hıdırellez", "Dilek ağacına kurdeleni bağla.", "tie_ribbon", "", 1, false],
	["mavi_pusula", "Mavi Pusula'nın İzinde", "Bütün notları bul (8).", "read_note", "", 8, false],
	["hazine_avcisi", "Hazine Avcısı", "Batıklardan 15 ganimet çıkar.", "loot_wreck", "", 15, false],
	["derin_yanki", "Derin Yankı", "Sonarla 5 batık bul.", "sonar_find", "", 5, false],
	["kedi_dostu", "Kedi Dostu", "Kedine 20 kez yemek ver.", "feed_cat", "", 20, false],
	["bekci_kedi", "Bekçi Kedi", "Kedin 3 kez köpekbalığına karşı uyarsın.", "cat_warn", "", 3, false],
	["kaptan", "Ege Kaptanı", "Bütün görevleri tamamla.", "quests_done", "", 1, false],
]

var main
## Etkin görevin sırası (QUESTS.size() = hepsi bitti) ve adım ilerlemeleri.
var current := 0
var progress: Array = []
## Başarım sayaçları ve açılanlar.
var ach_count := {}
var ach_done := {}


func _ready() -> void:
	reset()


func reset() -> void:
	current = 0
	ach_count = {}
	ach_done = {}
	_start_current()


func _start_current() -> void:
	progress = []
	if current < QUESTS.size():
		for s in QUESTS[current]["steps"]:
			progress.append(0.0)
	credit_existing()
	changed.emit()


## Görev başlarken (ya da kayıt yüklenince) oyuncunun zaten sahip olduklarını sayar:
## üretilmiş/kurulmuş eşya envanterde ya da salda varsa, toplanacak eşya envanterdeyse adım ilerler.
## Böylece görev açılmadan önce yapılmış işler görevi kilitlemez.
func credit_existing() -> void:
	if main == null or main.hud == null or main.player == null or main.raft == null or all_done():
		return
	var q: Dictionary = QUESTS[current]
	for i in q["steps"].size():
		var s: Array = q["steps"][i]
		var have := _already(s[0], s[1])
		if have > progress[i]:
			progress[i] = minf(float(s[2]), have)
	if _quest_complete():
		_finish_quest()


func _already(ev: String, id: String) -> float:
	var inv = main.player.inv
	var raft = main.raft
	match ev:
		"pickup":
			return float(inv.count(id))
		"read_note":
			return float(main.hud.lore.read.size()) if main.hud != null and main.hud.lore != null else 0.0
		"craft":
			return float(inv.count(id) + _placed(id))
		"build":
			if id == "zemin":
				return float(maxi(0, raft.tiles.size() - 4))
			if id == "guclendir":
				var m := 0
				for c in raft.tiles:
					if raft.is_metal(c):
						m += 1
				return float(m)
			var n := 0
			for k in raft.structures:
				if raft.structures[k]["kind"] == id:
					n += 1
			return float(n + _placed(id))
	return 0.0


## Salda kurulu bu türden yapı sayısı (istiflenmiş sandıklar dahil).
func _placed(kind: String) -> int:
	var n := 0
	for c in main.raft.buildings:
		if main.raft.buildings[c].kind == kind:
			n += 1
	if kind == "sandik":
		for c in main.raft.stacks:
			n += main.raft.stacks[c].size()
	return n


func active() -> Dictionary:
	return QUESTS[current] if current < QUESTS.size() else {}


func all_done() -> bool:
	return current >= QUESTS.size()


## Oyundan gelen olay. Görev adımlarını ve başarımları ilerletir.
func event(ev: String, id := "", amount := 1.0) -> void:
	var touched := false
	if not all_done():
		var q: Dictionary = QUESTS[current]
		for i in q["steps"].size():
			var s: Array = q["steps"][i]
			if s[0] == ev and (s[1] == "" or s[1] == id) and progress[i] < float(s[2]):
				var before: float = progress[i]
				progress[i] = minf(float(s[2]), progress[i] + amount)
				touched = true
				if before < float(s[2]) and progress[i] >= float(s[2]) and main != null and main.hud != null:
					main.hud.notify("Adım tamam: %s" % s[3], Color(0.6, 1.0, 0.6))
		if touched and _quest_complete():
			_finish_quest()
	for a in ACHIEVEMENTS:
		if ach_done.has(a[0]) or a[3] != ev or not (a[4] == "" or a[4] == id):
			continue
		var v: float = float(ach_count.get(a[0], 0.0))
		v = maxf(v, amount) if a[6] else v + amount
		ach_count[a[0]] = v
		touched = true
		if v >= float(a[5]):
			_unlock(a)
	if touched:
		changed.emit()


func _quest_complete() -> bool:
	var q: Dictionary = QUESTS[current]
	for i in q["steps"].size():
		if progress[i] < float(q["steps"][i][2]):
			return false
	return true


func _finish_quest() -> void:
	var q: Dictionary = QUESTS[current]
	if main != null:
		var parts: Array = []
		for k in q["reward"]:
			main.player.give(k, q["reward"][k])
			parts.append("%d %s" % [q["reward"][k], Items.name_of(k)])
		main.hud.notify("GÖREV TAMAM: %s" % q["title"], Color(1.0, 0.85, 0.35))
		main.audio.play("craft", -2.0)
		if not parts.is_empty():
			main.hud.toast("Görev tamamlandı: %s  ·  Ödül: %s" % [q["title"], ", ".join(parts)], 4.0)
	current += 1
	_start_current()
	if all_done():
		event("quests_done")
	elif main != null:
		main.hud.notify("Yeni görev: %s" % QUESTS[current]["title"], Color(0.75, 0.9, 1.0))


func _unlock(a: Array) -> void:
	ach_done[a[0]] = true
	if main != null and main.hud != null:
		main.hud.notify("BAŞARIM: %s" % a[1], Color(1.0, 0.8, 0.3))
		main.audio.play("chest_open", -6.0, "Arayuz")


func to_data() -> Dictionary:
	# Etkin görev kimliğiyle kaydedilir: görev sırası değişse de kayıt doğru göreve döner.
	var done_ids: Array = []
	for i in mini(current, QUESTS.size()):
		done_ids.append(QUESTS[i]["id"])
	return {"current_id": QUESTS[current]["id"] if current < QUESTS.size() else "", "done_ids": done_ids,
		"current": current, "progress": progress, "ach_count": ach_count, "ach_done": ach_done.keys()}


func from_data(d: Dictionary) -> void:
	current = int(d.get("current", 0))
	if d.has("current_id"):
		var cid: String = d["current_id"]
		current = QUESTS.size()
		for i in QUESTS.size():
			if QUESTS[i]["id"] == cid:
				current = i
				break
	_start_current()
	var p: Array = d.get("progress", [])
	for i in mini(p.size(), progress.size()):
		progress[i] = maxf(progress[i], float(p[i]))
	ach_count = d.get("ach_count", {})
	ach_done = {}
	for k in d.get("ach_done", []):
		ach_done[k] = true
	credit_existing()
	changed.emit()
