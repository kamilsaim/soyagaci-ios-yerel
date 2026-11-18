import Foundation

/// Metin yardimcilari. Turkce buyuk/kucuk harf elle yapilir (Linux'ta Locale'e guvenilmez).
public enum Metin {
    /// Tek bir Unicode skalerini `toLocaleUpperCase('tr-TR')` gibi buyutur.
    static func trBuyuk(_ u: Unicode.Scalar) -> String {
        if u == "i" { return "\u{130}" }
        if u == "\u{131}" { return "I" }
        // JS kod birimi uzerinde calisir: BMP disi harfler (yarim vekil) buyumez.
        if u.value > 0xFFFF { return String(Character(u)) }
        return String(Character(u)).uppercased()
    }

    /// Web `capStr`: `/(?:^|[\s\-])\S/g` eslesmelerindeki `\S` harfini Turkce kurallarla buyutur.
    /// Eslesmeler ust uste binmez ("a -b" icindeki b buyumez; ayni davranis web'de de var).
    public static func capStr(_ s: String) -> String {
        if s.isEmpty { return s }
        let a = Array(s.unicodeScalars)
        var cikti = ""
        var i = 0
        while i < a.count {
            if i == 0 && !Tarih.bosluk(a[0]) {
                cikti += trBuyuk(a[0])
                i = 1
            } else if (Tarih.bosluk(a[i]) || a[i] == "-") && i + 1 < a.count && !Tarih.bosluk(a[i + 1]) {
                cikti.unicodeScalars.append(a[i])
                cikti += trBuyuk(a[i + 1])
                i += 2
            } else {
                cikti.unicodeScalars.append(a[i])
                i += 1
            }
        }
        return cikti
    }

    /// Arama icin `toLocaleLowerCase('tr-TR')`: I -> ı, İ -> i, gerisi Unicode kucuk harf.
    public static func trKatla(_ s: String) -> String {
        let a = Array(s.unicodeScalars)
        var cikti = ""
        var i = 0
        while i < a.count {
            let u = a[i]
            if u == "I" {
                if i + 1 < a.count && a[i + 1].value == 0x307 {
                    // I + combining dot above -> i (ICU tr-TR)
                    cikti += "i"
                    i += 2
                    continue
                }
                cikti += "\u{131}"
            } else if u == "\u{130}" {
                cikti += "i"
            } else {
                cikti += String(Character(u)).lowercased()
            }
            i += 1
        }
        return cikti
    }
}
