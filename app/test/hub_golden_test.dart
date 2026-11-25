import 'package:daily_games/src/dates.dart';
import 'package:daily_games/src/screens/hub_screen.dart';
import 'package:daily_games/src/store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/golden.dart';

final _now = DateTime(2026, 11, 23);

AppStore _seededStore() {
  final store = AppStore(clock: () => _now);
  store.saveResult(
    game: 'zip',
    key: dateKey(_now),
    mode: 'daily',
    difficulty: 'medium',
    ms: 96_000,
  );
  store.saveResult(
    game: 'tango',
    key: previousDateKey(_now),
    mode: 'daily',
    difficulty: 'medium',
    ms: 131_000,
  );
  store.saveResult(
    game: 'tango',
    key: dateKey(_now),
    mode: 'daily',
    difficulty: 'medium',
    ms: 121_000,
  );
  store.saveResult(
    game: 'sudoku',
    key: dateKey(DateTime(2026, 11, 21)),
    mode: 'daily',
    difficulty: 'mini',
    ms: 208_000,
  );
  return store;
}

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('hub with three games solved', (tester) async {
    await pumpScreen(
      tester,
      HubScreen(
        store: _seededStore(),
        now: _now,
        reminderLabel: 'Every day at 9:00 AM',
        reminderEnabled: true,
        onReminderTap: () {},
        onOpenGame: (_, {required bool practice}) {},
      ),
    );
    await expectGolden(tester, 'hub');
  });

  testWidgets('hub at full height shows the week strip', (tester) async {
    await pumpScreen(
      tester,
      HubScreen(
        store: _seededStore(),
        now: _now,
        reminderLabel: 'Every day at 9:00 AM',
        reminderEnabled: true,
        onReminderTap: () {},
        onOpenGame: (_, {required bool practice}) {},
      ),
      size: const Size(390, 1200),
    );
    await expectGolden(tester, 'hub-full');
  });

  testWidgets('hub with nothing solved', (tester) async {
    await pumpScreen(
      tester,
      HubScreen(
        store: AppStore(clock: () => _now),
        now: _now,
        reminderLabel: 'Off — get a nudge when the new puzzles land',
        reminderEnabled: false,
        onReminderTap: () {},
        onOpenGame: (_, {required bool practice}) {},
      ),
    );
    await expectGolden(tester, 'hub-empty');
  });
}
