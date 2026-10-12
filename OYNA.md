# SaLda

Tuşların ve ipuçlarının tamamı oyunda **Menü → Oynanış** ekranında. Can, açlık, su ve oksijen sol altta.

Alet çubuğuna (1-0) yalnızca yiyecek, su, alet ve yapılar girer; tahta, plastik, ip gibi malzemeler çantada durur. Ürettiğin alet ya da yapı doğrudan eline gelir; yapıysa menü kapanır, hemen yerleştirirsin.

Okyanusta sal üzerinde hayatta kalma oyunu. Godot 4.7.2.
Not: "Raft" adı ve görselleri Redbeet Interactive'e aittir; bu oyun yalnızca oynanış türünü örnek alır,
orijinal oyundan hiçbir içerik kullanmaz.

## Nasıl açılır
Godot 4.7.2 → Proje Yöneticisi → `Raft` klasöründeki proje → ▶ (F5). Ana menüden **Yeni Oyun** ya da **Devam Et**.

## Kontroller
| Tuş | İşlev |
|---|---|
| WASD / Shift | Hareket / koş |
| Boşluk | Zıpla · suda yukarı yüz · salın kenarında sala tırman |
| Ctrl / C | Suda dal |
| 1–0 / fare tekerleği | Alet çubuğundan eşya seç |
| Sol tık | Seçili eşyayı kullan (kanca: basılı tut-bırak, sonra basılı tutarak çek) |
| Sağ tık | Kancayı / oltayı geri al |
| E | Etkileşim · suda yakındaki enkazı topla · çekiçle karo onar |
| R | Çekiçle yapı, duvar, çatı ya da karo sök (malzeme iade) |
| T | Taşıma modu: yapıyı içindekilerle al, sol tıkla başka karoya ya da sandık kulesine bırak (R döndürür, T / sağ tık geri koyar) |
| Tab / I | Envanter ve üretim |
| J | Seyir defteri: görevler ve başarımlar |
| M | Büyük harita |
| Esc | Duraklat (kaydet, ayarlar, ana menü) |

## Oynanış
* **Enkaz:** Tahta, plastik, palmiye yaprağı ve varil (rastgele ganimet) salın yanından geçer. Kancayla ya da suya girip E ile toplanır.
* **Üretim (Tab):** 5 kategori, 26 tarif; her malzeme için "elindeki / gereken" ve eksikler açıkça yazılır.
  * Malzeme: İp, Çivi, Kumaş
  * Araç: Kanca, Mızrak, Olta, Balta (ağaç keser), Meşale (elde ışık)
  * Yiyecek: Su Arıtıcı, Izgara, Ekim Saksısı, Yağmur Toplayıcı, Balık Ağı, Balık Çorbası
  * Yapı: Depo Sandığı, Yatak, Yelken, Çapa, Fener, Tavan Lambası
  * Gelişmiş: Eritme Ocağı (hurda → metal külçe), Toplama Ağı (otomatik enkaz toplar), Metal Kanca, Metal Mızrak, Dürbün
* **İnşa:** Çekiçle zemin (1 tahta + 1 plastik), duvar, kapılı/pencereli duvar ve çatı. Diğer yapılar üretilip alet çubuğundan sala yerleştirilir.
* **Ev ve yağmur:** Çatı altına yağmur yağmaz. Yağmurda uyumak için yatağın üstünde çatı olmalı.
* **Işık:** Meşale (elde), fener (sal üstünde), tavan lambası (çatıya asılır). Gece ve yağmurda kendiliğinden yanar; yüksek grafik kalitesinde ışık halesi oluşur.
* **Yiyecek ve su:** Arıtıcı (1 tahta yakıt → temiz su), ızgara (çiğ balık / patates pişirir), saksı (tohum → patates), olta ile balık, adalarda hindistan cevizi.
* **Yelken ve çapa:** Yelken salı baktığın yöne götürür; çapa durdurur. Sal adaya çarpınca durur.
* **Adalar:** ~520 m'de bir belirir. Kumsalda yaprak, hindistan cevizi, tohum, plastik; deniz tabanında (dalarak) hurda metal. Haritada mesafe ve yön görünür.
* **Köpekbalığı:** Salın kenar karolarını ısırır (çekiçle onar), suda sana saldırır. Mızrakla 3 isabette kaçar.
* **Hayatta kalma:** Açlık, susuzluk, oksijen. Bayılırsan yatağında (yoksa salın merkezinde) uyanırsın, envanter kaybolmaz.
* **Gece-gündüz ve hava:** Bir gün 24 dakika. Ara ara yağmur ve fırtına (dalgalar büyür). Gece yatakta uyunur.
* **Kayıt:** 3 dakikada bir otomatik, yatakta ve duraklatma menüsünden elle.

## Teknik notlar
* Okyanus: GPU shader'da 4 dalga + kayan detay dalgacıklar, yarı saydam su (derinlikle solan kırılma), köpük; aynı dalga formülü GDScript'te (`waves.gd`) — her şey görünen suya oturur.
* Gökyüzü: kendi shader'ı (gün batımı, bulut, güneş, ay, yıldız). Köpekbalığı modeli koddan üretilir (`shark_mesh.gd`), yüzme hareketi shader'dadır.
* Eşya ikonları oyun açılırken 3B modellerden otomatik çekilir (`icons.gd`).
* Grafik kalitesi Ayarlar'dan: Düşük / Orta / Yüksek / Ultra (MSAA, FXAA/TAA, SSR, SSAO, SSIL, gölge çözünürlüğü).
* Otomatik test: `Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --autotest`

## Kurulum dosyası
`kurulum_olustur.bat` dosyasına çift tıkla. Sonuç: `build/SaLda_Kurulum_1.0.0.exe` (ilk seferde Godot dışa aktarma şablonları indirilir).

## Balıkçılık
Olta elindeyken sol tıkı basılı tut (atış gücü), bırakınca şamandıra atılır. Şamandıra titrerse balık yokluyordur; suya gömülünce hemen sol tıkla kancayı tak.
Mücadelede sol tık basılı = sar, bırak = boşluk ver. Gerginlik çubuğu kırmızıya varırsa misina kopar; çok gevşek kalırsa balık kurtulur.
Ege balıkları: İstavrit, Çipura, Levrek, Lüfer, Palamut, nadiren Orfoz. Şafakta ve akşamüstü daha çok vurur; büyük balık birden fazla çiğ balık verir.

## Hikâye: Sönmüş Fenerler ve Hıdırellez
* Mavi Pusula araştırma ekibi Ege'de kayboldu. Denizde sürüklenen **şişelerde** (kancayla ya da E ile topla) ve batık kadırga sandıklarında ekibin notları var. Notlar kâğıt görünümlü bir ekranda okunur, seyir defterinde (J) "Notlar" bölümünde tekrar açılır.
* Görev zinciri: Ege'de İlk Günler → Sönmüş Fenerler → Derinlerin Sırrı → **Hıdırellez**. Fenerleri yakıp notları topladıktan sonra bir **Dilek Kurdelesi** (kumaş + ip) yap.
* Son bölüm açılınca fenerlerin çemberinin ortasında **Hıdırellez Adası** belirir (haritada işaretli): dilek çınarı, gül çalıları, Hıdırellez ateşi, geceleri ateş böcekleri; kıyıda Rıza Kaptan bekler.
* Kurdeleni çınarın dalına bağlayınca son anlatısı ve "Son" ekranı gelir; ardından oyun serbest olarak sürer.

## Kayıt yuvaları ve zorluk
* **Yeni Oyun:** Önce zorluk (Kolay / Normal / Zor), sonra 3 kayıt yuvasından biri seçilir. Dolu yuvaya yeni oyun için iki kez tıklanır.
  * Kolay: açlık-susuzluk yavaş, köpekbalığı seyrek ve zayıf, karo 4 ısırıkta kopar.
  * Normal: dengeli (karo 3 ısırıkta kopar).
  * Zor: açlık hızlı, köpekbalığı sık ve güçlü, karo 2 ısırıkta kopar; bayılınca çantadaki malzemelerin yarısı kaybolur.
* **Kayıtlar:** Yuvaların günü, zorluğu, sal büyüklüğü, görevi ve kayıt saati görünür; tıkla → yükle, Sil (iki kez) → sil. "Devam Et" en son oynanan yuvayı açar.
* Kayıt; otomatik (3 dk), yatakta ve duraklatma menüsünden o anki yuvaya yapılır. Eski tek kayıt 1. yuvaya taşındı.

## Ege'de yolculuk
* **Rüzgâr:** Yıldız, Poyraz, Lodos, İmbat... Yelken rüzgâr arkadan ya da yandan eserken çeker; rüzgâra karşı gidilmez. Pusula yönü, rüzgârı ve yelken verimini gösterir. Gece Kutup Yıldızı kuzeydedir.
* **Adalar:** Palmiye adası, kayalık ada (kazmayla taş ve demir cevheri), zeytinlik (zeytin → zeytinyağı) ve fener adası. Her adada yengeç, martı yuvası ve kum yığını bulunur.
* **Ocak:** 2 hurda ya da 2 demir cevheri → metal külçe; 2 kum → cam (+1 tahta). Elinde tuttuğunu eritir.
* **Fenerler:** Yıkık feneri 4 adımda onar (10 taş, 4 cam, mercek, 2 zeytinyağı). Yanan fener geceleri döner, haritada sarı görünür; yakınında köpekbalığı salı ısırmaz.
* **Telsiz:** Dinleyince en yakın sönmüş fenerin sinyalini bulur; haritada ve ekranda yeşil hedef olarak işaretler.
* **Tohumlar:** Patates, domates, biber, karpuz tohumu ve zeytin fidanı (varil ve adalardan). Saksıda büyür; hasatta ürünle birlikte 1–2 tohum geri gelir. Zeytin fidanı kalıcıdır, hasattan sonra yeniden meyve verir.
* **Kedi:** Palmiye ya da zeytinlik adalarda ıslak bir sokak kedisi bulabilirsin. Sev (E) → sala gelir, bir adı olur. Sal üstünde dolaşır, güneşlenir, geceleri kedi yatağında uyur. Balık verirsen mutlu olur, ara ara hediye getirir; köpekbalığı yaklaşınca tüylerini kabartıp tıslar.
* **Su altı:** Her adanın eteğinde resif var (mercanlar, yosun tarlaları, balık sürüleri). Ctrl ile dal; deniz yosunu topla (3 yosun → 1 ip), istiridye aç (bazılarından inci çıkar).
* **Dalış takımı:** Oksijen tüpü ve palet üret, elde tutup sol tıkla kuşan. Tüp yaklaşık 80 sn hava verir, yüzeyde kendiliğinden dolar (ekranda TÜP çubuğu). Paletle çok daha hızlı yüzersin. Envanterdeki "Dalış takımı" yuvalarına tıklayınca çıkarılır.
* **Sonar ve açık deniz batıkları:** Sonar (Gelişmiş: 3 metal külçe, 2 cam, 4 hurda, 4 çivi) sala kurulur, 6 saniyede bir yankı yollar ve 250 m içindeki batıkları bulur; bulunanlar haritada mor işaretle görünür. Sonara E ile basınca en yakın batığa hedef konur.
  * Batıklar 12–20 m derindeki kumlu sığlıklarda: **antik ticaret gemisi** (amforalar, sütunlar, bronz heykel), **balıkçı teknesi** (ağlar, variller), **yük gemisi enkazı** (paslı konteynerler).
  * Üstüne gelince çapa at, tüple dal. Açılmamış ganimetin üstünden kabarcık yükselir; sandık, amfora, konteyner, ağ ve variller E ile açılır, açılanlar kayıtta kalır.
  * **Antik sikke** ve **bronz heykel parçası** Rıza Kaptan'da çok değerlidir (mercek, oksijen tüpü, dürbün, dalgıç feneri...).
  * **Dalgıç feneri** (Gelişmiş: cam, 2 metal külçe, 2 plastik) dalış takımının üçüncü yuvasıdır: su altında ve gece yanar. Derinde dalan dalgıcı köpekbalığı daha uzaktan sezer.
* **Batık kadırga:** Batık kadırga koylarında, açıkta 5–6 m derinde yan yatmış bir kadırga bulunur. Kıçtaki sandıkta inci, külçe, mercek ve kayıp ekibin seyir defterinden bir sayfa vardır.
* **Köpekbalığına karşı:** Köpekbalığı yemini denize fırlat, yarım dakika onunla oyalanır. Diken tuzağı salın kenarına kurulur; kendi karosunu ve yanındakileri korur, 3 çarpmada körelir.
* **Gezgin tüccar:** Çan sesi duyunca Rıza Kaptan'ın teknesi Mavi Yolcu salına yanaşıyor demektir (haritada mavi-beyaz tekne). E ile takas ekranı açılır: topladıklarını verip tohum, cam, külçe, mercek, pusula, dürbün, demli çay ya da nazar boncuğu alırsın. Söylenti satın alırsan en yakın sönmüş feneri haritana işaretler. Tekne birkaç dakika bekler, sonra gider; 20–25 dakikada bir yeniden uğrar.
* **Nazar boncuğu:** Sala dikilir; köpekbalığının saldırılarını sık sık savuşturur.
* **Dümen ve motor:** Dümene geç (E), A/D ile rota çiz; açık yelkenler rotaya döner. Motora tahta (40 sn) ya da zeytinyağı (3 dk) koy ve çalıştır; rüzgârsız da yol alırsın.
