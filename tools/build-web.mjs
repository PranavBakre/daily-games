// Packages the PWA for the Cloudflare Worker: the app is served from /games/,
// the apex redirects to it. Only runtime files are copied, so sources and tests
// never reach the CDN.

import { cp, mkdir, rm } from 'node:fs/promises';
import { join } from 'node:path';

const OUT = 'dist/web';
const SLUG = 'games';

const FILES = ['index.html', 'styles.css', 'sw.js', 'manifest.webmanifest'];
const DIRS = ['js', 'icons'];

await rm(OUT, { recursive: true, force: true });
const dest = join(OUT, SLUG);
await mkdir(dest, { recursive: true });

for (const file of FILES) await cp(file, join(dest, file));
for (const dir of DIRS) await cp(dir, join(dest, dir), { recursive: true });

console.log(`built ${OUT} → /${SLUG}/`);
