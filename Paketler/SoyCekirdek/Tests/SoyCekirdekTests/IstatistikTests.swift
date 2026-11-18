import Foundation
import XCTest
@testable import SoyCekirdek

final class IstatistikTests: XCTestCase {
    static let vakalar: [FixtureYukle.Vaka] = (try? FixtureYukle.yukle("istatistik")) ?? []

    func agaclar() -> [String: Agac] {
        var d: [String: Agac] = [:]
        for v in IstatistikTests.vakalar where v.girdi["tur"]?.metin == "agac" {
            d[v.girdi["agac"]?.metin ?? ""] = Agac(people: v.beklenen["people"]?.nesne ?? Nesne(),
                                                    nextId: Int(v.beklenen["nextId"]?.sayi ?? 1))
        }
        return d
    }

    func tam(_ j: JSON?) -> Int? {
        guard let d = j?.sayi else { return nil }
        return Int(d)
    }

    func sayimKontrol(_ s: [SayimSatiri], _ b: JSON?, _ ad: String, genislikBak: Bool) {
        let dizi = b?.dizi ?? []
        XCTAssertEqual(s.count, dizi.count, ad)
        if s.count != dizi.count { return }
        let enCok = dizi.first?.dizi?[1].sayi ?? 1
        for (i, e) in dizi.enumerated() {
            XCTAssertEqual(s[i].ad, e.dizi?[0].metin, "\(ad) #\(i) ad")
            XCTAssertEqual(Double(s[i].sayi), e.dizi?[1].sayi, "\(ad) #\(i) sayi")
            if genislikBak {
                let beklenen = ((e.dizi?[1].sayi ?? 0) / enCok * 100 + 0.5).rounded(.down)
                XCTAssertEqual(Double(s[i].genislik), beklenen, "\(ad) #\(i) genislik")
            }
        }
    }

    func kayitKontrol(_ k: YasamKaydi?, _ b: JSON?, _ ad: String) {
        guard let b = b, b != .null else {
            XCTAssertNil(k, ad)
            return
        }
        XCTAssertEqual(k?.id, b["id"]?.metin, ad)
        XCTAssertEqual(k?.ad, b["name"]?.metin, ad)
        XCTAssertEqual(k?.dogumYili, b["by"]?.metin, ad)
        XCTAssertEqual(k?.olumYili, b["dy"]?.metin, ad)
        XCTAssertEqual(k?.yas, tam(b["age"]), ad)
        XCTAssertEqual(k?.vefat, b["died"]?.mantik, ad)
    }

    func test_ozetFixture() throws {
        let ag = agaclar()
        XCTAssertEqual(ag.count, 6)
        var sayac = 0
        var bosSayisi = 0
        for v in IstatistikTests.vakalar where v.girdi["tur"]?.metin == "ozet" {
            guard let a = ag[v.girdi["agac"]?.metin ?? ""] else { XCTFail("agac yok: \(v.ad)"); continue }
            let ayar = HatirlatmaAyari.oku(v.girdi["ayarHam"]?.metin)
            let o = Istatistik.hesapla(a, simdi: GedcomTests.simdi, takvim: GedcomTests.takvim, ayar: ayar)
            let b = v.beklenen
            XCTAssertEqual(o.bos, b["bos"]?.mantik, v.ad)
            let st = b["stats"] ?? .null
            if o.bos {
                bosSayisi += 1
                XCTAssertEqual(st, .null, v.ad)
            } else {
                XCTAssertEqual(o.toplam, tam(st["total"]), v.ad)
                XCTAssertEqual(o.erkek, tam(st["males"]), v.ad)
                XCTAssertEqual(o.kadin, tam(st["females"]), v.ad)
                XCTAssertEqual(o.hayatta, tam(st["living"]), v.ad)
                XCTAssertEqual(o.fotografli, tam(st["withPhoto"]), v.ad)
                XCTAssertEqual(o.toplamFotograf, tam(st["totPh"]), v.ad)
                XCTAssertEqual(o.kusak, tam(st["gens"]), v.ad)
                XCTAssertEqual(o.ortalamaOmur, tam(st["avgLife"]), v.ad)
                XCTAssertEqual(o.ortalamaYas, tam(st["avgAlive"]), v.ad)
                kayitKontrol(o.enUzun, st["oldest"], v.ad + " enUzun")
                kayitKontrol(o.enKisa, st["youngest"], v.ad + " enKisa")
                sayimKontrol(o.enCokIsimler, st["topNames"], v.ad + " isimler", genislikBak: true)
                sayimKontrol(o.dogumYerleri, st["topL"], v.ad + " yerler", genislikBak: true)
                sayimKontrol(o.soyadlar, st["topS"], v.ad + " soyadlar", genislikBak: false)
                let sd = st["sd"]?.dizi ?? []
                XCTAssertEqual(o.onYillar.count, sd.count, v.ad)
                if o.onYillar.count == sd.count {
                    let enCok = sd.map { $0.dizi?[1].sayi ?? 0 }.max() ?? 1
                    for (i, e) in sd.enumerated() {
                        XCTAssertEqual(String(o.onYillar[i].onYil), e.dizi?[0].metin, v.ad)
                        XCTAssertEqual(Double(o.onYillar[i].sayi), e.dizi?[1].sayi, v.ad)
                        let w = ((e.dizi?[1].sayi ?? 0) / max(enCok, 1) * 100 + 0.5).rounded(.down)
                        XCTAssertEqual(Double(o.onYillar[i].genislik), w, v.ad)
                    }
                }
                let ub = st["upcomingBD"]?.dizi ?? []
                XCTAssertEqual(o.yaklasanDogumGunleri.count, ub.count, v.ad)
                if o.yaklasanDogumGunleri.count == ub.count {
                    for (i, e) in ub.enumerated() {
                        let u = o.yaklasanDogumGunleri[i]
                        XCTAssertEqual(u.id, e["id"]?.metin, "\(v.ad) #\(i)")
                        XCTAssertEqual(u.ad, e["nm"]?.metin, "\(v.ad) #\(i)")
                        XCTAssertEqual(u.diff, tam(e["diff"]), "\(v.ad) #\(i)")
                        XCTAssertEqual(u.gun, e["day"]?.metin, "\(v.ad) #\(i)")
                        XCTAssertEqual(u.ay, e["month"]?.metin, "\(v.ad) #\(i)")
                        XCTAssertEqual(u.yasiniDolduruyor, tam(e["turningAge"]), "\(v.ad) #\(i)")
                    }
                }
                let m = Double(o.toplam)
                XCTAssertEqual(o.erkekYuzde, Int(((Double(o.erkek) / m * 100) + 0.5).rounded(.down)), v.ad)
                XCTAssertEqual(o.kadinYuzde, Int(((Double(o.kadin) / m * 100) + 0.5).rounded(.down)), v.ad)
            }
            // ana sayfa
            let h = b["home"] ?? .null
            XCTAssertEqual(o.kisiSayisi, tam(h["n"]), v.ad)
            XCTAssertEqual(o.genDepth, tam(h["genDepth"]), v.ad)
            XCTAssertEqual(Istatistik.genDepth(a), tam(h["genDepth"]), v.ad)
            let ev = h["ev"]?.dizi ?? []
            XCTAssertEqual(o.yaklasanOlaylar.count, ev.count, v.ad)
            if o.yaklasanOlaylar.count == ev.count {
                for (i, e) in ev.enumerated() {
                    let x = o.yaklasanOlaylar[i]
                    XCTAssertEqual(x.id, e["id"]?.metin, "\(v.ad) ev#\(i)")
                    XCTAssertEqual(x.diff, tam(e["diff"]), "\(v.ad) ev#\(i)")
                    XCTAssertEqual(x.kind, e["kind"]?.metin, "\(v.ad) ev#\(i)")
                    XCTAssertEqual(x.n, tam(e["n"]), "\(v.ad) ev#\(i)")
                    XCTAssertEqual(x.d, tam(e["d"]), "\(v.ad) ev#\(i)")
                    XCTAssertEqual(x.m, tam(e["m"]), "\(v.ad) ev#\(i)")
                }
            }
            if o.kisiSayisi > 0 {
                XCTAssertEqual(o.altBaslik, "\(o.kisiSayisi) kişi · \(o.genDepth) kuşak", v.ad)
                XCTAssertEqual(o.sayacBaslik, "Aile bireyleri (\(o.kisiSayisi))", v.ad)
            } else {
                XCTAssertEqual(o.altBaslik, "Ağacınız henüz boş — + ile başlayın", v.ad)
                XCTAssertEqual(o.sayacBaslik, "Aile bireyleri", v.ad)
            }
            XCTAssertEqual(o.anaOlayBasligi == nil, ev.isEmpty, v.ad)
            if let e = ev.first, let id = e["id"]?.metin, let k = a.kisi(id) {
                let ne = Islem.pname(k)
                let kind = e["kind"]?.metin
                let n = tam(e["n"]) ?? 0
                let ne2 = kind == "bd" ? "\(n). yaş günü" : (kind == "an" ? "vefatının \(n). yılı" : "doğumunun \(n). yılı")
                XCTAssertEqual(o.anaOlayBasligi, "\(ne) · \(ne2)", v.ad)
                let ay = Istatistik.AYLAR[(tam(e["m"]) ?? 1) - 1]
                let ek = ev.count > 1 ? " · +\(ev.count - 1) yaklaşan" : ""
                XCTAssertEqual(o.anaOlayAltSatiri, "\(tam(e["d"]) ?? 0) \(ay) · \(Istatistik.gunMetni(tam(e["diff"]) ?? 0))\(ek)", v.ad)
            }
            sayac += 1
        }
        XCTAssertEqual(sayac, 18)
        XCTAssertEqual(bosSayisi, 0 + 3)
    }

    func test_bosAgac() {
        let o = Istatistik.hesapla(Agac(), simdi: GedcomTests.simdi, takvim: GedcomTests.takvim)
        XCTAssertTrue(o.bos)
        XCTAssertEqual(o.toplam, 0)
        XCTAssertEqual(o.erkek, 0)
        XCTAssertEqual(o.kadin, 0)
        XCTAssertEqual(o.hayatta, 0)
        XCTAssertEqual(o.kusak, 0)
        XCTAssertEqual(o.genDepth, 0)
        XCTAssertEqual(o.kisiSayisi, 0)
        XCTAssertNil(o.ortalamaOmur)
        XCTAssertNil(o.ortalamaYas)
        XCTAssertNil(o.enUzun)
        XCTAssertNil(o.enKisa)
        XCTAssertTrue(o.enCokIsimler.isEmpty)
        XCTAssertTrue(o.dogumYerleri.isEmpty)
        XCTAssertTrue(o.soyadlar.isEmpty)
        XCTAssertTrue(o.onYillar.isEmpty)
        XCTAssertTrue(o.yaklasanDogumGunleri.isEmpty)
        XCTAssertTrue(o.yaklasanOlaylar.isEmpty)
        XCTAssertEqual(o.erkekYuzde, 0)
        XCTAssertEqual(o.kadinYuzde, 0)
        XCTAssertNil(o.anaOlayBasligi)
        XCTAssertEqual(o.altBaslik, "Ağacınız henüz boş — + ile başlayın")
        XCTAssertEqual(Istatistik.genDepth(Agac()), 0)
    }

    func test_etiketler() {
        XCTAssertEqual(Istatistik.Etiket.toplam, "Toplam Kişi")
        XCTAssertEqual(Istatistik.Etiket.hayatta, "Hayatta")
        XCTAssertEqual(Istatistik.Etiket.erkek, "Erkek")
        XCTAssertEqual(Istatistik.Etiket.kadin, "Kadın")
        XCTAssertEqual(Istatistik.Etiket.fotografli, "Fotoğraflı")
        XCTAssertEqual(Istatistik.Etiket.toplamFotograf, "Toplam Fotoğraf")
        XCTAssertEqual(Istatistik.Etiket.kusak, "Kuşak")
        XCTAssertEqual(Istatistik.Etiket.ortalamaOmur, "Ortalama Ömür (vefat)")
        XCTAssertEqual(Istatistik.Etiket.ortalamaYas, "Ortalama Yaş (yaşayan)")
        XCTAssertEqual(Istatistik.Etiket.yasamRekorlari, "🏅 Yaşam Rekorları")
        XCTAssertEqual(Istatistik.Etiket.enUzun, "🥇 En Uzun: ")
        XCTAssertEqual(Istatistik.Etiket.enKisa, "📉 En Kısa: ")
        XCTAssertEqual(Istatistik.Etiket.isimler, "👤 En Çok Kullanılan İsimler")
        XCTAssertEqual(Istatistik.Etiket.onYillar, "📅 On Yıllara Göre Doğumlar")
        XCTAssertEqual(Istatistik.Etiket.yerler, "📍 En Çok Doğum Yeri")
        XCTAssertEqual(Istatistik.Etiket.soyadlar, "👨‍👩‍👧 Soyadlar")
        XCTAssertEqual(Istatistik.Etiket.cinsiyetDagilimi, "Cinsiyet Dağılımı")
        XCTAssertEqual(Istatistik.Etiket.yaklasanDogum, "🎂 Yaklaşan Doğum Günleri (30 gün)")
        XCTAssertEqual(Istatistik.Etiket.veriYok, "Veri yok")
        XCTAssertEqual(Istatistik.Etiket.veriYokAciklama, "Önce kişi ekleyin.")
    }

    func test_yaklasanDogumGunuMetni() {
        XCTAssertEqual(Istatistik.gunMetni(0), "Bugün")
        XCTAssertEqual(Istatistik.gunMetni(1), "Yarın")
        XCTAssertEqual(Istatistik.gunMetni(7), "7 gün sonra")
        let u = YaklasanDogum(id: "P1", ad: "A", diff: 0, gun: "05", ay: "03", yasiniDolduruyor: 30)
        XCTAssertEqual(u.metin, "Bugün 🎉 · 05/03 · 30 yaşına giriyor")
        XCTAssertEqual(YaklasanDogum(id: "P1", ad: "A", diff: 1, gun: "05", ay: "03", yasiniDolduruyor: 3).metin, "Yarın 🎁 · 05/03 · 3 yaşına giriyor")
        XCTAssertEqual(YaklasanDogum(id: "P1", ad: "A", diff: 9, gun: "05", ay: "03", yasiniDolduruyor: 3).metin, "9 gün sonra · 05/03 · 3 yaşına giriyor")
    }
}
