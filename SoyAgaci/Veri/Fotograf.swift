import Foundation
import Supabase
import UIKit

/// Web `uid32()`: tire yok, küçük harfli 32 onaltılık karakter.
func uid32() -> String {
    UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
}

/// Fotoğraf referansı depo yolu mu ("uid/abc.jpg")? Eski base64 ("data:…") ve http adresleri değildir.
func fotoDepoYoluMu(_ r: String) -> Bool {
    !r.isEmpty && !r.hasPrefix("data:") && !r.hasPrefix("http")
}

/// Supabase Storage `soy-fotograf` kovası: imzalı bağlantılar, yükleme, temizlik.
/// `url(_:)` ekranlardan eşzamanlı çağrılabilsin diye kilitli önbellek kullanır (nonisolated).
actor FotoServisi {
    static let kova = "soy-fotograf"
    static let enBuyukKenar: CGFloat = 1400
    static let kalite: CGFloat = 0.82

    private final class Onbellek: @unchecked Sendable {
        private let kilit = NSLock()
        private var kayit: [String: (url: URL, bitis: Date)] = [:]
        func al(_ r: String) -> (url: URL, bitis: Date)? { kilit.lock(); defer { kilit.unlock() }; return kayit[r] }
        func koy(_ r: String, _ u: URL, _ b: Date) { kilit.lock(); kayit[r] = (u, b); kilit.unlock() }
        func sil(_ r: String) { kilit.lock(); kayit[r] = nil; kilit.unlock() }
        func bosalt() { kilit.lock(); kayit = [:]; kilit.unlock() }
    }

    private let istemci: SupabaseClient
    private let onbellek = Onbellek()
    private var uid: String?

    init(istemci: SupabaseClient = Servis.istemci) { self.istemci = istemci }

    /// Oturum değişince çağrılır (yükleme yolu `{uid}/…`); çıkışta önbellek boşalır.
    func kullaniciAyarla(_ yeni: String?) {
        if yeni != uid { onbellek.bosalt() }
        uid = yeni
    }

    /// `<img src>` karşılığı: depo yolu → imzalı adres (önbellekte yoksa nil); data URL → kendisi.
    nonisolated func url(_ ref: String) -> URL? {
        if ref.hasPrefix("data:") || ref.hasPrefix("http") { return URL(string: ref) }
        return onbellek.al(ref)?.url
    }

    /// Web `ensurePhotoUrls`: kullanılan yollar için toplu imzalı bağlantı (100'lük paketler, 3600 sn).
    /// `zorla` yoksa süresi 5 dakikadan fazla kalanlar atlanır. Hatalar sessizdir (fotoğraf görünmez, uygulama çalışır).
    func imzala(_ refs: Set<String>, zorla: Bool) async {
        guard uid != nil else { return }
        let simdi = Date()
        let gerek = refs.filter { r in
            guard fotoDepoYoluMu(r) else { return false }
            if zorla { return true }
            guard let k = onbellek.al(r) else { return true }
            return k.bitis < simdi.addingTimeInterval(300)
        }.sorted()
        let depo = istemci.storage.from(FotoServisi.kova)
        var i = 0
        while i < gerek.count {
            let paket = Array(gerek[i..<min(i + 100, gerek.count)])
            i += 100
            let bitis = simdi.addingTimeInterval(3300)
            do {
                let adresler = try await depo.createSignedURLs(paths: paket, expiresIn: 3600)
                if adresler.count == paket.count {
                    for (r, u) in zip(paket, adresler) { onbellek.koy(r, u, bitis) }
                } else {
                    // yanıt eksik döndü: eşleşme belirsiz, tek tek al
                    for r in paket {
                        if let u = try? await depo.createSignedURL(path: r, expiresIn: 3600) { onbellek.koy(r, u, bitis) }
                    }
                }
            } catch {
                continue
            }
        }
    }

    /// Web `storePhoto`: 1400 px / JPEG 0.82'ye küçültür; girişliyse `{uid}/{uid32}.jpg` olarak yükler ve yolu döner.
    /// Girişsizse (yerel mod) `data:image/jpeg;base64,…` döner. Yükleme hatası fırlatılır (çağıran gerekirse
    /// `veriUrlu` ile yerel saklamaya düşer: web "Fotoğraf buluta yüklenemedi, cihazda saklanıyor").
    func yukle(_ veri: Data) async throws -> String {
        guard let jpeg = FotoServisi.kucult(veri) else { throw BulutHatasi(description: "Görüntü okunamadı") }
        guard let uid else { return FotoServisi.veriUrlu(jpeg) }
        let yol = "\(uid)/\(uid32()).jpg"
        _ = try await istemci.storage.from(FotoServisi.kova)
            .upload(yol, data: jpeg, options: FileOptions(contentType: "image/jpeg", upsert: false))
        if let u = try? await istemci.storage.from(FotoServisi.kova).createSignedURL(path: yol, expiresIn: 3600) {
            onbellek.koy(yol, u, Date().addingTimeInterval(3300))
        }
        return yol
    }

    /// Web `purgePhotos`: `eskiler` içinde olup `kalan` (hâlâ kullanılan) kümede olmayan depo dosyalarını siler.
    func temizle(_ eskiler: [String], kalan: Set<String>) async {
        guard uid != nil else { return }
        var gorulen = Set<String>()
        let olu = eskiler.filter { fotoDepoYoluMu($0) && !kalan.contains($0) && gorulen.insert($0).inserted }
        guard !olu.isEmpty else { return }
        do {
            _ = try await istemci.storage.from(FotoServisi.kova).remove(paths: olu)
            for r in olu { onbellek.sil(r) }
        } catch {
            // web gibi: silinemeyen dosya sonraki temizliğe kalır
        }
    }

    /// Hesap silme / çıkış sonrası: o hesabın tüm klasörünü silmek sunucu tarafında (`hesap-sil`) yapılır; burada yalnız önbellek.
    func onbellekBosalt() { onbellek.bosalt() }

    // MARK: görüntü

    /// En uzun kenarı ≤ 1400 px, JPEG 0.82; EXIF yönü uygulanır.
    nonisolated static func kucult(_ veri: Data) -> Data? {
        guard let g = UIImage(data: veri), g.size.width > 0, g.size.height > 0 else { return nil }
        let oran = min(1, enBuyukKenar / max(g.size.width, g.size.height))
        let boyut = CGSize(width: (g.size.width * oran).rounded(), height: (g.size.height * oran).rounded())
        let bicim = UIGraphicsImageRendererFormat.default()
        bicim.scale = 1
        bicim.opaque = true
        let cikti = UIGraphicsImageRenderer(size: boyut, format: bicim).image { _ in
            g.draw(in: CGRect(origin: .zero, size: boyut))
        }
        return cikti.jpegData(compressionQuality: kalite)
    }

    nonisolated static func veriUrlu(_ jpeg: Data) -> String {
        "data:image/jpeg;base64," + jpeg.base64EncodedString()
    }
}
