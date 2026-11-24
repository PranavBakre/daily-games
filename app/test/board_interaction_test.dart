import 'package:daily_games/src/games/merge.dart';
import 'package:daily_games/src/games/merge_board.dart';
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
    testWidgets('a first touch that is not number 1 is a no-op', (tester) async {
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
