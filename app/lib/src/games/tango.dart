import '../rng.dart';

const int tangoSize = 6;
const int tangoSun = 1;
const int tangoMoon = 2;

class TangoDifficulty {
  const TangoDifficulty(this.id, this.label, this.givens, this.extraEdges);

  final String id;
  final String label;
  final int givens;
  final int extraEdges;
}

const tangoDifficulties = [
  TangoDifficulty('easy', 'Easy', 6, 3),
  TangoDifficulty('medium', 'Medium', 2, 1),
  TangoDifficulty('hard', 'Hard', 1, 0),
];

TangoDifficulty tangoDifficulty(String id) => tangoDifficulties.firstWhere(
  (difficulty) => difficulty.id == id,
  orElse: () => tangoDifficulties[1],
);

class TangoEdge {
  const TangoEdge(this.a, this.b, this.same);

  final int a;
  final int b;
  final bool same;

  bool connects(int x, int y) => (a == x && b == y) || (a == y && b == x);
}

class TangoPuzzle {
  const TangoPuzzle({
    required this.size,
    required this.givens,
    required this.edges,
    required this.solution,
    required this.difficulty,
  });

  final int size;
  final List<int> givens;
  final List<TangoEdge> edges;
  final List<int> solution;
  final String difficulty;
}

class TangoSearch {
  const TangoSearch(this.solutions, this.aborted);

  final List<List<int>> solutions;
  final bool aborted;
}

int _pairKey(int a, int b) => a < b ? a * 1000 + b : b * 1000 + a;

/// Up, down, left, right — the order the edge constraints are read in.
List<int> tangoNeighbours(int index, int size) {
  final row = index ~/ size;
  final col = index % size;
  return [
    if (row > 0) index - size,
    if (row < size - 1) index + size,
    if (col > 0) index - 1,
    if (col < size - 1) index + 1,
  ];
}

List<TangoEdge> _allEdges(int size) {
  final edges = <TangoEdge>[];
  for (var row = 0; row < size; row++) {
    for (var col = 0; col < size; col++) {
      final index = row * size + col;
      if (col < size - 1) edges.add(TangoEdge(index, index + 1, false));
      if (row < size - 1) edges.add(TangoEdge(index, index + size, false));
    }
  }
  return edges;
}

/// Depth-first fill with balance pruning. [rng] randomises the symbol order,
/// which is how a fresh solution is built; leave it null to enumerate.
TangoSearch tangoSearch(
  TangoPuzzle puzzle, {
  int limit = 2,
  Rng? rng,
  int budget = 400000,
}) {
  final size = puzzle.size;
  final total = size * size;
  final half = size ~/ 2;
  final grid = List<int>.filled(total, 0);
  final rowCount = List<int>.filled(size * 2, 0);
  final colCount = List<int>.filled(size * 2, 0);
  final constraints = <int, bool>{};
  for (final edge in puzzle.edges) {
    constraints[_pairKey(edge.a, edge.b)] = edge.same;
  }

  final solutions = <List<int>>[];
  var nodes = 0;
  var aborted = false;

  bool fits(int index, int value) {
    final row = index ~/ size;
    final col = index % size;
    if (rowCount[row * 2 + value - 1] >= half) return false;
    if (colCount[col * 2 + value - 1] >= half) return false;
    if (col >= 2 && grid[index - 1] == value && grid[index - 2] == value) {
      return false;
    }
    if (row >= 2 && grid[index - size] == value && grid[index - 2 * size] == value) {
      return false;
    }
    for (final neighbour in tangoNeighbours(index, size)) {
      final other = grid[neighbour];
      if (other == 0) continue;
      final same = constraints[_pairKey(index, neighbour)];
      if (same == null) continue;
      if ((other == value) != same) return false;
    }
    return true;
  }

  void walk(int index) {
    if (index == total) {
      solutions.add(List<int>.of(grid));
      return;
    }
    if (++nodes > budget) {
      aborted = true;
      return;
    }
    final given = puzzle.givens[index];
    var order = given != 0 ? [given] : [tangoSun, tangoMoon];
    if (rng != null && given == 0 && rng.chance(0.5)) {
      order = [tangoMoon, tangoSun];
    }

    for (final value in order) {
      if (!fits(index, value)) continue;
      grid[index] = value;
      rowCount[(index ~/ size) * 2 + value - 1]++;
      colCount[(index % size) * 2 + value - 1]++;
      walk(index + 1);
      rowCount[(index ~/ size) * 2 + value - 1]--;
      colCount[(index % size) * 2 + value - 1]--;
      grid[index] = 0;
      if (aborted || solutions.length >= limit) return;
    }
  }

  walk(0);
  return TangoSearch(solutions, aborted);
}

int tangoCountSolutions(TangoPuzzle puzzle, [int limit = 2]) =>
    tangoSearch(puzzle, limit: limit).solutions.length;

bool tangoIsValidSolution(List<int> values, [int size = tangoSize]) {
  final half = size ~/ 2;
  for (var i = 0; i < size * size; i++) {
    if (values[i] != tangoSun && values[i] != tangoMoon) return false;
    final row = i ~/ size;
    final col = i % size;
    if (col >= 2 && values[i] == values[i - 1] && values[i] == values[i - 2]) {
      return false;
    }
    if (row >= 2 && values[i] == values[i - size] && values[i] == values[i - 2 * size]) {
      return false;
    }
  }
  for (var line = 0; line < size; line++) {
    var rowSuns = 0;
    var colSuns = 0;
    for (var i = 0; i < size; i++) {
      if (values[line * size + i] == tangoSun) rowSuns++;
      if (values[i * size + line] == tangoSun) colSuns++;
    }
    if (rowSuns != half || colSuns != half) return false;
  }
  return true;
}

/// Cells that break a rule, for the board's red wash.
Set<int> tangoConflicts(List<int> values, List<TangoEdge> edges, int size) {
  final bad = <int>{};
  final lines = <List<int>>[];
  for (var line = 0; line < size; line++) {
    final row = <int>[];
    final col = <int>[];
    for (var i = 0; i < size; i++) {
      row.add(line * size + i);
      col.add(i * size + line);
    }
    lines
      ..add(row)
      ..add(col);
  }

  for (final line in lines) {
    var suns = 0;
    var moons = 0;
    for (final index in line) {
      if (values[index] == tangoSun) suns++;
      if (values[index] == tangoMoon) moons++;
    }
    if (suns > size / 2) {
      for (final index in line) {
        if (values[index] == tangoSun) bad.add(index);
      }
    }
    if (moons > size / 2) {
      for (final index in line) {
        if (values[index] == tangoMoon) bad.add(index);
      }
    }
    for (var i = 0; i < line.length - 2; i++) {
      final value = values[line[i]];
      if (value != 0 &&
          value == values[line[i + 1]] &&
          value == values[line[i + 2]]) {
        bad
          ..add(line[i])
          ..add(line[i + 1])
          ..add(line[i + 2]);
      }
    }
  }

  for (final edge in edges) {
    final a = values[edge.a];
    final b = values[edge.b];
    if (a == 0 || b == 0) continue;
    if ((a == b) != edge.same) {
      bad
        ..add(edge.a)
        ..add(edge.b);
    }
  }

  return bad;
}

TangoPuzzle generateTango(String seed, [String difficultyId = 'medium']) {
  final config = tangoDifficulty(difficultyId);
  const size = tangoSize;

  for (var attempt = 0; attempt < 40; attempt++) {
    final rng = Rng('$seed|tango|$difficultyId|$attempt');

    final blank = TangoPuzzle(
      size: size,
      givens: List<int>.filled(size * size, 0),
      edges: const [],
      solution: const [],
      difficulty: difficultyId,
    );
    final found = tangoSearch(blank, limit: 1, rng: rng, budget: 200000);
    if (found.solutions.isEmpty) continue;
    final solution = found.solutions.first;

    final givens = List<int>.filled(size * size, 0);
    final cells = rng.shuffle([for (var i = 0; i < size * size; i++) i]);
    for (final index in cells.take(config.givens)) {
      givens[index] = solution[index];
    }

    final puzzle = TangoPuzzle(
      size: size,
      givens: List<int>.of(givens),
      edges: <TangoEdge>[],
      solution: solution,
      difficulty: difficultyId,
    );

    var unique = tangoCountSolutions(puzzle) == 1;
    if (!unique) {
      final candidates = rng.shuffle(_allEdges(size));
      for (final edge in candidates) {
        puzzle.edges.add(
          TangoEdge(edge.a, edge.b, solution[edge.a] == solution[edge.b]),
        );
        if (tangoCountSolutions(puzzle) == 1) break;
      }
      unique = tangoCountSolutions(puzzle) == 1;
    }
    if (!unique) continue;

    // Drop every badge that is not needed, so the final board stays readable.
    final unused = List<TangoEdge>.of(puzzle.edges);
    rng.shuffle(unused);
    for (final edge in unused) {
      final at = puzzle.edges.indexOf(edge);
      if (at < 0) continue;
      puzzle.edges.removeAt(at);
      if (tangoCountSolutions(puzzle) != 1) puzzle.edges.insert(at, edge);
    }

    final extras = rng.shuffle(
      _allEdges(size)
          .where(
            (edge) => !puzzle.edges
                .any((existing) => existing.a == edge.a && existing.b == edge.b),
          )
          .toList(),
    );
    for (final edge in extras.take(config.extraEdges)) {
      puzzle.edges.add(
        TangoEdge(edge.a, edge.b, solution[edge.a] == solution[edge.b]),
      );
    }

    return puzzle;
  }

  throw StateError('tango: could not generate a unique puzzle');
}
