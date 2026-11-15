// Sudoku — classic 9x9 with 3x3 boxes, or a 6x6 mini with 2x3 boxes. Puzzles
// are dug out of a random complete grid and every one of them is checked for a
// single solution before it is used.

import { Rng } from '../rng.js';
import { h, haptic } from '../ui.js';

const BIT_VALUE = new Uint8Array(512);
for (let k = 0; k < 9; k++) BIT_VALUE[1 << k] = k + 1;

const POPCOUNT = new Uint8Array(512);
for (let i = 1; i < 512; i++) POPCOUNT[i] = POPCOUNT[i >> 1] + (i & 1);

const DIFFICULTIES = {
  mini: { label: 'Mini 6×6', size: 6, clues: 14 },
  easy: { label: 'Easy', size: 9, clues: 40 },
  medium: { label: 'Medium', size: 9, clues: 32 },
  hard: { label: 'Hard', size: 9, clues: 26 },
};

const BOX_SHAPE = { 6: [2, 3], 9: [3, 3] };
const layouts = new Map();

/** Geometry for an n x n board: box shape, units and each cell's peers. */
function layoutFor(n) {
  if (layouts.has(n)) return layouts.get(n);
  const [boxRows, boxCols] = BOX_SHAPE[n];
  const cells = n * n;
  const boxOf = new Uint8Array(cells);
  const rows = [];
  const cols = [];
  const boxes = [];
  for (let i = 0; i < n; i++) {
    rows.push([]);
    cols.push([]);
    boxes.push([]);
  }
  for (let i = 0; i < cells; i++) {
    const row = Math.floor(i / n);
    const col = i % n;
    boxOf[i] = Math.floor(row / boxRows) * (n / boxCols) + Math.floor(col / boxCols);
    rows[row].push(i);
    cols[col].push(i);
    boxes[boxOf[i]].push(i);
  }
  const peers = Array.from({ length: cells }, (_, i) => {
    const row = Math.floor(i / n);
    const col = i % n;
    return [...new Set([...rows[row], ...cols[col], ...boxes[boxOf[i]]])].filter((j) => j !== i);
  });
  const layout = {
    n,
    cells,
    all: (1 << n) - 1,
    boxRows,
    boxCols,
    boxOf,
    units: [...rows, ...cols, ...boxes],
    peers,
  };
  layouts.set(n, layout);
  return layout;
}

export function countSolutions(grid, limit = 2) {
  const { n, cells: total, all, boxOf } = layoutFor(Math.round(Math.sqrt(grid.length)));
  const cells = Uint8Array.from(grid, (value) => value | 0);
  const rows = new Uint16Array(n);
  const cols = new Uint16Array(n);
  const boxes = new Uint16Array(n);

  for (let i = 0; i < total; i++) {
    const value = cells[i];
    if (!value) continue;
    const bit = 1 << (value - 1);
    const row = Math.floor(i / n);
    const col = i % n;
    const box = boxOf[i];
    if ((rows[row] | cols[col] | boxes[box]) & bit) return 0;
    rows[row] |= bit;
    cols[col] |= bit;
    boxes[box] |= bit;
  }

  let count = 0;

  function search() {
    let best = -1;
    let bestMask = 0;
    let bestCount = n + 1;

    for (let i = 0; i < total; i++) {
      if (cells[i]) continue;
      const row = Math.floor(i / n);
      const col = i % n;
      const free = ~(rows[row] | cols[col] | boxes[boxOf[i]]) & all;
      if (free === 0) return;
      const options = POPCOUNT[free];
      if (options < bestCount) {
        bestCount = options;
        best = i;
        bestMask = free;
        if (options === 1) break;
      }
    }

    if (best < 0) {
      count++;
      return;
    }

    const row = Math.floor(best / n);
    const col = best % n;
    const box = boxOf[best];
    let mask = bestMask;
    while (mask) {
      const bit = mask & -mask;
      mask ^= bit;
      cells[best] = BIT_VALUE[bit];
      rows[row] |= bit;
      cols[col] |= bit;
      boxes[box] |= bit;
      search();
      rows[row] ^= bit;
      cols[col] ^= bit;
      boxes[box] ^= bit;
      cells[best] = 0;
      if (count >= limit) return;
    }
  }

  search();
  return count;
}

/** A random complete grid, built from the classic pattern then permuted. */
function fullGrid(rng, n) {
  const { boxRows, boxCols } = layoutFor(n);
  const range = (k) => Array.from({ length: k }, (_, i) => i);
  const digits = rng.shuffle(range(n).map((i) => i + 1));
  const rows = [];
  for (const band of rng.shuffle(range(n / boxRows))) {
    for (const row of rng.shuffle(range(boxRows))) rows.push(band * boxRows + row);
  }
  const cols = [];
  for (const stack of rng.shuffle(range(n / boxCols))) {
    for (const col of rng.shuffle(range(boxCols))) cols.push(stack * boxCols + col);
  }

  const grid = new Array(n * n);
  for (let r = 0; r < n; r++) {
    for (let c = 0; c < n; c++) {
      const source = rows[r];
      const pattern = (boxCols * (source % boxRows) + Math.floor(source / boxRows) + cols[c]) % n;
      grid[r * n + c] = digits[pattern];
    }
  }
  return grid;
}

export function generateSudoku(seed, difficulty = 'medium') {
  const config = DIFFICULTIES[difficulty] ?? DIFFICULTIES.medium;
  const n = config.size;
  const cells = n * n;

  for (let attempt = 0; attempt < 8; attempt++) {
    const rng = new Rng(`${seed}|sudoku|${difficulty}|${attempt}`);
    const solution = fullGrid(rng, n);
    const puzzle = solution.slice();
    let clues = cells;

    for (const index of rng.shuffle(Array.from({ length: cells }, (_, i) => i))) {
      if (clues <= config.clues) break;
      const backup = puzzle[index];
      puzzle[index] = 0;
      if (countSolutions(puzzle, 2) === 1) {
        clues--;
      } else {
        puzzle[index] = backup;
      }
    }

    if (clues <= config.clues + 6) {
      return { size: n, solution, givens: puzzle, clues, difficulty };
    }
  }

  throw new Error('sudoku: could not generate a puzzle');
}

function findConflicts(values, units) {
  const bad = new Set();
  for (const group of units) {
    const seen = new Map();
    for (const index of group) {
      const value = values[index];
      if (!value) continue;
      if (seen.has(value)) {
        bad.add(index);
        bad.add(seen.get(value));
      } else {
        seen.set(value, index);
      }
    }
  }
  return bad;
}

export function createSudoku(host, { puzzle, saved, onChange, onSolve }) {
  const L = layoutFor(puzzle.size ?? 9);
  const { n, cells: total, peers: PEERS } = L;
  const values = new Array(total).fill(0);
  const notes = new Array(total).fill(0);
  let selected = -1;
  let notesMode = false;
  let solved = false;
  let hints = 0;
  const hinted = new Set();
  let message = '';
  let flagged = -1;
  let doneUnits = null;

  for (let i = 0; i < total; i++) if (puzzle.givens[i]) values[i] = puzzle.givens[i];

  if (saved && Array.isArray(saved.values) && saved.values.length === total) {
    for (let i = 0; i < total; i++) {
      if (puzzle.givens[i]) continue;
      const value = saved.values[i];
      if (Number.isInteger(value) && value >= 0 && value <= n) values[i] = value;
    }
    if (Array.isArray(saved.notes) && saved.notes.length === total) {
      for (let i = 0; i < total; i++) {
        if (puzzle.givens[i]) continue;
        const mask = saved.notes[i];
        if (Number.isInteger(mask) && mask >= 0 && mask <= L.all) notes[i] = mask;
      }
    }
    if (Number.isInteger(saved.selected) && saved.selected >= 0 && saved.selected < total) {
      selected = saved.selected;
    }
    if (typeof saved.notesMode === 'boolean') notesMode = saved.notesMode;
    if (Number.isInteger(saved.hints) && saved.hints > 0) hints = saved.hints;
    if (Array.isArray(saved.hinted)) {
      for (const i of saved.hinted) if (Number.isInteger(i) && values[i] === puzzle.solution[i]) hinted.add(i);
    }
  }

  const board = h('div', { class: `sudoku-board size-${n}`, style: { '--n': n } });
  const grid = h('div', { class: 'sudoku-grid' });
  const cellNodes = [];
  const valueNodes = [];
  const noteNodes = [];

  for (let i = 0; i < total; i++) {
    const row = Math.floor(i / n);
    const col = i % n;
    const valueNode = h('span', { class: 'sd-value' });
    const noteNode = h('span', { class: 'sd-notes' });
    const noteCells = [];
    for (let d = 1; d <= n; d++) {
      const note = h('span', { class: 'sd-note' });
      noteCells.push(note);
      noteNode.append(note);
    }
    const cell = h('div', { class: 'sd-cell', dataset: { i: String(i) } }, noteNode, valueNode);
    if (col % L.boxCols === L.boxCols - 1 && col !== n - 1) cell.classList.add('box-right');
    if (row % L.boxRows === L.boxRows - 1 && row !== n - 1) cell.classList.add('box-bottom');
    if (col === n - 1) cell.classList.add('last-col');
    if (row === n - 1) cell.classList.add('last-row');
    cellNodes.push(cell);
    valueNodes.push(valueNode);
    noteNodes.push(noteCells);
    grid.append(cell);
  }
  board.append(grid);

  const numpad = h('div', { class: 'numpad', style: { '--n': n } });
  const padButtons = [];
  for (let d = 1; d <= n; d++) {
    const button = h(
      'button',
      {
        class: 'pad-key',
        type: 'button',
        dataset: { digit: String(d) },
        onclick: () => place(d),
      },
      h('span', { class: 'pad-digit', text: String(d) }),
      h('span', { class: 'pad-left', text: '' }),
    );
    padButtons.push(button);
    numpad.append(button);
  }

  const notesButton = h(
    'button',
    {
      class: 'btn ghost notes-toggle',
      type: 'button',
      onclick: () => {
        notesMode = !notesMode;
        notesButton.classList.toggle('active', notesMode);
        notesButton.setAttribute('aria-pressed', String(notesMode));
        notesButton.querySelector('.label').textContent = notesMode ? 'Notes on' : 'Notes';
        haptic();
        onChange();
      },
    },
    h('span', { class: 'label', text: 'Notes' }),
  );

  const eraseButton = h(
    'button',
    { class: 'btn ghost', type: 'button', onclick: () => erase() },
    'Erase',
  );

  const hintButton = h(
    'button',
    { class: 'btn ghost', type: 'button', onclick: () => giveHint() },
    'Hint',
  );

  const tools = h('div', { class: 'sudoku-tools' }, notesButton, eraseButton, hintButton);
  const hint = h('p', { class: 'stage-hint' });

  host.append(board, numpad, tools, hint);

  if (notesMode) {
    notesButton.classList.add('active');
    notesButton.setAttribute('aria-pressed', 'true');
    notesButton.querySelector('.label').textContent = 'Notes on';
  }

  if (selected < 0) {
    const firstEmpty = values.findIndex((value) => value === 0);
    selected = firstEmpty === -1 ? 0 : firstEmpty;
  }

  function conflicts() {
    return findConflicts(values, L.units);
  }

  function refresh() {
    const bad = conflicts();
    const selectedValue = selected >= 0 ? values[selected] : 0;
    const peerSet = selected >= 0 ? new Set(PEERS[selected]) : new Set();

    for (let i = 0; i < total; i++) {
      const cell = cellNodes[i];
      const value = values[i];
      const isGiven = puzzle.givens[i] !== 0;

      cell.classList.toggle('given', isGiven);
      cell.classList.toggle('selected', i === selected);
      cell.classList.toggle('peer', peerSet.has(i));
      cell.classList.toggle('same', value !== 0 && value === selectedValue && i !== selected);
      cell.classList.toggle('bad', bad.has(i));
      cell.classList.toggle('hinted', hinted.has(i));
      cell.classList.toggle('flagged', i === flagged);

      valueNodes[i].textContent = value ? String(value) : '';
      const noteMask = value ? 0 : notes[i];
      for (let d = 1; d <= n; d++) {
        noteNodes[i][d - 1].textContent = noteMask & (1 << (d - 1)) ? String(d) : '';
      }
    }

    for (let d = 1; d <= n; d++) {
      let used = 0;
      for (let i = 0; i < total; i++) if (values[i] === d) used++;
      const button = padButtons[d - 1];
      button.classList.toggle('complete', used >= n);
      button.querySelector('.pad-left').textContent = used >= n ? '' : String(n - used);
    }

    const filled = values.filter((value) => value !== 0).length;
    hint.textContent = message || (bad.size > 0
      ? 'That digit repeats in a row, column or box.'
      : `${filled} of ${total} cells filled`);

    markCompletedUnits();

    onChange();

    if (!solved && filled === total && bad.size === 0) {
      solved = true;
      board.classList.add('solved');
      haptic([12, 40, 12]);
      onSolve();
    }
  }

  function markCompletedUnits() {
    const { units } = L;
    const now = new Set();
    units.forEach((unit, u) => {
      if (unit.every((i) => values[i] === puzzle.solution[i])) now.add(u);
    });

    const doneCells = new Set();
    for (const u of now) for (const i of units[u]) doneCells.add(i);
    for (let i = 0; i < total; i++) cellNodes[i].classList.toggle('done', doneCells.has(i));

    // The first pass only records state, so a restored board does not replay sweeps.
    if (doneUnits) {
      for (const u of now) {
        if (doneUnits.has(u)) continue;
        units[u].forEach((i, k) => {
          const cell = cellNodes[i];
          cell.classList.remove('sweep');
          void cell.offsetWidth;
          cell.style.animationDelay = `${k * 40}ms`;
          cell.classList.add('sweep');
        });
      }
    }
    doneUnits = now;
  }

  function candidateCount(index) {
    let mask = 0;
    for (const peer of PEERS[index]) if (values[peer]) mask |= 1 << (values[peer] - 1);
    let count = 0;
    for (let d = 0; d < n; d++) if (!(mask & (1 << d))) count++;
    return count;
  }

  function giveHint() {
    if (solved) return;
    hints++;

    const wrong = values.findIndex((value, i) => value !== 0 && value !== puzzle.solution[i]);
    if (wrong !== -1) {
      selected = wrong;
      flagged = wrong;
      message = 'This cell is wrong. Erase it and try again.';
      haptic([10, 30, 10]);
      refresh();
      return;
    }

    let target = selected >= 0 && values[selected] === 0 ? selected : -1;
    if (target === -1) {
      let fewest = n + 1;
      for (let i = 0; i < total; i++) {
        if (values[i]) continue;
        const count = candidateCount(i);
        if (count < fewest) {
          fewest = count;
          target = i;
        }
      }
    }
    if (target === -1) return;

    const digit = puzzle.solution[target];
    values[target] = digit;
    notes[target] = 0;
    for (const peer of PEERS[target]) notes[peer] &= ~(1 << (digit - 1));
    hinted.add(target);
    selected = target;
    flagged = -1;
    message = `Hint: a ${digit} goes here.`;
    haptic();
    refresh();
  }

  function clearMessage() {
    message = '';
    flagged = -1;
  }

  function select(index) {
    clearMessage();
    selected = index;
    refresh();
    onChange();
  }

  function place(digit) {
    if (solved || selected < 0 || puzzle.givens[selected] || hinted.has(selected)) return;
    clearMessage();

    if (notesMode) {
      if (values[selected]) return;
      notes[selected] ^= 1 << (digit - 1);
    } else {
      if (values[selected] === digit) {
        values[selected] = 0;
      } else {
        values[selected] = digit;
        notes[selected] = 0;
        for (const peer of PEERS[selected]) {
          notes[peer] &= ~(1 << (digit - 1));
        }
      }
    }
    haptic();
    refresh();
  }

  function erase() {
    if (solved || selected < 0 || puzzle.givens[selected] || hinted.has(selected)) return;
    clearMessage();
    values[selected] = 0;
    notes[selected] = 0;
    haptic();
    refresh();
  }

  function onBoardClick(event) {
    const cell = event.target.closest('.sd-cell');
    if (!cell) return;
    select(Number(cell.dataset.i));
  }

  function onKeyDown(event) {
    if (event.metaKey || event.ctrlKey || event.altKey) return;
    if (event.key >= '1' && event.key <= String(n)) {
      place(Number(event.key));
      event.preventDefault();
      return;
    }
    if (event.key === 'Backspace' || event.key === 'Delete' || event.key === '0') {
      erase();
      event.preventDefault();
      return;
    }
    if (event.key === 'n' || event.key === 'N') {
      notesButton.click();
      event.preventDefault();
      return;
    }
    const moves = { ArrowUp: [-1, 0], ArrowDown: [1, 0], ArrowLeft: [0, -1], ArrowRight: [0, 1] };
    const delta = moves[event.key];
    if (delta) {
      const row = (Math.floor(selected / n) + delta[0] + n) % n;
      const col = ((selected % n) + delta[1] + n) % n;
      select(row * n + col);
      event.preventDefault();
    }
  }

  grid.addEventListener('click', onBoardClick);
  document.addEventListener('keydown', onKeyDown);

  refresh();

  return {
    getState() {
      return { values: values.slice(), notes: notes.slice(), selected, notesMode, hints, hinted: [...hinted] };
    },
    destroy() {
      grid.removeEventListener('click', onBoardClick);
      document.removeEventListener('keydown', onKeyDown);
      host.replaceChildren();
    },
  };
}

export const sudoku = {
  id: 'sudoku',
  name: 'Sudoku',
  tagline: 'Fill every row, column and box.',
  icon: 'sudoku',
  defaultDifficulty: 'mini',
  difficulties: Object.entries(DIFFICULTIES).map(([id, config]) => ({ id, label: config.label })),
  generate: generateSudoku,
  create: createSudoku,
  rules: [
    'Fill every row, column and box with each number once.',
    'Tap a cell, then a number. Notes pencils in candidates.',
    'Hint points out a wrong number, or fills one cell for you.',
  ],
};
