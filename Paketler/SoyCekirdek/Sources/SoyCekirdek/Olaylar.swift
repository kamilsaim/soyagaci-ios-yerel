import Foundation

/// Hatırlatma ayarları (web `remSet()` l.3271, `REM_DEF`): doğum günü / anma günü, kaç gün önce haber verilsin
/// (0/1/3/7), açılışta uyarı. Cihaza özel; saklama (`sa4_remset`) uygulamaya aittir.
public struct HatirlatmaAyari: Codable, Equatable {
    public var bd: Bool
    public var an: Bool
    public var lead: Int
    public var alert: Bool

    /// Web `REM_DEF`.
    public init(bd: Bool = true, an: Bool = true, lead: Int = 1, alert: Bool = true) {
        self.bd = bd
        self.an = an
        self.lead = lead
        self.alert = alert
    }

    private enum CodingKeys: String, CodingKey { case bd, an, lead, alert }

    /// Eksik alanlar varsayılanla doldurulur (web `Object.assign({},REM_DEF,JSON.parse(...))`).
    public init(from decoder: Decoder) throws {
        let k = try decoder.container(keyedBy: CodingKeys.self)
        let v = HatirlatmaAyari()
        bd = try k.decodeIfPresent(Bool.self, forKey: .bd) ?? v.bd
        an = try k.decodeIfPresent(Bool.self, forKey: .an) ?? v.an
        lead = try k.decodeIfPresent(Int.self, forKey: .lead) ?? v.lead
        alert = try k.decodeIfPresent(Bool.self, forKey: .alert) ?? v.alert
    }

    /// Web `remSet()`: saklanan ham metni okur. Metin yok/bozuk/nesne değilse varsayılan.
    /// Fark: web türe bakmadan üzerine yazar (`"lead":"3"`, `"bd":0`); burada türü uymayan alan varsayılanda kalır.
    public static func oku(_ ham: String?) -> HatirlatmaAyari {
        var s = HatirlatmaAyari()
        guard let ham = ham, !ham.isEmpty, let j = try? JSON.coz(ham), let o = j.nesne else { return s }
        if case .bool(let b)? = o["bd"] { s.bd = b }
        if case .bool(let b)? = o["an"] { s.an = b }
        if case .bool(let b)? = o["alert"] { s.alert = b }
        if case .number(let d)? = o["lead"], d == d.rounded(), abs(d) < 1e6 { s.lead = Int(d) }
        return s
    }
}

/// Hangi olay türleri istenir (web `opt`): `bd` yaşayanın doğum günü (varsayılan açık), `an` vefat yıl dönümü
/// (varsayılan açık), `bdx` vefat etmişin doğum günü (varsayılan kapalı; yalnızca takvimde).
public struct OlayFiltre: Equatable {
    public var bd: Bool
    public var an: Bool
    public var bdx: Bool

    public init(bd: Bool = true, an: Bool = true, bdx: Bool = false) {
        self.bd = bd
        self.an = an
        self.bdx = bdx
    }
}

/// Web `eventsBetween` öğesi `{id,diff,date,kind,n,d,m}`. `kind`: "bd" | "an" | "bdx".
public struct Olay: Equatable {
    public var id: String
    public var diff: Int
    public var date: Date
    public var kind: String
    public var n: Int
    public var d: Int
    public var m: Int

    public init(id: String, diff: Int, date: Date, kind: String, n: Int, d: Int, m: Int) {
        self.id = id
        self.diff = diff
        self.date = date
        self.kind = kind
        self.n = n
        self.d = d
        self.m = m
    }
}

/// Web `notificationPlan` öğesi `{id,at,title,body,personId}`.
public struct PlanliBildirim: Equatable {
    public var id: Int
    public var at: Date
    public var title: String
    public var body: String
    public var personId: String

    public init(id: Int, at: Date, title: String, body: String, personId: String) {
        self.id = id
        self.at = at
        self.title = title
        self.body = body
        self.personId = personId
    }
}

/// Doğum günü / anma günü olayları (web l.3268-3370). Arayüz (`renderReminders`, `remAlertOnce`, `openMonth` çizimi) taşınmadı;
/// ay takvimi için `eventsBetween(ayinIlkGunu, gunSayisi-1, OlayFiltre(bdx: true))` kullanılır.
public enum Olaylar {
    /// `[from, from+days]` aralığındaki olaylar, `diff` sonra `kind` sırasıyla (kararlı).
    /// Web `new Date(y,m-1,d)` taşması (29 Şubat artık olmayan yıl, 31 Nisan, gün 0, ay 13) olayı atlar.
    /// `simdi`: `isDead` için "şimdi" (web `new Date()`); verilmezse `from`. Web'de `from` ve şimdi ayrıdır (ay takvimi başka aya bakar).
    public static func eventsBetween(_ from: Date, _ days: Int, _ opt: OlayFiltre, _ a: Agac, takvim: Calendar, simdi: Date? = nil) -> [Olay] {
        let bugun = simdi ?? from
        let t0 = takvim.startOfDay(for: from)
        let yil0 = takvim.component(.year, from: t0)
        var ev: [Olay] = []

        func ekle(_ id: String, _ dp: TarihParca, _ kind: String) {
            guard let ay = dp.m, let gun = dp.d, ay >= 1, ay <= 12 else { return }
            for y in yil0...(yil0 + 1) {
                guard let x = tarih(y, ay, gun, takvim) else { continue }
                let diff = takvim.dateComponents([.day], from: t0, to: x).day ?? 0
                if diff >= 0 && diff <= days {
                    ev.append(Olay(id: id, diff: diff, date: x, kind: kind, n: y - dp.y, d: gun, m: ay))
                    break
                }
            }
        }

        for anahtar in a.people.anahtarlar {
            guard let p = a.kisi(anahtar) else { continue }
            let b = Tarih.dateParts(p.birthDate)
            let dd = Tarih.dateParts(p.deathDate)
            let dead = Islem.isDead(p, simdi: bugun, takvim: takvim)
            if let b = b, !Tarih.isPlaceholder(b) {
                if !dead && opt.bd {
                    ekle(p.id, b, "bd")
                } else if dead && opt.bdx {
                    ekle(p.id, b, "bdx")
                }
            }
            if let dd = dd, !(dd.d == 1 && dd.m == 7), opt.an { ekle(p.id, dd, "an") }
        }

        // JS sort kararlı; Swift'te dizine göre kararlı hale getirilir.
        var sirali: [(Int, Olay)] = []
        for (i, e) in ev.enumerated() { sirali.append((i, e)) }
        sirali.sort { x, y in
            if x.1.diff != y.1.diff { return x.1.diff < y.1.diff }
            if x.1.kind != y.1.kind { return x.1.kind < y.1.kind }
            return x.0 < y.0
        }
        var cikti: [Olay] = []
        for s in sirali { cikti.append(s.1) }
        return cikti
    }

    /// Geçerli takvim günü (yıl, ay 1...12, gün); taşan gün (29 Şub, 31 Nis, 0) için nil.
    static func tarih(_ y: Int, _ m: Int, _ d: Int, _ takvim: Calendar) -> Date? {
        guard d >= 1, let ilk = takvim.date(from: DateComponents(year: y, month: m, day: 1)),
              let aralik = takvim.range(of: .day, in: .month, for: ilk), d <= aralik.count else { return nil }
        return takvim.date(from: DateComponents(year: y, month: m, day: d))
    }

    /// Web `upcomingEvents(days)`: ayara göre `simdi`'den itibaren.
    public static func upcomingEvents(_ days: Int, _ a: Agac, ayar: HatirlatmaAyari, simdi: Date, takvim: Calendar) -> [Olay] {
        return eventsBetween(simdi, days, OlayFiltre(bd: ayar.bd, an: ayar.an), a, takvim: takvim, simdi: simdi)
    }

    /// Web `evText`: aynı HTML (ad kaçışlı, `<span>` içinde yaş/yıl).
    public static func evText(_ e: Olay, _ a: Agac) -> String {
        let nm = GedBirlestir.esc(a.kisi(e.id).map { Islem.pname($0) } ?? "İsimsiz")
        if e.kind == "bd" {
            return "\u{1F382} " + nm + " <span>" + String(e.n) + " yaşına giriyor</span>"
        }
        if e.kind == "an" {
            return "\u{1F54A}\u{FE0F} " + nm + " <span>vefatının " + String(e.n) + ". yılı</span>"
        }
        return "\u{1F56F}\u{FE0F} " + nm + " <span>doğumunun " + String(e.n) + ". yılı</span>"
    }

    /// Web `notificationPlan(hour)`: önümüzdeki 366 günün bildirimleri; `at` = olay günü - `lead` gün, saat `hour`:00.
    /// `id` filtrelemeden ÖNCEKİ sıra numarasıdır (1'den). `at <= simdi` olanlar atılır (`id` boşlukları kalır).
    /// iOS en fazla 64 yerel bildirim planlar: uygulama `Array(plan.prefix(60))` alır (liste zaten tarihe göre sıralı).
    public static func notificationPlan(_ a: Agac, ayar: HatirlatmaAyari, hour: Int = 9, simdi: Date, takvim: Calendar) -> [PlanliBildirim] {
        let olaylar = eventsBetween(simdi, 366, OlayFiltre(bd: ayar.bd, an: ayar.an), a, takvim: takvim, simdi: simdi)
        let w = ayar.lead == 0 ? "Bugün" : (ayar.lead == 1 ? "Yarın" : String(ayar.lead) + " gün sonra")
        var plan: [PlanliBildirim] = []
        for (i, e) in olaylar.enumerated() {
            guard let gun = takvim.date(byAdding: .day, value: -ayar.lead, to: e.date),
                  let at = takvim.date(bySettingHour: hour, minute: 0, second: 0, of: gun) else { continue }
            let nm = a.kisi(e.id).map { Islem.pname($0) } ?? "İsimsiz"
            let baslik: String
            let govde: String
            if e.kind == "bd" {
                baslik = "\u{1F382} " + w + " " + nm + " doğum günü"
                govde = String(e.n) + " yaşına giriyor"
            } else {
                baslik = "\u{1F54A}\u{FE0F} " + w + " " + nm + " vefat yıl dönümü"
                govde = "Vefatının " + String(e.n) + ". yılı"
            }
            if at > simdi {
                plan.append(PlanliBildirim(id: i + 1, at: at, title: baslik, body: govde, personId: e.id))
            }
        }
        return plan
    }
}
