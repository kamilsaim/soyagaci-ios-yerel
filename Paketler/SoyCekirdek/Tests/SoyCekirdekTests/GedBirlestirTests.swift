import Foundation
import XCTest
@testable import SoyCekirdek

final class GedBirlestirTests: XCTestCase {
    func agac(_ people: JSON?, _ nextId: JSON?) -> Agac {
        return Agac(people: people?.nesne ?? Nesne(), nextId: Int(nextId?.sayi ?? 1))
    }

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

    func ciftler(_ j: JSON?) -> [(yeni: String, eski: String)] {
        var c: [(yeni: String, eski: String)] = []
        for p in j?.dizi ?? [] {
            let d = p.dizi ?? []
            c.append((yeni: d[0].metin ?? "", eski: d[1].metin ?? ""))
        }
        return c
    }

    func ayniMi(_ a: [(yeni: String, eski: String)], _ b: [(yeni: String, eski: String)], _ ad: String) {
        XCTAssertEqual(a.count, b.count, "\(ad): esleme sayisi")
        for i in 0..<min(a.count, b.count) where a[i].yeni != b[i].yeni || a[i].eski != b[i].eski {
            XCTFail("\(ad): esleme \(i): \(a[i]) / \(b[i])")
            return
        }
    }

    /// Her vaka icin web akisi: taban -> parseGEDEkle -> (ids, nid0).
    func hazirla(_ v: FixtureYukle.Vaka) -> (taban: Agac, a: Agac, ids: [String], nid0: Int) {
        let taban = agac(v.girdi["people"], v.girdi["nextId"])
        var a = taban
        let nid0 = a.nextId
        let ids = Gedcom.parseGEDEkle(v.girdi["metin"]?.metin ?? "", &a)
        return (taban, a, ids, nid0)
    }

    func test_eslesmeFixture() throws {
        let vakalar = try FixtureYukle.yukle("gedbirlestir")
        XCTAssertEqual(vakalar.count, 8)
        for v in vakalar {
            let h = hazirla(v)
            let b = v.beklenen
            XCTAssertEqual(h.nid0, Int(b["nid0"]?.sayi ?? -1), v.ad)
            XCTAssertEqual(h.ids, (b["ids"]?.dizi ?? []).map { $0.metin ?? "" }, v.ad)
            let esler = GedBirlestir.matchImported(h.ids, h.a)
            ayniMi(esler, ciftler(b["esler"]), v.ad)
            // gedSum: web, onizleme aninda (uygulamadan once) yeni kisiler ve eslesen eski kisiler icin
            for (kimlik, metin) in b["ozet"]?.nesne?.ciftler ?? [] {
                guard let k = h.a.kisi(kimlik) else {
                    XCTFail("\(v.ad): kisi yok \(kimlik)")
                    continue
                }
                XCTAssertEqual(GedBirlestir.gedSum(k, h.a), metin.metin ?? "", "\(v.ad) gedSum \(kimlik)")
            }
        }
    }

    func test_beklenenSayilar() throws {
        let vakalar = try FixtureYukle.yukle("gedbirlestir")
        func bul(_ ad: String) -> FixtureYukle.Vaka { return vakalar.first { $0.ad == ad }! }
        func say(_ ad: String) -> (eslesen: Int, yeni: Int, kisi: Int) {
            let h = hazirla(bul(ad))
            var a = h.a
            let esler = GedBirlestir.matchImported(h.ids, a)
            GedBirlestir.applyImported(h.ids, esler, &a)
            return (esler.count, h.ids.count - esler.count, a.people.sayisi)
        }
        let s1 = say("soy-agaci.json + saim-soy.ged")
        XCTAssertEqual(s1.eslesen, 24)
        XCTAssertEqual(s1.yeni, 0)
        XCTAssertEqual(s1.kisi, 147)
        let s2 = say("soy-agaci.json + heritage.ged")
        XCTAssertEqual(s2.eslesen, 145)
        XCTAssertEqual(s2.yeni, 1)
        XCTAssertEqual(s2.kisi, 148)
        // kendi ustune birlestirme kisi sayisini degistirmez
        XCTAssertEqual(say("soy-agaci.json + kendi GED (kendi ustune)").kisi, 147)
        XCTAssertEqual(say("saim-soy kendi ustune").kisi, 24)
        XCTAssertEqual(say("heritage kendi ustune").kisi, 146)
        // yapay yeni kuzen: tek yeni kisi, babasi agactaki eski kayit
        let kuzen = say("soy-agaci.json + yeni kuzen")
        XCTAssertEqual(kuzen.yeni, 1)
        XCTAssertEqual(kuzen.kisi, 148)
        let h = hazirla(bul("soy-agaci.json + yeni kuzen"))
        var a = h.a
        let esler = GedBirlestir.matchImported(h.ids, a)
        GedBirlestir.applyImported(h.ids, esler, &a)
        let yeniKimlik = h.ids.first { id in !esler.contains { $0.yeni == id } }!
        let k = a.kisi(yeniKimlik)!
        XCTAssertEqual(k.firstName, "Yeni Kuzen")
        XCTAssertNotNil(k.father)
        XCTAssertTrue(h.taban.kisi(k.father ?? "") != nil, "baba eski agactaki kayit olmali")
    }

    func test_uygulaFixture() throws {
        for v in try FixtureYukle.yukle("gedbirlestir") {
            let h = hazirla(v)
            let b = v.beklenen
            let esler = GedBirlestir.matchImported(h.ids, h.a)
            var a = h.a
            let sayi = GedBirlestir.applyImported(h.ids, esler, &a)
            let u = agac(b["uygula"]?["people"], b["uygula"]?["nextId"])
            XCTAssertEqual(sayi, Int(b["uygula"]?["sayi"]?.sayi ?? -1), v.ad)
            XCTAssertEqual(a.nextId, u.nextId, v.ad)
            esitMi(a.people, u.people, v.ad)

            // isareti kaldirilmis ciftler: map'ten cikar -> ayri kisi
            var kalan = esler
            let kaldir = (v.girdi["kaldir"]?.dizi ?? []).map { Int($0.sayi ?? -1) }
            for i in kaldir.sorted(by: >) where i >= 0 && i < kalan.count { kalan.remove(at: i) }
            ayniMi(kalan, ciftler(b["kaldirUygula"]?["esler"]), v.ad + " kalan")
            var a2 = h.a
            let sayi2 = GedBirlestir.applyImported(h.ids, kalan, &a2)
            let k = agac(b["kaldirUygula"]?["people"], b["kaldirUygula"]?["nextId"])
            XCTAssertEqual(sayi2, Int(b["kaldirUygula"]?["sayi"]?.sayi ?? -1), v.ad + " kaldir")
            XCTAssertEqual(a2.nextId, k.nextId, v.ad)
            esitMi(a2.people, k.people, v.ad + " kaldir")
        }
    }

    func test_iptalAyniBirakir() throws {
        for v in try FixtureYukle.yukle("gedbirlestir") {
            var h = hazirla(v)
            XCTAssertNotEqual(h.a, h.taban, v.ad + " (ekleme bir sey eklemis olmali)")
            GedBirlestir.iptal(h.ids, nextId0: h.nid0, &h.a)
            XCTAssertTrue(h.a == h.taban, v.ad + ": iptal sonrasi baslangicla ayni degil")
            let i = agac(v.beklenen["iptal"]?["people"], v.beklenen["iptal"]?["nextId"])
            XCTAssertEqual(h.a.nextId, i.nextId, v.ad)
            esitMi(h.a.people, i.people, v.ad + " iptal")
        }
    }
}

final class MukerrerTests: XCTestCase {
    func test_mergePeopleFixture() throws {
        let vakalar = try FixtureYukle.yukle("mukerrer").filter { $0.girdi["tur"]?.metin == "mergePeople" }
        XCTAssertEqual(vakalar.count, 15)
        for v in vakalar {
            var a = Agac(people: v.girdi["people"]?.nesne ?? Nesne(), nextId: Int(v.girdi["nextId"]?.sayi ?? 1))
            Mukerrer.mergePeople(keep: v.girdi["keep"]?.metin ?? "", drop: v.girdi["drop"]?.metin ?? "", &a)
            let b = v.beklenen["people"]?.nesne ?? Nesne()
            XCTAssertEqual(a.nextId, Int(v.beklenen["nextId"]?.sayi ?? -1), v.ad)
            if a.people.anahtarlar != b.anahtarlar {
                XCTFail("\(v.ad): kimlik sirasi farkli")
                continue
            }
            for k in b.anahtarlar where a.people[k] != b[k] {
                XCTFail("\(v.ad): \(k) farkli:\n\(a.people[k]?.metinOlarak() ?? "-")\n\(b[k]?.metinOlarak() ?? "-")")
                break
            }
        }
    }
}
