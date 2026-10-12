# SaLda — Görevler, Adalar, Rota, Su Altı ve Kendine Özgü Ege Dünyası

## Context
Hayatta kalma döngüsü tamam (sal, inşa, ev, ağ, olta, palmiye, köpekbalığı, kayıt). Eksik olan
**uzun vadeli hedef, çeşitlilik ve Raft'tan ayrışan bir kimlik**. Kullanıcı şunları seçti:
görev/hikâye zinciri, ada çeşitleri + kaynaklar, dümen/motor/rota, su altı/dalış; hikâye havası
**gizemli keşif**; ayrıca Raft'tan ayrışmak için **Ege havası ve rüzgâr okuma, salda kedi yoldaş,
gezgin tüccar teknesi, deniz fenerleri ağı**.
Kurallar aynı: kodu ben yazarım; görseller CC0 ya da koddan; dokular 1024 px; her adım otomatik testle doğrulanır.

## Kimlik: Ege'de kaybolan fenerler
Mekân Ege Denizi. Adalardaki eski deniz fenerleri sönmüş; geceleri deniz tehlikeli. "Mavi Pusula"
araştırma ekibi fenerleri ve **Hızır** efsanesini araştırırken kayboldu. Oyuncu ekibin notlarını izler,
fenerleri yeniden yakar; her fener dünyanın bir parçasını açar. Son: **Hıdırellez gecesi** beliren
efsanevi ada, dilek ağacı ve kurtarma.

Bölümler (görevlerle ilerler):
1. **Şişedeki not** (enkazla gelir) → ilk görevler, pusula yapımı.
2. **İlk fener adası** → feneri onar (taş + cam + yağ) → harita bölgesi açılır, telsiz sinyali.
3. **Batık kadırga adası** → seyir defteri, kilitli sandık, dalışla anahtar.
4. **Resif üssü (su altı)** → ekibin son kaydı, Hıdırellez'in tarihi.
5. **Hıdırellez gecesi** → efsanevi ada, dilek ağacı, kurtarma işareti, "Son" ekranı; serbest oyun sürer.

## Aşamalar (sırayla; her biri ayrı teslim)

### A) Görev altyapısı ve günlük
- `scripts/quests.gd`: görev tanımı (id, başlık, açıklama, adımlar, ödül), durum, `progress(event, data)`.
  Olaylar: `craft`, `pickup`, `build`, `visit_island`, `read_note`, `repair_lighthouse`, `kill_shark`, `dive_depth`, `trade`, `pet_cat`.
- Olay bağlantıları: `main.craft()`, `player.give()`, `raft.add_tile/add_structure/place_building`, `shark` ölümü.
- Günlük ekranı **J** (`hud._build_bigmap` kalıbı); ekranda aktif görev satırı; 10–15 başarım (`hud.notify`).
- Kayıt: `save_game/load_game` → `"quests"`.

### B) Ege rüzgârları ve yön bulma (Raft'tan ayrışan çekirdek)
- `world.gd`: rüzgâr yönü ve gücü, zamanla döner; adları gerçek Ege rüzgârları
  (Yıldız, Poyraz, Gündoğusu, Keşişleme, Kıble, Lodos, Batı, Karayel; öğleden sonra İmbat).
- `raft.gd`: yelken itişi rüzgâr ile yelken açısına bağlı (`sail_vector()` buna göre); rüzgâra karşı gidilmez, yan rüzgârla kavançalı gidilir.
- **Pusula** (el aleti): elde tutunca yön ve rüzgârın adı; HUD'da küçük rüzgâr gülü. Gece **Kutup Yıldızı** gökyüzü shader'ında belirgin (kuzeyi gösterir).
- Lodos fırtınası olayı: dalgalar büyür, yağmur, yıldırım; fenerler yanıyorsa köpekbalığı uzak durur.

### C) Ada çeşitleri ve yeni kaynaklar
- `island.gd` türleri: `palmiye` (mevcut), `kayalik`, `fener` (yıkık fener + kamp), `batik_kadirga`, `zeytinlik` (zeytin ağacı, keçiboynuzu), `efsanevi` (yalnız Hıdırellez gecesi).
  `height_at()` türe göre; `main._spawn_island()` türü seçer, hikâye adaları belirli mesafelerde garanti çıkar.
- **Kazma** (`tool_models.gd` + `player._axe` kalıbı): taş, demir cevheri. Kaya düğümü `palm.gd` kesme kalıbını izler.
- Yeni malzemeler: taş, demir cevheri, kil, kum, deniz yosunu, zeytin, yengeç eti, martı yumurtası, inci.
  Tarifler: cevher→külçe (Eritme Ocağı), kum→cam, kil→tuğla/küp, zeytin→zeytinyağı (fener yakıtı, yemek), yosun→ip.
- Canlılar: yengeç (kumda gezer), martı yuvası (yumurta). CC0 kaya/fener/gemi modelleri Poly Haven'dan → `assets/KAYNAKLAR.md`.

### D) Deniz fenerleri ağı (hikâyenin omurgası)
- Fener adasında yıkık fener yapısı; onarım adımları (taş duvar, cam, zeytinyağı, mercek). Onarılınca:
  geceleri dönen ışık huzmesi, haritada çevre bölge açılır, telsiz sinyali, çevresinde köpekbalığı saldırmaz.
- Sala da küçük **fener direği** (mevcut `fener` geliştirilir).

### E) Dümen, motor ve rota
- **Dümen** (`building.gd` yeni tür): E ile tut → A/D sal yönü (oturma `player.sit()` kalıbı).
- **Motor** (hurda + külçe + çivi), yakıt zeytinyağı/tahta; rüzgârdan bağımsız yavaş itiş; döngü sesi.
- **Telsiz alıcısı**: fener sinyallerini çözer → hedef işareti; M haritasında kendi işaretini koyma.
- Ekran hedef işareti `raft_marker.gd` kalıbıyla.

### F) Salda kedi yoldaş
- `scripts/cat.gd`: bir adada ıslak sokak kedisi; E ile sev → sala gelir. Sal üstünde dolaşır, uyur, güneşlenir;
  balık verirsen yer; yengeç/fare yakalar; köpekbalığı yaklaşınca tüyleri kabarır, tıslar (uyarı).
  Kedi yatağı (yapı). Model: koddan üretilmiş stilize kedi (gövde/kafa/kuyruk kemik animasyonu) ya da CC0 animasyonlu kedi.
- Kayıt ve isim verme.

### G) Gezgin tüccar teknesi
- Belirli aralıklarla salın yanına yanaşan tekne (koddan model + tüccar: Quaternius CC0 karakter).
- Takas ekranı (`hud` sandık ekranı kalıbı): inci, kurutulmuş balık, zeytinyağı, kilim ↔ tohum, nadir tarif, mercek, pusula.
- Tüccar hikâye ipuçları da satar.

### H) Su altı ve dalış
- Ada çevresinde resif: mercan, yosun, kum, istiridye (inci) — `pickup.gd` ile.
- **Oksijen tüpü** ve **palet** (2 ekipman yuvası; `player.gd` oksijen/yüzme hızı).
- Batık kadırga içi, su altı mağarası (bölüm 3–4), dalış derinliği olayı.
- Köpekbalığı **yemi** (`shark.gd` yeni "oyalanma" durumu) ve sal kenarına **diken tuzağı**.

### I) Hikâye içeriği ve oyun sonu
- `scripts/lore.gd`: notlar, seyir defteri, Hızır/Hıdırellez metinleri; kâğıt görünümlü okuma paneli.
- Hıdırellez gecesi olayı: efsanevi ada, dilek ağacına kurdele bağlama, kurtarma işareti, "Son" ekranı, serbest oyun.
- Açılış vitrini (`showcase.gd` `furnish`): dümen, motor, telsiz, kedi.

## Yeniden kullanılacaklar
- Kesme/parçalanma ve E ile toplanan parçalar: `scripts/palm.gd` (`chop`, `_split`, `_spawn_pickup`); toplanabilir: `scripts/pickup.gd`.
- Ada yerleşimi: `island.gd` `_ground()`, `_pickup()`; ada akışı: `main._spawn_island/_stream_world`.
- Yapı kalıbı: `building.gd` (`SIZES`, `FLAT`, `_build_*`, `prompt`, `interact`, `to_data/from_data`); tarif/kategori: `items.gd`.
- Oturma/kilitlenen kontrol: `player.sit/stand_up`; sandık ekranı ve takas: `hud.open_chest/quick_store` kalıbı.
- Ekran işareti: `raft_marker.gd`; harita: `map.gd`; bildirim: `hud.notify/toast`.
- Sal hareketi: `raft.gd` `_physics_process` (`DRIFT`, `sail_vector()`, `vel`), `Waves` sakin su; gökyüzü: `shaders/sky.gdshader`; hava: `world.gd`.
- Karakter modeli/animasyon: `castaway.gd` (Quaternius CC0) kalıbı.
- Kayıt: `main.save_game/load_game`, `raft.to_data/from_data`.

## Doğrulama
- Her aşamada `_autotest()`'e adım: görev tamamlandı ve kayda yazıldı; rüzgâra karşı hız < yan rüzgâr hızı; kazma kayayı kırdı;
  fener onarıldı → bölge açıldı; dümen 90° çevirdi; motor hızı > 0 rüzgârsız; kedi sala geldi ve uyardı; takas envanteri değiştirdi;
  palet yüzme hızını artırdı; yem köpekbalığını oyaladı.
- Çalıştırma: `Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --autotest` (test kendi kayıt dosyasını kullanır).
- Görsel: Beckett `debug_action` (yeni: `island:fener`, `wind`, `cat`, `trader`, `reef`, `quest:N`) + ekran görüntüsü; oyuncunun açık oturumu bölünmez.
- Her aşama sonunda kısa Türkçe özet; kurulum dosyası yalnızca istenince derlenir.

## Önerilen sıra
A (küçük) → B rüzgâr (orta) → C adalar (büyük) → D fenerler (orta) → E dümen/motor (orta) → F kedi (orta) → G tüccar (orta) → H su altı (orta) → I hikâye/son (orta).
Her aşama ayrı teslim edilir; ara geri bildirimle yön değişebilir.

## Durum (8 Ekim 2026)
- **Aşama A tamam:** 14 görevlik "Ege'de İlk Günler" zinciri (kolaydan zora), 14 başarım, sol üstte takip, J seyir defteri; kayıtta görev kimliğiyle.
- **Balıkçılık yenilendi:** güç doldurarak atış, yoklama/vuruş, kanca takma, gerginlik çubuklu mücadele (koparma/kaçırma),
  Ege balıkları (İstavrit, Çipura, Levrek, Lüfer, Palamut, Orfoz), sıçrayan balık, eğilen olta, saate göre vuruş.
- **Aşama B tamam:** Ege rüzgârları (Yıldız, Poyraz, Gündoğusu, Keşişleme, Kıble, Lodos, Batı, Karayel, İmbat), meltem ağırlıklı;
  yelken itişi rüzgâr açısına bağlı (rüzgâra karşı gidilmez), sal rüzgârla sürüklenir; Pusula (iğne kuzeyi gösterir, yön/rüzgâr/verim);
  haritada rüzgâr oku; gece Kutup Yıldızı; fırtınada Lodos, şimşek ve gök gürültüsü (CC0). Kayıtta rüzgâr.
- Görsel kontrol için: `Godot_v4.7.2-stable_win64.exe --path . -- --debug=new_game,journal --shot=dosya.png`
- **Aşama C tamam:** ada türleri (palmiye, kayalık, zeytinlik, fener), kazma + kaya (taş, demir cevheri), zeytin ağacı, yengeç, martı yuvası, kum;
  ocakta cam ve cevherden külçe; zeytinyağı, mercek; yeni yiyecekler (yengeç, sahanda yumurta).
- **Aşama D tamam:** fener adaları kalıcı yer işareti (kayıtta), 4 adımlı onarım, dönen huzme, haritada fenerler, yanan fener çevresinde köpekbalığı koruması.
- **Ek: Sonar ve açık deniz batıkları (8 Ekim):** sonar yapısı (yankı sesi, 250 m menzil, harita işareti, hedef koyma); kalıcı batık sahaları (antik / balıkçı / yük, 12-20 m sığlık); ganimet noktaları (sandık, amfora, heykel, konteyner, ağ, varil; açılmışlık kayıtta), kabarcık ipucu;
  antik sikke, bronz heykel, dalgıç feneri (3. dalış yuvası, kafa lambası); köpekbalığı derindeki dalgıcı 75 m'den sezer; "Derinden Gelen Yankı" görevi, 2 başarım, tüccar takasları.
- **Aşama I tamam (oyun sonu):** hikâye notları (5 şişe notu + 3 seyir defteri sayfası + Hızır), kâğıt okuma paneli, defterde Notlar; denizde not taşıyan şişeler;
  "Hıdırellez" bölümü (Şişedeki Notlar, Hıdırellez Gecesi), Dilek Kurdelesi; Hıdırellez Adası (dilek çınarı, 70 kurdele, ateş böcekleri, gül, ateş, fenerler, kıyıda Rıza Kaptan);
  son anlatısı + "Son" ekranı (istatistikler) + serbest oyun; 2 başarım; açılış vitrinine nazar, kedi yatağı, diken tuzağı. Geliştirici çalıştırmaları artık kayıt yuvalarına yazmaz.
  **Yol haritası A–I tamamlandı.**
- **Optimizasyon + istekler (8 Ekim):** görev olayı her kare seyir defterini yeniden kuruyordu (ana döngü 9.7 ms → 0.08 ms); uzak deniz halka ağ (1.28 M → 28 bin üçgen); resif/batık/tekne/zeytin ağları birleştirildi (ada yanı 2400 → 1100 çizim çağrısı); küre/halka ağ yoğunluğu düşürüldü. Ölçüm: açık deniz 73 → 280 FPS, ada yanı 64 → 257 FPS (RTX 4060). `-- --perf=...` ölçüm modu.
  Tohum keseleri yeniden (ağzı açık çuval + ürün minyatürü). Zorluk modları (Kolay/Normal/Zor) ve 3 kayıt yuvası.
- **Aşama H tamam:** ada eteğinde resif (mercanlar, yosun, deniz yıldızı, kestane, balık sürüleri), istiridye (inci), deniz yosunu; oksijen tüpü ve palet (dalış takımı yuvaları, TÜP çubuğu); batık kadırga koyu (sandık + seyir defteri sayfası); köpekbalığı yemi ve diken tuzağı; "Mavi Derinlik" görevi ve "Derinlerin Sırrı" bölümü; 3 başarım. J defteri ve Oynanış ekranı kaydırılabilir.
  Su altı sisi berraklaştırıldı (20-25 m görüş, turkuaz), mercanlar kümeler hâlinde. Sıradaki: **Aşama I (hikâye/son)** — onay beklenir.
- **Aşama G tamam:** gezgin tüccar Rıza Kaptan ve tirhandil "Mavi Yolcu" (koddan tekne: kamara, direk, sarılı yelken, al bayrak, yükler; kaptan Quaternius "Farmer" karakteri: hasır şapka, keten gömlek, lacivert tulum, baş kemiğine bağlı kır bıyık).
  Ufuktan gelir, salın kenarına yanaşır, çan çalar; takas ekranı (her gelişte rastgele 5 teklif + söylenti), söylenti en yakın sönmüş feneri işaretler; yeni eşyalar nazar boncuğu (köpekbalığı saldırısını savuşturur) ve demli çay.
  "Mavi Yolcu" görevi, "Pazarlıkçı" başarımı, haritada tekne işareti, kayıtta bir sonraki geliş. Sıradaki: **Aşama H (su altı)** — onay beklenir.
- **Aşama F tamam:** kedi yoldaş (adalarda sokak kedisi, sevince sala gelir, Türkçe isim, 4 renk; dolaşır/oturur/uyur/yer; balıkla beslenir, hediye getirir, köpekbalığına tıslar; kedi yatağı; kayıtta), "Tüylü Yoldaş" görevi, 2 başarım.
  Ek: 5 tohum türü (patates, domates, biber, karpuz, kalıcı zeytin fidanı), tohum keseleri ve bitki görünümleri; balta/kazma vuruşu aletin kendi düzleminde.
- **Aşama E tamam:** dümen (A/D rota, yelkenler rotaya döner), motor (tahta/zeytinyağı yakıt, rüzgârsız itiş), telsiz (en yakın sönmüş fener hedefi, ekranda ve haritada).
- Görevlerde 2. bölüm "Sönmüş Fenerler" (7 görev) ve yeni başarımlar.
- Sıradaki: **Aşama F — Salda kedi yoldaş** (kullanıcı onayı bekleniyor).
