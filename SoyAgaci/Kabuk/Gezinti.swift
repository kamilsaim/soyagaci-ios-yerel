import SwiftUI

/// Tek `NavigationPath` ile tüm ekranlar. Kimlikler çekirdekteki kişi kimlikleridir ("P12").
enum Rota: Hashable {
    case kisi(String)
    case form(String?)          // nil = yeni kişi
    case ayarlar
    case bilgi
    case akrabalik
    case takvim(Int)            // ay kaydırması
    case mukerrer
    case istatistik
    case harita
    case eksik
    case gedOnizleme
    case edevlet
}

enum Sekme: Hashable { case anaSayfa, agac, kisiler, aktar }

@Observable
final class Gezinti {
    static let ortak = Gezinti()

    var yol = NavigationPath()
    var sekme: Sekme = .anaSayfa
    var eklemeAcik = false

    func git(_ rota: Rota) { yol.append(rota) }
    func basaDon() { yol = NavigationPath() }
}

/// Paylaşım/“Birlikte aç” ile gelen e-Devlet PDF'i. Task 17'deki aktarma ekranı `url`'yi okur, işi bitince `temizle()` der.
@Observable
final class GelenDosya {
    static let ortak = GelenDosya()

    private(set) var url: URL?

    /// Dosya yalnızca bu çağrıda erişilebilir olabilir (Dosyalar/Safari); geçici klasöre kopyalanır.
    @discardableResult
    func al(_ kaynak: URL) -> Bool {
        guard kaynak.isFileURL, kaynak.pathExtension.lowercased() == "pdf" else { return false }
        let erisim = kaynak.startAccessingSecurityScopedResource()
        defer { if erisim { kaynak.stopAccessingSecurityScopedResource() } }
        let klasor = FileManager.default.temporaryDirectory.appendingPathComponent("gelen", isDirectory: true)
        try? FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
        let hedef = klasor.appendingPathComponent(UUID().uuidString + ".pdf")
        do {
            try FileManager.default.copyItem(at: kaynak, to: hedef)
        } catch {
            return false
        }
        temizle()
        url = hedef
        return true
    }

    func temizle() {
        if let url { try? FileManager.default.removeItem(at: url) }
        url = nil
    }
}
