import 'package:daily_games/src/catalog.dart';
import 'package:daily_games/src/screens/hub_screen.dart';
import 'package:daily_games/src/store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/golden.dart';

void main() {
  setUpAll(loadGoldenFonts);

  Future<void> pumpHub(
    WidgetTester tester,
    void Function(GameInfo game, {required bool practice}) onOpen,
  ) {
    return pumpScreen(
      tester,
      HubScreen(
        store: AppStore(clock: () => DateTime(2026, 11, 24)),
        now: DateTime(2026, 11, 24),
        reminderLabel: 'Off',
        reminderEnabled: false,
        onReminderTap: () {},
        onOpenGame: onOpen,
      ),
    );
  }

  testWidgets('the card opens the daily', (tester) async {
    GameInfo? opened;
    var practice = true;
    await pumpHub(tester, (game, {required bool practice}) {
      opened = game;
      practice = practice;
    });

    await tester.tap(find.text('Zip').first);
    await tester.pump();

    expect(opened?.id, 'zip');
    expect(practice, isFalse);
  });

  testWidgets('the practice row opens practice', (tester) async {
    GameInfo? opened;
    var practice = false;
    await pumpHub(tester, (game, {required bool practice}) {
      opened = game;
      practice = practice;
    });

    await tester.tap(find.text('Practice').first);
    await tester.pump();

    expect(opened?.id, 'zip');
    expect(practice, isTrue);
  });
}
