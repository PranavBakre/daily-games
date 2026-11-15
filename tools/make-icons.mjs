// Generates the app icons with no image dependencies: shapes are drawn from
// signed distance fields at 3x, then box-filtered down to the target size.

import { deflateSync } from 'node:zlib';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, '..', 'icons');
const SS = 3;

const POINTS = [
  [0.245, 0.755],
  [0.245, 0.5],
  [0.5, 0.5],
  [0.5, 0.245],
  [0.755, 0.245],
];

const DOTS = [];
for (const x of [0.245, 0.5, 0.755]) for (const y of [0.245, 0.5, 0.755]) DOTS.push([x, y]);

function sdRoundRect(x, y, cx, cy, hw, hh, r) {
  const dx = Math.abs(x - cx) - hw + r;
  const dy = Math.abs(y - cy) - hh + r;
  const outside = Math.hypot(Math.max(dx, 0), Math.max(dy, 0));
  const inside = Math.min(Math.max(dx, dy), 0);
  return outside + inside - r;
}

function sdSegment(x, y, ax, ay, bx, by) {
  const pax = x - ax;
  const pay = y - ay;
  const bax = bx - ax;
  const bay = by - ay;
  const h = Math.max(0, Math.min(1, (pax * bax + pay * bay) / (bax * bax + bay * bay)));
  return Math.hypot(pax - bax * h, pay - bay * h);
}

function pathDistance(x, y) {
  let best = Infinity;
  for (let i = 0; i < POINTS.length - 1; i++) {
    const [ax, ay] = POINTS[i];
    const [bx, by] = POINTS[i + 1];
    best = Math.min(best, sdSegment(x, y, ax, ay, bx, by));
  }
  return best;
}

// Colours match the tokens in styles.css: paper, line, ink and the Zip accent.
const PAPER = [0.969, 0.957, 0.925];
const LINE = [0.851, 0.827, 0.773];
const INK = [0.071, 0.071, 0.071];
const ZIP = [0.988, 0.545, 0.369];

function blend(color, rgb, alpha) {
  color[0] = color[0] * (1 - alpha) + rgb[0] * alpha;
  color[1] = color[1] * (1 - alpha) + rgb[1] * alpha;
  color[2] = color[2] * (1 - alpha) + rgb[2] * alpha;
}

function sample(x, y, maskable) {
  if (!maskable && sdRoundRect(x, y, 0.5, 0.5, 0.485, 0.485, 0.215) > 0) {
    return [0, 0, 0, 0];
  }

  const color = PAPER.slice();
  const k = maskable ? 0.74 : 1;
  const u = (x - 0.5) / k + 0.5;
  const v = (y - 0.5) / k + 0.5;

  for (const [cx, cy] of DOTS) {
    if (sdRoundRect(u, v, cx, cy, 0.072, 0.072, 0.026) <= 0) {
      blend(color, LINE, 1);
    }
  }

  if (pathDistance(u, v) <= 0.043) {
    blend(color, INK, 1);
  }

  if (Math.hypot(u - 0.245, v - 0.755) <= 0.056) {
    blend(color, ZIP, 1);
  }

  return [color[0], color[1], color[2], 1];
}

function render(size, { maskable = false } = {}) {
  const big = size * SS;
  const out = Buffer.alloc(size * size * 4);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let r = 0;
      let g = 0;
      let b = 0;
      let a = 0;
      for (let sy = 0; sy < SS; sy++) {
        for (let sx = 0; sx < SS; sx++) {
          const px = (x * SS + sx + 0.5) / big;
          const py = (y * SS + sy + 0.5) / big;
          const [cr, cg, cb, ca] = sample(px, py, maskable);
          r += cr * ca;
          g += cg * ca;
          b += cb * ca;
          a += ca;
        }
      }
      const count = SS * SS;
      const offset = (y * size + x) * 4;
      const alpha = a / count;
      out[offset] = Math.round((r / count / (alpha || 1)) * 255);
      out[offset + 1] = Math.round((g / count / (alpha || 1)) * 255);
      out[offset + 2] = Math.round((b / count / (alpha || 1)) * 255);
      out[offset + 3] = Math.round(alpha * 255);
    }
  }
  return out;
}

// --- minimal PNG encoder ---------------------------------------------------

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return table;
})();

function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) crc = CRC_TABLE[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length, 0);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body), 0);
  return Buffer.concat([length, body, crc]);
}

function encodePng(size, rgba) {
  const raw = Buffer.alloc((size * 4 + 1) * size);
  for (let y = 0; y < size; y++) {
    raw[y * (size * 4 + 1)] = 0;
    rgba.copy(raw, y * (size * 4 + 1) + 1, y * size * 4, (y + 1) * size * 4);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // RGBA
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

// --- output ----------------------------------------------------------------

mkdirSync(outDir, { recursive: true });

const outputs = [
  ['icon-512.png', 512, { maskable: false }],
  ['icon-192.png', 192, { maskable: false }],
  ['apple-touch-icon.png', 180, { maskable: true }],
  ['maskable-512.png', 512, { maskable: true }],
];

for (const [name, size, options] of outputs) {
  const png = encodePng(size, render(size, options));
  writeFileSync(join(outDir, name), png);
  console.log(`${name}  ${size}x${size}  ${(png.length / 1024).toFixed(1)} kB`);
}
