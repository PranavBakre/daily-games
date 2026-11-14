import { describe, expect, test } from 'bun:test';
import { generateZip, countSolutions as countZip, neighbours } from '../js/games/zip.js';
import {
  generateTango,
  countSolutions as countTango,
  isValidSolution,
  search,
} from '../js/games/tango.js';
import { generateSudoku, countSolutions as countSudoku } from '../js/games/sudoku.js';

function edgeId(a, b) {
  return `${Math.min(a, b)}:${Math.max(a, b)}`;
}

function checkZip(puzzle) {
  const { width, height, numbers, walls, solution } = puzzle;
  const size = width * height;
  const table = neighbours(width, height);

  expect(solution.length).toBe(size);
  expect(new Set(solution).size).toBe(size);

  const wallSet = new Set(walls.map(([a, b]) => edgeId(a, b)));
  for (let i = 1; i < size; i++) {
    const from = solution[i - 1];
    const to = solution[i];
    expect(table[from]).toContain(to);
    expect(wallSet.has(edgeId(from, to))).toBe(false);
  }

  const labels = numbers.filter((value) => value !== 0);
  expect(labels.length).toBeGreaterThanOrEqual(3);
  const inPathOrder = solution.map((cell) => numbers[cell]).filter((value) => value !== 0);
  expect(inPathOrder).toEqual(labels.map((_, i) => i + 1));
  expect(numbers[solution[0]]).toBe(1);
  expect(numbers[solution[size - 1]]).toBe(labels.length);
  expect(walls.length).toBeLessThanOrEqual(6);

  expect(countZip(puzzle, { limit: 2, budget: 2000000 }).count).toBe(1);
}

function checkTango(puzzle) {
  const { size, givens, edges, solution } = puzzle;
  expect(isValidSolution(solution, size)).toBe(true);
  expect(givens.filter((value) => value !== 0).length).toBeGreaterThanOrEqual(1);
  for (let i = 0; i < size * size; i++) {
    if (givens[i]) expect(givens[i]).toBe(solution[i]);
  }
  for (const edge of edges) {
    expect(solution[edge.a] === solution[edge.b]).toBe(edge.same);
  }
  expect(countTango(puzzle)).toBe(1);
}

function checkSudoku(puzzle) {
  const { solution, givens } = puzzle;
  expect(solution.length).toBe(81);
  expect(countSudoku(solution, 2)).toBe(1);
  for (let i = 0; i < 81; i++) {
    if (givens[i]) expect(givens[i]).toBe(solution[i]);
  }
  expect(countSudoku(givens, 2)).toBe(1);
  expect(puzzle.clues).toBeLessThanOrEqual(46);
}

describe('zip generator', () => {
  for (const difficulty of ['easy', 'medium', 'hard']) {
    test(`produces unique, solvable ${difficulty} puzzles`, () => {
      for (let seed = 0; seed < 4; seed++) {
        checkZip(generateZip(`zip-test-${difficulty}-${seed}`, difficulty));
      }
    });
  }

  test('is deterministic for a seed', () => {
    const a = generateZip('same-seed', 'medium');
    const b = generateZip('same-seed', 'medium');
    expect(a.numbers).toEqual(b.numbers);
    expect(a.walls).toEqual(b.walls);
    expect(a.solution).toEqual(b.solution);
  });

  test('generates quickly enough for a phone', () => {
    const started = performance.now();
    for (let seed = 0; seed < 5; seed++) generateZip(`speed-${seed}`, 'medium');
    const perPuzzle = (performance.now() - started) / 5;
    expect(perPuzzle).toBeLessThan(1500);
  });
});

describe('tango generator', () => {
  for (const difficulty of ['easy', 'medium', 'hard']) {
    test(`produces unique, solvable ${difficulty} puzzles`, () => {
      for (let seed = 0; seed < 4; seed++) {
        checkTango(generateTango(`tango-test-${difficulty}-${seed}`, difficulty));
      }
    });
  }

  test('is deterministic for a seed', () => {
    const a = generateTango('same-seed', 'medium');
    const b = generateTango('same-seed', 'medium');
    expect(a.givens).toEqual(b.givens);
    expect(a.edges).toEqual(b.edges);
  });

  test('rejects rules-breaking solutions', () => {
    const broken = search(
      { size: 6, givens: [1, 1, 1, 0, 0, 0], edges: [] },
      { limit: 1 },
    );
    expect(broken.count).toBe(0);
  });
});

describe('sudoku generator', () => {
  for (const difficulty of ['easy', 'medium', 'hard']) {
    test(`produces unique, solvable ${difficulty} puzzles`, () => {
      for (let seed = 0; seed < 3; seed++) {
        checkSudoku(generateSudoku(`sudoku-test-${difficulty}-${seed}`, difficulty));
      }
    });
  }

  test('is deterministic for a seed', () => {
    const a = generateSudoku('same-seed', 'medium');
    const b = generateSudoku('same-seed', 'medium');
    expect(a.solution).toEqual(b.solution);
    expect(a.givens).toEqual(b.givens);
  });

  test('solves a known puzzle with one solution', () => {
    const known = [
      0, 0, 3, 0, 2, 0, 6, 0, 0,
      9, 0, 0, 3, 0, 5, 0, 0, 1,
      0, 0, 1, 8, 0, 6, 4, 0, 0,
      0, 0, 8, 1, 0, 2, 9, 0, 0,
      7, 0, 0, 0, 0, 0, 0, 0, 8,
      0, 0, 6, 7, 0, 8, 2, 0, 0,
      0, 0, 2, 6, 0, 9, 5, 0, 0,
      8, 0, 0, 2, 0, 3, 0, 0, 9,
      0, 0, 5, 0, 1, 0, 3, 0, 0,
    ];
    expect(countSudoku(known, 2)).toBe(1);
  });

  test('generates quickly enough for a phone', () => {
    const started = performance.now();
    for (let seed = 0; seed < 3; seed++) generateSudoku(`speed-${seed}`, 'hard');
    const perPuzzle = (performance.now() - started) / 3;
    expect(perPuzzle).toBeLessThan(2500);
  });
});

function bruteZip({ width, height, numbers, walls }) {
  const size = width * height;
  const table = neighbours(width, height);
  const wallSet = new Set(walls.map(([a, b]) => edgeId(a, b)));
  const last = Math.max(...numbers);
  const start = numbers.indexOf(1);
  const visited = new Uint8Array(size);
  let count = 0;
  function walk(cell, depth, next) {
    if (depth === size - 1) {
      if (numbers[cell] === last) count++;
      return;
    }
    for (const n of table[cell]) {
      if (visited[n] || wallSet.has(edgeId(cell, n))) continue;
      if (numbers[n] && numbers[n] !== next) continue;
      visited[n] = 1;
      walk(n, depth + 1, numbers[n] ? next + 1 : next);
      visited[n] = 0;
    }
  }
  visited[start] = 1;
  walk(start, 0, 2);
  return count;
}

test('zip solver agrees with brute force on small boards', () => {
  let nonZero = 0;
  for (let seed = 0; seed < 60; seed++) {
    const width = 4 + (seed % 2);
    const height = 4;
    const size = width * height;
    const cells = Array.from({ length: size }, (_, i) => i);
    let state = seed * 7919 + 13;
    const rand = () => (state = (state * 1103515245 + 12345) % 2147483648) / 2147483648;
    cells.sort(() => rand() - 0.5);
    const numbers = new Array(size).fill(0);
    const clues = 2 + (seed % 5 === 0 ? 1 : 0);
    cells.slice(0, clues).forEach((cell, i) => (numbers[cell] = i + 1));
    const walls = [];
    for (let a = 0; a < size; a++) {
      for (const b of neighbours(width, height)[a]) if (a < b && rand() < 0.06) walls.push([a, b]);
    }
    const puzzle = { width, height, numbers, walls };
    const fast = countZip(puzzle, { limit: 1000000, budget: 1e9 }).count;
    expect(fast).toBe(bruteZip(puzzle));
    if (fast) nonZero++;
  }
  expect(nonZero).toBeGreaterThan(10);
});
