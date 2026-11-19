import { Rng } from '../rng.js';
import { h, haptic } from '../ui.js';

function neighbors(index, size) {
  const row = Math.floor(index / size);
  const col = index % size;
  return [
    ...(row > 0 ? [index - size] : []),
    ...(col > 0 ? [index - 1] : []),
    ...(col < size - 1 ? [index + 1] : []),
    ...(row < size - 1 ? [index + size] : []),
  ];
}

export function mergeTiles(cells, size, from, to) {
  if (!cells[from] || cells[from] !== cells[to] || !neighbors(from, size).includes(to)) {
    return null;
  }
  const next = cells.slice();
  next[to] += next[from];
  next[from] = 0;
  return next;
}

export function generate(seed) {
  const rng = new Rng(seed);
  const size = 4;
  const cells = Array(size * size).fill(0);
  cells[rng.int(cells.length)] = 64;

  // Each split is the reverse of a legal merge. Reversing them solves the board.
  for (let count = 1; count < 8; count++) {
    const splits = cells.flatMap((value, from) => value > 1
      ? neighbors(from, size).filter((to) => !cells[to]).map((to) => [from, to])
      : []);
    const [from, to] = rng.pick(splits);
    cells[from] /= 2;
    cells[to] = cells[from];
  }
  return { size, cells };
}

export function findSolution(cells, size) {
  const deadEnds = new Set();
  function search(board) {
    if (board.filter(Boolean).length === 1) return [];
    const key = board.join(',');
    if (deadEnds.has(key)) return null;
    for (const [from, value] of board.entries()) {
      if (!value) continue;
      for (const to of neighbors(from, size)) {
        const next = mergeTiles(board, size, from, to);
        if (!next) continue;
        const rest = search(next);
        if (rest) return [[from, to], ...rest];
      }
    }
    deadEnds.add(key);
    return null;
  }
  return search(cells);
}

function create(stage, { puzzle, saved, onChange, onSolve }) {
  const { size } = puzzle;
  let cells = saved?.cells ?? puzzle.cells;
  let history = saved?.history ?? [];
  let hints = saved?.hints ?? 0;
  let selected = null;
  let suggested = [];
  let solved = false;

  const status = h('div', { class: 'merge-status', role: 'status' });
  const undo = h('button', { class: 'btn', type: 'button', onclick: () => {
    cells = history.pop();
    selected = null;
    suggested = [];
    paint('Move undone.');
    onChange();
  } }, 'Undo');
  const hint = h('button', { class: 'btn', type: 'button', onclick: () => {
    const move = findSolution(cells, size)?.[0];
    if (!move) {
      paint('Undo a move to find a way forward.');
      return;
    }
    hints++;
    selected = move[0];
    suggested = move;
    paint('Merge the highlighted tiles.');
    onChange();
  } }, 'Hint');

  const tiles = cells.map((_, index) => h('button', {
    class: 'merge-tile',
    type: 'button',
    onclick: () => choose(index),
  }));
  const board = h('div', {
    class: 'merge-board',
    role: 'group',
    'aria-label': 'Number Merge board',
    style: { '--cols': size },
  }, tiles);

  function paint(message = '') {
    for (const [index, tile] of tiles.entries()) {
      const value = cells[index];
      tile.textContent = value || '';
      tile.disabled = !value;
      tile.setAttribute('aria-label', `${value || 'Empty'}, row ${Math.floor(index / size) + 1}, column ${index % size + 1}`);
      tile.setAttribute('aria-pressed', String(index === selected));
      tile.classList.toggle('suggested', suggested.includes(index));
    }
    undo.disabled = solved || history.length === 0;
    hint.disabled = solved;
    status.textContent = message || `${cells.filter(Boolean).length} tiles remaining`;
  }

  function choose(index) {
    if (solved) return;
    const next = selected === null ? null : mergeTiles(cells, size, selected, index);
    if (!next) {
      selected = selected === index ? null : index;
      suggested = [];
      paint();
      return;
    }
    history.push(cells);
    cells = next;
    selected = null;
    suggested = [];
    solved = cells.filter(Boolean).length === 1;
    paint(solved ? 'One tile remains.' : '');
    haptic();
    if (solved) onSolve();
    else onChange();
  }

  stage.append(board, status, h('div', { class: 'merge-controls' }, undo, hint));
  paint();
  return {
    getState: () => ({ cells, history, hints }),
    destroy() {},
  };
}

export const merge = {
  id: 'merge',
  name: 'Number Merge',
  icon: 'merge',
  tagline: 'Join matching numbers until one tile remains.',
  defaultDifficulty: 'classic',
  difficulties: [{ id: 'classic', label: 'Classic' }],
  rules: [
    'Select two matching numbers that share an edge.',
    'The sum lands on the second tile. The first tile becomes empty.',
    'Keep merging until one tile remains. Use Undo if you get stuck.',
  ],
  generate,
  create,
};
