import AuthenticationServices
import SwiftUI

/// Giriş ekranı: Google üstte, Apple altta, "Giriş yapmadan kullan". Kullanıcı girince kök görünüm kendiliğinden `AnaKabuk`'a geçer.
struct Giris: View {
    @Environment(Oturum.self) private var oturum

    var body: some View {
        ZStack {
            Renk.zemin.ignoresSafeArea()
            Image("giris")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)
            LinearGradient(colors: [.clear, Renk.yesil.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 14) {
                    Image("amblem-logo")
                        .resizable().scaledToFit()
                        .frame(width: 96, height: 96)
                        .accessibilityHidden(true)
                    Text("Soy Ağacı")
                        .font(.baslik(30))
                        .foregroundStyle(Renk.metin)
                    Text("Aile ağacınıza erişmek için\nhesabınızla giriş yapın.")
                        .font(.govde(17))
                        .foregroundStyle(Renk.metin2)
                        .multilineTextAlignment(.center)

                    Button {
                        Task { await oturum.googleIleGir() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "g.circle.fill")
                            Text("Google ile Giriş Yap")
                        }
                    }
                    .buttonStyle(.birincil)
                    .padding(.top, 6)

                    SignInWithAppleButton(.signIn) { istek in
                        oturum.appleIstegi(istek)
                    } onCompletion: { sonuc in
                        Task { await oturum.appleTamam(sonuc) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text("Web/Android'de Google ile kullandıysanız Google ile girin.")
                        .font(.govde(13, .regular, .footnote))
                        .foregroundStyle(Renk.metin3)
                        .multilineTextAlignment(.center)

                    if let hata = oturum.hata {
                        Text(hata)
                            .font(.govde(14))
                            .foregroundStyle(Renk.pas)
                            .multilineTextAlignment(.center)
                    }

                    Button("Giriş yapmadan kullan") { oturum.yereldeKullan() }
                        .font(.govde(15, .yariKalin))
                        .foregroundStyle(Renk.metin2)
                        .underline()
                        .frame(minHeight: 44)
                }
                .padding(22)
                .background(Renk.yuzey.opacity(0.94), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Renk.altin, lineWidth: 1))
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .disabled(oturum.mesgul)
            }
        }
    }
}
