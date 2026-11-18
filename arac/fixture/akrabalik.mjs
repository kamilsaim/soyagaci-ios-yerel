// Akrabalik fixture'i: genOf, kinship, kinPhrase, kinSentence (web v6.1 modulu).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const veriDizini = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'veri');
const J = (x) => JSON.stringify(x);

// tohumlu PRNG (mulberry32)
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

// Elle agac kurucu: tutarli iki yonlu baglar
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

function elleBuyuk() {
  const { p, yeni, evlen, cocuk } = kur();
  const ibrahim = yeni('Ibrahim', 'M', 1920);
  const hatice = yeni('Hatice', 'F', 1925);
  const zehra = yeni('Zehra', 'F', 1930);
  evlen(ibrahim, hatice);
  evlen(ibrahim, zehra, 'widowed');
  const mehmet = yeni('Mehmet', 'M', 1950);
  const ayse = yeni('Ayşe', 'F', 1952);
  const hasan = yeni('Hasan', 'M', 1955);
  const fatma = yeni('Fatma', 'F', 1958);
  const kemal = yeni('Kemal', 'M', 1965);
  cocuk(ibrahim, hatice, mehmet); cocuk(ibrahim, hatice, ayse); cocuk(ibrahim, hatice, hasan); cocuk(ibrahim, hatice, fatma);
  cocuk(ibrahim, zehra, kemal);
  const elif = yeni('Elif', 'F', 1953);
  evlen(mehmet, elif);
  const ali = yeni('Ali', 'M', 1975); const veli = yeni('Veli', 'M', 1978); const zeynep = yeni('Zeynep', 'F', 1980);
  [ali, veli, zeynep].forEach((c) => cocuk(mehmet, elif, c));
  const mustafa = yeni('Mustafa', 'M', 1950);
  evlen(ayse, mustafa);
  const can = yeni('Can', 'M', 1980); const deniz = yeni('Deniz', 'F', 1982);
  cocuk(mustafa, ayse, can); cocuk(mustafa, ayse, deniz);
  const kaan = yeni('Kaan', 'M', 1980);
  evlen(deniz, kaan);
  const seda = yeni('Seda', 'F', 1957);
  evlen(hasan, seda);
  const emre = yeni('Emre', 'M', 1985);
  cocuk(hasan, seda, emre);
  const murat = yeni('Murat', 'M', 1955);
  evlen(fatma, murat, 'divorced');
  const ece = yeni('Ece', 'F', 1990);
  cocuk(murat, fatma, ece);
  const orhan = yeni('Orhan', 'M', 1957);
  evlen(fatma, orhan);
  const mert = yeni('Mert', 'M', 1995);
  cocuk(orhan, fatma, mert);
  const dilek = yeni('Dilek', 'F', 1968);
  evlen(kemal, dilek, 'divorced');
  const isil = yeni('Işıl', 'F', 1990);
  cocuk(kemal, dilek, isil);
  const pinar = yeni('Pınar', 'F', 1970);
  evlen(kemal, pinar);
  const sinan = yeni('Sinan', 'M', 1950); const sevgi = yeni('Sevgi', 'F', 1955);
  evlen(sinan, sevgi);
  const selin = yeni('Selin', 'F', 1977); const berk = yeni('Berk', 'M', 1980); const sibel = yeni('Sibel', 'F', 1983);
  [selin, berk, sibel].forEach((c) => cocuk(sinan, sevgi, c));
  evlen(ali, selin);
  const ada = yeni('Ada', 'F', 2005); const kerem = yeni('Kerem', 'M', 2008);
  cocuk(ali, selin, ada); cocuk(ali, selin, kerem);
  const osman = yeni('Osman', 'M', 1952); const leyla = yeni('Leyla', 'F', 1956);
  evlen(osman, leyla);
  const gul = yeni('Gül', 'F', 1980); const nur = yeni('Nur', 'F', 1983); const baris = yeni('Barış', 'M', 1985);
  [gul, nur, baris].forEach((c) => cocuk(osman, leyla, c));
  evlen(veli, gul);
  const tolga = yeni('Tolga', 'M', 1981);
  evlen(nur, tolga);
  const taner = yeni('Taner', 'M', 1979);
  evlen(zeynep, taner);
  const ayhan = yeni('Ayhan', 'M', 0); // Can ve Deniz ile ayni anne baba; dogum yili yok
  cocuk(mustafa, ayse, ayhan);
  yeni('Tek', 'F', 1960); // bagsiz
  return p;
}

function elleGaripler() {
  const { p, yeni, cocuk } = kur();
  const x1 = yeni('Baba', 'M', 1940); const x2 = yeni('Anne', 'F', 1942); const x3 = yeni('Liste', 'M', 1965);
  p[x1].children.push(x3); p[x2].children.push(x3); // x3'te father/mother yok, yalniz children listesi
  const x4 = yeni('Cocuk', 'F', 1966); const x5 = yeni('Ana', 'F', 1945);
  p[x4].father = x1; p[x1].children.push(x4); p[x4].mother = x5; // x5 listelememis
  const x6 = yeni('Yetim', 'M', 1970);
  p[x6].father = x1; p[x6].mother = 'P99'; // olmayan anne
  const x7 = yeni('Iki', 'F', 1968); const a1 = yeni('Birinci', 'F', 1944); const a2 = yeni('Ikinci', 'F', 1946);
  p[a1].children.push(x7); p[a2].children.push(x7);
  const x8 = yeni('Tek yon', 'M', 1950); const x9 = yeni('Karsisi', 'F', 1952);
  p[x8].spouses.push({ id: x9, status: 'married' }); p[x8].spouse = x9; // x9'da yok
  const d1 = yeni('Dongu A', 'M', 1950); const d2 = yeni('Dongu B', 'M', 1950);
  p[d1].father = d2; p[d2].father = d1; p[d1].children.push(d2); p[d2].children.push(d1);
  const g1 = yeni('', 'M', 1980); const g2 = yeni('Cinssiz', '', 1981);
  p[g2].father = x1; p[g1].father = x1;
  const s1 = yeni('Ozturk', 'F', 1960);
  p[s1].spouses.push({ id: 'P98', status: 'married' }); // olmayan es
  const ik = yeni('Ikiz', 'M', 1990); const ik2 = yeni('Ikiz2', 'F', 1990);
  cocuk(x3, null, ik); cocuk(x3, null, ik2); // tek ebeveynli
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
  const kurW = (people, nextId) => {
    const w = taze();
    w.ayarla(JSON.parse(J(people)), nextId);
    w.calistir('migrateData()');
    return w;
  };
  const goruntu = (w) => JSON.parse(w.calistir('JSON.stringify({people:people,nextId:nextId})'));

  const agaclar = {};
  agaclar.soy = goruntu(kurW(yedek.people, yedek.nextId));
  {
    const w = taze();
    w.ctx.__t = heritage;
    w.calistir('parseGED(__t,false)');
    agaclar.heritage = goruntu(w);
  }
  agaclar.elle1 = goruntu(kurW(elleBuyuk(), 200));
  agaclar.elle2 = goruntu(kurW(elleGaripler(), 200));

  const webde = {};
  for (const ad of Object.keys(agaclar)) webde[ad] = kurW(agaclar[ad].people, agaclar[ad].nextId);

  const hesapla = (agac, ciftler) => {
    const w = webde[agac];
    w.ctx.__c = ciftler;
    return JSON.parse(w.calistir(`(()=>{
      const norm=r=>r===null||r===undefined?null:{self:!!r.self,words:r.words||[],note:r.note||'',common:r.common===undefined?null:r.common,chain:!!r.chain};
      return JSON.stringify(__c.map(([a,b])=>({cumle:kinSentence(a,b),kisi:kinPhrase(a,b),kin:norm(kinship(a,b))})));
    })()`));
  };

  const vakalar = [];
  for (const ad of Object.keys(agaclar)) vakalar.push({ ad: 'agac ' + ad, girdi: { tur: 'agac', agac: ad }, beklenen: agaclar[ad] });

  const kullanilan = new Set();
  let zincir = 0;
  const ciftEkle = (agac, tur, ciftler) => {
    const sonuc = hesapla(agac, ciftler);
    ciftler.forEach(([a, b], i) => {
      const s = sonuc[i];
      if (s.kin) { (s.kin.words || []).forEach((k) => kullanilan.add(k)); if (s.kin.chain) zincir += 1; }
      vakalar.push({ ad: `${tur} ${agac} ${a}->${b}`, girdi: { tur, agac, a, b }, beklenen: s });
    });
  };

  // 1) soy-agaci.json: P3'e gore herkes
  const soyIds = Object.keys(agaclar.soy.people);
  ciftEkle('soy', 'cift', soyIds.filter((i) => i !== 'P3').map((i) => ['P3', i]));
  // 2) soy-agaci.json: 400 rastgele cift (tohum 42)
  const rng = mulberry32(42);
  const rast = (ids, n) => {
    const c = [];
    while (c.length < n) {
      const a = ids[Math.floor(rng() * ids.length)]; const b = ids[Math.floor(rng() * ids.length)];
      if (a !== b) c.push([a, b]);
    }
    return c;
  };
  ciftEkle('soy', 'cift', rast(soyIds, 400));
  // 3) heritage: 250 rastgele cift (kayinlik/uvey kapsami)
  ciftEkle('heritage', 'cift', rast(Object.keys(agaclar.heritage.people), 250));
  // 4) elle agaclar: tum sirali ciftler
  for (const ad of ['elle1', 'elle2']) {
    const ids = Object.keys(agaclar[ad].people);
    const c = [];
    for (const a of ids) for (const b of ids) if (a !== b) c.push([a, b]);
    ciftEkle(ad, 'cift', c);
  }
  // 5) ayni kisi + olmayan kimlikler
  ciftEkle('soy', 'ayni', [['P3', 'P3'], ['P1', 'P1']]);
  ciftEkle('elle1', 'ayni', [['P1', 'P1'], ['P9', 'P9']]);
  ciftEkle('elle2', 'ayni', [['P1', 'P1']]);
  ciftEkle('soy', 'yok', [['P3', 'Z999'], ['Z999', 'P3'], ['Z1', 'Z1'], ['P3', ''], ['', '']]);

  // genOf: ~60 ad
  const adlar = ['Kamil', 'Ayşe', 'Mustafa', 'Ümmügülsün', 'Ali', 'Veli', 'Hasan', 'Hüseyin', 'Ömer', 'Özlem', 'Işık', 'İbrahim', 'Irmak', 'İlker',
    'Zeynep', 'Fatma', 'Elif', 'Emine', 'Ahmet', 'Mehmet', 'Yusuf', 'Rabia', 'Esra', 'Şükrü', 'Gül', 'Güzide', 'Ece', 'Eda', 'Burcu', 'Cemil', 'Dilek',
    'Nur', 'Selim', 'Selin', 'Tuğba', 'Uğur', 'Ülkü', 'Ömür', 'Oğuz', 'Çiğdem', 'Cüneyt', 'Hâlâ', 'Nâzım', 'Aslı', 'Bülent', 'Kübra', 'Mümin',
    'Ayşe Nur', 'Mehmet Ali', 'Ali Rıza', 'Hacı Mehmet', 'KAMİL', 'ALİ', 'ışıl', '  Kamil  ', 'Jean-Luc', "D'Artagnan", '', '   ', 'X1', '123', 'Ay-', 'Ö', 'a', 'İ', 'I'];
  const gw = webde.soy;
  gw.ctx.__a = adlar;
  const gen = JSON.parse(gw.calistir('JSON.stringify(__a.map(genOf))'));
  adlar.forEach((a, i) => vakalar.push({ ad: 'genOf ' + J(a), girdi: { tur: 'genOf', ad: a }, beklenen: gen[i] }));

  // kapsam raporu
  const beklenen = ['dede', 'babaanne', 'anneanne', 'abi', 'abla', 'bababir', 'annebir', 'amca', 'hala', 'dayi', 'teyze', 'yegen', 'kuzen', 'ekardes', 'kkardes',
    'baba', 'anne', 'ogul', 'kiz', 'torun', 'es', 'eskies', 'kayinpeder', 'kayinvalide', 'kayinbirader', 'baldiz', 'gorumce', 'gelin', 'damat', 'yenge', 'eniste',
    'elti', 'bacanak', 'uveyanne', 'uveybaba', 'uveyogul', 'uveykiz'];
  const eksik = beklenen.filter((k) => !kullanilan.has(k));
  console.log('akrabalik kapsam: eksik =', J(eksik), 'zincir vakalari =', zincir, 'kullanilan =', [...kullanilan].sort().join(','));
  return { vakalar };
}
