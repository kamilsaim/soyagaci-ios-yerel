import Foundation
import XCTest
@testable import SoyCekirdek

final class GedcomTests: XCTestCase {
    // Sabit fixture saati: 2026-11-18T09:00:00Z, UTC takvim
    static let simdi = Date(timeIntervalSince1970: 1_794_992_400)
    static var takvim: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func agac(_ people: JSON?, _ nextId: JSON?) -> Agac {
        return Agac(people: people?.nesne ?? Nesne(), nextId: Int(nextId?.sayi ?? 1))
    }

    /// Ilk farki bildirir (anahtar sirasi dahil); dev ciktilar yerine kisa mesaj.
    func esitMi(_ a: Nesne, _ b: Nesne, _ ad: String) {
        if a.anahtarlar != b.anahtarlar {
            XCTFail("\(ad): kisi kimlik sirasi farkli: \(a.anahtarlar.prefix(8)) / \(b.anahtarlar.prefix(8))")
            return
        }
        for k in a.anahtarlar where a[k] != b[k] {
            XCTFail("\(ad): \(k) farkli:\n\(a[k]?.metinOlarak() ?? "-")\n\(b[k]?.metinOlarak() ?? "-")")
            return
        }
    }

    func metinFarki(_ a: String, _ b: String, _ ad: String) {
        if a == b { return }
        let x = a.components(separatedBy: "\n")
        let y = b.components(separatedBy: "\n")
        for i in 0..<min(x.count, y.count) where x[i] != y[i] {
            XCTFail("\(ad): satir \(i + 1) farkli: [\(x[i])] / [\(y[i])]")
            return
        }
        XCTFail("\(ad): satir sayisi farkli: \(x.count) / \(y.count)")
    }

    func vakalar(_ tur: String) throws -> [FixtureYukle.Vaka] {
        return try FixtureYukle.yukle("gedcom").filter { $0.girdi["tur"]?.metin == tur }
    }

    func test_splitGedName() {
        let kural: [(String, String, String)] = [
            ("Mehmet Ali /Kara Yilmaz/", "Mehmet Ali", "Kara Yilmaz"),
            ("Ali Veli Kara", "Ali Veli", "Kara"),
            ("Tek", "Tek", ""),
            ("/Soyad/", "", "Soyad"),
            ("Ali /K/ Jr", "Ali Jr", "K"),
            ("  Ali   Veli  /  Kara  /  ", "Ali Veli", "Kara"),
            ("Ali /Kara", "Ali", "Kara"),
            ("", "", ""),
            ("   ", "", ""),
        ]
        for (girdi, fn, ln) in kural {
            let s = Gedcom.splitGedName(girdi)
            XCTAssertEqual(s.given, fn, girdi)
            XCTAssertEqual(s.surname, ln, girdi)
        }
    }

    func test_parseFixture() throws {
        let hepsi = try vakalar("parse")
        XCTAssertEqual(hepsi.count, 5)
        for v in hepsi {
            let a = Gedcom.parseGED(v.girdi["metin"]?.metin ?? "")
            let b = agac(v.beklenen["people"], v.beklenen["nextId"])
            esitMi(a.people, b.people, v.ad)
            XCTAssertEqual(a.nextId, b.nextId, v.ad)
        }
    }

    func test_ekleFixture() throws {
        let hepsi = try vakalar("ekle")
        XCTAssertEqual(hepsi.count, 12)
        for v in hepsi {
            var a = agac(v.girdi["people"], v.girdi["nextId"])
            let ids = Gedcom.parseGEDEkle(v.girdi["metin"]?.metin ?? "", &a)
            let b = agac(v.beklenen["people"], v.beklenen["nextId"])
            XCTAssertEqual(ids, (v.beklenen["ids"]?.dizi ?? []).map { $0.metin ?? "" }, v.ad)
            esitMi(a.people, b.people, v.ad)
            XCTAssertEqual(a.nextId, b.nextId, v.ad)
        }
    }

    func test_expFixture() throws {
        let hepsi = try vakalar("yaz")
        XCTAssertEqual(hepsi.count, 7)
        for v in hepsi {
            let a = agac(v.girdi["people"], v.girdi["nextId"])
            let metin = Gedcom.expGED(a, tarih: GedcomTests.simdi, takvim: GedcomTests.takvim)
            metinFarki(metin, v.beklenen["metin"]?.metin ?? "", v.ad)
        }
    }

    func test_gidisDonusFixture() throws {
        for v in try vakalar("yaz") {
            let a = agac(v.girdi["people"], v.girdi["nextId"])
            let metin = Gedcom.expGED(a, tarih: GedcomTests.simdi, takvim: GedcomTests.takvim)
            let g = Gedcom.parseGED(metin)
            let b = agac(v.beklenen["gidis"]?["people"], v.beklenen["gidis"]?["nextId"])
            esitMi(g.people, b.people, v.ad)
            XCTAssertEqual(g.nextId, b.nextId, v.ad)
        }
    }

    /// GED -> Agac -> GED -> Agac: kisi alanlari ve sayilar korunur; (kizlik, cok satirli not, tarihsiz vefat) sayilari beklenen.
    func kayipsiz(_ ad: String, kisi: Int, kizlik: Int, cokSatirliNot: Int, tarihsizVefat: Int) throws {
        guard let v = try vakalar("parse").first(where: { $0.ad == ad }) else { return XCTFail("vaka yok: " + ad) }
        let a = Gedcom.parseGED(v.girdi["metin"]?.metin ?? "")
        XCTAssertEqual(a.people.sayisi, kisi, ad)
        let metin = Gedcom.expGED(a, tarih: GedcomTests.simdi, takvim: GedcomTests.takvim)
        let g = Gedcom.parseGED(metin)
        XCTAssertEqual(g.people.sayisi, kisi, ad)
        var sayac = [0, 0, 0, 0]
        for k in a.people.anahtarlar {
            guard let x = a.kisi(k), let y = g.kisi(k) else { return XCTFail("kisi eksik: " + k) }
            XCTAssertEqual(x.firstName, y.firstName, k)
            XCTAssertEqual(x.lastName, y.lastName, k)
            XCTAssertEqual(x.maidenName, y.maidenName, k)
            XCTAssertEqual(x.notes, y.notes, k)
            XCTAssertEqual(x.deceased, y.deceased, k)
            XCTAssertEqual(x.birthDate, y.birthDate, k)
            XCTAssertEqual(x.deathDate, y.deathDate, k)
            XCTAssertEqual(x.father, y.father, k)
            XCTAssertEqual(x.mother, y.mother, k)
            XCTAssertEqual(x.children.sorted(), y.children.sorted(), k)
            if !y.maidenName.isEmpty { sayac[0] += 1 }
            if y.notes.contains("\n") { sayac[1] += 1 }
            if y.deceased && y.deathDate.isEmpty && y.deathPlace.isEmpty { sayac[2] += 1 }
        }
        XCTAssertEqual(sayac[0], kizlik, ad)
        XCTAssertEqual(sayac[1], cokSatirliNot, ad)
        XCTAssertEqual(sayac[2], tarihsizVefat, ad)
        if tarihsizVefat > 0 { XCTAssertTrue(metin.contains("1 DEAT Y\n"), ad) }
    }

    func test_gidisDonusKayipsiz() throws {
        try kayipsiz("parse heritage.ged", kisi: 146, kizlik: 0, cokSatirliNot: 0, tarihsizVefat: 18)
        try kayipsiz("parse saim-soy.ged", kisi: 24, kizlik: 0, cokSatirliNot: 0, tarihsizVefat: 3)
        try kayipsiz("parse edevlet-soy-Mustafa.ged", kisi: 35, kizlik: 2, cokSatirliNot: 19, tarihsizVefat: 12)
    }
}
