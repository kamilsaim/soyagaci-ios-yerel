// Olaylar fixture'i: eventsBetween (+evText), upcomingEvents, notificationPlan, remSet okuma.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { webYukle as webYukleDogrudan } from '../web-ortam.mjs';

const kok = path.dirname(fileURLToPath(import.meta.url));
const HTML = path.join(kok, '..', 'kaynak', 'soy-agaci-7.0.0.html');
const J = (x) => JSON.stringify(x);

const K = (id, ad, soyad, g, o = {}) => ({
  id, firstName: ad, lastName: soyad, gender: g, birthDate: '', birthPlace: '', deathDate: '', deathPlace: '',
  occupation: '', notes: '', photo: null, gallery: [], mother: null, father: null, spouse: null, spouses: [], children: [], ...o,
});

function elleAgac() {
  const l = [
    K('L1', 'Sali', 'Artik', 'F', { birthDate: '29/02/2000' }),
    K('L2', 'Artik', 'Vefat', 'M', { birthDate: '10/10/1950', deathDate: '29/02/2004' }),
    K('L3', 'Artik', 'Eski', 'M', { birthDate: '29/02/1980', deathDate: '12/05/2020' }),
    K('Y1', 'Yalniz', 'Yil', 'M', { birthDate: '1980' }),
    K('Y2', 'Yalniz', 'OlumYili', 'F', { birthDate: '1950', deathDate: '1999' }),
    K('PH1', 'Yer', 'Tutucu', 'M', { birthDate: '01/07/1950' }),
    K('PH2', 'Yer', 'Tutucu1960', 'M', { birthDate: '01/07/1960' }),
    K('PH3', 'Yer', 'Tutucu2', 'F', { birthDate: '01/07/1955', deathDate: '01/07/2010' }),
    K('PH4', 'Yer', 'Tutucu3', 'F', { birthDate: '01/07/1959' }),
    K('PH5', 'Olum', 'Yertut', 'M', { birthDate: '14/09/1970', deathDate: '01/07/1999' }),
    K('PH6', 'Dogum', 'Tutucu', 'M', { birthDate: '1.7.1930' }),
    K('D1', 'Vefat', 'Bayrak', 'M', { birthDate: '15/03/1990', deceased: true }),
    K('D2', 'Yuz', 'Yirmi', 'F', { birthDate: '20/12/1900' }),
    K('D3', 'Yuz', 'On', 'M', { birthDate: '10/05/1916' }),
    K('D4', 'Yuz', 'Onbir', 'F', { birthDate: '11/05/1915' }),
    K('D5', 'Yerli', 'Vefat', 'M', { birthDate: '02/06/1980', deathPlace: 'Sivas' }),
    K('I1', 'Gecersiz', 'Subat31', 'M', { birthDate: '31/02/1990' }),
    K('I2', 'Gecersiz', 'Gun0', 'M', { birthDate: '00/05/1990' }),
    K('I3', 'Gecersiz', 'Ay13', 'F', { birthDate: '15/13/1990' }),
    K('I4', 'Nokta', 'Bicim', 'F', { birthDate: '30.04.1990' }),
    K('I5', 'Tire', 'Bicim', 'M', { birthDate: '5-8-1985' }),
    K('I6', 'Gecersiz', 'Gun99', 'M', { birthDate: '99/99/1990' }),
    K('I7', 'Nisan', 'Otuzbir', 'M', { birthDate: '31/04/1990' }),
    K('E1', 'Bugun', 'Bir', 'M', { birthDate: '18/11/1990' }),
    K('E2', 'Bugun', 'Iki', 'F', { birthDate: '18/11/1985' }),
    K('E3', 'Bugun', 'Vefatli', 'M', { birthDate: '18/11/1970', deathDate: '18/11/2000' }),
    K('X1', 'Noel', 'Bir', 'M', { birthDate: '25/12/1980' }),
    K('X2', 'Yilbasi', 'Oncesi', 'F', { birthDate: '31/12/1999' }),
    K('X3', 'Yilbasi', 'Sonrasi', 'F', { birthDate: '01/01/2001' }),
    K('X4', 'Yilbasi', 'Vefat', 'M', { birthDate: '02/03/1940', deathDate: '31/12/2015' }),
    K('X5', 'Yilbasi', 'Vefat2', 'M', { birthDate: '02/03/1940', deathDate: '02/01/2016' }),
    K('G1', 'Gelecek', 'Dogum', 'M', { birthDate: '10/12/2030' }),
    K('S1', 'Subat', 'Yirmisekiz', 'F', { birthDate: '28/02/1990' }),
    K('S2', 'Mart', 'Bir', 'M', { birthDate: '01/03/1990' }),
    K('V1', 'Yalniz', 'Vefat', 'M', { deathDate: '05/05/2005' }),
    K('V2', 'Hem', 'Ikisi', 'F', { birthDate: '07/07/1950', deathDate: '08/08/2008' }),
    K('V3', 'Hem', 'Ikisi2', 'F', { birthDate: '07/07/1950', deathDate: '07/07/2008' }),
    K('Q1', '<b>&"\'', 'Ad\'<i>', 'M', { birthDate: '12/12/1992' }),
    K('Q2', '', '', 'F', { birthDate: '13/12/1993' }),
    K('Q3', '  ', 'Bosluk', 'F', { birthDate: '14/12/1994' }),
  ];
  return Object.fromEntries(l.map((k) => [k.id, k]));
}

// 150 kisi: yilda 60'tan cok olay (iOS 64 sinir testi). Gun/ay dagilimi deterministik.
function yuzAgac() {
  const l = [];
  for (let i = 0; i < 150; i++) {
    const g = String((i * 7) % 28 + 1).padStart(2, '0');
    const a = String((i * 5) % 12 + 1).padStart(2, '0');
    const o = { birthDate: `${g}/${a}/${1930 + (i * 3) % 70}` };
    if (i % 4 === 0) o.deathDate = `${String((i * 11) % 28 + 1).padStart(2, '0')}/${String((i * 3) % 12 + 1).padStart(2, '0')}/${2000 + i % 25}`;
    l.push(K('Z' + (i + 1), 'Kisi' + i, 'Soy' + (i % 9), i % 2 ? 'F' : 'M', o));
  }
  return Object.fromEntries(l.map((k) => [k.id, k]));
}

const BASLAR = [
  '2026-11-18T09:00:00Z', '2026-12-25T23:30:00Z', '2026-12-31T00:00:00Z', '2027-01-01T12:00:00Z',
  '2026-07-01T00:00:00Z', '2027-02-27T10:00:00Z', '2027-02-28T00:00:00Z', '2028-02-28T08:00:00Z',
  '2028-02-29T21:15:00Z', '2026-03-01T00:00:00Z', '2027-06-15T05:00:00Z', '2029-02-26T00:00:00Z',
];
const GUNLER = [14, 30, 366];
const FILTRELER = [{}, { bdx: true }, { bd: false }, { an: false }];

export default function uret(webYukle) {
  const yedek = JSON.parse(fs.readFileSync(path.join(kok, '..', 'veri', 'soy-agaci.json'), 'utf8'));
  const agaclar = [['gercek soy-agaci', yedek.people], ['elle olaylar', elleAgac()], ['yuz elli kisi', yuzAgac()]];
  const hazir = (people, yukle = webYukle) => {
    const w = yukle();
    if (w.baslatmaHatasi) throw new Error('baslatma hatasi: ' + w.baslatmaHatasi.message);
    w.ayarla(JSON.parse(J(people)), 500);
    w.calistir('migrateData()');
    return w;
  };
  const pk = (w) => JSON.parse(w.calistir('JSON.stringify({people:people,nextId:nextId})'));
  const vakalar = [];
  // Agaclar bir kez yazilir (tur 'agac'); vakalar adlarina basvurur. Beklenen olay/plan listeleri tek satirlik JSON metni.
  const agacAd = new Map();
  for (const [ad, people] of agaclar) {
    const w = hazir(people);
    agacAd.set(ad, pk(w));
    vakalar.push({ ad: 'agac ' + ad, girdi: { tur: 'agac', ad, ...agacAd.get(ad) }, beklenen: null });
  }
  const olayJs = 'e=>({id:e.id,diff:e.diff,t:e.date.getTime(),kind:e.kind,n:e.n,d:e.d,m:e.m,text:evText(e)})';

  // ---- eventsBetween + evText ----
  for (const [ad, people] of agaclar) {
    const w = hazir(people);
    for (const baslangic of BASLAR) {
      const ms = new Date(baslangic).getTime();
      for (const gun of GUNLER) {
        for (const f of FILTRELER) {
          const sonuc = JSON.parse(w.calistir(`JSON.stringify(eventsBetween(new Date(${ms}),${gun},${J(f)}).map(${olayJs}))`));
          vakalar.push({
            ad: `eventsBetween ${ad} ${baslangic} ${gun}g ${J(f)}`,
            girdi: { tur: 'eventsBetween', agac: ad, from: ms, days: gun, opt: f },
            beklenen: J(sonuc),
          });
        }
      }
    }
  }

  // ---- upcomingEvents (ayar localStorage'dan) ----
  const ayarlar = ['', '{}', '{"bd":false}', '{"an":false}', '{"bd":false,"an":false}', '{"lead":7,"alert":false}'];
  for (const [ad, people] of agaclar) {
    const w = hazir(people);
    for (const ham of ayarlar) {
      for (const gun of [7, 14, 45]) {
        w.calistir(ham ? `localStorage.setItem('sa4_remset',${J(ham)})` : `localStorage.removeItem('sa4_remset')`);
        const sonuc = JSON.parse(w.calistir(`JSON.stringify(upcomingEvents(${gun}).map(${olayJs}))`));
        vakalar.push({
          ad: `upcomingEvents ${ad} ${ham || '(yok)'} ${gun}g`,
          girdi: { tur: 'upcoming', agac: ad, ayarHam: ham, days: gun },
          beklenen: J(sonuc),
        });
      }
    }
  }

  // ---- remSet okuma ----
  {
    const w = hazir({});
    const hamlar = [null, '', '{}', '{"lead":3}', '{"bd":false,"an":false,"lead":0,"alert":false}', '{"lead":7,"extra":1}', 'bozuk{', '[]', 'null', '{"lead":"3"}', '{"bd":0}', '{"lead":2.5}'];
    for (const ham of hamlar) {
      w.calistir(ham === null ? `localStorage.removeItem('sa4_remset')` : `localStorage.setItem('sa4_remset',${J(ham)})`);
      const s = JSON.parse(w.calistir('JSON.stringify(remSet())'));
      vakalar.push({ ad: 'remSet ' + J(ham), girdi: { tur: 'remSet', ham }, beklenen: s });
    }
  }

  // ---- notificationPlan ----
  const SIMDILER = ['2026-11-18T09:00:00Z', '2026-12-25T23:30:00Z', '2027-02-27T10:00:00Z', '2028-02-28T08:00:00Z', '2026-07-01T00:00:00Z'];
  for (const simdi of SIMDILER) {
    for (const [ad, people] of agaclar) {
      const w = hazir(people, () => webYukleDogrudan(HTML, { simdi }));
      const ms = new Date(simdi).getTime();
      const calis = (bd, an, lead, saat) => {
        w.calistir(`localStorage.setItem('sa4_remset',${J(J({ bd, an, lead, alert: true }))})`);
        return JSON.parse(w.calistir(
          `JSON.stringify(notificationPlan(${saat == null ? '' : saat}).map(n=>({id:n.id,at:n.at.getTime(),title:n.title,body:n.body,personId:n.personId})))`));
      };
      const ekle = (bd, an, lead, saat) => {
        vakalar.push({
          ad: `plan ${ad} ${simdi} bd=${bd} an=${an} lead=${lead} saat=${saat}`,
          girdi: { tur: 'plan', agac: ad, simdi: ms, ayar: { bd, an, lead, alert: true }, saat },
          beklenen: J(calis(bd, an, lead, saat)),
        });
      };
      for (const lead of [0, 1, 3, 7]) ekle(true, true, lead, 9);
      ekle(true, false, 1, 9); ekle(false, true, 3, 9); ekle(false, false, 1, 9);
      ekle(true, true, 1, 0); ekle(true, true, 0, 23); ekle(true, true, 7, 15);
      vakalar.push({
        ad: `plan ${ad} ${simdi} varsayilan saat`,
        girdi: { tur: 'plan', agac: ad, simdi: ms, ayar: { bd: true, an: true, lead: 1, alert: true }, saat: null },
        beklenen: J(calis(true, true, 1, null)),
      });
    }
  }
  return { vakalar };
}
