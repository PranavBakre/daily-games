import 'dart:math' as math;

import 'package:daily_games/src/games/merge.dart';
import 'package:daily_games/src/games/merge_board.dart';
import 'package:daily_games/src/games/tango.dart';
import 'package:daily_games/src/games/tango_board.dart';
import 'package:daily_games/src/games/zip.dart';
import 'package:daily_games/src/games/zip_board.dart';
import 'package:daily_games/src/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _frame(Widget board) => MaterialApp(
  theme: buildTheme(fontFamily: 'Roboto'),
  home: Scaffold(
    backgroundColor: Palette.paper,
    body: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(Space.x4), child: board),
    ),
  ),
);

void main() {
  group('Zip', () {
    testWidgets('a first touch that is not number 1 is a no-op', (
      tester,
    ) async {
      await tester.pumpWidget(
        _frame(
          ZipBoard(
            seed: 'zip:daily:2026-11-23',
            difficulty: 'medium',
            saved: null,
            onChanged: (_) {},
            onSolved: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final badge = find.text('5').first;
      expect(badge, findsOneWidget);
      await tester.tap(badge);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('0 of 36 cells'), findsOneWidget);
    });

    testWidgets('the line starts on 1', (tester) async {
      await tester.pumpWidget(
        _frame(
          ZipBoard(
            seed: 'zip:daily:2026-11-23',
            difficulty: 'medium',
            saved: null,
            onChanged: (_) {},
            onSolved: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('1').first);
      await tester.pumpAndSettle();

      expect(find.text('1 of 36 cells'), findsOneWidget);
    });
  });

  group('Zip', () {
    testWidgets('a line stuck on the highest number explains itself', (
      tester,
    ) async {
      // The route a player actually drew on 2026-11-24: it reaches cell 3
      // (label 7) having skipped cells 9 and 20, and cannot grow again.
      const stuck = [
        35,
        29,
        23,
        17,
        11,
        5,
        4,
        10,
        16,
        22,
        28,
        34,
        33,
        32,
        31,
        30,
        24,
        18,
        12,
        6,
        0,
        1,
        7,
        13,
        19,
        25,
        26,
        27,
        21,
        15,
        14,
        8,
        2,
        3,
      ];
      await tester.pumpWidget(
        _frame(
          ZipBoard(
            seed: 'zip:daily:2026-11-24',
            difficulty: 'medium',
            saved: {'path': stuck, 'hints': 0},
            onChanged: (_) {},
            onSolved: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('reached 7 with 2 cells still empty'),
        findsOneWidget,
      );
      expect(find.text('34 of 36 cells'), findsNothing);
    });

    testWidgets('a complete line is not reported as stuck', (tester) async {
      final solution = generateZip('zip:daily:2026-11-24', 'medium').solution;
      await tester.pumpWidget(
        _frame(
          ZipBoard(
            seed: 'zip:daily:2026-11-24',
            difficulty: 'medium',
            saved: {'path': solution, 'hints': 0},
            onChanged: (_) {},
            onSolved: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('still empty'), findsNothing);
    });
  });

  group('Tango', _tangoBadgeAlignment);

  group('Number Merge', () {
    testWidgets('tapping two equal neighbours merges them', (tester) async {
      const seed = 'merge:daily:2026-11-23';
      final puzzle = generateMerge(seed);
      final pair = _firstLegalMerge(puzzle.cells);
      expect(pair, isNotNull, reason: 'generated board must have a merge');

      await tester.pumpWidget(
        _frame(
          MergeBoard(
            seed: seed,
            saved: null,
            onChanged: (_) {},
            onSolved: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('merge-tile-${pair!.$1}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('merge-tile-${pair.$2}')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('7 tiles remaining'), findsOneWidget);
    });
  });
}

(int, int)? _firstLegalMerge(List<int> cells) {
  for (var from = 0; from < cells.length; from++) {
    if (cells[from] == 0) continue;
    for (final to in mergeNeighbours(from, mergeBoardSize)) {
      if (cells[to] == cells[from]) return (from, to);
    }
  }
  return null;
}

void _tangoBadgeAlignment() {
  testWidgets('tango badges sit on the border their cells share', (
    tester,
  ) async {
    const seed = 'tango:daily:2026-11-23';
    final puzzle = generateTango(seed, 'medium');
    expect(
      puzzle.edges.any((e) => e.b == e.a + 1),
      isTrue,
      reason: 'need a horizontal edge to cover',
    );
    expect(
      puzzle.edges.any((e) => e.b == e.a + tangoSize),
      isTrue,
      reason: 'need a vertical edge to cover',
    );

    await tester.pumpWidget(
      _frame(
        TangoBoard(
          seed: seed,
          difficulty: 'medium',
          saved: null,
          onChanged: (_) {},
          onSolved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final board = tester.getRect(find.byKey(const ValueKey('tango-board')));
    final inner = board.deflate(2);
    final cellWidth = inner.width / tangoSize;
    final cellHeight = inner.height / tangoSize;

    for (final edge in puzzle.edges) {
      final badge = find.byKey(ValueKey('tango-badge-${edge.a}-${edge.b}'));
      expect(badge, findsOneWidget);
      final center = tester.getCenter(badge);
      final horizontal = edge.b == edge.a + 1;
      final row = edge.a ~/ tangoSize;
      final col = edge.a % tangoSize;
      expect(
        tester.getSize(badge).width,
        closeTo(math.min(22.0, cellWidth * 0.36), 0.01),
        reason: 'edge ${edge.a}-${edge.b} is the wrong size',
      );
      final expectedX =
          inner.left + (horizontal ? col + 1 : col + 0.5) * cellWidth;
      final expectedY =
          inner.top + (horizontal ? row + 0.5 : row + 1) * cellHeight;
      expect(
        (center.dx - expectedX).abs(),
        lessThan(0.5),
        reason: 'edge ${edge.a}-${edge.b} is off horizontally',
      );
      expect(
        (center.dy - expectedY).abs(),
        lessThan(0.5),
        reason: 'edge ${edge.a}-${edge.b} is off vertically',
      );
    }
  });
}
