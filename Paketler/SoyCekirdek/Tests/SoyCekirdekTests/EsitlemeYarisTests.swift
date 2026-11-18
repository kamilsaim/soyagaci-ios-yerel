import XCTest
@testable import SoyCekirdek

/// yaz() bir devam noktasında bekler; test `birakIlk()` ile sürdürür (uyku yok).
final class KilitliBulut: BulutDeposu, @unchecked Sendable {
    private let kilit = NSLock()
    private var bekleyenler: [CheckedContinuation<Void, Never>] = []
    private var yazilan: [(String, Agac)] = []
    private var sayac = 0
    var satir: BulutSatiri?

    func oku(uid: String) async throws -> BulutSatiri? {
        return satir
    }

    private func kaydet(_ c: CheckedContinuation<Void, Never>) {
        kilit.lock()
        bekleyenler.append(c)
        kilit.unlock()
    }

    private func zaman(_ uid: String, _ agac: Agac) -> Date {
        kilit.lock()
        defer { kilit.unlock() }
        yazilan.append((uid, agac))
        sayac += 1
        return Date(timeIntervalSince1970: 2_000_000_000 + Double(sayac) * 10)
    }

    func yaz(uid: String, agac: Agac) async throws -> Date {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            self.kaydet(c)
        }
        let t = zaman(uid, agac)
        satir = BulutSatiri(agac: agac, updatedAt: t)
        return t
    }

    var bekleyenSayisi: Int {
        kilit.lock()
        defer { kilit.unlock() }
        return bekleyenler.count
    }

    var yazilanlar: [(String, Agac)] {
        kilit.lock()
        defer { kilit.unlock() }
        return yazilan
    }

    func birakIlk() {
        kilit.lock()
        let c = bekleyenler.isEmpty ? nil : bekleyenler.removeFirst()
        kilit.unlock()
        c?.resume()
    }

    /// Bekleyen yaz() sayısı `n` olana kadar (yield ile) bekler.
    func bekle(_ n: Int) async {
        while bekleyenSayisi < n { await Task.yield() }
    }
}

final class EsitlemeYarisTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func agac(_ n: Int) -> Agac {
        var a = Agac()
        for i in 0..<n {
            let id = "P\(i + 1)"
            a.people[id] = .object(Nesne([("id", .string(id)), ("firstName", .string("K\(i)"))]))
        }
        a.nextId = n + 1
        return a
    }

    func kur(gecikme: TimeInterval) -> (Esitleyici, KilitliBulut, BellekYerel) {
        let b = KilitliBulut()
        b.satir = BulutSatiri(agac: agac(1), updatedAt: t0)
        let y = BellekYerel()
        let e = Esitleyici(bulut: b, yerel: y, gecikme: gecikme,
                           simdi: { Date(timeIntervalSince1970: 1_800_000_000) })
        return (e, b, y)
    }

    // Web pushToCloud: `if(!gen||gen===_saveGen)` - ucustaki yazma sirasinda yeni save() olduysa
    // sa4_dirty ve sa4_base KALIR (yeni veri henuz bulutta degil)
    func test_kaydetUcusEsnasinda_kirliKalir_tabanIlerlemez() async {
        let (e, b, y) = kur(gecikme: 0.01)
        _ = await e.yukle(uid: "u1")
        await e.kaydet(agac(2))
        await b.bekle(1)              // A ucusta
        await e.kaydet(agac(3))       // B: nesil ilerledi
        b.birakIlk()                  // A biter
        await b.bekle(1)              // B'nin yazmasi basladi => A tamamen bitti
        XCTAssertEqual(y.kirli, "u1")
        XCTAssertEqual(y.taban, t0)
        b.birakIlk()
        await e.beklenenleriBitir()
        XCTAssertNil(y.kirli)
        XCTAssertEqual(b.yazilanlar.map { $0.1.people.sayisi }, [2, 3])
    }

    // Web pushToCloud: `if(gen&&gen<_saveGen)return` - kuyruktaki eski nesil atlanir, yalniz yenisi gider
    func test_kuyruktakiEskiNesilAtlanir() async {
        let (e, b, _) = kur(gecikme: 0.01)
        _ = await e.yukle(uid: "u1")
        await e.kaydet(agac(2))
        await b.bekle(1)              // A ucusta
        await e.kaydet(agac(3))       // B: zamanlayici dolunca A'nin arkasina kuyruklanir
        try? await Task.sleep(nanoseconds: 40_000_000)
        await e.kaydet(agac(4))       // C: B artik eski nesil
        b.birakIlk()
        await b.bekle(1)              // C yaziyor
        b.birakIlk()
        await e.beklenenleriBitir()
        XCTAssertEqual(b.yazilanlar.map { $0.1.people.sayisi }, [2, 4])
    }

    // Web pushToCloud(d,true,gen): zorla gonderim de nesli tasir; ucusta kaydet olursa kirli kalir
    func test_zorlaGonderimUcusta_kaydet_kirliKalir() async {
        let (e, b, y) = kur(gecikme: 5)
        _ = await e.yukle(uid: "u1")
        await e.kaydet(agac(2))
        let g = Task { await e.gonder(zorla: true) }
        await b.bekle(1)
        await e.kaydet(agac(3))
        b.birakIlk()
        _ = await g.value
        XCTAssertEqual(y.kirli, "u1")
        XCTAssertEqual(y.bulutKopya?.people.sayisi, 3)
        await e.cikisYap()
    }

    // Hesap degisimi: u1'in agaci u2'nin satirina yazilamaz; ucustaki u1 yazmasi yeni hesabin durumunu degistirmez
    func test_hesapDegisimi_eskiHesapYeniyeYazamaz() async {
        let (e, b, y) = kur(gecikme: 0.01)
        _ = await e.yukle(uid: "u1")
        await e.kaydet(agac(2))
        await b.bekle(1)              // u1 yazmasi ucusta
        await e.kaydet(agac(3))       // kuyrukta ikinci u1 gonderimi
        try? await Task.sleep(nanoseconds: 40_000_000)
        await e.cikisYap()
        _ = await e.yukle(uid: "u2")
        b.birakIlk()
        await e.beklenenleriBitir()
        let uidler = b.yazilanlar.map { $0.0 }
        XCTAssertEqual(uidler, ["u1"], "kuyruktaki u1 gonderimi u2 oturumunda calismamali")
        XCTAssertNil(y.kirli)
        XCTAssertNil(y.taban)
    }

    // SAPMA (web'den kasitli): cakisma denetiminde bulut okunamazsa web "satir yok" sayip yazar;
    // burada .hata doner, bulut yazilmaz, kirli kalir
    func test_cakismaDenetimindeOkumaHatasi_yazilmaz() async {
        let b = SahteBulut()
        let y = BellekYerel()
        let e = Esitleyici(bulut: b, yerel: y, gecikme: 0.01)
        b.satir = BulutSatiri(agac: agac(1),
                              updatedAt: t0)
        _ = await e.yukle(uid: "u1")
        b.okuHata = true
        var it = e.durumlar.makeAsyncIterator()
        await e.kaydet(agac(2))
        let ilk = await it.next()
        XCTAssertEqual(ilk, .gonderiliyor)
        let son = await it.next()
        if case .hata? = son {} else { XCTFail("hata bekleniyordu: \(String(describing: son))") }
        XCTAssertTrue(b.yazilanlar.isEmpty)
        XCTAssertEqual(y.kirli, "u1")
        await e.cikisYap()
    }

    // Web setSync: gecikmeli gonderim sonucu UI'ya ulasir - cakisma
    func test_durumlar_cakismaBildirilir() async {
        let b = SahteBulut()
        let y = BellekYerel()
        let e = Esitleyici(bulut: b, yerel: y, gecikme: 0.01)
        b.satir = BulutSatiri(agac: agac(1), updatedAt: t0)
        _ = await e.yukle(uid: "u1")
        let baska = t0.addingTimeInterval(100)
        b.satir = BulutSatiri(agac: agac(1), updatedAt: baska)
        var it = e.durumlar.makeAsyncIterator()
        await e.kaydet(agac(2))
        let ilk = await it.next()
        XCTAssertEqual(ilk, .gonderiliyor)
        let son = await it.next()
        XCTAssertEqual(son, .cakisma(bulutZamani: baska))
        XCTAssertTrue(b.yazilanlar.isEmpty)
        await e.cikisYap()
    }

    // Web setSync('ok') / hata
    func test_durumlar_tamamVeHata() async {
        let b = SahteBulut()
        let y = BellekYerel()
        let e = Esitleyici(bulut: b, yerel: y, gecikme: 0.01)
        b.satir = BulutSatiri(agac: agac(1), updatedAt: t0)
        _ = await e.yukle(uid: "u1")
        var it = e.durumlar.makeAsyncIterator()
        await e.kaydet(agac(2))
        _ = await it.next()
        let tamam = await it.next()
        XCTAssertEqual(tamam, .tamam)
        b.yazHata = true
        await e.kaydet(agac(3))
        _ = await it.next()
        let hata = await it.next()
        if case .hata? = hata {} else { XCTFail("hata bekleniyordu") }
        await e.cikisYap()
    }

    // bulutuKabulEt kuyruğu beklerken (çakışma penceresi) gelen kaydet(), kabul edilen bulut kopyasının üstüne itmemeli
    func test_bulutuKabulEt_beklerkenKaydedilenZamanlayiciIptalEdilir() async {
        let (e, b, y) = kur(gecikme: 0.3)
        _ = await e.yukle(uid: "u1")
        await e.kaydet(agac(2))
        let g = Task { await e.gonder(zorla: true) }
        await b.bekle(1)                       // yazma ucusta
        let k = Task { await e.bulutuKabulEt() }
        try? await Task.sleep(nanoseconds: 60_000_000) // bulutuKabulEt kuyrukta bekliyor
        await e.kaydet(agac(5))                // diyalog acikken yeni kayit: zamanlayici kurulur
        b.birakIlk()
        _ = await g.value
        _ = await k.value
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(b.bekleyenSayisi, 0)
        XCTAssertEqual(b.yazilanlar.count, 1)
        XCTAssertNil(y.kirli)
        await e.cikisYap()
    }

    // durumlar: en yeni 8 tutulur, Esitleyici bitince akis kapanir
    func test_durumlarAkisi_tamponluVeDeinitteKapanir() async {
        let b = KilitliBulut()
        let y = BellekYerel()
        var e: Esitleyici? = Esitleyici(bulut: b, yerel: y, gecikme: 5)
        let akis = e!.durumlar
        _ = await e!.yukle(uid: "u1")
        for i in 0..<20 { await e!.kaydet(agac(i + 1)) }
        e = nil
        var n = 0
        for await d in akis {
            XCTAssertEqual(d, .gonderiliyor)
            n += 1
        }
        XCTAssertEqual(n, 8)
    }

    // yukle(u1) bulut okurken gelen kaydet() misafir verisidir: u1'in kirli verisi olarak SIZMAZ
    func test_yukleBulutOkurken_kaydet_yeniHesabaSizmaz() async {
        let b = OkuBekleyenBulut()
        b.satir = BulutSatiri(agac: agac(3), updatedAt: t0)
        let y = BellekYerel()
        let e = Esitleyici(bulut: b, yerel: y, gecikme: 5, simdi: { self.t0 })
        let g = Task { await e.yukle(uid: "u1") }
        await b.bekle()
        await e.kaydet(agac(7))          // misafir düzenlemesi
        b.birak()
        let s = await g.value
        XCTAssertNil(y.kirli)
        XCTAssertNil(y.bulutKopya)
        XCTAssertEqual(y.yerelMod?.people.sayisi, 7)
        XCTAssertEqual(s.kaynak, .bulut)
        XCTAssertEqual(s.agac.people.sayisi, 3)
        XCTAssertFalse(s.cakisma)
        await e.cikisYap()
    }

    // askıdaki yukle(u1) sonradan biterse, araya giren yukle(nil)'in durumunu (uid = nil) bozmaz
    func test_eskiYukleSonradanBiter_durumuBozmaz() async {
        let b = OkuBekleyenBulut()
        b.satir = BulutSatiri(agac: agac(3), updatedAt: t0)
        let y = BellekYerel()
        let e = Esitleyici(bulut: b, yerel: y, gecikme: 5, simdi: { self.t0 })
        let g = Task { await e.yukle(uid: "u1") }
        await b.bekle()
        _ = await e.yukle(uid: nil)
        b.birak()
        _ = await g.value
        await e.kaydet(agac(2))
        XCTAssertEqual(y.yerelMod?.people.sayisi, 2)
        XCTAssertNil(y.kirli)
        XCTAssertNil(y.bulutKopya)
    }
}

/// oku() bir devam noktasında bekler; test `birak()` ile sürdürür.
final class OkuBekleyenBulut: BulutDeposu, @unchecked Sendable {
    private let kilit = NSLock()
    private var devam: CheckedContinuation<Void, Never>?
    var satir: BulutSatiri?

    func oku(uid: String) async throws -> BulutSatiri? {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            kilit.lock()
            devam = c
            kilit.unlock()
        }
        return satir
    }

    func yaz(uid: String, agac: Agac) async throws -> Date { throw SahteHata() }

    var bekliyor: Bool {
        kilit.lock()
        defer { kilit.unlock() }
        return devam != nil
    }

    func bekle() async {
        while !bekliyor { await Task.yield() }
    }

    func birak() {
        kilit.lock()
        let c = devam
        devam = nil
        kilit.unlock()
        c?.resume()
    }
}
