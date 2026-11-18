import XCTest
@testable import SoyCekirdek

final class BellekYerel: YerelDeposu {
    var bulutKopya: Agac?
    var bulutKopyaUid: String?
    var yerelMod: Agac?
    var kirli: String?
    var taban: Date?
    var eskiZaman: Date?
}

struct SahteHata: Error {}

final class SahteBulut: BulutDeposu {
    var satir: BulutSatiri?
    var okuHata = false
    var yazHata = false
    var okuSayisi = 0
    var yazilanlar: [Agac] = []
    var sayac = 0

    func oku(uid: String) async throws -> BulutSatiri? {
        okuSayisi += 1
        if okuHata { throw SahteHata() }
        return satir
    }

    func yaz(uid: String, agac: Agac) async throws -> Date {
        if yazHata { throw SahteHata() }
        yazilanlar.append(agac)
        sayac += 1
        let t = Date(timeIntervalSince1970: 2_000_000_000 + Double(sayac) * 10)
        satir = BulutSatiri(agac: agac, updatedAt: t)
        return t
    }
}

final class EsitlemeTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func agac(_ adlar: [String]) -> Agac {
        var a = Agac()
        for (i, ad) in adlar.enumerated() {
            let id = "P\(i + 1)"
            a.people[id] = .object(Nesne([("id", .string(id)), ("firstName", .string(ad))]))
        }
        a.nextId = adlar.count + 1
        return a
    }

    func kur(gecikme: TimeInterval = 0.02) -> (Esitleyici, SahteBulut, BellekYerel) {
        let b = SahteBulut()
        let y = BellekYerel()
        let e = Esitleyici(bulut: b, yerel: y, gecikme: gecikme,
                           simdi: { Date(timeIntervalSince1970: 1_800_000_000) })
        return (e, b, y)
    }

    func adlar(_ a: Agac) -> [String] {
        return a.people.ciftler.map { $0.1["firstName"]?.metin ?? "" }
    }

    // Web load() 2): kirli degil, bulutta veri var -> bulut kazanir (saat farkina bakilmaz)
    func test_temizAcilisBulutKazanir() async {
        let (e, b, y) = kur()
        b.satir = BulutSatiri(agac: agac(["Bulut1", "Bulut2"]), updatedAt: t0)
        y.bulutKopya = agac(["Eski"])
        y.bulutKopyaUid = "u1"
        y.taban = t0
        y.eskiZaman = t0
        let s = await e.yukle(uid: "u1")
        XCTAssertEqual(s.kaynak, .bulut)
        XCTAssertEqual(adlar(s.agac), ["Bulut1", "Bulut2"])
        XCTAssertFalse(s.cakisma)
        XCTAssertTrue(b.yazilanlar.isEmpty)
    }

    // Web load() 1): sa4_dirty==uid -> yerel kazanir, _serverTs=sa4_base, save() ile yeniden gonderilir
    func test_kirliYerelKazanir_tabanAyarlanir() async {
        let (e, b, y) = kur()
        b.satir = BulutSatiri(agac: agac(["Bulut"]), updatedAt: t0)
        y.bulutKopya = agac(["Yerel1", "Yerel2"])
        y.bulutKopyaUid = "u1"
        y.kirli = "u1"
        y.taban = t0
        let s = await e.yukle(uid: "u1")
        XCTAssertEqual(s.kaynak, .yerel)
        XCTAssertEqual(adlar(s.agac), ["Yerel1", "Yerel2"])
        XCTAssertFalse(s.cakisma)
        XCTAssertEqual(y.taban, t0)
        XCTAssertEqual(y.kirli, "u1")
        await e.beklenenleriBitir()
        XCTAssertEqual(b.yazilanlar.count, 1)
        XCTAssertEqual(adlar(b.yazilanlar[0]), ["Yerel1", "Yerel2"])
        XCTAssertNil(y.kirli)
    }

    // Web load() 1) + pushToCloud: arada baska cihaz yazdiysa (bulut > taban+2s) yerel kazanir ama
    // gonderim sormadan ezmez -> cakisma
    func test_aradaBaskaCihazYazdi_cakismaBildirilir_ezilmez() async {
        let (e, b, y) = kur()
        b.satir = BulutSatiri(agac: agac(["Baska"]), updatedAt: t0.addingTimeInterval(100))
        y.bulutKopya = agac(["Yerel"])
        y.bulutKopyaUid = "u1"
        y.kirli = "u1"
        y.taban = t0
        let s = await e.yukle(uid: "u1")
        XCTAssertTrue(s.cakisma)
        await e.beklenenleriBitir()
        XCTAssertTrue(b.yazilanlar.isEmpty, "cakismada bulut ezilmemeli")
        XCTAssertEqual(y.kirli, "u1")
        // kullanici "evet" derse zorla yazilir
        let g = await e.gonder(zorla: true)
        if case .tamam = g {} else { XCTFail("tamam bekleniyordu") }
        XCTAssertEqual(adlar(b.yazilanlar[0]), ["Yerel"])
        XCTAssertNil(y.kirli)
    }

    // Web pushToCloud `!ok` dali: kullanici "hayir" -> yerel birakilir, bulut surumu yuklenir
    func test_cakismadaHayir_bulutYuklenir() async {
        let (e, b, y) = kur()
        b.satir = BulutSatiri(agac: agac(["Baska"]), updatedAt: t0.addingTimeInterval(100))
        y.bulutKopya = agac(["Yerel"])
        y.bulutKopyaUid = "u1"
        y.kirli = "u1"
        y.taban = t0
        _ = await e.yukle(uid: "u1")
        await e.beklenenleriBitir()
        let s = await e.bulutuKabulEt()
        XCTAssertEqual(s.kaynak, .bulut)
        XCTAssertEqual(adlar(s.agac), ["Baska"])
        XCTAssertNil(y.kirli)
        XCTAssertTrue(b.yazilanlar.isEmpty)
    }

    // Web load(): bulut okunamazsa yerel gosterilir, buluta ITILMEZ
    func test_bulutOkunamazsaYerelGosterilirItilmez() async {
        let (e, b, y) = kur()
        b.okuHata = true
        y.bulutKopya = agac(["Yerel"])
        y.bulutKopyaUid = "u1"
        let s = await e.yukle(uid: "u1")
        XCTAssertEqual(s.kaynak, .yerelOkunamadi)
        XCTAssertEqual(adlar(s.agac), ["Yerel"])
        await e.beklenenleriBitir()
        XCTAssertTrue(b.yazilanlar.isEmpty)
        XCTAssertNil(y.kirli)
    }

    // Web v5.2: cihaz saati (sa4_ts) farki baska cihazin degisikliklerini silemez:
    // sa4_base varsa eski zaman damgasi kurali uygulanmaz; yoksa (v5.1 oncesi) bir kereligine uygulanir
    func test_saatFarkiBaskaCihaziSilmez() async {
        let (e, b, y) = kur()
        b.satir = BulutSatiri(agac: agac(["Bulut"]), updatedAt: t0)
        y.bulutKopya = agac(["Yerel"])
        y.bulutKopyaUid = "u1"
        y.taban = t0
        y.eskiZaman = t0.addingTimeInterval(86400)
        let s = await e.yukle(uid: "u1")
        XCTAssertEqual(s.kaynak, .bulut)
        XCTAssertEqual(adlar(s.agac), ["Bulut"])

        let (e2, b2, y2) = kur()
        b2.satir = BulutSatiri(agac: agac(["Bulut"]), updatedAt: t0)
        y2.bulutKopya = agac(["Yerel"])
        y2.bulutKopyaUid = "u1"
        y2.eskiZaman = t0.addingTimeInterval(10)
        let s2 = await e2.yukle(uid: "u1")
        XCTAssertEqual(s2.kaynak, .yerel)
        XCTAssertFalse(s2.cakisma)
    }

    // Web _readLocalSnap: sa4 yedegi baska kullaniciya aitse yok sayilir
    func test_baskaKullaniciYedegiYokSayilir() async {
        let (e, b, y) = kur()
        b.satir = BulutSatiri(agac: agac(["Bulut"]), updatedAt: t0)
        y.bulutKopya = agac(["Baskasi"])
        y.bulutKopyaUid = "u2"
        y.kirli = "u1"
        y.taban = t0
        let s = await e.yukle(uid: "u1")
        XCTAssertEqual(adlar(s.agac), ["Bulut"])
    }

    // Web load() 3): bulut bos, yerelde veri var -> yerelden geri yukle ve gonder
    func test_bulutBosYerelDoluGeriYuklenir() async {
        let (e, b, y) = kur()
        b.satir = BulutSatiri(agac: Agac(), updatedAt: t0)
        y.bulutKopya = agac(["Yerel"])
        y.bulutKopyaUid = "u1"
        let s = await e.yukle(uid: "u1")
        XCTAssertEqual(s.kaynak, .yerel)
        await e.beklenenleriBitir()
        XCTAssertEqual(b.yazilanlar.count, 1)
    }

    // Web save()+pushToCloud: yazma hatasi -> sa4_dirty kalir; sonraki gonder basarili olunca temizlenir
    func test_cevrimdisiDuzenlemeSonraGider() async {
        let (e, b, y) = kur()
        b.satir = BulutSatiri(agac: agac(["A"]), updatedAt: t0)
        _ = await e.yukle(uid: "u1")
        b.yazHata = true
        await e.kaydet(agac(["A", "B"]))
        await e.beklenenleriBitir()
        XCTAssertEqual(y.kirli, "u1")
        XCTAssertEqual(y.bulutKopya?.people.sayisi, 2)
        b.yazHata = false
        let g = await e.gonder(zorla: false)
        if case .tamam = g {} else { XCTFail("tamam bekleniyordu") }
        XCTAssertNil(y.kirli)
        XCTAssertEqual(b.yazilanlar.count, 1)
        XCTAssertEqual(b.yazilanlar[0].people.sayisi, 2)
    }

    // Web save(): _saveGen - art arda kayitlarda yalniz en son anlik goruntu gider
    func test_eskiNesilAtlanir() async {
        let (e, b, y) = kur(gecikme: 0.05)
        b.satir = BulutSatiri(agac: agac(["A"]), updatedAt: t0)
        _ = await e.yukle(uid: "u1")
        await e.kaydet(agac(["A", "B"]))
        await e.kaydet(agac(["A", "B", "C"]))
        await e.kaydet(agac(["A", "B", "C", "D"]))
        await e.beklenenleriBitir()
        XCTAssertEqual(b.yazilanlar.count, 1)
        XCTAssertEqual(b.yazilanlar[0].people.sayisi, 4)
        XCTAssertNil(y.kirli)
    }

    // Web pushToCloud: ayri ayri kaydedilen iki kayit sirayla gider
    func test_ardisikKayitlarSirayla() async {
        let (e, b, _) = kur(gecikme: 0.01)
        b.satir = BulutSatiri(agac: agac(["A"]), updatedAt: t0)
        _ = await e.yukle(uid: "u1")
        await e.kaydet(agac(["A", "B"]))
        await e.beklenenleriBitir()
        await e.kaydet(agac(["A", "B", "C"]))
        await e.beklenenleriBitir()
        XCTAssertEqual(b.yazilanlar.map { $0.people.sayisi }, [2, 3])
    }

    // Web save(): supaUser yoksa yalniz sa4_local yazilir; load() yerel modda bulut cagrilmaz
    func test_girissizYerelMod() async {
        let (e, b, y) = kur()
        y.yerelMod = agac(["Yerel"])
        let s = await e.yukle(uid: nil)
        XCTAssertEqual(adlar(s.agac), ["Yerel"])
        XCTAssertEqual(s.kaynak, .yerel)
        await e.kaydet(agac(["Yerel", "Yeni"]))
        await e.beklenenleriBitir()
        XCTAssertEqual(y.yerelMod?.people.sayisi, 2)
        XCTAssertNil(y.kirli)
        XCTAssertNil(y.bulutKopya)
        XCTAssertEqual(b.okuSayisi, 0)
        XCTAssertTrue(b.yazilanlar.isEmpty)
    }

    // Web signOut: bekleyen kayit hemen gonderilir; temizse true
    func test_cikistaBekleyenGonderilir() async {
        let (e, b, y) = kur(gecikme: 5)
        b.satir = BulutSatiri(agac: agac(["A"]), updatedAt: t0)
        _ = await e.yukle(uid: "u1")
        await e.kaydet(agac(["A", "B"]))
        let tamam = await e.cikisaHazirla()
        XCTAssertTrue(tamam)
        XCTAssertEqual(b.yazilanlar.count, 1)
        XCTAssertNil(y.kirli)
    }

    // Web signOut: buluta gitmemis degisiklik kalirsa kullaniciya sorulur -> false; cikis yerel izleri siler
    func test_cikistaKirliSorulur() async {
        let (e, b, y) = kur(gecikme: 5)
        b.satir = BulutSatiri(agac: agac(["A"]), updatedAt: t0)
        _ = await e.yukle(uid: "u1")
        b.yazHata = true
        await e.kaydet(agac(["A", "B"]))
        let tamam = await e.cikisaHazirla()
        XCTAssertFalse(tamam)
        XCTAssertEqual(y.kirli, "u1")
        await e.cikisYap()
        XCTAssertNil(y.kirli)
        XCTAssertNil(y.bulutKopya)
        XCTAssertNil(y.taban)
        XCTAssertNil(y.eskiZaman)
    }
}
