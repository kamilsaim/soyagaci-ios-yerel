// GED birlestirme fixture'i: parseGED(txt,true) -> matchImported -> applyImported / cancelGedMerge, gedSum.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const veriDizini = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'veri');
const oku = (ad) => fs.readFileSync(path.join(veriDizini, ad), 'utf8');
const J = (x) => JSON.stringify(x);

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
