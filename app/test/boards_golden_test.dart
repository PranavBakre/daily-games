import 'package:daily_games/src/games/merge_board.dart';
import 'package:daily_games/src/games/sudoku_board.dart';
import 'package:daily_games/src/games/tango_board.dart';
import 'package:daily_games/src/games/zip_board.dart';
import 'package:daily_games/src/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/golden.dart';

Widget _frame(Widget board) => Scaffold(
  backgroundColor: Palette.paper,
  body: SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [board],
      ),
    ),
  ),
);

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('zip board', (tester) async {
    await pumpScreen(
      tester,
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
    await expectGolden(tester, 'board-zip');
  });

  testWidgets('tango board', (tester) async {
    await pumpScreen(
      tester,
      _frame(
        TangoBoard(
          seed: 'tango:daily:2026-11-23',
          difficulty: 'medium',
          saved: null,
          onChanged: (_) {},
          onSolved: (_) {},
        ),
      ),
    );
    await expectGolden(tester, 'board-tango');
  });

  testWidgets('sudoku board', (tester) async {
    await pumpScreen(
      tester,
      _frame(
        SudokuBoard(
          seed: 'sudoku:daily:2026-11-23',
          difficulty: 'mini',
          saved: null,
          onChanged: (_) {},
          onSolved: (_) {},
        ),
      ),
    );
    await expectGolden(tester, 'board-sudoku');
  });

  testWidgets('number merge board', (tester) async {
    await pumpScreen(
      tester,
      _frame(
        MergeBoard(
          seed: 'merge:daily:2026-11-23',
          saved: null,
          onChanged: (_) {},
          onSolved: (_) {},
        ),
      ),
    );
    await expectGolden(tester, 'board-merge');
  });
}
