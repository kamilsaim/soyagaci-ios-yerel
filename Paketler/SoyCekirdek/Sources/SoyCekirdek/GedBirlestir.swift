import Foundation

/// GED birleştirme (web `matchImported` l.1388, `applyImported` l.1434, `gedSum` l.1445, `cancelGedMerge` l.1467).
/// `applyGedMerge`'in işareti-kaldırma adımı: çağıran ilgili çifti `esler`'den çıkarıp `applyImported`'a verir.
public enum GedBirlestir {
    // MARK: yardımcılar (iç)

    /// Web `_fold`: tr-TR küçük harf, tüm boşluklar atılır.
    static func katla(_ s: String) -> String {
        var t = String.UnicodeScalarView()
        for u in Metin.trKatla(s).unicodeScalars where !Tarih.bosluk(u) { t.append(u) }
        return String(t)
    }

    /// Web `words`: tr-TR küçük harf, `/\s+/` ile bölünür, boşlar atılır.
    static func kelimeler(_ s: String) -> [[Unicode.Scalar]] {
        var cikti: [[Unicode.Scalar]] = []
        var simdiki: [Unicode.Scalar] = []
        for u in Metin.trKatla(s).unicodeScalars {
            if Tarih.bosluk(u) {
                if !simdiki.isEmpty {
                    cikti.append(simdiki)
                    simdiki = []
                }
            } else {
                simdiki.append(u)
            }
        }
        if !simdiki.isEmpty { cikti.append(simdiki) }
        return cikti
    }

    /// Web `nameFit`: kelimelerden kısa olanın hepsi uzun olanda geçer.
    static func nameFit(_ x: String, _ y: String) -> Bool {
        let a = kelimeler(x)
        let b = kelimeler(y)
        if a.isEmpty || b.isEmpty { return false }
        let kisa = a.count <= b.count ? a : b
        let uzun = a.count <= b.count ? b : a
        for w in kisa where !uzun.contains(w) { return false }
        return true
    }

    /// Web `sur`: [lastName, maidenName] katlanmış, boşlar atılmış.
    static func sur(_ p: Kisi) -> [String] {
        var c: [String] = []
        for s in [katla(p.lastName), katla(p.maidenName)] where !s.isEmpty { c.append(s) }
        return c
    }

    static func icerir(_ liste: [String], _ x: String) -> Bool {
        for y in liste where y.unicodeScalars.elementsEqual(x.unicodeScalars) { return true }
        return false
    }

    // MARK: matchImported

    /// Eşleşmeler (yeni → eski), Map ekleme sırasıyla.
    public static func matchImported(_ ids: [String], _ a: Agac) -> [(yeni: String, eski: String)] {
        var isNew = Set<String>()
        for id in ids { isNew.insert(id) }
        var esler: [(yeni: String, eski: String)] = []
        var haritada = Set<String>()
        var used = Set<String>()
        var olds: [Kisi] = []
        for (_, j) in a.people.ciftler {
            if case .object(let o) = j {
                let k = Kisi(o)
                if !isNew.contains(k.id) { olds.append(k) }
            }
        }

        func pn(_ p: Kisi, _ r: String) -> String {
            let bag: String? = r == "father" ? p.father : p.mother
            guard let id = bag, let q = a.kisi(id) else { return "" }
            return q.firstName
        }
        func free(_ id: String) -> Bool {
            return isNew.contains(id) && !haritada.contains(id)
        }
        func ekle(_ n: String, _ o: String) {
            esler.append((yeni: n, eski: o))
            haritada.insert(n)
            used.insert(o)
        }
        func yilFarkiBuyuk(_ x: Kisi, _ y: Kisi) -> Bool {
            let ya = Tarih.yearOf(x.birthDate)
            let yb = Tarih.yearOf(y.birthDate)
            if ya.isEmpty || yb.isEmpty { return false }
            guard let na = Int(ya), let nb = Int(yb) else { return false }
            return abs(na - nb) > 1
        }
        func ebeveynCelisir(_ x: Kisi, _ y: Kisi) -> Bool {
            for r in ["father", "mother"] {
                let px = pn(x, r)
                let py = pn(y, r)
                if !px.isEmpty && !py.isEmpty && !nameFit(px, py) { return true }
            }
            return false
        }
        // rel: yakın üzerinden eşleşme — soyad bakılmaz
        func fit(_ x: Kisi, _ y: Kisi, _ rel: Bool) -> Bool {
            if x.ham["gender"] != y.ham["gender"] { return false }
            if !nameFit(x.firstName, y.firstName) {
                let ikisiAdsiz = kelimeler(x.firstName).isEmpty && kelimeler(y.firstName).isEmpty
                if !(rel && ikisiAdsiz) { return false }
            }
            if !rel {
                let sx = sur(x)
                let sy = sur(y)
                if !sx.isEmpty && !sy.isEmpty {
                    var ortak = false
                    for s in sx where icerir(sy, s) { ortak = true }
                    if !ortak { return false }
                }
            }
            if yilFarkiBuyuk(x, y) { return false }
            return !ebeveynCelisir(x, y)
        }
        func strong(_ x: Kisi, _ y: Kisi) -> Bool {
            if !fit(x, y, false) { return false }
            if Tarih.yearOf(x.birthDate).isEmpty || Tarih.yearOf(y.birthDate).isEmpty { return false }
            if Tarih.normDate(x.birthDate) == Tarih.normDate(y.birthDate) { return true }
            if !sur(x).isEmpty && !sur(y).isEmpty { return true }
            for r in ["father", "mother"] {
                let px = pn(x, r)
                if !px.isEmpty && nameFit(px, pn(y, r)) { return true }
            }
            return false
        }

        for id in ids {
            guard let ka = a.kisi(id) else { continue }
            var c: [Kisi] = []
            for b in olds where !used.contains(b.id) && strong(ka, b) { c.append(b) }
            if c.count != 1 { continue }
            var sayac = 0
            for x in ids where free(x) {
                if let kx = a.kisi(x), strong(kx, c[0]) { sayac += 1 }
            }
            if sayac != 1 { continue }
            ekle(id, c[0].id)
        }

        // Yakınları üzerinden yayıl
        func tryPair(_ nids: [String], _ oids: [String]) -> Bool {
            var ch = false
            var serbest: [String] = []
            for n in nids where free(n) { serbest.append(n) }
            for n in serbest {
                var c: [String] = []
                for o in oids where !o.isEmpty && !isNew.contains(o) && !used.contains(o) {
                    if let kn = a.kisi(n), let ko = a.kisi(o), fit(kn, ko, true) { c.append(o) }
                }
                if c.count != 1 { continue }
                var sayac = 0
                for x in nids where free(x) {
                    if let kx = a.kisi(x), let kc = a.kisi(c[0]), fit(kx, kc, true) { sayac += 1 }
                }
                if sayac != 1 { continue }
                ekle(n, c[0])
                ch = true
            }
            return ch
        }
        var go = true
        while go {
            go = false
            for (n, o) in esler {
                guard let ka = a.kisi(n), let kb = a.kisi(o) else { continue }
                var nBaba: [String] = []
                if let f = ka.father { nBaba.append(f) }
                var nAnne: [String] = []
                if let m = ka.mother { nAnne.append(m) }
                if tryPair(nBaba, [kb.father ?? ""]) { go = true }
                if tryPair(nAnne, [kb.mother ?? ""]) { go = true }
                if tryPair(ka.spouses.map { $0.id }, kb.spouses.map { $0.id }) { go = true }
                if tryPair(ka.children, kb.children) { go = true }
            }
        }
        return esler
    }

    // MARK: applyImported

    /// Eşleşenleri `mergePeople(eski, yeni)` ile birleştirir; eşleşmeyen yeni ebeveyn, ağaçta zaten başka
    /// anne/babası olan çocuğu sahiplenmesin. Döner: birleştirilen çift sayısı (`map.size`).
    @discardableResult
    public static func applyImported(_ ids: [String], _ esler: [(yeni: String, eski: String)], _ a: inout Agac) -> Int {
        for e in esler where a.kisi(e.yeni) != nil && a.kisi(e.eski) != nil {
            Mukerrer.mergePeople(keep: e.eski, drop: e.yeni, &a)
        }
        for id in ids {
            guard let p = a.kisi(id) else { continue }
            let slot = p.gender == "F" ? "mother" : "father"
            var kalan: [JSON] = []
            for c in p.ham["children"]?.dizi ?? [] {
                guard let q = a.kisi(c.jsMetin) else { continue }
                let s = q.ham[slot]
                let bos = !(s?.dogru ?? false)
                if bos || s == JSON.string(id) { kalan.append(c) }
            }
            Islem.degistir(&a, id) { $0["children"] = .array(kalan) }
        }
        return esler.count
    }

    // MARK: gedSum / iptal

    static func esc(_ s: String) -> String {
        var t = ""
        for ch in s.unicodeScalars {
            switch ch {
            case "&": t += "&amp;"
            case "<": t += "&lt;"
            case ">": t += "&gt;"
            case "\"": t += "&quot;"
            case "'": t += "&#39;"
            default: t.unicodeScalars.append(ch)
            }
        }
        return t
    }

    /// Önizleme satırı (HTML): kişi adı, kızlık soyadı, doğum, ebeveyn, eş. Web `people` aramaları için `a` gerekir.
    public static func gedSum(_ p: Kisi, _ a: Agac) -> String {
        func nm(_ id: String?) -> String {
            guard let i = id, let q = a.kisi(i) else { return "" }
            return q.firstName.isEmpty ? "İsimsiz" : q.firstName
        }
        var parcalar: [String] = []
        for s in [nm(p.father), nm(p.mother)] where !s.isEmpty { parcalar.append(s) }
        let par = parcalar.joined(separator: " & ")
        var esAdlari: [String] = []
        for s in p.spouses {
            let ad = nm(s.id)
            if !ad.isEmpty { esAdlari.append(ad) }
        }
        let sp = esAdlari.joined(separator: ", ")
        var bits: [String] = []
        if !p.birthDate.isEmpty { bits.append("d. " + p.birthDate) }
        if !p.birthPlace.isEmpty { bits.append(p.birthPlace) }
        if !par.isEmpty { bits.append("ebeveyn: " + par) }
        if !sp.isEmpty { bits.append("eş: " + sp) }
        var s = "<b>" + esc(Islem.pname(p)) + "</b>"
        if !p.maidenName.isEmpty { s += " <i>d. " + esc(p.maidenName) + "</i>" }
        let ozet = bits.isEmpty ? "bilgi yok" : bits.joined(separator: " · ")
        s += "<div>" + esc(ozet) + "</div>"
        return s
    }

    /// Web `cancelGedMerge`: içe aktarılan kişileri siler, `nextId`'yi geri alır.
    public static func iptal(_ ids: [String], nextId0: Int, _ a: inout Agac) {
        for id in ids { a.people[id] = nil }
        a.nextId = nextId0
    }
}
