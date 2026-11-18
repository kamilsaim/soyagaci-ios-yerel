# Soy Ağacı iOS — yerel SwiftUI uygulaması (tasarım)

Tarih: 18 Kasım 2026 · Yazan: Claude (Kamil ile)

## 1. Amaç ve neden
Soy Ağacı'nın iPhone sürümünü App Store'a çıkarmak. Web (`soy-agaci.html` v7.0.0) ve Android (Capacitor, `C:\apk\soyagaci-yerel`)
hazır; iOS yok (daha önce hiç iOS derlemesi yapılmadı). Kamil'in diğer uygulamalarında (Türbedar, Bal Defterim, Borç Defteri,
KümesPro, Bereket) Capacitor kabuğu 4.2/4.3 reddi riski taşıdığı için yerel SwiftUI'ye geçildi; Soy Ağacı da doğrudan yerel yapılır.
Aile bireyleri aynı Google hesaplarıyla web/Android/iPhone'dan **aynı veriyi** görmeli.

## 2. Hedefler
- **İlk sürüm web v7'deki her özelliği içerir** (Kamil kararı): giriş + eşitleme, ana sayfa, kişi listesi (filtre/arama/toplu silme),
  kişi kartı (bilgi/aile/foto/not sekmeleri, akrabalık satırı, "Ağaçta"), kişi formu (çoklu eş, çocuklar, satır içi ekleme, iptalde geri alma,
  soy döngüsü koruması), fotoğraf + galeri (Supabase Storage), ağaç (Odak + Tüm Ağaç, kuşak sayısı, arama, geri, sürükleyerek kaydırma,
  soy vurgusu, animasyon), ekleme paneli (yakına bağlı ekleme), akrabalık hesaplayıcı + "Ben kimim?", mükerrer bulucu + birleştirme,
  hatırlatmalar (ayarlar, 14 günlük bant, ay takvimi, açılış uyarısı, **yerel bildirim**), istatistik + doğum haritası,
  GED içe aktarma (değiştir / ağaca ekle + birleştirme önizlemesi), JSON yedek geri yükleme, GED/JSON dışa aktarma,
  e-Devlet aktarma (PDF + yapıştırılan metin), ağaç PNG + yazdırma, örnek aile, tümünü sil, eksik bilgi paneli, Bilgi sayfası.
- Görünüm v7 tasarımı: kâğıt/parşömen dokusu, Playfair Display başlık + Source Sans 3 gövde, `assets/ikon/*` ikonları, altın vurgu.
- Web ile **veri biçimi birebir uyumlu**; iPhone'un yazdığı veriyi web/Android okur, tersi de.

## 3. Hedef olmayanlar / kaçınılacaklar
- Web'e veya Android'e dokunmak (yalnız gerekirse küçük uyum düzeltmesi, ayrıca sorulur).
- Web Push / APNs (hatırlatmalar tarih bazlı → yerel bildirim yeterli).
- Widget, iPad düzeni, Mac Catalyst (sonraki sürüm).
- **Anti-hedef:** iPhone'un kaydı web'in alanlarını düşürmesi, eş/çocuk bağlantılarını bozması, başka cihazın değişikliğini sessizce ezmesi.
  Bu olursa uygulama "çalışsa da" başarısızdır.

## 4. Kısıtlar
- Mac yok: derleme/imza/TestFlight GitHub Actions bulut Mac'inde (`C:\mac\IOS-BULUT-DERLEME-REHBERI.md`). Kod cihazda adım adım
  hata ayıklanamaz → mantık Linux'ta test edilen paket, Swift 5 dil kipi, uzun ifadelerden kaçın, derlemeden önce bağımsız inceleme.
- Supabase projesi `mtialokiudmgdctznfiz` (Kentsel ve Patika ile paylaşılıyor; ikisinde Apple girişi yok). Tablolar `soy_family_data`
  (`user_id, people jsonb, next_id, updated_at`; `fams` NOT NULL varsayılanlı, yazılmaz), `soy_node_positions` (`user_id, positions`),
  kova `soy-fotograf` (`{uid}/{uid32}.jpg`). RLS `auth.uid() = user_id`.
- App Store 4.8: Google girişi var → **Apple ile Giriş zorunlu**. 5.1.1(v): **uygulama içinden hesap silme zorunlu** (+ Apple jeton iptali).
- Kamil Chrome'un açılmasını istemiyor (jeton maliyeti) → portal/panel adımlarını Kamil yapar, Claude değerleri ve komutları hazırlar.

## 5. Yaklaşımlar
| Yaklaşım | Artı | Eksi | Karar |
|---|---|---|---|
| **Yerel SwiftUI + ayrı test edilen çekirdek paket** (Bereket/Borç Defteri düzeni) | 4.2/4.3 riski en düşük; düzen 5 uygulamada denendi; mantık Linux'ta testli | En çok iş: 236 web fonksiyonunun mantığı Swift'e | **Seçildi** (Kamil) |
| Capacitor, aynı `index.html` + `assets/` paket içinde | Hızlı, Android ile aynı kod | "Web sarmalayıcı" reddi riski; Kamil'in diğer uygulamaları bu yüzden yerel'e geçti | Elendi |
| Yarı yerel (SwiftUI kabuk + ağacı WKWebView'de çiz) | Ağaç motoru yeniden yazılmaz | İki dünya arası köprü, yine 4.2 riski, tutarsız görünüm | Elendi |

## 6. Kararlaştırılanlar (Kamil)
- Tam SwiftUI, sıfırdan; klasör `soyagaci/ios-yerel`, gizli depo `kamilsaim/soyagaci-ios-yerel`.
- İlk sürüm her özelliği içerir.
- Chrome açılmaz; Kamil'in yapacakları listelenir.
- Kolay alt işler Sonnet alt ajanlarına verilebilir.

## 7. Yapı (Claude'un önerisi — Bereket/Borç Defteri ile aynı)
```
soyagaci/ios-yerel/
  project.yml                 XcodeGen (bundle com.kamilsaim.soyagaci, iOS 17, yalnız iPhone, dikey)
  Paketler/SoyCekirdek/       yalnız Foundation, Linux'ta `swift test`
  SoyAgaci/                   SwiftUI uygulaması (Kabuk, Ekranlar, Formlar, Agac, Veri, Tema, Kaynaklar, Assets.xcassets)
  fastlane/Fastfile, Gemfile
  .github/workflows/cekirdek-test.yml, ios-testflight.yml
  arac/fixture-uret.mjs       web fonksiyonlarını Node'da çalıştırıp eşlik verisi üretir
  supabase/                   hesap-sil + apple-jeton Edge Function, gerekli SQL (panelden yapıştırılır)
  README.md
```
Bağımlılıklar: `supabase-swift` 2.x, `GoogleSignIn-iOS` 9.x. Başka yok (harita MapKit, PDF PDFKit, yazdırma UIKit, bildirim UserNotifications).

### 7.1 Çekirdek (`SoyCekirdek`) — web'den birebir taşınan mantık
| Modül | Web karşılığı |
|---|---|
| `JSON` (ham değer) + `Kisi` görünümü | `people` nesneleri; **bilinmeyen alanlar korunur**, yalnız dokunulan anahtarlar değişir (Bereket dersi) |
| `Tarih` | `normDate`, `toGedDate`, `yearOf`, `fmtDate`, `dateParts`, `isPlaceholder` |
| `Veri` | `migrateData`, `newId`, `isAncestorOf`, `isDead`, `pname`, `initials`, `capStr` (tr-TR elle), `savePerson`/`delP` bağlantı kuralları |
| `Gedcom` | `splitGedName`, `parseGED`, `expGED`, `matchImported`, `applyImported`, `gedSum` |
| `Akrabalik` | `bloodLink`, `bloodWords`, `kinship`, `kinPhrase`, `kinSentence`, `genOf` |
| `Mukerrer` | `findDupes`, `mergePeople`, `notDupSet` |
| `Olaylar` | `eventsBetween`, `upcomingEvents`, `notificationPlan` (iOS: en yakın 60) |
| `Yerlesim` | `buildFamilies`, `placeSub`, `assignGenerations`, `layoutFull`, `layoutFocus`, `lineageOf`, `normDrag` (düğüm `NW=118,NH=128`) |
| `Istatistik` | `renderStats` hesapları, `genDepth` |
| `EDevlet` | `tableToGrid`, `textToGrid`, `gridToPersons`, `relTokens`, `analyze`, `pdfItemsToGrid` (girdi: konumlu metin parçaları), `buildGedcom` |
| `Esitleme` | `load()` kuralları: `dirty`/`base`, çakışma tespiti (`_serverTs`), "bulut okunamazsa yerel itilmez" |

**Eşlik testi:** `arac/fixture-uret.mjs` web dosyasından fonksiyonları adıyla ayıklar (DOM taklidiyle), gerçek veriler
(`soy-agaci.json` 147 kişi, `heritage.ged`, `saim-soy.ged`, `edevlet-soy-Mustafa.ged`, e-Devlet PDF/metin örnekleri) ve rastgele
senaryolarla beklenen çıktıları JSON'a yazar; Swift testleri birebir eşitliği kontrol eder (yerleşim koordinatları, akrabalık cümleleri,
GED gidiş-dönüş, birleştirme eşleşmeleri, olay listesi). Web değişince fixture yeniden üretilir.

### 7.2 Uygulama
- **Kabuk:** alt çubuk Ana Sayfa / Ağaç / ＋ / Kişiler / Aktar; başlıkta ⚙ Ayarlar ve ☰ Bilgi (web v7 ile aynı). Tek `NavigationPath` + enum rota.
- **Giriş:** Google yerel (GoogleSignIn → `signInWithIdToken`, kimlik yoksa/hata olursa tarayıcı OAuth'a düşer, şema
  `com.kamilsaim.soyagaci://auth-callback` + PKCE), Apple yerel (`ASAuthorization` → `signInWithIdToken(apple, nonce)`), ve
  **girişsiz yerel mod** (web'deki `useLocally`; veri cihazda dosyada). Gizli Apple e-postası "Gizli (Apple ile giriş)" yazılır.
- **Eşitleme:** web ile aynı kurallar; 800 ms toplayıp `upsert` (`returning: minimal`), sıralı kuyruk; başka cihaz arada yazdıysa sorar.
  Açılışta bulut okunmadan yazma yok. Konumlar `soy_node_positions`'a aynı biçimle (`$v:2`).
- **Fotoğraf:** `PhotosPicker` → 1400 px / JPEG 0.82 → `soy-fotograf/{uid}/{uid32}.jpg`; toplu imzalı bağlantı (100'lük, 1 saat, 50 dk'da
  tazele); eski base64 fotoğraflar gösterilir; kullanılmayanlar silinir (`purgePhotos` kuralı). Yerel modda foto cihazda.
- **Ağaç:** SwiftUI `Canvas` + yakınlaştırma/kaydırma, yerleşim çekirdekten; dokunma kuralları web'deki gibi (Odak: dokun = o kişiye geç,
  ortadakine/uzun bas = kart; Tüm Ağaç: dokun = kart, uzun bas = sürükle). Kart görünümü v7 dikey düğüm.
- **e-Devlet:** PDF (`fileImporter` → PDFKit sayfa metni + karakter konumları → `pdfItemsToGrid`), yapıştırma (düz metin `textToGrid`,
  HTML varsa `tableToGrid`) → `buildGedcom` → GED birleştirme önizlemesi.
- **Dışa aktarma / yazdırma:** GED/JSON/PNG `ShareLink` / paylaşım sayfası ("Dosyalar'a Kaydet"); yazdırma `UIPrintInteractionController`.
- **Harita:** MapKit + `CLGeocoder` (Nominatim yerine; önbellek cihazda).
- **Bildirim:** izin yalnız kullanıcı Ayarlar'da açınca istenir; açılışta ve veri değişince en yakın 60 bildirim yeniden kurulur.
- **Hesap silme:** Ayarlar → onay → Edge Function `hesap-sil` (satırlar + foto klasörü + kullanıcı + Apple jeton iptali; Sinerji/KümesPro şablonu).

### 7.3 Derleme
- Sürüm **7.0**, derleme no `100 + çalıştırma×10 + deneme` (Bereket kuralı). Push'ta `cekirdek-test` (Linux), TestFlight yalnız Kamil onayıyla
  `gh workflow run ios-testflight.yml -R kamilsaim/soyagaci-ios-yerel -f surum=7.0`.
- İlk derlemeden önce bağımsız kod incelemesi (KümesPro dersi).

## 8. Kamil'in yapacakları (Chrome'u Claude açmaz)
0. **Tamamlanan (18 Kas):** SIWA anahtarı "Soy Agaci SIWA" Key ID `W8295F83ZM` (`C:/apk/apple-anahtar/soyagaci/`), App Store Connect Apple ID `6836204652`, SKU `soyagaci`.
1. **Apple Developer → Identifiers:** App ID `com.kamilsaim.soyagaci` (Explicit), yetenek: **Sign In with Apple**. (Fastfile API anahtarıyla
   açmayı da dener; olmazsa elle.)
2. **Apple Developer → Keys → +:** "Soy Agaci SIWA" (Türkçe karakter yok), Sign in with Apple → Configure → primary App ID
   `com.kamilsaim.soyagaci` → Register → **.p8'i indir** → `C:\apk\apple-anahtar\soyagaci\` + Key ID'yi not et. (Yalnız bir kez inebilir.)
3. **App Store Connect → Uygulamalar → +:** iOS, ad "Soy Ağacı" (doluysa "Soy Ağacı: Aile Ağacım"), Türkçe, bundle `com.kamilsaim.soyagaci`,
   SKU `soyagaci`. Çıkan Apple ID'yi bildir.
4. **Google Cloud (Supabase'in Google Web istemcisinin projesi) → Credentials → Create OAuth client → iOS:** bundle `com.kamilsaim.soyagaci`,
   Team ID `NBTXFU47EV` → **iOS Client ID'yi bildir**. (Web istemcisi aynı projede değilse orada yeni Web istemcisi açılır — rehber 2.1.)
5. **Supabase (mtialokiudmgdctznfiz) → Authentication → Providers:**
   - Google → Authorized Client IDs'e Web + iOS istemci kimlikleri (virgülle).
   - Apple → Enable, Client IDs `com.kamilsaim.soyagaci` (yerel giriş için Secret gerekmez).
   - URL Configuration → Redirect URLs'te `com.kamilsaim.soyagaci://auth-callback` (Android'de eklendiyse zaten var).
6. **Supabase Edge Function secrets:** `SIWA_KEY_P8` (p8 base64 — Claude yerel betikle üretir, Kamil yapıştırır), `SIWA_KEY_ID`, `APPLE_TEAM_ID`.
   `hesap-sil`/`apple-jeton` fonksiyonları MCP ile yüklenemezse panelden yapıştırılır.
7. **GitHub:** Claude'un hazırladığı `! gh repo create …` ve `! gh secret set …` komutlarını çalıştırmak (ASC API anahtarı ve dağıtım
   sertifikası mevcut olanlar: `C:\apk\apple-anahtar\asc-api`, `dagitim-sertifikasi`).
8. **Gizlilik:** App Privacy etiketleri (ad, doğum tarihi/yeri, fotoğraf, e-posta — uygulama işlevi, kimliğe bağlı, izleme yok) ve gizlilik
   politikası adresi; Claude metni hazırlar.
9. TestFlight'tan iPhone'da deneme ve geri bildirim.

## 9. Değerlendirme sonrası netleşenler (Claude'un kararları — Kamil düzeltebilir)
- **Yerel mod ↔ giriş:** web'deki gibi iki ayrı depo: yerel mod verisi (`sa4_local` karşılığı) ile hesabın bulut kopyası (`sa4` karşılığı)
  birbirine karışmaz; girişte yerel veri otomatik yüklenmez (web de yüklemiyor). Çıkış web `signOut` gibi: bekleyen kaydı gönderir,
  buluta gitmemiş değişiklik varsa sorar, hesabın yerel kopyasını siler. `load()` kuralları birebir taşınır ve test edilir.
- **Eşlik kaynağı:** web v7.0.0 (`soy-agaci.html`, 18 Kas 2026) `arac/kaynak/`'a kopyalanıp sabitlenir; fixture'lar bu kopyadan, Node + DOM
  taklidiyle (v5–v6 testleri gibi) üretilir. Web değişirse kopya bilerek yenilenir.
- **PDF:** iOS'ta PDFKit satır/kelime parçaları pdf.js `items` biçimine (`{str, x, y, w}`) çevrilip aynı `pdfItemsToGrid`'e verilir.
  Test ölçütü ham ızgara değil sonuç: aynı PDF'ten aynı kişiler + aynı bağlar (`kamilsoyagaci` 22 kişi örneği). Web'e dokunulmaz.
- **Apple girişi ayrı hesaptır:** "E-postamı gizle" ile giren kişinin Google'daki ağacı gelmez (Supabase ayrı kullanıcı açar). Giriş ekranında
  Google üstte, Apple altında; Apple düğmesinin altında kısa not: "Web/Android'de Google ile kullandıysanız Google ile girin." Hesap birleştirme yok.
- **Hesap silme:** iki onay + önce "JSON yedeğini indir" önerisi; kendi satırları, foto klasörü ve auth kullanıcısı silinir. Apple jeton iptali:
  Apple girişinde `authorizationCode` `apple-jeton` fonksiyonuna gönderilip yenileme jetonu saklanır (Sinerji/KümesPro şablonu, tablo
  `soy_apple_jeton`); silmede iptal **en iyi çaba** (jeton yoksa silme yine yapılır).
- **Supabase değişiklikleri yalnız ekleyici:** yeni `soy_apple_jeton` tablosu (service_role-only) + Deno TS Edge Function'lar; Kentsel/Patika
  tablolarına ve mevcut `soy_*` politikalarına dokunulmaz.
- **Görseller/fontlar:** `assets/` ve `yenilogo/` kopyalanır; fontlar sabit ağırlıklı TTF. Görünüm "web'e yakın" yeterli, piksel eşliği aranmaz.
- **Ağaç:** hedef 150–500 kişide akıcı; PNG dışa aktarmada iOS bellek sınırı için tavan 8 MP (web 16 MP).
- **CI:** push'ta Linux `swift test` (çekirdek); uygulama derlemesi yalnız TestFlight iş akışında (macOS dakikası). UI testi yok, cihazda Kamil dener.
- **Dil:** yalnız Türkçe.

## 10. Builder'a bırakılanlar
Dosya/tip adları, ekranların SwiftUI bileşen bölümü, görev sırası, test senaryolarının ayrıntısı, ikon/açılış görselinin
`yenilogo/` kaynaklarından üretimi, renk kodları (web CSS değişkenlerinden), fontların sabit ağırlıklı TTF'ye çevrilmesi.
