import Foundation
import Supabase

/// Supabase istemcisi (tek örnek). URL ve anon anahtarı herkese açıktır (web uygulamasında da gömülü);
/// veriyi koruyan RLS politikalarıdır.
enum Servis {
    static let url = URL(string: "https://mtialokiudmgdctznfiz.supabase.co")!
    private static let anahtar = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im10aWFsb2tpdWRtZ2RjdHpuZml6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwODE5NjgsImV4cCI6MjA5NDY1Nzk2OH0.aznQX7ZiwO031n-xjDFr1bGTzgakoaOBWkGu7wps120"

    /// Tarayıcı girişi dönüş adresi (Info.plist'te `com.kamilsaim.soyagaci` şeması kayıtlı).
    static let donusAdresi = URL(string: "com.kamilsaim.soyagaci://auth-callback")!

    static let istemci = SupabaseClient(
        supabaseURL: url,
        supabaseKey: anahtar,
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(redirectToURL: donusAdresi, flowType: .pkce)
        )
    )
}
