// GED birlestirme fixture'i: parseGED(txt,true) -> matchImported -> applyImported / cancelGedMerge, gedSum.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const veriDizini = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'veri');
const oku = (ad) => fs.readFileSync(path.join(veriDizini, ad), 'utf8');
const J = (x) => JSON.stringify(x);

const K = (id, ad, soyad, g, o = {}) => ({
  id, firstName: ad, lastName: soyad, gender: g, birthDate: '', birthPlace: '', deathDate: '', deathPlace: '',
  occupation: '', notes: '', photo: null, gallery: [], mother: null, father: null, spouse: null, spouses: [], children: [], ...o,
});
const gedYap = (kayitlar, aileler = []) => ['0 HEAD', '1 CHAR UTF-8', ...kayitlar.flatMap((k) => [
  `0 @${k.id}@ INDI`, `1 NAME ${k.ad}`, `1 SEX ${k.cins || 'M'}`, ...(k.yil ? ['1 BIRT', `2 DATE ${k.yil}`] : []),
]), ...aileler.flatMap((f, i) => [`0 @F${i + 1}@ FAM`, ...(f.b ? [`1 HUSB @${f.b}@`] : []), ...(f.a ? [`1 WIFE @${f.a}@`] : []), ...(f.c || []).map((c) => `1 CHIL @${c}@`)]), '0 TRLR', ''].join('\n');

// Elle yazilmis belirsizlik vakalari: matchImported'in koruma dallarini tetikler
export function elleVakalar() {
  const agac = (...l) => ({ people: Object.fromEntries(l.map((k) => [k.id, k])), nextId: 50 });
  const ahmet = (ek = {}) => K('P1', 'Ahmet', 'Soy', 'M', { birthDate: '1920', ...ek });
  return [
    ['elle (a) iki eski Mehmet Yilmaz 1950 -> eslesme yok',
      agac(K('P1', 'Mehmet', 'Yilmaz', 'M', { birthDate: '1950' }), K('P2', 'Mehmet', 'Yilmaz', 'M', { birthDate: '1950' })),
      gedYap([{ id: 'I1', ad: 'Mehmet /Yilmaz/', yil: '1950' }]), [0]],
    ['elle (b) iki ayni yeni kayit tek eskiyi ceker -> eslesme yok',
      agac(K('P1', 'Ali', 'Kara', 'M', { birthDate: '1950' })),
      gedYap([{ id: 'I1', ad: 'Ali /Kara/', yil: '1950' }, { id: 'I2', ad: 'Ali /Kara/', yil: '1950' }]), [0]],
    ['elle (c) yalniz baba adiyla destekli, yil bir fark; ikincisi destek yok',
      agac(K('P1', 'Hasan', 'Demir', 'M', { birthDate: '1950', children: ['P2'] }),
        K('P2', 'Veli', 'Demir', 'M', { birthDate: '1980', father: 'P1' }),
        K('P3', 'Osman', 'Kaya', 'M', { birthDate: '1970' })),
      gedYap([{ id: 'I1', ad: 'Hasan', yil: '1950' }, { id: 'I2', ad: 'Veli', yil: '1981' }, { id: 'I3', ad: 'Osman', yil: '1971' }], [{ b: 'I1', c: ['I2'] }]), [0]],
    ['elle (d1) ebeveynin iki ayni adli cocugu (yayilmada c>1)',
      agac(ahmet({ children: ['P2', 'P3'] }), K('P2', 'Can', 'Soy', 'M', { father: 'P1' }), K('P3', 'Can', 'Soy', 'M', { father: 'P1' })),
      gedYap([{ id: 'I1', ad: 'Ahmet /Soy/', yil: '1920' }, { id: 'I2', ad: 'Can' }], [{ b: 'I1', c: ['I2'] }]), [0]],
    ['elle (d2) iki ayni yeni cocuk tek eski cocuga (yayilmada tersi tek degil)',
      agac(ahmet({ children: ['P2'] }), K('P2', 'Can', 'Soy', 'M', { father: 'P1' })),
      gedYap([{ id: 'I1', ad: 'Ahmet /Soy/', yil: '1920' }, { id: 'I2', ad: 'Can' }, { id: 'I3', ad: 'Can' }], [{ b: 'I1', c: ['I2', 'I3'] }]), [0]],
  ];
}

export default function uret(webYukle) {
  const yedek = JSON.parse(oku('soy-agaci.json'));
  const saim = oku('saim-soy.ged');
  const heritage = oku('heritage.ged');
  const edevlet = oku('edevlet-soy-Mustafa.ged');

  const taze = () => {
    const w = webYukle();
    if (w.baslatmaHatasi) throw new Error('baslatma hatasi: ' + w.baslatmaHatasi.message);
    w.calistir(`save=function(){}; saveLayout=function(){}; renderAll=function(){}; buildTree=function(){};
      toast=function(){}; cModal=function(){}; globalThis.__dl=null; globalThis.__prev=null;
      dl=function(a,b){globalThis.__dl=b;};
      showGedPreview=function(ids,map,nid0){globalThis.__prev={ids:ids,map:map,nid0:nid0};_gedPend={ids:ids,map:map,nid0:nid0};};`);
    return w;
  };
  const goruntu = (w) => JSON.parse(w.calistir('JSON.stringify({people:people,nextId:nextId})'));
  const kur = (people, nextId) => {
    const w = taze();
    w.ayarla(JSON.parse(J(people)), nextId);
    w.calistir('migrateData()');
    return w;
  };
  const parse = (metin) => {
    const w = taze();
    w.ctx.__t = metin;
    w.calistir('parseGED(__t,false)');
    return goruntu(w);
  };
  const disa = (people, nextId) => {
    const w = kur(people, nextId);
    w.calistir('globalThis.__dl=null; expGED()');
    return w.calistir('__dl');
  };

  // yapay yeni kuzen: soy-agaci.json'in kendi GED'i + ilk aileye yeni cocuk
  const kendiGed = disa(yedek.people, yedek.nextId);
  const satirlar = kendiGed.split('\n');
  const ilkFam = satirlar.findIndex((s) => /^0 @[^@]+@ FAM/.test(s));
  if (ilkFam < 0) throw new Error('FAM yok');
  const yeniKayit = ['0 @IYENI@ INDI', '1 NAME Yeni Kuzen /Deneme/', '1 SEX M', '1 BIRT', '2 DATE 14 FEB 1999', '2 PLAC Konya'];
  satirlar.splice(ilkFam + 1, 0, '1 CHIL @IYENI@');
  satirlar.splice(ilkFam, 0, ...yeniKayit);
  const kuzenGed = satirlar.join('\n');

  const saimTaban = parse(saim);
  const heritageTaban = parse(heritage);

  const tanimlar = [
    ['soy-agaci.json + saim-soy.ged', yedek, saim, [2]],
    ['soy-agaci.json + heritage.ged', yedek, heritage, [10]],
    ['soy-agaci.json + edevlet-soy-Mustafa.ged', yedek, edevlet, [0]],
    ['soy-agaci.json + kendi GED (kendi ustune)', yedek, kendiGed, [5]],
    ['soy-agaci.json + yeni kuzen', yedek, kuzenGed, [0]],
    ['saim-soy kendi ustune', saimTaban, saim, [1]],
    ['heritage kendi ustune', heritageTaban, heritage, [3]],
    ['bos ag + saim-soy.ged', { people: {}, nextId: 1 }, saim, [0]],
    ...elleVakalar().map(([ad, taban, metin, kaldir]) => [ad, taban, metin, kaldir]),
  ];

  const vakalar = [];
  for (const [ad, taban, metin, kaldir] of tanimlar) {
    const hazirla = () => {
      const w = kur(taban.people, taban.nextId);
      const once = goruntu(w);
      w.ctx.__t = metin;
      w.calistir('parseGED(__t,true)');
      return { w, once };
    };
    const { w, once } = hazirla();
    const ids = JSON.parse(w.calistir('JSON.stringify(__prev.ids)'));
    const nid0 = w.calistir('__prev.nid0');
    const esler = JSON.parse(w.calistir('JSON.stringify([...__prev.map])'));
    const ozet = JSON.parse(w.calistir(`(function(){const o={};const ids=__prev.ids;
      for(const id of ids)o[id]=gedSum(people[id]);
      for(const [n,e] of __prev.map)o[e]=gedSum(people[e]);
      return JSON.stringify(o);})()`));
    // uygula
    const sayi = w.calistir('applyImported(__prev.ids,__prev.map)');
    const uygula = { ...goruntu(w), sayi };
    // isareti kaldirilmis cift(ler)
    const w2 = hazirla().w;
    w2.ctx.__k = kaldir;
    w2.calistir('(function(){const k=[...__prev.map.keys()];for(const i of __k)if(k[i]!==undefined)__prev.map.delete(k[i]);})()');
    const kalanEsler = JSON.parse(w2.calistir('JSON.stringify([...__prev.map])'));
    const sayi2 = w2.calistir('applyImported(__prev.ids,__prev.map)');
    const kaldirUygula = { ...goruntu(w2), sayi: sayi2, esler: kalanEsler };
    // iptal
    const w3 = hazirla().w;
    w3.calistir('cancelGedMerge()');
    const iptal = goruntu(w3);
    vakalar.push({
      ad,
      girdi: { metin, people: once.people, nextId: once.nextId, kaldir },
      beklenen: { nid0, ids, esler, ozet, uygula, kaldirUygula, iptal },
    });
  }
  return { vakalar };
}
