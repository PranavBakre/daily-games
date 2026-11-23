// Records the exact puzzles and PRNG streams the web generators produce so the
// Dart port can be tested for bit-exact parity. Run after changing any
// generator: node tools/generate-goldens.mjs

import { mkdir, writeFile } from 'node:fs/promises';
import { Rng, hashSeed } from '../js/rng.js';
import { generateZip } from '../js/games/zip.js';
import { generateTango } from '../js/games/tango.js';
import { generateSudoku } from '../js/games/sudoku.js';
import { generate as generateMerge } from '../js/games/merge.js';

const OUT = 'app/test/fixtures/goldens.json';

const DATES = ['2026-11-14', '2026-11-23', '2027-01-01'];
const PRACTICE = 'practice7x';

const hashSeeds = [];
const rngStreams = [];

const hashCases = [
  '',
  'a',
  'zip:daily:2026-11-23|zip|medium|0',
  'tango:daily:2026-11-23|tango|medium|0',
  'sudoku:daily:2026-11-23|sudoku|mini|0',
  'merge:daily:2026-11-23',
  'practice7x',
];
for (const text of hashCases) hashSeeds.push([text, hashSeed(text)]);

for (const text of hashCases) {
  const ints = new Rng(text);
  const floats = new Rng(text);
  rngStreams.push({
    seed: text,
    ints: Array.from({ length: 8 }, () => ints.int(1000)),
    floats: Array.from({ length: 8 }, () => floats.next()),
  });
}

const puzzles = [];

function record(game, seed, difficulty, puzzle) {
  puzzles.push({ game, seed, difficulty, puzzle });
}

const generators = {
  zip: generateZip,
  tango: generateTango,
  sudoku: generateSudoku,
};

for (const date of DATES) {
  for (const game of ['zip', 'tango', 'sudoku']) {
    const seed = `${game}:daily:${date}`;
    const difficulty = game === 'sudoku' ? 'mini' : 'medium';
    record(game, seed, difficulty, generators[game](seed, difficulty));
  }
  const mergeSeed = `merge:daily:${date}`;
  record('merge', mergeSeed, 'classic', generateMerge(mergeSeed));
}

record('zip', 'zip:practice:practice7x', 'hard', generateZip(`zip:practice:${PRACTICE}`, 'hard'));
record('tango', 'tango:practice:practice7x', 'easy', generateTango(`tango:practice:${PRACTICE}`, 'easy'));
record('sudoku', 'sudoku:practice:practice7x', 'medium', generateSudoku(`sudoku:practice:${PRACTICE}`, 'medium'));
record('merge', 'merge:practice:practice7x', 'classic', generateMerge(`merge:practice:${PRACTICE}`));

await mkdir('app/test/fixtures', { recursive: true });
await writeFile(OUT, `${JSON.stringify({ hashSeeds, rngStreams, puzzles }, null, 2)}\n`);
console.log(`wrote ${OUT}: ${puzzles.length} puzzles`);
