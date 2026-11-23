import 'package:material_ui/material_ui.dart';

import 'notifications.dart';
import 'theme.dart';
import 'screens/game_screen.dart';
import 'screens/hub_screen.dart';
import 'store.dart';
import 'widgets/reminder_sheet.dart';

class DailyGamesApp extends StatelessWidget {
  const DailyGamesApp({required this.store, required this.reminders, super.key});

  final AppStore store;
  final Reminders reminders;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Games',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: _HubHost(store: store, reminders: reminders),
    );
  }
}

class _HubHost extends StatelessWidget {
  const _HubHost({required this.store, required this.reminders});

  final AppStore store;
  final Reminders reminders;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final enabled = store.pref('reminderEnabled', false);
        final hour = store.pref('reminderHour', 9);
        final minute = store.pref('reminderMinute', 0);
        final time = MaterialLocalizations.of(context).formatTimeOfDay(
          TimeOfDay(hour: hour, minute: minute),
        );
        return HubScreen(
          store: store,
          reminderLabel: enabled
              ? 'Every day at $time'
              : 'Off — get a nudge when the new puzzles land',
          onReminderTap: () =>
              showReminderSheet(context, store: store, reminders: reminders),
          onOpenGame: (game) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GameScreen(
                game: game,
                store: store,
                mode: 'daily',
                difficulty: game.defaultDifficulty,
              ),
            ),
          ),
        );
      },
    );
  }
}
