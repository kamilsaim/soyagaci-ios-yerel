#!/usr/bin/env python3
"""Web'in değişken woff2 fontlarından iOS için sabit ağırlıklı TTF üretir.
Çalıştır:  python arac/font-donustur.py   (fontTools + brotli gerekir)
Latin + latin-ext alt kümeleri birleştirilir (Türkçe ğ ş ı İ ... ikisinde de dağınık)."""
import io, sys
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools.merge import Merger

KOK = Path(__file__).resolve().parent.parent
KAYNAK = KOK.parent / "assets" / "fonts"
HEDEF = KOK / "SoyAgaci" / "Kaynaklar" / "Fontlar"

# (dosya öneki, aile PostScript adı, görünen aile, {ağırlık adı: wght})
AILELER = [
    ("playfair-display", "PlayfairDisplay", "Playfair Display", {"SemiBold": 600, "Bold": 700}),
    ("source-sans-3", "SourceSans3", "Source Sans 3", {"Regular": 400, "SemiBold": 600, "Bold": 700}),
]

def ornek(yol, wght):
    f = TTFont(str(yol))
    f.flavor = None
    eksenler = {a.axisTag: a for a in f["fvar"].axes}
    sinir = {"wght": max(eksenler["wght"].minValue, min(eksenler["wght"].maxValue, wght))}
    for tag, a in eksenler.items():
        if tag != "wght":
            sinir[tag] = a.defaultValue
    return instancer.instantiateVariableFont(f, sinir)

def adlandir(f, ps_aile, aile, agirlik, wght):
    ps = f"{ps_aile}-{agirlik}"
    n = f["name"]
    for rec in list(n.names):
        if rec.nameID in (1, 2, 3, 4, 6, 16, 17, 21, 22, 25):
            n.removeNames(nameID=rec.nameID)
    kalin = wght >= 700
    for pid, eid, lid in ((3, 1, 0x409), (1, 0, 0)):
        n.setName(f"{aile} {agirlik}", 1, pid, eid, lid) if agirlik != "Regular" else n.setName(aile, 1, pid, eid, lid)
        n.setName("Regular", 2, pid, eid, lid)
        n.setName(ps, 3, pid, eid, lid)
        n.setName(f"{aile} {agirlik}", 4, pid, eid, lid)
        n.setName(ps, 6, pid, eid, lid)
    f["OS/2"].usWeightClass = wght
    f["head"].macStyle = 0
    f["OS/2"].fsSelection = (f["OS/2"].fsSelection & ~0x21) | 0x40  # REGULAR bit, bold/italic yok
    if "STAT" in f: del f["STAT"]
    return ps

def main():
    HEDEF.mkdir(parents=True, exist_ok=True)
    for onek, ps_aile, aile, agirliklar in AILELER:
        for agirlik, wght in agirliklar.items():
            parcalar = []
            for alt in ("latin", "latin-ext"):
                f = ornek(KAYNAK / f"{onek}-{alt}.woff2", wght)
                tmp = io.BytesIO(); f.save(tmp); tmp.seek(0)
                parcalar.append(tmp)
            birlesik = Merger().merge(parcalar)
            ps = adlandir(birlesik, ps_aile, aile, agirlik, wght)
            cikti = HEDEF / f"{ps}.ttf"
            birlesik.save(str(cikti))
            kontrol = TTFont(str(cikti)).getBestCmap()
            eksik = [c for c in "ğĞşŞıİçÇöÖüÜâÂîÎûÛ" if ord(c) not in kontrol]
            print(f"{cikti.name}: {cikti.stat().st_size//1024} KB, eksik Türkçe harf: {eksik or 'yok'}")
            if eksik: sys.exit(1)

if __name__ == "__main__":
    main()
