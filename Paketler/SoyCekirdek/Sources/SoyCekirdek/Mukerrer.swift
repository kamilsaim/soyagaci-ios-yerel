import Foundation

/// Mükerrer kişi işlemleri (web `mergePeople`, satır 3242). `findDupes` Task 7'de eklenir.
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
}
