import XCTest
@testable import SoyCekirdek

final class JSONTests: XCTestCase {
    func test_jsonSiraKorunur() throws {
        let metin = "{\"b\":1,\"a\":2,\"c\":{\"z\":[1,2,{\"y\":null,\"x\":true}],\"m\":\"s\"}}"
        let j = try JSON.coz(metin)
        XCTAssertEqual(j.metinOlarak(), metin)
        XCTAssertEqual(j.nesne?.anahtarlar, ["b", "a", "c"])
    }

    func test_nesneEklemeVeSilme() throws {
        var o = Nesne()
        o["b"] = .number(1)
        o["a"] = .number(2)
        o["b"] = .number(3)
        XCTAssertEqual(JSON.object(o).metinOlarak(), "{\"b\":3,\"a\":2}")
        o["c"] = .null
        o["b"] = nil
        XCTAssertEqual(o.anahtarlar, ["a", "c"])
        XCTAssertEqual(JSON.object(o).metinOlarak(), "{\"a\":2,\"c\":null}")
    }

    func test_jsonSayiYazimi() throws {
        XCTAssertEqual(JSON.number(1).metinOlarak(), "1")
        XCTAssertEqual(JSON.number(1.5).metinOlarak(), "1.5")
        XCTAssertEqual(JSON.number(-0.0).metinOlarak(), "0")
        XCTAssertEqual(JSON.number(1e21).metinOlarak(), "1e+21")
        XCTAssertEqual(JSON.number(1e20).metinOlarak(), "100000000000000000000")
        XCTAssertEqual(JSON.number(123456789012345680000).metinOlarak(), "123456789012345680000")
        XCTAssertEqual(JSON.number(0.000001).metinOlarak(), "0.000001")
        XCTAssertEqual(JSON.number(0.0000001).metinOlarak(), "1e-7")
        XCTAssertEqual(JSON.number(1.5e-7).metinOlarak(), "1.5e-7")
        XCTAssertEqual(JSON.number(0.1).metinOlarak(), "0.1")
        XCTAssertEqual(JSON.number(100).metinOlarak(), "100")
        XCTAssertEqual(JSON.number(-12.25).metinOlarak(), "-12.25")
        XCTAssertEqual(JSON.number(1.7976931348623157e308).metinOlarak(), "1.7976931348623157e+308")
        XCTAssertEqual(JSON.number(5e-324).metinOlarak(), "5e-324")
        XCTAssertEqual(JSON.number(Double.nan).metinOlarak(), "null")
        XCTAssertEqual(JSON.number(Double.infinity).metinOlarak(), "null")
        let j = try JSON.coz("[1,1.5,-0,1e21,0.1]")
        XCTAssertEqual(j.metinOlarak(), "[1,1.5,0,1e+21,0.1]")
    }

    func test_jsonKacislar() throws {
        let s = "a\"b\c\n\r\t\u{08}\u{0C}\u{01}\u{1F}\u{7F}\u{2028}\u{2029}é😀"
        let yazilan = JSON.string(s).metinOlarak()
        XCTAssertEqual(yazilan, "\"a\\\"b\\c\n\r\t\b\f\u0001\u001f\u{7F}\u{2028}\u{2029}é😀\"")
        XCTAssertEqual(try JSON.coz(yazilan), .string(s))
        XCTAssertEqual(try JSON.coz("\"\ud83d\ude00\u0041\/\""), .string("😀A/"))
    }

    func test_jsonHatalar() {
        XCTAssertThrowsError(try JSON.coz("{\"a\":}"))
        XCTAssertThrowsError(try JSON.coz("[1,2"))
        XCTAssertThrowsError(try JSON.coz("{} x"))
        XCTAssertThrowsError(try JSON.coz("abc"))
    }

    func test_tekrarlananAnahtarSonDegerIlkKonum() throws {
        let j = try JSON.coz("{\"a\":1,\"b\":2,\"a\":3}")
        XCTAssertEqual(j.metinOlarak(), "{\"a\":3,\"b\":2}")
    }
}
