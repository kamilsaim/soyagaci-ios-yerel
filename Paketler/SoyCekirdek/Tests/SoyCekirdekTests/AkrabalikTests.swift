import Foundation
import XCTest
@testable import SoyCekirdek

final class AkrabalikTests: XCTestCase {
    static let vakalar: [FixtureYukle.Vaka] = (try? FixtureYukle.yukle("akrabalik")) ?? []

    /// Fixture'daki agaclar (`tur == "agac"` vakalari).
    func agaclar() -> [String: Agac] {
        var s: [String: Agac] = [:]
        for v in AkrabalikTests.vakalar where v.girdi["tur"]?.metin == "agac" {
            s[v.girdi["agac"]?.metin ?? ""] = Agac(people: v.beklenen["people"]?.nesne ?? Nesne(),
                                                    nextId: Int(v.beklenen["nextId"]?.sayi ?? 1))
        }
        return s
    }

    func metinVeyaNil(_ j: JSON?) -> String? {
        guard let j = j else { return nil }
        if case .null = j { return nil }
        return j.metin
    }

    func sonucKarsilastir(_ r: AkrabalikSonuc?, _ b: JSON?, _ ad: String) {
        guard let b = b, b.nesne != nil else {
            XCTAssertNil(r, "\(ad): kinship nil olmali")
            return
        }
        guard let r = r else {
            XCTFail("\(ad): kinship nil dondu")
            return
        }
        XCTAssertEqual(r.ayni, b["self"]?.mantik ?? false, "\(ad): self")
        XCTAssertEqual(r.words, (b["words"]?.dizi ?? []).map { $0.metin ?? "" }, "\(ad): words")
        XCTAssertEqual(r.note, b["note"]?.metin ?? "", "\(ad): note")
        XCTAssertEqual(r.common, metinVeyaNil(b["common"]), "\(ad): common")
        XCTAssertEqual(r.chain, b["chain"]?.mantik ?? false, "\(ad): chain")
    }

    func ciftVakalari(_ turler: Set<String>) -> [FixtureYukle.Vaka] {
        return AkrabalikTests.vakalar.filter { turler.contains($0.girdi["tur"]?.metin ?? "") }
    }

    func test_cumleFixture() {
        let ag = agaclar()
        XCTAssertEqual(ag.count, 4)
        let vakalar = ciftVakalari(["cift"])
        XCTAssertEqual(vakalar.count, 2742)
        var modeller: [String: AileModeli] = [:]
        for (ad, a) in ag { modeller[ad] = AileModeli(a) }
        var sayac = 0
        for v in vakalar {
            let adAgac = v.girdi["agac"]?.metin ?? ""
            let a = v.girdi["a"]?.metin ?? ""
            let b = v.girdi["b"]?.metin ?? ""
            guard let m = modeller[adAgac] else { XCTFail("agac yok \(adAgac)"); continue }
            XCTAssertEqual(Akrabalik.kinSentence(a, b, m), metinVeyaNil(v.beklenen["cumle"]), v.ad)
            XCTAssertEqual(Akrabalik.kinPhrase(a, b, m), metinVeyaNil(v.beklenen["kisi"]), v.ad)
            // Agac alan sarmalayici (her 7. vakada)
            if sayac % 7 == 0, let agac = ag[adAgac] {
                XCTAssertEqual(Akrabalik.kinSentence(a, b, agac), metinVeyaNil(v.beklenen["cumle"]), v.ad)
                XCTAssertEqual(Akrabalik.kinPhrase(a, b, agac), metinVeyaNil(v.beklenen["kisi"]), v.ad)
            }
            sayac += 1
        }
    }

    func test_kinshipFixture() {
        let ag = agaclar()
        var modeller: [String: AileModeli] = [:]
        for (ad, a) in ag { modeller[ad] = AileModeli(a) }
        var zincir = 0
        var kelimeler = Set<String>()
        for v in ciftVakalari(["cift", "ayni", "yok"]) {
            let adAgac = v.girdi["agac"]?.metin ?? ""
            guard let m = modeller[adAgac], let agac = ag[adAgac] else { XCTFail("agac yok"); continue }
            let a = v.girdi["a"]?.metin ?? ""
            let b = v.girdi["b"]?.metin ?? ""
            let r = Akrabalik.kinship(a, b, m)
            sonucKarsilastir(r, v.beklenen["kin"], v.ad)
            if let r = r {
                if r.chain { zincir += 1 }
                for k in r.words { kelimeler.insert(k) }
            }
            if a == "P3" || a == "P1" {
                sonucKarsilastir(Akrabalik.kinship(a, b, agac), v.beklenen["kin"], v.ad + " (agac)")
            }
        }
        XCTAssertGreaterThan(zincir, 100)
        for k in ["dede", "babaanne", "anneanne", "abi", "abla", "bababir", "annebir", "amca", "hala", "dayi", "teyze", "yegen", "kuzen",
                  "kayinpeder", "kayinvalide", "kayinbirader", "baldiz", "gorumce", "gelin", "damat", "yenge", "eniste", "elti", "bacanak",
                  "uveyanne", "uveybaba", "uveyogul", "uveykiz", "eskies"] {
            XCTAssertTrue(kelimeler.contains(k), "fixture \(k) dalini vurmuyor")
        }
    }

    func test_genOfFixture() {
        var n = 0
        for v in AkrabalikTests.vakalar where v.girdi["tur"]?.metin == "genOf" {
            XCTAssertEqual(Akrabalik.genOf(v.girdi["ad"]?.metin ?? ""), v.beklenen.metin, v.ad)
            n += 1
        }
        XCTAssertEqual(n, 66)
        XCTAssertEqual(Akrabalik.genOf("Kamil"), "Kamil'in")
        XCTAssertEqual(Akrabalik.genOf("Ayşe"), "Ayşe'nin")
        XCTAssertEqual(Akrabalik.genOf("Mustafa"), "Mustafa'nın")
        XCTAssertEqual(Akrabalik.genOf("Ümmügülsün"), "Ümmügülsün'ün")
        XCTAssertEqual(Akrabalik.genOf(""), "Bu kişi'nin")
    }

    func test_ayniKisi() {
        let ag = agaclar()
        let vakalar = ciftVakalari(["ayni"])
        XCTAssertEqual(vakalar.count, 5)
        for v in vakalar {
            let adAgac = v.girdi["agac"]?.metin ?? ""
            guard let agac = ag[adAgac] else { XCTFail("agac yok"); continue }
            let a = v.girdi["a"]?.metin ?? ""
            let b = v.girdi["b"]?.metin ?? ""
            let cumle = Akrabalik.kinSentence(a, b, agac)
            XCTAssertEqual(cumle, metinVeyaNil(v.beklenen["cumle"]), v.ad)
            XCTAssertEqual(Akrabalik.kinPhrase(a, b, agac), metinVeyaNil(v.beklenen["kisi"]), v.ad)
            // Kisi varsa web "Aynı kişi" dondurur, yoksa null (cokme yok)
            if agac.kisi(a) != nil { XCTAssertEqual(cumle, "Aynı kişi", v.ad) } else { XCTAssertNil(cumle, v.ad) }
            XCTAssertEqual(Akrabalik.kinship(a, b, agac)?.ayni, agac.kisi(a) != nil ? true : nil, v.ad)
        }
    }

    func test_bagsizKisiler() {
        // el yapimi: iki bagsiz kisi, olmayan kimlik
        func k(_ id: String, _ ad: String, _ g: String) -> JSON {
            return .object(Nesne([("id", .string(id)), ("firstName", .string(ad)), ("gender", .string(g)),
                                  ("birthDate", .string("")), ("spouses", .array([])), ("children", .array([]))]))
        }
        let agac = Agac(people: Nesne([("P1", k("P1", "Ali", "M")), ("P2", k("P2", "Ayşe", "F"))]), nextId: 3)
        XCTAssertNil(Akrabalik.kinship("P1", "P2", agac))
        XCTAssertNil(Akrabalik.kinSentence("P1", "P2", agac))
        XCTAssertNil(Akrabalik.kinPhrase("P1", "P2", agac))
        XCTAssertNil(Akrabalik.bloodLink("P1", "P2", agac))
        XCTAssertNil(Akrabalik.kinship("P1", "P9", agac))
        XCTAssertNil(Akrabalik.kinSentence("P9", "P1", agac))
        XCTAssertEqual(Akrabalik.kinSentence("P1", "P1", agac), "Aynı kişi")
        // fixture'daki bagsiz/olmayan vakalar
        let ag = agaclar()
        var nullSayisi = 0
        for v in ciftVakalari(["yok", "cift"]) {
            guard v.beklenen["kin"]?.nesne == nil, let agac = ag[v.girdi["agac"]?.metin ?? ""] else { continue }
            let a = v.girdi["a"]?.metin ?? ""
            let b = v.girdi["b"]?.metin ?? ""
            XCTAssertNil(Akrabalik.kinship(a, b, agac), v.ad)
            XCTAssertNil(Akrabalik.kinSentence(a, b, agac), v.ad)
            XCTAssertNil(Akrabalik.kinPhrase(a, b, agac), v.ad)
            nullSayisi += 1
        }
        XCTAssertGreaterThan(nullSayisi, 250)
    }

    func test_bloodLinkYapisi() {
        let ag = agaclar()
        guard let agac = ag["elle1"] else { return XCTFail("elle1 yok") }
        // P1 Ibrahim, P4 Mehmet'in oglu... P6 = Mehmet(P4) ; Ibrahim(P1) -> Mehmet(P4): a=0, b=1
        let l = Akrabalik.bloodLink("P1", "P4", agac)
        XCTAssertEqual(l?.a, 0)
        XCTAssertEqual(l?.b, 1)
        XCTAssertEqual(l?.downB, ["P4"])
        XCTAssertEqual(l?.upA, [])
        // kardesler: P4 (Mehmet) ve P5 (Ayse): a=1,b=1, x=P1 (baba once)
        let k = Akrabalik.bloodLink("P4", "P5", agac)
        XCTAssertEqual(k?.a, 1)
        XCTAssertEqual(k?.b, 1)
        XCTAssertEqual(k?.x, "P1")
        XCTAssertEqual(k?.upA, ["P1"])
        XCTAssertEqual(k?.downB, ["P5"])
        let s = Akrabalik.bloodLink("P4", "P4", agac)
        XCTAssertEqual(s?.a, 0)
        XCTAssertEqual(s?.b, 0)
        XCTAssertNil(s?.x)
    }
}
