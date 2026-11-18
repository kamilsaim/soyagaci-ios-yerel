import SwiftUI

/// Uygulama kabuğu: üstte ⚙ Ayarlar / ☰ Bilgi, altta özel çubuk (Ana Sayfa · Ağaç · ＋ · Kişiler · Aktar).
/// NavigationStack dışta olduğu için itilen ekranlar çubuğu kaplar (web'deki tam ekran kartlar gibi).
struct AnaKabuk: View {
    @Environment(Gezinti.self) private var gezinti

    var body: some View {
        @Bindable var g = gezinti
        NavigationStack(path: $g.yol) {
            VStack(spacing: 0) {
                TabView(selection: $g.sekme) {
                    YerTutucu(baslik: "Ana Sayfa").tag(Sekme.anaSayfa)
                    YerTutucu(baslik: "Ağaç").tag(Sekme.agac)
                    YerTutucu(baslik: "Kişiler").tag(Sekme.kisiler)
                    YerTutucu(baslik: "Aktar").tag(Sekme.aktar)
                }
                .toolbar(.hidden, for: .tabBar)
                AltCubuk()
            }
            .background(Renk.zemin.ignoresSafeArea())
            .navigationTitle("Soy Ağacı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { gezinti.git(.bilgi) } label: { Image(systemName: "line.3.horizontal") }
                        .accessibilityLabel("Bilgi")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { gezinti.git(.ayarlar) } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Ayarlar")
                }
            }
            .navigationDestination(for: Rota.self) { RotaEkrani(rota: $0) }
        }
        .sheet(isPresented: $g.eklemeAcik) {
            YerTutucu(baslik: "Ekle")
                .presentationDetents([.medium])
        }
    }
}

private struct AltCubuk: View {
    @Environment(Gezinti.self) private var gezinti

    var body: some View {
        HStack(spacing: 0) {
            oge(.anaSayfa, "Ana Sayfa", "nav-anasayfa")
            oge(.agac, "Ağaç", "nav-agac")
            Button { gezinti.eklemeAcik = true } label: {
                Image("arti").resizable().scaledToFit().frame(width: 52, height: 52)
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Ekle")
            oge(.kisiler, "Kişiler", "nav-kisiler")
            oge(.aktar, "Aktar", "nav-aktar")
        }
        .padding(.top, 6).padding(.bottom, 2)
        .background(Renk.yuzey.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Renk.cerceve).frame(height: 1) }
    }

    private func oge(_ s: Sekme, _ ad: String, _ ikon: String) -> some View {
        let secili = gezinti.sekme == s
        return Button { gezinti.sekme = s } label: {
            VStack(spacing: 2) {
                Image(secili ? "ikon-\(ikon)-altin" : "ikon-\(ikon)")
                    .resizable().scaledToFit().frame(width: 28, height: 28)
                Text(ad).font(.govde(11, .yariKalin, .caption2))
                    .foregroundStyle(secili ? Renk.altinYazi : Renk.metin2)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .accessibilityAddTraits(secili ? .isSelected : [])
    }
}

/// Henüz yazılmamış ekranlar için (Task 14+ doldurur).
struct YerTutucu: View {
    let baslik: String
    var body: some View {
        Text(baslik)
            .font(.baslik(24))
            .foregroundStyle(Renk.metin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .kagitZemin()
    }
}

struct RotaEkrani: View {
    let rota: Rota
    var body: some View {
        switch rota {
        case .kisi(let id): YerTutucu(baslik: "Kişi \(id)")
        case .form(let id): YerTutucu(baslik: id == nil ? "Yeni kişi" : "Kişiyi düzenle")
        case .ayarlar: YerTutucu(baslik: "Ayarlar")
        case .bilgi: YerTutucu(baslik: "Bilgi")
        case .akrabalik: YerTutucu(baslik: "Akrabalık")
        case .takvim: YerTutucu(baslik: "Takvim")
        case .mukerrer: YerTutucu(baslik: "Mükerrer kişiler")
        case .istatistik: YerTutucu(baslik: "İstatistik")
        case .harita: YerTutucu(baslik: "Harita")
        case .eksik: YerTutucu(baslik: "Eksik bilgiler")
        case .gedOnizleme: YerTutucu(baslik: "GED önizleme")
        case .edevlet: YerTutucu(baslik: "e-Devlet'ten aktar")
        }
    }
}
