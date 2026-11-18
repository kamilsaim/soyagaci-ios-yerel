import Foundation
import XCTest
@testable import SoyCekirdek

final class OlaylarTests: XCTestCase {
    static let vakalar: [FixtureYukle.Vaka] = (try? FixtureYukle.yukle("olaylar")) ?? []

    func agaclar() -> [String: Agac] {
        var d: [String: Agac] = [:]
        for v in OlaylarTests.vakalar where v.girdi["tur"]?.metin == "agac" {
            d[v.girdi["ad"]?.metin ?? ""] = Agac(people: v.girdi["people"]?.nesne ?? Nesne(), nextId: Int(v.girdi["nextId"]?.sayi ?? 1))
        }
        return d
    }

    func tarih(_ ms: Double?) -> Date {
        return Date(timeIntervalSince1970: (ms ?? 0) / 1000)
    }

    func filtre(_ j: JSON?) -> OlayFiltre {
        var f = OlayFiltre()
        if let b = j?["bd"]?.mantik { f.bd = b }
        if let b = j?["an"]?.mantik { f.an = b }
        if let b = j?["bdx"]?.mantik { f.bdx = b }
        return f
    }

    /// Beklenen olaylar: tek satirlik JSON metni.
    func beklenenListe(_ v: FixtureYukle.Vaka) throws -> [JSON] {
        let ham = v.beklenen.metin ?? "[]"
        return try JSON.coz(ham).dizi ?? []
    }

    func olayKontrol(_ ev: [Olay], _ a: Agac, _ beklenen: [JSON], _ ad: String) {
        XCTAssertEqual(ev.count, beklenen.count, ad)
        if ev.count != beklenen.count { return }
        for (i, e) in ev.enumerated() {
            let b = beklenen[i]
            let ozet = "\(ad) #\(i)"
            XCTAssertEqual(e.id, b["id"]?.metin, ozet)
            XCTAssertEqual(e.diff, Int(b["diff"]?.sayi ?? -999), ozet)
            XCTAssertEqual(e.date.timeIntervalSince1970 * 1000, b["t"]?.sayi, ozet)
            XCTAssertEqual(e.kind, b["kind"]?.metin, ozet)
            XCTAssertEqual(e.n, Int(b["n"]?.sayi ?? -999), ozet)
            XCTAssertEqual(e.d, Int(b["d"]?.sayi ?? -999), ozet)
            XCTAssertEqual(e.m, Int(b["m"]?.sayi ?? -999), ozet)
            XCTAssertEqual(Olaylar.evText(e, a), b["text"]?.metin, ozet)
        }
    }

    func test_olaylarFixture() throws {
        let ag = agaclar()
        XCTAssertEqual(ag.count, 3)
        var sayac = 0
        var upcoming = 0
        for v in OlaylarTests.vakalar {
            let tur = v.girdi["tur"]?.metin
            guard let a = ag[v.girdi["agac"]?.metin ?? ""] else { continue }
            if tur == "eventsBetween" {
                let ev = Olaylar.eventsBetween(tarih(v.girdi["from"]?.sayi), Int(v.girdi["days"]?.sayi ?? 0), filtre(v.girdi["opt"]), a,
                                               takvim: GedcomTests.takvim, simdi: GedcomTests.simdi)
                olayKontrol(ev, a, try beklenenListe(v), v.ad)
                sayac += 1
            } else if tur == "upcoming" {
                let ayar = HatirlatmaAyari.oku(v.girdi["ayarHam"]?.metin)
                let ev = Olaylar.upcomingEvents(Int(v.girdi["days"]?.sayi ?? 0), a, ayar: ayar, simdi: GedcomTests.simdi, takvim: GedcomTests.takvim)
                olayKontrol(ev, a, try beklenenListe(v), v.ad)
                upcoming += 1
            }
        }
        XCTAssertEqual(sayac, 432)
        XCTAssertEqual(upcoming, 54)
    }

    func test_remSetOkuma() throws {
        var n = 0
        for v in OlaylarTests.vakalar where v.girdi["tur"]?.metin == "remSet" {
            let ham = v.girdi["ham"]?.metin
            let s = HatirlatmaAyari.oku(ham)
            let b = v.beklenen
            // Web türe bakmadan üzerine yazar; bu üç ham değerde (tür uymuyor) varsayılan beklenir.
            if ham == "{\"lead\":\"3\"}" || ham == "{\"bd\":0}" || ham == "{\"lead\":2.5}" {
                XCTAssertEqual(s, HatirlatmaAyari(), v.ad)
            } else {
                XCTAssertEqual(s, HatirlatmaAyari(bd: b["bd"]?.mantik ?? false, an: b["an"]?.mantik ?? false,
                                                  lead: Int(b["lead"]?.sayi ?? -1), alert: b["alert"]?.mantik ?? false), v.ad)
            }
            n += 1
        }
        XCTAssertEqual(n, 12)
        XCTAssertEqual(HatirlatmaAyari(), HatirlatmaAyari(bd: true, an: true, lead: 1, alert: true))
        // Codable: eksik alanlar varsayılan
        let c = try JSONDecoder().decode(HatirlatmaAyari.self, from: Data("{\"lead\":7}".utf8))
        XCTAssertEqual(c, HatirlatmaAyari(bd: true, an: true, lead: 7, alert: true))
    }

    func test_planFixture() throws {
        let ag = agaclar()
        var n = 0
        for v in OlaylarTests.vakalar where v.girdi["tur"]?.metin == "plan" {
            guard let a = ag[v.girdi["agac"]?.metin ?? ""] else { XCTFail("agac yok: " + v.ad); continue }
            let ay = v.girdi["ayar"]
            let ayar = HatirlatmaAyari(bd: ay?["bd"]?.mantik ?? true, an: ay?["an"]?.mantik ?? true,
                                       lead: Int(ay?["lead"]?.sayi ?? 1), alert: ay?["alert"]?.mantik ?? true)
            let simdi = tarih(v.girdi["simdi"]?.sayi)
            let plan: [PlanliBildirim]
            if let saat = v.girdi["saat"]?.sayi {
                plan = Olaylar.notificationPlan(a, ayar: ayar, hour: Int(saat), simdi: simdi, takvim: GedcomTests.takvim)
            } else {
                plan = Olaylar.notificationPlan(a, ayar: ayar, simdi: simdi, takvim: GedcomTests.takvim)
            }
            let b = try beklenenListe(v)
            XCTAssertEqual(plan.count, b.count, v.ad)
            if plan.count == b.count {
                for (i, p) in plan.enumerated() {
                    XCTAssertEqual(p.id, Int(b[i]["id"]?.sayi ?? -1), "\(v.ad) #\(i)")
                    XCTAssertEqual(p.at.timeIntervalSince1970 * 1000, b[i]["at"]?.sayi, "\(v.ad) #\(i)")
                    XCTAssertEqual(p.title, b[i]["title"]?.metin, "\(v.ad) #\(i)")
                    XCTAssertEqual(p.body, b[i]["body"]?.metin, "\(v.ad) #\(i)")
                    XCTAssertEqual(p.personId, b[i]["personId"]?.metin, "\(v.ad) #\(i)")
                }
            }
            n += 1
        }
        XCTAssertEqual(n, 165)
    }

    func test_yerTutucuAtlanir() throws {
        guard let a = agaclar()["elle olaylar"] else { return XCTFail("agac yok") }
        var f = OlayFiltre()
        f.bdx = true
        let tum = Olaylar.eventsBetween(GedcomTests.simdi, 366, f, a, takvim: GedcomTests.takvim, simdi: GedcomTests.simdi)
        // 01/07/1950 doğum (PH1), 1.7.1930 (PH6), 01/07/1959 (PH4), 01/07/1955+ölüm 01/07/2010 (PH3): yok
        for kimlik in ["PH1", "PH3", "PH4", "PH6"] {
            XCTAssertFalse(tum.contains { $0.id == kimlik }, kimlik)
        }
        // 01/07 ölüm (PH5) anma günü olarak yok, ama 14/09 doğum günü var
        XCTAssertFalse(tum.contains { $0.id == "PH5" && $0.kind == "an" })
        XCTAssertTrue(tum.contains { $0.id == "PH5" && ($0.kind == "bd" || $0.kind == "bdx") })
        // 01/07/1960 yer tutucu değil (yıl < 1960 koşulu)
        XCTAssertTrue(tum.contains { $0.id == "PH2" && $0.kind == "bd" })
        // Plan da aynı kuralı uygular
        let plan = Olaylar.notificationPlan(a, ayar: HatirlatmaAyari(), simdi: GedcomTests.simdi, takvim: GedcomTests.takvim)
        XCTAssertFalse(plan.contains { ["PH1", "PH3", "PH4", "PH6"].contains($0.personId) })
        XCTAssertFalse(plan.contains { $0.personId == "PH5" && $0.title.contains("vefat") })
    }

    func test_artikGunVeTasma() throws {
        guard let a = agaclar()["elle olaylar"] else { return XCTFail("agac yok") }
        let t = GedcomTests.takvim
        func ids(_ from: String, _ gun: Int) -> [String] {
            let f = ISO8601DateFormatter()
            let d = f.date(from: from) ?? Date()
            return Olaylar.eventsBetween(d, gun, OlayFiltre(), a, takvim: t, simdi: GedcomTests.simdi).map { $0.id }
        }
        // 2027 artık değil: 29 Şubat doğumları (L1, L3) ve 29/02 ölüm (L2) Şubat 2027'de görünmez
        let s27 = ids("2027-02-01T00:00:00Z", 40)
        XCTAssertFalse(s27.contains("L1"))
        XCTAssertFalse(s27.contains("L2"))
        XCTAssertTrue(s27.contains("S1"))
        // 2028 artık: görünür
        let s28 = ids("2028-02-01T00:00:00Z", 40)
        XCTAssertTrue(s28.contains("L1"))
        XCTAssertTrue(s28.contains("L2"))
        // geçersiz günler hiç yok
        let yil = ids("2026-11-18T00:00:00Z", 366) + ids("2027-11-18T00:00:00Z", 366)
        for k in ["I1", "I2", "I3", "I6", "I7"] { XCTAssertFalse(yil.contains(k), k) }
        XCTAssertTrue(yil.contains("I4"))
        XCTAssertTrue(yil.contains("I5"))
        XCTAssertFalse(yil.contains("Y1"))
    }

    func test_iosIlk60() throws {
        guard let a = agaclar()["yuz elli kisi"] else { return XCTFail("agac yok") }
        let plan = Olaylar.notificationPlan(a, ayar: HatirlatmaAyari(), simdi: GedcomTests.simdi, takvim: GedcomTests.takvim)
        XCTAssertGreaterThan(plan.count, 60)
        let ilk = Array(plan.prefix(60))
        XCTAssertEqual(ilk.count, 60)
        for i in 1..<ilk.count { XCTAssertLessThanOrEqual(ilk[i - 1].at, ilk[i].at, "tarihe göre sıralı") }
        // Tüm plan da tarihe göre sıralı ve hepsi gelecekte
        for i in 1..<plan.count { XCTAssertLessThanOrEqual(plan[i - 1].at, plan[i].at) }
        for p in plan { XCTAssertGreaterThan(p.at, GedcomTests.simdi) }
        // web ilk 60'ı ile birebir
        var bulundu = 0
        for v in OlaylarTests.vakalar where v.ad == "plan yuz elli kisi 2026-11-18T09:00:00Z bd=true an=true lead=1 saat=9" {
            bulundu += 1
            let b = try beklenenListe(v)
            for i in 0..<60 {
                XCTAssertEqual(ilk[i].id, Int(b[i]["id"]?.sayi ?? -1))
                XCTAssertEqual(ilk[i].personId, b[i]["personId"]?.metin)
            }
        }
        XCTAssertEqual(bulundu, 1, "web ilk-60 vakasi bulunamadi")
    }

    func test_simdiVeSinirlar() throws {
        guard let a = agaclar()["elle olaylar"] else { return XCTFail("agac yok") }
        // simdi 09:00 UTC; E1 18/11 doğum günü bugün, lead 0 -> at == simdi tam 09:00 -> alınmaz (at > simdi)
        let plan0 = Olaylar.notificationPlan(a, ayar: HatirlatmaAyari(bd: true, an: true, lead: 0, alert: true), simdi: GedcomTests.simdi, takvim: GedcomTests.takvim)
        XCTAssertFalse(plan0.contains { $0.personId == "E1" })
        // lead 1 ise dünkü 09:00 geçmişte -> yok
        let plan1 = Olaylar.notificationPlan(a, ayar: HatirlatmaAyari(), simdi: GedcomTests.simdi, takvim: GedcomTests.takvim)
        XCTAssertFalse(plan1.contains { $0.personId == "E1" })
        // id'ler filtrelemeden önceki sıra: boşluklu ve artan
        for i in 1..<plan1.count { XCTAssertLessThan(plan1[i - 1].id, plan1[i].id) }
    }

    func test_istanbulGunSiniri() throws {
        var ist = Calendar(identifier: .gregorian)
        ist.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let ham = "{\"A\":{\"id\":\"A\",\"firstName\":\"Bir\",\"birthDate\":\"25/12/1980\"},\"B\":{\"id\":\"B\",\"firstName\":\"Iki\",\"birthDate\":\"26/12/1990\"}}"
        let a = Agac(people: try JSON.coz(ham).nesne ?? Nesne(), nextId: 3)
        // 2026-12-25T23:30Z = İstanbul'da 26 Aralık 02:30
        let from = Date(timeIntervalSince1970: 1_798_241_400)
        let ev = Olaylar.eventsBetween(from, 5, OlayFiltre(), a, takvim: ist, simdi: from)
        XCTAssertEqual(ev.first?.id, "B")
        XCTAssertEqual(ev.first?.diff, 0)
        XCTAssertEqual(ev.first?.d, 26)
        XCTAssertFalse(ev.contains { $0.id == "A" }, "25 Aralık İstanbul'da geçmişte")
        // UTC takvimle aynı an 25 Aralık: A bugün
        let utc = Olaylar.eventsBetween(from, 5, OlayFiltre(), a, takvim: GedcomTests.takvim, simdi: from)
        XCTAssertEqual(utc.first?.id, "A")
        XCTAssertEqual(utc.first?.diff, 0)
    }
}
