// Istatistik fixture'i: renderStats (web l.2751) + genDepth (l.3946) + renderHome (l.3952) sayilari.
// Yontem: renderStats.toString() govdesi alinir, `const BC=[` satirindan sonrasi (HTML kurma) atilip yerine
// hesaplanan yerel degiskenleri donduren `return {...}` konur. Ad alanlari `esc(pname(p))` yerine ham `pname(p)`
// olur (Swift tarafi ham ad tutar; kacis arayuzun isi). Bos agacta orijinal `return;` kalir -> null.
// Ek olarak orijinal renderStats calistirilip #stCont innerHTML'indeki etiket+sayilar dogrulanir.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const veriDizini = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'veri');
const J = (x) => JSON.stringify(x);

const K = (id, ad, soyad, g, o = {}) => ({
  id, firstName: ad, lastName: soyad, gender: g, birthDate: '', birthPlace: '', deathDate: '', deathPlace: '',
  occupation: '', notes: '', photo: null, gallery: [], mother: null, father: null, spouse: null, spouses: [], children: [], ...o,
});

// Kenar vakalar: tarihsiz, yalniz yil, 110+ olumsuz, vefat bayragi, gecersiz gunler, yaklasan dogum gunleri (bugun 18/11/2026)
function elle() {
  const l = [
    K('A1', 'Ali Riza', 'Yilmaz', 'M', { birthDate: '12/03/1920', deathDate: '01/01/2005', birthPlace: 'Sivas, Merkez', photo: 'u/a.jpg', gallery: ['u/g1.jpg', 'u/g2.jpg'] }),
    K('A2', 'Ayse', 'Yilmaz', 'F', { birthDate: '1925', deathDate: '1990', birthPlace: ' Sivas ', mother: 'A9', father: 'A1' }),
    K('A3', 'Hasan', 'Kaya', 'M', { birthDate: '1950', deathDate: '2030', birthPlace: 'Ankara' }),
    K('A4', 'Mehmet', 'Kaya', 'M', { birthDate: '1960', deathDate: '1960' }),
    K('A5', 'Veli', 'Kaya', 'M', { birthDate: '1970', deathDate: '1950' }),
    K('A6', 'Ali', 'Demir', 'M', { birthDate: '1900' }),
    K('A7', 'Fatma', 'Demir', 'F', { birthDate: '1890', deceased: true }),
    K('A8', 'Zeynep', 'Demir', 'F', { birthDate: '1980', deceased: true }),
    K('A9', 'Hatice', '', 'F', { birthDate: '1900', deathPlace: 'Konya', mother: 'A10', father: 'A1' }),
    K('A10', '', '', 'F', { birthPlace: ',Bos' }),
    K('A11', ' Bosluk', 'Soy ad', 'M', { birthDate: '0000', birthPlace: 'Ankara, Cankaya' }),
    K('A12', 'Kisi', 'Kaya', '', { birthDate: 'dogum 1999 yili' }),
    K('A13', 'X', 'Kaya', 'M', { birthDate: '1985', birthPlace: 'Mus', gallery: ['u/g3.jpg'] }),
    K('B1', 'Bugun', 'Dogum', 'M', { birthDate: '18/11/1990' }),
    K('B2', 'Yarin', 'Dogum', 'F', { birthDate: '19/11/1991' }),
    K('B3', 'Otuz', 'Gun', 'M', { birthDate: '18.12.1980' }),
    K('B4', 'Otuzbir', 'Gun', 'M', { birthDate: '19-12-1980' }),
    K('B5', 'Kasim', 'Otuzbir', 'F', { birthDate: '31/11/1990' }),
    K('B6', 'Subat', 'Otuzbir', 'F', { birthDate: '31/02/1990' }),
    K('B7', 'Subat', 'Yirmidokuz', 'F', { birthDate: '29/02/2000' }),
    K('B8', 'Yer', 'Tutucu', 'M', { birthDate: '01/07/1950' }),
    K('B9', 'Dunku', 'Dogum', 'M', { birthDate: '17/11/1990' }),
    K('B10', 'Ayni', 'Gun', 'F', { birthDate: '25/11/1988' }),
    K('B11', 'Ayni', 'Gun2', 'M', { birthDate: '25-11-1970' }),
    K('B12', 'Gecersiz', 'Ay', 'M', { birthDate: '15/13/1990' }),
    K('B13', 'Vefatli', 'Dogum', 'M', { birthDate: '20/11/1960', deathDate: '2001' }),
    K('B14', 'Bayrakli', 'Dogum', 'M', { birthDate: '21/11/1960', deceased: true }),
    K('B15', 'Eski', 'Yuz', 'M', { birthDate: '22/11/1900' }),
    K('B16', 'Bosluklu', 'Tarih', 'F', { birthDate: ' 23/11/1995 ' }),
    K('B17', 'Gelecek', 'Kisi', 'F', { birthDate: '24/11/2030' }),
    K('B18', 'Yilsonu', 'Yil', 'F', { birthDate: '31/12/1990' }),
    K('B19', 'Yilbasi', 'Yil', 'F', { birthDate: '01/01/1990' }),
  ];
  return Object.fromEntries(l.map((k) => [k.id, k]));
}

// Tek vefat edene sahip agac (oldest == youngest) + dongu
function tekOlu() {
  const l = [
    K('T1', 'Tek', 'Olu', 'M', { birthDate: '1900', deathDate: '1980', father: 'T2' }),
    K('T2', 'Dongu', 'Olu', 'M', { birthDate: '1930', father: 'T1', mother: 'T3' }),
    K('T3', 'Dongu', 'Es', 'F', { birthDate: '1935', mother: 'T2' }),
    K('T4', 'Cocuk', 'Olu', 'M', { father: 'T2', mother: 'T3' }),
  ];
  return Object.fromEntries(l.map((k) => [k.id, k]));
}

// Ayni yas / esit sayim baglari (kararli siralama)
function esit() {
  const l = [];
  const adlar = ['Ali', 'Veli', 'Can', 'Deniz', 'Efe', 'Gul', 'Hale', 'Ilke', 'Jale', 'Kemal'];
  const yerler = ['Sivas', 'Ankara', 'Bursa', 'Izmir', 'Konya', 'Rize', 'Van', 'Adana', 'Mus', 'Edirne'];
  for (let i = 0; i < 20; i++) {
    l.push(K('E' + i, adlar[i % 10], 'S' + (i % 8), i % 2 ? 'F' : 'M', {
      birthDate: String(1900 + (i % 5) * 10), deathDate: i % 2 ? '' : String(1900 + (i % 5) * 10 + 70),
      birthPlace: yerler[i % 10] + ', X',
    }));
  }
  return Object.fromEntries(l.map((k) => [k.id, k]));
}

const ENTRY_JS = 'e=>({id:e.id,diff:e.diff,kind:e.kind,n:e.n,d:e.d,m:e.m})';

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
  agaclar['soy-agaci'] = goruntu(kurW(yedek.people, yedek.nextId));
  { const w = taze(); w.ctx.__t = heritage; w.calistir('parseGED(__t,false)'); agaclar.heritage = goruntu(w); }
  agaclar.bos = { people: {}, nextId: 1 };
  agaclar.elle = goruntu(kurW(elle(), 100));
  agaclar.tekOlu = goruntu(kurW(tekOlu(), 100));
  agaclar.esit = goruntu(kurW(esit(), 100));

  const vakalar = [];
  for (const ad of Object.keys(agaclar)) vakalar.push({ ad: 'agac ' + ad, girdi: { tur: 'agac', agac: ad }, beklenen: agaclar[ad] });

  const ayarlar = [null, J({ bd: false, an: true, lead: 1, alert: true }), J({ bd: true, an: false, lead: 3, alert: false })];

  // renderStats govdesini donusturur
  const w0 = taze();
  const kaynak = w0.calistir('renderStats.toString()');
  const kes = kaynak.indexOf('const BC=[');
  if (kes < 0) throw new Error('renderStats: BC bulunamadi');
  let govde = kaynak.slice(0, kes);
  for (const [eski, yeni] of [['name:esc(pname(p))', 'name:pname(p)'], ['nm:esc(pname(p))', 'nm:pname(p)']]) {
    if (!govde.includes(eski)) throw new Error('renderStats: ' + eski + ' yok');
    govde = govde.replace(eski, yeni);
  }
  const donusmus = govde + 'return {total,males,females,living,withPhoto,totPh,gens,avgLife,avgAlive,oldest,youngest,topNames,sd,topL,topS,upcomingBD};}';

  const sayilar = (html) => {
    const m = {};
    for (const x of html.matchAll(/<div class="sn">([^<]*)<\/div><div class="sl">([^<]*)<\/div>/g)) m[x[2]] = x[1];
    return m;
  };

  for (const ad of Object.keys(agaclar)) {
    const w = taze();
    w.ayarla(JSON.parse(J(agaclar[ad].people)), agaclar[ad].nextId);
    for (const ham of ayarlar) {
      w.calistir(ham ? `localStorage.setItem('sa4_remset',${J(ham)})` : `localStorage.removeItem('sa4_remset')`);
      const st = JSON.parse(w.calistir(`JSON.stringify(((${donusmus}))())`) ?? 'null');
      const bos = st === null;
      // orijinal renderStats ile dogrulama (etiket -> sayi)
      w.calistir('renderStats()');
      const html = w.ogeler.get('stCont').innerHTML;
      if (bos) {
        if (!html.includes('Veri yok')) throw new Error(ad + ': bos agacta Veri yok metni yok');
      } else {
        const s = sayilar(html);
        const bekle = { 'Toplam Kişi': st.total, Hayatta: st.living, Erkek: st.males, Kadın: st.females };
        if (st.withPhoto) { bekle['Fotoğraflı'] = st.withPhoto; bekle['Toplam Fotoğraf'] = st.totPh; }
        if (st.gens) bekle['Kuşak'] = st.gens;
        if (st.avgLife !== null) bekle['Ortalama Ömür (vefat)'] = st.avgLife;
        if (st.avgAlive !== null) bekle['Ortalama Yaş (yaşayan)'] = st.avgAlive;
        for (const [e, v] of Object.entries(bekle)) if (s[e] !== String(v)) throw new Error(`${ad}: ${e} html=${s[e]} donusmus=${v}`);
        if (Object.keys(s).length !== Object.keys(bekle).length) throw new Error(ad + ': beklenmeyen karo ' + J(s));
      }
      const home = JSON.parse(w.calistir(`JSON.stringify({n:Object.keys(people).length,genDepth:genDepth(),ev:upcomingEvents(60).map(${ENTRY_JS})})`));
      vakalar.push({
        ad: `ozet ${ad} ${ham || '(yok)'}`,
        girdi: { tur: 'ozet', agac: ad, ayarHam: ham },
        beklenen: { bos, stats: st, home },
      });
    }
  }
  return { vakalar };
}
