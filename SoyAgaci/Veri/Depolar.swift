import Foundation
import Supabase
import SoyCekirdek

// MARK: Ağaç <-> JSON

extension Agac {
    /// Yerel dosya biçimi: `{ "people": {...}, "nextId": n }` (bilinmeyen kişi alanları korunur).
    func jsonVeri() -> Data {
        JSON.object(Nesne([("people", .object(people)), ("nextId", .number(Double(nextId)))])).veri()
    }

    init?(jsonVeri: Data) {
        guard let j = try? JSON.coz(jsonVeri), case .object(let o) = j, let p = o["people"]?.nesne else { return nil }
        self.init(people: p, nextId: Int(o["nextId"]?.sayi ?? 1))
    }
}

// MARK: Tarih

enum BulutTarihi {
    /// Postgres `timestamptz` metni ("2026-11-18T11:29:07.123456+00:00"); milisaniyeye kadar okunur (web `new Date()` gibi).
    static func coz(_ s: String) -> Date? {
        var govde = s
        var kesir = ""
        if let nokta = s.firstIndex(of: ".") {
            let sonrasi = s[s.index(after: nokta)...]
            let rakamlar = sonrasi.prefix(while: { $0.isNumber })
            kesir = String(rakamlar.prefix(3))
            while kesir.count < 3 { kesir += "0" }
            govde = String(s[..<nokta]) + "." + kesir + String(sonrasi.dropFirst(rakamlar.count))
        }
        let f = ISO8601DateFormatter()
        f.formatOptions = kesir.isEmpty ? [.withInternetDateTime] : [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: govde) { return d }
        // saat dilimi yoksa UTC varsay
        return f.date(from: govde + "Z")
    }
}

// MARK: Buluta erişim (soy_family_data)

struct BulutHatasi: Error, CustomStringConvertible {
    let description: String
}

struct SupabaseBulut: BulutDeposu {
    let istemci: SupabaseClient

    init(istemci: SupabaseClient = Servis.istemci) { self.istemci = istemci }

    private struct Yuk: Encodable {
        let user_id: String
        let people: AnyJSON
        let next_id: Int
    }

    func oku(uid: String) async throws -> BulutSatiri? {
        let yanit = try await istemci.from("soy_family_data")
            .select("people,next_id,updated_at")
            .eq("user_id", value: uid)
            .limit(1)
            .execute()
        guard let satirlar = try JSON.coz(yanit.data).dizi else { throw BulutHatasi(description: "Beklenmeyen yanıt") }
        guard let o = satirlar.first?.nesne else { return nil }
        let people = o["people"]?.nesne ?? Nesne()
        var agac = Agac(people: people, nextId: Int(o["next_id"]?.sayi ?? 1))
        if agac.nextId < 1 { agac.nextId = 1 }
        guard let zaman = o["updated_at"]?.metin.flatMap(BulutTarihi.coz) else { throw BulutHatasi(description: "updated_at okunamadı") }
        return BulutSatiri(agac: agac, updatedAt: zaman)
    }

    func yaz(uid: String, agac: Agac) async throws -> Date {
        // `fams` bilerek yazılmaz (kolon artık kullanılmıyor)
        let people = try JSONDecoder().decode(AnyJSON.self, from: JSON.object(agac.people).veri())
        try await istemci.from("soy_family_data")
            .upsert(Yuk(user_id: uid, people: people, next_id: agac.nextId), onConflict: "user_id", returning: .minimal)
            .execute()
        // updated_at'i trigger yazar; ayrıca okunur
        let yanit = try await istemci.from("soy_family_data")
            .select("updated_at")
            .eq("user_id", value: uid)
            .limit(1)
            .execute()
        guard let o = try JSON.coz(yanit.data).dizi?.first?.nesne,
              let zaman = o["updated_at"]?.metin.flatMap(BulutTarihi.coz) else {
            throw BulutHatasi(description: "Kaydedilen satır okunamadı")
        }
        return zaman
    }
}

// MARK: Yerel dosyalar (localStorage karşılığı)

/// Application Support/SoyAgaci altında anahtar başına bir dosya (web localStorage anahtarlarıyla aynı adlar), atomik yazma.
final class DosyaYerel: YerelDeposu {
    static let varsayilanKlasor: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SoyAgaci", isDirectory: true)
    }()

    private let klasor: URL

    init(klasor: URL = DosyaYerel.varsayilanKlasor) {
        self.klasor = klasor
        try? FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
    }

    private func yol(_ anahtar: String) -> URL { klasor.appendingPathComponent(anahtar + ".json") }

    func oku(_ anahtar: String) -> Data? { try? Data(contentsOf: yol(anahtar)) }

    func yaz(_ anahtar: String, _ veri: Data?) {
        if let v = veri {
            try? v.write(to: yol(anahtar), options: [.atomic])
        } else {
            try? FileManager.default.removeItem(at: yol(anahtar))
        }
    }

    private func metin(_ a: String) -> String? { oku(a).flatMap { String(data: $0, encoding: .utf8) } }
    private func metinYaz(_ a: String, _ m: String?) { yaz(a, m.map { Data($0.utf8) }) }

    private static func ms(_ d: Date) -> String { String(Int((d.timeIntervalSince1970 * 1000).rounded())) }
    private static func tarih(_ m: String?) -> Date? {
        guard let m, let v = Double(m) else { return nil }
        return Date(timeIntervalSince1970: v / 1000)
    }

    var bulutKopya: Agac? {
        get { oku("sa4").flatMap { Agac(jsonVeri: $0) } }
        set { yaz("sa4", newValue?.jsonVeri()) }
    }
    var bulutKopyaUid: String? {
        get { metin("sa4_uid") }
        set { metinYaz("sa4_uid", newValue) }
    }
    var yerelMod: Agac? {
        get { oku("sa4_local").flatMap { Agac(jsonVeri: $0) } }
        set { yaz("sa4_local", newValue?.jsonVeri()) }
    }
    var kirli: String? {
        get { metin("sa4_dirty") }
        set { metinYaz("sa4_dirty", newValue) }
    }
    var taban: Date? {
        get { DosyaYerel.tarih(metin("sa4_base")) }
        set { metinYaz("sa4_base", newValue.map { DosyaYerel.ms($0) }) }
    }
    var eskiZaman: Date? {
        get { DosyaYerel.tarih(metin("sa4_ts")) }
        set { metinYaz("sa4_ts", newValue.map { DosyaYerel.ms($0) }) }
    }
}

// MARK: Ağaç konumları (soy_node_positions + sa4nd_<uid|local>)

/// Tüm Ağaç'taki elle kaydırmalar: `{ "$v":2, [kişiId]: {dx,dy}, "$old": … }` (web `nodeDrag`).
final class KonumDeposu {
    private let yerel: DosyaYerel
    private let istemci: SupabaseClient

    init(yerel: DosyaYerel, istemci: SupabaseClient = Servis.istemci) {
        self.yerel = yerel
        self.istemci = istemci
    }

    private func anahtar(_ uid: String?) -> String { "sa4nd_" + (uid ?? "local") }

    /// Web `loadLayout`: girişliyse önce bulut (satır varsa o), yoksa/okunamazsa yerel dosya; hep `normDrag`'dan geçer.
    func yukle(uid: String?) async -> JSON {
        if let uid {
            do {
                let yanit = try await istemci.from("soy_node_positions")
                    .select("positions")
                    .eq("user_id", value: uid)
                    .limit(1)
                    .execute()
                if let o = try JSON.coz(yanit.data).dizi?.first?.nesne, let p = o["positions"] {
                    return Agacla.normDrag(p)
                }
            } catch {}
        }
        let yerelJson = yerel.oku(anahtar(uid)).flatMap { try? JSON.coz($0) }
        return Agacla.normDrag(yerelJson ?? .null)
    }

    private struct Yuk: Encodable {
        let user_id: String
        let positions: AnyJSON
    }

    /// Web `saveLayout`: önce yerel dosya, sonra (girişliyse) bulut. Bulut başarısızsa false döner (uyarı UI'nın işi).
    @discardableResult
    func kaydet(_ konumlar: JSON, uid: String?) async -> Bool {
        let j = Agacla.normDrag(konumlar)
        yerel.yaz(anahtar(uid), j.veri())
        guard let uid else { return true }
        do {
            let p = try JSONDecoder().decode(AnyJSON.self, from: j.veri())
            try await istemci.from("soy_node_positions")
                .upsert(Yuk(user_id: uid, positions: p), onConflict: "user_id", returning: .minimal)
                .execute()
            return true
        } catch {
            return false
        }
    }

    /// Çıkış / hesap silme: bu kullanıcının yerel konum dosyası silinir.
    func yerelSil(uid: String) { yerel.yaz(anahtar(uid), nil) }
}
