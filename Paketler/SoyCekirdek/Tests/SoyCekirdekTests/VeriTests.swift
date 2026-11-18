import Foundation
import XCTest
@testable import SoyCekirdek

final class VeriTests: XCTestCase {
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

    /// Web `load()` sırası: veri okunur, `migrateData()` çalışır.
    func gocluAgac(_ people: JSON?, _ nextId: JSON?) -> Agac {
        var a = agac(people, nextId)
        Islem.migrateData(&a)
        return a
    }

    func formu(_ j: JSON) -> KisiFormu {
        func m(_ k: String) -> String { return j[k]?.metin ?? "" }
        func o(_ k: String) -> String? { return j[k]?.metin }
        var es: [EsBag] = []
        for s in j["spouses"]?.dizi ?? [] {
            es.append(EsBag(id: s["id"]?.metin ?? "", status: s["status"]?.metin ?? ""))
        }
        return KisiFormu(id: o("id"), firstName: m("firstName"), lastName: m("lastName"), gender: m("gender"),
                         birthDate: m("birthDate"), birthPlace: m("birthPlace"), deathDate: m("deathDate"),
                         deathPlace: m("deathPlace"), deceased: j["deceased"]?.mantik ?? false,
                         occupation: m("occupation"), maidenName: m("maidenName"), notes: m("notes"),
                         mother: o("mother"), father: o("father"), photo: o("photo"),
                         gallery: (j["gallery"]?.dizi ?? []).map { $0.metin ?? "" },
                         spouses: es, children: (j["children"]?.dizi ?? []).map { $0.metin ?? "" })
    }

    /// Gerçek yedeğin web `migrateData` sonrası hâli (migrate vakasının beklenen çıktısı).
    func gercekTaban() throws -> JSON {
        let vakalar = try FixtureYukle.yukle("veri")
        guard let v = vakalar.first(where: { $0.ad == "migrate soy-agaci.json" }) else {
            throw JSON.Hata(description: "gercek taban yok")
        }
        return v.beklenen["people"] ?? .null
    }

    func gercekHam() throws -> JSON {
        let vakalar = try FixtureYukle.yukle("veri")
        guard let v = vakalar.first(where: { $0.ad == "migrate soy-agaci.json" }) else {
            throw JSON.Hata(description: "gercek ham yok")
        }
        return v.girdi["people"] ?? .null
    }

    func test_migrateFixture() throws {
        let vakalar = try FixtureYukle.yukle("veri").filter { $0.girdi["tur"]?.metin == "migrate" }
        XCTAssertGreaterThanOrEqual(vakalar.count, 8)
        for v in vakalar {
            var a = agac(v.girdi["people"], v.girdi["nextId"])
            Islem.migrateData(&a)
            XCTAssertEqual(a.people, v.beklenen["people"]?.nesne, v.ad)
            // ikinci çalıştırma değiştirmez
            let once = a
            Islem.migrateData(&a)
            XCTAssertEqual(a, once, v.ad)
        }
    }

    func test_savePersonFixture() throws {
        let vakalar = try FixtureYukle.yukle("veri").filter { $0.girdi["tur"]?.metin == "kaydet" }
        XCTAssertGreaterThanOrEqual(vakalar.count, 40)
        let taban = try gercekTaban()
        var hata = 0
        var tamam = 0
        for v in vakalar {
            var a: Agac
            if v.girdi["temel"] != nil {
                a = gocluAgac(taban, v.girdi["nextId"])
            } else {
                a = gocluAgac(v.girdi["people"], v.girdi["nextId"])
            }
            let sonuc = Islem.savePerson(formu(v.girdi["form"] ?? .null), &a)
            let b = v.beklenen["sonuc"] ?? .null
            if b["tur"]?.metin == "tamam" {
                tamam += 1
                let fotolar = (b["eskiFotolar"]?.dizi ?? []).map { $0.metin ?? "" }
                XCTAssertEqual(sonuc, .tamam(id: b["id"]?.metin ?? "", eskiFotolar: fotolar), v.ad)
            } else {
                hata += 1
                XCTAssertEqual(sonuc, .hata(b["mesaj"]?.metin ?? ""), v.ad)
            }
            XCTAssertEqual(a.people, v.beklenen["people"]?.nesne, v.ad)
            XCTAssertEqual(a.nextId, Int(v.beklenen["nextId"]?.sayi ?? -1), v.ad)
        }
        XCTAssertGreaterThanOrEqual(hata, 8)
        XCTAssertGreaterThanOrEqual(tamam, 30)
    }

    func test_delPFixture() throws {
        let vakalar = try FixtureYukle.yukle("veri").filter { $0.girdi["tur"]?.metin == "sil" }
        XCTAssertGreaterThanOrEqual(vakalar.count, 20)
        let taban = try gercekTaban()
        for v in vakalar {
            var a: Agac
            if v.girdi["temel"] != nil {
                a = gocluAgac(taban, v.girdi["nextId"])
            } else {
                a = gocluAgac(v.girdi["people"], v.girdi["nextId"])
            }
            Islem.delP(v.girdi["id"]?.metin ?? "", &a)
            XCTAssertEqual(a.people, v.beklenen["people"]?.nesne, v.ad)
            XCTAssertEqual(a.nextId, Int(v.beklenen["nextId"]?.sayi ?? -1), v.ad)
        }
    }

    func test_yardimcilarFixture() throws {
        let vakalar = try FixtureYukle.yukle("veri")
        var kisiSayisi = 0
        for v in vakalar where v.girdi["tur"]?.metin == "yardimci" {
            kisiSayisi += 1
            guard let ham = v.girdi["kisi"]?.nesne else { XCTFail(v.ad); continue }
            let k = Kisi(ham)
            XCTAssertEqual(Islem.isDead(k, simdi: VeriTests.simdi, takvim: VeriTests.takvim), v.beklenen["dead"]?.mantik, v.ad)
            XCTAssertEqual(Islem.initials(k), v.beklenen["ini"]?.metin, v.ad)
            XCTAssertEqual(Islem.pname(k), v.beklenen["ad"]?.metin, v.ad)
            let foto = (v.beklenen["foto"]?.dizi ?? []).map { $0.metin ?? "" }
            XCTAssertEqual(Islem.photoRefsOf(k), foto, v.ad)
        }
        XCTAssertGreaterThanOrEqual(kisiSayisi, 175)

        for v in vakalar where v.girdi["tur"]?.metin == "newId" {
            let people: JSON? = v.girdi["gercek"]?.mantik == true ? try gercekHam() : v.girdi["people"]
            var a = gocluAgac(people, v.girdi["nextId"])
            let id = Islem.newId(&a)
            XCTAssertEqual(id, v.beklenen["id"]?.metin, v.ad)
            XCTAssertEqual(a.nextId, Int(v.beklenen["nextId"]?.sayi ?? -1), v.ad)
        }

        for v in vakalar where v.girdi["tur"]?.metin == "ata" {
            let people: JSON? = v.girdi["gercek"]?.mantik == true ? try gercekHam() : v.girdi["people"]
            let a = gocluAgac(people, .number(1000))
            let kimlikler = (v.girdi["kimlikler"]?.dizi ?? []).map { $0.metin ?? "" }
            var bulunan: [String] = []
            for x in kimlikler {
                for y in kimlikler where Islem.isAncestorOf(x, y, a) { bulunan.append(x + "|" + y) }
            }
            var beklenen: [String] = []
            for c in v.beklenen["atalar"]?.dizi ?? [] {
                let p = c.dizi ?? []
                beklenen.append((p[0].metin ?? "") + "|" + (p[1].metin ?? ""))
            }
            XCTAssertEqual(bulunan, beklenen, v.ad)
            XCTAssertFalse(beklenen.isEmpty, v.ad)
        }

        for v in vakalar where v.girdi["tur"]?.metin == "foto" {
            let people: JSON? = v.girdi["gercek"]?.mantik == true ? try gercekHam() : v.girdi["people"]
            let a = gocluAgac(people, .number(1))
            let beklenen = (v.beklenen["hepsi"]?.dizi ?? []).map { $0.metin ?? "" }
            XCTAssertEqual(Islem.allPhotoRefsSirali(a), beklenen, v.ad)
            XCTAssertEqual(Islem.allPhotoRefs(a), Set(beklenen), v.ad)
        }
    }

    func test_bilinmeyenAlanKorunur() throws {
        let j = try JSON.coz("""
        {"P1":{"id":"P1","firstName":"ali","lastName":"veli","gender":"M","xyz":{"a":[1]},"children":[]}}
        """)
        var a = gocluAgac(j, .number(2))
        let sonuc = Islem.savePerson(KisiFormu(id: "P1", firstName: "ali", lastName: "veli", gender: "M", notes: "yeni not"), &a)
        XCTAssertEqual(sonuc, .tamam(id: "P1", eskiFotolar: []))
        let xyz = a.people["P1"]?["xyz"]
        XCTAssertEqual(xyz, try JSON.coz("{\"a\":[1]}"))
        XCTAssertEqual(a.people["P1"]?["notes"]?.metin, "yeni not")
        XCTAssertEqual(a.people["P1"]?["firstName"]?.metin, "Ali")
    }

    func test_eskiBicimler() throws {
        let j = try JSON.coz("""
        {"P1":{"id":"P1","firstName":"a","spouse":"P2","photo":"data:image/jpeg;base64,AAAA","gallery":["x",""]},
         "P2":{"id":"P2","firstName":"b","spouse":"P1","maritalStatus":"widowed"},
         "X7":{"id":"X7","firstName":"c"}}
        """)
        var a = gocluAgac(j, .number(3))
        let p1 = a.kisi("P1")
        XCTAssertEqual(p1?.spouses, [EsBag(id: "P2", status: "married")])
        XCTAssertEqual(a.kisi("P2")?.spouses, [EsBag(id: "P1", status: "widowed")])
        // data: fotoğrafı yok sayılmaz (web `photoRefsOf` onu da döndürür); boş galeri öğesi elenir
        XCTAssertEqual(Islem.photoRefsOf(p1!), ["data:image/jpeg;base64,AAAA", "x"])
        // önekli olmayan kimlik korunur
        XCTAssertNotNil(a.kisi("X7"))
        XCTAssertEqual(a.kisi("X7")?.id, "X7")
        // yeni kimlik "P" + nextId; var olanı atlar
        XCTAssertEqual(Islem.newId(&a), "P3")
        XCTAssertEqual(a.nextId, 4)
        // kaydet: önekli kimlikli kişi düzenlenebilir
        let s = Islem.savePerson(KisiFormu(id: "X7", firstName: "c", lastName: ""), &a)
        XCTAssertEqual(s, .tamam(id: "X7", eskiFotolar: []))
        XCTAssertEqual(a.nextId, 4)
    }

    func test_ayrikHatalar() {
        var a = Agac()
        XCTAssertEqual(Islem.savePerson(KisiFormu(), &a), .hata("⚠️ Ad veya soyad girin"))
        XCTAssertEqual(a.nextId, 1)
    }
}
