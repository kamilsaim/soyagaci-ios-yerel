# Soy Ağacı iOS — yerel SwiftUI uygulaması

Web uygulamasının (`soy-agaci.html`) yerel iPhone karşılığı. Aynı Supabase tablolarını (`soy_family_data`, `soy_node_positions`) kullanır.

- Gizli depo: `kamilsaim/soyagaci-ios-yerel` · bundle `com.kamilsaim.soyagaci`
- Web sürümü esas alınan: 7.0.0

## Yapı
- `Paketler/SoyCekirdek` — yalnız Foundation çekirdeği; Linux CI'da `swift test` (her push, main).
- `docs/superpowers/` — plan ve tasarım belgeleri.

## Komutlar
```
cd Paketler/SoyCekirdek && swift test     # Mac/Linux'ta
gh run list -R kamilsaim/soyagaci-ios-yerel
gh run watch <id> --exit-status
```
Yerelde Swift kurulu değilse testler yalnız GitHub Actions'ta çalışır.

## Fixture üreticisi
Web'in JS'i Node'da çalıştırılıp eşlik (parity) fixture'ları üretilir. Saat dilimi UTC şart:
```
TZ=UTC node arac/fixture-uret.mjs duman     # duman testi (fixture yazmaz)
TZ=UTC node arac/fixture-uret.mjs <modül>   # arac/fixture/<modül>.mjs → Paketler/SoyCekirdek/Tests/SoyCekirdekTests/fixtures/<modül>.json
```
