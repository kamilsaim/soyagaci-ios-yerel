import Foundation

/// Olası mükerrer çift (web `findDupes` dönüşündeki `{a,b,key,score}`; kişiler yerine kimlikler).
public struct MukerrerCift: Equatable {
    public var a: String
    public var b: String
    /// `[a.id,b.id].sort().join('|')` (JS UTF-16 sırası); "Farklı kişiler" kümesinin anahtarı.
    public var key: String
    public var puan: Int

    public init(a: String, b: String, key: String, puan: Int) {
        self.a = a
        self.b = b
        self.key = key
        self.puan = puan
    }
}

/// Mükerrer kişi işlemleri (web `findDupes` l.3184, `dupSummary` l.3213, `mergePeople` l.3242).
/// `renderDupes`/`notDup`/`askMerge` arayüzdür; `notDup` anahtarını saklamak (`sa4_notdup_<uid|local>`) uygulamaya aittir.
public enum Mukerrer {
    static func tekil(_ d: [JSON]) -> [JSON] {
        var cikti: [JSON] = []
        for x in d where !cikti.contains(x) { cikti.append(x) }
        return cikti
    }

    /// `drop` kaydını `keep` kaydına katar: boş alanlar doldurulur, eş/çocuk/galeri birleşir,
    /// herkesin bağlantısı `keep`'e çevrilir, `drop` silinir. (Web'deki `nodeDrag`/`imgCache` temizliği yok.)
    public static func mergePeople(keep: String, drop: String, _ a: inout Agac) {
        guard case .object(var k)? = a.people[keep], case .object(let d)? = a.people[drop] else { return }
        let kimlikKeep = JSON.string(keep)
        let kimlikDrop = JSON.string(drop)

        for f in ["firstName", "lastName", "maidenName", "birthDate", "birthPlace", "deathDate", "deathPlace", "occupation", "photo"] {
            let kd = k[f]?.dogru ?? false
            if !kd, let dv = d[f], dv.dogru { k[f] = dv }
        }
        if d["deceased"]?.dogru ?? false { k["deceased"] = .bool(true) }
        if let dn = d["notes"], dn.dogru, dn != k["notes"] {
            if let kn = k["notes"], kn.dogru {
                k["notes"] = .string(kn.jsMetin + "\n" + dn.jsMetin)
            } else {
                k["notes"] = dn
            }
        }
        var galeri: [JSON] = []
        if let g = k["gallery"], g.dogru { galeri += g.dizi ?? [] }
        if let g = d["gallery"], g.dogru { galeri += g.dizi ?? [] }
        k["gallery"] = .array(tekil(galeri))
        if !(k["father"]?.dogru ?? false), let v = d["father"], v.dogru { k["father"] = v }
        if !(k["mother"]?.dogru ?? false), let v = d["mother"], v.dogru { k["mother"] = v }

        var kEsler: [JSON] = k["spouses"]?.dizi ?? []
        if let dEsler = d["spouses"], dEsler.dogru {
            for s in dEsler.dizi ?? [] {
                var varMi = false
                for x in kEsler where x["id"] == s["id"] { varMi = true }
                if !varMi { kEsler.append(s) }
            }
        }
        k["spouses"] = .array(kEsler)

        var cocuklar: [JSON] = []
        if let c = k["children"], c.dogru { cocuklar += c.dizi ?? [] }
        if let c = d["children"], c.dogru { cocuklar += c.dizi ?? [] }
        k["children"] = .array(tekil(cocuklar))
        a.people[keep] = .object(k)

        // Diğer herkesin bağlantılarını yeni kayda çevir
        for anahtar in a.people.anahtarlar {
            guard case .object(var p)? = a.people[anahtar] else { continue }
            if p["id"] == kimlikDrop { continue }
            if p["father"] == kimlikDrop { p["father"] = kimlikKeep }
            if p["mother"] == kimlikDrop { p["mother"] = kimlikKeep }
            if p["spouse"] == kimlikDrop { p["spouse"] = kimlikKeep }
            if let es = p["spouses"], es.dogru {
                var liste: [JSON] = es.dizi ?? []
                for i in 0..<liste.count where liste[i]["id"] == kimlikDrop {
                    if case .object(var o) = liste[i] {
                        o["id"] = kimlikKeep
                        liste[i] = .object(o)
                    }
                }
                var suzulmus: [JSON] = []
                for s in liste {
                    var ilk = true
                    for t in suzulmus where t["id"] == s["id"] { ilk = false }
                    if ilk { suzulmus.append(s) }
                }
                p["spouses"] = .array(suzulmus)
            }
            if let c = p["children"], c.dogru {
                let yeni = (c.dizi ?? []).map { $0 == kimlikDrop ? kimlikKeep : $0 }
                p["children"] = .array(tekil(yeni))
            }
            a.people[anahtar] = .object(p)
        }

        if case .object(var son)? = a.people[keep] {
            let es = (son["spouses"]?.dizi ?? []).filter { $0["id"] != kimlikKeep }
            son["spouses"] = .array(es)
            son["children"] = .array((son["children"]?.dizi ?? []).filter { $0 != kimlikKeep })
            if son["father"] == kimlikKeep { son["father"] = .null }
            if son["mother"] == kimlikKeep { son["mother"] = .null }
            if let ilk = es.first {
                son["spouse"] = ilk["id"] ?? .null
            } else {
                son["spouse"] = .null
            }
            a.people[keep] = .object(son)
        }
        a.people[drop] = nil
    }

    // MARK: findDupes

    static func jsSirali(_ x: String, _ y: String) -> Bool {
        return Array(x.utf16).lexicographicallyPrecedes(Array(y.utf16))
    }

    static func yilSayi(_ p: Kisi) -> Int? {
        let y = Tarih.yearOf(p.birthDate)
        return y.isEmpty ? nil : Int(y)
    }

    static func ebeveynAdi(_ p: Kisi, _ rol: String, _ a: Agac) -> String {
        guard let id = rol == "father" ? p.father : p.mother, let q = a.kisi(id) else { return "" }
        return GedBirlestir.katla(q.firstName)
    }

    /// Mükerrer olabilecek çiftler, puana göre azalan (eşitlikte web'deki sıra). `notDup`: "A|B" anahtarları.
    public static func findDupes(_ a: Agac, notDup: Set<String>) -> [MukerrerCift] {
        var sira: [String] = []
        var gruplar: [String: [Kisi]] = [:]
        for anahtar in a.people.anahtarlar {
            guard let p = a.kisi(anahtar) else { continue }
            let ad = GedBirlestir.katla(p.firstName)
            if ad.isEmpty { continue }
            var cins = "undefined"
            if let g = p.ham["gender"] { cins = g == .null ? "null" : g.jsMetin }
            let k = ad + "|" + cins
            if gruplar[k] == nil {
                gruplar[k] = []
                sira.append(k)
            }
            gruplar[k]?.append(p)
        }
        var cikti: [MukerrerCift] = []
        for k in sira {
            let g = gruplar[k] ?? []
            for i in 0..<g.count {
                for j in (i + 1)..<max(g.count, i + 1) {
                    if let c = cift(g[i], g[j], a, notDup) { cikti.append(c) }
                }
            }
        }
        // kararlı azalan sıralama
        var sirali: [(Int, MukerrerCift)] = []
        for (i, c) in cikti.enumerated() { sirali.append((i, c)) }
        sirali.sort { x, y in
            if x.1.puan != y.1.puan { return x.1.puan > y.1.puan }
            return x.0 < y.0
        }
        return sirali.map { $0.1 }
    }

    static func cift(_ x: Kisi, _ y: Kisi, _ ag: Agac, _ notDup: Set<String>) -> MukerrerCift? {
        let kimlikler = [x.id, y.id].sorted(by: jsSirali)
        let key = kimlikler[0] + "|" + kimlikler[1]
        if notDup.contains(key) { return nil }
        let xEs = x.ham["spouses"]?.dizi ?? []
        var esMi = false
        for s in xEs where s["id"] == JSON.string(y.id) { esMi = true }
        if esMi { return nil }
        if x.ham["father"] == JSON.string(y.id) || x.ham["mother"] == JSON.string(y.id) { return nil }
        if y.ham["father"] == JSON.string(x.id) || y.ham["mother"] == JSON.string(x.id) { return nil }
        let sx = GedBirlestir.sur(x)
        let sy = GedBirlestir.sur(y)
        if !sx.isEmpty && !sy.isEmpty {
            var ortak = false
            for t in sx where GedBirlestir.icerir(sy, t) { ortak = true }
            if !ortak { return nil }
        }
        let yx = yilSayi(x)
        let yy = yilSayi(y)
        let yilVar = yx != nil && yy != nil
        if let u = yx, let v = yy, abs(u - v) > 1 { return nil }
        let roller = ["father", "mother"]
        for r in roller {
            let pa = ebeveynAdi(x, r, ag)
            let pb = ebeveynAdi(y, r, ag)
            if !pa.isEmpty && !pb.isEmpty && !pa.unicodeScalars.elementsEqual(pb.unicodeScalars) { return nil }
        }
        for r in roller {
            let ia = r == "father" ? x.father : x.mother
            let ib = r == "father" ? y.father : y.mother
            guard let ida = ia, let idb = ib, let ka = ag.kisi(ida), let kb = ag.kisi(idb), ida != idb else { continue }
            let ya = yilSayi(ka)
            let yb = yilSayi(kb)
            if let u = ya, let v = yb, abs(u - v) <= 1 { continue }
            return nil
        }
        if x.ham["father"]?.dogru ?? false, x.ham["father"] == y.ham["father"], x.ham["mother"] == y.ham["mother"] {
            let ayniYil = yilVar && Tarih.yearOf(x.birthDate) == Tarih.yearOf(y.birthDate)
            if !ayniYil { return nil }
        }
        var puan = 0
        if yilVar { puan += 3 }
        if !sx.isEmpty && !sy.isEmpty { puan += 2 }
        for r in roller {
            let pa = ebeveynAdi(x, r, ag)
            if !pa.isEmpty && pa.unicodeScalars.elementsEqual(ebeveynAdi(y, r, ag).unicodeScalars) {
                puan += 2
                break
            }
        }
        if !x.birthPlace.isEmpty && !y.birthPlace.isEmpty
            && GedBirlestir.katla(x.birthPlace).unicodeScalars.elementsEqual(GedBirlestir.katla(y.birthPlace).unicodeScalars) {
            puan += 1
        }
        if puan < 4 { return nil }
        return MukerrerCift(a: x.id, b: y.id, key: key, puan: puan)
    }

    // MARK: dupSummary

    /// Çift satırındaki kişi özeti (web `dupSummary`, aynı HTML). `simdi`/`takvim`: `isDead` için.
    public static func dupSummary(_ p: Kisi, _ a: Agac, simdi: Date, takvim: Calendar) -> String {
        var ebeveyn: [String] = []
        for id in [p.father, p.mother] {
            if let i = id, let q = a.kisi(i) { ebeveyn.append(q.firstName) }
        }
        let par = ebeveyn.joined(separator: " & ")
        var parcalar: [String] = []
        if !p.birthDate.isEmpty { parcalar.append("d. " + p.birthDate) }
        if !p.birthPlace.isEmpty { parcalar.append(p.birthPlace) }
        if Islem.isDead(p, simdi: simdi, takvim: takvim) {
            parcalar.append(p.deathDate.isEmpty ? "vefat" : "ö. " + p.deathDate)
        }
        if !par.isEmpty { parcalar.append("ebeveyn: " + par) }
        let esler = p.ham["spouses"]?.dizi ?? []
        if !esler.isEmpty {
            var adlar: [String] = []
            for s in esler {
                if let i = s["id"], i.dogru, let q = a.kisi(i.jsMetin), !q.firstName.isEmpty { adlar.append(q.firstName) }
            }
            parcalar.append("eş: " + adlar.joined(separator: ", "))
        }
        let cocuk = p.ham["children"]?.dizi ?? []
        if !cocuk.isEmpty { parcalar.append(String(cocuk.count) + " çocuk") }
        let ozet = parcalar.isEmpty ? "bilgi yok" : parcalar.joined(separator: " · ")
        var s = "<div class=\"dup-p\" onclick=\"openDetail('" + p.id + "')\"><b>" + GedBirlestir.esc(Islem.pname(p)) + "</b>"
        if !p.maidenName.isEmpty { s += " <i>d. " + GedBirlestir.esc(p.maidenName) + "</i>" }
        s += "<div>" + GedBirlestir.esc(ozet) + "</div></div>"
        return s
    }
}
