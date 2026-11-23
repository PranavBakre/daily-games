import '../rng.dart';

const int mergeBoardSize = 4;

/// Up, left, right, down — the order the web generator enumerates splits in,
/// which the seeded output depends on.
List<int> mergeNeighbours(int index, int size) {
  final row = index ~/ size;
  final col = index % size;
  return [
    if (row > 0) index - size,
    if (col > 0) index - 1,
    if (col < size - 1) index + 1,
    if (row < size - 1) index + size,
  ];
}

class MergePuzzle {
  const MergePuzzle({required this.size, required this.cells});

  final int size;
  final List<int> cells;
}

/// Built backwards from a single 64 tile: every split is the reverse of a legal
/// merge, so the board is always solvable in seven moves.
MergePuzzle generateMerge(String seed) {
  final rng = Rng(seed);
  const size = mergeBoardSize;
  final cells = List<int>.filled(size * size, 0);
  cells[rng.nextInt(cells.length)] = 64;

  for (var count = 1; count < 8; count++) {
    final splits = <List<int>>[];
    for (var from = 0; from < cells.length; from++) {
      if (cells[from] <= 1) continue;
      for (final to in mergeNeighbours(from, size)) {
        if (cells[to] == 0) splits.add([from, to]);
      }
    }
    final move = rng.pick(splits);
    cells[move[0]] ~/= 2;
    cells[move[1]] = cells[move[0]];
  }

  return MergePuzzle(size: size, cells: cells);
}

List<int>? mergeTiles(List<int> cells, int size, int from, int to) {
  if (cells[from] == 0 ||
      cells[from] != cells[to] ||
      !mergeNeighbours(from, size).contains(to)) {
    return null;
  }
  final next = List<int>.from(cells);
  next[to] += next[from];
  next[from] = 0;
  return next;
}

bool mergeIsStuck(List<int> cells, int size) {
  final tiles = cells.where((value) => value != 0).length;
  if (tiles <= 1) return false;
  for (var index = 0; index < cells.length; index++) {
    final value = cells[index];
    if (value == 0) continue;
    for (final neighbour in mergeNeighbours(index, size)) {
      if (cells[neighbour] == value) return false;
    }
  }
  return true;
}

/// First sequence of merges that leaves a single tile, or null when the board
/// is a dead end. Memoised on the board's shape.
List<List<int>>? findMergeSolution(List<int> cells, int size) {
  final deadEnds = <String>{};

  List<List<int>>? search(List<int> board) {
    if (board.where((value) => value != 0).length == 1) return const [];
    final key = board.join(',');
    if (deadEnds.contains(key)) return null;
    for (var from = 0; from < board.length; from++) {
      if (board[from] == 0) continue;
      for (final to in mergeNeighbours(from, size)) {
        final next = mergeTiles(board, size, from, to);
        if (next == null) continue;
        final rest = search(next);
        if (rest != null) return [[from, to], ...rest];
      }
    }
    deadEnds.add(key);
    return null;
  }

  return search(cells);
}
