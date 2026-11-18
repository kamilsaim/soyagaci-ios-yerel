import Foundation
import XCTest
@testable import SoyCekirdek

final class EDevletTests: XCTestCase {
    static let vakalar: [FixtureYukle.Vaka] = (try? FixtureYukle.yukle("edevlet")) ?? []

    // Sabit fixture saati: 2026-11-18T09:00:00Z, UTC takvim
    static let simdi = Date(timeIntervalSince1970: 1_794_992_400)
    static var takvim: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func secili(_ onek: String) -> [FixtureYukle.Vaka] {
        let l = EDevletTests.vakalar.filter { $0.ad.hasPrefix(onek) }
        XCTAssertFalse(l.isEmpty, "fixture bos: \(onek)")
        return l
    }

    func metinler(_ j: JSON?) -> [String] {
        return (j?.dizi ?? []).map { $0.metin ?? "" }
    }

    func izgara(_ j: JSON?) -> [[String]] {
        return (j?.dizi ?? []).map { metinler($0) }
    }

    func kisi(_ j: JSON) -> EDKisi {
        func m(_ k: String) -> String { return j[k]?.metin ?? "" }
        var k = EDKisi(sira: Int(j["sira"]?.sayi ?? 0))
        k.cinsiyet = m("cinsiyet")
        k.relationship = m("relationship")
        k.givn = m("givn")
        k.surn = m("surn")
        k.babaAdi = m("babaAdi")
        k.anaAdi = m("anaAdi")
        k.birthPlace = m("birthPlace")
        k.birthDate = m("birthDate")
        k.il = m("il")
        k.ilce = m("ilce")
        k.mahalle = m("mahalle")
        k.cilt = m("cilt")
        k.hane = m("hane")
        k.birey = m("birey")
        k.medeniHal = m("medeniHal")
        k.status = m("status")
        k.deathDate = m("deathDate")
        return k
    }

    func kisiler(_ j: JSON?) -> [EDKisi] {
        return (j?.dizi ?? []).map { kisi($0) }
    }

    func parca(_ j: JSON) -> PdfParca {
        let str: String = j["str"]?.metin ?? ""
        let x: Double = j["x"]?.sayi ?? 0
        let y: Double = j["y"]?.sayi ?? 0
        let w: Double = j["w"]?.sayi ?? 0
        let h: Double = j["h"]?.sayi ?? 0
        return PdfParca(str: str, x: x, y: y, w: w, h: h)
    }

    // MARK: textToGrid

    func test_metinIzgaraFixture() {
        for v in secili("metin:") {
            let g = EDevlet.textToGrid(v.girdi["metin"]?.metin ?? "")
            let b = izgara(v.beklenen["izgara"])
            XCTAssertEqual(g, b, v.ad)
        }
    }

    // MARK: gridToPersons

    func test_kisilerFixture() {
        for v in secili("kisiler:") {
            let g = EDevlet.gridToPersons(izgara(v.girdi["izgara"]))
            let b = kisiler(v.beklenen["kisiler"])
            XCTAssertEqual(g.count, b.count, v.ad)
            for (i, x) in g.enumerated() where i < b.count && x != b[i] {
                XCTFail("\(v.ad) #\(i): \(x) / \(b[i])")
                break
            }
        }
    }

    // MARK: analyze

    func ebeveyn(_ j: JSON?) -> EDEbeveyn? {
        guard let j = j, j != .null else { return nil }
        if j["tur"]?.metin == "dugum" { return .dugum(Int(j["i"]?.sayi ?? -1)) }
        let anahtar: String = j["anahtar"]?.metin ?? ""
        let ad: String = j["ad"]?.metin ?? ""
        let cins: String = j["cins"]?.metin ?? ""
        let cocuk: Int = Int(j["cocuk"]?.sayi ?? -1)
        return .hayali(anahtar: anahtar, ad: ad, cins: cins, cocuk: cocuk)
    }

    func test_analizFixture() {
        for v in secili("analiz:") {
            let a = EDevlet.analyze(kisiler(v.girdi["kisiler"]))
            let b = v.beklenen["dugumler"]?.dizi ?? []
            XCTAssertEqual(a.nodes.count, b.count, v.ad)
            XCTAssertEqual(a.warns, metinler(v.beklenen["uyarilar"]), v.ad)
            if a.nodes.count != b.count { continue }
            for (i, n) in a.nodes.enumerated() {
                let e = b[i]
                XCTAssertEqual(n.kisi.sira, Int(e["sira"]?.sayi ?? -1), "\(v.ad) #\(i) sira")
                XCTAssertEqual(n.path, e["yol"]?.metin, "\(v.ad) #\(i) yol")
                XCTAssertEqual(n.sex, e["cins"]?.metin, "\(v.ad) #\(i) cins")
                XCTAssertEqual(n.given, e["ad"]?.metin, "\(v.ad) #\(i) ad")
                let tok = (e["tok"]?.dizi ?? []).map { EDTok(t: $0["t"]?.metin ?? "", sex: $0["sex"]?.metin) }
                XCTAssertEqual(n.toks, tok, "\(v.ad) #\(i) tok")
                XCTAssertEqual(n.father, ebeveyn(e["baba"]), "\(v.ad) #\(i) baba")
                XCTAssertEqual(n.mother, ebeveyn(e["anne"]), "\(v.ad) #\(i) anne")
            }
        }
    }

    /// Web'de beklenen sayilar: soyagaci.xlsx ve kamilsoyagaci.docx -> 22 kisi + 23 adi bilinen ebeveyn;
    /// mustafa saim soy.xlsx -> 19 kisi, uyarisiz (fixture'in kendisinden dogrulanir).
    func test_dosyaSayilari() {
        var olculen: [String: (Int, Int, Int)] = [:]
        for v in secili("analiz: dosya") {
            let a = EDevlet.analyze(kisiler(v.girdi["kisiler"]))
            var anahtarlar = Set<String>()
            for n in a.nodes {
                for e in [n.father, n.mother] {
                    if case .hayali(let k, _, _, _)? = e { anahtarlar.insert(k) }
                }
            }
            olculen[v.ad] = (a.nodes.count, anahtarlar.count, a.warns.count)
        }
        XCTAssertEqual(olculen["analiz: dosya soyagaci.xlsx"]?.0, 22)
        XCTAssertEqual(olculen["analiz: dosya soyagaci.xlsx"]?.1, 23)
        XCTAssertEqual(olculen["analiz: dosya kamilsoyagaci.docx"]?.0, 22)
        XCTAssertEqual(olculen["analiz: dosya kamilsoyagaci.docx"]?.1, 23)
        XCTAssertEqual(olculen["analiz: dosya mustafa saim soy.xlsx"]?.0, 19)
        XCTAssertEqual(olculen["analiz: dosya mustafa saim soy.xlsx"]?.2, 0)
    }

    // MARK: buildGedcom

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

    func test_gedcomFixture() {
        for v in secili("gedcom:") {
            var opt = EDSecenek()
            if let o = v.girdi["secenek"], o != .null {
                opt = EDSecenek(tc: o["tc"]?.mantik ?? true, ghost: o["ghost"]?.mantik ?? true,
                                maiden: o["maiden"]?.mantik ?? true, note: o["note"]?.mantik ?? true)
            }
            let analiz = EDevlet.analyze(kisiler(v.girdi["kisiler"]))
            let g = EDevlet.buildGedcom(analiz, opt: opt, simdi: EDevletTests.simdi, takvim: EDevletTests.takvim)
            metinFarki(g, v.beklenen["ged"]?.metin ?? "", v.ad)
        }
    }

    // MARK: pdfItemsToGrid

    func test_pdfIzgaraFixture() {
        for v in secili("pdf:") {
            let sayfalar: [[PdfParca]] = (v.girdi["sayfalar"]?.dizi ?? []).map { ($0.dizi ?? []).map { parca($0) } }
            let g = EDevlet.pdfItemsToGrid(sayfalar)
            let bj = v.beklenen["izgara"]
            if bj == .null || bj == nil {
                XCTAssertNil(g, v.ad)
            } else {
                XCTAssertEqual(g, izgara(bj), v.ad)
            }
        }
    }

    // MARK: relTokens / titleCase / gedDate

    func test_relTokensFixture() {
        for v in secili("reltok:") {
            let r = v.girdi["rel"]?.metin ?? ""
            let b = v.beklenen["tok"]
            if b == .null || b == nil {
                XCTAssertNil(EDevlet.relTokens(r), v.ad)
                XCTAssertNil(EDevlet.relTokenler(r), v.ad)
            } else {
                let tok = (b?.dizi ?? []).map { EDTok(t: $0["t"]?.metin ?? "", sex: $0["sex"]?.metin) }
                XCTAssertEqual(EDevlet.relTokenler(r) ?? [], tok, v.ad)
                XCTAssertEqual(EDevlet.relTokens(r) ?? [], tok.map { $0.t }, v.ad)
            }
        }
    }

    func test_titleCaseFixture() {
        for v in secili("titleCase:") {
            XCTAssertEqual(EDevlet.titleCase(v.girdi["s"]?.metin ?? ""), v.beklenen["s"]?.metin, v.ad)
        }
    }

    func test_gedDateFixture() {
        for v in secili("gedDate:") {
            XCTAssertEqual(EDevlet.gedDate(v.girdi["s"]?.metin ?? ""), v.beklenen["s"]?.metin, v.ad)
        }
    }
}
