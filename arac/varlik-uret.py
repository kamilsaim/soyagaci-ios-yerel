#!/usr/bin/env python3
"""Web varlıklarından Assets.xcassets üretir (AppIcon, Acilis, Zemin, görseller).
Çalıştır:  python arac/varlik-uret.py   (Pillow gerekir). Çıktılar depoya işlenir."""
import json
from collections import deque
from pathlib import Path
from PIL import Image

KOK = Path(__file__).resolve().parent.parent
WEB = KOK.parent
XC = KOK / "SoyAgaci" / "Assets.xcassets"
BILGI = {"author": "xcode", "version": 1}
ZEMIN = (0xF1, 0xE4, 0xC6)  # web --bg

def yaz(yol, veri):
    yol.parent.mkdir(parents=True, exist_ok=True)
    yol.write_text(json.dumps(veri, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

def imageset(ad, goruntu, dosya, ucx=True, **kayit):
    d = XC / f"{ad}.imageset"
    d.mkdir(parents=True, exist_ok=True)
    goruntu.save(d / dosya, optimize=True)
    girdi = {"filename": dosya, "idiom": "universal"}
    if ucx: girdi["scale"] = "3x"
    yaz(d / "Contents.json", {"images": [girdi], "info": BILGI})

def appicon():
    """Amblemin köşeleri siyah (yuvarlak köşeli PNG). Köşe siyahını çerçevenin altınıyla doldur,
    sonra 1024'e küçült, alfa kanalı olmasın (App Store şartı)."""
    kaynak = Image.open(WEB / "yenilogo" / "Türk Soy Ağacı Amblemi.png").convert("RGB")
    w, h = kaynak.size
    px = kaynak.load()
    altin = px[w // 2, 12]  # üst kenar ortasındaki çerçeve altını
    karanlik = lambda c: c[0] < 40 and c[1] < 40 and c[2] < 40
    gorulen = bytearray(w * h)
    kuyruk = deque()
    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        kuyruk.append((x, y)); gorulen[y * w + x] = 1
    while kuyruk:  # yalnız köşelerden ulaşılabilen siyah bölge
        x, y = kuyruk.popleft()
        if not karanlik(px[x, y]): continue
        px[x, y] = altin
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not gorulen[ny * w + nx]:
                gorulen[ny * w + nx] = 1; kuyruk.append((nx, ny))
    ikon = kaynak.resize((1024, 1024), Image.LANCZOS)
    d = XC / "AppIcon.appiconset"
    d.mkdir(parents=True, exist_ok=True)
    ikon.save(d / "ikon-1024.png", optimize=True)
    yaz(d / "Contents.json", {"images": [{"filename": "ikon-1024.png", "idiom": "universal",
        "platform": "ios", "size": "1024x1024"}], "info": BILGI})

def renk(ad, r, g, b):
    yaz(XC / f"{ad}.colorset" / "Contents.json", {"colors": [{"idiom": "universal", "color": {
        "color-space": "srgb", "components": {"alpha": "1.000", "red": f"0x{r:02X}",
        "green": f"0x{g:02X}", "blue": f"0x{b:02X}"}}}], "info": BILGI})

def main():
    XC.mkdir(parents=True, exist_ok=True)
    yaz(XC / "Contents.json", {"info": BILGI})
    appicon()
    renk("Zemin", *ZEMIN)
    # Açılış görseli: giriş ekranındaki amblem (360 px, 3x -> 120 pt)
    amb = Image.open(WEB / "assets" / "amblem-logo.webp").convert("RGBA")
    imageset("Acilis", amb, "acilis.png")
    imageset("amblem-logo", amb, "amblem-logo.png")
    # Arka planlar
    for ad in ("kagit", "parsomen", "giris"):
        imageset(ad, Image.open(WEB / "assets" / f"{ad}.jpg").convert("RGB"), f"{ad}.jpg")
    imageset("kisi-kart", Image.open(WEB / "assets" / "kisi-kart.webp").convert("RGBA"), "kisi-kart.png")
    imageset("arti", Image.open(WEB / "assets" / "arti.png").convert("RGBA"), "arti.png")
    # ikon/*.png -> "ikon-<ad>"
    n = 0
    for f in sorted((WEB / "assets" / "ikon").glob("*.png")):
        imageset(f"ikon-{f.stem}", Image.open(f).convert("RGBA"), f.name); n += 1
    print(f"{n} ikon + AppIcon + Acilis + Zemin + 6 görsel üretildi -> {XC}")

if __name__ == "__main__":
    main()
