process.env.TZ = 'UTC'; // calistirirken de: TZ=UTC node arac/fixture-uret.mjs <modul|hepsi>
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { webYukle } from './web-ortam.mjs';

process.on('unhandledRejection', () => {});
process.on('uncaughtException', (e) => { console.error('yakalanmamis hata:', e && e.stack); process.exitCode = 1; });

const kok = path.dirname(fileURLToPath(import.meta.url));
const HTML = path.join(kok, 'kaynak', 'soy-agaci-7.0.0.html');
const CIKTI = path.join(kok, '..', 'Paketler', 'SoyCekirdek', 'Tests', 'SoyCekirdekTests', 'fixtures');
const SIMDI = '2026-11-18T09:00:00Z';

const hedef = process.argv[2];
if (!hedef) { console.error('kullanim: node arac/fixture-uret.mjs <modul|hepsi>'); process.exit(2); }
const dizin = path.join(kok, 'fixture');
const moduller = hedef === 'hepsi'
  ? fs.readdirSync(dizin).filter((f) => f.endsWith('.mjs') && f !== 'duman.mjs').map((f) => f.slice(0, -4))
  : [hedef];

const webYukleSabit = () => webYukle(HTML, { simdi: SIMDI });
for (const m of moduller) {
  const mod = await import(pathToFileURL(path.join(dizin, m + '.mjs')).href);
  const sonuc = await mod.default(webYukleSabit);
  if (sonuc) {
    fs.mkdirSync(CIKTI, { recursive: true });
    fs.writeFileSync(path.join(CIKTI, m + '.json'), JSON.stringify(sonuc, null, 2) + '\n');
    console.log(`${m}: ${sonuc.vakalar?.length ?? 0} vaka yazildi`);
  }
}
