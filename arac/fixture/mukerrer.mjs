// Mukerrer fixture'i: mergePeople(keep, drop), findDupes + dupSummary (notDup), bul->birlestir->bul.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const veriDizini = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'veri');
const J = (x) => JSON.stringify(x);

export default function uret(webYukle) {
  const yedek = JSON.parse(fs.readFileSync(path.join(veriDizini, 'soy-agaci.json'), 'utf8'));
  const K = (id, ad, soyad, g, o = {}) => ({
    id, firstName: ad, lastName: soyad, gender: g, birthDate: '', birthPlace: '', deathDate: '', deathPlace: '',
    occupation: '', notes: '', photo: null, gallery: [], mother: null, father: null, spouse: null, spouses: [], children: [], ...o,
  });
  const kucuk = {
    P1: K('P1', 'Ahmet', 'Yilmaz', 'M', { birthDate: '01/02/1930', spouses: [{ id: 'P2', status: 'married' }], spouse: 'P2', children: ['P3', 'P4'], gallery: ['a.jpg'], notes: 'ilk', extra: { x: 1 } }),
    P2: K('P2', 'Ayse', 'Kara', 'F', { spouses: [{ id: 'P1', status: 'married' }, { id: 'P8', status: 'divorced' }], spouse: 'P1', children: ['P3', 'P4'] }),
    P3: K('P3', 'Mehmet', 'Yilmaz', 'M', { father: 'P1', mother: 'P2', spouses: [{ id: 'P5', status: 'married' }], spouse: 'P5', children: ['P6'] }),
    P4: K('P4', '', '', 'F', { father: 'P1', mother: 'P2', deceased: true, notes: 'ikinci', gallery: ['a.jpg', 'b.jpg'], birthPlace: 'Sivas', photo: 'x/y.jpg' }),
    P5: K('P5', 'Fatma', 'Yilmaz', 'F', { maidenName: 'Oz', spouses: [{ id: 'P3', status: 'married' }, { id: 'P9', status: 'widowed' }], spouse: 'P3', children: ['P6'] }),
    P6: K('P6', 'Can', 'Yilmaz', 'M', { father: 'P3', mother: 'P5', notes: 'ikinci' }),
    P7: K('P7', 'Mehmet', 'Yilmaz', 'M', { father: 'P1', mother: 'P2', birthDate: '1960', birthPlace: 'Ankara', occupation: 'Doktor', notes: 'baska not', spouses: [{ id: 'P5', status: 'divorced' }, { id: 'P8', status: 'partner' }], spouse: 'P5', children: ['P6', 'P10'] }),
    P8: K('P8', 'Zeynep', 'Aksoy', 'F', { spouses: [{ id: 'P7', status: 'partner' }, { id: 'P2', status: 'divorced' }], spouse: 'P7', children: ['P10'] }),
    P9: K('P9', 'Hasan', 'Oz', 'M', { spouses: [{ id: 'P5', status: 'widowed' }], spouse: 'P5' }),
    P10: K('P10', 'Veli', 'Yilmaz', 'M', { father: 'P7', mother: 'P8' }),
  };
  const ciftler = [
    ['kucuk P3<-P7 (ayni isim)', kucuk, 'P3', 'P7'],
    ['kucuk P7<-P3 (ters)', kucuk, 'P7', 'P3'],
    ['kucuk P1<-P3 (ebeveyn<-cocuk)', kucuk, 'P1', 'P3'],
    ['kucuk P3<-P1 (cocuk<-ebeveyn)', kucuk, 'P3', 'P1'],
    ['kucuk P1<-P2 (es<-es)', kucuk, 'P1', 'P2'],
    ['kucuk P4<-P6 (not ve galeri)', kucuk, 'P4', 'P6'],
    ['kucuk P6<-P4', kucuk, 'P6', 'P4'],
    ['kucuk P5<-P9', kucuk, 'P5', 'P9'],
  ];
  // gercek agac: aralikli ciftler (akraba olmayanlar dahil)
  const anah = Object.keys(yedek.people);
  for (const [i, j] of [[0, 1], [3, 40], [20, 21], [60, 5], [100, 99], [146, 0], [12, 13]]) {
    ciftler.push([`soy-agaci ${anah[i]}<-${anah[j]}`, yedek.people, anah[i], anah[j]]);
  }

  const vakalar = [];
  for (const [ad, people, keep, drop] of ciftler) {
    const w = webYukle();
    if (w.baslatmaHatasi) throw new Error('baslatma hatasi: ' + w.baslatmaHatasi.message);
    w.ayarla(JSON.parse(J(people)), 200);
    w.calistir('migrateData()');
    const once = JSON.parse(w.calistir('JSON.stringify({people:people,nextId:nextId})'));
    w.calistir(`nodeDrag=nodeDrag||{};mergePeople(${J(keep)},${J(drop)})`);
    const sonra = JSON.parse(w.calistir('JSON.stringify({people:people,nextId:nextId})'));
    vakalar.push({ ad: 'mergePeople ' + ad, girdi: { tur: 'mergePeople', people: once.people, nextId: once.nextId, keep, drop }, beklenen: sonra });
  }
  // ---- findDupes / dupSummary ----
  const bul = (ad, people, nd = [], nextId = 300) => {
    const w = webYukle();
    if (w.baslatmaHatasi) throw new Error('baslatma hatasi: ' + w.baslatmaHatasi.message);
    w.ayarla(JSON.parse(J(people)), nextId);
    w.calistir('migrateData()');
    w.calistir(`localStorage.setItem(userKey('sa4_notdup'), ${J(J(nd))})`);
    const once = JSON.parse(w.calistir('JSON.stringify({people:people,nextId:nextId})'));
    const sonuc = JSON.parse(w.calistir('JSON.stringify({cift:findDupes().map(x=>({a:x.a.id,b:x.b.id,key:x.key,score:x.score})),ozet:Object.fromEntries(Object.values(people).map(p=>[p.id,dupSummary(p)]))})'));
    vakalar.push({ ad: 'findDupes ' + ad, girdi: { tur: 'findDupes', people: once.people, nextId: once.nextId, notDup: nd }, beklenen: sonuc });
    return { w, sonuc, once };
  };
  for (const [ad, agac, nd] of dupAgaclari(yedek)) bul(ad, agac, nd);
  // bul -> ilkini birlestir -> tekrar bul
  for (const [ad, agac, nd] of dupAgaclari(yedek).filter((x) => x[0].startsWith('sentetik') || x[0].startsWith('elle genel'))) {
    const { w, sonuc, once } = bul('(on) ' + ad, agac, nd);
    const adim = [];
    for (const c of sonuc.cift.slice(0, 3)) {
      if (!JSON.parse(w.calistir(`JSON.stringify(!!people[${J(c.a)}]&&!!people[${J(c.b)}])`))) continue;
      w.calistir(`nodeDrag=nodeDrag||{};mergePeople(${J(c.a)},${J(c.b)})`);
      adim.push([c.a, c.b]);
    }
    const son = JSON.parse(w.calistir('JSON.stringify({people:people,nextId:nextId,cift:findDupes().map(x=>({a:x.a.id,b:x.b.id,key:x.key,score:x.score}))})'));
    vakalar.push({ ad: 'bulBirlestir ' + ad, girdi: { tur: 'bulBirlestir', people: once.people, nextId: once.nextId, notDup: nd, adim }, beklenen: son });
  }
  return { vakalar };
}


const K = (id, ad, soyad, g, o = {}) => ({
  id, firstName: ad, lastName: soyad, gender: g, birthDate: '', birthPlace: '', deathDate: '', deathPlace: '',
  occupation: '', notes: '', photo: null, gallery: [], mother: null, father: null, spouse: null, spouses: [], children: [], ...o,
});
const tablo = (...l) => Object.fromEntries(l.map((k) => [k.id, k]));

// [ad, people, notDup[]]
export function dupAgaclari(yedek) {
  const J2 = (x) => JSON.parse(JSON.stringify(x));
  const out = [];
  out.push(['gercek soy-agaci', J2(yedek.people), []]);

  // 5 tur yapay kopya (soy-agaci.json uzerine)
  const kopya = J2(yedek.people);
  const ekle = (id, kaynak, alan) => { kopya[id] = { ...J2(kopya[kaynak]), ...alan, id, children: [], spouses: [], spouse: null }; };
  ekle('P200', 'P3', {});                                                                       // 1 birebir kopya (ebeveynli)
  ekle('P201', 'P10', { firstName: 'YUSUF', lastName: 'SAİM', birthDate: '05.09.1989' });       // 2 buyuk harf + baska tarih bicimi
  kopya.P56.birthPlace = 'Sivas';
  ekle('P202', 'P56', { birthDate: '20/01/1962', father: null, mother: null, birthPlace: 'sivas' }); // 3 yil +1 + ayni dogum yeri
  ekle('P203', 'P56', {});                                                                      // 4 ayni ebeveyn + ayni yil
  ekle('P204', 'P6', { lastName: '', birthDate: '', father: null, mother: null });              // 5 zayif kopya (puan < 4)
  ekle('P205', 'P10', { birthDate: '1 SEP 1992', father: null, mother: null });                 // yil farki 3 -> elenir
  out.push(['sentetik kopyalar', kopya, []]);
  out.push(['sentetik kopyalar notDup (P3|P200 ve P10|P201)', J2(kopya), ['P200|P3', 'P10|P201']]);
  out.push(['sentetik kopyalar notDup anahtari yanlis sirada (elenmez)', J2(kopya), ['P3|P200']]);

  // elle: her puan/ret dali
  const t = [];
  const A = (...x) => t.push(...x);
  A(K('A1', 'Ali', 'Kaya', 'M', { birthDate: '1950' }), K('A2', 'Ali', 'Kaya', 'M', { birthDate: '1950' }));
  A(K('B1', 'Veli', 'Demir', 'M', { birthDate: '1940', spouses: [{ id: 'B2', status: 'married' }] }), K('B2', 'Veli', 'Demir', 'M', { birthDate: '1940' }));
  A(K('C1', 'Hasan', 'Er', 'M', { father: 'C2' }), K('C2', 'Hasan', 'Er', 'M'));
  A(K('C3', 'Hamdi', 'Er', 'M'), K('C4', 'Hamdi', 'Er', 'M', { father: 'C3' }));
  A(K('C5', 'Aynur', 'Er', 'F', { mother: 'C6' }), K('C6', 'Aynur', 'Er', 'F'));
  A(K('C7', 'Aysel', 'Er', 'F'), K('C8', 'Aysel', 'Er', 'F', { mother: 'C7' }));
  A(K('D1', 'Orhan', 'Kaya', 'M', { birthDate: '1950' }), K('D2', 'Orhan', 'Demir', 'M', { birthDate: '1950' }));
  A(K('D3', 'Ayse', 'Kaya', 'F', { birthDate: '1950' }), K('D4', 'Ayse', 'Oz', 'F', { maidenName: 'Kaya', birthDate: '1950' }));
  A(K('D5', 'Omer', '', 'M', { birthDate: '1950' }), K('D6', 'Omer', 'Aydin', 'M', { birthDate: '1950' }));
  A(K('D7', 'Murat', '', 'M', { birthDate: '1950', birthPlace: ' Sivas' }), K('D8', 'Murat', 'Aydin', 'M', { birthDate: '1950', birthPlace: 'sivas' }));
  A(K('D9', 'Selim', '', 'M', { birthDate: '1950', birthPlace: 'Sivas' }), K('D10', 'Selim', 'Aydin', 'M', { birthDate: '1950', birthPlace: 'Sivas' }));
  A(K('E1', 'Tarik', 'Su', 'M', { birthDate: '1950' }), K('E2', 'Tarik', 'Su', 'M', { birthDate: '1952' }));
  A(K('E3', 'Cevdet', 'Su', 'M', { birthDate: '1950' }), K('E4', 'Cevdet', 'Su', 'M', { birthDate: '1951' }));
  A(K('E5', 'Rıza', 'Su', 'M', { birthDate: '1950' }), K('E6', 'Rıza', 'Su', 'M', { birthDate: '' }));
  A(K('F0a', 'Ali', 'Ata', 'M'), K('F0b', 'Veli', 'Ata', 'M'));
  A(K('F1', 'Nuri', 'Er', 'M', { birthDate: '1950', father: 'F0a' }), K('F2', 'Nuri', 'Er', 'M', { birthDate: '1950', father: 'F0b' }));
  A(K('G0a', 'Mehmet', 'Yel', 'M', { birthDate: '1874' }), K('G0b', 'Mehmet', 'Yel', 'M', { birthDate: '1928' }),
    K('G0c', 'Mehmet', 'Yel', 'M', { birthDate: '1900' }), K('G0d', 'Mehmet', 'Yel', 'M', { birthDate: '1901' }),
    K('G0e', 'Mehmet', 'Yel', 'M'), K('G0f', 'Mehmet', 'Yel', 'M'));
  A(K('G1', 'Fikret', 'Yel', 'M', { birthDate: '1950', father: 'G0a' }), K('G2', 'Fikret', 'Yel', 'M', { birthDate: '1950', father: 'G0b' }));
  A(K('G3', 'Kemal', 'Yel', 'M', { birthDate: '1950', father: 'G0c' }), K('G4', 'Kemal', 'Yel', 'M', { birthDate: '1950', father: 'G0d' }));
  A(K('G5', 'Necip', 'Yel', 'M', { birthDate: '1950', father: 'G0e' }), K('G6', 'Necip', 'Yel', 'M', { birthDate: '1950', father: 'G0f' }));
  A(K('H0', 'Baba', 'Tas', 'M'), K('H0m', 'Ana', 'Tas', 'F'));
  A(K('H1', 'Cem', 'Tas', 'M', { birthDate: '1950', father: 'H0', mother: 'H0m' }), K('H2', 'Cem', 'Tas', 'M', { birthDate: '1951', father: 'H0', mother: 'H0m' }));
  A(K('H3', 'Can', 'Tas', 'M', { birthDate: '1950', father: 'H0', mother: 'H0m' }), K('H4', 'Can', 'Tas', 'M', { birthDate: '1950', father: 'H0', mother: 'H0m' }));
  A(K('H5', 'Cuma', 'Tas', 'M', { father: 'H0', mother: 'H0m' }), K('H6', 'Cuma', 'Tas', 'M', { father: 'H0', mother: 'H0m' }));
  A(K('I1', 'Ece', 'Yol', 'F'), K('I2', 'Ece', 'Yol', 'F'));
  A(K('I3', 'Sema', '', 'F', { birthDate: '1960' }), K('I4', 'Sema', '', 'F', { birthDate: '1960' }));
  A(K('J1', 'Deniz', 'Ak', 'M', { birthDate: '1950' }), K('J2', 'Deniz', 'Ak', 'F', { birthDate: '1950' }));
  A(K('J3', '', 'Ak', 'M', { birthDate: '1950' }), K('J4', '', 'Ak', 'M', { birthDate: '1950' }));
  A(K('J5', 'İsmail', 'Ak', 'M', { birthDate: '1950' }), K('J6', 'ismail', 'AK', 'M', { birthDate: '1950' }));
  A(K('J7', 'Mehmet Ali', 'Ak', 'M', { birthDate: '1950' }), K('J8', 'MehmetAli', 'Ak', 'M', { birthDate: '1950' }));
  A(K('J9', 'Işık', 'Ak', 'M', { birthDate: '1950' }), K('J10', 'ışık', 'Ak', 'M', { birthDate: '1950' }));
  A(K('L1', 'Zafer', 'Pak', 'M', { birthDate: '1950' }), K('L2', 'Zafer', 'Pak', 'M', { birthDate: '1950', birthPlace: 'Van' }), K('L3', 'Zafer', 'Pak', 'M', { birthDate: '1950', birthPlace: 'van' }));
  A(K('L4', 'Buse', 'Pak', 'F', { birthDate: '1950' }), K('L5', 'Buse', 'Pak', 'F', { birthDate: '1950' }));
  A(K('L6', 'Aras', 'Pak', 'M', { birthDate: '1950', father: 'F0a' }), K('L7', 'Aras', 'Pak', 'M', { birthDate: '1950', father: 'F0a' }));
  out.push(['elle genel', tablo(...t), []]);
  out.push(['elle genel notDup (A1|A2, J5|J6)', tablo(...t), ['A1|A2', 'J5|J6']]);
  out.push(['elle notDup dizgi siralamasi P10|P9',
    tablo(K('P10', 'Ayhan', 'Cil', 'M', { birthDate: '1970' }), K('P9', 'Ayhan', 'Cil', 'M', { birthDate: '1970' })), ['P10|P9']]);
  out.push(['elle dizgi siralamasi P10 P9 notDup yok',
    tablo(K('P10', 'Ayhan', 'Cil', 'M', { birthDate: '1970' }), K('P9', 'Ayhan', 'Cil', 'M', { birthDate: '1970' })), []]);
  out.push(['elle ozet', tablo(
    K('S1', 'Ali <b>', 'O\'Neil & "Co"', 'M', { birthDate: '1900', birthPlace: 'A&B', deathDate: '1980', maidenName: 'X<y', father: 'S2', mother: 'S3', spouses: [{ id: 'S4', status: 'married' }, { id: 'S5', status: 'married' }], children: ['S6', 'S7'] }),
    K('S2', 'Baba', '', 'M'), K('S3', '', '', 'F'), K('S4', 'Es', '', 'F'), K('S5', '', '', 'F'),
    K('S6', '', '', 'M', { deceased: true }), K('S7', '', '', 'F', { deathPlace: 'Ankara', birthDate: '1850' }),
    K('S8', 'Yalniz', 'Ad', 'M'), K('S9', 'Tek', 'Es', 'F', { spouses: [{ id: 'S5', status: 'x' }], children: ['S6'], mother: 'S3' }),
  ), []]);
  return out;
}
