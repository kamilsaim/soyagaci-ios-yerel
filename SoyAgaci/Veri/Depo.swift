import Foundation
import Observation
import SoyCekirdek

/// Uygulamanın tek veri kaynağı: ağaç, eşitleme durumu, fotoğraf bağlantıları, ağaç konumları.
/// Ekranlar `degistir` ile ağacı değiştirir; kayıt/eşitleme (`Esitleyici`) arkada çalışır.
@MainActor
@Observable
final class Depo {
    /// Güncel ağaç. Doğrudan yazmayın: `degistir` kullanın (kayıt tetikler).
    private(set) var agac = Agac()
    /// Web `setSync`: gonderiliyor ⟳, tamam ✓, hata !. (cakisma da hata gibi gösterilir; diyalog `cakisma` ile açılır.)
    private(set) var esitleme: EsitlemeDurumu = .tamam
    /// Başka cihaz araya girdi: dolu iken "Bu ağaç başka bir cihazdan güncellenmiş…" sorulur → `cakismayiCoz`.
    var cakisma: Date?
    /// Son yüklemenin kaynağı (`.yerelOkunamadi` = bulut okunamadı, yerel gösteriliyor ve buluta itilmez).
    private(set) var kaynak: YuklemeKaynagi = .yerel
    private(set) var yukleniyor = false
    /// Tüm Ağaç elle kaydırmaları (`$v:2` biçimi, web `nodeDrag`).
    private(set) var konumlar: JSON = Agacla.normDrag(.null)
    /// İmzalı fotoğraf bağlantıları yenilenince artar; fotoğraf gösteren görünümler bunu okuyarak yeniden çizilir.
    private(set) var fotoSurum = 0
    /// Şu an yüklü verinin sahibi (nil = yerel mod / yok).
    private(set) var uid: String?

    let foto: FotoServisi
    let konum: KonumDeposu

    private let esitleyici: Esitleyici
    private let yerel: DosyaYerel
    private var islemler: AsyncStream<Is>.Continuation!
    private var yuklemeNo = 0
    private var yenileme: Task<Void, Never>?

    /// Kayıtlar sırayla `Esitleyici`'ye gider (Task'ların sırası garanti olmadığından tek tüketicili akış).
    private enum Is {
        case kaydet(Agac)
        case bitir(CheckedContinuation<Void, Never>)
    }

    init(oturum: Oturum? = nil) {
        let y = DosyaYerel()
        yerel = y
        esitleyici = Esitleyici(bulut: SupabaseBulut(), yerel: y)
        foto = FotoServisi()
        konum = KonumDeposu(yerel: y)

        let (akis, devam) = AsyncStream<Is>.makeStream()
        islemler = devam
        let e = esitleyici
        Task {
            for await i in akis {
                switch i {
                case .kaydet(let a): await e.kaydet(a)
                case .bitir(let c): c.resume()
                }
            }
        }

        let durumlar = esitleyici.durumlar
        Task { [weak self] in
            for await d in durumlar {
                guard let self else { return }
                self.durumUygula(d)
            }
        }

        // 50 dakikada bir imzalı bağlantıları tazele (bağlantılar 1 saatte dolar)
        yenileme = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50 * 60 * 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                await self.fotolariImzala(zorla: true)
            }
        }

        oturum?.cikisHazirlik = { [weak self] in await self?.cikisaHazirla() ?? true }
        oturum?.cikisTemizle = { [weak self] eskiUid in await self?.cikisTemizligi(eskiUid) }
    }

    private func durumUygula(_ d: EsitlemeDurumu) {
        esitleme = d
        if case .cakisma(let t) = d { cakisma = t }
    }

    // MARK: değiştirme

    /// Ağacı değiştirir ve kaydeder (yerel + 800 ms sonra bulut). Web `save()`.
    func degistir(_ f: (inout Agac) -> Void) {
        var a = agac
        f(&a)
        guard a != agac else { return }
        agac = a
        islemler.yield(.kaydet(a))
    }

    /// Bekleyen `degistir` kayıtlarının `Esitleyici`'ye ulaşmasını bekler.
    private func kayitlariBekle() async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            islemler.yield(.bitir(c))
        }
    }

    // MARK: yükleme (web load())

    /// Kullanıcı değişince çağrılır. `uid == nil` yerel mod verisini yükler.
    func yukle(uid yeniUid: String?) async {
        yuklemeNo += 1
        let no = yuklemeNo
        yukleniyor = true
        await kayitlariBekle()
        await foto.kullaniciAyarla(yeniUid)
        let sonuc = await esitleyici.yukle(uid: yeniUid)
        let k = await konum.yukle(uid: yeniUid)
        guard no == yuklemeNo else { return } // daha yeni bir yükleme başladı
        uid = yeniUid
        agac = sonuc.agac
        kaynak = sonuc.kaynak
        konumlar = k
        cakisma = nil
        esitleme = .tamam
        yukleniyor = false
        await fotolariImzala(zorla: true)
    }

    /// Oturum yok ve yerel mod seçilmedi (giriş ekranı): veri bellekten atılır, yerel dosyalar kalır.
    func bosalt() async {
        yuklemeNo += 1
        await kayitlariBekle()
        await foto.kullaniciAyarla(nil)
        _ = await esitleyici.yukle(uid: nil) // eşitleyicinin eski hesap durumunu bırakması için
        uid = nil
        agac = Agac()
        konumlar = Agacla.normDrag(.null)
        yukleniyor = false
    }

    // MARK: çakışma (web pushToCloud askConfirm)

    /// Evet ("Üzerine yaz") → zorla gönder; hayır → buluttaki sürümü yükle, yerel değişiklik bırakılır.
    func cakismayiCoz(uzerineYaz: Bool) async {
        cakisma = nil
        if uzerineYaz {
            _ = await esitleyici.gonder(zorla: true)
        } else {
            let sonuc = await esitleyici.bulutuKabulEt()
            let k = await konum.yukle(uid: uid)
            agac = sonuc.agac
            kaynak = sonuc.kaynak
            konumlar = k
            esitleme = .tamam
            await fotolariImzala(zorla: true)
        }
    }

    /// "Yeniden dene" (ör. bulut kaydı hata verdi).
    func yenidenGonder() async {
        _ = await esitleyici.gonder(zorla: false)
    }

    // MARK: çıkış

    /// Çıkıştan önce bekleyen kaydı gönderir; false = hâlâ buluta gitmemiş değişiklik var.
    func cikisaHazirla() async -> Bool {
        await kayitlariBekle()
        return await esitleyici.cikisaHazirla()
    }

    /// Çıkış / hesap silme sonrası: yerel bulut kopyası, eşitleme izleri, konum dosyası ve bellekteki veri silinir.
    func cikisTemizligi(_ eskiUid: String?) async {
        await kayitlariBekle()
        await esitleyici.cikisYap()
        if let eskiUid { konum.yerelSil(uid: eskiUid) }
        await foto.kullaniciAyarla(nil)
        await foto.onbellekBosalt()
        uid = nil
        agac = Agac()
        konumlar = Agacla.normDrag(.null)
        cakisma = nil
        esitleme = .tamam
        fotoSurum += 1
    }

    // MARK: konumlar

    /// Web `saveLayout`: yerel + bulut. Bulut başarısızsa false (kullanıcıya "Ağaç konumları buluta kaydedilemedi").
    @discardableResult
    func konumlariKaydet(_ yeni: JSON) async -> Bool {
        konumlar = Agacla.normDrag(yeni)
        return await konum.kaydet(konumlar, uid: uid)
    }

    // MARK: fotoğraflar

    /// Ağaçtaki tüm fotoğraf referansları (kapak + galeri).
    static func fotoReferanslari(_ a: Agac) -> Set<String> {
        var s = Set<String>()
        for (_, j) in a.people.ciftler {
            guard case .object(let o) = j else { continue }
            let k = Kisi(o)
            if let p = k.photo, !p.isEmpty { s.insert(p) }
            for g in k.gallery where !g.isEmpty { s.insert(g) }
        }
        return s
    }

    func fotolariImzala(zorla: Bool = false) async {
        guard uid != nil else { return }
        await foto.imzala(Depo.fotoReferanslari(agac), zorla: zorla)
        fotoSurum += 1
    }

    /// Fotoğrafı küçültüp yükler (girişsizse data URL). Yeni yol için bağlantı hemen hazır olur.
    func fotoYukle(_ veri: Data) async throws -> String {
        let r = try await foto.yukle(veri)
        fotoSurum += 1
        return r
    }

    /// Artık hiçbir kişide kullanılmayan depo fotoğraflarını siler (web `purgePhotos`; çağrıdan ÖNCE ağaç güncellenmiş olmalı).
    func fotoTemizle(_ eskiler: [String]) async {
        await foto.temizle(eskiler, kalan: Depo.fotoReferanslari(agac))
    }
}
