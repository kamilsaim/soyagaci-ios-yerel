#!/usr/bin/env bash
# Soy Ağacı iOS (yerel) — depoyu (yoksa) kurar, kodu iter, 5 secret'ı yükler.
# Değerler ekrana basılmaz. Çalıştır:  ! bash "E:/ksaim/claude programlar/soyagaci/ios-yerel/arac/github-kur.sh"
set -e
cd "$(dirname "$0")/.."
DEPO="kamilsaim/soyagaci-ios-yerel"
SERT="/c/apk/apple-anahtar/dagitim-sertifikasi"
P8="/c/apk/apple-anahtar/asc-api/AuthKey_GTQ97LCA87.p8"

if ! gh repo view "$DEPO" >/dev/null 2>&1; then
  gh repo create "$DEPO" --private --source=. --remote=origin
fi
git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$DEPO.git"
git push -u origin main

printf '%s' "GTQ97LCA87" | gh secret set ASC_KEY_ID -R "$DEPO"
printf '%s' "6a682700-506a-456d-9768-f18908898acd" | gh secret set ASC_ISSUER_ID -R "$DEPO"
base64 -w0 "$P8" | gh secret set ASC_KEY_P8_BASE64 -R "$DEPO"
gh secret set DIST_CERT_P12_BASE64 -R "$DEPO" < "$SERT/GITHUB-DIST_CERT_P12_BASE64.txt"
gh secret set DIST_CERT_PASSWORD -R "$DEPO" < "$SERT/GITHUB-DIST_CERT_PASSWORD.txt"
gh secret list -R "$DEPO"
echo "TAMAM: depo ve secret'lar hazır."
