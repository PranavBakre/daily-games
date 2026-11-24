import 'package:material_ui/material_ui.dart';

import '../catalog.dart';
import '../dates.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/game_icon.dart';
import '../widgets/pressable.dart';

class HubScreen extends StatelessWidget {
  const HubScreen({
    required this.store,
    required this.onOpenGame,
    required this.reminderLabel,
    required this.onReminderTap,
    this.now,
    super.key,
  });

  final AppStore store;
  final void Function(GameInfo game) onOpenGame;
  final String reminderLabel;
  final VoidCallback onReminderTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final today = now ?? DateTime.now();
    final todayKey = dateKey(today);
    final done = [
      for (final game in games)
        if (store.result(game.id, todayKey) != null) game,
    ].length;
    final allSolved = done == games.length;

    return Scaffold(
      backgroundColor: Palette.paper,
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            Space.x4,
            padding.top + Space.x5,
            Space.x4,
            padding.bottom + Space.x6,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Masthead(date: today, number: puzzleNumber(today)),
                  const SizedBox(height: Space.x5),
                  _SectionTitle(
                    allSolved
                        ? 'All solved. Back tomorrow.'
                        : "Today's puzzles",
                  ),
                  const SizedBox(height: Space.x4),
                  for (final game in games) ...[
                    _GameCard(
                      game: game,
                      store: store,
                      todayKey: todayKey,
                      number: puzzleNumber(today),
                      onTap: () => onOpenGame(game),
                    ),
                    if (game != games.last) const SizedBox(height: Space.x4),
                  ],
                  const SizedBox(height: Space.x5),
                  const _SectionTitle('This week'),
                  const SizedBox(height: Space.x3),
                  _WeekStrip(store: store, days: lastSevenDays(today)),
                  const SizedBox(height: Space.x5),
                  _ReminderRow(label: reminderLabel, onTap: onReminderTap),
                  const SizedBox(height: Space.x4),
                  _Footer(done: done, total: games.length),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead({required this.date, required this.number});

  final DateTime date;
  final int number;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Daily Games',
          style: AppType.serif(40, height: 1.1, letterSpacing: -0.4),
          textAlign: TextAlign.center,
        ),
        Container(
          margin: const EdgeInsets.only(top: Space.x2),
          padding: const EdgeInsets.only(top: Space.x2),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Palette.ink, width: 1)),
          ),
          child: Text(
            '${longDate(date)} · No. $number',
            style: AppType.sans(14, color: Palette.ink),
            textAlign: TextAlign.center,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: Space.x3),
          height: 2,
          color: Palette.ink,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: Space.x2),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Palette.ink, width: 1)),
      ),
      child: Text(text, style: AppType.serif(20, height: 1.2)),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.game,
    required this.store,
    required this.todayKey,
    required this.number,
    required this.onTap,
  });

  final GameInfo game;
  final AppStore store;
  final String todayKey;
  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final result = store.result(game.id, todayKey);
    final streak = store.liveStreak(game.id);
    final status = <String>[
      'No. $number · ${game.labelFor(game.defaultDifficulty)}',
      if (result != null) '· ${formatTime(result.ms)}',
      if (streak > 1) '· $streak-day streak',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Palette.card,
        border: Border.all(color: Palette.line, width: 1),
        borderRadius: BorderRadius.circular(Frame.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Pressable(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.only(right: Space.x4),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 88,
                      constraints: const BoxConstraints(minHeight: 112),
                      decoration: BoxDecoration(
                        color: game.accent.block,
                        border: const Border(
                          right: BorderSide(color: Palette.line, width: 1),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: GameIcon(game.id),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.x4,
                          vertical: Space.x3,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              game.name,
                              style: AppType.serif(28, height: 1.1),
                            ),
                            const SizedBox(height: Space.x1),
                            Text(
                              game.tagline,
                              style: AppType.sans(14, height: 1.35),
                            ),
                            const SizedBox(height: Space.x2),
                            Row(
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: Space.x1,
                                    children: [
                                      for (final part in status)
                                        Text(
                                          part,
                                          style: AppType.sans(
                                            12,
                                            color: Palette.ink2,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: Space.x3),
                                _PlayPill(solved: result != null),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Palette.line, width: 1)),
            ),
            child: Pressable(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.x4,
                  vertical: Space.x3,
                ),
                child: Row(
                  children: [
                    Text(
                      'Practice with a new puzzle',
                      style: AppType.sans(14, weight: 600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayPill extends StatelessWidget {
  const _PlayPill({required this.solved});

  final bool solved;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: Space.x4),
      decoration: BoxDecoration(
        color: solved ? Palette.card : Palette.ink,
        border: Border.all(
          color: Palette.ink,
          width: solved ? Frame.border : 0,
        ),
        borderRadius: BorderRadius.circular(Frame.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (solved) ...[
            const _CheckIcon(color: Palette.ink),
            const SizedBox(width: Space.x1),
          ],
          Text(
            solved ? 'Solved' : 'Play',
            style: AppType.sans(
              14,
              weight: 600,
              height: 1,
              color: solved ? Palette.ink : Palette.card,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckIcon extends StatelessWidget {
  const _CheckIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(painter: _CheckPainter(Palette.ink)),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.76)
      ..lineTo(size.width * 0.84, size.height * 0.26);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.store, required this.days});

  final AppStore store;
  final List<WeekDay> days;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in days)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: Space.x2),
              decoration: BoxDecoration(
                border: day.isToday
                    ? const Border(
                        bottom: BorderSide(color: Palette.ink, width: 2),
                      )
                    : null,
              ),
              child: Column(
                children: [
                  Text(
                    weekdayLetter(day.date),
                    style: AppType.sans(12, weight: 600),
                  ),
                  const SizedBox(height: Space.x2),
                  for (final game in games)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.x0),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: store.result(game.id, day.key) != null
                              ? game.accent.block
                              : Palette.card,
                          border: Border.all(
                            color: store.result(game.id, day.key) != null
                                ? Palette.ink
                                : Palette.line,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      radius: Frame.cardRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x3,
        ),
        decoration: BoxDecoration(
          color: Palette.card,
          border: Border.all(color: Palette.line, width: 1),
          borderRadius: BorderRadius.circular(Frame.cardRadius),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily reminder', style: AppType.sans(14, weight: 600)),
                  const SizedBox(height: Space.x0),
                  Text(label, style: AppType.sans(12, color: Palette.ink2)),
                ],
              ),
            ),
            Text(
              'Change',
              style: AppType.sans(14, weight: 600, color: Palette.ink2),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: Space.x3),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Palette.line, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$done of $total solved today', style: AppType.sans(14)),
          const SizedBox(height: Space.x2),
          Text(
            'Works offline. Your progress stays on this device.',
            style: AppType.sans(12, height: 1.5, color: Palette.ink2),
          ),
        ],
      ),
    );
  }
}
