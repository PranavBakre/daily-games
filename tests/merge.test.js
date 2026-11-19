import { expect, test } from 'bun:test';
import { findSolution, generate, isStuck, mergeTiles, projectDrag } from '../js/games/merge.js';

test('merges equal edge neighbors into their sum and leaves other cells fixed', () => {
  const board = [2, 2, 4, 0, 2, 0, 2, 2, 0];
  expect(mergeTiles(board, 3, 0, 1)).toEqual([0, 4, 4, 0, 2, 0, 2, 2, 0]);
  expect(mergeTiles(board, 3, 0, 4)).toBeNull();
  expect(mergeTiles(board, 3, 6, 4)).toBeNull();
  expect(mergeTiles(board, 3, 1, 2)).toBeNull();
  expect(mergeTiles([0, 0, 2, 2], 2, 0, 1)).toBeNull();
  expect(mergeTiles([0, 0, 2, 2, 2, 0], 3, 2, 3)).toBeNull();
  expect(board[0]).toBe(2);
});

test('generated boards are deterministic and hints lead to one tile', () => {
  const first = generate('2026-11-19');
  expect(generate('2026-11-19')).toEqual(first);
  expect(generate('2026-11-20')).not.toEqual(first);
  for (let seed = 0; seed < 100; seed++) {
    const { size, cells } = generate(String(seed));
    const solution = findSolution(cells, size);
    expect(solution).not.toBeNull();
    expect(solution.length).toBe(7);
    const final = solution.reduce((board, [from, to]) => mergeTiles(board, size, from, to), cells);
    expect(final.filter(Boolean)).toEqual([cells.reduce((sum, value) => sum + value, 0)]);
  }
});

test('hints distinguish a dead end from a completed board', () => {
  expect(findSolution([2, 0, 0, 2], 2)).toBeNull();
  expect(findSolution([0, 4, 0, 0], 2)).toEqual([]);
});

test('flags only unfinished boards with no legal merge', () => {
  expect(isStuck([2, 0, 0, 2], 2)).toBe(true);
  expect(isStuck([2, 4, 0, 0], 2)).toBe(true);
  expect(isStuck([2, 2, 0, 0], 2)).toBe(false);
  expect(isStuck([2, 0, 2, 0], 2)).toBe(false);
  expect(isStuck([0, 4, 0, 0], 2)).toBe(false);
});

test('projects a drag onto one axis and one neighboring cell', () => {
  expect(projectDrag(5, 4, 'x', 500, 80)).toEqual({ x: 80, y: 0, to: 6 });
  expect(projectDrag(5, 4, 'y', -500, 80)).toEqual({ x: 0, y: -80, to: 1 });
  expect(projectDrag(5, 4, 'x', -39, 80)).toEqual({ x: -39, y: 0, to: null });
  expect(projectDrag(5, 4, 'x', 40, 80)).toEqual({ x: 40, y: 0, to: 6 });
  expect(projectDrag(7, 4, 'x', 500, 80)).toEqual({ x: 0, y: 0, to: null });
  expect(projectDrag(1, 4, 'y', -500, 80)).toEqual({ x: 0, y: 0, to: null });
});
