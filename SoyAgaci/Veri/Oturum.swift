import AuthenticationServices
import CryptoKit
import Foundation
import GoogleSignIn
import Supabase
import UIKit

/// Oturum: Supabase Auth (Google yerel / tarayıcı, Apple), yerel mod, çıkış, hesap silme.
/// Kök görünüm `hazir` olana kadar açılış ekranını gösterir; `kullanici == nil && !yerelMod` ise `Giris`.
@MainActor
@Observable
final class Oturum {
    private static let yerelAnahtar = "sa4_yerelmod"

    var kullanici: User?
    /// "Giriş yapmadan kullan" seçildi (cihazda kalıcı; giriş yapılınca / çıkışta sıfırlanır).
    var yerelMod: Bool
    /// İlk `authStateChanges` olayı geldi (kayıtlı oturum okundu).
    var hazir = false
    /// Giriş sürerken true (düğmeleri kilitlemek için).
    var mesgul = false
    /// Kullanıcıya gösterilecek son giriş hatası (Türkçe).
    var hata: String?

    /// Depo bağlar: çıkıştan önce bekleyen kaydı gönderir; false = buluta gitmemiş değişiklik var.
    var cikisHazirlik: (() async -> Bool)?
    /// Depo bağlar: çıkışta yerel bulut kopyasını ve eşitleme izlerini siler.
    var cikisTemizle: ((_ uid: String?) async -> Void)?

    private let istemci = Servis.istemci
    private var dinleyici: Task<Void, Never>?
    private var hamNonce: String?
    private var appleYoneticisi: AppleYoneticisi?

    init() {
        yerelMod = UserDefaults.standard.bool(forKey: Oturum.yerelAnahtar)
        let akis = istemci.auth.authStateChanges
        dinleyici = Task { [weak self] in
            for await (olay, oturum) in akis {
                guard let self else { return }
                self.olayIsle(olay, oturum)
            }
        }
    }

    private func olayIsle(_ olay: AuthChangeEvent, _ oturum: Session?) {
        kullanici = oturum?.user
        if kullanici != nil && yerelMod { yerelModAyarla(false) }
        if olay == .initialSession { hazir = true }
    }

    private func yerelModAyarla(_ v: Bool) {
        yerelMod = v
        UserDefaults.standard.set(v, forKey: Oturum.yerelAnahtar)
    }

    /// Ekranda gösterilecek e-posta; Apple gizli aktarma adresi gizlenir.
    var eposta: String {
        guard let e = kullanici?.email, !e.isEmpty else { return "" }
        return e.lowercased().hasSuffix("privaterelay.appleid.com") ? "Gizli (Apple ile giriş)" : e
    }

    // MARK: Yerel mod

    func yereldeKullan() {
        yerelModAyarla(true)
    }

    // MARK: Google

    func googleIleGir() async {
        guard !mesgul else { return }
        mesgul = true
        hata = nil
        defer { mesgul = false }
        let id = (Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String) ?? ""
        if !id.isEmpty {
            do {
                try await yerelGoogle()
                return
            } catch {
                if Oturum.iptalMi(error) { return }
                // başka hata: tarayıcı girişine düş
            }
        }
        await tarayiciGoogle()
    }

    private func yerelGoogle() async throws {
        guard let vc = Oturum.ustEkran() else { throw BulutHatasi(description: "Ekran bulunamadı") }
        let sonuc = try await GIDSignIn.sharedInstance.signIn(withPresenting: vc)
        guard let idJeton = sonuc.user.idToken?.tokenString else { throw BulutHatasi(description: "Google kimlik jetonu yok") }
        _ = try await istemci.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .google, idToken: idJeton, accessToken: sonuc.user.accessToken.tokenString)
        )
    }

    /// `ASWebAuthenticationSession` (SDK içinde): `com.kamilsaim.soyagaci://auth-callback` → `session(from:)` PKCE.
    private func tarayiciGoogle() async {
        do {
            _ = try await istemci.auth.signInWithOAuth(provider: .google, redirectTo: Servis.donusAdresi)
        } catch {
            if Oturum.iptalMi(error) { return }
            hata = "Giriş başlatılamadı: \(error.localizedDescription)"
        }
    }

    // MARK: Apple

    /// `SignInWithAppleButton(onRequest:)` için: ham nonce üretir, sha256'sını isteğe koyar.
    func appleIstegi(_ istek: ASAuthorizationAppleIDRequest) {
        let ham = Oturum.nonceUret()
        hamNonce = ham
        istek.requestedScopes = [.fullName, .email]
        istek.nonce = Oturum.sha256(ham)
    }

    /// `SignInWithAppleButton(onCompletion:)` için.
    func appleTamam(_ sonuc: Result<ASAuthorization, Error>) async {
        hata = nil
        switch sonuc {
        case .failure(let e):
            if (e as NSError).code == ASAuthorizationError.canceled.rawValue { return }
            hata = "Apple ile giriş başarısız: \(e.localizedDescription)"
        case .success(let yetki):
            guard let kimlik = yetki.credential as? ASAuthorizationAppleIDCredential,
                  let jetonVeri = kimlik.identityToken, let jeton = String(data: jetonVeri, encoding: .utf8),
                  let nonce = hamNonce else {
                hata = "Apple ile giriş başarısız: kimlik jetonu alınamadı"
                return
            }
            mesgul = true
            defer { mesgul = false }
            do {
                _ = try await istemci.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(provider: .apple, idToken: jeton, nonce: nonce)
                )
            } catch {
                hata = "Apple ile giriş başarısız: \(error.localizedDescription)"
                return
            }
            // Hesap silmede Apple yetkisini geri almak için yenileme jetonu: sunucu işlevi (henüz yayında olmayabilir; hata sessiz)
            if let kodVeri = kimlik.authorizationCode, let kod = String(data: kodVeri, encoding: .utf8) {
                do {
                    try await istemci.functions.invoke("apple-jeton", options: FunctionInvokeOptions(body: ["code": kod]))
                } catch {}
            }
        }
    }

    /// Programatik Apple girişi (düğme dışından).
    func appleIleGir() async {
        guard !mesgul else { return }
        let y = AppleYoneticisi()
        appleYoneticisi = y
        let istek = ASAuthorizationAppleIDProvider().createRequest()
        appleIstegi(istek)
        let sonuc = await y.calistir(istek)
        appleYoneticisi = nil
        await appleTamam(sonuc)
    }

    // MARK: Çıkış / hesap silme

    /// Web `signOut`: bekleyeni gönderir; buluta gitmemiş değişiklik varsa `false` döner ve ÇIKMAZ
    /// (UI sorar: "Bazı değişiklikler henüz buluta kaydedilemedi…"; evet → `cikis(zorla: true)`).
    func cikis(zorla: Bool = false) async -> Bool {
        if !zorla, let hazirlik = cikisHazirlik, !(await hazirlik()) { return false }
        await cikisTemizle?(kullanici?.id.uuidString.lowercased())
        try? await istemci.auth.signOut()
        GIDSignIn.sharedInstance.signOut()
        kullanici = nil
        yerelModAyarla(false)
        return true
    }

    /// Edge Function `hesap-sil` (Task 19'da yayınlanır; yoksa hata fırlatılır). Başarılıysa yerel veriler silinir ve oturum kapanır.
    func hesabiSil() async throws {
        try await istemci.functions.invoke("hesap-sil")
        await cikisTemizle?(kullanici?.id.uuidString.lowercased())
        try? await istemci.auth.signOut(scope: .local)
        GIDSignIn.sharedInstance.signOut()
        kullanici = nil
        yerelModAyarla(false)
    }

    // MARK: yardımcılar

    nonisolated static func iptalMi(_ e: Error) -> Bool {
        if e is CancellationError { return true }
        let n = e as NSError
        if n.domain == kGIDSignInErrorDomain && n.code == GIDSignInError.canceled.rawValue { return true }
        if n.domain == ASWebAuthenticationSessionError.errorDomain && n.code == ASWebAuthenticationSessionError.canceledLogin.rawValue { return true }
        return false
    }

    static func ustEkran() -> UIViewController? {
        let sahneler = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let sahne = sahneler.first(where: { $0.activationState == .foregroundActive }) ?? sahneler.first
        var vc = sahne?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let ust = vc?.presentedViewController { vc = ust }
        return vc
    }

    nonisolated static func nonceUret(_ uzunluk: Int = 32) -> String {
        let harfler = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var sonuc = ""
        var g = SystemRandomNumberGenerator()
        for _ in 0..<uzunluk { sonuc.append(harfler[Int(g.next() % UInt64(harfler.count))]) }
        return sonuc
    }

    nonisolated static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// `ASAuthorizationController` için devam (continuation) sarmalayıcısı.
@MainActor
final class AppleYoneticisi: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var devam: CheckedContinuation<Result<ASAuthorization, Error>, Never>?
    private var denetleyici: ASAuthorizationController?

    func calistir(_ istek: ASAuthorizationAppleIDRequest) async -> Result<ASAuthorization, Error> {
        await withCheckedContinuation { (c: CheckedContinuation<Result<ASAuthorization, Error>, Never>) in
            devam = c
            let d = ASAuthorizationController(authorizationRequests: [istek])
            d.delegate = self
            d.presentationContextProvider = self
            denetleyici = d
            d.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        devam?.resume(returning: .success(authorization))
        devam = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        devam?.resume(returning: .failure(error))
        devam = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        Oturum.ustEkran()?.view.window ?? ASPresentationAnchor()
    }
}
