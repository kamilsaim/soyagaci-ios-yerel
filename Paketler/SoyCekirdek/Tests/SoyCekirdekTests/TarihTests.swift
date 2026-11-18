import XCTest
@testable import SoyCekirdek

final class TarihTests: XCTestCase {
    func test_tarihFixture() throws {
        let vakalar = try FixtureYukle.yukle("tarih")
        var tarihSayisi = 0
        for v in vakalar where v.girdi["tur"]?.metin == "tarih" {
            tarihSayisi += 1
            let s = v.girdi["deger"]?.metin ?? ""
            let b = v.beklenen
            XCTAssertEqual(Tarih.normDate(s), b["norm"]?.metin, v.ad)
            XCTAssertEqual(Tarih.toGedDate(s), b["ged"]?.metin, v.ad)
            XCTAssertEqual(Tarih.yearOf(s), b["yil"]?.metin, v.ad)
            XCTAssertEqual(Tarih.fmtDate(s), b["fmt"]?.metin, v.ad)
            let parca = Tarih.dateParts(s)
            if let bp = b["parca"], bp != .null {
                XCTAssertNotNil(parca, v.ad)
                XCTAssertEqual(parca?.d, Int(bp["d"]?.sayi ?? -1), v.ad)
                XCTAssertEqual(parca?.m, Int(bp["m"]?.sayi ?? -1), v.ad)
                XCTAssertEqual(parca?.y, Int(bp["y"]?.sayi ?? -1), v.ad)
            } else {
                XCTAssertNil(parca, v.ad)
            }
            var ph = false
            if let p = parca { ph = Tarih.isPlaceholder(p) }
            XCTAssertEqual(ph, b["ph"]?.mantik, v.ad)
        }
        XCTAssertGreaterThanOrEqual(tarihSayisi, 200)
    }

    func test_capStrTurkce() throws {
        XCTAssertEqual(Metin.capStr("ismail ılgaz"), "İsmail Ilgaz")
        XCTAssertEqual(Metin.trKatla("I\u{307}x"), "ix")
        XCTAssertEqual(Metin.trKatla("IŞIK İ"), "ışık i")
        let vakalar = try FixtureYukle.yukle("tarih")
        var n = 0
        for v in vakalar where v.girdi["tur"]?.metin == "metin" {
            n += 1
            let s = v.girdi["deger"]?.metin ?? ""
            XCTAssertEqual(Metin.capStr(s), v.beklenen["capStr"]?.metin, v.ad)
            XCTAssertEqual(Metin.trKatla(s), v.beklenen["trKatla"]?.metin, v.ad)
        }
        XCTAssertGreaterThanOrEqual(n, 50)
    }
}
