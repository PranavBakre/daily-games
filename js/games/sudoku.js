// Sudoku — classic 9x9. Puzzles are dug out of a random complete grid and every
// one of them is checked for a single solution before it is used.

import { Rng } from '../rng.js';
import { h, haptic } from '../ui.js';

const ALL = 0x1ff;
const BIT_VALUE = new Uint8Array(512);
for (let k = 0; k < 9; k++) BIT_VALUE[1 << k] = k + 1;

const POPCOUNT = new Uint8Array(512);
for (let i = 1; i < 512; i++) POPCOUNT[i] = POPCOUNT[i >> 1] + (i & 1);

const DIFFICULTIES = {
  easy: { label: 'Easy', clues: 40 },
  medium: { label: 'Medium', clues: 32 },
  hard: { label: 'Hard', clues: 26 },
};

function boxOf(index) {
  const row = Math.floor(index / 9);
  const col = index % 9;
  return Math.floor(row / 3) * 3 + Math.floor(col / 3);
}

export function countSolutions(grid, limit = 2) {
  const cells = Uint8Array.from(grid, (value) => value | 0);
  const rows = new Uint16Array(9);
  const cols = new Uint16Array(9);
  const boxes = new Uint16Array(9);

  for (let i = 0; i < 81; i++) {
    const value = cells[i];
    if (!value) continue;
    const bit = 1 << (value - 1);
    const row = Math.floor(i / 9);
    const col = i % 9;
    const box = boxOf(i);
    if ((rows[row] | cols[col] | boxes[box]) & bit) return 0;
    rows[row] |= bit;
    cols[col] |= bit;
    boxes[box] |= bit;
  }

  let count = 0;

  function search() {
    let best = -1;
    let bestMask = 0;
    let bestCount = 10;

    for (let i = 0; i < 81; i++) {
      if (cells[i]) continue;
      const row = Math.floor(i / 9);
      const col = i % 9;
      const free = ~(rows[row] | cols[col] | boxes[boxOf(i)]) & ALL;
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

    const row = Math.floor(best / 9);
    const col = best % 9;
    const box = boxOf(best);
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
function fullGrid(rng) {
  const digits = rng.shuffle([1, 2, 3, 4, 5, 6, 7, 8, 9]);
  const rows = [];
  for (const band of rng.shuffle([0, 1, 2])) {
    for (const row of rng.shuffle([0, 1, 2])) rows.push(band * 3 + row);
  }
  const cols = [];
  for (const stack of rng.shuffle([0, 1, 2])) {
    for (const col of rng.shuffle([0, 1, 2])) cols.push(stack * 3 + col);
  }

  const grid = new Array(81);
  for (let r = 0; r < 9; r++) {
    for (let c = 0; c < 9; c++) {
      const pattern = (rows[r] * 3 + Math.floor(rows[r] / 3) + cols[c]) % 9;
      grid[r * 9 + c] = digits[pattern];
    }
  }
  return grid;
}

export function generateSudoku(seed, difficulty = 'medium') {
  const config = DIFFICULTIES[difficulty] ?? DIFFICULTIES.medium;

  for (let attempt = 0; attempt < 8; attempt++) {
    const rng = new Rng(`${seed}|sudoku|${difficulty}|${attempt}`);
    const solution = fullGrid(rng);
    const puzzle = solution.slice();
    let clues = 81;

    for (const index of rng.shuffle(Array.from({ length: 81 }, (_, i) => i))) {
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
      return { solution, givens: puzzle, clues, difficulty };
    }
  }

  throw new Error('sudoku: could not generate a puzzle');
}

function grouping() {
  const rows = [];
  const cols = [];
  const boxes = [];
  for (let i = 0; i < 9; i++) {
    rows.push([]);
    cols.push([]);
    boxes.push([]);
  }
  for (let i = 0; i < 81; i++) {
    const row = Math.floor(i / 9);
    const col = i % 9;
    rows[row].push(i);
    cols[col].push(i);
    boxes[boxOf(i)].push(i);
  }
  return { rows, cols, boxes };
}

const GROUPS = grouping();
const PEERS = Array.from({ length: 81 }, (_, i) => {
  const row = Math.floor(i / 9);
  const col = i % 9;
  return [...new Set([...GROUPS.rows[row], ...GROUPS.cols[col], ...GROUPS.boxes[boxOf(i)]])].filter((j) => j !== i);
});

function findConflicts(values) {
  const bad = new Set();
  for (const group of [...GROUPS.rows, ...GROUPS.cols, ...GROUPS.boxes]) {
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
  const values = new Array(81).fill(0);
  const notes = new Array(81).fill(0);
  let selected = -1;
  let notesMode = false;
  let solved = false;

  for (let i = 0; i < 81; i++) if (puzzle.givens[i]) values[i] = puzzle.givens[i];

  if (saved && Array.isArray(saved.values) && saved.values.length === 81) {
    for (let i = 0; i < 81; i++) {
      if (puzzle.givens[i]) continue;
      const value = saved.values[i];
      if (Number.isInteger(value) && value >= 0 && value <= 9) values[i] = value;
    }
    if (Array.isArray(saved.notes) && saved.notes.length === 81) {
      for (let i = 0; i < 81; i++) {
        if (puzzle.givens[i]) continue;
        const mask = saved.notes[i];
        if (Number.isInteger(mask) && mask >= 0 && mask <= ALL) notes[i] = mask;
      }
    }
    if (Number.isInteger(saved.selected) && saved.selected >= 0 && saved.selected < 81) {
      selected = saved.selected;
    }
    if (typeof saved.notesMode === 'boolean') notesMode = saved.notesMode;
  }

  const board = h('div', { class: 'sudoku-board' });
  const grid = h('div', { class: 'sudoku-grid' });
  const cellNodes = [];
  const valueNodes = [];
  const noteNodes = [];

  for (let i = 0; i < 81; i++) {
    const row = Math.floor(i / 9);
    const col = i % 9;
    const valueNode = h('span', { class: 'sd-value' });
    const noteNode = h('span', { class: 'sd-notes' });
    const noteCells = [];
    for (let d = 1; d <= 9; d++) {
      const note = h('span', { class: 'sd-note' });
      noteCells.push(note);
      noteNode.append(note);
    }
    const cell = h('div', { class: 'sd-cell', dataset: { i: String(i) } }, noteNode, valueNode);
    if (col % 3 === 2 && col !== 8) cell.classList.add('box-right');
    if (row % 3 === 2 && row !== 8) cell.classList.add('box-bottom');
    if (col === 8) cell.classList.add('last-col');
    if (row === 8) cell.classList.add('last-row');
    cellNodes.push(cell);
    valueNodes.push(valueNode);
    noteNodes.push(noteCells);
    grid.append(cell);
  }
  board.append(grid);

  const numpad = h('div', { class: 'numpad' });
  const padButtons = [];
  for (let d = 1; d <= 9; d++) {
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

  const tools = h('div', { class: 'sudoku-tools' }, notesButton, eraseButton);
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
    return findConflicts(values);
  }

  function refresh() {
    const bad = conflicts();
    const selectedValue = selected >= 0 ? values[selected] : 0;
    const peerSet = selected >= 0 ? new Set(PEERS[selected]) : new Set();

    for (let i = 0; i < 81; i++) {
      const cell = cellNodes[i];
      const value = values[i];
      const isGiven = puzzle.givens[i] !== 0;

      cell.classList.toggle('given', isGiven);
      cell.classList.toggle('selected', i === selected);
      cell.classList.toggle('peer', peerSet.has(i));
      cell.classList.toggle('same', value !== 0 && value === selectedValue && i !== selected);
      cell.classList.toggle('bad', bad.has(i));

      valueNodes[i].textContent = value ? String(value) : '';
      const noteMask = value ? 0 : notes[i];
      for (let d = 1; d <= 9; d++) {
        noteNodes[i][d - 1].textContent = noteMask & (1 << (d - 1)) ? String(d) : '';
      }
    }

    for (let d = 1; d <= 9; d++) {
      let used = 0;
      for (let i = 0; i < 81; i++) if (values[i] === d) used++;
      const button = padButtons[d - 1];
      button.classList.toggle('complete', used >= 9);
      button.querySelector('.pad-left').textContent = used >= 9 ? '' : String(9 - used);
    }

    const filled = values.filter((value) => value !== 0).length;
    hint.textContent = bad.size > 0
      ? 'That digit repeats in a row, column or box.'
      : `${filled} of 81 cells filled`;

    onChange();

    if (!solved && filled === 81 && bad.size === 0) {
      solved = true;
      board.classList.add('solved');
      haptic([12, 40, 12]);
      onSolve();
    }
  }

  function select(index) {
    selected = index;
    refresh();
    onChange();
  }

  function place(digit) {
    if (solved || selected < 0 || puzzle.givens[selected]) return;

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
    if (solved || selected < 0 || puzzle.givens[selected]) return;
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
    if (event.key >= '1' && event.key <= '9') {
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
    const moves = { ArrowUp: -9, ArrowDown: 9, ArrowLeft: -1, ArrowRight: 1 };
    const delta = moves[event.key];
    if (delta) {
      const row = Math.floor(selected / 9);
      const col = selected % 9;
      let nextRow = row;
      let nextCol = col;
      if (delta === -9) nextRow = (row + 8) % 9;
      if (delta === 9) nextRow = (row + 1) % 9;
      if (delta === -1) nextCol = (col + 8) % 9;
      if (delta === 1) nextCol = (col + 1) % 9;
      select(nextRow * 9 + nextCol);
      event.preventDefault();
    }
  }

  grid.addEventListener('click', onBoardClick);
  document.addEventListener('keydown', onKeyDown);

  refresh();

  return {
    getState() {
      return { values: values.slice(), notes: notes.slice(), selected, notesMode };
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
  tagline: 'Nine by nine, every day',
  accent: 'sky',
  icon: 'sudoku',
  defaultDifficulty: 'medium',
  difficulties: Object.entries(DIFFICULTIES).map(([id, config]) => ({ id, label: config.label })),
  generate: generateSudoku,
  create: createSudoku,
  rules: [
    'Fill the grid so every row, column and 3×3 box holds the digits 1–9 exactly once.',
    'Tap a cell, then a number to fill it.',
    'Notes lets you pencil in small candidates instead of a final digit.',
  ],
};
