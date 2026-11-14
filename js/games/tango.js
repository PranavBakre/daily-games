// Tango — fill the grid with suns and moons so that every row and column holds
// an equal number of each, no three of a kind touch in a line, and every edge
// badge between two cells is satisfied ( = same, ≠ different ).

import { Rng } from '../rng.js';
import { h, haptic } from '../ui.js';

export const SIZE = 6;
const SUN = 1;
const MOON = 2;

const DIFFICULTIES = {
  easy: { label: 'Easy', givens: 6, extraEdges: 3 },
  medium: { label: 'Medium', givens: 2, extraEdges: 1 },
  hard: { label: 'Hard', givens: 1, extraEdges: 0 },
};

function pairKey(a, b) {
  return a < b ? a * 1000 + b : b * 1000 + a;
}

function gridNeighbours(index, size) {
  const row = Math.floor(index / size);
  const col = index % size;
  const list = [];
  if (row > 0) list.push(index - size);
  if (row < size - 1) list.push(index + size);
  if (col > 0) list.push(index - 1);
  if (col < size - 1) list.push(index + 1);
  return list;
}

/**
 * Depth-first search with balanced-row/column pruning. Returns up to `limit`
 * solutions; `rng` randomises the digit order (used to build a fresh solution).
 */
export function search(puzzle, { limit = 2, rng = null, budget = 400000 } = {}) {
  const { size, givens, edges } = puzzle;
  const total = size * size;
  const half = size / 2;
  const grid = new Int8Array(total);
  const rowCount = new Int8Array(size * 2);
  const colCount = new Int8Array(size * 2);
  const constraints = new Map();
  for (const edge of edges) constraints.set(pairKey(edge.a, edge.b), edge.same);

  const solutions = [];
  let nodes = 0;
  let aborted = false;

  function fits(index, value) {
    const row = Math.floor(index / size);
    const col = index % size;
    if (rowCount[row * 2 + value - 1] >= half) return false;
    if (colCount[col * 2 + value - 1] >= half) return false;
    if (col >= 2 && grid[index - 1] === value && grid[index - 2] === value) return false;
    if (row >= 2 && grid[index - size] === value && grid[index - 2 * size] === value) return false;

    for (const neighbour of gridNeighbours(index, size)) {
      const other = grid[neighbour];
      if (other === 0) continue;
      const same = constraints.get(pairKey(index, neighbour));
      if (same === undefined) continue;
      if ((other === value) !== same) return false;
    }
    return true;
  }

  function walk(index) {
    if (index === total) {
      solutions.push(Array.from(grid));
      return;
    }
    if (++nodes > budget) {
      aborted = true;
      return;
    }
    const given = givens[index];
    let order = given ? [given] : [SUN, MOON];
    if (rng && !given && rng.chance(0.5)) order = [MOON, SUN];

    for (const value of order) {
      if (!fits(index, value)) continue;
      grid[index] = value;
      rowCount[Math.floor(index / size) * 2 + value - 1]++;
      colCount[(index % size) * 2 + value - 1]++;
      walk(index + 1);
      rowCount[Math.floor(index / size) * 2 + value - 1]--;
      colCount[(index % size) * 2 + value - 1]--;
      grid[index] = 0;
      if (aborted || solutions.length >= limit) return;
    }
  }

  walk(0);
  return { count: solutions.length, solutions, aborted };
}

export function countSolutions(puzzle, limit = 2) {
  return search(puzzle, { limit }).count;
}

export function isValidSolution(values, size = SIZE) {
  const half = size / 2;
  for (let i = 0; i < size * size; i++) {
    if (values[i] !== SUN && values[i] !== MOON) return false;
    const row = Math.floor(i / size);
    const col = i % size;
    if (col >= 2 && values[i] === values[i - 1] && values[i] === values[i - 2]) return false;
    if (row >= 2 && values[i] === values[i - size] && values[i] === values[i - 2 * size]) return false;
  }
  for (let line = 0; line < size; line++) {
    let rowSuns = 0;
    let colSuns = 0;
    for (let i = 0; i < size; i++) {
      if (values[line * size + i] === SUN) rowSuns++;
      if (values[i * size + line] === SUN) colSuns++;
    }
    if (rowSuns !== half || colSuns !== half) return false;
  }
  return true;
}

function allEdges(size) {
  const edges = [];
  for (let row = 0; row < size; row++) {
    for (let col = 0; col < size; col++) {
      const index = row * size + col;
      if (col < size - 1) edges.push({ a: index, b: index + 1 });
      if (row < size - 1) edges.push({ a: index, b: index + size });
    }
  }
  return edges;
}

export function generateTango(seed, difficulty = 'medium') {
  const config = DIFFICULTIES[difficulty] ?? DIFFICULTIES.medium;
  const size = SIZE;

  for (let attempt = 0; attempt < 40; attempt++) {
    const rng = new Rng(`${seed}|tango|${difficulty}|${attempt}`);

    const solution = search(
      { size, givens: new Array(size * size).fill(0), edges: [] },
      { limit: 1, rng, budget: 200000 },
    ).solutions[0];
    if (!solution) continue;

    const givens = new Array(size * size).fill(0);
    const cells = rng.shuffle(Array.from({ length: size * size }, (_, i) => i));
    for (const index of cells.slice(0, config.givens)) givens[index] = solution[index];

    const puzzle = { size, givens: givens.slice(), edges: [] };
    if (countSolutions(puzzle) !== 1) {
      const candidates = rng.shuffle(allEdges(size));
      for (const edge of candidates) {
        puzzle.edges.push({ a: edge.a, b: edge.b, same: solution[edge.a] === solution[edge.b] });
        if (countSolutions(puzzle) === 1) break;
      }
    }
    if (countSolutions(puzzle) !== 1) continue;

    // Drop every badge that is not needed, so the final board stays readable.
    const unused = puzzle.edges.slice();
    rng.shuffle(unused);
    for (const edge of unused) {
      const at = puzzle.edges.indexOf(edge);
      if (at < 0) continue;
      puzzle.edges.splice(at, 1);
      if (countSolutions(puzzle) !== 1) puzzle.edges.splice(at, 0, edge);
    }

    const extras = rng.shuffle(allEdges(size).filter((edge) => {
      return !puzzle.edges.some((existing) => existing.a === edge.a && existing.b === edge.b);
    }));
    for (const edge of extras.slice(0, config.extraEdges)) {
      puzzle.edges.push({ a: edge.a, b: edge.b, same: solution[edge.a] === solution[edge.b] });
    }

    return { ...puzzle, solution, difficulty };
  }

  throw new Error('tango: could not generate a unique puzzle');
}

const SYMBOLS = {
  [SUN]: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"><circle cx="12" cy="12" r="4.1" fill="currentColor" stroke="none"/><path d="M12 2.4v1.9M12 19.7v1.9M2.4 12h1.9M19.7 12h1.9M5.2 5.2l1.4 1.4M17.4 17.4l1.4 1.4M18.8 5.2l-1.4 1.4M6.6 17.4l-1.4 1.4"/></svg>`,
  [MOON]: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M21 13.3A8.7 8.7 0 1 1 10.7 3a7.1 7.1 0 0 0 10.3 10.3Z"/></svg>`,
};

function findConflicts(values, edges, size) {
  const bad = new Set();
  const lines = [];
  for (let line = 0; line < size; line++) {
    const row = [];
    const col = [];
    for (let i = 0; i < size; i++) {
      row.push(line * size + i);
      col.push(i * size + line);
    }
    lines.push(row, col);
  }

  for (const line of lines) {
    let suns = 0;
    let moons = 0;
    for (const index of line) {
      if (values[index] === SUN) suns++;
      if (values[index] === MOON) moons++;
    }
    if (suns > size / 2) for (const index of line) if (values[index] === SUN) bad.add(index);
    if (moons > size / 2) for (const index of line) if (values[index] === MOON) bad.add(index);

    for (let i = 0; i < line.length - 2; i++) {
      const value = values[line[i]];
      if (value !== 0 && value === values[line[i + 1]] && value === values[line[i + 2]]) {
        bad.add(line[i]);
        bad.add(line[i + 1]);
        bad.add(line[i + 2]);
      }
    }
  }

  for (const edge of edges) {
    const a = values[edge.a];
    const b = values[edge.b];
    if (a === 0 || b === 0) continue;
    if ((a === b) !== edge.same) {
      bad.add(edge.a);
      bad.add(edge.b);
    }
  }

  return bad;
}

export function createTango(host, { puzzle, saved, onChange, onSolve }) {
  const size = puzzle.size ?? SIZE;
  const values = new Array(size * size).fill(0);
  let solved = false;
  let hints = 0;
  const hinted = new Set();
  let message = '';
  let flagged = -1;

  if (saved && Array.isArray(saved.values) && saved.values.length === size * size) {
    for (let i = 0; i < values.length; i++) {
      const value = saved.values[i];
      if (puzzle.givens[i]) continue;
      if (value === SUN || value === MOON) values[i] = value;
    }
    if (Number.isInteger(saved.hints) && saved.hints > 0) hints = saved.hints;
    if (Array.isArray(saved.hinted)) {
      for (const i of saved.hinted) if (Number.isInteger(i) && values[i] === puzzle.solution[i]) hinted.add(i);
    }
  }

  const board = h('div', {
    class: 'tango-board',
    style: { '--n': size },
  });
  const grid = h('div', { class: 'tango-grid' });
  const cellNodes = [];
  const symbolNodes = [];

  for (let i = 0; i < size * size; i++) {
    const symbol = h('span', { class: 'tango-symbol' });
    const tile = h('span', { class: 'tango-tile' }, symbol);
    const cell = h('button', {
      class: 'tango-cell',
      type: 'button',
      dataset: { i: String(i) },
    }, tile);
    if (puzzle.givens[i]) {
      cell.classList.add('given');
      cell.setAttribute('aria-disabled', 'true');
      values[i] = puzzle.givens[i];
    }
    cellNodes.push(cell);
    symbolNodes.push(symbol);
    grid.append(cell);
  }

  const badgeLayer = h('div', { class: 'tango-badges' });
  for (const edge of puzzle.edges) {
    const row = Math.floor(edge.a / size);
    const col = edge.a % size;
    const horizontal = edge.b === edge.a + 1;
    const badge = h('span', {
      class: `tango-badge ${edge.same ? 'same' : 'different'}`,
      text: edge.same ? '=' : '×',
      'aria-hidden': 'true',
    });
    if (horizontal) {
      badge.style.left = `${((col + 1) / size) * 100}%`;
      badge.style.top = `${((row + 0.5) / size) * 100}%`;
    } else {
      badge.style.left = `${((col + 0.5) / size) * 100}%`;
      badge.style.top = `${((row + 1) / size) * 100}%`;
    }
    badgeLayer.append(badge);
  }

  board.append(grid, badgeLayer);

  const hint = h('p', { class: 'stage-hint' });
  const controls = h(
    'div',
    { class: 'stage-controls' },
    h('button', {
      class: 'btn ghost',
      type: 'button',
      onclick: () => {
        if (solved) return;
        for (let i = 0; i < values.length; i++) if (!puzzle.givens[i] && !hinted.has(i)) values[i] = 0;
        message = '';
        flagged = -1;
        refresh();
        haptic();
      },
    }, 'Clear'),
    h('button', { class: 'btn ghost', type: 'button', onclick: () => giveHint() }, 'Hint'),
  );

  const legend = h('p', { class: 'stage-legend' }, 'Tap a cell: sun → moon → empty');

  host.append(board, hint, legend, controls);

  function renderCell(index) {
    const value = values[index];
    const symbol = symbolNodes[index];
    if (value === 0) {
      symbol.innerHTML = '';
      cellNodes[index].dataset.value = '0';
    } else {
      symbol.innerHTML = SYMBOLS[value];
      cellNodes[index].dataset.value = String(value);
    }
  }

  function refresh() {
    for (let i = 0; i < values.length; i++) renderCell(i);

    const bad = findConflicts(values, puzzle.edges, size);
    for (let i = 0; i < values.length; i++) {
      cellNodes[i].classList.toggle('bad', bad.has(i));
      cellNodes[i].classList.toggle('hinted', hinted.has(i));
      cellNodes[i].classList.toggle('flagged', i === flagged);
    }

    const filled = values.filter((value) => value !== 0).length;
    hint.textContent = message || (bad.size > 0
      ? 'Something clashes — check the highlighted cells.'
      : `${filled} of ${values.length} cells`);

    onChange();

    if (!solved && filled === values.length && bad.size === 0) {
      solved = true;
      board.classList.add('solved');
      haptic([12, 40, 12]);
      onSolve();
    }
  }

  function filledAround(index) {
    const row = Math.floor(index / size);
    const col = index % size;
    let score = 0;
    if (row > 0 && values[index - size]) score++;
    if (row < size - 1 && values[index + size]) score++;
    if (col > 0 && values[index - 1]) score++;
    if (col < size - 1 && values[index + 1]) score++;
    for (const edge of puzzle.edges) if (edge.a === index || edge.b === index) score++;
    return score;
  }

  function giveHint() {
    if (solved) return;
    hints++;

    const wrong = values.findIndex((value, i) => value !== 0 && value !== puzzle.solution[i]);
    if (wrong !== -1) {
      flagged = wrong;
      message = 'This cell is wrong. Tap it to change it.';
      haptic([10, 30, 10]);
      refresh();
      return;
    }

    let target = -1;
    let best = -1;
    for (let i = 0; i < values.length; i++) {
      if (values[i]) continue;
      const score = filledAround(i);
      if (score > best) {
        best = score;
        target = i;
      }
    }
    if (target === -1) return;

    values[target] = puzzle.solution[target];
    hinted.add(target);
    flagged = -1;
    message = `Hint: a ${values[target] === SUN ? 'sun' : 'moon'} goes in the marked cell.`;
    haptic();
    refresh();
  }

  function onBoardClick(event) {
    if (solved) return;
    const cell = event.target.closest('.tango-cell');
    if (!cell) return;
    const index = Number(cell.dataset.i);
    if (puzzle.givens[index] || hinted.has(index)) return;
    message = '';
    flagged = -1;
    values[index] = values[index] === 0 ? SUN : values[index] === SUN ? MOON : 0;
    haptic();
    refresh();
  }

  grid.addEventListener('click', onBoardClick);

  refresh();

  return {
    getState() {
      return { values: values.slice(), hints, hinted: [...hinted] };
    },
    destroy() {
      grid.removeEventListener('click', onBoardClick);
      host.replaceChildren();
    },
  };
}

export const tango = {
  id: 'tango',
  name: 'Tango',
  tagline: 'Suns, moons and balance',
  accent: 'amber',
  icon: 'tango',
  defaultDifficulty: 'medium',
  difficulties: Object.entries(DIFFICULTIES).map(([id, config]) => ({ id, label: config.label })),
  generate: generateTango,
  create: createTango,
  rules: [
    'Each row and each column must hold three suns and three moons.',
    'No three of the same symbol may sit next to each other in a line.',
    'A badge between two cells must hold: = means the same symbol, ≠ means different.',
    'Tap a cell to cycle empty → sun → moon → empty.',
    'Hint points out a wrong cell, or fills one for you.',
  ],
};
