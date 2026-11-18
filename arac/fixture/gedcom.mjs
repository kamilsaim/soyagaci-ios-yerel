// GEDCOM fixture'i: parseGED (degistir + ekle yolu) ve expGED, gidis-donus.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const veriDizini = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'veri');
const oku = (ad) => fs.readFileSync(path.join(veriDizini, ad), 'utf8');
const J = (x) => JSON.stringify(x);

export default function uret(webYukle) {
  const gercekYedek = JSON.parse(oku('soy-agaci.json'));
  const girdiler = [
    ['heritage.ged', oku('heritage.ged')],
    ['saim-soy.ged', oku('saim-soy.ged')],
    ['edevlet-soy-Mustafa.ged', oku('edevlet-soy-Mustafa.ged')],
  ];
  // CRLF varyanti: saim-soy.ged'in satir sonlari \r\n yapilmis hali; LF'ye geri donusturulunce ayni metin olmali
  const saim = girdiler[1][1];
  const crlf = saim.replace(/\r?\n/g, '\r\n');
  if (crlf.replace(/\r\n/g, '\n') !== saim.replace(/\r\n/g, '\n')) throw new Error('crlf donusumu tutarsiz');

  // Elle yazilmis kenar durumlari: tamsayi benzeri kimlik sirasi, tekrar eden kimlik, SEX U, adsiz kayit,
  // egik cizgisiz ad, ikinci NAME (kizlik), NOTE CONT/CONC, DEAT Y, DIV, bilinmeyen kimlik, kendine es, bozuk satir
  const kenar = [
    '0 HEAD', '1 CHAR UTF-8',
    '0 @10@ INDI', '1 NAME mehmet ali /kara yilmaz/', '1 SEX M', '1 BIRT', '2 DATE 30.07.1950', '2 PLAC istanbul',
    '1 OCCU doktor', '1 NOTE ilk satir', '2 CONT ikinci satir', '2 CONC devam', '2 CONT', '2 CONT son',
    '1 DEAT Y',
    '0 @2@ INDI', '1 NAME Ayse /Demir/', '1 NAME Ayse /Kara/', '2 TYPE birth', '1 SEX F', '1 DEAT', '2 DATE 1 JAN 2001', '2 PLAC Ankara',
    '0 @I3@ INDI', '1 NAME Veli Can Oz', '1 SEX U', '1 BIRT', '2 DATE 5 MAR 1980',
    '0 @I4@ INDI', '1 NAME', '1 SEX F',
    '0 @I5@ INDI', '1 NAME Tek', '1 NOTE a', '1 NOTE b', '2 CONT c',
    '0 @I3@ INDI', '1 NAME Yinelenen /Soyad/', '1 SEX M',
    'bozuk satir', '',
    '0 @F1@ FAM', '1 HUSB @10@', '1 WIFE @2@', '1 CHIL @I3@', '1 CHIL @I4@', '1 CHIL @YOK@', '1 CHIL @I3@',
    '0 @F2@ FAM', '1 HUSB @I5@', '1 WIFE @2@', '1 DIV', '1 CHIL @I4@',
    '0 @F3@ FAM', '1 HUSB @I5@', '1 WIFE @I5@',
    '0 @F4@ FAM', '1 HUSB @YOK@', '1 CHIL @I5@',
    '0 TRLR', '',
  ].join('\n');

  const vakalar = [];
  const taze = () => {
    const w = webYukle();
    if (w.baslatmaHatasi) throw new Error('baslatma hatasi: ' + w.baslatmaHatasi.message);
    w.calistir(`save=function(){}; saveLayout=function(){}; renderAll=function(){}; buildTree=function(){};
      toast=function(){}; globalThis.__dl=null; globalThis.__prev=null;
      dl=function(a,b){globalThis.__dl=b;};
      matchImported=function(){return new Map();};
      showGedPreview=function(ids,map,nid0){globalThis.__prev=ids;};`);
    return w;
  };
  const goruntu = (w) => JSON.parse(w.calistir('JSON.stringify({people:people,nextId:nextId})'));
  const parse = (w, metin) => { w.ctx.__t = metin; w.calistir('parseGED(__t,false)'); return goruntu(w); };

  const tumu = [...girdiler, ['crlf saim-soy.ged', crlf], ['kenar durumlari', kenar]];
  for (const [ad, metin] of tumu) {
    const sonuc = parse(taze(), metin);
    vakalar.push({ ad: 'parse ' + ad, girdi: { tur: 'parse', metin }, beklenen: sonuc });
  }

  // expGED: soy-agaci.json + her parse sonucu + elle kurulan kucuk aile
  const K = (id, ad, soyad, g, o = {}) => ({
    id, firstName: ad, lastName: soyad, gender: g, birthDate: '', birthPlace: '', deathDate: '', deathPlace: '',
    occupation: '', notes: '', photo: null, gallery: [], mother: null, father: null, spouse: null, spouses: [], children: [], ...o,
  });
  const kucuk = {
    P1: K('P1', 'Ahmet', 'Yilmaz', 'M', { birthDate: '01/02/1930', birthPlace: 'Sivas', spouses: [{ id: 'P2', status: 'married' }, { id: 'P9', status: 'divorced' }], spouse: 'P2', children: ['P3'] }),
    P2: K('P2', 'Ayse', 'Yilmaz', 'F', { maidenName: 'Kara', birthDate: '1935', deathDate: '12.05.2010', deathPlace: 'Ankara', notes: 'bir\n\nuc\r\ndort', spouses: [{ id: 'P1', status: 'married' }], spouse: 'P1' }),
    P3: K('P3', 'Mehmet', 'Yilmaz', 'M', { father: 'P1', mother: 'P2', deceased: true, occupation: 'Doktor', birthDate: 'JUL 2003' }),
    P4: K('P4', '', '', 'F', { father: 'P1', maidenName: 'X' }),
    P5: K('P5', 'Eksik', 'Ebeveyn', 'M', { father: 'YOK', mother: 'P2', deathPlace: 'Bursa' }),
    P6: K('P6', 'Es', 'Es', 'F', { spouses: [{ id: 'P6', status: 'married' }, { id: 'P3', status: 'widowed' }, { id: 'P4', status: 'partner' }] }),
    P7: K('P7', 'Cinsiyetsiz', 'Kisi', 'M', { gender: '', spouses: [{ id: 'P3', status: 'divorced' }] }),
  };
  const yazKaynaklari = [['soy-agaci.json', gercekYedek.people, gercekYedek.nextId], ['kucuk aile', kucuk, 10]];
  for (const v of vakalar.slice()) yazKaynaklari.push([v.ad.replace('parse ', 'parse sonucu '), v.beklenen.people, v.beklenen.nextId]);
  for (const [ad, people, nextId] of yazKaynaklari) {
    const w = taze();
    w.ayarla(JSON.parse(J(people)), nextId);
    w.calistir('migrateData()');
    const onceki = goruntu(w);
    w.calistir('globalThis.__dl=null; expGED()');
    const metin = w.calistir('__dl');
    const gidis = parse(taze(), metin);
    vakalar.push({
      ad: 'yaz ' + ad,
      girdi: { tur: 'yaz', people: onceki.people, nextId: onceki.nextId },
      beklenen: { metin, gidis },
    });
  }

  // parseGEDEkle: mevcut agaca ekleme (eslestirme Task 5'te; burada yalnizca eklenen kimlikler)
  const tabanlar = [['bos', {}, 1], ['soy-agaci.json', gercekYedek.people, gercekYedek.nextId], ['kucuk aile', kucuk, 10]];
  const ekleMetinleri = [girdiler[1], girdiler[2], ['kenar durumlari', kenar], girdiler[0]];
  for (const [tAd, people, nextId] of tabanlar) {
    for (const [mAd, metin] of ekleMetinleri) {
      const w = taze();
      w.ayarla(JSON.parse(J(people)), nextId);
      w.calistir('migrateData()');
      const tabanGoruntu = goruntu(w);
      w.ctx.__t = metin;
      w.calistir('parseGED(__t,true)');
      const sonra = goruntu(w);
      const ids = JSON.parse(w.calistir('JSON.stringify(__prev)'));
      vakalar.push({
        ad: 'ekle ' + mAd + ' -> ' + tAd,
        girdi: { tur: 'ekle', metin, people: tabanGoruntu.people, nextId: tabanGoruntu.nextId },
        beklenen: { people: sonra.people, nextId: sonra.nextId, ids },
      });
    }
  }
  return { vakalar };
}
