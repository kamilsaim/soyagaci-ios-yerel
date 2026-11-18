import Foundation
import XCTest
@testable import SoyCekirdek

final class MukerrerTests: XCTestCase {
    func agac(_ v: FixtureYukle.Vaka) -> Agac {
        return Agac(people: v.girdi["people"]?.nesne ?? Nesne(), nextId: Int(v.girdi["nextId"]?.sayi ?? 1))
    }

    func notDup(_ v: FixtureYukle.Vaka) -> Set<String> {
        var k = Set<String>()
        for x in v.girdi["notDup"]?.dizi ?? [] { k.insert(x.metin ?? "") }
        return k
    }

    func vakalar(_ tur: String) throws -> [FixtureYukle.Vaka] {
        return try FixtureYukle.yukle("mukerrer").filter { $0.girdi["tur"]?.metin == tur }
    }

    func esitMi(_ a: Nesne, _ b: Nesne, _ ad: String) {
        if a.anahtarlar != b.anahtarlar {
            XCTFail("\(ad): kimlik sirasi farkli")
            return
        }
        for k in b.anahtarlar where a[k] != b[k] {
            XCTFail("\(ad): \(k) farkli:\n\(a[k]?.metinOlarak() ?? "-")\n\(b[k]?.metinOlarak() ?? "-")")
            return
        }
    }

    func ciftler(_ j: JSON?) -> [MukerrerCift] {
        var c: [MukerrerCift] = []
        for x in j?.dizi ?? [] {
            c.append(MukerrerCift(a: x["a"]?.metin ?? "", b: x["b"]?.metin ?? "", key: x["key"]?.metin ?? "", puan: Int(x["score"]?.sayi ?? -1)))
        }
        return c
    }

    func test_mergePeopleFixture() throws {
        let vs = try vakalar("mergePeople")
        XCTAssertEqual(vs.count, 15)
        for v in vs {
            var a = agac(v)
            Mukerrer.mergePeople(keep: v.girdi["keep"]?.metin ?? "", drop: v.girdi["drop"]?.metin ?? "", &a)
            XCTAssertEqual(a.nextId, Int(v.beklenen["nextId"]?.sayi ?? -1), v.ad)
            esitMi(a.people, v.beklenen["people"]?.nesne ?? Nesne(), v.ad)
        }
    }

    func test_bulFixture() throws {
        let vs = try vakalar("findDupes")
        XCTAssertEqual(vs.count, 14)
        for v in vs {
            let a = agac(v)
            let bulunan = Mukerrer.findDupes(a, notDup: notDup(v))
            XCTAssertEqual(bulunan, ciftler(v.beklenen["cift"]), v.ad)
            for k in a.people.anahtarlar {
                guard let p = a.kisi(k) else { continue }
                let s = Mukerrer.dupSummary(p, a, simdi: GedcomTests.simdi, takvim: GedcomTests.takvim)
                XCTAssertEqual(s, v.beklenen["ozet"]?[k]?.metin, "\(v.ad) ozet \(k)")
            }
        }
    }

    func test_beklenenSayilar() throws {
        let vs = try vakalar("findDupes")
        func vaka(_ ad: String) -> FixtureYukle.Vaka { return vs.first { $0.ad == "findDupes " + ad }! }
        // gercek agac: farkli kusaklardan iki Hasan Saim (P21 1905 / P51) eslesmemeli; hic cift yok
        let g = vaka("gercek soy-agaci")
        XCTAssertEqual(Mukerrer.findDupes(agac(g), notDup: []).count, 0)
        // sentetik kopyalar: 5 cift, kopya turlerinden zayif ve yil farkli olanlar yok
        let s = vaka("sentetik kopyalar")
        let ss = Mukerrer.findDupes(agac(s), notDup: [])
        XCTAssertEqual(ss.map { $0.key }, ["P200|P3", "P10|P201", "P203|P56", "P202|P56", "P202|P203"])
        XCTAssertEqual(ss.map { $0.puan }, [8, 8, 8, 6, 6])
        // notDup: yalniz tam anahtar ("A|B" kucuk siralamali) eler
        let n = Mukerrer.findDupes(agac(s), notDup: ["P200|P3", "P10|P201"])
        XCTAssertEqual(n.map { $0.key }, ["P203|P56", "P202|P56", "P202|P203"])
        XCTAssertEqual(Mukerrer.findDupes(agac(s), notDup: ["P3|P200"]).count, 5)
        // JS dizgi siralamasi: "P10" < "P9"
        let d = vaka("elle dizgi siralamasi P10 P9 notDup yok")
        XCTAssertEqual(Mukerrer.findDupes(agac(d), notDup: []).map { $0.key }, ["P10|P9"])
    }

    func test_birlestirFixture() throws {
        let vs = try vakalar("bulBirlestir")
        XCTAssertEqual(vs.count, 5)
        for v in vs {
            var a = agac(v)
            let nd = notDup(v)
            for adim in v.girdi["adim"]?.dizi ?? [] {
                let d = adim.dizi ?? []
                Mukerrer.mergePeople(keep: d[0].metin ?? "", drop: d[1].metin ?? "", &a)
            }
            esitMi(a.people, v.beklenen["people"]?.nesne ?? Nesne(), v.ad)
            XCTAssertEqual(Mukerrer.findDupes(a, notDup: nd), ciftler(v.beklenen["cift"]), v.ad)
        }
    }

    func test_birlestirmeSonrasiBaglantiKalmaz() throws {
        // bul -> ilk uc cifti birlestir -> silinen kimlige hicbir baglanti kalmamali
        let vs = try vakalar("bulBirlestir") + vakalar("findDupes") + vakalar("mergePeople")
        var kontrol = 0
        for v in vs {
            var a = agac(v)
            var ciftler: [(String, String)] = []
            if v.girdi["tur"]?.metin == "mergePeople" {
                ciftler = [(v.girdi["keep"]?.metin ?? "", v.girdi["drop"]?.metin ?? "")]
            } else {
                for c in Mukerrer.findDupes(a, notDup: notDup(v)).prefix(3) { ciftler.append((c.a, c.b)) }
            }
            for (keep, drop) in ciftler where a.people[keep] != nil && a.people[drop] != nil {
                Mukerrer.mergePeople(keep: keep, drop: drop, &a)
                kontrol += 1
                XCTAssertNil(a.people[drop], "\(v.ad): \(drop) silinmedi")
                for k in a.people.anahtarlar {
                    guard case .object(let p)? = a.people[k] else { continue }
                    let id = JSON.string(drop)
                    XCTAssertNotEqual(p["father"], id, "\(v.ad): \(k).father")
                    XCTAssertNotEqual(p["mother"], id, "\(v.ad): \(k).mother")
                    XCTAssertNotEqual(p["spouse"], id, "\(v.ad): \(k).spouse")
                    for s in p["spouses"]?.dizi ?? [] { XCTAssertNotEqual(s["id"], id, "\(v.ad): \(k).spouses") }
                    XCTAssertFalse((p["children"]?.dizi ?? []).contains(id), "\(v.ad): \(k).children")
                }
            }
        }
        XCTAssertGreaterThan(kontrol, 20)
    }
}
