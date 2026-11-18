import SwiftUI

// Renkler web v7 `:root` değişkenlerinden (soy-agaci.html, 297. satır). Ekranlarda ham hex kullanılmaz.
// Uygulama yalnız açık tema (Info.plist UIUserInterfaceStyle=Light), web'deki gibi.

private func hex(_ v: UInt32, _ a: Double = 1) -> Color {
    Color(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
          blue: Double(v & 0xFF) / 255, opacity: a)
}

enum Renk {
    static let zemin = hex(0xF1E4C6)      // --bg
    static let yuzey = hex(0xFFFAEE)      // --surface
    static let yuzey2 = hex(0xF7EDD5)     // --surface2
    static let cerceve = hex(0xDCC79A)    // --border
    static let metin = hex(0x1E2A28)      // --text
    static let metin2 = hex(0x5A4E36)     // --text2
    static let metin3 = hex(0x7A6B4C)     // --text3
    static let vurgu = hex(0x1C6B60)      // --accent (zümrüt)
    static let vurgu2 = hex(0x5F8A5A)     // --accent2
    static let vurgu3 = hex(0x3E7F92)     // --accent3
    static let altin = hex(0xC9A24E)      // --accent4 / --gold
    static let yesil = hex(0x0F3D3A)      // --green (koyu)
    static let pas = hex(0x8B3E2F)        // --rust
    static let erkek = hex(0xDCE9E4)      // --male
    static let kadin = hex(0xF2E0D8)      // --female
    static let bilinmeyen = hex(0xE9DFC9) // --unk
    static let golge = hex(0x281E0A, 0.18) // --shadow rgba(40,30,10,.18)
    /// Krem zeminde okunur altın metin (saf `altin` küçük yazıda zayıf kontrast verir).
    static let altinYazi = hex(0x8A6A1F)
}

/// Playfair Display (başlık) + Source Sans 3 (gövde). Dinamik yazı boyutuyla ölçeklenir.
enum Agirlik { case regular, yariKalin, kalin }

extension Font {
    static func baslik(_ boyut: CGFloat, _ a: Agirlik = .kalin, _ stil: Font.TextStyle = .title2) -> Font {
        .custom(a == .kalin ? "PlayfairDisplay-Bold" : "PlayfairDisplay-SemiBold", size: boyut, relativeTo: stil)
    }

    static func govde(_ boyut: CGFloat = 17, _ a: Agirlik = .regular, _ stil: Font.TextStyle = .body) -> Font {
        let ad: String
        switch a {
        case .regular: ad = "SourceSans3-Regular"
        case .yariKalin: ad = "SourceSans3-SemiBold"
        case .kalin: ad = "SourceSans3-Bold"
        }
        return .custom(ad, size: boyut, relativeTo: stil)
    }
}

/// Defter kâğıdı dokusu (ekranların, pencerelerin arka planı).
struct KagitZemin: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            Renk.zemin.overlay(Image("kagit").resizable().scaledToFill()).ignoresSafeArea()
        }
    }
}

/// Parşömen dokusu (giriş, ağaç araç çubuğu gibi süslü yüzeyler).
struct ParsomenZemin: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            Renk.zemin.overlay(Image("parsomen").resizable().scaledToFill()).ignoresSafeArea()
        }
    }
}

extension View {
    func kagitZemin() -> some View { modifier(KagitZemin()) }
    func parsomenZemin() -> some View { modifier(ParsomenZemin()) }
}
