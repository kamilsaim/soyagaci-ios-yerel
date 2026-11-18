// Mukerrer fixture'i: mergePeople(keep, drop). (findDupes Task 7'de eklenecek.)
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
  return { vakalar };
}
