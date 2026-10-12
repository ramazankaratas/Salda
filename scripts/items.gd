extends RefCounted
## Eşya veritabanı ve üretim tarifleri.
## type: material | food | tool | place (sala yerleştirilen yapı)

const ITEMS := {
	# Malzemeler
	"tahta": {"name": "Tahta", "type": "material", "stack": 30, "color": Color(0.62, 0.44, 0.26)},
	"plastik": {"name": "Plastik", "type": "material", "stack": 30, "color": Color(0.85, 0.88, 0.92)},
	"yaprak": {"name": "Palmiye Yaprağı", "type": "material", "stack": 30, "color": Color(0.35, 0.62, 0.25)},
	"ip": {"name": "İp", "type": "material", "stack": 30, "color": Color(0.78, 0.68, 0.45)},
	"hurda": {"name": "Hurda Metal", "type": "material", "stack": 30, "color": Color(0.55, 0.55, 0.6)},
	"tohum": {"name": "Patates Tohumu", "type": "seed", "stack": 20, "color": Color(0.7, 0.6, 0.35)},
	"domates_tohumu": {"name": "Domates Tohumu", "type": "seed", "stack": 20, "color": Color(0.8, 0.25, 0.2)},
	"biber_tohumu": {"name": "Biber Tohumu", "type": "seed", "stack": 20, "color": Color(0.3, 0.6, 0.25)},
	"karpuz_tohumu": {"name": "Karpuz Tohumu", "type": "seed", "stack": 20, "color": Color(0.2, 0.45, 0.25)},
	"zeytin_fidani": {"name": "Zeytin Fidanı", "type": "seed", "stack": 5, "color": Color(0.5, 0.55, 0.4)},
	"civi": {"name": "Çivi", "type": "material", "stack": 50, "color": Color(0.6, 0.6, 0.62)},
	"kumas": {"name": "Kumaş", "type": "material", "stack": 20, "color": Color(0.85, 0.8, 0.65)},
	"metal_kulce": {"name": "Metal Külçe", "type": "material", "stack": 20, "color": Color(0.7, 0.72, 0.76)},
	"tas": {"name": "Taş", "type": "material", "stack": 30, "color": Color(0.55, 0.54, 0.52)},
	"demir_cevheri": {"name": "Demir Cevheri", "type": "material", "stack": 30, "color": Color(0.55, 0.32, 0.22)},
	"kum": {"name": "Kum", "type": "material", "stack": 30, "color": Color(0.86, 0.78, 0.6)},
	"cam": {"name": "Cam", "type": "material", "stack": 20, "color": Color(0.7, 0.88, 0.95)},
	"zeytin": {"name": "Zeytin", "type": "material", "stack": 40, "color": Color(0.25, 0.25, 0.15)},
	"zeytinyagi": {"name": "Zeytinyağı", "type": "material", "stack": 10, "color": Color(0.8, 0.7, 0.2)},
	"antik_sikke": {"name": "Antik Sikke", "type": "material", "stack": 30, "color": Color(0.85, 0.7, 0.3)},
	"bronz_heykel": {"name": "Bronz Heykel Parçası", "type": "material", "stack": 5, "color": Color(0.3, 0.45, 0.38)},
	"kurdele": {"name": "Dilek Kurdelesi", "type": "material", "stack": 5, "color": Color(0.85, 0.15, 0.12)},
	"inci": {"name": "İnci", "type": "material", "stack": 20, "color": Color(0.95, 0.93, 0.9)},
	"deniz_yosunu": {"name": "Deniz Yosunu", "type": "material", "stack": 30, "color": Color(0.35, 0.5, 0.2)},
	"mercek": {"name": "Fener Merceği", "type": "material", "stack": 5, "color": Color(0.95, 0.88, 0.6)},
	# Yiyecek ve içecek: food = tokluk, water = su
	"hindistan_cevizi": {"name": "Hindistan Cevizi", "type": "food", "stack": 10, "food": 12.0, "water": 18.0, "color": Color(0.5, 0.35, 0.2)},
	"ham_balik": {"name": "Çiğ Balık", "type": "food", "stack": 10, "food": 6.0, "water": -5.0, "cook": "pismis_balik", "color": Color(0.6, 0.7, 0.8)},
	"pismis_balik": {"name": "Pişmiş Balık", "type": "food", "stack": 10, "food": 35.0, "water": 0.0, "color": Color(0.85, 0.6, 0.35)},
	"patates": {"name": "Patates", "type": "food", "stack": 10, "food": 8.0, "water": 0.0, "cook": "pismis_patates", "color": Color(0.75, 0.62, 0.38)},
	"domates": {"name": "Domates", "type": "food", "stack": 10, "food": 7.0, "water": 10.0, "color": Color(0.85, 0.15, 0.1)},
	"biber": {"name": "Biber", "type": "food", "stack": 10, "food": 6.0, "water": 4.0, "color": Color(0.3, 0.6, 0.2)},
	"karpuz": {"name": "Karpuz", "type": "food", "stack": 5, "food": 14.0, "water": 40.0, "color": Color(0.25, 0.55, 0.25)},
	"pismis_patates": {"name": "Fırın Patates", "type": "food", "stack": 10, "food": 25.0, "water": 0.0, "color": Color(0.9, 0.72, 0.4)},
	"konserve": {"name": "Konserve", "type": "food", "stack": 10, "food": 30.0, "water": 5.0, "color": Color(0.7, 0.3, 0.25)},
	"su_sise": {"name": "Su Şişesi", "type": "food", "stack": 10, "food": 0.0, "water": 40.0, "color": Color(0.5, 0.75, 0.95)},
	"temiz_su": {"name": "Temiz Su", "type": "food", "stack": 10, "food": 0.0, "water": 35.0, "color": Color(0.6, 0.85, 1.0)},
	"yengec_eti": {"name": "Yengeç Eti", "type": "food", "stack": 10, "food": 5.0, "water": -3.0, "cook": "pismis_yengec", "color": Color(0.8, 0.45, 0.35)},
	"pismis_yengec": {"name": "Pişmiş Yengeç", "type": "food", "stack": 10, "food": 28.0, "water": 2.0, "color": Color(0.9, 0.35, 0.2)},
	"marti_yumurtasi": {"name": "Martı Yumurtası", "type": "food", "stack": 10, "food": 4.0, "water": 0.0, "cook": "pismis_yumurta", "color": Color(0.9, 0.86, 0.75)},
	"pismis_yumurta": {"name": "Sahanda Yumurta", "type": "food", "stack": 10, "food": 22.0, "water": 0.0, "color": Color(1.0, 0.85, 0.4)},
	"cay": {"name": "Demli Çay", "type": "food", "stack": 10, "food": 4.0, "water": 30.0, "color": Color(0.7, 0.25, 0.1)},
	"istiridye": {"name": "İstiridye", "type": "food", "stack": 10, "food": 9.0, "water": 3.0, "color": Color(0.8, 0.78, 0.75)},
	"balik_corbasi": {"name": "Balık Çorbası", "type": "food", "stack": 5, "food": 55.0, "water": 30.0, "color": Color(0.9, 0.65, 0.35)},
	# Aletler: dur = dayanıklılık (kullanım sayısı)
	"kanca": {"name": "Kanca", "type": "tool", "stack": 1, "dur": 80, "color": Color(0.55, 0.55, 0.6)},
	"cekic": {"name": "Çekiç", "type": "tool", "stack": 1, "dur": 0, "color": Color(0.6, 0.45, 0.3)},
	"mizrak": {"name": "Mızrak", "type": "tool", "stack": 1, "dur": 40, "color": Color(0.7, 0.55, 0.35)},
	"olta": {"name": "Olta", "type": "tool", "stack": 1, "dur": 30, "color": Color(0.65, 0.5, 0.3)},
	"metal_kanca": {"name": "Metal Kanca", "type": "tool", "stack": 1, "dur": 220, "color": Color(0.7, 0.72, 0.78)},
	"metal_mizrak": {"name": "Metal Mızrak", "type": "tool", "stack": 1, "dur": 90, "color": Color(0.65, 0.66, 0.7)},
	"balta": {"name": "Balta", "type": "tool", "stack": 1, "dur": 50, "color": Color(0.6, 0.45, 0.3)},
	"durbun": {"name": "Dürbün", "type": "tool", "stack": 1, "dur": 0, "color": Color(0.3, 0.3, 0.32)},
	"pusula": {"name": "Pusula", "type": "tool", "stack": 1, "color": Color(0.8, 0.62, 0.3)},
	"mesale": {"name": "Meşale", "type": "tool", "stack": 1, "dur": 300, "color": Color(1.0, 0.6, 0.2)},
	"kazma": {"name": "Kazma", "type": "tool", "stack": 1, "dur": 60, "color": Color(0.5, 0.5, 0.55)},
	"nazar": {"name": "Nazar Boncuğu", "type": "place", "stack": 3, "color": Color(0.15, 0.35, 0.8)},
	"dalgic_feneri": {"name": "Dalgıç Feneri", "type": "gear", "slot": "fener", "stack": 1, "color": Color(0.9, 0.85, 0.3)},
	"sonar": {"name": "Sonar", "type": "place", "stack": 2, "color": Color(0.2, 0.6, 0.5)},
	"oksijen_tupu": {"name": "Oksijen Tüpü", "type": "gear", "slot": "tup", "stack": 1, "color": Color(0.95, 0.8, 0.2)},
	"palet": {"name": "Palet", "type": "gear", "slot": "palet", "stack": 1, "color": Color(0.2, 0.5, 0.85)},
	"kopekbaligi_yemi": {"name": "Köpekbalığı Yemi", "type": "tool", "stack": 5, "color": Color(0.7, 0.35, 0.3)},
	"diken_tuzagi": {"name": "Diken Tuzağı", "type": "place", "stack": 4, "color": Color(0.5, 0.4, 0.3)},
	"kedi_yatagi": {"name": "Kedi Yatağı", "type": "place", "stack": 2, "color": Color(0.7, 0.5, 0.3)},
	"dumen": {"name": "Dümen", "type": "place", "stack": 2, "color": Color(0.55, 0.4, 0.25)},
	"motor": {"name": "Motor", "type": "place", "stack": 2, "color": Color(0.35, 0.36, 0.4)},
	"telsiz": {"name": "Telsiz", "type": "place", "stack": 2, "color": Color(0.3, 0.35, 0.3)},
	"tavan_lambasi": {"name": "Tavan Lambası", "type": "roof", "stack": 5, "color": Color(1.0, 0.85, 0.5)},
	# Ev parçaları: envantere girmez, Yapı sekmesinden seçilip çekiçle doğrudan kurulur.
	"p_zemin": {"name": "Zemin", "type": "piece", "stack": 1, "piece": 0, "color": Color(0.62, 0.44, 0.26)},
	"p_duvar": {"name": "Duvar", "type": "piece", "stack": 1, "piece": 1, "color": Color(0.62, 0.44, 0.26)},
	"p_kapi": {"name": "Kapılı Duvar", "type": "piece", "stack": 1, "piece": 2, "color": Color(0.62, 0.44, 0.26)},
	"p_pencere": {"name": "Pencereli Duvar", "type": "piece", "stack": 1, "piece": 3, "color": Color(0.62, 0.44, 0.26)},
	"p_cati": {"name": "Çatı", "type": "piece", "stack": 1, "piece": 4, "color": Color(0.8, 0.7, 0.4)},
	"p_guclendir": {"name": "Zemin Güçlendirme", "type": "piece", "stack": 1, "piece": 5, "color": Color(0.5, 0.5, 0.55)},
	# Yerleştirilebilir yapılar
	"aritici": {"name": "Su Arıtıcı", "type": "place", "stack": 5, "color": Color(0.4, 0.6, 0.85)},
	"izgara": {"name": "Izgara", "type": "place", "stack": 5, "color": Color(0.75, 0.35, 0.2)},
	"sandik": {"name": "Depo Sandığı", "type": "place", "stack": 5, "color": Color(0.55, 0.4, 0.25)},
	"saksi": {"name": "Ekim Saksısı", "type": "place", "stack": 5, "color": Color(0.45, 0.35, 0.25)},
	"yatak": {"name": "Yatak", "type": "place", "stack": 2, "color": Color(0.7, 0.65, 0.5)},
	"sandalye": {"name": "Sandalye", "type": "place", "stack": 4, "color": Color(0.6, 0.45, 0.3)},
	"masa": {"name": "Masa", "type": "place", "stack": 2, "color": Color(0.55, 0.4, 0.28)},
	"hali": {"name": "Halı", "type": "place", "stack": 4, "color": Color(0.7, 0.35, 0.25)},
	"yelken": {"name": "Yelken", "type": "place", "stack": 2, "color": Color(0.9, 0.88, 0.8)},
	"capa": {"name": "Çapa", "type": "place", "stack": 2, "color": Color(0.4, 0.42, 0.45)},
	"ocak": {"name": "Eritme Ocağı", "type": "place", "stack": 2, "color": Color(0.5, 0.35, 0.3)},
	"yagmur_toplayici": {"name": "Yağmur Toplayıcı", "type": "place", "stack": 3, "color": Color(0.35, 0.55, 0.8)},
	"fener": {"name": "Fener", "type": "place", "stack": 5, "color": Color(1.0, 0.8, 0.4)},
	"toplayici": {"name": "Ağ", "type": "place", "stack": 4, "color": Color(0.85, 0.82, 0.7)},
}

## Eşya açıklamaları (envanter ve üretim ekranında gösterilir).
const DESC := {
	"tas": "Kayalık adalarda kazmayla kırılır. Fenerlerin yıkık duvarlarını örmekte kullanılır.",
	"demir_cevheri": "Pas renkli kayalardan çıkar. Eritme Ocağında metal külçeye döner.",
	"kum": "Adaların kumsalındaki yığınlardan alınır. Eritme Ocağında cama döner.",
	"cam": "Eritme Ocağında kumdan dökülür. Fener odası ve fener merceği için.",
	"zeytin": "Zeytinlik adalardaki ağaçlardan toplanır. Sıkılınca zeytinyağı olur.",
	"zeytinyagi": "Fenerlerin kandil yakıtı; motor da onunla uzun çalışır.",
	"mercek": "Camdan ve metalden yapılan fener merceği. Işığı denize uzanan bir huzmeye çevirir.",
	"yengec_eti": "Kumsalda yakalanan yengeçten. Izgarada pişir.",
	"pismis_yengec": "Izgarada pişmiş yengeç. Doyurucu.",
	"marti_yumurtasi": "Martı yuvasından. Izgarada sahanda yumurta olur.",
	"pismis_yumurta": "Sahanda yumurta.",
	"kazma": "Kayaları kırar (sol tık): taş ve demir cevheri verir.",
	"nazar": "Rıza Kaptan'dan. Sala dikilen direğe asılır; köpekbalığı salı daha seyrek ısırır. Nazar değmesin!",
	"cay": "İnce belli bardakta tavşan kanı çay. Rıza Kaptan'ın teknesinden; susuzluğu giderir.",
	"antik_sikke": "Batık antik gemilerden çıkan gümüş sikkeler. Rıza Kaptan antika sever: iyi takas eder.",
	"bronz_heykel": "Yosun tutmuş bronz bir büst parçası. Çok değerli; Rıza Kaptan karşılığında nadir eşyalar verir.",
	"dalgic_feneri": "Elde tutup sol tıkla kuşan (dalış takımı). Su altında ve gece önünü aydınlatır; derin batıklarda gerekli.",
	"sonar": "Sala kurulur. Ara ara ses dalgası yollar: 250 m içindeki batıkları bulur, haritada gösterir. E ile en yakın batığa hedef koyar. Batıklar 12-20 m derindedir; çapa atıp dal.",
	"kurdele": "Bir parça kumaş, bir parça ip. Hıdırellez gecesi dileğini dilek ağacının dalına bağlarsın.",
	"inci": "İstiridyelerden ve batık sandıklardan çıkar. Rıza Kaptan incinin hasını tanır, iyi takas eder.",
	"deniz_yosunu": "Resifteki yosun tarlalarından toplanır. Ondan da ip örülür.",
	"istiridye": "Deniz tabanından. Açınca bazen içinden inci çıkar; eti çiğ yenir.",
	"oksijen_tupu": "Elde tutup sol tıkla kuşan. Dalarken önce tüpteki hava harcanır (yaklaşık 80 sn); yüzeyde kendiliğinden dolar.",
	"palet": "Elde tutup sol tıkla kuşan. Suda çok daha hızlı yüzer, daha çabuk dalarsın.",
	"kopekbaligi_yemi": "Sol tıkla denize fırlat. Köpekbalığı yarım dakika kadar yemle uğraşır; salı ve seni unutur.",
	"diken_tuzagi": "Salın kenarına kurulur. Kendi karosunu ve yanındakileri korur: ısırmaya gelen köpekbalığı dikenlere çarpar. 3 çarpmada körelir.",
	"kedi_yatagi": "Hasır sepet ve yumuşak minder. Kedin geceleri burada uyur.",
	"dumen": "Sala kurulur. E ile başına geç; A/D ile rota çizersin. Açık yelkenler ve motor rotaya göre çalışır.",
	"motor": "Sala kurulur. E ile yakıt koy (tahta ya da zeytinyağı) ve çalıştır; rüzgârsız da yol alırsın.",
	"telsiz": "Sala kurulur. E ile dinle: en yakın sönmüş fenerin sinyalini yakalar, haritada ve ekranda hedef işaretler.",
	"p_zemin": "Salı büyütür. Çekiçle salın kenarındaki suya bakıp sol tık.",
	"p_duvar": "Evin duvarı. Çekiçle bir karonun kenarına bakıp sol tık; duvar o kenara oturur.",
	"p_kapi": "İçinden geçilebilen kapı boşluklu duvar. Evin girişi için.",
	"p_pencere": "Ortasında pencere boşluğu olan duvar. İçerisi aydınlık kalır.",
	"p_guclendir": "Var olan bir zemini metal çerçeve ve perçinlerle güçlendirir. Köpekbalığı güçlendirilmiş zemini kıramaz. Çekiçle zemine bakıp sol tık.",
	"p_cati": "Karonun üstünü kapatır. Altında yağmur yağmaz; yağmurda uyumak için yatağın üstünde çatı olmalı.",
	"tahta": "Temel yapı malzemesi. Kancayla denizden toplanır. Arıtıcı ve ızgaranın yakıtıdır.",
	"plastik": "Su geçirmez parçalar. Zemin ve su arıtıcı için gerekir.",
	"yaprak": "Palmiye yaprağı. Üretim ekranında ipe dönüştürülür.",
	"ip": "2 palmiye yaprağından örülür. Aletlerin ve yapıların çoğunda kullanılır.",
	"hurda": "Metal parça. Varillerden ve ada çevresindeki deniz tabanından (dalarak) çıkar.",
	"tohum": "Ekim saksısına ekilir; büyüyünce patates verir. Hasatta tohum da çıkar.",
	"domates_tohumu": "Saksıda sırığa sarılan domates yetişir. Hasatta tohum da çıkar.",
	"biber_tohumu": "Saksıda kırmızı ve yeşil biber verir. Hasatta tohum da çıkar.",
	"karpuz_tohumu": "Saksıda yavaş büyür; koca bir karpuz susuzluğu giderir. Hasatta tohum da çıkar.",
	"zeytin_fidani": "Saksıya dikilir; büyüyünce her hasatta zeytin verir ve yeniden meyveye durur.",
	"domates": "Saksıda yetişir. Hem doyurur hem susuzluğu biraz giderir.",
	"biber": "Saksıda yetişir.",
	"karpuz": "Saksıda yetişir. Susuzluğu çok giderir.",
	"hindistan_cevizi": "Adalarda ağaç altında bulunur. Hem tok tutar hem susuzluğu giderir.",
	"ham_balik": "Oltayla tutulur. Çiğ yemek pek iyi değil: ızgarada pişir.",
	"pismis_balik": "Izgarada pişmiş balık. Çok doyurucu.",
	"patates": "Saksıda yetişir. Izgarada pişirince daha doyurucu.",
	"pismis_patates": "Izgarada pişmiş patates.",
	"konserve": "Varillerden çıkar. Doyurucu hazır yiyecek.",
	"su_sise": "Varillerden çıkar. İçilebilir temiz su.",
	"temiz_su": "Su arıtıcıdan alınır. Susuzluğu giderir.",
	"kanca": "Sol tık basılı tut, bırakınca fırlat. Suda sol tıkla çek, yolundaki enkaza takılır.",
	"cekic": "Sala zemin ekler (sol tık), hasarlı karoyu onarır (E), yapı ve karo söker (R).",
	"mizrak": "Köpekbalığını kovalamak için. 3 isabette köpekbalığı kaçar.",
	"olta": "Sol tıkla at. Şamandıra batınca hemen sol tıkla çek.",
	"aritici": "Sala kurulur. 1 tahta yakıtla 20 saniyede 1 temiz su üretir.",
	"izgara": "Sala kurulur. Çiğ balık ve patatesi 1 tahta yakıtla pişirir.",
	"sandik": "Sandıklar üst üste konabilir (6 kat). Türünü seç (Malzeme, Yiyecek, Tohum, Alet, Yapı ya da Karışık); Q ile türüne uyan eşyaları hızlıca koy. Sala kurulur. 20 yuvalık depo.",
	"saksi": "Sala kurulur. Elindeki ya da çantandaki tohumu eker (patates, domates, biber, karpuz, zeytin fidanı); yağmurda daha hızlı büyür.",
	"sandalye": "Dekor. Sala kurulur (R ile döndür); E ile oturursun, E ya da Boşluk ile kalkarsın.",
	"masa": "Dekor. Üstünde bir kupa ve harita durur. Sala kurulur (R ile döndür).",
	"hali": "Dekor. Türk kilimi motifli (elibelinde, koçboynuzu, göz, su yolu) iki karo boyunda halı. R ile yönünü çevir; zemine serilir, üstünden yürünür.",
	"yatak": "Gece uyuyup sabaha atlarsın. Doğma noktası olur ve oyunu kaydeder.",
	"yelken": "Açınca salı baktığın yöne götürür. Adalara ulaşmak için.",
	"capa": "Atınca sal durur. Adada ya da balık tutarken kullan.",
	"civi": "1 hurda metalden 4 çivi dövülür. Sağlam yapılar ve aletler için.",
	"kumas": "Palmiye yaprakları ve ipten dokunur. Yelken ve yatak için daha iyi malzeme.",
	"metal_kulce": "Eritme ocağında hurda metalden dökülür. Metal aletlerin ana malzemesi.",
	"balik_corbasi": "Pişmiş balık, patates ve temiz sudan. Hem çok doyurur hem susuzluğu giderir.",
	"metal_kanca": "Çok daha dayanıklı ve daha hızlı çeker. 4 çatalı enkazı daha geniş alandan yakalar.",
	"metal_mizrak": "Her isabet köpekbalığına 2 kat hasar verir; 2 vuruşta kaçırır.",
	"balta": "Adalardaki ağaçları keser (sol tık). Her ağaç tahta ve yaprak verir.",
	"durbun": "Sol tıkla yakınlaştır. Uzaktaki adaları ve varilleri görmek için.",
	"ocak": "Sala kurulur. 2 hurda + 1 tahta yakıtla 25 saniyede 1 metal külçe döker.",
	"yagmur_toplayici": "Sala kurulur. Yağmur yağarken kendiliğinden temiz su biriktirir (en fazla 3).",
	"fener": "Sala kurulur. Gece kendiliğinden yanar; E ile açıp kapatılır.",
	"pusula": "Elde tutunca baktığın yönü, esen rüzgârın adını ve yelkenin verimini gösterir. İğnesi hep kuzeyi gösterir.",
	"mesale": "Elinde tutarken etrafını aydınlatır. Yaktıkça tükenir (yaklaşık 5 dakika).",
	"tavan_lambasi": "Bir çatının altına asılır (çatıya bakarak sol tık). Gece ve yağmurda kendiliğinden yanar.",
	"toplayici": "Sala kurulur (R ile döndür). Yanından geçen tahta, plastik, yaprak ve varilleri yakalar. Yakaladıkları ağın üstünde görünür; E ile al.",
}

## Çekiçle inşa edilen zemin.
const FOUNDATION_COST := {"tahta": 1, "plastik": 1}
## Çekiçle inşa edilen yapı parçaları (Yapı sekmesinden seçilir): [kimlik, ad, maliyet]
const PIECES := [
	["zemin", "Zemin", {"tahta": 1, "plastik": 1}],
	["duvar", "Duvar", {"tahta": 2}],
	["kapi", "Kapılı Duvar", {"tahta": 2, "ip": 1}],
	["pencere", "Pencereli Duvar", {"tahta": 2, "plastik": 1}],
	["cati", "Çatı", {"tahta": 2, "yaprak": 3}],
	["guclendir", "Zemin Güçlendirme", {"hurda": 1, "tahta": 1}],
]
const REPAIR_COST := {"tahta": 1}

const CATEGORIES := ["Malzeme", "Araç", "Yiyecek", "Yapı", "Gelişmiş"]

const RECIPES := [
	{"cat": "Malzeme", "out": "ip", "n": 1, "cost": {"yaprak": 2}},
	{"cat": "Araç", "out": "kanca", "n": 1, "cost": {"tahta": 2, "plastik": 4, "ip": 2}},
	{"cat": "Araç", "out": "mizrak", "n": 1, "cost": {"tahta": 4, "ip": 2, "hurda": 1}},
	{"cat": "Araç", "out": "olta", "n": 1, "cost": {"tahta": 4, "ip": 4, "hurda": 1}},
	{"cat": "Yiyecek", "out": "aritici", "n": 1, "cost": {"tahta": 4, "plastik": 6, "ip": 2}},
	{"cat": "Yiyecek", "out": "izgara", "n": 1, "cost": {"tahta": 6, "plastik": 2, "hurda": 2}},
	{"cat": "Yiyecek", "out": "saksi", "n": 1, "cost": {"tahta": 4, "plastik": 4}},
	{"cat": "Yapı", "out": "p_zemin", "n": 1, "cost": PIECES[0][2]},
	{"cat": "Yapı", "out": "p_duvar", "n": 1, "cost": PIECES[1][2]},
	{"cat": "Yapı", "out": "p_kapi", "n": 1, "cost": PIECES[2][2]},
	{"cat": "Yapı", "out": "p_pencere", "n": 1, "cost": PIECES[3][2]},
	{"cat": "Yapı", "out": "p_cati", "n": 1, "cost": PIECES[4][2]},
	{"cat": "Yapı", "out": "p_guclendir", "n": 1, "cost": PIECES[5][2]},
	{"cat": "Yapı", "out": "sandik", "n": 1, "cost": {"tahta": 6, "ip": 2}},
	{"cat": "Yapı", "out": "yatak", "n": 1, "cost": {"tahta": 8, "kumas": 2, "ip": 2}},
	{"cat": "Yapı", "out": "sandalye", "n": 1, "cost": {"tahta": 4, "civi": 2}},
	{"cat": "Yapı", "out": "masa", "n": 1, "cost": {"tahta": 6, "civi": 4}},
	{"cat": "Yapı", "out": "hali", "n": 1, "cost": {"kumas": 3, "ip": 2}},
	{"cat": "Yapı", "out": "yelken", "n": 1, "cost": {"tahta": 8, "kumas": 4, "ip": 4}},
	{"cat": "Yapı", "out": "capa", "n": 1, "cost": {"tahta": 2, "hurda": 4, "ip": 4}},
	{"cat": "Malzeme", "out": "civi", "n": 4, "cost": {"hurda": 1}},
	{"cat": "Malzeme", "out": "kumas", "n": 1, "cost": {"yaprak": 4, "ip": 1}},
	{"cat": "Araç", "out": "balta", "n": 1, "cost": {"tahta": 3, "ip": 2, "hurda": 2}},
	{"cat": "Yiyecek", "out": "balik_corbasi", "n": 1, "cost": {"pismis_balik": 1, "patates": 1, "temiz_su": 1}},
	{"cat": "Yiyecek", "out": "yagmur_toplayici", "n": 1, "cost": {"tahta": 4, "plastik": 4, "kumas": 1}},
	{"cat": "Yapı", "out": "fener", "n": 1, "cost": {"tahta": 2, "civi": 2, "plastik": 1}},
	{"cat": "Yapı", "out": "tavan_lambasi", "n": 1, "cost": {"tahta": 1, "civi": 2, "plastik": 1}},
	{"cat": "Araç", "out": "pusula", "n": 1, "cost": {"hurda": 1, "plastik": 1, "ip": 1}},
	{"cat": "Araç", "out": "mesale", "n": 1, "cost": {"tahta": 1, "yaprak": 2, "ip": 1}},
	{"cat": "Gelişmiş", "out": "ocak", "n": 1, "cost": {"tahta": 6, "hurda": 4, "civi": 4}},
	{"cat": "Gelişmiş", "out": "toplayici", "n": 1, "cost": {"tahta": 6, "ip": 6, "plastik": 2, "civi": 4}},
	{"cat": "Gelişmiş", "out": "metal_kanca", "n": 1, "cost": {"metal_kulce": 2, "ip": 2, "tahta": 2}},
	{"cat": "Gelişmiş", "out": "metal_mizrak", "n": 1, "cost": {"metal_kulce": 2, "tahta": 4, "ip": 2}},
	{"cat": "Araç", "out": "kazma", "n": 1, "cost": {"tahta": 3, "ip": 2, "hurda": 3}},
	{"cat": "Malzeme", "out": "zeytinyagi", "n": 1, "cost": {"zeytin": 5}},
	{"cat": "Yapı", "out": "kedi_yatagi", "n": 1, "cost": {"yaprak": 6, "kumas": 1, "ip": 2}},
	{"cat": "Gelişmiş", "out": "mercek", "n": 1, "cost": {"cam": 2, "metal_kulce": 1}},
	{"cat": "Gelişmiş", "out": "telsiz", "n": 1, "cost": {"metal_kulce": 2, "cam": 1, "hurda": 3, "ip": 2}},
	{"cat": "Gelişmiş", "out": "dumen", "n": 1, "cost": {"tahta": 8, "ip": 4, "civi": 4}},
	{"cat": "Gelişmiş", "out": "motor", "n": 1, "cost": {"metal_kulce": 4, "hurda": 6, "civi": 6, "ip": 2}},
	{"cat": "Malzeme", "out": "ip", "n": 1, "cost": {"deniz_yosunu": 3}},
	{"cat": "Malzeme", "out": "kurdele", "n": 1, "cost": {"kumas": 1, "ip": 1}},
	{"cat": "Gelişmiş", "out": "oksijen_tupu", "n": 1, "cost": {"metal_kulce": 3, "plastik": 2, "ip": 2, "civi": 2}},
	{"cat": "Araç", "out": "palet", "n": 1, "cost": {"plastik": 4, "ip": 2, "deniz_yosunu": 2}},
	{"cat": "Araç", "out": "kopekbaligi_yemi", "n": 2, "cost": {"ham_balik": 2, "ip": 1}},
	{"cat": "Yapı", "out": "diken_tuzagi", "n": 1, "cost": {"tahta": 4, "civi": 6, "metal_kulce": 1}},
	{"cat": "Gelişmiş", "out": "sonar", "n": 1, "cost": {"metal_kulce": 3, "cam": 2, "hurda": 4, "civi": 4}},
	{"cat": "Gelişmiş", "out": "dalgic_feneri", "n": 1, "cost": {"cam": 1, "metal_kulce": 2, "plastik": 2}},
	{"cat": "Gelişmiş", "out": "durbun", "n": 1, "cost": {"metal_kulce": 1, "plastik": 2, "civi": 2}},
]

const BARREL_LOOT := ["tahta", "tahta", "plastik", "plastik", "yaprak", "hurda", "hurda", "konserve", "su_sise", "tohum", "ham_balik",
	"domates_tohumu", "biber_tohumu", "karpuz_tohumu"]


static func info(id: String) -> Dictionary:
	return ITEMS.get(id, {"name": id, "type": "material", "stack": 30, "color": Color.WHITE})


static func name_of(id: String) -> String:
	return info(id)["name"]


static func desc_of(id: String) -> String:
	return DESC.get(id, "")


## Eksik malzemeler: {id: eksik adet}
static func missing(inv, cost: Dictionary) -> Dictionary:
	var out := {}
	for k in cost:
		var have: int = inv.count(k)
		if have < cost[k]:
			out[k] = cost[k] - have
	return out


static func cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for k in cost:
		parts.append("%d %s" % [cost[k], name_of(k)])
	return ", ".join(parts)
