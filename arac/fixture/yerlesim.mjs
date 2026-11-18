// Yerlesim fixture'i: buildFamilies, layoutFull, layoutFocus, defaultFocus, lineageOf, normDrag (web l.2023-2290, ~2599).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const veriDizini = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'veri');
const J = (x) => JSON.stringify(x);

function mulberry32(tohum) {
  let a = tohum >>> 0;
  return () => {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const K = (id, ad, soyad, g, o = {}) => ({
  id, firstName: ad, lastName: soyad, gender: g, birthDate: '', birthPlace: '', deathDate: '', deathPlace: '',
  occupation: '', notes: '', photo: null, gallery: [], mother: null, father: null, spouse: null, spouses: [], children: [], ...o,
});

function kur() {
  const p = {};
  let n = 0;
  const yeni = (ad, g, yil, o = {}) => {
    n += 1;
    const id = 'P' + n;
    p[id] = K(id, ad, 'Soy', g, { birthDate: yil ? String(yil) : '', ...o });
    return id;
  };
  const evlen = (a, b, durum = 'married') => {
    p[a].spouses.push({ id: b, status: durum });
    p[b].spouses.push({ id: a, status: durum });
    if (!p[a].spouse) p[a].spouse = b;
    if (!p[b].spouse) p[b].spouse = a;
  };
  const cocuk = (baba, anne, c) => {
    if (baba) { p[c].father = baba; p[baba].children.push(c); }
    if (anne) { p[c].mother = anne; p[anne].children.push(c); }
  };
  return { p, yeni, evlen, cocuk };
}

// Coklu es, yeniden evlilik, iki evliligin cocuklari
function elleCokEs() {
  const { p, yeni, evlen, cocuk } = kur();
  const ib = yeni('Ibrahim', 'M', 1900);
  const a = yeni('Hatice', 'F', 1905); const b = yeni('Zehra', 'F', 1910); const c = yeni('Meryem', 'F', 1915);
  evlen(ib, a); evlen(ib, b, 'widowed'); evlen(ib, c, 'divorced');
  const a1 = yeni('Ali', 'M', 1925); const a2 = yeni('Veli', 'M', 1928);
  const b1 = yeni('Aysel', 'F', 1935); const b2 = yeni('Songul', 'F', 1938); const b3 = yeni('Hakan', 'M', 1940);
  const c1 = yeni('Cem', 'M', 1950);
  [a1, a2].forEach((k) => cocuk(ib, a, k));
  [b1, b2, b3].forEach((k) => cocuk(ib, b, k));
  cocuk(ib, c, c1);
  // yeniden evlenen kadin: iki evlilikten cocuklar
  const w = yeni('Nuray', 'F', 1960); const m1 = yeni('Orhan', 'M', 1955); const m2 = yeni('Sinan', 'M', 1958);
  evlen(w, m1, 'divorced'); evlen(w, m2);
  const k1 = yeni('Ece', 'F', 1985); const k2 = yeni('Efe', 'M', 1988); const k3 = yeni('Mina', 'F', 1995);
  cocuk(m1, w, k1); cocuk(m1, w, k2); cocuk(m2, w, k3);
  evlen(a1, w);
  const e = yeni('Elif', 'F', 1962); evlen(m2, e);
  const k4 = yeni('Kaan', 'M', 1996); cocuk(m2, e, k4);
  const s1 = yeni('Selin', 'F', 1955); evlen(a2, s1);
  const t1 = yeni('Tuna', 'M', 1980); const t2 = yeni('Tulin', 'F', 1982);
  cocuk(a2, s1, t1); cocuk(a2, s1, t2);
  const t3 = yeni('Tarik', 'M', 2010); cocuk(t1, null, t3);
  return p;
}

// Tek ebeveyn, kardesler (yilli / yilsiz), bagsizlar
function elleTekEbeveyn() {
  const { p, yeni, evlen, cocuk } = kur();
  const an = yeni('Anne', 'F', 1950);
  const k1 = yeni('Birinci', 'M', 1975); const k2 = yeni('Ikinci', 'F', 0); const k3 = yeni('Ucuncu', 'M', 1980); const k4 = yeni('Dorduncu', 'F', 0);
  [k1, k2, k3, k4].forEach((k) => cocuk(null, an, k));
  const t1 = yeni('Torun1', 'M', 2000); const t2 = yeni('Torun2', 'F', 1999);
  cocuk(k1, null, t1); cocuk(k3, null, t2);
  const ba = yeni('Baba', 'M', 1940);
  const c1 = yeni('Cocuk1', 'F', 1970); const c2 = yeni('Cocuk2', 'M', 1970); const c3 = yeni('Cocuk3', 'F', 0);
  [c1, c2, c3].forEach((k) => cocuk(ba, null, k));
  const es = yeni('Es', 'M', 1972); evlen(c1, es);
  yeni('Yalniz', 'F', 1961);
  const cift = yeni('CiftA', 'M', 1990); const cift2 = yeni('CiftB', 'F', 1991); evlen(cift, cift2, 'partner');
  return p;
}

// Gelin / damat aileleri: occ carpisma aramasi, es-yayilmasi, ayri ayri koklu aileler
function elleGelin() {
  const { p, yeni, evlen, cocuk } = kur();
  const dede = yeni('Dede', 'M', 1920); const nine = yeni('Nine', 'F', 1925);
  evlen(dede, nine);
  const kids = [];
  for (let i = 0; i < 5; i++) { const k = yeni('A' + i, i % 2 ? 'F' : 'M', 1945 + i * 2); cocuk(dede, nine, k); kids.push(k); }
  const torunlar = [];
  kids.forEach((k, i) => {
    const e = yeni('AEs' + i, p[k].gender === 'M' ? 'F' : 'M', 1946 + i * 2);
    evlen(k, e);
    for (let j = 0; j < 2 + (i % 2); j++) {
      const t = yeni('AT' + i + j, j % 2 ? 'F' : 'M', 1970 + i * 3 + j);
      if (p[k].gender === 'M') cocuk(k, e, t); else cocuk(e, k, t);
      torunlar.push(t);
    }
  });
  // B ailesi (gelinin ailesi): kendi dede/nine'si ve kardesleri
  const bd = yeni('BDede', 'M', 1925); const bn = yeni('BNine', 'F', 1928); evlen(bd, bn);
  const gelin = yeni('Gelin', 'F', 1972); cocuk(bd, bn, gelin);
  const gk1 = yeni('GKardes1', 'M', 1975); const gk2 = yeni('GKardes2', 'F', 1978); cocuk(bd, bn, gk1); cocuk(bd, bn, gk2);
  evlen(torunlar[0], gelin);
  const gt = yeni('GelinCocuk', 'M', 2000); cocuk(torunlar[0], gelin, gt);
  // C ailesi: damat
  const cd = yeni('CDede', 'M', 1930); const cn = yeni('CNine', 'F', 1932); evlen(cd, cn);
  const damat = yeni('Damat', 'M', 1970); cocuk(cd, cn, damat);
  const ck = yeni('CKiz', 'F', 1973); cocuk(cd, cn, ck);
  evlen(torunlar[3], damat);
  evlen(ck, gk1);
  const cc = yeni('CCocuk', 'F', 2003); cocuk(gk1, ck, cc);
  // tamamen ayri aile (xs bos -> sag kenar)
  const zd = yeni('ZDede', 'M', 1940); const zn = yeni('ZNine', 'F', 1942); evlen(zd, zn);
  const z1 = yeni('Z1', 'M', 1965); cocuk(zd, zn, z1);
  const z2 = yeni('Z2', 'F', 1968); cocuk(zd, zn, z2);
  const z3 = yeni('Z3', 'M', 1990); cocuk(z1, null, z3);
  yeni('Yalniz', 'M', 1977);
  void z2; void z3; void gt; void cc;
  return p;
}

// Rastgele buyuk agac: coklu evlilik, gelin/damat, yilsiz kisiler, tek ebeveyn
function rastgele(tohum, hedef) {
  const rng = mulberry32(tohum);
  const { p, yeni, evlen, cocuk } = kur();
  const r = (n) => Math.floor(rng() * n);
  const cift = [];
  for (let i = 0; i < 4; i++) {
    const m = yeni('Kok' + i, 'M', 1900 + r(10)); const f = yeni('Kok' + i + 'k', 'F', 1903 + r(10));
    evlen(m, f); cift.push([m, f, 0]);
  }
  const nesil = [[...cift]];
  for (let g = 1; g < 6 && Object.keys(p).length < hedef; g++) {
    const yeniCift = [];
    for (const [m, f] of nesil[g - 1]) {
      const adet = r(4) + (rng() < 0.2 ? 1 : 0);
      for (let i = 0; i < adet; i++) {
        const cin = rng() < 0.5 ? 'M' : 'F';
        const yilK = rng() < 0.15 ? 0 : 1900 + g * 25 + r(15);
        const k = yeni((cin === 'M' ? 'E' : 'K') + g + '_' + Object.keys(p).length, cin, yilK);
        if (rng() < 0.1) cocuk(m, null, k); else cocuk(m, f, k);
        if (rng() < 0.7) {
          const e = yeni('Es' + Object.keys(p).length, cin === 'M' ? 'F' : 'M', yilK ? yilK + r(6) : 0);
          evlen(k, e, rng() < 0.2 ? 'divorced' : 'married');
          yeniCift.push([cin === 'M' ? k : e, cin === 'M' ? e : k]);
          if (rng() < 0.25) {
            const e2 = yeni('YeniEs' + Object.keys(p).length, cin === 'M' ? 'F' : 'M', yilK ? yilK + 3 : 0);
            evlen(k, e2); yeniCift.push([cin === 'M' ? k : e2, cin === 'M' ? e2 : k]);
          }
        }
      }
    }
    // farkli ailelerden evlilik (es-yayilmasi)
    const adaylar = Object.values(p).filter((x) => !x.spouses.length && x.father && x.birthDate);
    for (let i = 0; i + 1 < adaylar.length && i < 6; i += 2) {
      const x = adaylar[i]; const y = adaylar[i + 1];
      if (x.gender !== y.gender && x.father !== y.father) { evlen(x.id, y.id); yeniCift.push([x.gender === 'M' ? x.id : y.id, x.gender === 'M' ? y.id : x.id]); }
    }
    nesil.push(yeniCift);
  }
  return p;
}

// Ham (migrateData uygulanmamis): cinsiyet alani eksik / bos / null, dongu, eksik referans
function elleHam() {
  const p = {};
  const ekle = (id, g, yil, o = {}) => {
    const k = { id, firstName: id, birthDate: yil, children: [], spouses: [], ...o };
    if (g !== undefined) k.gender = g;
    p[id] = k;
  };
  ekle('P1', 'M', '1940'); ekle('P2', 'F', '1942');
  ekle('P3', undefined, '1965', { father: 'P1' }); // cinsiyet alani yok
  ekle('P5', undefined, '1966', { father: 'P1' });
  ekle('P7', '', '1967', { father: 'P1' });
  ekle('P10', 'M', '1990', { father: 'P5', mother: 'P7' }); // biri yok, biri '': ayni degil -> sira degismez
  ekle('P11', 'M', '1991', { father: 'P7', mother: 'P5' });
  ekle('P12', undefined, '1992', { father: 'P5', mother: 'P3' }); // iki "alan yok": id'ye gore sirala
  ekle('P13', undefined, '1993', { father: 'P5', mother: 'P3' });
  ekle('P14', null, '1994', { father: 'P5', mother: 'P3' }); // null != undefined
  ekle('P17', null, '1995', { father: 'P3', mother: 'P17x' });
  ekle('P18', null, '1950', { father: 'P17' });
  ekle('P15', 'M', '1950', { father: 'P16' }); ekle('P16', 'M', '1950', { father: 'P15' }); // dongu
  ekle('P20', 'F', '1980', { father: 'P99', mother: 'P2' }); // olmayan baba
  p.P2.children.push('P20', 'P3');
  return p;
}

export default function uret(webYukle) {
  const yedek = JSON.parse(fs.readFileSync(path.join(veriDizini, 'soy-agaci.json'), 'utf8'));
  const heritage = fs.readFileSync(path.join(veriDizini, 'heritage.ged'), 'utf8');

  const taze = () => {
    const w = webYukle();
    if (w.baslatmaHatasi) throw new Error('baslatma hatasi: ' + w.baslatmaHatasi.message);
    w.calistir('save=function(){}; saveLayout=function(){}; renderAll=function(){}; buildTree=function(){}; toast=function(){}; cModal=function(){};');
    return w;
  };
  const kurW = (people, nextId, migrate = true) => {
    const w = taze();
    w.ayarla(JSON.parse(J(people)), nextId);
    if (migrate) w.calistir('migrateData()');
    return w;
  };
  const goruntu = (w) => JSON.parse(w.calistir('JSON.stringify({people:people,nextId:nextId})'));

  const agaclar = {};
  const migrateYok = new Set(['ham']);
  agaclar.soy = goruntu(kurW(yedek.people, yedek.nextId));
  {
    const w = taze();
    w.ctx.__t = heritage;
    w.calistir('parseGED(__t,false)');
    agaclar.heritage = goruntu(w);
  }
  agaclar.cokes = goruntu(kurW(elleCokEs(), 100));
  agaclar.tekebeveyn = goruntu(kurW(elleTekEbeveyn(), 100));
  agaclar.gelin = goruntu(kurW(elleGelin(), 200));
  agaclar.rastgele1 = goruntu(kurW(rastgele(7, 90), 500));
  agaclar.rastgele2 = goruntu(kurW(rastgele(2026, 120), 500));
  agaclar.bos = { people: {}, nextId: 1 };
  agaclar.tek = goruntu(kurW({ P1: K('P1', 'Tek', 'Kisi', 'M', { birthDate: '1980' }) }, 2));
  agaclar.ham = goruntu(kurW(elleHam(), 100, false));

  const vakalar = [];
  for (const ad of Object.keys(agaclar)) vakalar.push({ ad: 'agac ' + ad, girdi: { tur: 'agac', agac: ad }, beklenen: agaclar[ad] });

  const toplam = {};
  for (const ad of Object.keys(agaclar)) {
    const w = kurW(agaclar[ad].people, agaclar[ad].nextId, !migrateYok.has(ad));
    w.calistir('buildFamilies();');
    const aile = JSON.parse(w.calistir(`JSON.stringify({
      aileler:Object.values(famMap),
      famOf:Object.fromEntries(Object.entries(famOf).map(([k,v])=>[k,v.map(F=>F.key)])),
      parentFam:Object.fromEntries(Object.entries(parentFam).map(([k,v])=>[k,v.key]))})`));
    vakalar.push({ ad: 'aileler ' + ad, girdi: { tur: 'aileler', agac: ad }, beklenen: aile });

    const tum = JSON.parse(w.calistir(`(()=>{nodePos={};nodeRow={};layoutFull();
      return JSON.stringify(Object.keys(nodePos).map(id=>id+'|'+nodePos[id].x+'|'+nodePos[id].y+'|'+nodeRow[id]));})()`));
    vakalar.push({ ad: 'tum ' + ad, girdi: { tur: 'tum', agac: ad }, beklenen: { dugumler: tum } });

    const varsayilan = JSON.parse(w.calistir('JSON.stringify(defaultFocus())'));
    vakalar.push({ ad: 'varsayilan ' + ad, girdi: { tur: 'varsayilan', agac: ad }, beklenen: { id: varsayilan } });

    for (const [u, d] of [[3, 2], [1, 1], [5, 4]]) {
      const odak = JSON.parse(w.calistir(`(()=>{upGen=${u};downGen=${d};const out={};
        Object.keys(people).forEach(id=>{nodePos={};nodeRow={};layoutFocus(id);
          out[id]=Object.keys(nodePos).map(k=>k+'|'+nodePos[k].x+'|'+nodePos[k].y+'|'+nodeRow[k]);});
        return JSON.stringify(out);})()`));
      toplam[ad] = (toplam[ad] || 0) + Object.keys(odak).length;
      vakalar.push({ ad: `odak ${ad} ${u}/${d}`, girdi: { tur: 'odak', agac: ad, up: u, down: d }, beklenen: odak });
    }

    const ids = Object.keys(agaclar[ad].people);
    const adim = Math.max(1, Math.floor(ids.length / 20));
    const secilen = ids.filter((_, i) => i % adim === 0).slice(0, 20);
    secilen.push('P99999', '');
    w.ctx.__ids = secilen;
    const soy = JSON.parse(w.calistir('JSON.stringify(__ids.map(id=>{const s=lineageOf(id);return s?[...s].sort():null;}))'));
    secilen.forEach((id, i) => vakalar.push({ ad: `soy ${ad} ${id}`, girdi: { tur: 'soy', agac: ad, kisi: id }, beklenen: { kume: soy[i] } }));
  }

  // rowLabel + layoutBounds (soy, heritage; odak ve tum ag.)
  for (const ad of ['soy', 'heritage', 'bos']) {
    const wb = kurW(agaclar[ad].people, agaclar[ad].nextId);
    wb.calistir('buildFamilies();');
    for (const mod of ['focus', 'full']) {
      const etiket = JSON.parse(wb.calistir(`(()=>{treeMode='${mod}';const o={};for(let r=-6;r<=8;r++)o[r]=rowLabel(r);return JSON.stringify(o);})()`));
      vakalar.push({ ad: `etiket ${ad} ${mod}`, girdi: { tur: 'etiket', agac: ad, mod }, beklenen: etiket });
    }
    const ids = Object.keys(agaclar[ad].people);
    const secim = ad === 'bos' ? [] : [JSON.parse(wb.calistir('JSON.stringify(defaultFocus())')), ids[3], ids[ids.length - 1]];
    for (const mod of ['focus', 'full']) {
      for (const sur of [false, true]) {
        const drag = {};
        if (sur) ids.slice(0, 6).forEach((id, i) => { drag[id] = { dx: 40 * (i + 1) - 90, dy: i % 2 ? -300 : 250 }; });
        wb.ctx.__drag = drag;
        const dugumler = [];
        for (const f of (mod === 'focus' ? secim : [null])) {
          const b = JSON.parse(wb.calistir(`(()=>{treeMode='${mod}';nodeDrag=Object.assign({'$v':2},__drag);nodePos={};nodeRow={};
            ${mod === 'focus' ? 'upGen=3;downGen=2;if(' + J(f) + '!==null)layoutFocus(' + J(f) + ');' : 'layoutFull();'}
            const k=Object.keys(nodePos).map(i=>i+'|'+nodePos[i].x+'|'+nodePos[i].y+'|'+nodeRow[i]);
            return JSON.stringify({dugumler:k,b:layoutBounds()});})()`));
          vakalar.push({ ad: `sinir ${ad} ${mod} ${sur ? 'surukle' : 'duz'} ${f}`, girdi: { tur: 'sinir', agac: ad, mod, odak: f, drag: sur ? drag : {} }, beklenen: b });
        }
        void dugumler;
      }
    }
  }

  // normDrag
  const w = taze();
  const dragGirdi = [
    { $v: 2 }, { $v: 2, P1: { dx: 3, dy: -4 } }, { P1: { dx: 5, dy: 6 }, P2: { dx: 0, dy: 1 } },
    {}, null, [], [1, 2], { $v: 1, P1: { dx: 1, dy: 1 } }, { $v: '2' }, 'metin', 7, true, { $old: { P1: { dx: 1, dy: 2 } } },
  ];
  dragGirdi.forEach((d, i) => {
    w.ctx.__d = J(d);
    const s = JSON.parse(w.calistir('JSON.stringify(normDrag(JSON.parse(__d)))'));
    vakalar.push({ ad: 'normDrag ' + i, girdi: { tur: 'normDrag', d }, beklenen: s });
  });
  console.log('odak kisi sayilari:', J(toplam));
  return { vakalar };
}
