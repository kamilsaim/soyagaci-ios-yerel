import GoogleSignIn
import SwiftUI
import SoyCekirdek

/// Oturum okunurken (ilk `authStateChanges` olayına kadar) gösterilen açılış zemini.
struct Acilis: View {
    var body: some View {
        ZStack {
            Renk.zemin.ignoresSafeArea()
            Image("Acilis").resizable().scaledToFit().padding(40)
        }
    }
}

@main
struct SoyAgaciApp: App {
    @State private var gezinti = Gezinti.ortak
    @State private var gelen = GelenDosya.ortak
    @State private var oturum: Oturum
    @State private var depo: Depo

    init() {
        let o = Oturum()
        _oturum = State(initialValue: o)
        _depo = State(initialValue: Depo(oturum: o))
    }

    /// Kullanıcı ya da mod değişince değişir; `.task(id:)` verinin yeniden yüklenmesini buna bağlar.
    private var veriAnahtari: String {
        if !oturum.hazir { return "" }
        if let k = oturum.kullanici { return "u:" + k.id.uuidString.lowercased() }
        return oturum.yerelMod ? "yerel" : "yok"
    }

    private func veriyiYukle() async {
        let a = veriAnahtari
        if a.hasPrefix("u:") {
            await depo.yukle(uid: String(a.dropFirst(2)))
        } else if a == "yerel" {
            await depo.yukle(uid: nil)
        } else if a == "yok" {
            await depo.bosalt()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !oturum.hazir {
                    Acilis()
                } else if oturum.kullanici == nil && !oturum.yerelMod {
                    Giris()
                } else {
                    AnaKabuk()
                }
            }
                .environment(gezinti)
                .environment(gelen)
                .environment(oturum)
                .environment(depo)
                .tint(Renk.vurgu)
                .task(id: veriAnahtari) { await veriyiYukle() }
                .alert("Başka cihazla çakışma", isPresented: Binding(
                    get: { depo.cakisma != nil },
                    set: { if !$0 { depo.cakisma = nil } }
                )) {
                    Button("Üzerine yaz", role: .destructive) { Task { await depo.cakismayiCoz(uzerineYaz: true) } }
                    Button("Buluttakini yükle", role: .cancel) { Task { await depo.cakismayiCoz(uzerineYaz: false) } }
                } message: {
                    Text("Bu ağaç başka bir cihazdan güncellenmiş. Buradaki \(depo.agac.people.sayisi) kişilik sürüm bulutun üzerine yazılsın mı?")
                }
                .onOpenURL { url in
                    if url.isFileURL {
                        // e-Devlet PDF'i: Paylaş → Soy Ağacı
                        if gelen.al(url) {
                            gezinti.eklemeAcik = false
                            gezinti.basaDon()
                            gezinti.git(.edevlet)
                        }
                    } else if url.scheme == Servis.donusAdresi.scheme {
                        Servis.istemci.auth.handle(url) // tarayıcı girişi dönüşü (PKCE)
                    } else {
                        _ = GIDSignIn.sharedInstance.handle(url) // Google yerel giriş dönüşü
                    }
                }
        }
    }
}
