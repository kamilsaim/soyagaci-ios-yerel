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
}
