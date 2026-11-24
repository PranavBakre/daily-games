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

export function projectDrag(from, size, axis, delta, pitch) {
  const direction = Math.sign(delta);
  const neighbor = from + direction * (axis === 'x' ? 1 : size);
  if (!neighbors(from, size).includes(neighbor)) return { x: 0, y: 0, to: null };

  const distance = Math.min(Math.abs(delta), pitch);
  return {
    x: axis === 'x' ? direction * distance : 0,
    y: axis === 'y' ? direction * distance : 0,
    to: distance >= pitch / 2 ? neighbor : null,
  };
}

export function isStuck(cells, size) {
  return cells.filter(Boolean).length > 1 && !cells.some((value, index) =>
    value && neighbors(index, size).some((neighbor) => cells[neighbor] === value),
  );
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
  let destination = null;
  let solved = false;
  let drag = null;

  const status = h('div', { class: 'merge-status', role: 'status' });
  const undo = h('button', { class: 'btn', type: 'button', onclick: () => {
    cells = history.pop();
    selected = null;
    destination = null;
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
    destination = move[1];
    paint(`Drag the filled tile to the outlined tile in row ${Math.floor(destination / size) + 1}, column ${destination % size + 1}.`);
    onChange();
  } }, 'Hint');

  const tiles = cells.map((_, index) => h('button', {
    class: 'merge-tile',
    type: 'button',
    // Gesture handling must work even if an older stylesheet is cached.
    style: { 'touch-action': 'none' },
    onpointerdown: (event) => startDrag(event, index),
    onclick: (event) => {
      if (event.detail === 0) choose(index);
    },
  }));
  const board = h('div', {
    class: 'merge-board',
    role: 'group',
    'aria-label': 'Number Merge board',
    style: { '--cols': size },
    onpointermove: moveDrag,
    onpointerup: endDrag,
    onpointercancel: cancelDrag,
    onlostpointercapture: cancelDrag,
    oncontextmenu: (event) => event.preventDefault(),
  }, tiles);

  function paint(message = '') {
    for (const [index, tile] of tiles.entries()) {
      const value = cells[index];
      tile.textContent = value || '';
      tile.disabled = !value;
      tile.setAttribute('aria-label', `${value || 'Empty'}, row ${Math.floor(index / size) + 1}, column ${index % size + 1}`);
      tile.setAttribute('aria-pressed', String(index === selected));
      tile.classList.toggle('suggested', index === destination);
    }
    const stuck = isStuck(cells, size);
    board.classList.toggle('stuck', stuck);
    undo.disabled = solved || history.length === 0;
    hint.disabled = solved || stuck;
    status.textContent = stuck
      ? 'No legal moves. Undo a move to keep playing.'
      : message || `${cells.filter(Boolean).length} tiles remaining`;
  }

  function choose(index) {
    if (solved || (destination !== null && index === selected)) return;
    if (selected !== null && applyMerge(selected, index)) return;
    selected = selected === index ? null : index;
    destination = null;
    paint();
  }

  function applyMerge(from, to) {
    const next = mergeTiles(cells, size, from, to);
    if (!next) return false;
    history.push(cells);
    cells = next;
    selected = null;
    destination = null;
    solved = cells.filter(Boolean).length === 1;
    paint(solved ? 'One tile remains.' : '');
    haptic();
    if (solved) onSolve();
    else onChange();
    return true;
  }

  function startDrag(event, from) {
    if (solved || drag || event.button !== 0) return;
    event.preventDefault();
    board.setPointerCapture(event.pointerId);
    drag = {
      from,
      pointerId: event.pointerId,
      x: event.clientX,
      y: event.clientY,
      axis: null,
      pitchX: tiles[1].offsetLeft - tiles[0].offsetLeft,
      pitchY: tiles[size].offsetTop - tiles[0].offsetTop,
    };
    tiles[from].classList.add('dragging');
  }

  function moveDrag(event) {
    if (drag?.pointerId !== event.pointerId) return;
    const { x, y } = dragPosition(event);
    tiles[drag.from].style.transform = `translate(${x}px, ${y}px)`;
  }

  function dragPosition(event) {
    const x = event.clientX - drag.x;
    const y = event.clientY - drag.y;
    if (!drag.axis) {
      if (Math.max(Math.abs(x), Math.abs(y)) < 6) return { x: 0, y: 0, to: null };
      drag.axis = Math.abs(x) >= Math.abs(y) ? 'x' : 'y';
    }
    return drag.axis === 'x'
      ? projectDrag(drag.from, size, 'x', x, drag.pitchX)
      : projectDrag(drag.from, size, 'y', y, drag.pitchY);
  }

  function cancelDrag(event) {
    if (drag?.pointerId !== event.pointerId) return;
    const tile = tiles[drag.from];
    drag = null;
    tile.classList.remove('dragging');
    tile.style.removeProperty('transform');
  }

  function endDrag(event) {
    if (drag?.pointerId !== event.pointerId) return;
    const from = drag.from;
    const { to } = dragPosition(event);
    cancelDrag(event);
    if (to !== null) applyMerge(from, to);
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
    'Drag a number onto an equal number that shares an edge.',
    'The sum lands on the second tile. The first tile becomes empty.',
    'Keep merging until one tile remains. Use Undo if you get stuck.',
  ],
  generate,
  create,
};
