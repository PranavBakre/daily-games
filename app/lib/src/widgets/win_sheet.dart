import 'package:material_ui/material_ui.dart';

import '../catalog.dart';
import '../dates.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/pressable.dart';

Future<void> showWinSheet(
  BuildContext context, {
  required AppStore store,
  required GameInfo game,
  required String mode,
  required String difficulty,
  required int ms,
  required int hints,
  required VoidCallback onPracticeAgain,
  required VoidCallback onBackToGames,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Palette.ink.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
        opacity: animation,
        child: _WinSheet(
          store: store,
          game: game,
          mode: mode,
          difficulty: difficulty,
          ms: ms,
          hints: hints,
          onPracticeAgain: onPracticeAgain,
          onBackToGames: onBackToGames,
        ),
      ),
    ),
  );
}

class _WinSheet extends StatelessWidget {
  const _WinSheet({
    required this.store,
    required this.game,
    required this.mode,
    required this.difficulty,
    required this.ms,
    required this.hints,
    required this.onPracticeAgain,
    required this.onBackToGames,
  });

  final AppStore store;
  final GameInfo game;
  final String mode;
  final String difficulty;
  final int ms;
  final int hints;
  final VoidCallback onPracticeAgain;
  final VoidCallback onBackToGames;

  @override
  Widget build(BuildContext context) {
    final accent = game.accent;
    final best = store.best(game.id, difficulty);
    final hintLabel = hints == 0 ? '' : ' · $hints hint${hints == 1 ? '' : 's'}';
    final kicker =
        '${game.name} · ${mode == 'daily' ? 'No. ${puzzleNumber()}' : 'Practice'} · ${game.labelFor(difficulty)}$hintLabel';

    return Material(
      color: accent.block,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.x4, Space.x5, Space.x4, Space.x5),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      Text(
                        kicker,
                        style: AppType.sans(14, weight: 600, height: 1.3),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Space.x3),
                      Text('Solved.', style: AppType.serif(40, height: 1.05)),
                      const SizedBox(height: Space.x2),
                      Text(
                        formatTime(ms),
                        style: AppType.serif(64, height: 1),
                      ),
                      const SizedBox(height: Space.x2),
                      SizedBox(
                        height: 20,
                        child: Text(
                          best != null && best == ms
                              ? 'New personal best'
                              : best != null
                                  ? 'Your best: ${formatTime(best)}'
                                  : '',
                          style: AppType.sans(14, weight: 600),
                        ),
                      ),
                      const SizedBox(height: Space.x3),
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Palette.ink, width: 1),
                            bottom: BorderSide(color: Palette.ink, width: 1),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: Space.x3),
                        child: Row(
                          children: [
                            _Stat(
                              value: '${store.solvedCount(game.id)}',
                              label: 'Played',
                            ),
                            Container(width: 1, height: 36, color: Palette.ink),
                            _Stat(
                              value: '${store.liveStreak(game.id)}',
                              label: 'Day streak',
                            ),
                            Container(width: 1, height: 36, color: Palette.ink),
                            _Stat(
                              value: best == null ? '—' : formatTime(best),
                              label: 'Best',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.x4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final day in lastSevenDays())
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    weekdayLetter(day.date),
                                    style: AppType.sans(12, weight: 600),
                                  ),
                                  const SizedBox(height: Space.x2),
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: store.result(game.id, day.key) != null
                                          ? Palette.ink
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: Palette.ink,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: Space.x5),
                      SizedBox(
                        width: double.infinity,
                        child: PillButton(
                          label: mode == 'practice' ? 'New puzzle' : 'Back to games',
                          primary: true,
                          onPressed: mode == 'practice'
                              ? onPracticeAgain
                              : onBackToGames,
                        ),
                      ),
                      const SizedBox(height: Space.x2),
                      SizedBox(
                        width: double.infinity,
                        child: PillButton(
                          label: mode == 'practice'
                              ? 'Back to games'
                              : 'Practice another',
                          onPressed: mode == 'practice'
                              ? onBackToGames
                              : onPracticeAgain,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppType.serif(28, height: 1.1)),
          const SizedBox(height: Space.x0),
          Text(label, style: AppType.sans(12)),
        ],
      ),
    );
  }
}
