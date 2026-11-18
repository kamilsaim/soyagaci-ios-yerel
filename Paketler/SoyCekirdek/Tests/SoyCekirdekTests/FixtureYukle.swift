import Foundation
import XCTest
@testable import SoyCekirdek

/// Web'den uretilmis parity fixture'larini (fixtures/<ad>.json) SoyCekirdek JSON ayristiricisiyla yukler.
enum FixtureYukle {
    struct Vaka {
        let ad: String
        let girdi: JSON
        let beklenen: JSON
    }

    static func yukle(_ ad: String) throws -> [Vaka] {
        guard let url = Bundle.module.url(forResource: ad, withExtension: "json", subdirectory: "fixtures") else {
            throw JSON.Hata(description: "fixture bulunamadi: " + ad)
        }
        let kok = try JSON.coz(try Data(contentsOf: url))
        guard let dizi = kok["vakalar"]?.dizi else { throw JSON.Hata(description: "vakalar yok: " + ad) }
        var cikti: [Vaka] = []
        for v in dizi {
            cikti.append(Vaka(ad: v["ad"]?.metin ?? "", girdi: v["girdi"] ?? .null, beklenen: v["beklenen"] ?? .null))
        }
        return cikti
    }
}
