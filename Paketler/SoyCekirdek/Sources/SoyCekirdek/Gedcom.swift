import Foundation

/// GEDCOM okuma/yazma: web `soy-agaci-7.0.0.html` içindeki `splitGedName`, `parseGED`, `expGED` birebir portu.
/// Satırlar JS `split(/\r?\n/)` gibi bölünür; her şey Unicode skalerleri üzerinde yürür
/// (Swift'te "\r\n" tek Character olduğundan Character kullanılmaz).
public enum Gedcom {
    // MARK: yardımcılar (iç)

    static func satirlaraBol(_ metin: String) -> [[Unicode.Scalar]] {
        var cikti: [[Unicode.Scalar]] = []
        var gecerli: [Unicode.Scalar] = []
        for u in metin.unicodeScalars {
            if u == "\n" {
                if gecerli.last == "\r" { gecerli.removeLast() }
                cikti.append(gecerli)
                gecerli = []
            } else {
                gecerli.append(u)
            }
        }
        cikti.append(gecerli)
        return cikti
    }

    static func dizge(_ s: ArraySlice<Unicode.Scalar>) -> String {
        var v = String.UnicodeScalarView()
        v.append(contentsOf: s)
        return String(v)
    }

    static func dizge(_ s: [Unicode.Scalar]) -> String {
        return dizge(s[0..<s.count])
    }

    static func kirp(_ s: String) -> String {
        return Islem.kirpMetin(s)
    }

    /// JS `s.trim().split(/\s+/).filter(Boolean)`
    static func kelimeler(_ s: String) -> [String] {
        var cikti: [String] = []
        var gecerli: [Unicode.Scalar] = []
        for u in s.unicodeScalars {
            if Tarih.bosluk(u) {
                if !gecerli.isEmpty { cikti.append(dizge(gecerli)); gecerli = [] }
            } else {
                gecerli.append(u)
            }
        }
        if !gecerli.isEmpty { cikti.append(dizge(gecerli)) }
        return cikti
    }

    static func satirSonuMu(_ u: Unicode.Scalar) -> Bool {
        return u == "\n" || u == "\r" || u.value == 0x2028 || u.value == 0x2029
    }

    static func sozcukMu(_ u: Unicode.Scalar) -> Bool {
        return Tarih.rakam(u) || Tarih.harf(u) || u == "_"
    }

    /// `g(r)`: tüm `@` işaretlerini siler.
    static func atsiz(_ s: String) -> String {
        var v = String.UnicodeScalarView()
        for u in s.unicodeScalars where u != "@" { v.append(u) }
        return String(v)
    }

    /// JS nesne anahtar sırası: dizi indeksi gibi görünen anahtarlar (artan sayı) önce, ötekiler ekleme sırasıyla.
    static func jsSira(_ anahtarlar: [String]) -> [String] {
        var sayisal: [(UInt64, String)] = []
        var digerleri: [String] = []
        for k in anahtarlar {
            if let n = diziIndeksi(k) { sayisal.append((n, k)) } else { digerleri.append(k) }
        }
        sayisal.sort { $0.0 < $1.0 }
        return sayisal.map { $0.1 } + digerleri
    }

    static func diziIndeksi(_ k: String) -> UInt64? {
        let u = Array(k.unicodeScalars)
        if u.isEmpty || u.count > 10 { return nil }
        for c in u where !Tarih.rakam(c) { return nil }
        if u.count > 1 && u[0] == "0" { return nil }
        guard let n = UInt64(k), n < 4_294_967_295 else { return nil }
        return n
    }

    // MARK: splitGedName (web satır 1298)

    /// "Mehmet Ali /Kara Yılmaz/" -> (Mehmet Ali, Kara Yılmaz); eğik çizgi yoksa son kelime soyadı.
    public static func splitGedName(_ v: String) -> (given: String, surname: String) {
        let s = Array(v.unicodeScalars)
        if let a = s.firstIndex(of: "/") {
            var b: Int? = nil
            var i = a + 1
            while i < s.count {
                if s[i] == "/" { b = i; break }
                i += 1
            }
            let m1 = s[0..<a]
            let m2 = s[(a + 1)..<(b ?? s.count)]
            let m3: ArraySlice<Unicode.Scalar> = b.map { s[($0 + 1)...] } ?? []
            // JS `.` satır sonu eşleştirmez: sonda satır sonu olan değer eğik çizgisiz yola düşer
            if !m3.contains(where: { satirSonuMu($0) }) {
                let birlesik = "\(dizge(m1)) \(dizge(m3))"
                let ad = kelimeler(birlesik).joined(separator: " ")
                return (ad, kirp(dizge(m2)))
            }
        }
        let p = kelimeler(v)
        let ad: String
        if p.count > 1 {
            ad = p.dropLast().joined(separator: " ")
        } else {
            ad = p.first ?? ""
        }
        return (ad, p.count > 1 ? p[p.count - 1] : "")
    }

    // MARK: parseGED (web satır 1304)

    struct Satir {
        var seviye: Int
        var ref: String?
        var etiket: String
        var deger: String
    }

    /// `/^(\d+)\s+(@[^@]+@)?\s*(\w+)\s*(.*)?$/`
    static func satirCoz(_ s: [Unicode.Scalar]) -> Satir? {
        let n = s.count
        var i = 0
        while i < n && Tarih.rakam(s[i]) { i += 1 }
        if i == 0 { return nil }
        let seviye = Int(dizge(s[0..<i])) ?? Int.max
        let bosBas = i
        while i < n && Tarih.bosluk(s[i]) { i += 1 }
        if i == bosBas { return nil }
        var ref: String? = nil
        if i < n && s[i] == "@" {
            var k = i + 1
            while k < n && s[k] != "@" { k += 1 }
            if k < n && k > i + 1 {
                ref = dizge(s[i...k])
                i = k + 1
            }
        }
        while i < n && Tarih.bosluk(s[i]) { i += 1 }
        let etiketBas = i
        while i < n && sozcukMu(s[i]) { i += 1 }
        if i == etiketBas { return nil }
        let etiket = dizge(s[etiketBas..<i])
        while i < n && Tarih.bosluk(s[i]) { i += 1 }
        let kalan = s[i..<n]
        if kalan.contains(where: { satirSonuMu($0) }) { return nil }
        return Satir(seviye: seviye, ref: ref, etiket: etiket, deger: kirp(dizge(kalan)))
    }

    struct HamKisi {
        var fn: String?
        var ln = ""
        var mn = ""
        var gn: String?
        var dead = false
        var oc = ""
        var bd = ""
        var bp = ""
        var dd = ""
        var dp = ""
        var no = ""
    }

    struct HamAile {
        var h = ""
        var w = ""
        var c: [String] = []
        var div = false
    }

    struct YeniKisi {
        var id: String
        var ham: HamKisi
        var father: String?
        var mother: String?
        var spouse: String?
        var spouses: [EsBag] = []
        var children: [String] = []
    }

    static func nesneYap(_ y: YeniKisi) -> Nesne {
        let s = y.ham
        let es: [JSON] = y.spouses.map { .object(Nesne([("id", .string($0.id)), ("status", .string($0.status))])) }
        func bag(_ v: String?) -> JSON { return v.map { JSON.string($0) } ?? .null }
        let kizlik = s.gn == "F" ? Metin.capStr(s.mn) : ""
        let ciftler: [(String, JSON)] = [
            ("id", .string(y.id)),
            ("firstName", .string(Metin.capStr(s.fn ?? ""))),
            ("lastName", .string(Metin.capStr(s.ln))),
            ("gender", .string(s.gn ?? "M")),
            ("birthDate", .string(Tarih.normDate(s.bd))),
            ("birthPlace", .string(Metin.capStr(s.bp))),
            ("deathDate", .string(Tarih.normDate(s.dd))),
            ("deathPlace", .string(Metin.capStr(s.dp))),
            ("deceased", .bool(s.dead)),
            ("occupation", .string(Metin.capStr(s.oc))),
            ("notes", .string(kirp(s.no))),
            ("maidenName", .string(kizlik)),
            ("maritalStatus", .string("married")),
            ("photo", .null),
            ("gallery", .array([])),
            ("mother", bag(y.mother)),
            ("father", bag(y.father)),
            ("spouse", bag(y.spouse)),
            ("spouses", .array(es)),
            ("children", .array(y.children.map { JSON.string($0) }))
        ]
        return Nesne(ciftler)
    }

    /// Metni ayrıştırıp yeni kişileri `a.newId()` ile numaralayarak döndürür (sıra: JS nesne anahtar sırası).
    static func ayristir(_ metin: String, _ a: inout Agac) -> [(String, Nesne)] {
        var kisiAnahtar: [String] = []
        var kisiler: [String: HamKisi] = [:]
        var aileAnahtar: [String] = []
        var aileler: [String: HamAile] = [:]
        var turu = ""   // "I" | "F" | ""
        var kimlik = ""
        var etiket = ""

        for satir in satirlaraBol(metin) {
            guard let m = satirCoz(satir) else { continue }
            let lv = m.seviye
            let t = m.etiket
            let v = m.deger
            if lv == 0 {
                turu = ""
                etiket = ""
                if let r = m.ref, t == "INDI" {
                    turu = "I"
                    kimlik = atsiz(r)
                    if kisiler[kimlik] == nil { kisiAnahtar.append(kimlik) }
                    kisiler[kimlik] = HamKisi()
                } else if let r = m.ref, t == "FAM" {
                    turu = "F"
                    kimlik = atsiz(r)
                    if aileler[kimlik] == nil { aileAnahtar.append(kimlik) }
                    aileler[kimlik] = HamAile()
                }
                continue
            }
            if turu == "I", var cur = kisiler[kimlik] {
                if lv == 1 && t == "NAME" {
                    let nm = splitGedName(v)
                    if cur.fn == nil {
                        cur.fn = nm.given
                        cur.ln = nm.surname
                    } else if !nm.surname.isEmpty && nm.surname != cur.ln && cur.mn.isEmpty {
                        cur.mn = nm.surname
                    }
                }
                if lv == 1 && t == "SEX" { cur.gn = v == "M" ? "M" : "F" }
                if lv == 1 && (t == "BIRT" || t == "DEAT" || t == "OCCU" || t == "NOTE") {
                    etiket = t
                    if t == "OCCU" { cur.oc = v }
                    if t == "NOTE" { cur.no = (cur.no.isEmpty ? "" : cur.no + "\n") + v }
                }
                if lv == 2 && etiket == "NOTE" && t == "CONT" { cur.no = cur.no + "\n" + v }
                if lv == 2 && etiket == "NOTE" && t == "CONC" { cur.no = cur.no + v }
                if lv == 2 && etiket == "BIRT" && t == "DATE" { cur.bd = v }
                if lv == 2 && etiket == "BIRT" && t == "PLAC" { cur.bp = v }
                if lv == 1 && t == "DEAT" { cur.dead = true }
                if lv == 2 && etiket == "DEAT" && t == "DATE" { cur.dd = v }
                if lv == 2 && etiket == "DEAT" && t == "PLAC" { cur.dp = v }
                if lv == 1 && !["BIRT", "DEAT", "OCCU", "NOTE"].contains(t) { etiket = "" }
                kisiler[kimlik] = cur
            }
            if turu == "F", var cur = aileler[kimlik] {
                if lv == 1 && t == "HUSB" { cur.h = atsiz(v) }
                if lv == 1 && t == "WIFE" { cur.w = atsiz(v) }
                if lv == 1 && t == "CHIL" { cur.c.append(atsiz(v)) }
                if lv == 1 && t == "DIV" { cur.div = true }
                aileler[kimlik] = cur
            }
        }

        var im: [String: String] = [:]
        var sirali: [String] = []
        for gid in jsSira(kisiAnahtar) {
            let pid = Islem.newId(&a)
            im[gid] = pid
            sirali.append(pid)
        }
        var yeni: [String: YeniKisi] = [:]
        for gid in jsSira(kisiAnahtar) {
            guard let pid = im[gid], let src = kisiler[gid] else { continue }
            yeni[pid] = YeniKisi(id: pid, ham: src, father: nil, mother: nil, spouse: nil)
        }
        for fid in jsSira(aileAnahtar) {
            guard let fam = aileler[fid] else { continue }
            let h: String? = fam.h.isEmpty ? nil : im[fam.h]
            let w: String? = fam.w.isEmpty ? nil : im[fam.w]
            let ch = fam.c.compactMap { im[$0] }
            if let h = h, let w = w {
                let ms = fam.div ? "divorced" : "married"
                if var kh = yeni[h] {
                    if !kh.spouses.contains(where: { $0.id == w }) { kh.spouses.append(EsBag(id: w, status: ms)) }
                    kh.spouse = w
                    yeni[h] = kh
                }
                if var kw = yeni[w] {
                    if !kw.spouses.contains(where: { $0.id == h }) { kw.spouses.append(EsBag(id: h, status: ms)) }
                    kw.spouse = h
                    yeni[w] = kw
                }
            }
            for cid in ch {
                guard var cocuk = yeni[cid] else { continue }
                if let h = h {
                    cocuk.father = h
                    yeni[cid] = cocuk
                    if var kh = yeni[h], !kh.children.contains(cid) {
                        kh.children.append(cid)
                        yeni[h] = kh
                    }
                }
                if let w = w {
                    guard var c2 = yeni[cid] else { continue }
                    c2.mother = w
                    yeni[cid] = c2
                    if var kw = yeni[w], !kw.children.contains(cid) {
                        kw.children.append(cid)
                        yeni[w] = kw
                    }
                }
            }
        }
        var cikti: [(String, Nesne)] = []
        for pid in sirali {
            guard var y = yeni[pid] else { continue }
            var gorulen = Set<String>()
            y.children = y.children.filter { gorulen.insert($0).inserted }
            cikti.append((pid, nesneYap(y)))
        }
        return cikti
    }

    /// `parseGED(txt,false)`: ağacı değiştirir (kimlikler P1'den başlar).
    public static func parseGED(_ metin: String) -> Agac {
        var a = Agac(people: Nesne(), nextId: 1)
        let yeni = ayristir(metin, &a)
        var p = Nesne()
        for (k, v) in yeni { p[k] = .object(v) }
        a.people = p
        return a
    }

    /// `parseGED(txt,true)` önizleme açmadan öncesine kadar: yeni kişileri çakışmayan kimliklerle ekler,
    /// eklenen kimlikleri (JS anahtar sırasıyla) döndürür. Eşleştirme/birleştirme Task 5'tedir.
    public static func parseGEDEkle(_ metin: String, _ a: inout Agac) -> [String] {
        let yeni = ayristir(metin, &a)
        var ids: [String] = []
        for (k, v) in yeni {
            a.people[k] = .object(v)
            ids.append(k)
        }
        return ids
    }

    // MARK: expGED (web satır 2842)

    struct DisAile {
        var h: String?
        var w: String?
        var c: [String] = []
        var div = false
    }

    public static func expGED(_ a: Agac, tarih: Date, takvim: Calendar) -> String {
        var arr: [Kisi] = []
        for k in jsSira(a.people.anahtarlar) {
            if let p = a.kisi(k) { arr.append(p) }
        }
        var aileler: [DisAile] = []
        var aileSirasi: [String: Int] = [:]
        func getFam(_ h: String, _ w: String) -> Int {
            let anahtar = "\(h)|\(w)"
            if let i = aileSirasi[anahtar] { return i }
            aileler.append(DisAile(h: h.isEmpty ? nil : h, w: w.isEmpty ? nil : w))
            aileSirasi[anahtar] = aileler.count - 1
            return aileler.count - 1
        }
        for p in arr {
            for s in p.spouses {
                guard let sp = a.kisi(s.id) else { continue }
                let h = p.gender == "F" ? sp.id : p.id
                let w = p.gender == "F" ? p.id : sp.id
                if h == w { continue }
                let i = getFam(h, w)
                if s.status == "divorced" { aileler[i].div = true }
            }
        }
        for c in arr {
            let baba = c.father ?? ""
            let anne = c.mother ?? ""
            if baba.isEmpty && anne.isEmpty { continue }
            let i = getFam(baba, anne)
            if !aileler[i].c.contains(c.id) { aileler[i].c.append(c.id) }
        }

        var famsOf: [String: [String]] = [:]
        var famcOf: [String: [String]] = [:]
        for (n, f) in aileler.enumerated() {
            let fid = "F\(n + 1)"
            if let h = f.h { famsOf[h, default: []].append(fid) }
            if let w = f.w { famsOf[w, default: []].append(fid) }
            for cid in f.c { famcOf[cid, default: []].append(fid) }
        }

        let ay = Tarih.gAyDizi
        let gun = takvim.component(.day, from: tarih)
        let ayNo = takvim.component(.month, from: tarih)
        let yil = takvim.component(.year, from: tarih)
        var out = "0 HEAD\n1 SOUR SoyAgaci\n2 VERS \(Surum.web)\n2 NAME Soy Ağacı\n1 DEST ANY\n"
        out += "1 DATE \(gun) \(ay[ayNo - 1]) \(yil)\n"
        out += "1 GEDC\n2 VERS 5.5.1\n2 FORM LINEAGE-LINKED\n1 CHAR UTF-8\n"
        for p in arr {
            out += "0 @\(p.id)@ INDI\n1 NAME \(p.firstName) /\(p.lastName)/\n"
            if !p.firstName.isEmpty { out += "2 GIVN \(p.firstName)\n" }
            if !p.lastName.isEmpty { out += "2 SURN \(p.lastName)\n" }
            if !p.maidenName.isEmpty && p.gender == "F" {
                out += "1 NAME \(p.firstName) /\(p.maidenName)/\n2 TYPE birth\n2 SURN \(p.maidenName)\n"
            }
            if !p.gender.isEmpty { out += "1 SEX \(p.gender)\n" }
            if !p.birthDate.isEmpty || !p.birthPlace.isEmpty {
                out += "1 BIRT\n"
                if !p.birthDate.isEmpty { out += "2 DATE \(Tarih.toGedDate(p.birthDate))\n" }
                if !p.birthPlace.isEmpty { out += "2 PLAC \(p.birthPlace)\n" }
            }
            if !p.deathDate.isEmpty || !p.deathPlace.isEmpty {
                out += "1 DEAT\n"
                if !p.deathDate.isEmpty { out += "2 DATE \(Tarih.toGedDate(p.deathDate))\n" }
                if !p.deathPlace.isEmpty { out += "2 PLAC \(p.deathPlace)\n" }
            } else if p.deceased {
                out += "1 DEAT Y\n"
            }
            if !p.occupation.isEmpty { out += "1 OCCU \(p.occupation)\n" }
            if !p.notes.isEmpty {
                for (i, ln) in satirlaraBol(p.notes).enumerated() {
                    let onEk = i == 0 ? "1 NOTE " : "2 CONT "
                    out += "\(onEk)\(dizge(ln))\n"
                }
            }
            for fid in famcOf[p.id] ?? [] { out += "1 FAMC @\(fid)@\n" }
            for fid in famsOf[p.id] ?? [] { out += "1 FAMS @\(fid)@\n" }
        }
        for (n, f) in aileler.enumerated() {
            out += "0 @F\(n + 1)@ FAM\n"
            if let h = f.h { out += "1 HUSB @\(h)@\n" }
            if let w = f.w { out += "1 WIFE @\(w)@\n" }
            if f.div {
                out += "1 DIV Y\n"
            } else if f.h != nil && f.w != nil {
                out += "1 MARR\n"
            }
            for cid in f.c { out += "1 CHIL @\(cid)@\n" }
        }
        out += "0 TRLR\n"
        return out
    }
}
