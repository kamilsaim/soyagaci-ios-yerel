import Foundation

/// Bulut satırı: web `soy_family_data` {people, next_id, updated_at}.
public struct BulutSatiri {
    public var agac: Agac
    public var updatedAt: Date
    public init(agac: Agac, updatedAt: Date) {
        self.agac = agac
        self.updatedAt = updatedAt
    }
}

/// Supabase `soy_family_data` erişimi. `yaz` upsert eder (`fams` YAZILMAZ: yalnız user_id, people, next_id)
/// ve yeni `updated_at` döner.
public protocol BulutDeposu {
    /// Satır yoksa nil; okunamazsa fırlatır.
    func oku(uid: String) async throws -> BulutSatiri?
    func yaz(uid: String, agac: Agac) async throws -> Date
}

/// Cihazdaki localStorage karşılıkları. Sınıf-bağlı: aktör içinden değiştirilebilir.
/// Sendable DEĞİL: uygulama depoya yalnızca `Esitleyici` üzerinden erişmeli (ya da kendi kilidini koymalı).
public protocol YerelDeposu: AnyObject {
    /// sa4 (giriş yapmış kullanıcının bulut yedeği)
    var bulutKopya: Agac? { get set }
    /// sa4 içindeki `uid` (web `o.uid`); nil = herkese açık sayılır
    var bulutKopyaUid: String? { get set }
    /// sa4_local
    var yerelMod: Agac? { get set }
    /// sa4_dirty (buluta gitmemiş değişikliği olan kullanıcı id'si)
    var kirli: String? { get set }
    /// sa4_base (yerel kopyanın dayandığı bulut updated_at)
    var taban: Date? { get set }
    /// sa4_ts (eski kayıtlar için son yazma zamanı)
    var eskiZaman: Date? { get set }
}

public enum YuklemeKaynagi: Equatable {
    case bulut, yerel, yerelOkunamadi
}

public struct YuklemeSonucu {
    public var agac: Agac
    public var kaynak: YuklemeKaynagi
    /// Yerel (kirli) kopya kazandı ama bulutun updated_at'i sa4_base'den 2 sn'den fazla yeni (arada başka
    /// cihaz yazmış). Ardından gelen gönderim `.cakisma` verecek (`durumlar` akışında da görünür); UI bir kez sormalı.
    public var cakisma: Bool
    public init(agac: Agac, kaynak: YuklemeKaynagi, cakisma: Bool) {
        self.agac = agac
        self.kaynak = kaynak
        self.cakisma = cakisma
    }
}

/// Web `setSync` karşılığı: gecikmeli (debounce) gönderimlerin sonucu UI'ya bu akışla ulaşır.
/// Hata metni tanılama içindir; kullanıcıya gösterilecek metin UI'nın ("Buluta kaydedilemedi — veri bu cihazda duruyor").
public enum EsitlemeDurumu: Equatable {
    case gonderiliyor
    case tamam
    case cakisma(bulutZamani: Date)
    case hata(String)
}

public enum GonderimSonucu {
    case tamam
    /// Başka cihaz araya girdi; kullanıcıya sorulmalı: evet -> `gonder(zorla: true)`, hayır -> `bulutuKabulEt()`.
    case cakisma(bulutZamani: Date)
    case hata(String)
}

/// Web `load()` / `save()` / `pushToCloud()` / `signOut()` eşitleme kuralları. Kullanıcıya sormaz, sonuç döner.
public actor Esitleyici {
    private let bulut: BulutDeposu
    private let yerel: YerelDeposu
    private let gecikme: TimeInterval
    private let simdi: () -> Date
    private let durumBildir: AsyncStream<EsitlemeDurumu>.Continuation
    /// Gecikmeli gönderimlerin sonucu (web setSync). Tek tüketici için.
    public nonisolated let durumlar: AsyncStream<EsitlemeDurumu>

    private var uid: String?
    private var sunucuMs: Int = 0          // _serverTs
    private var nesil: Int = 0             // _saveGen
    private var guncel: Agac?              // son kaydedilen anlık görüntü (gonder için)
    private var zamanlayici: Task<Void, Never>?
    private var kuyruk: Task<Void, Never>? // _pushQ

    public init(bulut: BulutDeposu, yerel: YerelDeposu, gecikme: TimeInterval = 0.8,
                simdi: @escaping () -> Date = { Date() }) {
        self.bulut = bulut
        self.yerel = yerel
        self.gecikme = gecikme
        self.simdi = simdi
        var c: AsyncStream<EsitlemeDurumu>.Continuation!
        self.durumlar = AsyncStream<EsitlemeDurumu> { c = $0 }
        self.durumBildir = c
    }

    private static func ms(_ d: Date) -> Int {
        return Int((d.timeIntervalSince1970 * 1000).rounded())
    }

    // MARK: load()

    /// Web `load()`. `uid == nil` -> yerel mod (bulut çağrılmaz).
    public func yukle(uid yeniUid: String?) async -> YuklemeSonucu {
        if uid != yeniUid {
            // hesap değişti: eski hesabın bekleyen/uçuştaki gönderimleri artık yazamaz
            zamanlayici?.cancel()
            zamanlayici = nil
            nesil += 1
            sunucuMs = 0
        }
        uid = yeniUid
        guard let uid = yeniUid else {
            var a = yerel.yerelMod ?? Agac()
            if a.nextId == 0 { a.nextId = 1 }
            Islem.migrateData(&a)
            guncel = a
            return YuklemeSonucu(agac: a, kaynak: .yerel, cakisma: false)
        }

        var veri: BulutSatiri?
        var basarisiz = false
        do {
            veri = try await bulut.oku(uid: uid)
        } catch {
            basarisiz = true
        }

        let kirliMi = yerel.kirli == uid
        let tabanMs = yerel.taban.map { Esitleyici.ms($0) } ?? 0
        let yerelKopya = yerelBulutKopyasi(uid)

        if var v = veri {
            let bulutMs = Esitleyici.ms(v.updatedAt)
            sunucuMs = bulutMs
            if v.agac.nextId == 0 { v.agac.nextId = 1 }
            let bulutSayi = v.agac.people.sayisi
            let yerelSayi = yerelKopya?.people.sayisi ?? 0

            // 1) buluta gitmemiş yerel değişiklik (veya sa4_base yokken eski zaman damgası kuralı) -> yerel kazanır
            let eskiMs = yerel.eskiZaman.map { Esitleyici.ms($0) } ?? 0
            let eskiDahaYeni = yerel.taban == nil && eskiMs > bulutMs + 5000
            if var y = yerelKopya, yerelSayi > 0, kirliMi || eskiDahaYeni {
                if kirliMi { sunucuMs = tabanMs != 0 ? tabanMs : 1 }
                if y.nextId == 0 { y.nextId = 1 }
                Islem.migrateData(&y)
                let cakisma = kirliMi && bulutMs > sunucuMs + 2000
                kaydetIc(y)
                return YuklemeSonucu(agac: y, kaynak: .yerel, cakisma: cakisma)
            }
            // 2) bulutta veri varsa bulut kazanır
            if bulutSayi > 0 {
                var a = v.agac
                Islem.migrateData(&a)
                guncel = a
                return YuklemeSonucu(agac: a, kaynak: .bulut, cakisma: false)
            }
            // 3) bulut boş, yerelde veri var -> yerelden geri yükle ve gönder
            if var y = yerelKopya, yerelSayi > 0 {
                if y.nextId == 0 { y.nextId = 1 }
                Islem.migrateData(&y)
                kaydetIc(y)
                return YuklemeSonucu(agac: y, kaynak: .yerel, cakisma: false)
            }
            var bos = Agac()
            Islem.migrateData(&bos)
            guncel = bos
            return YuklemeSonucu(agac: bos, kaynak: .bulut, cakisma: false)
        }

        // Bulut satırı yok / okunamadı -> yerel bulut yedeği
        var a = yerelKopya ?? Agac()
        if a.nextId == 0 { a.nextId = 1 }
        Islem.migrateData(&a)
        if basarisiz {
            // yereli göster ama buluta İTME; sonraki kayıtlarda çakışma denetimi için taban ayarla
            sunucuMs = tabanMs != 0 ? tabanMs : 1
            guncel = a
            return YuklemeSonucu(agac: a, kaynak: .yerelOkunamadi, cakisma: false)
        }
        if a.people.sayisi > 0 {
            kaydetIc(a)
        } else {
            guncel = a
        }
        return YuklemeSonucu(agac: a, kaynak: .yerel, cakisma: false)
    }

    /// Web `_readLocalSnap()`: başka kullanıcıya ait yedek yok sayılır.
    private func yerelBulutKopyasi(_ uid: String) -> Agac? {
        guard let k = yerel.bulutKopya else { return nil }
        if let u = yerel.bulutKopyaUid, u != uid { return nil }
        return k
    }

    // MARK: save()

    /// Web `save()`: yerel yaz; girişliyse kirli işaretle ve gecikmeli (800 ms) gönder.
    public func kaydet(_ agac: Agac) {
        kaydetIc(agac)
    }

    private func kaydetIc(_ agac: Agac) {
        guncel = agac
        yerel.eskiZaman = simdi()
        guard let uid = uid else {
            yerel.yerelMod = agac
            return
        }
        yerel.bulutKopya = agac
        yerel.bulutKopyaUid = uid
        yerel.kirli = uid
        yerel.taban = Date(timeIntervalSince1970: Double(sunucuMs) / 1000)
        nesil += 1
        let n = nesil
        durumBildir.yield(.gonderiliyor)
        zamanlayici?.cancel()
        let bekleme = UInt64(max(0, gecikme) * 1_000_000_000)
        zamanlayici = Task { [weak self] in
            try? await Task.sleep(nanoseconds: bekleme)
            if Task.isCancelled { return }
            await self?.zamanlayiciDoldu(agac, n, uid)
        }
    }

    private func zamanlayiciDoldu(_ agac: Agac, _ n: Int, _ u: String) async {
        // yalnız bu zamanlayıcı hâlâ güncelse tutamağı bırak (araya girmiş yeni zamanlayıcıyı ezme)
        if n == nesil { zamanlayici = nil }
        _ = await sirala { await self.gonderIc(agac, zorla: false, nesil: n, uid: u) }
    }

    /// Bekleyen zamanlayıcı ve kuyruk bitene kadar bekler (testler / uygulama kapanışı için).
    public func beklenenleriBitir() async {
        if let z = zamanlayici { await z.value }
        if let k = kuyruk { await k.value }
    }

    // MARK: sıralı kuyruk (_pushQ)

    private func sirala(_ isle: @escaping () async -> GonderimSonucu) async -> GonderimSonucu {
        let onceki = kuyruk
        let t = Task { () -> GonderimSonucu in
            if let o = onceki { await o.value }
            return await isle()
        }
        kuyruk = Task { _ = await t.value }
        return await t.value
    }

    // MARK: pushToCloud

    /// Son kaydedilen anlık görüntüyü buluta gönderir. `zorla` çakışma denetimini atlar (kullanıcı "evet" dedi).
    /// Çağrı anındaki nesil ve uid yakalanır: gönderim sürerken yeni `kaydet` olursa kirli işareti kalır.
    /// Uid yoksa web sessizce döner; burada `.hata` verilir.
    public func gonder(zorla: Bool) async -> GonderimSonucu {
        guard let u = uid else { return .hata("Giriş yapılmadı") }
        guard let a = guncel else { return .tamam }
        // web yalnız kirli veriyi iter; temiz kopya (ör. okunamayan bulut sonrası) zorla olmadan gitmez
        if !zorla && yerel.kirli != u { return .tamam }
        let n = nesil
        durumBildir.yield(.gonderiliyor)
        return await sirala { await self.gonderIc(a, zorla: zorla, nesil: n, uid: u) }
    }

    /// Tüm karar girdileri (uid, nesil, anlık görüntü) kuyruğa girerken yakalanır; await sonrası yalnız
    /// hâlâ aynı hesap/nesilse durum değiştirilir.
    private func gonderIc(_ d: Agac, zorla: Bool, nesil gen: Int, uid u: String) async -> GonderimSonucu {
        if u != uid || gen < nesil { return .tamam } // hesap değişti / arkadan daha yeni bir kayıt geliyor
        let tabanSunucu = sunucuMs
        if !zorla && tabanSunucu != 0 {
            // SAPMA (web'den kasıtlı): web okuma hatasını "satır yok" sayıp yazar (supabase-js hata fırlatmaz,
            // data=null döner). Burada okunamazsa yazmayız: yeni bir bulut sürümünü sormadan ezme riski olmasın.
            // Hata dönülür, kirli kalır, sonraki gönderimde yeniden denenir.
            let simdiki: BulutSatiri?
            do {
                simdiki = try await bulut.oku(uid: u)
            } catch {
                durumBildir.yield(.hata("\(error)"))
                return .hata("\(error)")
            }
            if u != uid || gen < nesil { return .tamam }
            if let s = simdiki, Esitleyici.ms(s.updatedAt) > tabanSunucu + 2000 {
                durumBildir.yield(.cakisma(bulutZamani: s.updatedAt))
                return .cakisma(bulutZamani: s.updatedAt)
            }
        }
        do {
            let yeni = try await bulut.yaz(uid: u, agac: d)
            if u == uid {
                sunucuMs = Esitleyici.ms(yeni)
                // arada daha yeni bir kaydet olduysa kirli kalır (o veri henüz bulutta değil)
                if gen == nesil && yerel.kirli == u {
                    yerel.kirli = nil
                    yerel.taban = yeni
                }
            }
            durumBildir.yield(.tamam)
            return .tamam
        } catch {
            // Metin tanılama içindir; kullanıcıya UI kendi metnini gösterir.
            durumBildir.yield(.hata("\(error)"))
            return .hata("\(error)")
        }
    }

    /// Çakışmada kullanıcı "hayır" derse (web pushToCloud `!ok` dalı): bekleyen gönderim iptal,
    /// yerel değişiklik bilerek bırakılır (kirli + sa4 silinir), bulut sürümü yeniden yüklenir.
    public func bulutuKabulEt() async -> YuklemeSonucu {
        zamanlayici?.cancel()
        zamanlayici = nil
        nesil += 1
        if let k = kuyruk { await k.value }
        yerel.kirli = nil
        yerel.bulutKopya = nil
        yerel.bulutKopyaUid = nil
        return await yukle(uid: uid)
    }

    // MARK: signOut

    /// Web `signOut` başı: bekleyeni hemen gönder. Hâlâ buluta gitmemiş değişiklik varsa false
    /// (UI kullanıcıya sorar); true = çıkış güvenli.
    public func cikisaHazirla() async -> Bool {
        guard let u = uid else { return true }
        if zamanlayici != nil, let a = guncel {
            zamanlayici?.cancel()
            zamanlayici = nil
            let n = nesil
            _ = await sirala { await self.gonderIc(a, zorla: false, nesil: n, uid: u) }
        }
        if let k = kuyruk { await k.value }
        return yerel.kirli != u
    }

    /// Web `signOut` sonu: yerel bulut kopyası ve eşitleme izleri silinir (sa4, sa4_ts, sa4_dirty, sa4_base).
    public func cikisYap() {
        nesil += 1 // uçuştaki/kuyruktaki gönderimler artık durum değiştiremez, yeni hesaba yazamaz
        zamanlayici?.cancel()
        zamanlayici = nil
        yerel.bulutKopya = nil
        yerel.bulutKopyaUid = nil
        yerel.eskiZaman = nil
        yerel.kirli = nil
        yerel.taban = nil
        sunucuMs = 0
        uid = nil
        guncel = nil
    }
}
