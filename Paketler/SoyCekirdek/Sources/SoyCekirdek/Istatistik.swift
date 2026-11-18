import Foundation

/// Sayım satırı (ad + adet + çubuk genişliği %): web `topNames` / `topL` / `topS` öğeleri.
public struct SayimSatiri: Equatable {
    public var ad: String
    public var sayi: Int
    /// Web `Math.round(c/max*100)` (çubuk genişliği, 0-100).
    public var genislik: Int

    public init(ad: String, sayi: Int, genislik: Int) {
        self.ad = ad
        self.sayi = sayi
        self.genislik = genislik
    }
}

/// "On Yıllara Göre Doğumlar" satırı: etiket web'de `1950'ler`.
public struct OnYilSatiri: Equatable {
    public var onYil: Int
    public var sayi: Int
    public var genislik: Int

    public init(onYil: Int, sayi: Int, genislik: Int) {
        self.onYil = onYil
        self.sayi = sayi
        self.genislik = genislik
    }

    public var etiket: String { return String(onYil) + "'ler" }
}

/// Yaşam rekoru / yaşı hesaplanan kişi (web `aged` öğesi). `ad` ham (kaçışsız) kişi adıdır.
public struct YasamKaydi: Equatable {
    public var id: String
    public var ad: String
    public var yas: Int
    public var vefat: Bool
    public var dogumYili: String
    public var olumYili: String

    public init(id: String, ad: String, yas: Int, vefat: Bool, dogumYili: String, olumYili: String) {
        self.id = id
        self.ad = ad
        self.yas = yas
        self.vefat = vefat
        self.dogumYili = dogumYili
        self.olumYili = olumYili
    }

    /// Web: `*${by} — ${dy} · ${age} yıl`.
    public var ayrinti: String {
        return "*" + dogumYili + " — " + olumYili + " · " + String(yas) + " yıl"
    }
}

/// Yaklaşan doğum günü (30 gün; web `upcomingBD` öğesi). `gun`/`ay` iki haneli metin.
public struct YaklasanDogum: Equatable {
    public var id: String
    public var ad: String
    public var diff: Int
    public var gun: String
    public var ay: String
    public var yasiniDolduruyor: Int

    public init(id: String, ad: String, diff: Int, gun: String, ay: String, yasiniDolduruyor: Int) {
        self.id = id
        self.ad = ad
        self.diff = diff
        self.gun = gun
        self.ay = ay
        self.yasiniDolduruyor = yasiniDolduruyor
    }

    /// Web: `Bugün 🎉 | Yarın 🎁 | N gün sonra` · `GG/AA` · `N yaşına giriyor`.
    public var metin: String {
        var ne = String(diff) + " gün sonra"
        if diff == 0 { ne = "Bugün 🎉" } else if diff == 1 { ne = "Yarın 🎁" }
        return ne + " · " + gun + "/" + ay + " · " + String(yasiniDolduruyor) + " yaşına giriyor"
    }
}

/// İstatistik ekranının (web `renderStats`) ve ana sayfa sayılarının (web `renderHome`) tek kaynağı.
/// `bos` ise web "Veri yok" boş durumunu gösterir (sayılar 0 / boş liste).
public struct IstatistikOzet: Equatable {
    // renderStats
    public var bos: Bool = true
    public var toplam: Int = 0
    public var hayatta: Int = 0
    public var erkek: Int = 0
    public var kadin: Int = 0
    public var fotografli: Int = 0
    public var toplamFotograf: Int = 0
    /// En uzun ata zinciri (web `gens`).
    public var kusak: Int = 0
    /// Yalnız vefat edenlerden; kayıt yoksa nil (kutu gösterilmez).
    public var ortalamaOmur: Int?
    /// Yalnız yaşayanlardan; kayıt yoksa nil.
    public var ortalamaYas: Int?
    public var enUzun: YasamKaydi?
    public var enKisa: YasamKaydi?
    public var enCokIsimler: [SayimSatiri] = []
    public var onYillar: [OnYilSatiri] = []
    public var dogumYerleri: [SayimSatiri] = []
    public var soyadlar: [SayimSatiri] = []
    public var yaklasanDogumGunleri: [YaklasanDogum] = []
    public var erkekYuzde: Int = 0
    public var kadinYuzde: Int = 0

    // renderHome
    public var kisiSayisi: Int = 0
    /// Web `genDepth()` (ana sayfa alt başlığı; `kusak`tan farklı hesap).
    public var genDepth: Int = 0
    public var altBaslik: String = ""
    public var sayacBaslik: String = ""
    /// `upcomingEvents(60)` (ilki ana sayfada gösterilir, kalan sayısı "+N yaklaşan").
    public var yaklasanOlaylar: [Olay] = []
    public var anaOlayBasligi: String?
    public var anaOlayAltSatiri: String?

    public init() {}

    /// Web: `En Uzun`/`En Kısa` kartı yalnız vefat edenler varsa; `En Kısa` en uzunla aynı kişiyse gösterilmez.
    public var enKisaGoster: Bool {
        guard let k = enKisa, let u = enUzun else { return false }
        return k.id != u.id
    }
}

public enum Istatistik {
    /// Web'de gösterilen Türkçe etiketler (aynen).
    public enum Etiket {
        public static let toplam = "Toplam Kişi"
        public static let hayatta = "Hayatta"
        public static let erkek = "Erkek"
        public static let kadin = "Kadın"
        public static let fotografli = "Fotoğraflı"
        public static let toplamFotograf = "Toplam Fotoğraf"
        public static let kusak = "Kuşak"
        public static let ortalamaOmur = "Ortalama Ömür (vefat)"
        public static let ortalamaYas = "Ortalama Yaş (yaşayan)"
        public static let yasamRekorlari = "🏅 Yaşam Rekorları"
        public static let enUzun = "🥇 En Uzun: "
        public static let enKisa = "📉 En Kısa: "
        public static let isimler = "👤 En Çok Kullanılan İsimler"
        public static let onYillar = "📅 On Yıllara Göre Doğumlar"
        public static let yerler = "📍 En Çok Doğum Yeri"
        public static let soyadlar = "👨‍👩‍👧 Soyadlar"
        public static let cinsiyetDagilimi = "Cinsiyet Dağılımı"
        public static let yaklasanDogum = "🎂 Yaklaşan Doğum Günleri (30 gün)"
        public static let veriYok = "Veri yok"
        public static let veriYokAciklama = "Önce kişi ekleyin."
    }

    /// Web `AYLAR`.
    public static let AYLAR = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]

    /// Web `_when`.
    public static func gunMetni(_ d: Int) -> String {
        if d == 0 { return "Bugün" }
        if d == 1 { return "Yarın" }
        return String(d) + " gün sonra"
    }

    // MARK: yardımcılar

    /// JS `Math.round` (pozitif/negatif yarım değerler +∞'a).
    static func yuvarla(_ x: Double) -> Int {
        return Int((x + 0.5).rounded(.down))
    }

    /// Ekleme sırasını koruyan sayaç (JS nesnesi gibi); anahtar UTF-8 baytlarıdır (Swift'in kanonik eşitliği yok).
    struct Sayac {
        var sira: [[UInt8]] = []
        var adlar: [[UInt8]: String] = [:]
        var sayilar: [[UInt8]: Int] = [:]

        mutating func artir(_ ad: String) {
            let k = Array(ad.utf8)
            if let s = sayilar[k] {
                sayilar[k] = s + 1
            } else {
                sira.append(k)
                adlar[k] = ad
                sayilar[k] = 1
            }
        }

        /// Sayıya göre azalan, eşitlikte ekleme sırası (kararlı); ilk `n`.
        func enCok(_ n: Int) -> [(String, Int)] {
            var liste: [(Int, Int, String)] = []
            for (i, k) in sira.enumerated() {
                liste.append((sayilar[k] ?? 0, i, adlar[k] ?? ""))
            }
            liste.sort { a, b in
                if a.0 != b.0 { return a.0 > b.0 }
                return a.1 < b.1
            }
            var cikti: [(String, Int)] = []
            for e in liste.prefix(n) { cikti.append((e.2, e.0)) }
            return cikti
        }
    }

    static func sayimSatirlari(_ l: [(String, Int)]) -> [SayimSatiri] {
        let enCok = Double(l.first?.1 ?? 1)
        var cikti: [SayimSatiri] = []
        for (ad, c) in l {
            cikti.append(SayimSatiri(ad: ad, sayi: c, genislik: yuvarla(Double(c) / enCok * 100)))
        }
        return cikti
    }

    /// (y, m, 1) + (d - 1) gününün sıra numarası (JS `new Date(y,m-1,d)` taşmasıyla aynı: Şubat 31 -> Mart).
    static func gunNo(_ y: Int, _ m: Int, _ d: Int) -> Int {
        let yy = m <= 2 ? y - 1 : y
        let era = (yy >= 0 ? yy : yy - 399) / 400
        let yoe = yy - era * 400
        let mp = (m + 9) % 12
        let doy = (153 * mp + 2) / 5
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468 + (d - 1)
    }

    static func iki(_ n: Int) -> String {
        return n < 10 ? "0" + String(n) : String(n)
    }

    // MARK: genDepth (web l.3946)

    /// Web `genDepth()`: ana sayfa "N kuşak" sayısı. Web'de kişi olmayan (nesne olmayan) kayıt hata verir;
    /// burada 1 sayılır. `AileModeli` gerekmez (web yalnızca `people` okur).
    public static func genDepth(_ a: Agac) -> Int {
        var memo: [String: Int] = [:]
        func d(_ id: String, _ seen: inout Set<String>) -> Int {
            if let m = memo[id], m != 0 { return m }
            if seen.contains(id) { return 1 }
            seen.insert(id)
            var en = 0
            if let p = a.kisi(id) {
                var adaylar: [String] = []
                if let f = p.father, a.kisi(f) != nil { adaylar.append(f) }
                if let m = p.mother, a.kisi(m) != nil { adaylar.append(m) }
                for x in adaylar {
                    let r = d(x, &seen)
                    if r > en { en = r }
                }
            }
            seen.remove(id)
            let r = 1 + en
            memo[id] = r
            return r
        }
        var mx = 0
        for id in a.people.anahtarlar {
            var seen = Set<String>()
            let r = d(id, &seen)
            if r > mx { mx = r }
        }
        return mx
    }

    // MARK: renderStats gens (web l.2772)

    /// Web `renderStats` içindeki en uzun ata zinciri (`seen` hiç temizlenmez; kasıtlı farklı hesap).
    static func zincirKusak(_ a: Agac, _ kisiler: [Kisi]) -> Int {
        var memo: [String: Int] = [:]
        func depth(_ id: String?, _ seen: inout Set<String>) -> Int {
            guard let id = id, !id.isEmpty, let q = a.kisi(id) else { return 0 }
            if let m = memo[id] { return m }
            if seen.contains(id) { return 0 }
            seen.insert(id)
            let x = depth(q.mother, &seen)
            let y = depth(q.father, &seen)
            let r = 1 + (x > y ? x : y)
            memo[id] = r
            return r
        }
        var m = 0
        for q in kisiler {
            var seen = Set<String>()
            let r = depth(q.id, &seen)
            if r > m { m = r }
        }
        return m
    }

    // MARK: hesapla

    /// Web `renderStats` + `renderHome` sayıları. `takvim`: uygulama gregorian + `timeZone = .current` vermeli
    /// (bkz. `Olaylar.eventsBetween`). `ayar`: ana sayfa olayları (`upcomingEvents(60)`) için hatırlatma ayarı.
    public static func hesapla(_ a: Agac, simdi: Date, takvim: Calendar, ayar: HatirlatmaAyari = HatirlatmaAyari()) -> IstatistikOzet {
        var o = IstatistikOzet()
        var kisiler: [Kisi] = []
        for k in a.people.anahtarlar {
            if let p = a.kisi(k) { kisiler.append(p) }
        }
        o.kisiSayisi = a.people.sayisi
        o.genDepth = genDepth(a)
        if o.kisiSayisi > 0 {
            o.altBaslik = String(o.kisiSayisi) + " kişi · " + String(o.genDepth) + " kuşak"
            o.sayacBaslik = "Aile bireyleri (" + String(o.kisiSayisi) + ")"
        } else {
            o.altBaslik = "Ağacınız henüz boş — + ile başlayın"
            o.sayacBaslik = "Aile bireyleri"
        }
        if o.kisiSayisi > 0 {
            o.yaklasanOlaylar = Olaylar.upcomingEvents(60, a, ayar: ayar, simdi: simdi, takvim: takvim)
            if let e = o.yaklasanOlaylar.first {
                let ad = a.kisi(e.id).map { Islem.pname($0) } ?? "İsimsiz"
                var ne = "doğumunun " + String(e.n) + ". yılı"
                if e.kind == "bd" { ne = String(e.n) + ". yaş günü" } else if e.kind == "an" { ne = "vefatının " + String(e.n) + ". yılı" }
                o.anaOlayBasligi = ad + " · " + ne
                var alt = String(e.d) + " " + AYLAR[e.m - 1] + " · " + gunMetni(e.diff)
                if o.yaklasanOlaylar.count > 1 { alt += " · +" + String(o.yaklasanOlaylar.count - 1) + " yaklaşan" }
                o.anaOlayAltSatiri = alt
            }
        }
        if kisiler.isEmpty { return o }
        o.bos = false
        o.toplam = kisiler.count
        for p in kisiler {
            if p.gender == "M" { o.erkek += 1 }
            if p.gender == "F" { o.kadin += 1 }
            if !Islem.isDead(p, simdi: simdi, takvim: takvim) { o.hayatta += 1 }
            if p.photo != nil { o.fotografli += 1 }
            o.toplamFotograf += p.ham["gallery"]?.dizi?.count ?? 0
        }
        let bugun = takvim.dateComponents([.year, .month, .day], from: simdi)
        let buYil = bugun.year ?? 1970
        let buAy = bugun.month ?? 1
        let buGun = bugun.day ?? 1

        var aged: [YasamKaydi] = []
        for p in kisiler {
            let by = Tarih.yearOf(p.birthDate)
            let dy = Tarih.yearOf(p.deathDate)
            if by.isEmpty { continue }
            let b = Int(by) ?? 0
            let yas = dy.isEmpty ? buYil - b : (Int(dy) ?? 0) - b
            aged.append(YasamKaydi(id: p.id, ad: Islem.pname(p), yas: yas, vefat: !dy.isEmpty, dogumYili: by, olumYili: dy))
        }
        var da: [YasamKaydi] = []
        var alive: [YasamKaydi] = []
        for x in aged where x.yas >= 0 {
            if x.vefat { da.append(x) } else { alive.append(x) }
        }
        if !da.isEmpty {
            var toplam = 0
            for x in da { toplam += x.yas }
            o.ortalamaOmur = yuvarla(Double(toplam) / Double(da.count))
            var en = da[0]
            var kisa = da[0]
            for x in da {
                if x.yas > en.yas { en = x }
                if x.yas < kisa.yas { kisa = x }
            }
            o.enUzun = en
            o.enKisa = kisa
        }
        if !alive.isEmpty {
            var toplam = 0
            for x in alive { toplam += x.yas }
            o.ortalamaYas = yuvarla(Double(toplam) / Double(alive.count))
        }
        o.kusak = zincirKusak(a, kisiler)

        var isimler = Sayac()
        var yerler = Sayac()
        var soyadlar = Sayac()
        var onYil: [Int: Int] = [:]
        for p in kisiler {
            if !p.firstName.isEmpty {
                var u = String.UnicodeScalarView()
                for s in p.firstName.unicodeScalars {
                    if s == " " { break }
                    u.append(s)
                }
                isimler.artir(String(u))
            }
            let y = Tarih.yearOf(p.birthDate)
            if !y.isEmpty, let yn = Int(y) {
                let dd = (yn / 10) * 10
                onYil[dd] = (onYil[dd] ?? 0) + 1
            }
            if !p.birthPlace.isEmpty {
                var u = String.UnicodeScalarView()
                for s in p.birthPlace.unicodeScalars {
                    if s == "," { break }
                    u.append(s)
                }
                yerler.artir(String(String.UnicodeScalarView(Tarih.kirp(String(u)))))
            }
            if !p.lastName.isEmpty { soyadlar.artir(p.lastName) }
        }
        o.enCokIsimler = sayimSatirlari(isimler.enCok(8))
        o.dogumYerleri = sayimSatirlari(yerler.enCok(8))
        o.soyadlar = sayimSatirlari(soyadlar.enCok(6))
        let onSirali = onYil.keys.sorted()
        var enCokOn = 1
        for k in onSirali { enCokOn = max(enCokOn, onYil[k] ?? 0) }
        for k in onSirali {
            let c = onYil[k] ?? 0
            o.onYillar.append(OnYilSatiri(onYil: k, sayi: c, genislik: yuvarla(Double(c) / Double(enCokOn) * 100)))
        }

        // Yaklaşan doğum günleri (30 gün): web kendi hesabı (Olaylar'dan ayrı: Şubat 31 -> Mart 3 taşar, vefat/yer tutucu atlanır)
        let bugunNo = gunNo(buYil, buAy, buGun)
        var yak: [YaklasanDogum] = []
        for p in kisiler {
            if Islem.isDead(p, simdi: simdi, takvim: takvim) || p.birthDate.isEmpty { continue }
            guard let dp = Tarih.dateParts(p.birthDate), let d = dp.d, let mo = dp.m else { continue }
            if mo < 1 || mo > 12 || d < 1 || d > 31 { continue }
            if Tarih.isPlaceholder(dp) { continue }
            var yil = buYil
            var no = gunNo(yil, mo, d)
            if no < bugunNo {
                yil = buYil + 1
                no = gunNo(yil, mo, d)
            }
            let diff = no - bugunNo
            if diff > 30 { continue }
            yak.append(YaklasanDogum(id: p.id, ad: Islem.pname(p), diff: diff, gun: iki(d), ay: iki(mo), yasiniDolduruyor: yil - dp.y))
        }
        // kararlı: diff'e göre, eşitlikte kişi sırası
        var idx: [(Int, Int)] = []
        for (i, y) in yak.enumerated() { idx.append((y.diff, i)) }
        idx.sort { a, b in a.0 != b.0 ? a.0 < b.0 : a.1 < b.1 }
        o.yaklasanDogumGunleri = idx.map { yak[$0.1] }

        o.erkekYuzde = yuvarla(Double(o.erkek) / Double(o.toplam) * 100)
        o.kadinYuzde = yuvarla(Double(o.kadin) / Double(o.toplam) * 100)
        return o
    }
}
