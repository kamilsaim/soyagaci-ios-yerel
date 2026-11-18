import Foundation

/// Ordered key/value container with JS object semantics: insertion order is kept,
/// re-assigning an existing key keeps its position, assigning nil removes the key.
public struct Nesne: Equatable {
    public private(set) var anahtarlar: [String] = []
    private var deger: [String: JSON] = [:]

    public init() {}

    public init(_ ciftler: [(String, JSON)]) {
        for (k, v) in ciftler { self[k] = v }
    }

    public subscript(_ anahtar: String) -> JSON? {
        get { return deger[anahtar] }
        set {
            if let yeni = newValue {
                if deger[anahtar] == nil { anahtarlar.append(anahtar) }
                deger[anahtar] = yeni
            } else if deger[anahtar] != nil {
                deger[anahtar] = nil
                if let i = anahtarlar.firstIndex(of: anahtar) { anahtarlar.remove(at: i) }
            }
        }
    }

    public var ciftler: [(String, JSON)] {
        var cikti: [(String, JSON)] = []
        for k in anahtarlar {
            if let v = deger[k] { cikti.append((k, v)) }
        }
        return cikti
    }

    public var sayisi: Int { return anahtarlar.count }

    public static func == (a: Nesne, b: Nesne) -> Bool {
        return a.anahtarlar == b.anahtarlar && a.deger == b.deger
    }
}

/// Raw JSON tree (unknown fields must survive a read/write round trip). Parser and writer are
/// hand-written; the writer matches JS `JSON.stringify(x)` byte for byte (object key order kept).
public enum JSON: Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSON])
    case object(Nesne)

    public struct Hata: Error, CustomStringConvertible {
        public let description: String
    }

    // MARK: access
    public subscript(_ anahtar: String) -> JSON? {
        if case .object(let o) = self { return o[anahtar] }
        return nil
    }
    public var metin: String? { if case .string(let s) = self { return s }; return nil }
    public var sayi: Double? { if case .number(let n) = self { return n }; return nil }
    public var mantik: Bool? { if case .bool(let b) = self { return b }; return nil }
    public var dizi: [JSON]? { if case .array(let a) = self { return a }; return nil }
    public var nesne: Nesne? { if case .object(let o) = self { return o }; return nil }

    /// JavaScript truthiness (`!!x`).
    public var dogru: Bool {
        switch self {
        case .null: return false
        case .bool(let b): return b
        case .number(let n): return !(n == 0 || n.isNaN)
        case .string(let s): return !s.isEmpty
        case .array, .object: return true
        }
    }

    /// JavaScript `String(x||'')`.
    public var jsMetinVeyaBos: String {
        if !dogru { return "" }
        return jsMetin
    }

    /// JavaScript `String(x)`.
    public var jsMetin: String {
        switch self {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .number(let n): return JSON.jsSayi(n)
        case .string(let s): return s
        case .array(let a): return a.map { $0 == .null ? "" : $0.jsMetin }.joined(separator: ",")
        case .object: return "[object Object]"
        }
    }

    // MARK: number formatting (ECMAScript Number::toString)

    /// JS `String(d)`.
    public static func jsSayi(_ d: Double) -> String {
        if d.isNaN { return "NaN" }
        if d.isInfinite { return d < 0 ? "-Infinity" : "Infinity" }
        if d == 0 { return "0" }
        let negatif = d < 0
        let sonuc = kisaRakamlar(abs(d))
        let rakamlar = sonuc.0
        let n = sonuc.1
        let k = rakamlar.count
        var s = ""
        if k <= n && n <= 21 {
            s = String(rakamlar) + String(repeating: "0", count: n - k)
        } else if 0 < n && n <= 21 {
            let bas = String(rakamlar[0..<n])
            let son = String(rakamlar[n...])
            s = bas + "." + son
        } else if -6 < n && n <= 0 {
            s = "0." + String(repeating: "0", count: -n) + String(rakamlar)
        } else {
            let e = n - 1
            let isaret = e < 0 ? "-" : "+"
            let us = String(abs(e))
            if k == 1 {
                s = String(rakamlar) + "e" + isaret + us
            } else {
                let bas = String(rakamlar[0..<1])
                let son = String(rakamlar[1...])
                s = bas + "." + son + "e" + isaret + us
            }
        }
        return negatif ? "-" + s : s
    }

    /// Shortest round-trip digits from Swift's description: value = 0.DIGITS x 10^n.
    private static func kisaRakamlar(_ d: Double) -> ([Character], Int) {
        let t = "\(d)"
        var mant = t
        var us = 0
        if let i = t.firstIndex(where: { $0 == "e" || $0 == "E" }) {
            mant = String(t[t.startIndex..<i])
            us = Int(String(t[t.index(after: i)...])) ?? 0
        }
        var tam: [Character] = []
        var noktaKonum = -1
        for c in mant {
            if c == "." { noktaKonum = tam.count } else { tam.append(c) }
        }
        if noktaKonum < 0 { noktaKonum = tam.count }
        var n = noktaKonum + us
        var bas = 0
        while bas < tam.count - 1 && tam[bas] == "0" {
            bas += 1
            n -= 1
        }
        var govde = Array(tam[bas...])
        while govde.count > 1 && govde[govde.count - 1] == "0" { govde.removeLast() }
        return (govde, n)
    }

    static func sayiMetni(_ d: Double) -> String {
        if !d.isFinite { return "null" }
        return jsSayi(d)
    }

    // MARK: writer
    public func metinOlarak() -> String {
        var s = ""
        yaz(&s)
        return s
    }

    func yaz(_ s: inout String) {
        switch self {
        case .null: s += "null"
        case .bool(let b): s += b ? "true" : "false"
        case .number(let n): s += JSON.sayiMetni(n)
        case .string(let t): JSON.kacir(t, &s)
        case .array(let a):
            s += "["
            var ilk = true
            for e in a {
                if !ilk { s += "," }
                ilk = false
                e.yaz(&s)
            }
            s += "]"
        case .object(let o):
            s += "{"
            var ilk = true
            for (k, v) in o.ciftler {
                if !ilk { s += "," }
                ilk = false
                JSON.kacir(k, &s)
                s += ":"
                v.yaz(&s)
            }
            s += "}"
        }
    }

    static func kacir(_ t: String, _ s: inout String) {
        s += "\""
        for u in t.unicodeScalars {
            switch u.value {
            case 0x22: s += "\\\""
            case 0x5C: s += "\\\\"
            case 0x08: s += "\\b"
            case 0x0C: s += "\\f"
            case 0x0A: s += "\\n"
            case 0x0D: s += "\\r"
            case 0x09: s += "\\t"
            default:
                if u.value < 0x20 {
                    let h = String(u.value, radix: 16)
                    s += "\\u" + String(repeating: "0", count: 4 - h.count) + h
                } else {
                    s.unicodeScalars.append(u)
                }
            }
        }
        s += "\""
    }

    public func veri() -> Data { return Data(metinOlarak().utf8) }

    // MARK: parser
    public static func coz(_ veri: Data) throws -> JSON {
        var p = Ayristirici(b: [UInt8](veri))
        p.bosluk()
        let v = try p.deger()
        p.bosluk()
        if p.i != p.b.count { throw Hata(description: "fazla veri") }
        return v
    }
    public static func coz(_ metin: String) throws -> JSON { return try coz(Data(metin.utf8)) }

    struct Ayristirici {
        let b: [UInt8]
        var i = 0
        init(b: [UInt8]) { self.b = b }

        mutating func bosluk() {
            while i < b.count, b[i] == 0x20 || b[i] == 0x0A || b[i] == 0x0D || b[i] == 0x09 { i += 1 }
        }
        mutating func deger() throws -> JSON {
            guard i < b.count else { throw Hata(description: "beklenmedik son") }
            switch b[i] {
            case UInt8(ascii: "{"): return try nesne()
            case UInt8(ascii: "["): return try dizi()
            case UInt8(ascii: "\""): return .string(try metin())
            case UInt8(ascii: "t"): try sabit("true"); return .bool(true)
            case UInt8(ascii: "f"): try sabit("false"); return .bool(false)
            case UInt8(ascii: "n"): try sabit("null"); return .null
            default: return try sayi()
            }
        }
        mutating func sabit(_ s: String) throws {
            let u = Array(s.utf8)
            guard i + u.count <= b.count, Array(b[i..<i + u.count]) == u else { throw Hata(description: "gecersiz sabit") }
            i += u.count
        }
        mutating func sayi() throws -> JSON {
            let bas = i
            if i < b.count, b[i] != 0x2D, !(b[i] >= 0x30 && b[i] <= 0x39) { throw Hata(description: "gecersiz deger") }
            while i < b.count {
                let c = b[i]
                if (c >= 0x30 && c <= 0x39) || c == 0x2D || c == 0x2B || c == 0x2E || c == 0x65 || c == 0x45 { i += 1 } else { break }
            }
            guard i > bas, let s = String(bytes: b[bas..<i], encoding: .utf8), let d = Double(s) else {
                throw Hata(description: "gecersiz sayi")
            }
            return .number(d)
        }
        mutating func hex4() throws -> UInt32 {
            guard i + 4 <= b.count, let s = String(bytes: b[i..<i + 4], encoding: .utf8), let v = UInt32(s, radix: 16) else {
                throw Hata(description: "gecersiz u kacisi")
            }
            i += 4
            return v
        }
        mutating func metin() throws -> String {
            i += 1
            var out = [UInt8]()
            while true {
                guard i < b.count else { throw Hata(description: "metin bitmedi") }
                let c = b[i]
                if c == UInt8(ascii: "\"") { i += 1; break }
                if c == UInt8(ascii: "\\") {
                    i += 1
                    guard i < b.count else { throw Hata(description: "kacis bitmedi") }
                    let e = b[i]
                    i += 1
                    switch e {
                    case UInt8(ascii: "\""): out.append(0x22)
                    case UInt8(ascii: "\\"): out.append(0x5C)
                    case UInt8(ascii: "/"): out.append(0x2F)
                    case UInt8(ascii: "b"): out.append(0x08)
                    case UInt8(ascii: "f"): out.append(0x0C)
                    case UInt8(ascii: "n"): out.append(0x0A)
                    case UInt8(ascii: "r"): out.append(0x0D)
                    case UInt8(ascii: "t"): out.append(0x09)
                    case UInt8(ascii: "u"):
                        var kod = try hex4()
                        if kod >= 0xD800 && kod < 0xDC00, i + 1 < b.count, b[i] == 0x5C, b[i + 1] == UInt8(ascii: "u") {
                            i += 2
                            let alt = try hex4()
                            if alt >= 0xDC00 && alt < 0xE000 {
                                kod = 0x10000 + ((kod - 0xD800) << 10) + (alt - 0xDC00)
                            } else {
                                kod = 0xFFFD
                            }
                        } else if kod >= 0xD800 && kod < 0xE000 {
                            kod = 0xFFFD
                        }
                        let sk = Unicode.Scalar(kod) ?? Unicode.Scalar(0xFFFD)!
                        out.append(contentsOf: Array(String(Character(sk)).utf8))
                    default: throw Hata(description: "gecersiz kacis")
                    }
                } else {
                    out.append(c)
                    i += 1
                }
            }
            return String(decoding: out, as: UTF8.self)
        }
        mutating func dizi() throws -> JSON {
            i += 1
            var a = [JSON]()
            bosluk()
            if i < b.count, b[i] == UInt8(ascii: "]") { i += 1; return .array(a) }
            while true {
                bosluk()
                a.append(try deger())
                bosluk()
                guard i < b.count else { throw Hata(description: "dizi bitmedi") }
                if b[i] == UInt8(ascii: ",") { i += 1; continue }
                if b[i] == UInt8(ascii: "]") { i += 1; break }
                throw Hata(description: "dizide gecersiz karakter")
            }
            return .array(a)
        }
        mutating func nesne() throws -> JSON {
            i += 1
            var o = Nesne()
            bosluk()
            if i < b.count, b[i] == UInt8(ascii: "}") { i += 1; return .object(o) }
            while true {
                bosluk()
                guard i < b.count, b[i] == UInt8(ascii: "\"") else { throw Hata(description: "anahtar bekleniyordu") }
                let k = try metin()
                bosluk()
                guard i < b.count, b[i] == UInt8(ascii: ":") else { throw Hata(description: "iki nokta bekleniyordu") }
                i += 1
                bosluk()
                o[k] = try deger()
                bosluk()
                guard i < b.count else { throw Hata(description: "nesne bitmedi") }
                if b[i] == UInt8(ascii: ",") { i += 1; continue }
                if b[i] == UInt8(ascii: "}") { i += 1; break }
                throw Hata(description: "nesnede gecersiz karakter")
            }
            return .object(o)
        }
    }
}
