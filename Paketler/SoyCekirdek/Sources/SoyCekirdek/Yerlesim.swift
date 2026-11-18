import Foundation

/// Düğümün sol-üst köşesi (web `{x,y}`).
public struct Nokta: Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Web `nodePos` / `nodeRow` (kişi -> konum / kuşak satırı).
public struct Yerlesim: Equatable {
    public var nodePos: [String: Nokta] = [:]
    public var nodeRow: [String: Int] = [:]
    /// nodePos anahtarlarının ilk eklenme sırası (JS `Object.keys(nodePos)`)
    var sira: [String] = []

    public init() {}

    mutating func yerles(_ id: String, _ x: Double, _ y: Double, _ satir: Int) {
        if nodePos[id] == nil { sira.append(id) }
        nodePos[id] = Nokta(x: x, y: y)
        nodeRow[id] = satir
    }

    public static func == (a: Yerlesim, b: Yerlesim) -> Bool {
        return a.nodePos == b.nodePos && a.nodeRow == b.nodeRow
    }
}

/// Ağaç yerleşimi (web l.2023-2290 ve normDrag). Koordinatlar web ile aynıdır.
public enum Agacla {
    public static let NW = 118.0
    public static let NH = 128.0
    public static let HGAP = 16.0
    public static let SPGAP = 30.0
    public static let VGAP = 58.0
    public static let ROWH = 128.0 + 58.0
    public static let AVR = 30.0
    public static let AVC = 36.0

    public static func pairKey(_ x: String?, _ y: String?, _ m: AileModeli) -> String {
        return m.pairKey(x, y)
    }

    public static func buildFamilies(_ agac: Agac) -> AileModeli {
        return AileModeli(agac)
    }

    /// Web `byBirth(a,b)` (-1/0/1): doğum yılı, yoksa "9999"
    static func byBirth(_ a: String, _ b: String, _ m: AileModeli) -> Int {
        let ya = m.dogumYili[a] ?? "9999"
        let yb = m.dogumYili[b] ?? "9999"
        if ya == yb { return 0 }
        return ya < yb ? -1 : 1
    }

    // MARK: placeSub

    /// Kişi + eşleri bir blok olarak yan yana; çocuklar evliliğe göre gruplu. maxRow verilirse o satırın altına inilmez.
    static func placeSub(_ id: String, _ row: Int, _ left: Double, _ visited: inout Set<String>,
                         _ maxRow: Int?, _ m: AileModeli, _ d: inout Yerlesim) -> (ids: [String], right: Double) {
        visited.insert(id)
        let fams = m.famOf[id] ?? []
        var partners: [String] = []
        for fi in fams {
            if let o = m.partnerIn(m.aileler[fi], id), !o.isEmpty, !visited.contains(o) {
                visited.insert(o)
                partners.append(o)
            }
        }
        var block: [String] = [id]
        if !partners.isEmpty {
            block = [partners[0], id]
            block.append(contentsOf: partners.dropFirst())
        }
        let n = Double(block.count)
        let blockW = n * NW + (n - 1) * SPGAP
        var placed: [String] = []
        var placedSet = Set<String>()
        var cx = left
        var anyKid = false
        var altaInilir = true
        if let mr = maxRow { altaInilir = row < mr }
        if altaInilir {
            for fi in fams {
                for k in m.aileler[fi].kids {
                    if visited.contains(k) || m.kisiler[k] == nil { continue }
                    let r = placeSub(k, row + 1, cx, &visited, maxRow, m, &d)
                    for q in r.ids {
                        placed.append(q)
                        placedSet.insert(q)
                    }
                    cx = r.right + HGAP
                    anyKid = true
                }
            }
        }
        var blockLeft = left
        if anyKid {
            var kidCenters: [Double] = []
            for fi in fams {
                for k in m.aileler[fi].kids {
                    if let p = d.nodePos[k], placedSet.contains(k), d.nodeRow[k] == row + 1 {
                        kidCenters.append(p.x + NW / 2)
                    }
                }
            }
            var mid = (left + cx - HGAP) / 2
            if let mn = kidCenters.min(), let mx = kidCenters.max() {
                mid = (mn + mx) / 2
            }
            blockLeft = mid - blockW / 2
            if blockLeft < left {
                let fark = left - blockLeft
                for q in placed { d.nodePos[q]!.x += fark }
                cx += fark
                blockLeft = left
            }
        }
        for (i, q) in block.enumerated() {
            d.yerles(q, blockLeft + Double(i) * (NW + SPGAP), Double(row) * ROWH, row)
            placed.append(q)
        }
        var right = blockLeft + blockW
        let kidRight = anyKid ? cx - HGAP : left
        if kidRight > right { right = kidRight }
        return (placed, right)
    }

    // MARK: kuşaklar, torun sayısı

    /// Ana kökten başlayıp ebeveyn -1, çocuk +1, eş aynı satır
    static func assignGenerations(_ startIds: [String], _ m: AileModeli) -> [String: Int] {
        var gen: [String: Int] = [:]
        var q: [String] = []
        var bas = 0
        func push(_ id: String, _ g: Int) {
            if gen[id] == nil && m.kisiler[id] != nil {
                gen[id] = g
                q.append(id)
            }
        }
        for id in startIds {
            if gen[id] != nil { continue }
            push(id, 0)
            while bas < q.count {
                let id2 = q[bas]
                bas += 1
                let g = gen[id2] ?? 0
                for fi in m.famOf[id2] ?? [] {
                    let f = m.aileler[fi]
                    if let o = m.partnerIn(f, id2), !o.isEmpty { push(o, g) }
                    for k in f.kids { push(k, g + 1) }
                }
                if let pi = m.parentFam[id2] {
                    let p = m.aileler[pi]
                    if !p.a.isEmpty { push(p.a, g - 1) }
                    if let b = p.b, !b.isEmpty { push(b, g - 1) }
                }
            }
        }
        return gen
    }

    static func descCount(_ id: String, _ seen: inout Set<String>, _ m: AileModeli) -> Int {
        if seen.contains(id) { return 0 }
        seen.insert(id)
        var n = 0
        for fi in m.famOf[id] ?? [] {
            for k in m.aileler[fi].kids where !seen.contains(k) {
                n += 1 + descCount(k, &seen, m)
            }
        }
        return n
    }

    public static func descCount(_ id: String, _ m: AileModeli) -> Int {
        var seen = Set<String>()
        return descCount(id, &seen, m)
    }

    // MARK: Tüm Ağaç

    public static func layoutFull(_ agac: Agac, _ m: AileModeli) -> Yerlesim {
        var d = Yerlesim()
        let pl = m.sira
        if pl.isEmpty { return d }
        // Kök: ebeveyni olmayan ve hiçbir eşinin ebeveyni ağaçta bulunmayan kişi
        var roots: [String] = []
        for id in pl {
            if m.parentFam[id] != nil { continue }
            var esliEbeveynli = false
            for fi in m.famOf[id] ?? [] {
                if let o = m.partnerIn(m.aileler[fi], id), !o.isEmpty, m.parentFam[o] != nil {
                    esliEbeveynli = true
                    break
                }
            }
            if !esliEbeveynli { roots.append(id) }
        }
        var dc: [String: Int] = [:]
        for r in roots { dc[r] = descCount(r, m) }
        // kararlı sıralama: torun sayısı azalan, sonra doğum yılı
        let eskiKok = roots
        let kokDizin = Array(0..<eskiKok.count).sorted { (p, q) in
            let fark = (dc[eskiKok[q]] ?? 0) - (dc[eskiKok[p]] ?? 0)
            if fark != 0 { return fark < 0 }
            let b = byBirth(eskiKok[p], eskiKok[q], m)
            if b != 0 { return b < 0 }
            return p < q
        }
        roots = kokDizin.map { eskiKok[$0] }
        let gen = assignGenerations(roots.isEmpty ? pl : roots, m)
        var minG = 0
        for g in gen.values where g < minG { minG = g }
        var visited = Set<String>()
        var occ: [Int: [(Double, Double)]] = [:]
        func addOcc(_ ids: [String]) {
            for q in ids {
                let r = d.nodeRow[q] ?? 0
                let x = d.nodePos[q]!.x
                occ[r, default: []].append((x, x + NW))
            }
        }
        func hits(_ ids: [String], _ dx: Double) -> Bool {
            for q in ids {
                let px = d.nodePos[q]!.x
                let L = px + dx - HGAP / 2
                let R = px + NW + dx + HGAP / 2
                for (a, b) in occ[d.nodeRow[q] ?? 0] ?? [] where L < b && R > a {
                    return true
                }
            }
            return false
        }
        var rightEdge = 0.0
        var first = true
        var order = roots
        var orderSet = Set(roots)
        for id in pl where !orderSet.contains(id) {
            order.append(id)
            orderSet.insert(id)
        }
        for r in order {
            if visited.contains(r) { continue }
            let row = (gen[r] ?? 0) - minG
            let before = visited
            let res = placeSub(r, row, 0, &visited, nil, m, &d)
            if res.ids.isEmpty { continue }
            if first {
                addOcc(res.ids)
                rightEdge = res.right
                first = false
                continue
            }
            // Daha önce yerleşmiş akrabaların (ör. gelin/damat) üstüne en yakın boş yere koy
            var xs: [Double] = []
            for q in res.ids {
                var lk: [String] = []
                for fi in m.famOf[q] ?? [] {
                    let f = m.aileler[fi]
                    if let o = m.partnerIn(f, q), !o.isEmpty { lk.append(o) }
                    lk.append(contentsOf: f.kids)
                }
                if let pi = m.parentFam[q] {
                    let p = m.aileler[pi]
                    lk.append(p.a)
                    if let b = p.b { lk.append(b) }
                }
                for o in lk where !o.isEmpty && before.contains(o) {
                    if let po = d.nodePos[o], let pq = d.nodePos[q] { xs.append(po.x - pq.x) }
                }
            }
            var dx: Double?
            if !xs.isEmpty {
                var toplam = 0.0
                for v in xs { toplam += v }
                let want = toplam / Double(xs.count)
                let step = (NW + HGAP) / 2
                var k = 0
                while k < 600 && dx == nil {
                    let isaretler: [Double] = k == 0 ? [1] : [1, -1]
                    for sgn in isaretler {
                        let t = want + sgn * Double(k) * step
                        if !hits(res.ids, t) {
                            dx = t
                            break
                        }
                    }
                    k += 1
                }
            }
            let kayma = dx ?? (rightEdge + HGAP * 3)
            for q in res.ids { d.nodePos[q]!.x += kayma }
            addOcc(res.ids)
            for q in res.ids {
                let sag = d.nodePos[q]!.x + NW
                if sag > rightEdge { rightEdge = sag }
            }
        }
        // Son güvenlik: aynı satırda çakışan kart kalmasın
        var rows: [Int: [String]] = [:]
        for id in d.sira { rows[d.nodeRow[id] ?? 0, default: []].append(id) }
        for (_, ids0) in rows {
            let dizin = Array(0..<ids0.count).sorted { (p, q) in
                let xp = d.nodePos[ids0[p]]!.x
                let xq = d.nodePos[ids0[q]]!.x
                if xp != xq { return xp < xq }
                return p < q
            }
            let ids = dizin.map { ids0[$0] }
            if ids.count < 2 { continue }
            for i in 1..<ids.count {
                let p0 = d.nodePos[ids[i - 1]]!
                let alt = p0.x + NW + HGAP / 2
                if d.nodePos[ids[i]]!.x < alt { d.nodePos[ids[i]]!.x = alt }
            }
        }
        return d
    }

    // MARK: Odak

    /// Odak görünümü: üstte atalar (upGen kuşak), ortada kişi + eşleri + kardeşleri, altta torunlar (downGen kuşak)
    public static func layoutFocus(_ fid: String, upGen: Int, downGen: Int, _ agac: Agac, _ m: AileModeli) -> Yerlesim {
        var d = Yerlesim()
        guard m.kisiler[fid] != nil else { return d }
        var visited = Set<String>()
        let res = placeSub(fid, 0, 0, &visited, downGen, m, &d)
        let shift = -(d.nodePos[fid]!.x + NW / 2)
        for q in res.ids { d.nodePos[q]!.x += shift }
        var L = Double.infinity
        var R = -Double.infinity
        for q in res.ids where d.nodeRow[q] == 0 {
            let x = d.nodePos[q]!.x
            if x < L { L = x }
            if x > R { R = x }
        }
        R += NW
        if let pi = m.parentFam[fid] {
            let P = m.aileler[pi]
            var sibs: [String] = []
            for k in P.kids where k != fid && m.kisiler[k] != nil && !visited.contains(k) { sibs.append(k) }
            let fy = m.dogumYili[fid] ?? "9999"
            var older: [String] = []
            var olderSet = Set<String>()
            for k in sibs where (m.dogumYili[k] ?? "9999") < fy {
                older.append(k)
                olderSet.insert(k)
            }
            older.reverse()
            var younger: [String] = []
            for k in sibs where !olderSet.contains(k) { younger.append(k) }
            for k in older {
                L -= NW + HGAP
                d.yerles(k, L, 0, 0)
                visited.insert(k)
            }
            for k in younger {
                d.yerles(k, R + HGAP, 0, 0)
                R += NW + HGAP
                visited.insert(k)
            }
        }
        // Atalar: her ebeveyn kendi atalarının genişliği kadar yer alır
        var wMemo: [String: Double] = [:]
        func pedW(_ id: String, _ dd: Int) -> Double {
            let key = id + "@" + String(dd)
            if let w = wMemo[key] { return w }
            var w = NW
            if dd > 0, let fi = m.parentFam[id] {
                let F = m.aileler[fi]
                var ps: [String] = []
                if !F.a.isEmpty && !visited.contains(F.a) { ps.append(F.a) }
                if let b = F.b, !b.isEmpty, !visited.contains(b) { ps.append(b) }
                if ps.count == 2 {
                    let w0 = pedW(ps[0], dd - 1)
                    let w1 = pedW(ps[1], dd - 1)
                    w = max(NW, w0 + SPGAP + w1)
                } else if ps.count == 1 {
                    w = max(NW, pedW(ps[0], dd - 1))
                }
            }
            wMemo[key] = w
            return w
        }
        func placePed(_ id: String, _ cx: Double, _ row: Int, _ dd: Int) {
            if dd <= 0 { return }
            guard let fi = m.parentFam[id] else { return }
            let F = m.aileler[fi]
            var ps: [String] = []
            if !F.a.isEmpty && m.kisiler[F.a] != nil && !visited.contains(F.a) { ps.append(F.a) }
            if let b = F.b, !b.isEmpty, m.kisiler[b] != nil, !visited.contains(b) { ps.append(b) }
            if ps.isEmpty { return }
            for x in ps { visited.insert(x) }
            let y = Double(row) * ROWH
            if ps.count == 1 {
                d.yerles(ps[0], cx - NW / 2, y, row)
                placePed(ps[0], cx, row - 1, dd - 1)
                return
            }
            let w0 = pedW(ps[0], dd - 1)
            let w1 = pedW(ps[1], dd - 1)
            let tot = w0 + SPGAP + w1
            let c0 = cx - tot / 2 + w0 / 2
            let c1 = cx + tot / 2 - w1 / 2
            d.yerles(ps[0], c0 - NW / 2, y, row)
            d.yerles(ps[1], c1 - NW / 2, y, row)
            placePed(ps[0], c0, row - 1, dd - 1)
            placePed(ps[1], c1, row - 1, dd - 1)
        }
        placePed(fid, 0, -1, upGen)
        return d
    }

    // MARK: varsayılan odak, soy

    public static func defaultFocus(_ agac: Agac, _ m: AileModeli) -> String? {
        var best: String?
        var bs = -1
        for id in m.sira {
            var a = 0
            var cur = [id]
            var seen: Set<String> = [id]
            var dd = 0
            while dd < 4 && !cur.isEmpty {
                var nx: [String] = []
                for x in cur {
                    guard let fi = m.parentFam[x] else { continue }
                    let F = m.aileler[fi]
                    var ebeveynler: [String] = [F.a]
                    if let b = F.b { ebeveynler.append(b) }
                    for y in ebeveynler where !y.isEmpty && !seen.contains(y) {
                        seen.insert(y)
                        nx.append(y)
                        a += 1
                    }
                }
                cur = nx
                dd += 1
            }
            let s = min(a, 6) * 2 + min(descCount(id, m), 20)
            if s > bs {
                bs = s
                best = id
            }
        }
        return best
    }

    /// Seçilen kişinin doğrudan soyu (atalar + torunlar + eşleri); kişi yoksa nil
    public static func lineageOf(_ id: String, _ agac: Agac, _ m: AileModeli) -> Set<String>? {
        if id.isEmpty || m.kisiler[id] == nil { return nil }
        var s: Set<String> = [id]
        func up(_ x: String) {
            guard let fi = m.parentFam[x] else { return }
            let F = m.aileler[fi]
            var ebeveynler: [String] = [F.a]
            if let b = F.b { ebeveynler.append(b) }
            for y in ebeveynler where !y.isEmpty && !s.contains(y) {
                s.insert(y)
                up(y)
            }
        }
        func down(_ x: String) {
            for fi in m.famOf[x] ?? [] {
                let F = m.aileler[fi]
                if let o = m.partnerIn(F, x), !o.isEmpty { s.insert(o) }
                for k in F.kids where !s.contains(k) {
                    s.insert(k)
                    down(k)
                }
            }
        }
        up(id)
        down(id)
        for fi in m.famOf[id] ?? [] {
            if let o = m.partnerIn(m.aileler[fi], id), !o.isEmpty { s.insert(o) }
        }
        return s
    }

    // MARK: normDrag

    /// v6 öncesi kaydırmalar eski yerleşime göreydi; yeni yerleşimde anlamsız olduklarından "$old" altında saklanır
    public static func normDrag(_ d: JSON) -> JSON {
        if case .object(let o) = d, let v = o["$v"], case .number(let n) = v, n == 2 { return d }
        var cikti = Nesne()
        cikti["$v"] = .number(2)
        switch d {
        case .object(let o) where o.sayisi > 0:
            cikti["$old"] = d
        case .array(let a) where !a.isEmpty:
            cikti["$old"] = d
        default:
            break
        }
        return .object(cikti)
    }
}
