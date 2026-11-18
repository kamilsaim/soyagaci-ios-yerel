// Tarih + metin yardimcilari fixture'i: normDate/toGedDate/yearOf/fmtDate/dateParts/isPlaceholder, capStr, trKatla.
export default function uret(webYukle) {
  const w = webYukle();
  const hesapla = (kod) => w.calistir(kod);
  const J = (s) => JSON.stringify(s);

  const tarihler = [
    '30/07/2003', '1/7/1950', '01/07/1950', '01/07/1959', '01/07/1960', '1.7.1900', '30.07.2003', '5.12.1988',
    '30-07-2003', '5-3-1999', '15/3/2001', '31/02/2000', '00/13/2000', '0/0/2000', '99/99/9999', '1/1/0001',
    '30 JUL 2003', '1 jan 2000', '05 Feb 1999', '5 FEB 1999', '30  JUL  2003', '30 XXX 2003', '123 JUL 2003', '3 AUG 2003 ',
    'JUL 2003', 'jul 2003', 'Dec 1900', 'XXX 2003', 'JUL  2003', '07/2003', '7-2003', '7.2003', '13/2003', '00/2003',
    'ABT 1900', 'ABT 1900 ', 'BEF 1850', 'AFT 1700', 'BET 1800 AND 1900', 'CAL 1950', '1900', '  1900  ', '190', '19000', '12345',
    '1900-1950', 'ca. 1900', '~1900', 'dogum 1900?', '', ' ', '   ', 'abc', '??', '-', '/', '//', '30/07/', '/07/2003',
    '30/07/20033', '30/07/203', '30/07-2003', '30.07/2003', '30-07.2003', '1/7/59', '\t30/07/2003\n', '30/07/2003\n', '\u00a030/07/2003',
    '30/07/2003 ', ' 30 JUL 2003', 'Jul 3000', 'MAY 2003', 'mar 2003', 'MART 2003', '1 Ocak 2000', '12 Mart 1950', 'ŞUBAT 2000',
    '٣٠/٠٧/٢٠٠٣', '０１/０７/１９５０', '01/07/195０', '01/07/1950x', 'x01/07/1950', '1/07/1950', '01/7/1950', '07/1950', '7/1950',
    '00/00/0000', '01/01/1900', '31/12/1999', '29/02/2000', '01/07/2020', '01/07/1900', '01/07/1800', '01/07/1', '1/7/10000',
    '01 JUL 1950', '1 JUL 1950', '01 JUL 1959', '1 JUL 1960', 'JUL 1950', '01/07', '1 JUL', '30 JUL', '2003', '03', '3', '1',
    '01/07/1940', '01/07/1930', '02/07/1950', '01/08/1950', '01/06/1950', '1.07.1950', '01.7.1950', '01-07-1950', '1-7-1950',
    '30 JUL 2003 AD', 'JUL 2003 BC', 'Mon 30 JUL 2003', '2003/07/30', '2003-07-30', '2003.07.30', '2003-07', '07-30-2003', '30/7/2003 14:00',
    'İ', 'ı', '30/07/2003\u2028', '\u200b30/07/2003', '30\u00a0JUL\u00a02003', '30\u2003JUL\u20032003', 'JUL\u00a02003', '30 JUL\t2003', '30\nJUL\n2003',
    'ya da 1900', 'okuyamadim 1923 civari', 'd. 1850', '1850 1900', '2003 JUL', '30 2003 JUL', 'JUL 30 2003', 'JULY 2003', 'SEPT 2003', 'Sep 2003',
    'OCT 1999', 'NOV 1999', 'oct 1999', 'nov 1999', '15 Apr 1815', '15 APR 1815', '9 SEP 1923', '29 OCT 1923', '10 NOV 1938',
  ];
  // Rastgele ama deterministik uretim: bicim x gun/ay/yil
  let tohum = 12345;
  const rnd = (n) => { tohum = (tohum * 1103515245 + 12345) & 0x7fffffff; return tohum % n; };
  const aylarKisa = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  const ayirac = ['/', '.', '-'];
  while (tarihler.length < 210) {
    const g = 1 + rnd(31), a = 1 + rnd(12), y = 1700 + rnd(330);
    const bicim = rnd(6);
    if (bicim === 0) tarihler.push(`${g}${ayirac[rnd(3)]}${a}${ayirac[rnd(3)]}${y}`);
    else if (bicim === 1) tarihler.push(`${String(g).padStart(2, '0')}/${String(a).padStart(2, '0')}/${y}`);
    else if (bicim === 2) tarihler.push(`${g} ${aylarKisa[a - 1]} ${y}`);
    else if (bicim === 3) tarihler.push(`${aylarKisa[a - 1].toLowerCase()} ${y}`);
    else if (bicim === 4) tarihler.push(`${a}${ayirac[rnd(3)]}${y}`);
    else tarihler.push(`01/07/${1900 + rnd(100)}`);
  }

  const vakalar = [];
  for (const s of tarihler) {
    const norm = hesapla(`normDate(${J(s)})`);
    const ged = hesapla(`toGedDate(${J(s)})`);
    const yil = hesapla(`yearOf(${J(s)})`);
    const fmt = hesapla(`fmtDate(${J(s)})`);
    const parca = hesapla(`(function(){const p=dateParts(${J(s)});return p?{d:p.d,m:p.m,y:p.y}:null;})()`);
    const ph = hesapla(`!!isPlaceholder(dateParts(${J(s)}))`);
    vakalar.push({ ad: 'tarih ' + J(s), girdi: { tur: 'tarih', deger: s },
      beklenen: { norm, ged, yil, fmt, parca: parca ? { d: parca.d, m: parca.m, y: parca.y } : null, ph } });
  }

  const adlar = [
    'ismail ılgaz', 'İSMAİL ILGAZ', 'ayşe', 'AYŞE nur', 'mehmet ali', 'ali-veli', 'ali - veli', 'a -b', 'a --b', '-ali', ' ali', '  ali  veli  ',
    'iıİI', 'ıspanak', 'istanbul', 'ışıl ışık', 'şükrü ÇAĞLAR', 'öner ünal', 'güler üzüm', 'hacı mehmet', 'sail efendi', 'fatma zehra',
    'abdülhamid', 'ibrahim halil', 'ömer faruk', 'ç', 'ğ', 'ş', 'i', 'ı', '', ' ', '-', 'a', 'ab cd ef', 'ali\tveli', 'ali\nveli', 'ali\u00a0veli',
    'ali\u2003veli', "o'neil", 'mc donald', 'ßeta', 'ǆ', 'ñandú', 'émile zola', 'ÂLİ', 'ınci', 'iNCİ', 'ELİF NUR', 'hüseyin-öz', 'zeynep (kızlık)',
    '1ahmet', 'ahmet 2', '😀 emoji', 'a😀b', 'ǅ', 'I' + String.fromCharCode(0x307), 'I' + String.fromCharCode(0x307) + 'x', 'İ' + String.fromCharCode(0x307), 'KIRMIZI' + String.fromCharCode(0x307), '\u2028x',
  ];
  for (const s of adlar) {
    const capStr = hesapla(`capStr(${J(s)})`);
    const trKatla = hesapla(`(${J(s)}).toLocaleLowerCase('tr-TR')`);
    vakalar.push({ ad: 'metin ' + J(s), girdi: { tur: 'metin', deger: s }, beklenen: { capStr, trKatla } });
  }
  console.log('tarih vakalari:', tarihler.length, 'metin vakalari:', adlar.length);
  return { kaynak: '7.0.0', vakalar };
}
