// Veri modeli fixture'i: migrateData, savePerson, delP, newId, isAncestorOf, allPhotoRefs, isDead/initials/pname/photoRefsOf.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const veriDizini = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'veri');
const J = (x) => JSON.stringify(x);
const klon = (x) => JSON.parse(JSON.stringify(x));

export default function uret(webYukle) {
  const gercekYedek = JSON.parse(fs.readFileSync(path.join(veriDizini, 'soy-agaci.json'), 'utf8'));
  const gercek = gercekYedek.people;
  const gercekNext = gercekYedek.nextId;
  const vakalar = [];

  function taze(people, nextId, migrate) {
    const w = webYukle();
    if (w.baslatmaHatasi) throw new Error('baslatma hatasi: ' + w.baslatmaHatasi.message);
    w.calistir('people=' + J(people) + ';nextId=' + J(nextId) + ';');
    if (migrate) w.calistir('migrateData()');
    return w;
  }
  const goruntu = (w) => JSON.parse(w.calistir('JSON.stringify({people:people,nextId:nextId})'));

  // ── (a) migrateData ──
  function eskiKayit(i) {
    // Eski surumlerden kalma bicimler: deterministik cesitleme
    const id = 'P' + (i + 1);
    const p = { id, firstName: 'Ad' + i, lastName: 'Soyad' + i };
    const t = i % 10;
    if (t !== 0) p.gender = ['M', 'F', 'U', 'M', 'F', 'U', 'M', 'F', 'M'][t - 1];
    if (t === 1) { p.spouse = 'P' + (i + 2); }
    if (t === 2) { p.spouse = 'P' + (i + 2); p.maritalStatus = 'divorced'; }
    if (t === 3) { p.spouses = [{ id: 'P' + (i + 2), status: 'widowed' }, null, 'P9', { status: 'married' }, { id: '' }, { id: 'P7', extra: 1 }]; }
    if (t === 4) { p.gallery = 'x'; p.children = 'P3'; p.deceased = 'yes'; }
    if (t === 5) { p.maidenName = null; p.maritalStatus = ''; p.deceased = true; p.children = ['P2']; }
    if (t === 6) { p.spouse = null; p.spouses = null; p.gallery = null; p.deceased = 0; }
    if (t === 7) { p.spouse = 'P3'; p.spouses = []; p.maritalStatus = 'partner'; p.maidenName = 'Kizlik'; }
    if (t === 8) { p.xyz = { a: [1] }; p.spouse = 0; p.photo = 'data:image/jpeg;base64,AAAA'; }
    if (t === 9) { p.gallery = ['a', 'b']; p.spouses = [[], { id: 'P2', status: 'married' }]; p.deceased = false; }
    return p;
  }
  const eskiPeople = {};
  for (let i = 0; i < 30; i++) { const p = eskiKayit(i); eskiPeople[p.id] = p; }
  eskiPeople.X7 = { id: 'X7', firstName: 'Onekiz', spouse: 'P1' };
  eskiPeople.abc = { id: 'abc', firstName: 'Harf' };
  for (const [ad, people, nextId] of [['sentetik eski bicimler', eskiPeople, 33], ['soy-agaci.json', gercek, gercekNext]]) {
    const w = taze(people, nextId, false);
    w.calistir('migrateData()');
    vakalar.push({ ad: 'migrate ' + ad, girdi: { tur: 'migrate', people, nextId }, beklenen: goruntu(w) });
  }
  // Tek kayitlik kucuk migrate vakalari (kenar durumlar)
  const kucukler = [
    { id: 'A', firstName: 'x' },
    { id: 'A', spouse: 'B', maritalStatus: 'widowed', gender: 'U' },
    { id: 'A', spouses: [{ id: 'B' }], spouse: 'C' },
    { id: 'A', maidenName: 0, deceased: 1, gallery: [], children: [], spouses: [] },
    { id: 'A', gender: 'u' },
    { id: 'A', spouse: ' ', maritalStatus: 'divorced' },
  ];
  kucukler.forEach((k, i) => {
    const people = { A: k };
    const w = taze(people, 1, false);
    w.calistir('migrateData()');
    vakalar.push({ ad: 'migrate kucuk ' + i, girdi: { tur: 'migrate', people, nextId: 1 }, beklenen: goruntu(w) });
  });

  // ── yapay aile (savePerson / delP / yardimcilar) ──
  const K = (id, ad, soyad, g, o = {}) => ({
    id, firstName: ad, lastName: soyad, gender: g, birthDate: '', birthPlace: '', deathDate: '', deathPlace: '',
    occupation: '', notes: '', photo: null, gallery: [], mother: null, father: null, spouse: null, spouses: [], children: [], ...o,
  });
  const aile = () => {
    const p = {
      P1: K('P1', 'Ahmet', 'Yilmaz', 'M', { birthDate: '01/02/1930', spouse: 'P2', spouses: [{ id: 'P2', status: 'married' }], children: ['P3', 'P4'] }),
      P2: K('P2', 'Ayse', 'Yilmaz', 'F', { maidenName: 'Kara', birthDate: '1935', spouse: 'P1', spouses: [{ id: 'P1', status: 'married' }], children: ['P3', 'P4'] }),
      P3: K('P3', 'Mehmet', 'Yilmaz', 'M', { father: 'P1', mother: 'P2', spouse: 'P5', spouses: [{ id: 'P5', status: 'married' }], children: ['P6'], photo: 'u/a.jpg', gallery: ['u/a.jpg', 'u/b.jpg'] }),
      P4: K('P4', 'Fatma', 'Demir', 'F', { father: 'P1', mother: 'P2', spouse: 'P7', spouses: [{ id: 'P7', status: 'divorced' }] }),
      P5: K('P5', 'Zeynep', 'Yilmaz', 'F', { spouse: 'P3', spouses: [{ id: 'P3', status: 'married' }], children: ['P6'] }),
      P6: K('P6', 'Ali', 'Yilmaz', 'M', { father: 'P3', mother: 'P5', birthDate: '2001' }),
      P7: K('P7', 'Hasan', 'Demir', 'M', { spouse: 'P4', spouses: [{ id: 'P4', status: 'divorced' }, { id: 'P9', status: 'widowed' }], maritalStatus: 'divorced' }),
      P8: K('P8', 'Emine', 'Kaya', 'F', { deceased: true }),
      P9: K('P9', 'Leyla', 'Demir', 'F', { spouse: 'P7', spouses: [{ id: 'P7', status: 'widowed' }], deathDate: '1999' }),
      P10: K('P10', 'Tek', 'Kisi', 'M', { photo: 'u/c.jpg' }),
    };
    for (const k of Object.keys(p)) { p[k].maidenName = p[k].maidenName || ''; p[k].maritalStatus = p[k].maritalStatus || 'married'; p[k].deceased = !!p[k].deceased; }
    return p;
  };
  const aileTaban = aile();

  // openForm benzeri: kisiden form degerleri
  function formDan(people, id) {
    const p = people[id];
    if (!p) return { id: id || null, firstName: '', lastName: '', gender: 'M', birthDate: '', birthPlace: '', deathDate: '', deathPlace: '', deceased: false, occupation: '', maidenName: '', notes: '', mother: null, father: null, photo: null, gallery: [], spouses: [], children: [] };
    const gal = [...(p.gallery || [])];
    const photo = p.photo || null;
    if (photo && !gal.includes(photo)) gal.unshift(photo);
    return {
      id, firstName: p.firstName || '', lastName: p.lastName || '', gender: p.gender || 'M', birthDate: p.birthDate || '',
      birthPlace: p.birthPlace || '', deathDate: p.deathDate || '', deathPlace: p.deathPlace || '', deceased: !!p.deceased,
      occupation: p.occupation || '', maidenName: p.maidenName || '', notes: p.notes || '', mother: p.mother || null, father: p.father || null,
      photo, gallery: gal,
      spouses: (p.spouses || []).filter((s) => s && people[s.id]).map((s) => ({ id: s.id, status: s.status || 'married' })),
      children: [...(p.children || [])].filter((c) => people[c]),
    };
  }
  const bos = () => formDan({}, null);

  function kaydetVaka(ad, people, nextId, form, temel) {
    const w = taze(people, nextId, true);
    const once = goruntu(w);
    w.calistir(`(function(){
      const F=${J(form)}; const d=document;
      d.getElementById('f_fn').value=F.firstName; d.getElementById('f_ln').value=F.lastName;
      d.getElementById('f_g').value=F.gender; d.getElementById('f_bd').value=F.birthDate;
      d.getElementById('f_bp').value=F.birthPlace; d.getElementById('f_dd').value=F.deathDate;
      d.getElementById('f_dp').value=F.deathPlace; d.getElementById('f_dc').checked=F.deceased;
      d.getElementById('f_oc').value=F.occupation; d.getElementById('f_ms').value=F.maidenName;
      d.getElementById('f_no').value=F.notes; d.getElementById('f_mo').value=F.mother||'';
      d.getElementById('f_fa').value=F.father||'';
      editId=F.id; mainPhoto=F.photo; gal=F.gallery; formChildren=F.children; formSpouses=F.spouses;
      _tempNewIds=[]; _pendingRelations=[]; _tempPhotoRefs=[];
      globalThis.__toast=[]; globalThis.__purge=null;
      save=function(){}; renderAll=function(){}; buildTree=function(){}; cModal=function(){};
      focusAfterLink=function(){}; setFocus=function(){};
      purgePhotos=function(r){globalThis.__purge=r;};
      toast=function(m){globalThis.__toast.push(m);};
    })()`);
    w.calistir('savePerson()');
    const toastlar = JSON.parse(w.calistir('JSON.stringify(__toast)'));
    const sonra = goruntu(w);
    let sonuc;
    if (toastlar.length === 1 && toastlar[0].startsWith('✅')) {
      let id = form.id;
      if (!id) id = Object.keys(sonra.people).find((k) => !(k in once.people));
      sonuc = { tur: 'tamam', id, eskiFotolar: JSON.parse(w.calistir('JSON.stringify(__purge)')) };
    } else if (toastlar.length === 1) {
      sonuc = { tur: 'hata', mesaj: toastlar[0] };
    } else throw new Error('beklenmeyen toast: ' + J(toastlar) + ' / ' + ad);
    const girdi = { tur: 'kaydet', form };
    if (temel) girdi.temel = temel; else { girdi.people = people; girdi.nextId = nextId; }
    girdi.nextId = nextId;
    vakalar.push({ ad: 'kaydet ' + ad, girdi, beklenen: { sonuc, people: sonra.people, nextId: sonra.nextId } });
  }

  // ── (b) savePerson: yapay aile ──
  const D = (id, o) => ({ ...formDan(aileTaban, id), ...o });
  const A = (o) => ({ ...bos(), ...o });
  const S = (id, status) => ({ id, status });
  const kayitlar = [
    ['yeni yalniz ad', A({ firstName: 'veli' })],
    ['yeni yalniz soyad', A({ lastName: 'ozturk' })],
    ['yeni bosluklu kucuk harf', A({ firstName: '  mehmet ali ', lastName: ' ISIK-yilmaz ', birthPlace: ' istanbul ', occupation: 'ogretmen', notes: '  not  ' })],
    ['yeni tarihler', A({ firstName: 'Tarih', birthDate: '5.12.1988', deathDate: ' 30 JUL 2003 ', deceased: true })],
    ['yeni kadin kizlik', A({ firstName: 'ayse', gender: 'F', maidenName: ' kara ' })],
    ['yeni erkek kizlik yok sayilir', A({ firstName: 'Erkek', gender: 'M', maidenName: 'Kara' })],
    ['yeni ad bos hata', A({ firstName: '  ', lastName: '' })],
    ['yeni ad bos hata tarihli', A({ birthDate: '1900', notes: 'x' })],
    ['yeni anne baba', A({ firstName: 'Cocuk', mother: 'P2', father: 'P1' })],
    ['yeni anne bos string', A({ firstName: 'Cocuk', mother: '', father: '' })],
    ['yeni bilinmeyen anne', A({ firstName: 'Cocuk', mother: 'P999' })],
    ['yeni es bos durum', A({ firstName: 'Es', spouses: [S('P10', '')] })],
    ['yeni es var olan eslerle', A({ firstName: 'Ucuncu', gender: 'F', spouses: [S('P7', 'married')] })],
    ['yeni olmayan es filtre', A({ firstName: 'Es', spouses: [S('P404', 'married'), S('P10', 'partner')] })],
    ['yeni cift es tekrar', A({ firstName: 'Es', spouses: [S('P10', 'married'), S('P10', 'divorced')] })],
    ['yeni cocuk yetim', A({ firstName: 'Baba', gender: 'M', children: ['P10'] })],
    ['yeni cocuk eski babasi var', A({ firstName: 'Yeni Baba', gender: 'M', children: ['P6'] })],
    ['yeni anne cocuk eski annesi var', A({ firstName: 'Yeni Anne', gender: 'F', children: ['P6'] })],
    ['yeni cocuklar tekrar ve olmayan', A({ firstName: 'Baba', children: ['P10', 'P10', 'P404', 'P8'] })],
    ['yeni foto galeri tekrar', A({ firstName: 'Foto', photo: 'u/x.jpg', gallery: ['u/x.jpg', 'u/y.jpg', 'u/x.jpg'] })],
    ['yeni kimlik cakisan nextId', A({ firstName: 'Cakisma' }), 3],
    ['yeni nextId buyuk', A({ firstName: 'Buyuk' }), 100],
    ['yeni bos gender', A({ firstName: 'Cins', gender: '' })],
    ['duzenle degisiklik yok P3', D('P3')],
    ['duzenle degisiklik yok P1', D('P1')],
    ['duzenle ad degistir', D('P3', { firstName: 'mehmet emin', lastName: 'yildiz' })],
    ['duzenle foto degistir', D('P3', { photo: 'u/z.jpg', gallery: ['u/z.jpg'] })],
    ['duzenle foto kaldir', D('P3', { photo: null, gallery: [] })],
    ['duzenle ebeveyn degistir', D('P3', { mother: 'P8', father: 'P10' })],
    ['duzenle ebeveyn kaldir', D('P4', { mother: null, father: null })],
    ['duzenle yalniz baba degistir', D('P6', { father: 'P1' })],
    ['duzenle es kaldir', D('P3', { spouses: [] })],
    ['duzenle es ekle ikinci', D('P3', { spouses: [S('P5', 'married'), S('P8', 'partner')] })],
    ['duzenle es durum degistir', D('P3', { spouses: [S('P5', 'divorced')] })],
    ['duzenle es sirasi degis', D('P7', { spouses: [S('P9', 'widowed'), S('P4', 'divorced')] })],
    ['duzenle es kendisi filtre', D('P3', { spouses: [S('P3', 'married'), S('P5', 'married')] })],
    ['duzenle cocuk kaldir', D('P1', { children: ['P3'] })],
    ['duzenle cocuk hepsi kaldir', D('P1', { children: [] })],
    ['duzenle cocuk ekle', D('P8', { children: ['P6'], gender: 'F' })],
    ['duzenle cinsiyet degis M->F', D('P3', { gender: 'F', maidenName: 'eski' })],
    ['duzenle cinsiyet degis F->M cocuklu', D('P5', { gender: 'M' })],
    ['duzenle olmayan kimlik', D('P3', { id: 'P500' })],
    ['duzenle kendi ebeveyni anne', D('P3', { mother: 'P3' })],
    ['duzenle kendi ebeveyni baba', D('P3', { father: 'P3' })],
    ['hata anne soyundan', D('P1', { mother: 'P6' })],
    ['hata baba soyundan', D('P1', { father: 'P3' })],
    ['hata cocuk atasi', D('P6', { children: ['P1'] })],
    ['hata cocuk atasi ad', D('P3', { children: ['P1', 'P6'] })],
    ['hata anne dedesi', D('P6', { mother: 'P1' }) ],
    ['hata ad yok duzenle', D('P3', { firstName: '', lastName: ' ' })],
  ];
  for (const [ad, form, nextId] of kayitlar) kaydetVaka(ad, aile(), nextId || 11, form, null);

  // ── (b) savePerson: gercek veri ──
  const gw = taze(gercek, gercekNext, true);
  const gercekMig = goruntu(gw).people;
  const gv = Object.values(gercekMig);
  const ebeveynliCocuk = gv.find((p) => p.mother && p.father && gercekMig[p.mother] && gercekMig[p.father]);
  const cocuklu = gv.find((p) => (p.children || []).length >= 2 && p.mother);
  const esli = gv.find((p) => (p.spouses || []).length >= 1 && (p.children || []).length >= 1);
  const esiz = gv.find((p) => !(p.spouses || []).length && p.gender === 'M' && !(p.children || []).length);
  const diger = gv.find((p) => p.id !== esiz.id && p.gender === 'F' && !(p.spouses || []).length);
  const temel = 'migrate soy-agaci.json';
  kaydetVaka('gercek degisiklik yok ' + esli.id, gercekMig, gercekNext, formDan(gercekMig, esli.id), temel);
  kaydetVaka('gercek yeni ebeveynli', gercekMig, gercekNext, { ...bos(), firstName: 'yeni kisi', mother: ebeveynliCocuk.mother, father: ebeveynliCocuk.father, birthDate: '3.4.2020' }, temel);
  kaydetVaka('gercek ad degistir ' + cocuklu.id, gercekMig, gercekNext, { ...formDan(gercekMig, cocuklu.id), firstName: 'degisti' }, temel);
  kaydetVaka('gercek ebeveyn degistir ' + ebeveynliCocuk.id, gercekMig, gercekNext, { ...formDan(gercekMig, ebeveynliCocuk.id), mother: null, father: null }, temel);
  kaydetVaka('gercek cocuk hepsi kaldir ' + cocuklu.id, gercekMig, gercekNext, { ...formDan(gercekMig, cocuklu.id), children: [] }, temel);
  kaydetVaka('gercek es ekle ' + esiz.id, gercekMig, gercekNext, { ...formDan(gercekMig, esiz.id), spouses: [{ id: diger.id, status: 'married' }] }, temel);
  kaydetVaka('gercek soy dongusu', gercekMig, gercekNext, { ...formDan(gercekMig, cocuklu.id), father: cocuklu.children[0] }, temel);
  kaydetVaka('gercek cocuk atasi', gercekMig, gercekNext, { ...formDan(gercekMig, ebeveynliCocuk.id), children: [ebeveynliCocuk.father] }, temel);

  // ── (c) delP ──
  function silVaka(ad, people, nextId, id, temelAd) {
    const w = taze(people, nextId, true);
    w.calistir(`imgCache=typeof imgCache==='undefined'?{}:imgCache; delP(${J(id)})`);
    const girdi = { tur: 'sil', id };
    if (temelAd) girdi.temel = temelAd; else { girdi.people = people; }
    girdi.nextId = nextId;
    vakalar.push({ ad: 'sil ' + ad, girdi, beklenen: goruntu(w) });
  }
  for (const id of ['P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'P7', 'P8', 'P9', 'P10', 'P404']) silVaka('yapay ' + id, aile(), 11, id, null);
  const gercekSil = [esli.id, cocuklu.id, ebeveynliCocuk.id, esiz.id, diger.id, gv[0].id, gv[50].id, gv[100].id, 'P99999'];
  for (const id of gercekSil) silVaka('gercek ' + id, gercekMig, gercekNext, id, temel);

  // ── (d) newId ──
  const idDurumlari = [[{}, 1], [{}, 5], [{ P1: { id: 'P1' } }, 1], [{ P1: {}, P2: {}, P3: {} }, 1], [{ P3: {} }, 3], [{ P2: {}, P4: {} }, 2], [gercek, 1], [gercek, 100], [gercek, gercekNext], [gercek, 0]];
  for (const [people, nextId] of idDurumlari) {
    const w = taze(people, nextId, false);
    const id = w.calistir('newId()');
    vakalar.push({ ad: 'newId ' + Object.keys(people).length + '/' + nextId, girdi: { tur: 'newId', people: Object.keys(people).length > 20 ? null : people, gercek: Object.keys(people).length > 20, nextId }, beklenen: { id, nextId: w.calistir('nextId') } });
  }

  // ── isAncestorOf: tum cift kombinasyonlari ──
  function ataVakasi(ad, people, kimlikler) {
    const w = taze(people, 1000, true);
    const sonuc = {};
    const hepsi = [];
    for (const a of kimlikler) for (const d of kimlikler) {
      const r = !!w.calistir(`isAncestorOf(${J(a)},${J(d)})`);
      if (r) hepsi.push([a, d]);
    }
    vakalar.push({ ad: 'ata ' + ad, girdi: { tur: 'ata', ...(people === gercek ? { gercek: true } : { people: aile() }), kimlikler }, beklenen: { atalar: hepsi } });
    return sonuc;
  }
  ataVakasi('yapay', aile(), ['P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'P7', 'P8', 'P9', 'P10', 'P404', '']);
  ataVakasi('gercek', gercek, Object.keys(gercek).filter((_, i) => i % 3 === 0));

  // ── allPhotoRefs ──
  const fotoPeople = aile();
  fotoPeople.P1.photo = 'u/p1.jpg'; fotoPeople.P2.gallery = ['u/g1.jpg', 'u/p1.jpg', '']; fotoPeople.P8.photo = 'data:image/png;base64,QQ==';
  for (const [ad, people] of [['yapay', aile()], ['yapay foto', fotoPeople], ['gercek', gercek]]) {
    const w = taze(people, 1, true);
    vakalar.push({ ad: 'foto ' + ad, girdi: { tur: 'foto', ...(people === gercek ? { gercek: true } : { people }) }, beklenen: { hepsi: JSON.parse(w.calistir('JSON.stringify(allPhotoRefs())')) } });
  }

  // ── (d) yardimcilar: isDead / initials / pname / photoRefsOf ──
  function yardimci(ad, kisi) {
    const w = taze({ X: kisi }, 1, false);
    const r = w.calistir(`(function(){const p=people.X;return JSON.stringify({dead:!!isDead(p),ini:initials(p),ad:pname(p),foto:photoRefsOf(p)});})()`);
    vakalar.push({ ad: 'yardimci ' + ad, girdi: { tur: 'yardimci', kisi }, beklenen: JSON.parse(r) });
  }
  for (const p of Object.values(gercek)) yardimci('gercek ' + p.id, p);
  const sentetik = [
    { id: 'S1', firstName: 'ilker', lastName: 'ışık' }, { id: 'S2', firstName: '', lastName: '' }, { id: 'S3', firstName: ' ', lastName: ' x' },
    { id: 'S4', firstName: 'ali' }, { id: 'S5', lastName: 'soyad' }, { id: 'S6', firstName: 'İbrahim', lastName: 'ıspanak' },
    { id: 'S7', firstName: 'ßeta', lastName: 'ǆ' }, { id: 'S8', firstName: 'ç', lastName: 'ğ' }, { id: 'S9', firstName: '  ahmet  ', lastName: 'yilmaz' },
    { id: 'S10', firstName: null, lastName: null }, { id: 'S11', firstName: null, lastName: 'k' },
    { id: 'S12', birthDate: '1916', firstName: 'x' }, { id: 'S13', birthDate: '1915', firstName: 'x' }, { id: 'S14', birthDate: '01/02/1900', firstName: 'x' },
    { id: 'S15', birthDate: '1917', firstName: 'x' }, { id: 'S16', birthDate: 'ABT 1800', firstName: 'x' }, { id: 'S17', birthDate: '', firstName: 'x', deceased: true },
    { id: 'S18', firstName: 'x', deathPlace: 'Konya' }, { id: 'S19', firstName: 'x', deathDate: '1990' }, { id: 'S20', firstName: 'x', deceased: 'yes' },
    { id: 'S21', firstName: 'x', deceased: false, birthDate: '2000' }, { id: 'S22', birthDate: 'yok', firstName: 'x' },
    { id: 'S23', firstName: 'x', photo: 'u/a.jpg', gallery: ['u/a.jpg', '', 'u/b.jpg'] }, { id: 'S24', firstName: 'x', photo: null, gallery: [] },
    { id: 'S25', firstName: 'x', photo: 'data:image/png;base64,AA==', gallery: ['data:image/png;base64,AA=='] }, { id: 'S26', firstName: 'x', gallery: [null, 'k'] },
    { id: 'S27', firstName: 'x', birthDate: '0000' }, { id: 'S28', firstName: 'x', birthDate: '1950' },
  ];
  for (const k of sentetik) yardimci('sentetik ' + k.id, k);

  console.log('veri vakalari:', vakalar.length);
  return { kaynak: '7.0.0', simdi: '2026-11-18T09:00:00Z', vakalar };
}
