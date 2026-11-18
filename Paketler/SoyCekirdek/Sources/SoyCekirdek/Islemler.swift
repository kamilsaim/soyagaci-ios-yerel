import Foundation

/// Web `soy-agaci-7.0.0.html` kişi işlemlerinin birebir portu.
public enum Islem {
    // MARK: yardımcılar (iç)

    static func kirpMetin(_ s: String) -> String {
        var t = String.UnicodeScalarView()
        t.append(contentsOf: Tarih.kirp(s))
        return String(t)
    }

    static func kisiVarMi(_ a: Agac, _ id: String) -> Bool {
        return a.kisi(id) != nil
    }

    /// `people[id]` nesnesini değiştirir (kayıt yoksa hiçbir şey yapmaz).
    static func degistir(_ a: inout Agac, _ id: String, _ f: (inout Nesne) -> Void) {
        guard case .object(var o)? = a.people[id] else { return }
        f(&o)
        a.people[id] = .object(o)
    }

    /// `(x.children||[]).filter(c => c !== id)`
    static func diziden(_ j: JSON?, cikar id: String) -> [JSON] {
        guard let d = j?.dizi else { return [] }
        return d.filter { $0 != .string(id) }
    }

    /// `(x.spouses||[]).filter(s => s.id !== id)`
    static func esleriSuz(_ j: JSON?, cikar id: String) -> [JSON] {
        guard let d = j?.dizi else { return [] }
        return d.filter { $0["id"] != .string(id) }
    }

    /// `(spouses[0]||{}).id||null`
    static func birincilEs(_ d: [JSON]) -> JSON {
        if let ilk = d.first, let k = ilk["id"], k.dogru { return k }
        return .null
    }

    // MARK: migrateData (web satır 1193)

    public static func migrateData(_ a: inout Agac) {
        for (anahtar, deger) in a.people.ciftler {
            guard case .object(var p) = deger else { continue }
            if p["gallery"]?.dizi == nil { p["gallery"] = .array([]) }
            if !(p["maidenName"]?.dogru ?? false) { p["maidenName"] = .string("") }
            if !(p["maritalStatus"]?.dogru ?? false) { p["maritalStatus"] = .string("married") }
            if p["deceased"]?.mantik == nil { p["deceased"] = .bool(false) }
            if p["spouses"]?.dizi == nil {
                if let es = p["spouse"], es.dogru {
                    let durum = p["maritalStatus"] ?? .null
                    p["spouses"] = .array([.object(Nesne([("id", es), ("status", durum)]))])
                } else {
                    p["spouses"] = .array([])
                }
            }
            var suzulmus: [JSON] = []
            for s in p["spouses"]?.dizi ?? [] {
                guard case .object(let o) = s, let k = o["id"], k.dogru else { continue }
                suzulmus.append(s)
            }
            p["spouses"] = .array(suzulmus)
            if p["children"]?.dizi == nil { p["children"] = .array([]) }
            if p["gender"] == .string("U") { p["gender"] = .string("M") }
            a.people[anahtar] = .object(p)
        }
    }

    // MARK: newId (web satır 1082)

    public static func newId(_ a: inout Agac) -> String {
        var id = ""
        repeat {
            id = "P" + String(a.nextId)
            a.nextId += 1
        } while kisiVarMi(a, id)
        return id
    }

    // MARK: isAncestorOf (web satır 1128)

    public static func isAncestorOf(_ anc: String, _ desc: String, _ a: Agac) -> Bool {
        var seen = Set<String>()
        return atasiMi(anc, desc, a, &seen)
    }

    private static func atasiMi(_ anc: String, _ desc: String, _ a: Agac, _ seen: inout Set<String>) -> Bool {
        if desc.isEmpty || seen.contains(desc) { return false }
        seen.insert(desc)
        guard let p = a.kisi(desc) else { return false }
        let anne = p.ham["mother"]?.metin
        let baba = p.ham["father"]?.metin
        if anne == anc || baba == anc { return true }
        if let m = anne, atasiMi(anc, m, a, &seen) { return true }
        if let b = baba, atasiMi(anc, b, a, &seen) { return true }
        return false
    }

    // MARK: isDead / pname / initials

    /// Web `isDead` (satır 3013); `new Date().getFullYear()` yerine `simdi`/`takvim`.
    public static func isDead(_ p: Kisi, simdi: Date, takvim: Calendar) -> Bool {
        let h = p.ham
        if (h["deathDate"]?.dogru ?? false) || (h["deathPlace"]?.dogru ?? false) || (h["deceased"]?.dogru ?? false) {
            return true
        }
        let by = Tarih.yearOf(p.birthDate)
        guard !by.isEmpty, let yil = Int(by) else { return false }
        return takvim.component(.year, from: simdi) - yil > 110
    }

    /// Web `pname` (satır 1087).
    public static func pname(_ p: Kisi) -> String {
        var parcalar: [String] = []
        for k in ["firstName", "lastName"] {
            if let j = p.ham[k], j.dogru { parcalar.append(j.jsMetin) }
        }
        let s = parcalar.joined(separator: " ")
        return s.isEmpty ? "İsimsiz" : s
    }

    /// Web `initials` (satır 2413). Not: JS UTF-16 kod birimi alır; BMP dışı ilk harfte (yarım vekil) fark olur.
    public static func initials(_ p: Kisi) -> String {
        func ilk(_ j: JSON?, _ varsayilan: String) -> Unicode.Scalar? {
            var ham = varsayilan
            if let d = j, d.dogru { ham = d.jsMetin }
            return Tarih.kirp(ham).first
        }
        var cikti = ""
        cikti += Metin.trBuyuk(ilk(p.ham["firstName"], "?") ?? "?")
        if let s = ilk(p.ham["lastName"], "") { cikti += Metin.trBuyuk(s) }
        return cikti
    }

    // MARK: fotoğraf başvuruları

    static func fotoListesi(_ o: Nesne) -> [String] {
        var cikti: [String] = []
        if let f = o["photo"], f.dogru { cikti.append(f.jsMetin) }
        for g in o["gallery"]?.dizi ?? [] where g.dogru { cikti.append(g.jsMetin) }
        return cikti
    }

    /// Web `photoRefsOf` (satır 1080): `[photo, ...gallery].filter(Boolean)`.
    public static func photoRefsOf(_ q: Kisi) -> [String] {
        return fotoListesi(q.ham)
    }

    /// Web `allPhotoRefs` (satır 979), tekil ve ilk görülme sırasıyla.
    public static func allPhotoRefsSirali(_ a: Agac) -> [String] {
        var gorulen = Set<String>()
        var cikti: [String] = []
        for (_, v) in a.people.ciftler {
            guard case .object(let o) = v else { continue }
            for r in fotoListesi(o) where !gorulen.contains(r) {
                gorulen.insert(r)
                cikti.append(r)
            }
        }
        return cikti
    }

    public static func allPhotoRefs(_ a: Agac) -> Set<String> {
        return Set(allPhotoRefsSirali(a))
    }

    // MARK: bağ temizliği (delP ve savePerson ortak)

    /// Kişinin eski ebeveyn/eş/çocuk bağlarını karşı taraflardan çıkarır (kişinin kendisi kalır).
    static func baglariKopar(_ id: String, _ p: Kisi, _ a: inout Agac) {
        for ebeveyn in [p.ham["mother"], p.ham["father"]] {
            guard let k = ebeveyn?.metin else { continue }
            degistir(&a, k) { $0["children"] = .array(diziden($0["children"], cikar: id)) }
        }
        for s in p.ham["spouses"]?.dizi ?? [] {
            guard let k = s["id"]?.metin else { continue }
            degistir(&a, k) { sp in
                let yeni = esleriSuz(sp["spouses"], cikar: id)
                sp["spouses"] = .array(yeni)
                sp["spouse"] = birincilEs(yeni)
            }
        }
        for c in p.ham["children"]?.dizi ?? [] {
            guard let k = c.metin else { continue }
            degistir(&a, k) { co in
                if co["mother"] == .string(id) { co["mother"] = .null }
                if co["father"] == .string(id) { co["father"] = .null }
            }
        }
    }

    // MARK: delP (web satır 1863)

    public static func delP(_ id: String, _ a: inout Agac) {
        guard let p = a.kisi(id) else { return }
        baglariKopar(id, p, &a)
        a.people[id] = nil
    }

    // MARK: savePerson (web satır 1782)

    public static func savePerson(_ f: KisiFormu, _ a: inout Agac) -> KaydetSonuc {
        let fn = Metin.capStr(kirpMetin(f.firstName))
        let ln = Metin.capStr(kirpMetin(f.lastName))
        if fn.isEmpty && ln.isEmpty { return .hata("⚠️ Ad veya soyad girin") }
        var id = ""
        if let e = f.id, !e.isEmpty { id = e } else { id = newId(&a) }
        let mo: String? = (f.mother ?? "").isEmpty ? nil : f.mother
        let fa: String? = (f.father ?? "").isEmpty ? nil : f.father
        let g = f.gender

        var yeniCocuklar: [String] = []
        for c in f.children where kisiVarMi(a, c) && c != id && !yeniCocuklar.contains(c) {
            yeniCocuklar.append(c)
        }
        var yeniEsler: [EsBag] = []
        for s in f.spouses where kisiVarMi(a, s.id) && s.id != id && !yeniEsler.contains(where: { $0.id == s.id }) {
            yeniEsler.append(EsBag(id: s.id, status: s.status.isEmpty ? "married" : s.status))
        }

        // Döngü koruması
        if mo == id || fa == id { return .hata("⚠️ Kişi kendi ebeveyni olamaz") }
        if let m = mo, isAncestorOf(id, m, a) {
            return .hata("⚠️ Anne olarak seçilen kişi bu kişinin soyundan geliyor")
        }
        if let b = fa, isAncestorOf(id, b, a) {
            return .hata("⚠️ Baba olarak seçilen kişi bu kişinin soyundan geliyor")
        }
        for cid in yeniCocuklar where isAncestorOf(cid, id, a) {
            let ad = a.kisi(cid).map { pname($0) } ?? ""
            return .hata("⚠️ " + ad + " bu kişinin atası — çocuk olarak eklenemez")
        }

        let eski = a.kisi(id)
        let eskiFotolar = eski.map { photoRefsOf($0) } ?? []
        if let o = eski { baglariKopar(id, o, &a) }

        let birincil = yeniEsler.first
        var galeri: [String] = []
        for x in f.gallery where !galeri.contains(x) { galeri.append(x) }
        var esJSON: [JSON] = []
        for e in yeniEsler {
            esJSON.append(.object(Nesne([("id", .string(e.id)), ("status", .string(e.status))])))
        }
        var yeni = Nesne()
        yeni["id"] = .string(id)
        yeni["firstName"] = .string(fn)
        yeni["lastName"] = .string(ln)
        yeni["gender"] = .string(g)
        yeni["birthDate"] = .string(Tarih.normDate(kirpMetin(f.birthDate)))
        yeni["birthPlace"] = .string(Metin.capStr(kirpMetin(f.birthPlace)))
        yeni["deathDate"] = .string(Tarih.normDate(kirpMetin(f.deathDate)))
        yeni["deathPlace"] = .string(Metin.capStr(kirpMetin(f.deathPlace)))
        yeni["deceased"] = .bool(f.deceased)
        yeni["occupation"] = .string(Metin.capStr(kirpMetin(f.occupation)))
        yeni["maidenName"] = .string(g == "F" ? Metin.capStr(kirpMetin(f.maidenName)) : "")
        yeni["notes"] = .string(kirpMetin(f.notes))
        yeni["maritalStatus"] = .string(birincil?.status ?? "married")
        yeni["photo"] = f.photo.map { JSON.string($0) } ?? .null
        yeni["gallery"] = .array(galeri.map { JSON.string($0) })
        yeni["mother"] = mo.map { JSON.string($0) } ?? .null
        yeni["father"] = fa.map { JSON.string($0) } ?? .null
        yeni["spouse"] = birincil.map { JSON.string($0.id) } ?? .null
        yeni["spouses"] = .array(esJSON)
        yeni["children"] = .array(yeniCocuklar.map { JSON.string($0) })
        // Web kaydı baştan kurar; burada bilinmeyen alanlar (başka sürümlerden) korunur.
        if let o = eski {
            for (k, v) in o.ham.ciftler where yeni[k] == nil { yeni[k] = v }
        }
        a.people[id] = .object(yeni)

        for ebeveyn in [mo, fa] {
            guard let k = ebeveyn else { continue }
            degistir(&a, k) { o in
                var d = o["children"]?.dizi ?? []
                if !d.contains(.string(id)) { d.append(.string(id)) }
                o["children"] = .array(d)
            }
        }
        for e in yeniEsler {
            degistir(&a, e.id) { sp in
                var d = esleriSuz(sp["spouses"], cikar: id)
                d.append(.object(Nesne([("id", .string(id)), ("status", .string(e.status))])))
                sp["spouses"] = .array(d)
                sp["spouse"] = d[0]["id"]
                sp["maritalStatus"] = d[0]["status"]
            }
        }
        for cid in yeniCocuklar {
            guard let c = a.kisi(cid) else { continue }
            let onceki = g == "F" ? c.ham["mother"] : c.ham["father"]
            if let p = onceki?.metin, !p.isEmpty, p != id, kisiVarMi(a, p) {
                degistir(&a, p) { $0["children"] = .array(diziden($0["children"], cikar: cid)) }
            }
            degistir(&a, cid) { co in
                if g == "F" { co["mother"] = .string(id) } else { co["father"] = .string(id) }
            }
        }
        return .tamam(id: id, eskiFotolar: eskiFotolar)
    }
}
