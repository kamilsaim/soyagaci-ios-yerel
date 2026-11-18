import Foundation
import XCTest
@testable import SoyCekirdek

final class YerlesimTests: XCTestCase {
    static let vakalar: [FixtureYukle.Vaka] = (try? FixtureYukle.yukle("yerlesim")) ?? []
    static let agaclar: [String: Agac] = {
        var s: [String: Agac] = [:]
        for v in vakalar where v.girdi["tur"]?.metin == "agac" {
            s[v.girdi["agac"]?.metin ?? ""] = Agac(people: v.beklenen["people"]?.nesne ?? Nesne(),
                                                    nextId: Int(v.beklenen["nextId"]?.sayi ?? 1))
        }
        return s
    }()
    static let modeller: [String: AileModeli] = {
        var s: [String: AileModeli] = [:]
        for (ad, a) in agaclar { s[ad] = AileModeli(a) }
        return s
    }()

    func turVakalari(_ tur: String) -> [FixtureYukle.Vaka] {
        return YerlesimTests.vakalar.filter { $0.girdi["tur"]?.metin == tur }
    }

    /// "id|x|y|satir" dizgileri
    func coz(_ j: JSON?) -> [String: (x: Double, y: Double, row: Int)] {
        var s: [String: (x: Double, y: Double, row: Int)] = [:]
        for e in j?.dizi ?? [] {
            let p = (e.metin ?? "").split(separator: "|", omittingEmptySubsequences: false).map { String($0) }
            guard p.count == 4, let x = Double(p[1]), let y = Double(p[2]), let r = Int(p[3]) else {
                XCTFail("bozuk dugum: \(e.metin ?? "?")")
                continue
            }
            s[p[0]] = (x, y, r)
        }
        return s
    }

    func karsilastir(_ y: Yerlesim, _ b: JSON?, _ ad: String) {
        let beklenen = coz(b)
        XCTAssertEqual(Set(y.nodePos.keys), Set(beklenen.keys), "\(ad): dugum kumesi")
        XCTAssertEqual(Set(y.nodeRow.keys), Set(beklenen.keys), "\(ad): satir kumesi")
        for (id, e) in beklenen {
            guard let p = y.nodePos[id] else { continue }
            XCTAssertEqual(p.x, e.x, accuracy: 0.001, "\(ad) \(id).x")
            XCTAssertEqual(p.y, e.y, accuracy: 0.001, "\(ad) \(id).y")
            XCTAssertEqual(y.nodeRow[id], e.row, "\(ad) \(id).row")
        }
    }

    func test_ailelerFixture() {
        let vakalar = turVakalari("aileler")
        XCTAssertEqual(vakalar.count, 10)
        var kisiAileSayisi = 0
        for v in vakalar {
            let ad = v.girdi["agac"]?.metin ?? ""
            guard let agac = YerlesimTests.agaclar[ad] else { XCTFail("agac yok \(ad)"); continue }
            let m = Agacla.buildFamilies(agac)
            let bek = v.beklenen["aileler"]?.dizi ?? []
            XCTAssertEqual(m.aileler.count, bek.count, "\(ad): aile sayisi")
            for (i, b) in bek.enumerated() where i < m.aileler.count {
                let f = m.aileler[i]
                XCTAssertEqual(f.key, b["key"]?.metin, "\(ad) #\(i) key")
                XCTAssertEqual(f.a, b["a"]?.metin, "\(ad) #\(i) a")
                let bb: String? = b["b"]?.metin
                XCTAssertEqual(f.b, bb, "\(ad) #\(i) b")
                XCTAssertEqual(f.status, b["status"]?.metin, "\(ad) #\(i) status")
                XCTAssertEqual(f.kids, (b["kids"]?.dizi ?? []).map { $0.metin ?? "" }, "\(ad) #\(i) kids")
                XCTAssertEqual(m.aileIndeks[f.key], i, "\(ad) aileIndeks \(f.key)")
            }
            let fo = v.beklenen["famOf"]?.nesne ?? Nesne()
            XCTAssertEqual(Set(m.famOf.keys), Set(fo.anahtarlar), "\(ad): famOf anahtarlari")
            for (id, liste) in fo.ciftler {
                let anahtarlar = (m.famOf[id] ?? []).map { m.aileler[$0].key }
                XCTAssertEqual(anahtarlar, (liste.dizi ?? []).map { $0.metin ?? "" }, "\(ad): famOf \(id)")
                kisiAileSayisi += anahtarlar.count
            }
            let pf = v.beklenen["parentFam"]?.nesne ?? Nesne()
            XCTAssertEqual(Set(m.parentFam.keys), Set(pf.anahtarlar), "\(ad): parentFam anahtarlari")
            for (id, k) in pf.ciftler {
                if let i = m.parentFam[id] { XCTAssertEqual(m.aileler[i].key, k.metin, "\(ad): parentFam \(id)") }
            }
        }
        XCTAssertGreaterThan(kisiAileSayisi, 500)
    }

    /// Cinsiyet alani eksik (JS undefined) ile "" ayni degildir
    func test_pairKeyHamCinsiyet() {
        guard let agac = YerlesimTests.agaclar["ham"] else { return XCTFail("ham agac yok") }
        let m = AileModeli(agac)
        XCTAssertEqual(Agacla.pairKey("P7", "P5", m), "P7|P5") // "" ile alan-yok esit degil: yer degismez
        XCTAssertEqual(Agacla.pairKey("P5", "P7", m), "P5|P7")
        XCTAssertEqual(Agacla.pairKey("P5", "P3", m), "P3|P5") // ikisi de alan-yok: kimlige gore
        XCTAssertEqual(Agacla.pairKey("P3", "P5", m), "P3|P5")
        XCTAssertEqual(Agacla.pairKey("P3", "P14", m), "P3|P14") // alan-yok != null
        XCTAssertEqual(Agacla.pairKey("P14", "P3", m), "P14|P3")
        XCTAssertEqual(Agacla.pairKey("P2", "P1", m), "P1|P2") // kadin + erkek: erkek onde
        XCTAssertEqual(Agacla.pairKey("P1", nil, m), "P1|")
        XCTAssertEqual(Agacla.pairKey(nil, "P2", m), "P2|")
    }

    func test_tumAgacFixture() {
        let vakalar = turVakalari("tum")
        XCTAssertEqual(vakalar.count, 10)
        var toplamDugum = 0
        for v in vakalar {
            let ad = v.girdi["agac"]?.metin ?? ""
            guard let agac = YerlesimTests.agaclar[ad], let m = YerlesimTests.modeller[ad] else { XCTFail("agac yok \(ad)"); continue }
            let y = Agacla.layoutFull(agac, m)
            karsilastir(y, v.beklenen["dugumler"], "tum \(ad)")
            toplamDugum += y.nodePos.count
        }
        XCTAssertGreaterThan(toplamDugum, 500)
    }

    func test_odakFixture() {
        let vakalar = turVakalari("odak")
        XCTAssertEqual(vakalar.count, 30)
        var sayac = 0
        for v in vakalar {
            let ad = v.girdi["agac"]?.metin ?? ""
            let up = Int(v.girdi["up"]?.sayi ?? 3)
            let down = Int(v.girdi["down"]?.sayi ?? 2)
            guard let agac = YerlesimTests.agaclar[ad], let m = YerlesimTests.modeller[ad] else { XCTFail("agac yok \(ad)"); continue }
            let tum = v.beklenen.nesne ?? Nesne()
            XCTAssertEqual(tum.sayisi, m.sira.count, "\(ad): kisi sayisi")
            for (id, dugumler) in tum.ciftler {
                let y = Agacla.layoutFocus(id, upGen: up, downGen: down, agac, m)
                karsilastir(y, dugumler, "odak \(ad) \(up)/\(down) \(id)")
                sayac += 1
            }
        }
        XCTAssertEqual(sayac, 1953)
    }

    func test_odakKisiOrtada() {
        guard let agac = YerlesimTests.agaclar["soy"], let m = YerlesimTests.modeller["soy"] else { return XCTFail() }
        for id in m.sira {
            let y = Agacla.layoutFocus(id, upGen: 3, downGen: 2, agac, m)
            XCTAssertEqual(y.nodeRow[id], 0, id)
            XCTAssertEqual(y.nodePos[id]?.x ?? 1, -Agacla.NW / 2, accuracy: 0.001, id)
        }
    }

    func test_tumAgactaCakismaYok() {
        for (ad, agac) in YerlesimTests.agaclar {
            guard let m = YerlesimTests.modeller[ad] else { continue }
            let y = Agacla.layoutFull(agac, m)
            XCTAssertEqual(y.nodePos.count, m.sira.count, "\(ad): herkes yerlesmeli")
            var satirlar: [Int: [Double]] = [:]
            for (id, p) in y.nodePos { satirlar[y.nodeRow[id] ?? 0, default: []].append(p.x) }
            for (satir, xs) in satirlar {
                let sirali = xs.sorted()
                if sirali.count < 2 { continue }
                for i in 1..<sirali.count {
                    XCTAssertGreaterThanOrEqual(sirali[i] - sirali[i - 1], Agacla.NW + Agacla.HGAP / 2 - 0.001, "\(ad) satir \(satir)")
                }
            }
        }
    }

    func test_bosVeTekKisi() {
        guard let bos = YerlesimTests.agaclar["bos"], let tek = YerlesimTests.agaclar["tek"] else { return XCTFail() }
        let mb = AileModeli(bos)
        XCTAssertTrue(Agacla.layoutFull(bos, mb).nodePos.isEmpty)
        XCTAssertNil(Agacla.defaultFocus(bos, mb))
        XCTAssertTrue(Agacla.layoutFocus("P1", upGen: 3, downGen: 2, bos, mb).nodePos.isEmpty)
        XCTAssertNil(Agacla.lineageOf("P1", bos, mb))
        let mt = AileModeli(tek)
        let o = Agacla.layoutFocus("P1", upGen: 3, downGen: 2, tek, mt)
        XCTAssertEqual(o.nodePos.count, 1)
        XCTAssertEqual(o.nodePos["P1"], Nokta(x: -59, y: 0))
        XCTAssertEqual(o.nodeRow["P1"], 0)
        XCTAssertEqual(Agacla.defaultFocus(tek, mt), "P1")
        let t = Agacla.layoutFull(tek, mt)
        XCTAssertEqual(t.nodePos["P1"], Nokta(x: 0, y: 0))
    }

    func test_varsayilanOdakVeSoy() {
        let v1 = turVakalari("varsayilan")
        XCTAssertEqual(v1.count, 10)
        for v in v1 {
            let ad = v.girdi["agac"]?.metin ?? ""
            guard let agac = YerlesimTests.agaclar[ad], let m = YerlesimTests.modeller[ad] else { XCTFail(); continue }
            var bek: String?
            if let s = v.beklenen["id"]?.metin { bek = s }
            XCTAssertEqual(Agacla.defaultFocus(agac, m), bek, "varsayilan \(ad)")
        }
        let v2 = turVakalari("soy")
        XCTAssertGreaterThan(v2.count, 150)
        var bosKume = 0
        for v in v2 {
            let ad = v.girdi["agac"]?.metin ?? ""
            let id = v.girdi["kisi"]?.metin ?? ""
            guard let agac = YerlesimTests.agaclar[ad], let m = YerlesimTests.modeller[ad] else { XCTFail(); continue }
            let r = Agacla.lineageOf(id, agac, m)
            if let dizi = v.beklenen["kume"]?.dizi {
                XCTAssertEqual(r, Set(dizi.map { $0.metin ?? "" }), "soy \(ad) \(id)")
            } else {
                XCTAssertNil(r, "soy \(ad) \(id)")
                bosKume += 1
            }
        }
        XCTAssertGreaterThanOrEqual(bosKume, 10)
    }

    func test_normDrag() {
        let vakalar = turVakalari("normDrag")
        XCTAssertEqual(vakalar.count, 13)
        for v in vakalar {
            XCTAssertEqual(Agacla.normDrag(v.girdi["d"] ?? .null), v.beklenen, v.ad)
        }
    }

    /// Gercek agaclarda ulasilamayan duzeltme gecisi: elle cakistirilmis yerlesim
    func test_ayniSatirDuzeltCakisan() {
        var d = Yerlesim()
        d.yerles("A", 100, 0, 0)
        d.yerles("B", 100, 0, 0)   // ayni x: ekleme sirasi korunur
        d.yerles("C", 150, 0, 0)
        d.yerles("D", 0, 186, 1)
        d.yerles("E", 10, 186, 1)
        d.yerles("F", 500, 186, 1)  // yeterince uzak: degismez
        Agacla.ayniSatirDuzelt(&d)
        let a = Agacla.NW + Agacla.HGAP / 2
        XCTAssertEqual(d.nodePos["A"]?.x, 100)
        XCTAssertEqual(d.nodePos["B"]?.x ?? 0, 100 + a, accuracy: 1e-9)
        XCTAssertEqual(d.nodePos["C"]?.x ?? 0, 100 + 2 * a, accuracy: 1e-9)
        XCTAssertEqual(d.nodePos["D"]?.x, 0)
        XCTAssertEqual(d.nodePos["E"]?.x ?? 0, a, accuracy: 1e-9)
        XCTAssertEqual(d.nodePos["F"]?.x, 500)
        XCTAssertEqual(d.sira, ["A", "B", "C", "D", "E", "F"])
    }

    func test_rowLabelFixture() {
        let vakalar = turVakalari("etiket")
        XCTAssertEqual(vakalar.count, 6)
        for v in vakalar {
            let odak = v.girdi["mod"]?.metin == "focus"
            for (k, b) in v.beklenen.nesne?.ciftler ?? [] {
                XCTAssertEqual(Agacla.rowLabel(Int(k) ?? 0, odak: odak), b.metin, "\(v.ad) \(k)")
            }
        }
        XCTAssertEqual(Agacla.rowLabel(-1, odak: true), "Anne · Baba")
        XCTAssertEqual(Agacla.rowLabel(2, odak: false), "3. Kuşak")
    }

    func test_layoutBoundsFixture() {
        let vakalar = turVakalari("sinir")
        XCTAssertEqual(vakalar.count, 14)
        for v in vakalar {
            let ad = v.girdi["agac"]?.metin ?? ""
            guard let agac = YerlesimTests.agaclar[ad], let m = YerlesimTests.modeller[ad] else { XCTFail("agac yok"); continue }
            var y: Yerlesim
            var drag: [String: Nokta] = [:]
            if v.girdi["mod"]?.metin == "focus" {
                y = Yerlesim()
                if let f = v.girdi["odak"]?.metin { y = Agacla.layoutFocus(f, upGen: 3, downGen: 2, agac, m) }
            } else {
                y = Agacla.layoutFull(agac, m)
                for (id, o) in v.girdi["drag"]?.nesne?.ciftler ?? [] {
                    drag[id] = Nokta(x: o["dx"]?.sayi ?? 0, y: o["dy"]?.sayi ?? 0)
                }
            }
            karsilastir(y, v.beklenen["dugumler"], v.ad)
            let b = Agacla.layoutBounds(y, drag: drag)
            if let e = v.beklenen["b"], e.nesne != nil {
                guard let b = b else { XCTFail("\(v.ad): sinir nil"); continue }
                XCTAssertEqual(b.minX, e["minX"]?.sayi ?? .nan, accuracy: 0.001, v.ad)
                XCTAssertEqual(b.maxX, e["maxX"]?.sayi ?? .nan, accuracy: 0.001, v.ad)
                XCTAssertEqual(b.minY, e["minY"]?.sayi ?? .nan, accuracy: 0.001, v.ad)
                XCTAssertEqual(b.maxY, e["maxY"]?.sayi ?? .nan, accuracy: 0.001, v.ad)
            } else {
                XCTAssertNil(b, v.ad)
            }
        }
    }

    func test_sabitler() {
        XCTAssertEqual(Agacla.ROWH, 186)
        XCTAssertEqual(Agacla.NW, 118)
        XCTAssertEqual(Agacla.NH, 128)
        XCTAssertEqual(Agacla.HGAP, 16)
        XCTAssertEqual(Agacla.SPGAP, 30)
        XCTAssertEqual(Agacla.VGAP, 58)
        XCTAssertEqual(Agacla.AVR, 30)
        XCTAssertEqual(Agacla.AVC, 36)
    }
}
