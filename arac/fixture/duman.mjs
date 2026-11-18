// Duman testi: web betigi Node'da yuklenir; fixture yazmaz.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const veri = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'veri');

export default function uret(webYukle) {
  const w = webYukle();
  if (w.baslatmaHatasi) console.log('baslatma hatasi:', w.baslatmaHatasi.message);
  const yedek = JSON.parse(fs.readFileSync(path.join(veri, 'soy-agaci.json'), 'utf8'));
  w.ayarla(yedek.people, yedek.nextId);
  console.log('kisi sayisi:', w.calistir('Object.keys(people).length'));
  console.log("normDate('30 JUL 2003'):", w.calistir("normDate('30 JUL 2003')"));
  console.log('simdi:', w.calistir('new Date().toISOString()'));
  return null;
}
