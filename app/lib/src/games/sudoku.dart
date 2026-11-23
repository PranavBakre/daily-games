import 'dart:math' as math;

import '../rng.dart';

class SudokuDifficulty {
  const SudokuDifficulty(this.id, this.label, this.size, this.clues);

  final String id;
  final String label;
  final int size;
  final int clues;
}

const sudokuDifficulties = [
  SudokuDifficulty('mini', 'Mini 6×6', 6, 14),
  SudokuDifficulty('easy', 'Easy', 9, 40),
  SudokuDifficulty('medium', 'Medium', 9, 32),
  SudokuDifficulty('hard', 'Hard', 9, 26),
];

SudokuDifficulty sudokuDifficulty(String id) => sudokuDifficulties.firstWhere(
  (difficulty) => difficulty.id == id,
  orElse: () => sudokuDifficulties[2],
);

const _boxShapes = {6: [2, 3], 9: [3, 3]};

final _bitValue = _buildBitValues();
final _popcount = _buildPopcount();

List<int> _buildBitValues() {
  final table = List<int>.filled(512, 0);
  for (var k = 0; k < 9; k++) {
    table[1 << k] = k + 1;
  }
  return table;
}

List<int> _buildPopcount() {
  final table = List<int>.filled(512, 0);
  for (var i = 1; i < 512; i++) {
    table[i] = table[i >> 1] + (i & 1);
  }
  return table;
}

class SudokuLayout {
  SudokuLayout._({
    required this.n,
    required this.cells,
    required this.all,
    required this.boxRows,
    required this.boxCols,
    required this.boxOf,
    required this.units,
    required this.peers,
  });

  final int n;
  final int cells;
  final int all;
  final int boxRows;
  final int boxCols;
  final List<int> boxOf;
  final List<List<int>> units;
  final List<List<int>> peers;
}

final _layouts = <int, SudokuLayout>{};

SudokuLayout sudokuLayout(int n) {
  final cached = _layouts[n];
  if (cached != null) return cached;

  final shape = _boxShapes[n]!;
  final boxRows = shape[0];
  final boxCols = shape[1];
  final cells = n * n;
  final boxOf = List<int>.filled(cells, 0);
  final rows = [for (var i = 0; i < n; i++) <int>[]];
  final cols = [for (var i = 0; i < n; i++) <int>[]];
  final boxes = [for (var i = 0; i < n; i++) <int>[]];

  for (var i = 0; i < cells; i++) {
    final row = i ~/ n;
    final col = i % n;
    boxOf[i] = (row ~/ boxRows) * (n ~/ boxCols) + (col ~/ boxCols);
    rows[row].add(i);
    cols[col].add(i);
    boxes[boxOf[i]].add(i);
  }

  final peers = [
    for (var i = 0; i < cells; i++)
      {
        ...rows[i ~/ n],
        ...cols[i % n],
        ...boxes[boxOf[i]],
      }.where((j) => j != i).toList(),
  ];

  final layout = SudokuLayout._(
    n: n,
    cells: cells,
    all: (1 << n) - 1,
    boxRows: boxRows,
    boxCols: boxCols,
    boxOf: boxOf,
    units: [...rows, ...cols, ...boxes],
    peers: peers,
  );
  _layouts[n] = layout;
  return layout;
}

int sudokuCountSolutions(List<int> grid, {int limit = 2}) {
  final layout = sudokuLayout(math.sqrt(grid.length).round());
  final n = layout.n;
  final total = layout.cells;
  final all = layout.all;
  final boxOf = layout.boxOf;
  final cells = List<int>.of(grid);
  final rows = List<int>.filled(n, 0);
  final cols = List<int>.filled(n, 0);
  final boxes = List<int>.filled(n, 0);

  for (var i = 0; i < total; i++) {
    final value = cells[i];
    if (value == 0) continue;
    final bit = 1 << (value - 1);
    final row = i ~/ n;
    final col = i % n;
    final box = boxOf[i];
    if ((rows[row] | cols[col] | boxes[box]) & bit != 0) return 0;
    rows[row] |= bit;
    cols[col] |= bit;
    boxes[box] |= bit;
  }

  var count = 0;

  void search() {
    var best = -1;
    var bestMask = 0;
    var bestCount = n + 1;

    for (var i = 0; i < total; i++) {
      if (cells[i] != 0) continue;
      final row = i ~/ n;
      final col = i % n;
      final free = ~(rows[row] | cols[col] | boxes[boxOf[i]]) & all;
      if (free == 0) return;
      final options = _popcount[free];
      if (options < bestCount) {
        bestCount = options;
        best = i;
        bestMask = free;
        if (options == 1) break;
      }
    }

    if (best < 0) {
      count++;
      return;
    }

    final row = best ~/ n;
    final col = best % n;
    final box = boxOf[best];
    var mask = bestMask;
    while (mask != 0) {
      final bit = mask & -mask;
      mask ^= bit;
      cells[best] = _bitValue[bit];
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

class SudokuPuzzle {
  const SudokuPuzzle({
    required this.size,
    required this.solution,
    required this.givens,
    required this.clues,
    required this.difficulty,
  });

  final int size;
  final List<int> solution;
  final List<int> givens;
  final int clues;
  final String difficulty;
}

List<int> _fullGrid(Rng rng, int n) {
  final layout = sudokuLayout(n);
  final boxRows = layout.boxRows;
  final boxCols = layout.boxCols;
  List<int> range(int k) => [for (var i = 0; i < k; i++) i];

  final digits = rng.shuffle(range(n).map((i) => i + 1).toList());
  final rows = <int>[];
  for (final band in rng.shuffle(range(n ~/ boxRows))) {
    for (final row in rng.shuffle(range(boxRows))) {
      rows.add(band * boxRows + row);
    }
  }
  final cols = <int>[];
  for (final stack in rng.shuffle(range(n ~/ boxCols))) {
    for (final col in rng.shuffle(range(boxCols))) {
      cols.add(stack * boxCols + col);
    }
  }

  final grid = List<int>.filled(n * n, 0);
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      final source = rows[r];
      final pattern =
          (boxCols * (source % boxRows) + (source ~/ boxRows) + cols[c]) % n;
      grid[r * n + c] = digits[pattern];
    }
  }
  return grid;
}

SudokuPuzzle generateSudoku(String seed, [String difficultyId = 'medium']) {
  final config = sudokuDifficulty(difficultyId);
  final n = config.size;
  final cells = n * n;

  for (var attempt = 0; attempt < 8; attempt++) {
    final rng = Rng('$seed|sudoku|$difficultyId|$attempt');
    final solution = _fullGrid(rng, n);
    final puzzle = List<int>.of(solution);
    var clues = cells;

    for (final index in rng.shuffle([for (var i = 0; i < cells; i++) i])) {
      if (clues <= config.clues) break;
      final backup = puzzle[index];
      puzzle[index] = 0;
      if (sudokuCountSolutions(puzzle, limit: 2) == 1) {
        clues--;
      } else {
        puzzle[index] = backup;
      }
    }

    if (clues <= config.clues + 6) {
      return SudokuPuzzle(
        size: n,
        solution: solution,
        givens: puzzle,
        clues: clues,
        difficulty: difficultyId,
      );
    }
  }

  throw StateError('sudoku: could not generate a puzzle');
}
