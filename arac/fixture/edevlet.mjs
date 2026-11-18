// e-Devlet donusturucu fixture'i: EDV (soy-agaci-7.0.0.html l.3566-3939) ic fonksiyonlari.
// Web'de yalniz fromText/analyze/buildGedcom/titleCase disari acik; IIFE govdesi ayri vm baglaminda
// "return {...}" tum ic fonksiyonlari verecek sekilde yeniden derlenir (govde AYNEN; yalniz donus nesnesi degisir).
// Girdi dosyalari repo disinda: ../../.. (soyagaci kok) ya da EDEVLET_GIRDI ortam degiskeni. Yalniz turetilen izgaralar gomulur.
// xlsx: SheetJS (node_modules) sheet_to_json(header:1, defval:'') + donusturucunun cellToStr'u.
// docx: donusturucunun KENDI unzipEntry + docxToGrid kodu (html'den alinir; Node'un DecompressionStream'i + jsdom DOMParser).
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const kok = path.dirname(fileURLToPath(import.meta.url));
const HTML = path.join(kok, '..', 'kaynak', 'soy-agaci-7.0.0.html');
const girdiDizini = process.env.EDEVLET_GIRDI || path.join(kok, '..', '..', '..');
const DONUSTURUCU = path.join(girdiDizini, 'edevlet-gedcom.html');
const require = createRequire(import.meta.url);

const SIMDI = new Date('2026-11-18T09:00:00Z').getTime();

function edvYukle() {
  const satirlar = fs.readFileSync(HTML, 'utf8').split(/\r?\n/);
  const bas =satirlar.findIndex((s) => s.startsWith('const EDV=(()=>{'));
  let son = -1;
  for (let i = bas; i < satirlar.length; i++) if (satirlar[i] === '})();') { son = i; break; }
  if (bas < 0 || son < 0) throw new Error('EDV bulunamadi');
  let kod = satirlar.slice(bas, son + 1).join('\n');
  const r = kod.lastIndexOf('return {');
  kod = kod.slice(0, r) + 'return { titleCase, fold, textToGrid, gridToPersons, relTokens, analyze, pdfItemsToGrid, buildGedcom, gedDate, normMedi };\n})();\nEDV;';
  const GercekDate = Date;
  function SabitDate(...a) {
    if (!new.target) return new GercekDate(SIMDI).toString();
    return a.length === 0 ? new GercekDate(SIMDI) : new GercekDate(...a);
  }
  SabitDate.prototype = GercekDate.prototype; SabitDate.now = () => SIMDI; SabitDate.UTC = GercekDate.UTC; SabitDate.parse = GercekDate.parse;
  const ctx = vm.createContext({ Date: SabitDate, console });
  return vm.runInContext(kod, ctx);
}

// Donusturucudeki docx okuyucusu (html'den kelimesi kelimesine)
async function docxOku(dosya) {
  const html = fs.readFileSync(DONUSTURUCU, 'utf8');
  const kes = (ad, asenkron) => {
    const bas = html.indexOf((asenkron ? 'async function ' : 'function ') + ad + '(');
    const son = html.indexOf('\n}\n', bas) + 2;
    return html.slice(bas, son);
  };
  const { JSDOM } = require('jsdom');
  const { DOMParser } = new JSDOM('').window;
  const fab = new Function('DOMParser', 'DecompressionStream', 'Blob', 'Response', 'TextDecoder',
    kes('unzipEntry', true) + '\n' + kes('docxToGrid', false) + '\nreturn {unzipEntry, docxToGrid};');
  const { unzipEntry, docxToGrid } = fab(DOMParser, DecompressionStream, Blob, Response, TextDecoder);
  const buf = new Uint8Array(fs.readFileSync(dosya));
  return docxToGrid(await unzipEntry(buf, 'word/document.xml'));
}

function cellToStr(v) { // donusturucu l.239
  if (v === null || v === undefined) return '';
  if (v instanceof Date) {
    if (isNaN(v.getTime())) return '';
    return `${String(v.getDate()).padStart(2, '0')}/${String(v.getMonth() + 1).padStart(2, '0')}/${v.getFullYear()}`;
  }
  return String(v);
}

let maskelenen = 0;
const maskele = (g) => g.map((r) => r.map((c) => String(c).replace(/(?<!\d)\d{11}(?!\d)/g, () => { maskelenen++; return '00000000000'; })));

function xlsxOku(dosya) {
  const XLSX = require('xlsx');
  const wb = XLSX.readFile(dosya, { cellDates: true });
  return XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { header: 1, defval: '' }).map((r) => r.map(cellToStr));
}

const K = (sira, cins, rel, givn, surn, baba = '', ana = '', o = {}) => ({
  sira, cinsiyet: cins, relationship: rel, givn, surn, babaAdi: baba, anaAdi: ana, birthPlace: '', birthDate: '',
  il: '', ilce: '', mahalle: '', cilt: '', hane: '', birey: '', medeniHal: '', status: 'sağ', deathDate: '', ...o,
});

export default async function uret() {
  for (const f of ['edevlet-gedcom.html', 'soyagaci.xlsx', 'kamilsoyagaci.docx', 'mustafa saim soy.xlsx']) {
    if (!fs.existsSync(path.join(girdiDizini, f))) {
      console.warn(`UYARI: e-Devlet girdisi yok (${path.join(girdiDizini, f)}); edevlet fixture'i atlandi (EDEVLET_GIRDI ile belirtin).`);
      return null;
    }
  }
  const E = edvYukle();
  const J = (x) => JSON.parse(JSON.stringify(x)); // undefined alanlari at
  const dosyalar = [
    ['soyagaci.xlsx', () => xlsxOku(path.join(girdiDizini, 'soyagaci.xlsx'))],
    ['kamilsoyagaci.docx', () => docxOku(path.join(girdiDizini, 'kamilsoyagaci.docx'))],
    ['mustafa saim soy.xlsx', () => xlsxOku(path.join(girdiDizini, 'mustafa saim soy.xlsx'))],
  ];
  const izgaralar = [];
  for (const [ad, oku] of dosyalar) izgaralar.push([ad, maskele(await oku())]);
  console.error('T.C. kimlik maskelenen hucre sayisi:', maskelenen);

  const vakalar = [];
  const ekle = (ad, girdi, beklenen) => vakalar.push({ ad, girdi, beklenen });

  // ---- 1) textToGrid ----
  const duzMetin = (g) => g.map((r) => r.join('\t')).join('\n');
  const metinler = izgaralar.map(([ad, g]) => ['duz metin ' + ad, duzMetin(g)]);
  const baslik = 'Sıra\tC\tYakınlık Derecesi\tAdı\tSoyadı\tBaba Adı\tAna Adı\tDoğum Yeri ve Tarihi\tİl-İlçe-Mahalle/Köy\tCilt-Hane-Birey Sıra No\tMedeni Hali\tDurumu';
  metinler.push(
    ['telefon: hucre ici satir sonlari', baslik + '\n1\tE\tKendisi\tALİ\tKAYA\tVELİ\tAYŞE\tSİVAS\n01/02/1950\tSivas/\nMerkez\n2-3-4\tEvli\tSağ\n2\tK\tKendisinin Eşi\tFATMA\tKAYA\tHASAN\tZEYNEP\tANKARA\n05/05/1955\tAnkara/\nÇankaya\tEvli\tSağ'],
    ['crlf + bos satirlar + aciklama', '\r\nBaşlık satırı\r\n\r\n 7\tE\tKendisi\tAD\tSOY\r\n\r\ncontinuation\tx\r\n8\tK\tEşi\r\n\r\nAÇIKLAMALAR\r\nbir şey'],
    ['sadece baslik', 'Sıra\tC'],
    ['bos', ''],
    ['numarasiz', 'abc\tdef\nghi'],
    ['bosluk numarali', '  12\tx\ty\n\t\tdevam\n 13\tz'],
  );
  for (const [ad, m] of metinler) ekle('metin: ' + ad, { tur: 'metin', metin: m }, { izgara: J(E.textToGrid(m)) });

  // ---- 2) gridToPersons ----
  const bas12 = ['Sıra', 'C', 'Yakınlık Derecesi', 'Adı', 'Soyadı', 'Baba Adı', 'Ana Adı', 'Doğum Yeri ve Tarihi', 'İl-İlçe-Mahalle/Köy', 'Cilt-Hane-Birey Sıra No', 'Medeni Hali', 'Durumu'];
  const kenarIzgaralar = [
    ['kisa satirlar ve eksik hucreler', [bas12, ['1', 'E', 'Kendisi', 'ali', 'kaya'], ['', '', '', '', '', '', '', '01.02.1950'], ['2', 'k', 'Eşi', 'AYŞE', '-', '-', '-']]],
    ['fazla sutun tabloyu bitirir', [bas12, ['1', 'E', 'Kendisi', 'ALİ', 'KAYA', 'VELİ', 'AYŞE', 'SİVAS', 'Sivas/', '1-2-3', 'Evli', 'Sağ'], ['', '', '', '', '', '', '', '01-02-1950'], ['', '', '', '', 'açıklama'], ['', '', '', '', '', '', '', '03/04/1990'], ['2', 'E', 'Oğlu', 'MEHMET', 'KAYA']]],
    ['13. sutun dolu devam satiri', [['1', 'E', 'Kendisi', 'A', 'B', '', '', '', '', '', '', '', ''], ['', '', '', '', '', '', '', '', '', '', '', '', 'x'], ['', '', '', '', '', '', '', '01/01/1990']]],
    ['aciklama satiri ve basliksiz', [['Not: bu bir açıklama'], ['x', 'y'], ['3', 'K', 'Kızı', 'ZEYNEP', 'KAYA', 'ALİ', 'FATMA', 'ANKARA', 'Ankara/ ', 'Çankaya/', 'Mah. Ev', '9-8-7', 'Boşanmış', 'Ölüm'], ['', '', '', '', '', '', '', '30/07/2003', '', '', '', '', ''], ['', '', '', '', '', '', '', '', '', '', '', 'Ölüm', '12/12/2012']]],
    ['durum ve medeni hal cesitleri', [
      ['1', 'E', 'Kendisi', 'A', 'B', '', '', '', '', '', 'DUL', 'VEFAT'],
      ['2', 'K', 'Eşi', 'C', 'D', '', '', '', '', '', 'bekar', 'sağ'],
      ['3', 'K', 'Kızı', 'E', 'F', '', '', '', '', '', 'Boşanmış', 'ÖLÜM'],
      ['4', 'E', 'Oğlu', 'G', 'H', '', '', '', '', '', 'bilinmez', 'Olum'],
      ['5', 'e', 'Oğlu', 'İ', 'J', '', '', '', '', '', 'Evli', '-']]],
    ['adsiz kayitlar elenir + dogum satirlari', [['1', 'E', 'Kendisi', '', ''], ['2', 'E', 'Oğlu', '', 'SOY'], ['3', 'K', 'Kızı', 'AD', ''], ['', '', '', '', '', '', '', 'Yeşilhisar', '', '', '', ''], ['', '', '', '', '', '', '', '1/2/1999', '', '', '', ''], ['', '', '', '', '', '', '', '', '', '1-2', '', '']]],
    ['bosluk ve satir sonlari', [['  1 ', ' K ', ' Kendisinin   Eşi ', 'MARY\nANN', ' DOE ', ' - ', 'X  Y', 'Köy\n05/06/1970', 'Kayseri/\nYeşilhisar/\nKELER  MAH.', ' 6 - 43 - 1 ', 'evli', 'Ölüm\n\n01/07/1941']]],
    ['bos satirlar', [[], ['1', 'E', 'Kendisi', 'A', 'B'], [], ['', '', '', '', '', '', '', '', '', '', '', '']]],
    ['sira basamaklari', [['007', 'E', 'Kendisi', 'A', 'B'], ['08x', 'E', 'Oğlu', 'C', 'D'], ['9', 'E', 'Oğlu', 'E', 'F']]],
  ];
  const tumIzgara = [...izgaralar.map(([ad, g]) => ['dosya ' + ad, g]), ...kenarIzgaralar];
  for (const [ad, g] of izgaralar) {
    // metin yolundan gelen izgara da (telefon yapistirmasi): web davranisi neyse o kaydedilir
    tumIzgara.push(['metin yolu ' + ad, E.textToGrid(duzMetin(g))]);
  }
  for (const [ad, g] of tumIzgara) ekle('kisiler: ' + ad, { tur: 'kisiler', izgara: g }, { kisiler: J(E.gridToPersons(g)) });

  // ---- 3) analyze ----
  const analizSerisi = (kisiler) => {
    const a = E.analyze(kisiler);
    const idx = (n) => a.nodes.indexOf(n);
    const ata = (q) => (q ? (q.ghost ? { tur: 'hayali', anahtar: q.key, ad: q.name, cins: q.sex, cocuk: idx(q.child) } : { tur: 'dugum', i: idx(q) }) : null);
    return J({
      dugumler: a.nodes.map((n) => ({ sira: n.p.sira, yol: n.path, cins: n.sex, ad: n.given, tok: n.toks, baba: ata(n.father), anne: ata(n.mother) })),
      uyarilar: a.warns,
    });
  };
  const kisiListeleri = izgaralar.map(([ad, g]) => ['dosya ' + ad, E.gridToPersons(g)]);
  kisiListeleri.push(
    ['taninmayan ve yinelenen yakinlik', [K(1, 'E', 'Kendisi', 'ALİ', 'KAYA', 'VELİ', 'AYŞE'), K(2, 'K', 'Kendisinin Eşi', 'FATMA', 'KAYA'), K(3, 'E', 'Amcası', 'HASAN', 'KAYA'), K(4, 'E', 'Babası', 'VELİ', 'KAYA'), K(5, 'E', 'Babası', 'VELİ', 'KAYA'), K(6, 'K', 'Annesi', 'AYŞE', 'DEMİR', 'MEHMET', 'ZEHRA')]],
    ['kendisi yok', [K(1, 'E', 'Babası', 'VELİ', 'KAYA'), K(2, 'E', 'Oğlu', 'MEHMET', 'KAYA', 'VELİ'), K(3, 'K', 'Eşi', 'X', 'Y')]],
    ['cocuk ebeveyni belirsiz', [K(1, 'E', 'Kendisi', 'ALİ', 'KAYA'), K(2, 'E', 'Oğlu', 'MEHMET', 'KAYA', 'ALİ', 'FATMA'), K(3, 'K', 'Oğlunun Kızı', 'ZEYNEP', 'KAYA', 'SELİM', 'AYŞE'), K(4, 'K', 'Oğlunun Oğlu', 'EMRE', 'KAYA', 'YOK', 'YOK'), K(5, 'E', 'Oğlunun Oğlu', 'CAN', 'KAYA', 'MEHMET', 'AYŞE')]],
    ['torun ve es yollari', [K(1, 'K', 'Kendisi', 'AYŞE', 'KARA', 'VELİ', 'ZEHRA'), K(2, 'E', 'Eşi', 'ALİ', 'KARA', 'HASAN', 'EMİNE'), K(3, 'E', 'Oğlu', 'MEHMET', 'KARA', 'ALİ', 'AYŞE'), K(4, 'K', 'Kızı', 'FATMA', 'KARA', 'ali', 'ayşe'), K(5, 'E', 'Torunu', 'CAN', 'KARA', 'MEHMET', 'GÜL'), K(6, 'K', 'Oğlunun Çocuğu', 'ELİF', 'KARA', 'MEHMET', 'GÜL'), K(7, 'K', 'Kızının Çocuğu', 'ELA', 'DEMİR', 'MURAT', 'FATMA'), K(8, 'K', 'Eşinin Annesi', 'EMİNE', 'ÖZ'), K(9, 'E', 'Babasının Babası', 'HASAN', 'KARA', 'ZEKİ', 'HALİME'), K(10, 'E', 'Babasının Babasının Babası', 'ZEKİ', 'KARA', 'ZEKİ', '')]],
    ['isim uyusmazligi', [K(1, 'E', 'Kendisi', 'ALİ', 'KAYA', 'VELİ', 'AYŞE'), K(2, 'E', 'Babası', 'MUSTAFA', 'KAYA', '', 'ZEHRA'), K(3, 'K', 'Annesi', 'AYSEL', 'KAYA', 'MEHMET', '')]],
    ['turkce harf katlama', [K(1, 'E', 'Kendisi', 'ışık', 'KAYA', 'İSMAİL', 'ıSPARTA'), K(2, 'E', 'Babası', 'ISMAIL', 'KAYA'), K(3, 'K', 'Annesi', 'ısparta', 'X')]],
    ['es kendisinin cocugu adla', [K(1, 'E', 'Kendisi', 'ALİ', 'K'), K(2, 'K', 'Eşi', 'AYŞE', 'K'), K(3, 'E', 'Oğlu', 'C', 'K', 'ALİ', 'AYŞE'), K(4, 'E', 'Oğlu', 'D', 'K', 'ALİ', 'MEDİHA')]],
    ['cocugun cocugu belirsiz', [K(1, 'E', 'Kendisi', 'ALİ', 'KAYA'), K(2, 'E', 'Oğlu', 'MEHMET', 'KAYA', 'ALİ'), K(3, 'E', 'Oğlu', 'HASAN', 'KAYA', 'ALİ'), K(4, 'K', 'Oğlunun Kızı', 'ZEYNEP', 'KAYA', 'SELİM', 'AYŞE'), K(5, 'E', 'Oğlunun Oğlu', 'CAN', 'KAYA', 'MEHMET')]],
    ['bos', []],
  );
  for (const [ad, l] of kisiListeleri) ekle('analiz: ' + ad, { tur: 'analiz', kisiler: l }, J(analizSerisi(l)));

  // ---- 4) buildGedcom ----
  const hepsiAcik = { tc: true, ghost: true, maiden: true, note: true };
  const hepsiKapali = { tc: false, ghost: false, maiden: false, note: false };
  const gedKisiler = [...kisiListeleri];
  gedKisiler.push(
    ['tarih ve yer cesitleri', [
      K(1, 'E', 'Kendisi', 'ali veli', 'kaya', 'MEHMET', 'AYŞE', { birthPlace: 'sivas', birthDate: '01/07/1950', il: 'Sivas', ilce: 'Merkez', mahalle: 'Köy', cilt: '1', hane: '2', birey: '3', medeniHal: 'bekar', status: 'ölüm', deathDate: '01/07/2000' }),
      K(2, 'K', 'Kendisinin Eşi', 'aysel', 'demir', '', '', { birthPlace: 'Merkez', birthDate: '01/07/1959', il: 'Sivas', ilce: 'Merkez', medeniHal: 'evli', status: 'ölüm' }),
      K(3, 'K', 'Kızı', 'zeynep', 'öz', 'ali veli', 'aysel', { birthPlace: 'Sivas', birthDate: '01/07/1960', il: 'Sivas', ilce: 'Merkez', status: 'ölüm', deathDate: '5.6.2010' }),
      K(4, 'E', 'Oğlu', 'can', 'kaya', 'ali veli', 'aysel', { birthPlace: 'Ankara', birthDate: '32/13/1990', il: 'Sivas', status: 'ölüm', deathDate: 'bilinmiyor' }),
      K(5, 'K', 'Kızı', 'elif', 'kaya', 'ali veli', 'aysel', { birthDate: '0950', medeniHal: 'dul', hane: '7', cilt: '1', birey: '2', il: 'A', ilce: 'B', mahalle: 'C D' }),
      K(6, 'E', 'Babası', 'mehmet', 'kaya', 'zeki', 'halime', { birthDate: '1/7/1900' }),
      K(7, 'K', 'Annesi', 'ayşe', 'çelik', 'musa', 'gül', { birthDate: '12.01.1925', medeniHal: 'boşanmış', status: 'ölüm' }),
    ]],
    ['sade kendisi', [K(1, 'E', 'Kendisi', 'ISPARTALI', 'IŞIK', 'İBRAHİM', 'ISIL', { birthDate: '02/03/1980' })]],
  );
  for (const [ad, l] of gedKisiler) {
    for (const [oad, o] of [['varsayilan', undefined], ['hepsi acik', hepsiAcik], ['hepsi kapali', hepsiKapali], ['yalniz tc', { tc: true, ghost: false, maiden: false, note: false }], ['yalniz hayali+not', { tc: false, ghost: true, maiden: false, note: true }]]) {
      ekle(`gedcom: ${ad} / ${oad}`, { tur: 'gedcom', kisiler: l, secenek: o ?? null }, { ged: E.buildGedcom(l, o) });
    }
  }

  // ---- 5) relTokens ----
  const rels = ['Kendisi', 'Babası', 'Annesi', 'Anası', 'Ana', 'Anasının', 'Annesinin Annesinin Annesinin Babası', 'Oğlu', 'Oğlunun Kızı', 'Kızı', 'Kızının Çocuğu', 'Çocuğu', 'Torunu', 'Eşi', 'Kendisinin Eşi', 'Esi', 'OĞLU', 'ÇOCUĞU', 'KIZI', 'Eşinin Babası', 'Ogl', 'Kiz', 'Cocugu', 'Amcası', 'Kardeşi', '', '   ', 'Babasının  Annesi', 'ANNESİ', 'İKİZ', 'Anne', 'Anneannesi', 'Babaannesi', 'torunun'];
  for (const r of rels) ekle('reltok: ' + JSON.stringify(r), { tur: 'reltok', rel: r }, { tok: J(E.relTokens(r)) });

  // ---- 6) titleCase + gedDate ----
  const adlar = ['', 'ali veli', 'İSMAİL', 'ISPARTA', 'ışık', "o'brien", 'mary-ann smith', '  baş  boşluk', 'çağrı ÖZ', 'ĞÜŞİÖÇ', 'iİıI', 'x-', "-'a", 'abc  def', 'ǆ', 'ß test', 'ali\tveli', '😀 emoji'];
  for (const a of adlar) ekle('titleCase: ' + JSON.stringify(a), { tur: 'titleCase', s: a }, { s: E.titleCase(a) });
  const tarihler = ['', '01/07/1950', '1/7/1959', '01/07/1960', '1.7.1900', '5-6-2010', '30/07/2003', '12/13/2003', '00/00/1999', '32/01/1990', ' 01/01/1990 ', '1990', 'bilinmiyor', '01/07/0950', '01/07/0001', '31/12/9999', '1/2/99'];
  for (const t of tarihler) ekle('gedDate: ' + JSON.stringify(t), { tur: 'gedDate', s: t }, { s: E.gedDate(t) });

  // ---- 7) pdfItemsToGrid (yapay pdf.js ogeleri) ----
  const toplam = (g) => { // izgaradan kayit: devam satirlari hucrelerde '\n' ile birlesir
    const kayitlar = [];
    for (const r of g.slice(1)) {
      if (/^\d+$/.test(String(r[0]).trim())) kayitlar.push(r.map((c) => String(c)));
      else if (kayitlar.length) r.forEach((c, i) => { if (String(c).trim()) kayitlar[kayitlar.length - 1][i] = (kayitlar[kayitlar.length - 1][i] ? kayitlar[kayitlar.length - 1][i] + '\n' : '') + c; });
    }
    return kayitlar;
  };
  const x0 = [30, 62, 90, 390, 460, 530, 600, 670, 780, 890, 990, 1080];
  const H = 8, KAR = 4.2;
  const baslikParcalari = [['Sıra'], ['C'], ['Yakınlık', 'Derecesi'], ['Adı'], ['Soyadı'], ['Baba', 'Adı'], ['Ana', 'Adı'], ['Doğum', 'Yeri', 've', 'Tarihi'], ['İl-İlçe-Mahalle/Köy'], ['Cilt-Hane-Birey', 'Sıra', 'No'], ['Medeni', 'Hali'], ['Durumu']];
  const parca = (str, x, y, h = H) => ({ str, x: +x.toFixed(2), y: +y.toFixed(2), w: +(str.length * KAR).toFixed(2), h });
  const baslikOgeleri = (y) => {
    const o = [];
    baslikParcalari.forEach((ps, c) => { let x = x0[c]; ps.forEach((p) => { const it = parca(p, x, y); o.push(it); x += it.w + 2; }); });
    return o;
  };
  // Hucre metnini satirlara, kelimeleri (bazilarini) harf parcalarina bol; y dalgalanmasi ekle
  const hucreOgeleri = (c, metin, ustY, jit) => {
    const o = [];
    String(metin).split('\n').filter((s) => s.trim()).forEach((s, li) => {
      const y = ustY - li * 10;
      let x = x0[c];
      s.split(' ').forEach((k, ki) => {
        if (ki % 3 === 2 && k.length > 3) {
          [k.slice(0, 2), k.slice(2, 3), k.slice(3)].forEach((p) => { const it = parca(p, x, y + jit(), H); o.push(it); x += it.w + 0.3; });
        } else { const it = parca(k, x, y + jit(), H); o.push(it); x += it.w; }
        x += 2.4; // kelime arasi bosluk (> h*0.18)
      });
    });
    return o;
  };
  const kayitOgeleri = (satir, ustY, jit) => {
    const o = [];
    satir.forEach((metin, c) => { if (String(metin).trim()) o.push(...hucreOgeleri(c, metin, ustY, jit)); });
    return o;
  };
  const kaynak = toplam(izgaralar[0][1]).slice(0, 12);
  const jitSabit = (() => { let n = 0; return () => { n++; return [0, 0.9, -1.1, 0.4, -0.6, 1.3][n % 6]; }; })();
  const yukseklik = (satir) => Math.max(1, ...satir.map((m) => String(m).split('\n').filter((s) => s.trim()).length)) * 10;
  const sayfaYap = (satirlar, { baslik, ustBilgi, altBilgi, aciklama, ilkY = 760, jit = jitSabit }) => {
    const items = [];
    if (ustBilgi) items.push(parca('18.11.2026 09:00', 30, 820), parca('e-Devlet Kapısı turkiye.gov.tr', 300, 820));
    let y = ilkY;
    if (baslik) { items.push(...baslikOgeleri(y)); y -= 34; }
    satirlar.forEach((s) => { items.push(...kayitOgeleri(s, y, jit)); y -= yukseklik(s) + 24; });
    if (aciklama) { items.push(parca('AÇIKLAMALAR', 30, y)); y -= 24; items.push(...kayitOgeleri(['99', 'E', 'Kendisi', 'HAYALET'], y, jit)); }
    if (altBilgi) items.push(parca(altBilgi, 380, 20));
    return items;
  };
  const pdfVaka = (ad, sayfalar) => ekle('pdf: ' + ad, { tur: 'pdf', sayfalar }, { izgara: J(E.pdfItemsToGrid(sayfalar)) });
  pdfVaka('tek sayfa, cok satirli hucreler ve dalgali y', [sayfaYap(kaynak.slice(0, 5), { baslik: true, ustBilgi: true, altBilgi: 'Sayfa 1 / 1', aciklama: true })]);
  pdfVaka('iki sayfa', [
    sayfaYap(kaynak.slice(0, 4), { baslik: true, ustBilgi: true, altBilgi: 'Sayfa 1 / 2' }),
    sayfaYap(kaynak.slice(4, 9), { baslik: false, ustBilgi: true, altBilgi: 'Sayfa 2 / 2', aciklama: true }),
  ]);
  { // sayfa arasinda bolunmus kayit
    const r = kaynak[5].slice();
    const bolunen = ['', '', '', '', '', '', '', '', '', '', '', ''];
    const ilk = r.slice();
    ilk[7] = String(r[7]).split('\n')[0]; ilk[8] = String(r[8]).split('\n')[0]; ilk[11] = String(r[11]).split('\n')[0];
    bolunen[7] = String(r[7]).split('\n').slice(1).join('\n') || '01/07/1900'; bolunen[8] = 'KELER MAHALLESİ';
    pdfVaka('kayit sayfa arasinda bolunmus', [
      sayfaYap([kaynak[4], ilk], { baslik: true, altBilgi: 'Sayfa 1 / 2' }),
      sayfaYap([bolunen, kaynak[6], kaynak[7]], { baslik: false, ustBilgi: true, altBilgi: 'Sayfa 2 / 2' }),
    ]);
    const altBant = ['', '', '', '', '', '', '', 'SAYFA SONU', 'ALT BAND', '', '', ''];
    pdfVaka('sayfa sonundaki numarasiz bant sonraki kayda', [
      sayfaYap([kaynak[0], altBant], { baslik: true, altBilgi: 'Sayfa 1 / 2' }),
      sayfaYap([kaynak[1], kaynak[2]], { baslik: false, altBilgi: 'Sayfa 2 / 2' }),
    ]);
  }
  { // alt bilgi bantlari: isJunk'a takilmayan (onek farkli) sayfa numarasi ve gov.tr satiri bandin tamamen atilmasini saglar
    const s = sayfaYap(kaynak.slice(0, 4), { baslik: true, ustBilgi: false });
    s.push(parca('Toplam Sayfa 1 / 2', 380, 40), parca('Dogrulama kodu: x1 www.egov.tr', 380, 60), parca('7', 30, 80));
    pdfVaka('alt bilgi bantlari (gov.tr, sayfa x / y)', [s]);
  }
  pdfVaka('baslik yok', [sayfaYap(kaynak.slice(0, 3), { baslik: false })]);
  pdfVaka('bos sayfa', [[]]);
  pdfVaka('hic sayfa', []);
  pdfVaka('sutun sayisi 12 degil', [sayfaYap(kaynak.slice(0, 2), { baslik: true }).filter((i) => i.str !== 'Durumu')]);
  { // buyuk harfli baslik, bos parcalar
    const s = sayfaYap(kaynak.slice(0, 3), { baslik: true, aciklama: true }).map((i) => ({ ...i, str: ['Sıra', 'Durumu'].includes(i.str) ? i.str.toUpperCase().replace('İ', 'I') : i.str }));
    s.push(parca('   ', 100, 500), parca('', 120, 500));
    pdfVaka('buyuk harfli baslik ve bos parcalar', [s]);
  }
  { // baslik parcalari farkli y'lerde
    const s = sayfaYap(kaynak.slice(0, 3), { baslik: true });
    pdfVaka('baslik parcalari dalgali y', [s.map((i, k) => (k < 18 ? { ...i, y: +(i.y + (k % 3) * 1.2).toFixed(2) } : i))]);
  }
  pdfVaka('mustafa ilk 6 kayit', [sayfaYap(toplam(izgaralar[2][1]).slice(0, 6), { baslik: true, altBilgi: 'Sayfa 1 / 1', ustBilgi: true })]);

  return { vakalar };
}
