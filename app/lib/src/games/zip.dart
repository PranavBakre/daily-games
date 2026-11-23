import '../rng.dart';

class ZipDifficulty {
  const ZipDifficulty(
    this.id,
    this.label,
    this.width,
    this.height,
    this.numbers,
    this.minNumbers,
    this.maxWalls,
    this.wallChance,
  );

  final String id;
  final String label;
  final int width;
  final int height;
  final int numbers;
  final int minNumbers;
  final int maxWalls;
  final double wallChance;
}

const zipDifficulties = [
  ZipDifficulty('easy', 'Easy', 6, 6, 12, 10, 2, 0.25),
  ZipDifficulty('medium', 'Medium', 6, 6, 10, 7, 4, 0.35),
  ZipDifficulty('hard', 'Hard', 7, 7, 10, 7, 6, 0.40),
];

ZipDifficulty zipDifficulty(String id) => zipDifficulties.firstWhere(
  (difficulty) => difficulty.id == id,
  orElse: () => zipDifficulties[1],
);

class ZipPuzzle {
  const ZipPuzzle({
    required this.width,
    required this.height,
    required this.numbers,
    required this.walls,
    required this.solution,
    required this.difficulty,
  });

  final int width;
  final int height;
  final List<int> numbers;
  final List<List<int>> walls;
  final List<int> solution;
  final String difficulty;

  int get size => width * height;
}

class ZipSearch {
  const ZipSearch(this.count, this.aborted, this.solutions);

  final int count;
  final bool aborted;
  final List<List<int>> solutions;
}

/// Up, down, left, right — the order the DFS visits neighbours in, which the
/// seeded puzzles depend on.
final _neighbourCache = <String, List<List<int>>>{};

List<List<int>> zipNeighbours(int width, int height) {
  final key = '${width}x$height';
  final cached = _neighbourCache[key];
  if (cached != null) return cached;
  final table = <List<int>>[];
  for (var r = 0; r < height; r++) {
    for (var c = 0; c < width; c++) {
      table.add([
        if (r > 0) (r - 1) * width + c,
        if (r < height - 1) (r + 1) * width + c,
        if (c > 0) r * width + c - 1,
        if (c < width - 1) r * width + c + 1,
      ]);
    }
  }
  _neighbourCache[key] = table;
  return table;
}

int _edgeKey(int a, int b) => a < b ? a * 1000 + b : b * 1000 + a;

List<int>? _randomPath(int width, int height, Rng rng) {
  final size = width * height;
  final table = zipNeighbours(width, height);
  final visited = List<bool>.filled(size, false);
  final path = List<int>.filled(size, 0);
  var steps = 0;

  int onwardDegree(int cell) {
    var count = 0;
    for (final next in table[cell]) {
      if (!visited[next]) count++;
    }
    return count;
  }

  bool walk(int cell, int depth) {
    visited[cell] = true;
    path[depth] = cell;
    if (depth == size - 1) return true;
    if (++steps > 250000) return false;

    final options = [
      for (final next in table[cell])
        if (!visited[next]) next,
    ];
    // One draw per option, before sorting: the most constrained neighbour goes
    // first, with the draw breaking ties.
    final ranked = [
      for (var i = 0; i < options.length; i++)
        (next: options[i], degree: onwardDegree(options[i]), tie: rng.next(), index: i),
    ];
    ranked.sort((a, b) {
      final byDegree = a.degree.compareTo(b.degree);
      if (byDegree != 0) return byDegree;
      final byTie = a.tie.compareTo(b.tie);
      if (byTie != 0) return byTie;
      return a.index.compareTo(b.index);
    });

    for (final entry in ranked) {
      if (walk(entry.next, depth + 1)) return true;
    }
    visited[cell] = false;
    return false;
  }

  for (var attempt = 0; attempt < 8; attempt++) {
    for (var i = 0; i < size; i++) {
      visited[i] = false;
    }
    steps = 0;
    if (walk(rng.nextInt(size), 0)) return List<int>.of(path);
  }
  return null;
}

List<(int cell, int label)> _checkpointOrder(List<int> numbers) {
  final list = <(int, int)>[];
  for (var cell = 0; cell < numbers.length; cell++) {
    if (numbers[cell] != 0) list.add((cell, numbers[cell]));
  }
  list.sort((a, b) => a.$2.compareTo(b.$2));
  return list;
}

/// Counts routes that start on 1, visit the numbers in order, cover every cell
/// and end on the highest number. [budget] stops a hard check from hanging.
ZipSearch zipCountSolutions(
  ZipPuzzle puzzle, {
  int limit = 2,
  int budget = 200000,
}) {
  final width = puzzle.width;
  final height = puzzle.height;
  final size = width * height;
  final table = zipNeighbours(width, height);
  final wallSet = {for (final wall in puzzle.walls) _edgeKey(wall[0], wall[1])};
  final open = [
    for (var cell = 0; cell < size; cell++)
      [
        for (final next in table[cell])
          if (!wallSet.contains(_edgeKey(cell, next))) next,
      ],
  ];
  final checkpoints = _checkpointOrder(puzzle.numbers);
  final order = List<int>.filled(size, -1);
  for (var i = 0; i < checkpoints.length; i++) {
    order[checkpoints[i].$1] = i;
  }
  final start = checkpoints.isEmpty ? -1 : checkpoints.first.$1;
  final finish = checkpoints.isEmpty ? -1 : checkpoints.last.$1;
  final visited = List<bool>.filled(size, false);
  final seen = List<bool>.filled(size, false);
  final queue = List<int>.filled(size, 0);
  final trail = List<int>.filled(size, 0);
  final found = <List<int>>[];
  var count = 0;
  var nodes = 0;
  var aborted = false;

  bool stranded(int cell, int head) {
    var free = 0;
    for (final next in open[cell]) {
      if (!visited[next] || next == head) free++;
    }
    return free < (cell == finish ? 1 : 2);
  }

  bool connected(int head, int remaining) {
    for (var i = 0; i < size; i++) {
      seen[i] = false;
    }
    var read = 0;
    var write = 0;
    queue[write++] = head;
    seen[head] = true;
    var reached = 0;
    while (read < write) {
      final cell = queue[read++];
      for (final next in open[cell]) {
        if (visited[next] || seen[next]) continue;
        seen[next] = true;
        reached++;
        queue[write++] = next;
      }
    }
    return reached == remaining;
  }

  void walk(int cell, int depth, int nextCheckpoint) {
    trail[depth] = cell;
    if (depth == size - 1) {
      if (cell != finish) return;
      count++;
      if (found.length < limit) found.add(List<int>.of(trail));
      return;
    }
    if (cell == finish) return;
    if (++nodes > budget) {
      aborted = true;
      return;
    }
    if (depth > 0) {
      for (final other in open[trail[depth - 1]]) {
        if (!visited[other] && stranded(other, cell)) return;
      }
    }
    if (!connected(cell, size - 1 - depth)) return;

    for (final next in open[cell]) {
      if (visited[next]) continue;
      final rank = order[next];
      if (rank != -1 && rank != nextCheckpoint) continue;
      visited[next] = true;
      walk(next, depth + 1, rank == -1 ? nextCheckpoint : nextCheckpoint + 1);
      visited[next] = false;
      if (count >= limit || aborted) return;
    }
  }

  if (start >= 0) {
    visited[start] = true;
    walk(start, 0, 1);
  }
  return ZipSearch(count, aborted, found);
}

List<int>? zipSolve(ZipPuzzle puzzle) {
  final result = zipCountSolutions(puzzle, limit: 1, budget: 2000000);
  return result.solutions.isEmpty ? null : result.solutions.first;
}

List<int> _labelNumbers(List<int> path, Set<int> indexes) {
  final numbers = List<int>.filled(path.length, 0);
  final sorted = indexes.toList()..sort();
  for (var rank = 0; rank < sorted.length; rank++) {
    numbers[path[sorted[rank]]] = rank + 1;
  }
  return numbers;
}

/// `Math.round` rounds half toward +∞; Dart's `round` rounds away from zero.
int _jsRound(num value) => (value + 0.5).floor();

ZipPuzzle generateZip(String seed, [String difficultyId = 'medium']) {
  final config = zipDifficulty(difficultyId);
  final width = config.width;
  final height = config.height;
  final size = width * height;
  const budget = 60000;

  for (var attempt = 0; attempt < 24; attempt++) {
    final rng = Rng('$seed|zip|$difficultyId|$attempt');
    final path = _randomPath(width, height, rng);
    if (path == null) continue;

    final pathEdges = <int>{};
    for (var i = 1; i < size; i++) {
      pathEdges.add(_edgeKey(path[i - 1], path[i]));
    }

    // Start with evenly spread checkpoints, always including both ends.
    final indexes = <int>{0, size - 1};
    final gap = (size - 1) / (config.numbers - 1);
    for (var k = 1; k < config.numbers - 1; k++) {
      final jitter = _jsRound((rng.next() - 0.5) * gap * 0.6);
      final target = _jsRound(k * gap) + jitter;
      indexes.add(target < 1 ? 1 : (target > size - 2 ? size - 2 : target));
    }
    var walls = <List<int>>[];

    ZipPuzzle build() => ZipPuzzle(
      width: width,
      height: height,
      numbers: _labelNumbers(path, indexes),
      walls: walls,
      solution: path,
      difficulty: difficultyId,
    );

    // Pin down every alternative route, preferring a new number and only
    // occasionally a wall, the way the published puzzles read.
    var unique = false;
    for (var step = 0; step < size; step++) {
      final check = zipCountSolutions(build(), limit: 2, budget: budget);
      if (check.count == 1 && !check.aborted) {
        unique = true;
        break;
      }
      List<int>? alt;
      for (final route in check.solutions) {
        for (var i = 0; i < route.length; i++) {
          if (route[i] != path[i]) {
            alt = route;
            break;
          }
        }
        if (alt != null) break;
      }

      if (alt == null) {
        final sorted = indexes.toList()..sort();
        var widest = 0;
        for (var i = 1; i < sorted.length; i++) {
          if (sorted[i] - sorted[i - 1] >
              sorted[widest + 1] - sorted[widest]) {
            widest = i - 1;
          }
        }
        indexes.add(((sorted[widest] + sorted[widest + 1]) / 2).floor());
        continue;
      }

      var diverge = -1;
      for (var i = 0; i < alt.length; i++) {
        if (alt[i] != path[i]) {
          diverge = i;
          break;
        }
      }
      var wallEdge = -1;
      if (diverge > 0) {
        for (var i = 1; diverge - 1 + i < alt.length; i++) {
          final previous = alt[diverge - 1 + i - 1];
          final current = alt[diverge - 1 + i];
          if (!pathEdges.contains(_edgeKey(previous, current))) {
            wallEdge = i;
            break;
          }
        }
      }

      if (walls.length < config.maxWalls &&
          wallEdge > 0 &&
          rng.next() < config.wallChance) {
        final a = alt[diverge - 1 + wallEdge - 1];
        final b = alt[diverge - 1 + wallEdge];
        walls = [
          ...walls,
          [a < b ? a : b, a < b ? b : a],
        ];
      } else {
        indexes.add(diverge);
      }
    }
    if (!unique) continue;

    // Drop clues the solution does not need, down to the difficulty's floor.
    for (final wall in rng.shuffle(List<List<int>>.of(walls))) {
      final without = [
        for (final entry in walls)
          if (!identical(entry, wall)) entry,
      ];
      final check = zipCountSolutions(
        ZipPuzzle(
          width: width,
          height: height,
          numbers: _labelNumbers(path, indexes),
          walls: without,
          solution: path,
          difficulty: difficultyId,
        ),
        limit: 2,
        budget: budget,
      );
      if (check.count == 1 && !check.aborted) walls = without;
    }

    final removable = [
      for (final index in indexes)
        if (index != 0 && index != size - 1) index,
    ];
    for (final index in rng.shuffle(removable)) {
      if (indexes.length <= config.minNumbers) break;
      indexes.remove(index);
      final check = zipCountSolutions(build(), limit: 2, budget: budget);
      if (check.count != 1 || check.aborted) indexes.add(index);
    }

    final puzzle = build();
    final verify = zipCountSolutions(puzzle, limit: 2, budget: 400000);
    if (verify.count == 1 && !verify.aborted) return puzzle;
  }

  throw StateError('zip: could not generate a unique puzzle');
}
