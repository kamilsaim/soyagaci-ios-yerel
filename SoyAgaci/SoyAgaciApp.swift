import GoogleSignIn
import SwiftUI
import SoyCekirdek

@main
struct SoyAgaciApp: App {
    @State private var gezinti = Gezinti.ortak
    @State private var gelen = GelenDosya.ortak

    var body: some Scene {
        WindowGroup {
            AnaKabuk()
                .environment(gezinti)
                .environment(gelen)
                .tint(Renk.vurgu)
                .onOpenURL { url in
                    if url.isFileURL {
                        // e-Devlet PDF'i: Paylaş → Soy Ağacı
                        if gelen.al(url) {
                            gezinti.eklemeAcik = false
                            gezinti.basaDon()
                            gezinti.git(.edevlet)
                        }
                    } else {
                        _ = GIDSignIn.sharedInstance.handle(url) // Google yerel giriş dönüşü
                    }
                }
        }
    }
}
