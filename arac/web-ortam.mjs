// Web uygulamasinin ana betigini Node'da (vm) calistirir; DOM/ag taklitleriyle.
import vm from 'node:vm';
import fs from 'node:fs';

const DEFAULT_SIMDI = '2026-11-18T09:00:00Z';

// Bilinmeyen her ozellige/cagriya dayanikli taklit nesnesi.
function taklit(ad = 'stub', ozel = {}) {
  const depo = { ...ozel };
  const fn = function () {};
  return new Proxy(fn, {
    get(_, k) {
      if (k === Symbol.toPrimitive) return () => '';
      if (k === 'then') return undefined; // thenable olmasin
      if (k === Symbol.iterator) return function* () {};
      if (typeof k === 'symbol') return undefined;
      if (k in depo) return depo[k];
      if (k === 'length') return 0;
      if (k === 'toString' || k === 'valueOf') return () => '';
      const alt = taklit(ad + '.' + String(k));
      depo[k] = alt;
      return alt;
    },
    set(_, k, v) { depo[k] = v; return true; },
    has() { return true; },
    apply() { return taklit(ad + '()'); },
    construct() { return taklit(ad + ' new'); },
  });
}

function ogeYap(kimlik) {
  const nitelik = new Map();
  const ozel = {
    id: kimlik, value: '', checked: false, innerHTML: '', textContent: '', innerText: '',
    style: taklit('style'), dataset: {}, className: '', disabled: false,
    files: [], width: 300, height: 150, clientWidth: 300, clientHeight: 150, offsetWidth: 300, offsetHeight: 150,
    children: [], childNodes: [], options: [],
    classList: { add() {}, remove() {}, toggle() { return false; }, contains() { return false; } },
    addEventListener() {}, removeEventListener() {},
    appendChild(c) { return c; }, removeChild(c) { return c; }, remove() {}, insertBefore(c) { return c; },
    setAttribute(k, v) { nitelik.set(k, v); }, getAttribute(k) { return nitelik.has(k) ? nitelik.get(k) : null; },
    removeAttribute(k) { nitelik.delete(k); }, hasAttribute(k) { return nitelik.has(k); },
    getContext() { return taklit('ctx2d', { measureText: () => ({ width: 10 }) }); },
    getBoundingClientRect() { return { left: 0, top: 0, right: 300, bottom: 150, width: 300, height: 150, x: 0, y: 0 }; },
    querySelector() { return ogeYap('q'); }, querySelectorAll() { return []; },
    closest() { return null; }, contains() { return false; },
    focus() {}, blur() {}, click() {}, scrollIntoView() {}, select() {}, toDataURL() { return 'data:,'; },
    cloneNode() { return ogeYap(kimlik); },
  };
  return taklit('el#' + kimlik, ozel);
}

export function webYukle(htmlYolu, { simdi = DEFAULT_SIMDI } = {}) {
  process.env.TZ = 'UTC';
  const html = fs.readFileSync(htmlYolu, 'utf8');
  const satirlar = html.split('\n');
  // Ana betik: en uzun satir-ici (src'siz) <script> ... </script> blogu.
  let bas = -1, son = -1;
  for (let i = 0; i < satirlar.length; i++) {
    if (satirlar[i].trim() === '<script>') {
      let j = i + 1;
      while (j < satirlar.length && satirlar[j].trim() !== '</script>') j++;
      if (j - i > son - bas) { bas = i; son = j; }
      i = j;
    }
  }
  if (bas < 0) throw new Error('ana <script> bulunamadi');
  const kod = satirlar.slice(bas + 1, son).join('\n');

  const SIMDI_MS = new Date(simdi).getTime();
  const GercekDate = Date;
  function SabitDate(...a) {
    if (!new.target) return new GercekDate(SIMDI_MS).toString();
    return a.length === 0 ? new GercekDate(SIMDI_MS) : new GercekDate(...a);
  }
  SabitDate.prototype = GercekDate.prototype;
  SabitDate.now = () => SIMDI_MS;
  SabitDate.UTC = GercekDate.UTC;
  SabitDate.parse = GercekDate.parse;

  const ogeler = new Map();
  const oge = (k) => { if (!ogeler.has(k)) ogeler.set(k, ogeYap(k)); return ogeler.get(k); };
  const depo = new Map();
  const localStorage = {
    getItem: (k) => (depo.has(String(k)) ? depo.get(String(k)) : null),
    setItem: (k, v) => { depo.set(String(k), String(v)); },
    removeItem: (k) => { depo.delete(String(k)); },
    clear: () => depo.clear(),
    key: (i) => [...depo.keys()][i] ?? null,
    get length() { return depo.size; },
  };
  const sessionDepo = new Map();
  const sessionStorage = {
    getItem: (k) => (sessionDepo.has(k) ? sessionDepo.get(k) : null),
    setItem: (k, v) => { sessionDepo.set(k, String(v)); },
    removeItem: (k) => { sessionDepo.delete(k); }, clear: () => sessionDepo.clear(),
  };

  // from(...).select().eq()... zinciri: her cagri zincir, await -> {data:null,error:null}
  const bosZincir = () => new Proxy(function () {}, {
    get(_, k) {
      if (k === 'then') return (res, rej) => Promise.resolve({ data: null, error: null }).then(res, rej);
      if (typeof k === 'symbol') return undefined;
      return () => bosZincir();
    },
    apply() { return bosZincir(); },
  });
  const supabase = {
    createClient() {
      const auth = {
        getSession: async () => ({ data: { session: null } }),
        getUser: async () => ({ data: { user: null }, error: null }),
        onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } }),
      };
      return {
        auth: new Proxy(auth, { get(t, k) { return k in t ? t[k] : async () => ({ data: null, error: null }); } }),
        from: () => bosZincir(),
        storage: { from: () => bosZincir() },
        rpc: () => bosZincir(),
      };
    },
  };

  const document = taklit('document', {
    getElementById: oge, querySelector: (s) => oge('q:' + s), querySelectorAll: () => [],
    createElement: (t) => ogeYap('new:' + t), createTextNode: () => ogeYap('text'),
    addEventListener() {}, removeEventListener() {},
    body: oge('body'), documentElement: oge('html'), head: oge('head'),
    cookie: '', readyState: 'complete', title: '', hidden: false, visibilityState: 'visible',
    fonts: { ready: Promise.resolve(), load: () => Promise.resolve([]) },
  });
  const location = {
    origin: 'https://example.test', pathname: '/index.html', search: '', hash: '', href: 'https://example.test/index.html',
    host: 'example.test', hostname: 'example.test', protocol: 'https:',
    replace() {}, reload() {}, assign() {},
  };
  const zamanlayicilar = [];
  const sandbox = {
    console, document, localStorage, sessionStorage, location, supabase,
    navigator: taklit('navigator', { userAgent: 'node', language: 'tr-TR', languages: ['tr-TR'], platform: 'node', onLine: true }),
    history: { replaceState() {}, pushState() {}, state: null, back() {} },
    matchMedia: () => ({ matches: false, addEventListener() {}, removeEventListener() {}, addListener() {}, removeListener() {} }),
    fetch: () => new Promise(() => {}),
    Image: function () { return ogeYap('img'); },
    URL: Object.assign(function (...a) { return new URL(...a); }, { createObjectURL: () => 'blob:stub', revokeObjectURL() {} }),
    requestAnimationFrame: () => 0, cancelAnimationFrame() {},
    setTimeout: (f, ms) => { zamanlayicilar.push([f, ms]); return zamanlayicilar.length; },
    clearTimeout() {}, setInterval: () => 0, clearInterval() {},
    alert() {}, confirm: () => true, prompt: () => null, open() {}, print() {},
    addEventListener() {}, removeEventListener() {}, dispatchEvent() {},
    getComputedStyle: () => taklit('cs'), devicePixelRatio: 1, innerWidth: 390, innerHeight: 844,
    screen: { width: 390, height: 844 }, scrollTo() {}, scroll() {},
    Date: SabitDate,
    TextEncoder, TextDecoder,
    atob: (s) => Buffer.from(s, 'base64').toString('binary'), btoa: (s) => Buffer.from(s, 'binary').toString('base64'),
    Blob: function () {}, FileReader: function () { return ogeYap('fr'); }, FormData: function () {},
    AbortController, Event: function () {}, CustomEvent: function () {}, MutationObserver: function () { return taklit('mo'); },
    ResizeObserver: function () { return taklit('ro'); }, IntersectionObserver: function () { return taklit('io'); },
    structuredClone,
  };
  sandbox.window = sandbox; sandbox.self = sandbox; sandbox.top = sandbox; sandbox.parent = sandbox;
  const ctx = vm.createContext(sandbox); // Object/Array/JSON/Intl vb. yerlesikler baglamin kendisinden gelir

  let baslatmaHatasi = null;
  try {
    new vm.Script(kod, { filename: 'soy-agaci-ana.js' }).runInContext(ctx);
  } catch (e) { baslatmaHatasi = e; }

  return {
    ctx, ogeler, localStorage, zamanlayicilar, baslatmaHatasi,
    calistir: (k) => vm.runInContext(k, ctx),
    ayarla(people, nextId) {
      ctx.__p = people; ctx.__n = nextId;
      vm.runInContext('people=__p; nextId=__n; delete globalThis.__p; delete globalThis.__n;', ctx);
    },
    people: () => vm.runInContext('people', ctx),
  };
}
