import Foundation

// Web `soy-agaci-7.0.0.html` l.3566-3939 `EDV` ad alaninin birebir portu (e-Devlet soy agaci -> GEDCOM).
// `tableToGrid` / HTML yapistirma tasinmadi (iOS'ta yapistirma duz metindir). xlsx/docx/pdf dosya okuyuculari
// uygulama katmaninda; burasi izgara/metin/pdf-parca -> kisi -> analiz -> GEDCOM mantigidir.

/// Izgaradan okunan bir kisi (web `gridToPersons` nesnesi).
public struct EDKisi: Codable, Equatable {
    public var sira: Int
    public var cinsiyet: String
    public var relationship: String
    public var givn: String
    public var surn: String
    public var babaAdi: String
    public var anaAdi: String
    public var birthPlace: String
    public var birthDate: String
    public var il: String
    public var ilce: String
    public var mahalle: String
    public var cilt: String
    public var hane: String
    public var birey: String
    public var medeniHal: String
    public var status: String
    public var deathDate: String

    public init(sira: Int, cinsiyet: String = "E", relationship: String = "", givn: String = "", surn: String = "",
                babaAdi: String = "", anaAdi: String = "", birthPlace: String = "", birthDate: String = "",
                il: String = "", ilce: String = "", mahalle: String = "", cilt: String = "", hane: String = "",
                birey: String = "", medeniHal: String = "", status: String = "sağ", deathDate: String = "") {
        self.sira = sira
        self.cinsiyet = cinsiyet
        self.relationship = relationship
        self.givn = givn
        self.surn = surn
        self.babaAdi = babaAdi
        self.anaAdi = anaAdi
        self.birthPlace = birthPlace
        self.birthDate = birthDate
        self.il = il
        self.ilce = ilce
        self.mahalle = mahalle
        self.cilt = cilt
        self.hane = hane
        self.birey = birey
        self.medeniHal = medeniHal
        self.status = status
        self.deathDate = deathDate
    }
}

/// Yakinlik belirteci: `t` F/M/C/E, `sex` yalniz C icin (M/F) olabilir.
public struct EDTok: Codable, Equatable {
    public var t: String
    public var sex: String?
    public init(t: String, sex: String? = nil) {
        self.t = t
        self.sex = sex
    }
}

/// Bir dugumun anne/babasi: belgedeki dugum (indeks) ya da yalniz adi bilinen "hayali" kisi.
public enum EDEbeveyn: Equatable {
    case dugum(Int)
    case hayali(anahtar: String, ad: String, cins: String, cocuk: Int)
}

public struct EDDugum: Equatable {
    public var kisi: EDKisi
    public var toks: [EDTok]
    public var path: String
    public var sex: String
    public var given: String
    public var father: EDEbeveyn?
    public var mother: EDEbeveyn?
    public init(kisi: EDKisi, toks: [EDTok], path: String, sex: String, given: String,
                father: EDEbeveyn? = nil, mother: EDEbeveyn? = nil) {
        self.kisi = kisi
        self.toks = toks
        self.path = path
        self.sex = sex
        self.given = given
        self.father = father
        self.mother = mother
    }
}

public struct EDAnaliz: Equatable {
    public var nodes: [EDDugum]
    public var warns: [String]
    public init(nodes: [EDDugum] = [], warns: [String] = []) {
        self.nodes = nodes
        self.warns = warns
    }
}

public struct EDSecenek: Equatable {
    public var tc: Bool
    public var ghost: Bool
    public var maiden: Bool
    public var note: Bool
    public init(tc: Bool = true, ghost: Bool = true, maiden: Bool = true, note: Bool = true) {
        self.tc = tc
        self.ghost = ghost
        self.maiden = maiden
        self.note = note
    }
}

/// pdf.js `getTextContent().items` ogesi: `str`, `transform[4]`=x, `transform[5]`=y, `width`, `height`.
/// `y` pdf.js kipinde YUKARI dogru artar (sayfa altindan olculur; ust satirlarin y'si buyuktur).
/// `h`: pdf.js `item.height`, 0 ise `abs(transform[3])`, o da 0 ise 8 (web `pdfToGrid` dusme degeri).
public struct PdfParca: Codable, Equatable {
    public var str: String
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double
    public init(str: String, x: Double, y: Double, w: Double, h: Double) {
        self.str = str
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }
}

public enum EDevlet {
    typealias S = [Unicode.Scalar]
    static let gedAylar = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

    // MARK: metin yardimcilari (JS semantigi)

    static func dz(_ s: ArraySlice<Unicode.Scalar>) -> String {
        var v = String.UnicodeScalarView()
        v.append(contentsOf: s)
        return String(v)
    }

    static func dz(_ s: S) -> String {
        return dz(s[0..<s.count])
    }

    static func kirp(_ s: String) -> String {
        return dz(Tarih.kirp(s))
    }

    /// JS `s.split(sep)` (sep tek skaler): bos parcalar korunur; bos metin -> [""].
    static func bol(_ a: S, _ sep: Unicode.Scalar) -> [S] {
        var cikti: [S] = []
        var gecerli: S = []
        for u in a {
            if u == sep {
                cikti.append(gecerli)
                gecerli = []
            } else {
                gecerli.append(u)
            }
        }
        cikti.append(gecerli)
        return cikti
    }

    /// `s.replace(/\s+/g,' ').trim()`
    static func bosluklariTek(_ s: String) -> String {
        var cikti: [String] = []
        var gecerli: S = []
        for u in s.unicodeScalars {
            if Tarih.bosluk(u) {
                if !gecerli.isEmpty { cikti.append(dz(gecerli)); gecerli = [] }
            } else {
                gecerli.append(u)
            }
        }
        if !gecerli.isEmpty { cikti.append(dz(gecerli)) }
        return cikti.joined(separator: " ")
    }

    static func esit(_ a: String, _ b: String) -> Bool {
        return Array(a.unicodeScalars) == Array(b.unicodeScalars)
    }

    static func onEk(_ a: String, _ p: String) -> Bool {
        return Array(a.unicodeScalars).starts(with: Array(p.unicodeScalars))
    }

    static func trBuyukMetin(_ s: String) -> String {
        var cikti = ""
        for u in s.unicodeScalars { cikti += Metin.trBuyuk(u) }
        return cikti
    }

    /// `^\d+$`
    static func tamRakam(_ s: String) -> Bool {
        let a = Array(s.unicodeScalars)
        if a.isEmpty { return false }
        for u in a where !Tarih.rakam(u) { return false }
        return true
    }

    /// JS `String(x||'')` ile ayni: hic `nil` yok, bos metin bos kalir.
    static func fold(_ s: String) -> String {
        var cikti = ""
        for u in trBuyukMetin(s).unicodeScalars where !Tarih.bosluk(u) { cikti.unicodeScalars.append(u) }
        return cikti
    }

    /// Web `titleCase`: `toLocaleLowerCase('tr-TR')`, sonra `(^|[\s\-'])(\S)` esleslerindeki `\S` buyur.
    public static func titleCase(_ s: String) -> String {
        let a = Array(Metin.trKatla(s).unicodeScalars)
        var cikti = ""
        var i = 0
        while i < a.count {
            if i == 0 && !Tarih.bosluk(a[0]) {
                cikti += Metin.trBuyuk(a[0])
                i = 1
            } else if (Tarih.bosluk(a[i]) || a[i] == "-" || a[i] == "'") && i + 1 < a.count && !Tarih.bosluk(a[i + 1]) {
                cikti.unicodeScalars.append(a[i])
                cikti += Metin.trBuyuk(a[i + 1])
                i += 2
            } else {
                cikti.unicodeScalars.append(a[i])
                i += 1
            }
        }
        return cikti
    }

    /// `^\d{1,2}[./-]\d{1,2}[./-]\d{4}$` (ASCII rakam) -> (gun, ay, yil)
    static func tarihUc(_ s: String) -> (Int, Int, Int)? {
        let a = Array(s.unicodeScalars)
        var i = 0
        func sayi(_ en: Int, _ cok: Int) -> Int? {
            var n = 0
            var d = 0
            while i < a.count && d < cok && Tarih.rakam(a[i]) {
                n = n * 10 + Int(a[i].value - 0x30)
                i += 1
                d += 1
            }
            return d >= en ? n : nil
        }
        func ayirac() -> Bool {
            if i < a.count && Tarih.ayiracMi(a[i]) { i += 1; return true }
            return false
        }
        guard let g = sayi(1, 2), ayirac(), let m = sayi(1, 2), ayirac(), let y = sayi(4, 4), i == a.count else { return nil }
        return (g, m, y)
    }

    static func tarihMi(_ s: String) -> Bool {
        return tarihUc(s) != nil
    }

    // MARK: textToGrid

    /// Telefondan yapistirilan duz metin: numarayla baslayan satir yeni kayit, sonrakiler o kayda eklenir.
    public static func textToGrid(_ text: String) -> [[String]] {
        var recs: [[S]] = []
        var cur: Int? = nil
        var temiz: S = []
        for u in text.unicodeScalars where u != "\r" { temiz.append(u) }
        for l in bol(temiz, "\n") {
            var i = 0
            while i < l.count && Tarih.bosluk(l[i]) { i += 1 }
            var j = i
            while j < l.count && Tarih.rakam(l[j]) { j += 1 }
            let numarali = j > i && j < l.count && l[j] == "\t"
            if numarali {
                recs.append([l])
                cur = recs.count - 1
            } else if let c = cur, !Tarih.kirp(dz(l)).isEmpty {
                recs[c].append(l)
            } else if cur == nil {
                recs.append([l])
            }
        }
        var cikti: [[String]] = []
        for r in recs {
            var birlesik: S = []
            for (k, l) in r.enumerated() {
                if k > 0 { birlesik.append("\n") }
                birlesik.append(contentsOf: l)
            }
            cikti.append(bol(birlesik, "\t").map { dz($0) })
        }
        return cikti
    }

    // MARK: gridToPersons

    static func satirlar(_ s: String) -> [String] {
        var cikti: [String] = []
        for p in bol(Array(s.unicodeScalars), "\n") {
            let t = bosluklariTek(dz(p))
            if !t.isEmpty { cikti.append(t) }
        }
        return cikti
    }

    static func normMedi(_ s: String) -> String {
        let l = Metin.trKatla(s)
        if onEk(l, "dul") { return "dul" }
        if onEk(l, "evli") { return "evli" }
        if onEk(l, "bek") { return "bekar" }
        if onEk(l, "boş") { return "boşanmış" }
        return ""
    }

    /// Satir sonundaki tek `/` atilir (`replace(/\/$/,'')`).
    static func sonEgikSil(_ s: String) -> String {
        var a = Array(s.unicodeScalars)
        if let son = a.last, son == "/" { a.removeLast() }
        return dz(a)
    }

    /// Izgara (satirlar x 12 sutun) -> kisiler. Sutunlar: 0 Sira, 1 C, 2 Yakinlik, 3 Adi, 4 Soyadi, 5 Baba, 6 Ana,
    /// 7 Dogum yeri/tarihi, 8 Il-Ilce-Mahalle, 9 Cilt-Hane-Birey, 10 Medeni hal, 11 Durum.
    public static func gridToPersons(_ grid: [[String]]) -> [EDKisi] {
        var hucreler: [[[String]]] = []
        var cur: Int? = nil
        for row in grid {
            if row.isEmpty { continue }
            let first = kirp(row[0])
            if tamRakam(first) {
                hucreler.append(Array(repeating: [], count: 12))
                cur = hucreler.count - 1
            } else if cur == nil || !first.isEmpty {
                continue
            } else {
                var baskaVar = false
                for (i, v) in row.enumerated() where !kirp(v).isEmpty && ![2, 7, 8, 11].contains(i) { baskaVar = true }
                if baskaVar {
                    cur = nil
                    continue
                }
            }
            guard let c = cur else { continue }
            for k in 0..<12 where k < row.count {
                hucreler[c][k].append(contentsOf: satirlar(row[k]))
            }
        }
        var cikti: [EDKisi] = []
        for c in hucreler {
            func tire(_ v: String) -> String { return (!v.isEmpty && v != "-") ? v : "" }
            let dYer = c[7].first(where: { !tarihMi($0) }) ?? ""
            let dTar = c[7].first(where: { tarihMi($0) }) ?? ""
            let durum = c[11].first ?? ""
            let olum = c[11].dropFirst().first(where: { tarihMi($0) }) ?? ""
            let parcalar = bol(Array(c[9].joined().unicodeScalars), "-").map { kirp(dz($0)) }
            let cilt = parcalar.count > 0 ? parcalar[0] : ""
            let hane = parcalar.count > 1 ? parcalar[1] : ""
            let birey = parcalar.count > 2 ? parcalar[2] : ""
            let kIlk = Array((c[1].first ?? "").unicodeScalars).first
            let dl = durum.lowercased()
            let olu = dl.contains("ölüm") || dl.contains("olum") || dl.contains("vefat")
            let siraMetin = c[0].first ?? ""
            let k = EDKisi(
                sira: Int(siraMetin) ?? 0,
                cinsiyet: (kIlk == "k" || kIlk == "K") ? "K" : "E",
                relationship: bosluklariTek(c[2].joined(separator: " ")),
                givn: c[3].joined(separator: " "),
                surn: tire(c[4].joined(separator: " ")),
                babaAdi: tire(c[5].joined(separator: " ")),
                anaAdi: tire(c[6].joined(separator: " ")),
                birthPlace: dYer,
                birthDate: dTar,
                il: sonEgikSil(c[8].count > 0 ? c[8][0] : ""),
                ilce: sonEgikSil(c[8].count > 1 ? c[8][1] : ""),
                mahalle: c[8].dropFirst(2).joined(separator: " "),
                cilt: cilt,
                hane: hane,
                birey: birey,
                medeniHal: normMedi(c[10].first ?? ""),
                status: olu ? "ölüm" : "sağ",
                deathDate: olum)
            if !k.givn.isEmpty || !k.surn.isEmpty { cikti.append(k) }
        }
        return cikti
    }

    // MARK: gedDate

    /// `GG/AA/YYYY` -> `D MON YYYY`; 01/07 ve yil < 1960 -> yalniz yil; bicim tanimsizsa kirpilmis metin.
    public static func gedDate(_ s: String) -> String {
        let t = kirp(s)
        guard let (d, mo, y) = tarihUc(t) else { return t }
        if d == 1 && mo == 7 && y < 1960 { return String(y) }
        let ay = (mo >= 1 && mo <= 12) ? gedAylar[mo - 1] : "undefined"
        return "\(d) \(ay) \(y)"
    }

    // MARK: relTokens

    /// Yakinlik metni -> belirtecler; taninmayan sozcukte `nil`.
    public static func relTokens(_ rel: String) -> [String]? {
        guard let t = tokens(rel) else { return nil }
        return t.map { $0.t }
    }

    /// Belirtec nesneleriyle (cinsiyetli) `relTokens`.
    public static func relTokenler(_ rel: String) -> [EDTok]? {
        return tokens(rel)
    }

    static func tokens(_ rel: String) -> [EDTok]? {
        var cikti: [EDTok] = []
        for w in Gedcom.kelimeler(Metin.trKatla(rel)) {
            if esit(w, "kendisi") { continue }
            if onEk(w, "baba") {
                cikti.append(EDTok(t: "F"))
            } else if onEk(w, "anne") || esit(w, "ana") || esit(w, "anası") || esit(w, "anasının") {
                cikti.append(EDTok(t: "M"))
            } else if onEk(w, "oğl") || onEk(w, "ogl") {
                cikti.append(EDTok(t: "C", sex: "M"))
            } else if onEk(w, "kız") || onEk(w, "kiz") {
                cikti.append(EDTok(t: "C", sex: "F"))
            } else if onEk(w, "çocu") || onEk(w, "cocu") {
                cikti.append(EDTok(t: "C"))
            } else if onEk(w, "torun") {
                cikti.append(EDTok(t: "C"))
                cikti.append(EDTok(t: "C"))
            } else if onEk(w, "eş") || esit(w, "esi") {
                cikti.append(EDTok(t: "E"))
            } else {
                return nil
            }
        }
        return cikti
    }

    // MARK: analyze

    static func hepsiFME(_ p: String) -> Bool {
        for u in p.unicodeScalars where !(u == "F" || u == "M" || u == "E") { return false }
        return true
    }

    /// `/E./`: yolda sonda olmayan bir `E` var.
    static func eSonrasiVar(_ p: String) -> Bool {
        let a = Array(p.unicodeScalars)
        for (i, u) in a.enumerated() where u == "E" && i + 1 < a.count { return true }
        return false
    }

    static func hepsiFM(_ p: String) -> Bool {
        if p.isEmpty { return false }
        for u in p.unicodeScalars where !(u == "F" || u == "M") { return false }
        return true
    }

    public static func analyze(_ list: [EDKisi]) -> EDAnaliz {
        var warns: [String] = []
        var nodes: [EDDugum] = []
        var anc: [String: Int] = [:]
        func lbl(_ p: EDKisi) -> String { return "\(p.sira). \(titleCase(p.givn))" }
        for p in list {
            guard let toks = tokens(p.relationship) else {
                warns.append("\(lbl(p)): yakınlık anlaşılamadı (\"\(p.relationship)\") — ağaca bağlanmayacak.")
                continue
            }
            let path = toks.map { $0.t }.joined()
            nodes.append(EDDugum(kisi: p, toks: toks, path: path, sex: p.cinsiyet == "E" ? "M" : "F", given: p.givn))
            if hepsiFME(path) && !eSonrasiVar(path) {
                if anc[path] != nil {
                    warns.append("\(lbl(p)): \"\(p.relationship)\" yakınlığı iki kez geçiyor.")
                } else {
                    anc[path] = nodes.count - 1
                }
            }
        }
        let selfIdx = anc[""]
        if selfIdx == nil { warns.append("\"Kendisi\" satırı bulunamadı — kişiler birbirine bağlanamaz.") }
        func ghost(_ key: String, _ name: String, _ sex: String, _ child: Int) -> EDEbeveyn? {
            if name.isEmpty { return nil }
            return .hayali(anahtar: key + "#" + fold(name), ad: name, cins: sex, cocuk: child)
        }
        func spouseOf(_ par: Int, _ name: String, _ child: Int) -> EDEbeveyn? {
            if par == selfIdx, let e = anc["E"], name.isEmpty || fold(nodes[e].given) == fold(name) {
                return .dugum(e)
            }
            let sex = nodes[par].sex == "M" ? "F" : "M"
            return ghost("sp:\(nodes[par].kisi.sira)", name, sex, child)
        }
        for ni in 0..<nodes.count {
            let n = nodes[ni]
            let p = n.kisi
            if n.path.isEmpty || hepsiFM(n.path) || n.path == "E" {
                if let f = anc[n.path + "F"] {
                    nodes[ni].father = .dugum(f)
                } else {
                    nodes[ni].father = ghost(n.path + "F", p.babaAdi, "M", ni)
                }
                if let m = anc[n.path + "M"] {
                    nodes[ni].mother = .dugum(m)
                } else {
                    nodes[ni].mother = ghost(n.path + "M", p.anaAdi, "F", ni)
                }
                if n.path == "E" {
                    nodes[ni].father = ghost("EF", p.babaAdi, "M", ni)
                    nodes[ni].mother = ghost("EM", p.anaAdi, "F", ni)
                }
                continue
            }
            if n.path.hasSuffix("C") {
                let pp = String(n.path.dropLast())
                let need: String? = n.toks.count > 1 ? n.toks[n.toks.count - 2].sex : nil
                var cands: [Int] = []
                if pp.isEmpty {
                    if let s = selfIdx { cands = [s] }
                } else {
                    for (ci, c) in nodes.enumerated() where c.path == pp && (need == nil || need == "" || c.sex == need!) {
                        cands.append(ci)
                    }
                }
                var byName: [Int] = []
                for ci in cands {
                    let ad = nodes[ci].sex == "M" ? p.babaAdi : p.anaAdi
                    if fold(nodes[ci].given) == fold(ad) { byName.append(ci) }
                }
                var par: Int? = byName.first
                if par == nil && cands.count == 1 { par = cands[0] }
                guard let pi = par else {
                    let baba = titleCase(p.babaAdi)
                    let ana = titleCase(p.anaAdi)
                    let kim = pp == "C" ? "çocuğun" : "kişinin"
                    warns.append("\(lbl(p)): hangi \(kim) çocuğu olduğu bulunamadı (baba adı \(baba.isEmpty ? "—" : baba), ana adı \(ana.isEmpty ? "—" : ana)).")
                    continue
                }
                if nodes[pi].sex == "M" {
                    nodes[ni].father = .dugum(pi)
                    nodes[ni].mother = spouseOf(pi, p.anaAdi, ni)
                } else {
                    nodes[ni].mother = .dugum(pi)
                    nodes[ni].father = spouseOf(pi, p.babaAdi, ni)
                }
                continue
            }
            warns.append("\(lbl(p)): \"\(p.relationship)\" yakınlığı ağaca bağlanamıyor.")
        }
        // Belgedeki anne-babanin adi, kisinin baba/ana adi sutunuyla uyusuyor mu?
        for n in nodes {
            let ciftler: [(EDEbeveyn?, String, String, String)] = [
                (n.father, n.kisi.babaAdi, "baba", "babası"),
                (n.mother, n.kisi.anaAdi, "ana", "annesi")
            ]
            for (q, ad, l, l2) in ciftler {
                if case .dugum(let qi)? = q, !ad.isEmpty, fold(nodes[qi].given) != fold(ad) {
                    warns.append("\(lbl(n.kisi)): \(l) adı \"\(titleCase(ad))\" yazıyor, ama belgedeki \(l2) \"\(titleCase(nodes[qi].given))\".")
                }
            }
        }
        return EDAnaliz(nodes: nodes, warns: warns)
    }

    // MARK: buildGedcom

    static func birthPlace(_ p: EDKisi, _ nm: (String) -> String) -> String {
        let b = nm(p.birthPlace)
        if b.isEmpty { return "" }
        if !p.il.isEmpty && fold(p.ilce) == fold(p.birthPlace) { return "\(b), \(nm(p.il))" }
        return b
    }

    /// JS `+(s)` (yalniz 0-9 + - . e E icerenler); sayi degilse nil.
    static func jsSayi(_ s: String) -> Double? {
        let t = kirp(s)
        if t.isEmpty { return 0 }
        for u in t.unicodeScalars where !(Tarih.rakam(u) || u == "+" || u == "-" || u == "." || u == "e" || u == "E") { return nil }
        return Double(t)
    }

    struct GercekEbeveyn {
        var id: String
        var dugum: Int?
        var hayaliAnahtar: String?
    }

    struct HayaliKayit {
        var id: String
        var anahtar: String
        var givn: String
        var sex: String
        var dead: Bool
        var cocuk: Int
    }

    struct AileKaydi {
        var husb: GercekEbeveyn?
        var wife: GercekEbeveyn?
        var chil: [Int] = []
    }

    /// Cevrilmis kisiler -> GEDCOM 5.5.1 metni. `simdi`/`takvim`: web `new Date()` (baslik tarihi ve hayali kisinin
    /// "yasli" sayilmasi); uygulama `Calendar(identifier: .gregorian)` + yerel saat dilimi vermeli.
    public static func buildGedcom(_ analiz: EDAnaliz, opt: EDSecenek = EDSecenek(), simdi: Date,
                                   takvim: Calendar) -> String {
        let nodes = analiz.nodes
        if !nodes.contains(where: { $0.path.isEmpty }) { return "" }
        func nm(_ s: String) -> String { return opt.tc ? titleCase(s) : kirp(s) }
        let bugunYil = takvim.component(.year, from: simdi)
        var n = 0
        var nodeId: [String] = []
        for _ in nodes {
            n += 1
            nodeId.append("@I\(n)@")
        }
        var hayaliSira: [String] = []
        var hayali: [String: HayaliKayit] = [:]
        func gercek(_ g: EDEbeveyn?) -> GercekEbeveyn? {
            guard let g = g else { return nil }
            switch g {
            case .dugum(let i):
                return GercekEbeveyn(id: nodeId[i], dugum: i, hayaliAnahtar: nil)
            case .hayali(let anahtar, let ad, let cins, let cocuk):
                if !opt.ghost { return nil }
                if hayali[anahtar] == nil {
                    let c = nodes[cocuk].kisi
                    let yil = jsSayi(dz(Array(c.birthDate.unicodeScalars.suffix(4))))
                    var y = yil ?? 9999
                    if y == 0 { y = 9999 }
                    let eski = c.status == "ölüm" || y < Double(bugunYil - 90)
                    n += 1
                    hayali[anahtar] = HayaliKayit(id: "@I\(n)@", anahtar: anahtar, givn: ad, sex: cins, dead: eski, cocuk: cocuk)
                    hayaliSira.append(anahtar)
                }
                return GercekEbeveyn(id: hayali[anahtar]!.id, dugum: nil, hayaliAnahtar: anahtar)
            }
        }
        var aileAnahtarlari: [String] = []
        var aileler: [String: AileKaydi] = [:]
        var aileOf: [String: String] = [:]
        var babaDugum: [Int?] = []
        for (ci, c) in nodes.enumerated() {
            let f = gercek(c.father)
            let m = gercek(c.mother)
            babaDugum.append(f?.dugum)
            if f == nil && m == nil { continue }
            let key = (f?.id ?? "-") + (m?.id ?? "-")
            if aileler[key] == nil {
                aileler[key] = AileKaydi(husb: f, wife: m, chil: [])
                aileAnahtarlari.append(key)
            }
            aileler[key]!.chil.append(ci)
            aileOf[nodeId[ci]] = key
        }
        var aileKimlik: [String: String] = [:]
        for (i, k) in aileAnahtarlari.enumerated() { aileKimlik[k] = "@F\(i + 1)@" }
        func famsOf(_ id: String) -> [String] {
            var cikti: [String] = []
            for k in aileAnahtarlari {
                guard let f = aileler[k] else { continue }
                if f.husb?.id == id || f.wife?.id == id { cikti.append(aileKimlik[k] ?? "") }
            }
            return cikti
        }

        var ged = ""
        func line(_ s: String) { ged += s + "\n" }
        func note(_ txt: String) {
            let ls = bol(Array(txt.unicodeScalars), "\n").map { dz($0) }
            line("1 NOTE \(ls[0])")
            for l in ls.dropFirst() { line("2 CONT \(l)") }
        }

        for (ci, node) in nodes.enumerated() {
            let p = node.kisi
            let g = nm(p.givn)
            let s = nm(p.surn)
            line("0 \(nodeId[ci]) INDI")
            line("1 NAME \(g) /\(s)/")
            if !g.isEmpty { line("2 GIVN \(g)") }
            if !s.isEmpty { line("2 SURN \(s)") }
            // Kizlik soyadi: babasi belgedeyse ve soyadi farkliysa ikinci ad kaydi (dogum adi)
            if opt.maiden && p.cinsiyet == "K" {
                var ms = ""
                if let bi = babaDugum[ci], !nodes[bi].kisi.surn.isEmpty { ms = nm(nodes[bi].kisi.surn) }
                if !ms.isEmpty && fold(ms) != fold(s) {
                    line("1 NAME \(g) /\(ms)/")
                    line("2 TYPE birth")
                }
            }
            line("1 SEX \(p.cinsiyet == "E" ? "M" : "F")")
            let bd = gedDate(p.birthDate)
            let bp = birthPlace(p, nm)
            if !bd.isEmpty || !bp.isEmpty {
                line("1 BIRT")
                if !bd.isEmpty { line("2 DATE \(bd)") }
                if !bp.isEmpty { line("2 PLAC \(bp)") }
            }
            if p.status == "ölüm" {
                let dd = gedDate(p.deathDate)
                if !dd.isEmpty {
                    line("1 DEAT")
                    line("2 DATE \(dd)")
                } else {
                    line("1 DEAT Y")
                }
            }
            var parts = ["e-Devlet yakınlık: \(p.relationship)"]
            if opt.note {
                var kayit: [String] = []
                for x in [p.il, p.ilce, p.mahalle] where !x.isEmpty { kayit.append(nm(x)) }
                let k = kayit.joined(separator: " / ")
                if !k.isEmpty {
                    var satir = "Nüfusa kayıtlı: \(k)"
                    if !p.hane.isEmpty { satir += " (cilt \(p.cilt), hane \(p.hane), birey \(p.birey))" }
                    parts.append(satir)
                }
                if !p.medeniHal.isEmpty {
                    var t = titleCase(p.medeniHal)
                    if let r = t.range(of: "Bekar") { t.replaceSubrange(r, with: "Bekâr") }
                    parts.append("Medeni hâli: \(t)")
                }
            }
            note(parts.joined(separator: "\n"))
            line("1 _YAKINLIK \(p.relationship)")
            if let fk = aileOf[nodeId[ci]], let fid = aileKimlik[fk] { line("1 FAMC \(fid)") }
            for f in famsOf(nodeId[ci]) { line("1 FAMS \(f)") }
        }

        for anahtar in hayaliSira {
            guard let gh = hayali[anahtar] else { continue }
            let g = nm(gh.givn)
            line("0 \(gh.id) INDI")
            line("1 NAME \(g) //")
            line("2 GIVN \(g)")
            line("1 SEX \(gh.sex)")
            if gh.dead { line("1 DEAT Y") }
            let cp = nodes[gh.cocuk].kisi
            note("Yalnızca adı biliniyor: e-Devlet'te \(nm(cp.givn)) \(nm(cp.surn)) kişisinin \(gh.sex == "M" ? "baba" : "ana") adı.")
            for f in famsOf(gh.id) { line("1 FAMS \(f)") }
        }

        for k in aileAnahtarlari {
            guard let f = aileler[k] else { continue }
            line("0 \(aileKimlik[k] ?? "") FAM")
            if let h = f.husb { line("1 HUSB \(h.id)") }
            if let w = f.wife { line("1 WIFE \(w.id)") }
            for c in f.chil { line("1 CHIL \(nodeId[c])") }
        }

        let gun = takvim.component(.day, from: simdi)
        let ay = gedAylar[takvim.component(.month, from: simdi) - 1]
        let yil = takvim.component(.year, from: simdi)
        var bas = "0 HEAD\n1 SOUR EDEVLET-GED\n2 NAME e-Devlet Soyagaci -> GEDCOM\n2 VERS 2.0\n"
        bas += "1 DATE \(gun) \(ay) \(yil)\n1 GEDC\n2 VERS 5.5.1\n2 FORM LINEAGE-LINKED\n1 CHAR UTF-8\n"
        bas += "1 NOTE NVI Alt-Ust Soy Bilgisi. Gunu-ayi bilinmeyen eski dogumlar yalnizca yil olarak yazildi.\n"
        return bas + ged + "0 TRLR\n"
    }

    /// Gregorian + UTC takvim (varsayilan arguman; uygulama kendi yerel takvimini vermeli).
    public static func utcTakvim() -> Calendar {
        var t = Calendar(identifier: .gregorian)
        t.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        return t
    }

    // MARK: pdfItemsToGrid

    struct PdfOge {
        var p: PdfParca
        var page: Int
    }

    struct PdfSatir {
        var y: Double
        var its: [PdfParca]
        var s: String
    }

    struct PdfBant {
        var page: Int
        var items: [PdfParca]
    }

    /// JS kararli `sort`.
    static func kararli<T>(_ a: [T], _ once: (T, T) -> Bool) -> [T] {
        let sirali = a.enumerated().sorted { (l, r) -> Bool in
            if once(l.element, r.element) { return true }
            if once(r.element, l.element) { return false }
            return l.offset < r.offset
        }
        return sirali.map { $0.element }
    }

    static func ascii(_ s: String) -> [Unicode.Scalar] { return Array(s.lowercased().unicodeScalars) }

    /// `/turkiye\.gov\.tr|^Sayfa\s*\d|^\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2}/i`
    static func pdfCop(_ str: String) -> Bool {
        let t = kirp(str)
        let low = t.lowercased()
        if low.contains("turkiye.gov.tr") { return true }
        let a = ascii(t)
        if a.starts(with: ascii("sayfa")) {
            var i = 5
            while i < a.count && Tarih.bosluk(a[i]) { i += 1 }
            if i < a.count && Tarih.rakam(a[i]) { return true }
        }
        // GG.AA.YYYY SS:DD
        func r(_ i: Int) -> Bool { return i < a.count && Tarih.rakam(a[i]) }
        func nokta(_ i: Int) -> Bool { return i < a.count && a[i] == "." }
        if r(0) && r(1) && nokta(2) && r(3) && r(4) && nokta(5) && r(6) && r(7) && r(8) && r(9) {
            var i = 10
            let bas = i
            while i < a.count && Tarih.bosluk(a[i]) { i += 1 }
            if i > bas && r(i) && r(i + 1) && i + 2 < a.count && a[i + 2] == ":" && r(i + 3) && r(i + 4) { return true }
        }
        return false
    }

    /// `/Sayfa\s*\d+\s*\/\s*\d+/i` herhangi bir yerde
    static func sayfaNumarasiVar(_ t: String) -> Bool {
        let a = ascii(t)
        let kalip = ascii("sayfa")
        if a.count < kalip.count { return false }
        for bas in 0...(a.count - kalip.count) where Array(a[bas..<(bas + kalip.count)]) == kalip {
            var i = bas + kalip.count
            while i < a.count && Tarih.bosluk(a[i]) { i += 1 }
            let r1 = i
            while i < a.count && Tarih.rakam(a[i]) { i += 1 }
            if i == r1 { continue }
            while i < a.count && Tarih.bosluk(a[i]) { i += 1 }
            if i >= a.count || a[i] != "/" { continue }
            i += 1
            while i < a.count && Tarih.bosluk(a[i]) { i += 1 }
            if i < a.count && Tarih.rakam(a[i]) { return true }
        }
        return false
    }

    static func joinLine(_ itsIn: [PdfParca]) -> String {
        let its = kararli(itsIn) { $0.x < $1.x }
        var s = ""
        var end: Double? = nil
        for i in its {
            if let e = end, i.x - e > i.h * 0.18 { s += " " }
            s += i.str
            end = i.x + i.w
        }
        return bosluklariTek(s)
    }

    static func toLines(_ its: [PdfParca]) -> [PdfSatir] {
        var ls: [(y: Double, its: [PdfParca])] = []
        let sirali = kararli(its) { (a, b) -> Bool in
            if a.y != b.y { return a.y > b.y }
            return a.x < b.x
        }
        for i in sirali {
            if let k = ls.firstIndex(where: { abs($0.y - i.y) < i.h * 0.35 }) {
                ls[k].its.append(i)
            } else {
                ls.append((y: i.y, its: [i]))
            }
        }
        return ls.map { PdfSatir(y: $0.y, its: $0.its, s: joinLine($0.its)) }
    }

    static func sayfaBantlari(_ items: [PdfParca], _ page: Int) -> [PdfBant] {
        let its = items.filter { !kirp($0.str).isEmpty && !pdfCop($0.str) }
        if its.isEmpty { return [] }
        let hler = its.map { $0.h }.sorted()
        var fs = hler[its.count >> 1]
        if fs == 0 || fs.isNaN { fs = 8 }
        var ys: [Double] = []
        for i in its {
            let v = ((i.y * 2) + 0.5).rounded(.down) / 2
            if !ys.contains(v) { ys.append(v) }
        }
        ys.sort { $0 > $1 }
        var cuts: [Double] = []
        if ys.count > 1 {
            for k in 1..<ys.count where ys[k - 1] - ys[k] > fs * 1.75 { cuts.append((ys[k - 1] + ys[k]) / 2) }
        }
        var bands = Array(repeating: PdfBant(page: page, items: []), count: cuts.count + 1)
        for i in its {
            var b = 0
            while b < cuts.count && i.y < cuts[b] { b += 1 }
            bands[b].items.append(i)
        }
        func altBilgi(_ b: PdfBant) -> Bool {
            var t = ""
            for i in b.items { t += i.str }
            if sayfaNumarasiVar(t) { return true }
            var harf = ""
            for u in t.unicodeScalars where Tarih.harf(u) || u == "." { harf.unicodeScalars.append(u) }
            let l = harf.lowercased()
            let govtr = l.contains("govtr") || l.contains("gov.tr")
            if !govtr { return false }
            for i in b.items {
                let k = kirp(i.str)
                if tamRakam(k) && i.x < 80 { return false }
            }
            return true
        }
        return bands.filter { !$0.items.isEmpty && !altBilgi($0) }
    }

    static func siraBasligi(_ str: String) -> Bool {
        let l = Array(kirp(str).lowercased().unicodeScalars)
        return l == Array("sira".unicodeScalars) || l == Array("sıra".unicodeScalars)
    }

    static func aciklamaBasligi(_ str: String) -> Bool {
        let l = Array(kirp(str).lowercased().unicodeScalars)
        return l.starts(with: Array("aciklamalar".unicodeScalars)) || l.starts(with: Array("açiklamalar".unicodeScalars))
    }

    /// pdf.js parcalari (sayfa sayfa) -> izgara; e-Devlet basligi/12 sutun bulunamazsa `nil` (web `null`).
    public static func pdfItemsToGrid(_ pages: [[PdfParca]]) -> [[String]]? {
        var all: [PdfBant] = []
        for (p, items) in pages.enumerated() { all.append(contentsOf: sayfaBantlari(items, p)) }
        guard let hbi = all.firstIndex(where: { b in
            b.items.contains(where: { $0.str.lowercased().contains("durumu") }) && b.items.contains(where: { siraBasligi($0.str) })
        }) else { return nil }
        let hb = all[hbi]
        // Ayni yukseklikteki basliklar genis bosluklardan ayri parcalara bolunur
        var segs: [(x0: Double, x1: Double)] = []
        for l in toLines(hb.items) {
            var cur: Int? = nil
            for i in kararli(l.its, { $0.x < $1.x }) {
                if let c = cur, i.x - segs[c].x1 < i.h * 0.3 {
                    segs[c].x1 = max(segs[c].x1, i.x + i.w)
                } else {
                    segs.append((x0: i.x, x1: i.x + i.w))
                    cur = segs.count - 1
                }
            }
        }
        let centers = segs.map { ($0.x0 + $0.x1) / 2 }.sorted()
        var cols: [(v: [Double], max: Double)] = []
        for c in centers {
            if let g = cols.last, c - g.max < 8 {
                cols[cols.count - 1].v.append(c)
                cols[cols.count - 1].max = c
            } else {
                cols.append((v: [c], max: c))
            }
        }
        if cols.count != 12 { return nil }
        let cx: [Double] = cols.map { g in
            var t = 0.0
            for x in g.v { t += x }
            return t / Double(g.v.count)
        }
        func colOf(_ i: PdfParca) -> Int {
            let m = i.x + i.w / 2
            var best = 0
            for (k, c) in cx.enumerated() where abs(m - c) < abs(m - cx[best]) { best = k }
            return best
        }
        // Bantlari kayitlara cevir (sayfa arasinda bolunmus satirlar icin bkz. web yorumu)
        var recs: [[PdfOge]] = []
        var pending: [PdfOge] = []
        var started = false
        var k = hbi + 1
        while k < all.count {
            let b = all[k]
            if b.items.contains(where: { aciklamaBasligi($0.str) }) { break }
            let ogeler = b.items.map { PdfOge(p: $0, page: b.page) }
            let num = b.items.contains(where: { colOf($0) == 0 && tamRakam(kirp($0.str)) })
            if num {
                recs.append(pending + ogeler)
                pending = []
                started = true
                k += 1
                continue
            }
            if !started { k += 1; continue }
            let sonrakiVar = k + 1 < all.count
            let sayfaSonu = !sonrakiVar || all[k + 1].page != b.page
            if sayfaSonu {
                pending.append(contentsOf: ogeler)
            } else if !recs.isEmpty {
                recs[recs.count - 1].append(contentsOf: ogeler)
            }
            k += 1
        }
        var grid: [[String]] = []
        for its in recs {
            var row: [[PdfOge]] = Array(repeating: [], count: 12)
            for i in its { row[colOf(i.p)].append(i) }
            var satir: [String] = []
            for cell in row {
                var sayfalar: [Int] = []
                var byPage: [Int: [PdfParca]] = [:]
                for i in cell {
                    if byPage[i.page] == nil { sayfalar.append(i.page) }
                    byPage[i.page, default: []].append(i.p)
                }
                sayfalar.sort()
                var metin: [String] = []
                for pg in sayfalar { for l in toLines(byPage[pg] ?? []) { metin.append(l.s) } }
                satir.append(metin.joined(separator: "\n"))
            }
            grid.append(satir)
        }
        return grid
    }
}
