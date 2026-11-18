import Foundation

/// Web `bloodLink` dönüş nesnesi: ortak en yakın ata ve aradaki yollar.
public struct KanBagi: Equatable {
    /// A'dan ortak ataya yukarı adım sayısı.
    public var a: Int
    /// B'den ortak ataya yukarı adım sayısı.
    public var b: Int
    /// Ortak ata (A == B ise yok).
    public var x: String?
    /// A'nın ebeveyni ... X
    public var upA: [String]
    /// X'in çocuğu ... B
    public var downB: [String]

    public init(a: Int, b: Int, x: String?, upA: [String], downB: [String]) {
        self.a = a
        self.b = b
        self.x = x
        self.upA = upA
        self.downB = downB
    }
}

/// Web `kinship` dönüş nesnesi (`null` → `nil`). Web alan adları; `self` Swift'te kullanılamadığından `ayni`.
public struct AkrabalikSonuc: Equatable {
    /// Web `{self:true}`
    public var ayni: Bool
    public var words: [String]
    public var note: String
    /// Kan bağında ortak ata
    public var common: String?
    /// En kısa zincir (son çare)
    public var chain: Bool

    public init(ayni: Bool = false, words: [String] = [], note: String = "", common: String? = nil, chain: Bool = false) {
        self.ayni = ayni
        self.words = words
        self.note = note
        self.common = common
        self.chain = chain
    }
}

/// Web `buildFamilies()` sonucu (famMap / famOf / parentFam) + kişi önbelleği.
/// Çok sorgu için bir kez kurup `Akrabalik` fonksiyonlarının `AileModeli` aşırı yüklemelerine verin.
public struct AileModeli {
    public struct Aile: Equatable {
        public var key: String
        public var a: String
        public var b: String?
        public var status: String
        public var kids: [String]

        public init(key: String, a: String, b: String?, status: String, kids: [String]) {
            self.key = key
            self.a = a
            self.b = b
            self.status = status
            self.kids = kids
        }
    }

    public private(set) var aileler: [Aile] = []
    /// kişi -> aile dizini (web `famOf`, eş sırasıyla)
    public private(set) var famOf: [String: [Int]] = [:]
    /// çocuk -> aile dizini (web `parentFam`)
    public private(set) var parentFam: [String: Int] = [:]
    /// çift anahtarı (pairKey) -> aileler dizini (web `famMap` anahtarları)
    public private(set) var aileIndeks: [String: Int] = [:]
    /// Web `Object.keys(people)` sırası (yalnızca kişi olan kayıtlar)
    public private(set) var sira: [String] = []
    var kisiler: [String: Kisi] = [:]
    /// kişi -> doğum yılı (yoksa "9999"), web `yearOf(birthDate)||'9999'`
    var dogumYili: [String: String] = [:]

    public init(_ agac: Agac) {
        for k in agac.people.anahtarlar {
            if let kisi = agac.kisi(k) {
                kisiler[k] = kisi
                sira.append(k)
                let y = Tarih.yearOf(kisi.birthDate)
                dogumYili[k] = y.isEmpty ? "9999" : y
            }
        }
        kur(sira)
    }

    /// Ham cinsiyet değeri: alan yoksa nil (JS `undefined`), "" ile aynı DEĞİLDİR.
    func cinsiyet(_ id: String) -> JSON? { return kisiler[id]?.ham["gender"] }

    /// Web `partnerIn(F,id)`
    public func partnerIn(_ f: Aile, _ id: String) -> String? {
        return f.a == id ? f.b : f.a
    }

    /// Erkek önde olacak şekilde çift anahtarı (tek ebeveyn: "id|")
    public func pairKey(_ x: String?, _ y: String?) -> String {
        guard let x = x, !x.isEmpty, let y = y, !y.isEmpty else {
            let t = (x == nil || x!.isEmpty) ? (y ?? "") : x!
            return t + "|"
        }
        let gx = cinsiyet(x)
        let gy = cinsiyet(y)
        if gx == JSON.string("F") && gy == JSON.string("M") { return y + "|" + x }
        if gx == gy && AileModeli.jsBuyuk(x, y) { return y + "|" + x }
        return x + "|" + y
    }

    /// JS `x > y` (UTF-16 kod birimi sırası)
    static func jsBuyuk(_ x: String, _ y: String) -> Bool {
        return Array(y.utf16).lexicographicallyPrecedes(Array(x.utf16))
    }

    private mutating func kur(_ sira: [String]) {
        func aileBul(_ m: inout AileModeli, _ x: String?, _ y: String?) -> Int {
            let k = m.pairKey(x, y)
            if let i = m.aileIndeks[k] { return i }
            let parca = k.split(separator: "|", omittingEmptySubsequences: false).map { String($0) }
            let a = parca[0]
            let b: String? = (parca.count > 1 && !parca[1].isEmpty) ? parca[1] : nil
            m.aileler.append(Aile(key: k, a: a, b: b, status: "married", kids: []))
            m.aileIndeks[k] = m.aileler.count - 1
            return m.aileler.count - 1
        }
        // Çocuğun ebeveynleri: father/mother alanları + onu children listesinde tutanlar
        var par: [String: [String]] = [:]
        for id in sira {
            guard let p = kisiler[id] else { continue }
            for c in p.children where kisiler[c] != nil && c != p.id {
                var l = par[c] ?? []
                if !l.contains(p.id) { l.append(p.id) }
                par[c] = l
            }
        }
        for id in sira {
            guard let c = kisiler[id] else { continue }
            var f: String? = (c.father != nil && kisiler[c.father!] != nil) ? c.father : nil
            var m: String? = (c.mother != nil && kisiler[c.mother!] != nil) ? c.mother : nil
            for x in par[c.id] ?? [] {
                if x == f || x == m { continue }
                if kisiler[x]?.gender == "F" {
                    if m == nil { m = x }
                } else if f == nil {
                    f = x
                }
            }
            if f == nil && m == nil { continue }
            let i = aileBul(&self, f, m)
            aileler[i].kids.append(c.id)
            parentFam[c.id] = i
        }
        for id in sira {
            guard let p = kisiler[id] else { continue }
            for s in p.spouses {
                if kisiler[s.id] == nil || s.id == p.id { continue }
                let i = aileBul(&self, p.id, s.id)
                if !s.status.isEmpty && s.status != "married" { aileler[i].status = s.status }
            }
        }
        for i in 0..<aileler.count {
            // kararlı sıralama (yıl yoksa "9999")
            let yillar = aileler[i].kids.map { yil($0) }
            let dizin = Array(0..<yillar.count).sorted { (p, q) in
                if yillar[p] != yillar[q] { return yillar[p] < yillar[q] }
                return p < q
            }
            let eski = aileler[i].kids
            aileler[i].kids = dizin.map { eski[$0] }
            for x in [aileler[i].a, aileler[i].b ?? ""] where !x.isEmpty {
                famOf[x, default: []].append(i)
            }
        }
        // Eş sırası kişinin spouses dizisini izler; tek ebeveynli aile en sonda
        for id in Array(famOf.keys) {
            let ord = (kisiler[id]?.spouses ?? []).map { $0.id }
            func rank(_ f: Aile) -> Int {
                let o: String? = f.a == id ? f.b : f.a
                guard let oo = o, !oo.isEmpty else { return 999 }
                if let i = ord.firstIndex(of: oo) { return i }
                return 500
            }
            let liste = famOf[id] ?? []
            let rutbe = liste.map { rank(aileler[$0]) }
            let dizin = Array(0..<liste.count).sorted { (p, q) in
                if rutbe[p] != rutbe[q] { return rutbe[p] < rutbe[q] }
                return p < q
            }
            famOf[id] = dizin.map { liste[$0] }
        }
    }

    private func yil(_ id: String) -> String {
        return dogumYili[id] ?? "9999"
    }

    /// Web `parentsOf`
    func parentsOf(_ id: String) -> [String] {
        guard let i = parentFam[id] else { return [] }
        let f = aileler[i]
        var r = [f.a]
        if let b = f.b, !b.isEmpty { r.append(b) }
        return r.filter { !$0.isEmpty }
    }

    /// Web `gnd`
    func gnd(_ id: String) -> String {
        return kisiler[id]?.gender == "F" ? "F" : "M"
    }

    /// Web `spousesOf`
    func spousesOf(_ id: String) -> [EsBag] {
        return (kisiler[id]?.spouses ?? []).filter { kisiler[$0.id] != nil }
    }
}

/// Türkçe akrabalık (web v6.1 modülü: genOf, bloodLink, kinship, kinPhrase, kinSentence).
public enum Akrabalik {
    // MARK: sözlük

    /// Her kelimenin [iyelik, iyelik+tamlayan] hâli: "babası" / "babasının"
    static let KW: [String: (String, String)] = [
        "baba": ("babası", "babasının"), "anne": ("annesi", "annesinin"), "dede": ("dedesi", "dedesinin"),
        "babaanne": ("babaannesi", "babaannesinin"), "anneanne": ("anneannesi", "anneannesinin"),
        "ogul": ("oğlu", "oğlunun"), "kiz": ("kızı", "kızının"), "cocuk": ("çocuğu", "çocuğunun"), "torun": ("torunu", "torununun"),
        "ekardes": ("erkek kardeşi", "erkek kardeşinin"), "kkardes": ("kız kardeşi", "kız kardeşinin"),
        "abi": ("ağabeyi", "ağabeyinin"), "abla": ("ablası", "ablasının"),
        "bababir": ("baba bir kardeşi", "baba bir kardeşinin"), "annebir": ("anne bir kardeşi", "anne bir kardeşinin"),
        "amca": ("amcası", "amcasının"), "hala": ("halası", "halasının"), "dayi": ("dayısı", "dayısının"), "teyze": ("teyzesi", "teyzesinin"),
        "yegen": ("yeğeni", "yeğeninin"), "kuzen": ("kuzeni", "kuzeninin"), "es": ("eşi", "eşinin"), "eskies": ("eski eşi", "eski eşinin"),
        "kayinpeder": ("kayınpederi", "kayınpederinin"), "kayinvalide": ("kayınvalidesi", "kayınvalidesinin"),
        "kayinbirader": ("kayınbiraderi", "kayınbiraderinin"), "baldiz": ("baldızı", "baldızının"), "gorumce": ("görümcesi", "görümcesinin"),
        "gelin": ("gelini", "gelininin"), "damat": ("damadı", "damadının"), "yenge": ("yengesi", "yengesinin"),
        "eniste": ("eniştesi", "eniştesinin"), "elti": ("eltisi", "eltisinin"), "bacanak": ("bacanağı", "bacanağının"),
        "uveyanne": ("üvey annesi", "üvey annesinin"), "uveybaba": ("üvey babası", "üvey babasının"),
        "uveyogul": ("üvey oğlu", "üvey oğlunun"), "uveykiz": ("üvey kızı", "üvey kızının")
    ]

    /// Web `phrase`: son kelime iyelik, öncekiler iyelik+tamlayan hâlinde.
    static func phrase(_ w: [String]) -> String {
        var parcalar: [String] = []
        for (i, x) in w.enumerated() {
            let t = KW[x] ?? ("", "")
            parcalar.append(i == w.count - 1 ? t.0 : t.1)
        }
        return parcalar.joined(separator: " ")
    }

    // MARK: genOf

    /// Özel adın tamlayan eki: Kamil'in, Ayşe'nin, Mustafa'nın, Ümmügülsün'ün
    public static func genOf(_ ad: String) -> String {
        let kirpik = String(String.UnicodeScalarView(Tarih.kirp(ad)))
        let n = kirpik.isEmpty ? "Bu kişi" : kirpik
        let lo = Array(Metin.trKatla(n).unicodeScalars)
        let unluler = Set("aeıioöuü".unicodeScalars)
        var lv: Unicode.Scalar = "e"
        for u in lo.reversed() where unluler.contains(u) {
            lv = u
            break
        }
        let h: String
        switch lv {
        case "a", "ı": h = "ı"
        case "e", "i": h = "i"
        case "o", "u": h = "u"
        default: h = "ü" // ö, ü
        }
        let unluyleBitiyor = lo.last.map { unluler.contains($0) } ?? false
        return n + "'" + (unluyleBitiyor ? "n" : "") + h + "n"
    }

    // MARK: kelime üretimi

    /// Atalara doğru: [baba, anne, ...] → dede/babaanne/anneanne kısaltmalı kelimeler
    static func upWords(_ ids: [String], _ m: AileModeli) -> [String] {
        let g = ids.map { m.gnd($0) }
        if g.isEmpty { return [] }
        if g.count == 1 { return [g[0] == "M" ? "baba" : "anne"] }
        let ilk = g[1] == "M" ? "dede" : (g[0] == "M" ? "babaanne" : "anneanne")
        var r = [ilk]
        for x in g.dropFirst(2) { r.append(x == "M" ? "baba" : "anne") }
        return r
    }

    /// Torunlara doğru: ikişer kuşak "torun", artan tek kuşak "oğul/kız"
    static func downWords(_ ids: [String], _ m: AileModeli) -> [String] {
        var w: [String] = []
        var i = 0
        while ids.count - i >= 2 {
            w.append("torun")
            i += 2
        }
        if i < ids.count { w.append(m.gnd(ids[i]) == "M" ? "ogul" : "kiz") }
        return w
    }

    // MARK: bloodLink

    /// Ortak en yakın ata: A'dan yukarı adım, B'den yukarı adım ve aradaki yollar; kan bağı yoksa nil.
    public static func bloodLink(_ A: String, _ B: String, _ t: Agac) -> KanBagi? {
        return bloodLink(A, B, AileModeli(t))
    }

    public static func bloodLink(_ A: String, _ B: String, _ m: AileModeli) -> KanBagi? {
        if A == B { return KanBagi(a: 0, b: 0, x: nil, upA: [], downB: []) }
        struct Ziyaret {
            var sira: [String] = []
            var d: [String: Int] = [:]
            var onceki: [String: String] = [:]
        }
        func anc(_ start: String) -> Ziyaret {
            var z = Ziyaret()
            z.sira = [start]
            z.d[start] = 0
            var q = [start]
            var bas = 0
            while bas < q.count {
                let x = q[bas]
                bas += 1
                for p in m.parentsOf(x) where z.d[p] == nil {
                    z.d[p] = (z.d[x] ?? 0) + 1
                    z.onceki[p] = x
                    z.sira.append(p)
                    q.append(p)
                }
            }
            return z
        }
        let mA = anc(A)
        let mB = anc(B)
        var best: (x: String, a: Int, b: Int)?
        for x in mA.sira {
            guard let db = mB.d[x], let da = mA.d[x] else { continue }
            if best == nil || da + db < best!.a + best!.b { best = (x, da, db) }
        }
        guard let bs = best else { return nil }
        // X → ... → kişi
        func zincir(_ z: Ziyaret, _ x: String) -> [String] {
            var r: [String] = []
            var c: String? = x
            while let cc = c {
                r.append(cc)
                c = z.onceki[cc]
            }
            return r
        }
        let upA = Array(zincir(mA, bs.x).reversed().dropFirst())
        let downB = Array(zincir(mB, bs.x).dropFirst())
        return KanBagi(a: bs.a, b: bs.b, x: bs.x, upA: upA, downB: downB)
    }

    // MARK: bloodWords / kinDetail

    static func bloodWords(_ A: String, _ B: String, _ L: KanBagi, _ m: AileModeli) -> [String] {
        let a = L.a
        let b = L.b
        let gB = m.gnd(B)
        if a == 0 { return downWords(L.downB, m) }
        if b == 0 { return upWords(L.upA, m) }
        if a == 1 && b == 1 {
            let pa = m.parentsOf(A)
            let pb = m.parentsOf(B)
            let full = pa.count == 2 && pb.count == 2 && pa.allSatisfy { pb.contains($0) }
            if !full { return [m.gnd(L.x ?? "") == "M" ? "bababir" : "annebir"] }
            let ya = Tarih.yearOf(m.kisiler[A]?.birthDate ?? "")
            let yb = Tarih.yearOf(m.kisiler[B]?.birthDate ?? "")
            if !ya.isEmpty && !yb.isEmpty, let iyb = Int(yb), let iya = Int(ya), iyb < iya {
                return [gB == "M" ? "abi" : "abla"]
            }
            return [gB == "M" ? "ekardes" : "kkardes"]
        }
        func sib(_ id: String) -> String { return m.gnd(id) == "M" ? "ekardes" : "kkardes" }
        func uncle(_ parentId: String, _ id: String) -> String {
            if m.gnd(parentId) == "M" { return m.gnd(id) == "M" ? "amca" : "hala" }
            return m.gnd(id) == "M" ? "dayi" : "teyze"
        }
        if a == 1 {
            return ["yegen"] + downWords(Array(L.downB.dropFirst(2)), m)
        }
        if a == 2 {
            if b == 2 { return ["kuzen"] }
            return [uncle(L.upA[0], L.downB[0])] + downWords(Array(L.downB.dropFirst(1)), m)
        }
        var r = upWords(Array(L.upA.prefix(a - 1)), m)
        r.append(sib(L.downB[0]))
        r.append(contentsOf: downWords(Array(L.downB.dropFirst(1)), m))
        return r
    }

    /// Kuzenler için "amcasının oğlu" gibi açıklama
    static func kinDetail(_ B: String, _ L: KanBagi, _ m: AileModeli) -> String {
        if L.b == 0 && L.a == 2 { return m.gnd(L.upA[0]) == "M" ? "baba tarafından" : "anne tarafından" }
        if L.a == 2 && L.b == 2 {
            let u: String
            if m.gnd(L.upA[0]) == "M" { u = m.gnd(L.downB[0]) == "M" ? "amca" : "hala" } else { u = m.gnd(L.downB[0]) == "M" ? "dayi" : "teyze" }
            return phrase([u, m.gnd(B) == "M" ? "ogul" : "kiz"])
        }
        return ""
    }

    // MARK: kinship

    public static func kinship(_ A: String, _ B: String, _ t: Agac) -> AkrabalikSonuc? {
        return kinship(A, B, AileModeli(t))
    }

    public static func kinship(_ A: String, _ B: String, _ m: AileModeli) -> AkrabalikSonuc? {
        if m.kisiler[A] == nil || m.kisiler[B] == nil { return nil }
        if A == B { return AkrabalikSonuc(ayni: true) }
        if let L = bloodLink(A, B, m) {
            return AkrabalikSonuc(words: bloodWords(A, B, L, m), note: kinDetail(B, L, m), common: L.x)
        }
        let esleri = m.spousesOf(A)
        if let sp = esleri.first(where: { $0.id == B }) {
            return AkrabalikSonuc(words: [sp.status == "divorced" ? "eskies" : "es"])
        }
        let gA = m.gnd(A)
        let gB = m.gnd(B)
        // Eşinin akrabası
        for s in esleri {
            let S = s.id
            guard let l = bloodLink(S, B, m) else { continue }
            if l.a == 1 && l.b == 0 { return AkrabalikSonuc(words: [gB == "M" ? "kayinpeder" : "kayinvalide"]) }
            if l.a == 1 && l.b == 1 { return AkrabalikSonuc(words: [gB == "M" ? "kayinbirader" : (gA == "M" ? "baldiz" : "gorumce")]) }
            if l.a == 0 && l.b == 1 { return AkrabalikSonuc(words: [gB == "M" ? "uveyogul" : "uveykiz"]) }
            return AkrabalikSonuc(words: ["es"] + bloodWords(S, B, l, m))
        }
        // Akrabasının eşi
        let besleri = m.spousesOf(B)
        for s in besleri {
            let R = s.id
            guard let l = bloodLink(A, R, m) else { continue }
            if l.a == 0 && l.b == 1 { return AkrabalikSonuc(words: [gB == "F" ? "gelin" : "damat"]) }
            if (l.a == 1 || l.a == 2) && l.b == 1 { return AkrabalikSonuc(words: [gB == "F" ? "yenge" : "eniste"]) }
            if l.a == 1 && l.b == 0 { return AkrabalikSonuc(words: [gB == "M" ? "uveybaba" : "uveyanne"]) }
            return AkrabalikSonuc(words: bloodWords(A, R, l, m) + ["es"])
        }
        // Eşinin kardeşinin eşi: elti / bacanak
        for s in esleri {
            for tt in besleri {
                guard let l = bloodLink(s.id, tt.id, m), l.a == 1, l.b == 1 else { continue }
                if gA == "F" && gB == "F" { return AkrabalikSonuc(words: ["elti"]) }
                if gA == "M" && gB == "M" { return AkrabalikSonuc(words: ["bacanak"]) }
                return AkrabalikSonuc(words: ["es", m.gnd(tt.id) == "M" ? "ekardes" : "kkardes", "es"])
            }
        }
        // Son çare: en kısa bağlantı zinciri (baba/anne/çocuk/eş)
        var gorulen: Set<String> = [A]
        var onceki: [String: (String, String)] = [:]
        var q = [A]
        var bas = 0
        while bas < q.count && !gorulen.contains(B) {
            let x = q[bas]
            bas += 1
            var nb: [(String, String)] = m.parentsOf(x).map { ($0, m.gnd($0) == "M" ? "baba" : "anne") }
            for i in m.famOf[x] ?? [] {
                for k in m.aileler[i].kids { nb.append((k, m.gnd(k) == "M" ? "ogul" : "kiz")) }
            }
            for sp in m.spousesOf(x) { nb.append((sp.id, "es")) }
            for (y, kel) in nb where !gorulen.contains(y) {
                gorulen.insert(y)
                onceki[y] = (x, kel)
                q.append(y)
            }
            if gorulen.count > 4000 { break }
        }
        if !gorulen.contains(B) { return nil }
        var w: [String] = []
        var c = B
        while let e = onceki[c] {
            w.insert(e.1, at: 0)
            c = e.0
        }
        return AkrabalikSonuc(words: w, chain: true)
    }

    // MARK: kinPhrase / kinSentence

    /// Kişi kartı için: "Kamil'in dedesi (anne tarafından)"; aynı kişi / bağ yoksa nil (web null).
    public static func kinPhrase(_ A: String, _ B: String, _ t: Agac) -> String? {
        return kinPhrase(A, B, AileModeli(t))
    }

    public static func kinPhrase(_ A: String, _ B: String, _ m: AileModeli) -> String? {
        guard let r = kinship(A, B, m), !r.ayni, let a = m.kisiler[A] else { return nil }
        return genOf(a.firstName) + " " + phrase(r.words) + (r.note.isEmpty ? "" : " (" + r.note + ")")
    }

    /// "Mustafa, Kamil'in babası (...)"; aynı kişi → "Aynı kişi"; bağ yoksa nil (web null).
    public static func kinSentence(_ A: String, _ B: String, _ t: Agac) -> String? {
        return kinSentence(A, B, AileModeli(t))
    }

    public static func kinSentence(_ A: String, _ B: String, _ m: AileModeli) -> String? {
        guard let r = kinship(A, B, m) else { return nil }
        if r.ayni { return "Aynı kişi" }
        guard let a = m.kisiler[A], let b = m.kisiler[B] else { return nil }
        let ad = b.firstName.isEmpty ? "Bu kişi" : b.firstName
        let s = ad + ", " + genOf(a.firstName) + " " + phrase(r.words)
        return s + (r.note.isEmpty ? "" : " (" + r.note + ")")
    }
}
