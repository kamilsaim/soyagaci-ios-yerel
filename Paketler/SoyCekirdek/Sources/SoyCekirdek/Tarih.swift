import Foundation

/// Web `dateParts` sonucu: `{d, m, y}` (gun/ay dogrulanmaz, 99/99/9999 gecerli sayilir).
public struct TarihParca: Equatable {
    public var d: Int?
    public var m: Int?
    public var y: Int

    public init(d: Int?, m: Int?, y: Int) {
        self.d = d
        self.m = m
        self.y = y
    }
}

/// Web tarih yardimcilari (normDate, toGedDate, yearOf, dateParts, isPlaceholder, fmtDate) ile birebir.
/// Duzenli ifade kullanilmaz: JS `\d`/`\s` ile Foundation farklarini onlemek icin elle ayristirilir.
public enum Tarih {
    static let gAy: [String: String] = [
        "JAN": "01", "FEB": "02", "MAR": "03", "APR": "04", "MAY": "05", "JUN": "06",
        "JUL": "07", "AUG": "08", "SEP": "09", "OCT": "10", "NOV": "11", "DEC": "12",
    ]
    static let gAyDizi: [String] = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    static let aylar: [String] = [
        "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
        "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık",
    ]

    // MARK: JS karakter siniflari

    /// JS `\s` (ve `String.prototype.trim` kumesi).
    static func bosluk(_ u: Unicode.Scalar) -> Bool {
        switch u.value {
        case 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0xA0, 0x1680, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF:
            return true
        default:
            return u.value >= 0x2000 && u.value <= 0x200A
        }
    }
    static func rakam(_ u: Unicode.Scalar) -> Bool { return u.value >= 0x30 && u.value <= 0x39 }
    static func harf(_ u: Unicode.Scalar) -> Bool {
        return (u.value >= 0x41 && u.value <= 0x5A) || (u.value >= 0x61 && u.value <= 0x7A)
    }
    static func ayiracMi(_ u: Unicode.Scalar) -> Bool { return u == "." || u == "-" || u == "/" }

    /// JS `String.prototype.trim`.
    static func kirp(_ s: String) -> [Unicode.Scalar] {
        let a = Array(s.unicodeScalars)
        var bas = 0
        var son = a.count
        while bas < son && bosluk(a[bas]) { bas += 1 }
        while son > bas && bosluk(a[son - 1]) { son -= 1 }
        return Array(a[bas..<son])
    }

    /// Kucuk ayristirma imleci (acgozlu; sonraki oge hep ayri sinifta oldugundan geri izleme gerekmez).
    struct Imlec {
        let a: [Unicode.Scalar]
        var i = 0
        init(_ a: [Unicode.Scalar]) { self.a = a }

        mutating func rakamlar(_ enAz: Int, _ enCok: Int) -> String? {
            var s = ""
            var n = 0
            while i < a.count && n < enCok && Tarih.rakam(a[i]) {
                s.unicodeScalars.append(a[i])
                i += 1
                n += 1
            }
            return n >= enAz ? s : nil
        }
        mutating func harfler3() -> String? {
            if i + 3 > a.count { return nil }
            var s = ""
            for k in 0..<3 {
                if !Tarih.harf(a[i + k]) { return nil }
                s.unicodeScalars.append(a[i + k])
            }
            i += 3
            return s
        }
        mutating func ayirac() -> Bool {
            if i < a.count && Tarih.ayiracMi(a[i]) {
                i += 1
                return true
            }
            return false
        }
        mutating func bosluklar() -> Bool {
            var n = 0
            while i < a.count && Tarih.bosluk(a[i]) {
                i += 1
                n += 1
            }
            return n > 0
        }
        var sonMu: Bool { return i == a.count }
    }

    static func pad2(_ s: String) -> String {
        return s.count >= 2 ? s : "0" + s
    }

    // MARK: normDate

    /// Her tarihi GG/AA/YYYY kanonik bicimine cevirir (web `normDate`).
    public static func normDate(_ d: String) -> String {
        if d.isEmpty { return "" }
        let kirpik = kirp(d)
        var s = ""
        s.unicodeScalars.append(contentsOf: kirpik)

        // "30 JUL 2003"
        do {
            var c = Imlec(kirpik)
            if let g = c.rakamlar(1, 2), c.bosluklar(), let ay = c.harfler3(), c.bosluklar(),
               let y = c.rakamlar(4, 4), c.sonMu, let aa = gAy[ay.uppercased()] {
                return pad2(g) + "/" + aa + "/" + y
            }
        }
        // "JUL 2003"
        do {
            var c = Imlec(kirpik)
            if let ay = c.harfler3(), c.bosluklar(), let y = c.rakamlar(4, 4), c.sonMu,
               let aa = gAy[ay.uppercased()] {
                return aa + "/" + y
            }
        }
        // "30/07/2003", "30.07.2003", "30-07-2003"
        do {
            var c = Imlec(kirpik)
            if let g = c.rakamlar(1, 2), c.ayirac(), let a = c.rakamlar(1, 2), c.ayirac(),
               let y = c.rakamlar(4, 4), c.sonMu {
                return pad2(g) + "/" + pad2(a) + "/" + y
            }
        }
        // "07/2003"
        do {
            var c = Imlec(kirpik)
            if let a = c.rakamlar(1, 2), c.ayirac(), let y = c.rakamlar(4, 4), c.sonMu {
                return pad2(a) + "/" + y
            }
        }
        return s
    }

    // MARK: toGedDate

    /// GG/AA/YYYY -> GEDCOM "30 JUL 2003" (web `toGedDate`).
    public static func toGedDate(_ d: String) -> String {
        let s = normDate(d)
        if s.isEmpty { return "" }
        let a = Array(s.unicodeScalars)
        // ^(\d{2})\/(\d{2})\/(\d{4})$
        if a.count == 10, a[2] == "/", a[5] == "/" {
            let g = String(String.UnicodeScalarView(a[0..<2]))
            let ay = String(String.UnicodeScalarView(a[3..<5]))
            let y = String(String.UnicodeScalarView(a[6..<10]))
            if tamRakam(g) && tamRakam(ay) && tamRakam(y), let gn = Int(g), let an = Int(ay), an >= 1, an <= 12 {
                return String(gn) + " " + gAyDizi[an - 1] + " " + y
            }
        }
        // ^(\d{2})\/(\d{4})$
        if a.count == 7, a[2] == "/" {
            let ay = String(String.UnicodeScalarView(a[0..<2]))
            let y = String(String.UnicodeScalarView(a[3..<7]))
            if tamRakam(ay) && tamRakam(y), let an = Int(ay), an >= 1, an <= 12 {
                return gAyDizi[an - 1] + " " + y
            }
        }
        return s
    }

    static func tamRakam(_ s: String) -> Bool {
        if s.isEmpty { return false }
        for u in s.unicodeScalars where !rakam(u) { return false }
        return true
    }

    // MARK: yearOf

    /// Ilk 4 haneli rakam dizisi (web `yearOf`: `/(\d{4})/`), yoksa "".
    public static func yearOf(_ d: String) -> String {
        let a = Array(d.unicodeScalars)
        if a.count < 4 { return "" }
        for i in 0...(a.count - 4) {
            if rakam(a[i]) && rakam(a[i + 1]) && rakam(a[i + 2]) && rakam(a[i + 3]) {
                return String(String.UnicodeScalarView(a[i..<i + 4]))
            }
        }
        return ""
    }

    // MARK: dateParts / isPlaceholder / fmtDate

    /// `^(\d{1,2})[.\-/](\d{1,2})[.\-/](\d{4})$` (kirpilmis metinde); eslesmezse nil.
    public static func dateParts(_ s: String) -> TarihParca? {
        var c = Imlec(kirp(s))
        guard let g = c.rakamlar(1, 2), c.ayirac(), let a = c.rakamlar(1, 2), c.ayirac(),
              let y = c.rakamlar(4, 4), c.sonMu else { return nil }
        guard let gn = Int(g), let an = Int(a), let yn = Int(y) else { return nil }
        return TarihParca(d: gn, m: an, y: yn)
    }

    /// NVI yer tutucusu: 01/07/YYYY ve yil < 1960.
    public static func isPlaceholder(_ dp: TarihParca) -> Bool {
        return dp.d == 1 && dp.m == 7 && dp.y < 1960
    }

    /// Gosterim: "30 Temmuz 2003"; yer tutucuda yalniz yil; ayristirilamazsa girdi aynen.
    public static func fmtDate(_ s: String) -> String {
        guard let dp = dateParts(normDate(s)) else { return s }
        if isPlaceholder(dp) { return String(dp.y) }
        let gun = dp.d.map { String($0) } ?? "undefined"
        var ay = "undefined"
        if let m = dp.m, m >= 1, m <= 12 { ay = aylar[m - 1] }
        return gun + " " + ay + " " + String(dp.y)
    }
}
