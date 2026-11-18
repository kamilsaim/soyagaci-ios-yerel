import SwiftUI

/// Altın çerçeveli, yarı saydam krem giriş kutusu (44 pt).
struct AltinGirisKutusu: View {
    let ipucu: String
    @Binding var metin: String
    var klavye: UIKeyboardType = .default

    var body: some View {
        TextField(ipucu, text: $metin)
            .font(.govde(17))
            .foregroundStyle(Renk.metin)
            .keyboardType(klavye)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Renk.yuzey.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Renk.altin, lineWidth: 1))
    }
}

/// Zümrüt dolgulu birincil düğme.
struct BirincilDugme: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.govde(17, .yariKalin))
            .foregroundStyle(Renk.yuzey)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Renk.vurgu, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Altın çerçeveli ikincil düğme.
struct IkincilDugme: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.govde(17, .yariKalin))
            .foregroundStyle(Renk.vurgu)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Renk.yuzey.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Renk.altin, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension ButtonStyle where Self == BirincilDugme { static var birincil: BirincilDugme { BirincilDugme() } }
extension ButtonStyle where Self == IkincilDugme { static var ikincil: IkincilDugme { IkincilDugme() } }

/// Satır/içerik grubunu taşıyan kart.
struct Kart<Icerik: View>: View {
    var dolgu: CGFloat = 16
    @ViewBuilder var icerik: () -> Icerik

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { icerik() }
            .padding(dolgu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Renk.yuzey, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Renk.cerceve, lineWidth: 1))
            .shadow(color: Renk.golge, radius: 6, y: 2)
    }
}
