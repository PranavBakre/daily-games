import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../catalog.dart';
import '../dates.dart';
import '../games/merge_board.dart';
import '../games/sudoku_board.dart';
import '../games/tango_board.dart';
import '../games/zip_board.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/pressable.dart';
import '../widgets/win_sheet.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.game,
    required this.store,
    this.mode = 'daily',
    this.difficulty,
    this.seed,
    super.key,
  });

  final GameInfo game;
  final AppStore store;
  final String mode;
  final String? difficulty;
  final String? seed;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late String _mode;
  late String _difficulty;
  late String _seed;
  late String _key;
  late String _sessionId;

  final Stopwatch _clock = Stopwatch();
  int _base = 0;
  Timer? _ticker;
  Timer? _saveTimer;
  bool _solved = false;
  Map<String, dynamic>? _snapshot;
  bool _showHowTo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mode = widget.mode;
    _difficulty = _resolveDifficulty(widget.difficulty);
    _seed = widget.seed ??
        (_mode == 'daily' ? dateKey() : randomPracticeSeed());
    _key = _mode == 'daily' ? dateKey() : _seed;
    _sessionId = widget.store.sessionId(widget.game.id, _mode, _key);

    final saved = widget.store.loadSession(_sessionId);
    _base = saved?.elapsed ?? 0;
    _snapshot = saved?.data;
    _showHowTo = !widget.store.howToSeen(widget.game.id);
    widget.store.markHowToSeen(widget.game.id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _clock.start();
      _ticker = Timer.periodic(const Duration(milliseconds: 400), (_) {
        if (mounted) setState(() {});
      });
    });
  }

  String _resolveDifficulty(String? requested) {
    if (_mode != 'practice') return widget.game.defaultDifficulty;
    if (requested != null && widget.game.hasDifficulty(requested)) {
      return requested;
    }
    return widget.game.defaultDifficulty;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _saveTimer?.cancel();
    _flush();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
      _clock.stop();
      _flush();
    } else if (state == AppLifecycleState.resumed) {
      if (!_solved) _clock.start();
      if (_mode == 'daily' && _key != dateKey()) {
        Navigator.of(context).maybePop();
      }
    }
  }

  int get _elapsed => _base + _clock.elapsedMilliseconds;

  void _onChanged(Map<String, dynamic> snapshot) {
    _snapshot = snapshot;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 220), _flush);
  }

  void _flush() {
    if (_solved || _snapshot == null) return;
    widget.store.saveSession(_sessionId, _snapshot!, _elapsed);
  }

  void _onSolved(Map<String, dynamic> snapshot) {
    if (_solved) return;
    _snapshot = snapshot;
    _solved = true;
    _clock.stop();
    _ticker?.cancel();
    final ms = _elapsed < 1000 ? 1000 : _elapsed;
    widget.store.saveResult(
      game: widget.game.id,
      key: _key,
      mode: _mode,
      difficulty: _difficulty,
      ms: ms,
    );
    widget.store.clearSession(_sessionId);
    showWinSheet(
      context,
      store: widget.store,
      game: widget.game,
      mode: _mode,
      difficulty: _difficulty,
      ms: ms,
      hints: (snapshot['hints'] as num?)?.toInt() ?? 0,
      onPracticeAgain: () => _restartPractice(),
      onBackToGames: () => Navigator.of(context).maybePop(),
    );
  }

  void _restartPractice() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          game: widget.game,
          store: widget.store,
          mode: 'practice',
          difficulty: _difficulty,
        ),
      ),
    );
  }

  void _switchMode(String mode) {
    if (mode == _mode) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          game: widget.game,
          store: widget.store,
          mode: mode,
          difficulty: _difficulty,
        ),
      ),
    );
  }

  void _setDifficulty(String difficulty) {
    if (difficulty == _difficulty && _mode == 'practice') return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          game: widget.game,
          store: widget.store,
          mode: 'practice',
          difficulty: difficulty,
        ),
      ),
    );
  }

  Widget _board() {
    final onChanged = _onChanged;
    final onSolved = _onSolved;
    switch (widget.game.id) {
      case 'zip':
        return ZipBoard(
          seed: '${widget.game.id}:$_mode:$_seed',
          difficulty: _difficulty,
          saved: _snapshot,
          onChanged: onChanged,
          onSolved: onSolved,
        );
      case 'tango':
        return TangoBoard(
          seed: '${widget.game.id}:$_mode:$_seed',
          difficulty: _difficulty,
          saved: _snapshot,
          onChanged: onChanged,
          onSolved: onSolved,
        );
      case 'sudoku':
        return SudokuBoard(
          seed: '${widget.game.id}:$_mode:$_seed',
          difficulty: _difficulty,
          saved: _snapshot,
          onChanged: onChanged,
          onSolved: onSolved,
        );
      default:
        return MergeBoard(
          seed: '${widget.game.id}:$_mode:$_seed',
          saved: _snapshot,
          onChanged: onChanged,
          onSolved: onSolved,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final todayResult = widget.store.result(widget.game.id, dateKey());

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
                  _Header(
                    game: widget.game,
                    meta:
                        '${_mode == 'daily' ? 'No. ${puzzleNumber()}' : 'Practice'} · ${widget.game.labelFor(_difficulty)}',
                    elapsed: _elapsed,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: Space.x3),
                  _Subbar(
                    mode: _mode,
                    difficulty: _difficulty,
                    game: widget.game,
                    onMode: _switchMode,
                    onDifficulty: _setDifficulty,
                  ),
                  if (todayResult != null && _mode == 'daily') ...[
                    const SizedBox(height: Space.x3),
                    _SolvedBanner(ms: todayResult.ms),
                  ],
                  const SizedBox(height: Space.x3),
                  _HowToPlay(
                    rules: widget.game.rules,
                    open: _showHowTo,
                    onToggle: () => setState(() => _showHowTo = !_showHowTo),
                  ),
                  const SizedBox(height: Space.x3),
                  _board(),
                  if (_mode == 'practice') ...[
                    const SizedBox(height: Space.x5),
                    SizedBox(
                      width: double.infinity,
                      child: _PrimaryButton(
                        label: 'New puzzle',
                        onPressed: _restartPractice,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String randomPracticeSeed() {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return now.substring(now.length - 7);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.game,
    required this.meta,
    required this.elapsed,
    required this.onBack,
  });

  final GameInfo game;
  final String meta;
  final int elapsed;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: Space.x3),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Palette.ink, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Transform.translate(
            offset: const Offset(-8, 0),
            child: Pressable(
              onTap: onBack,
              radius: Frame.pillRadius,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: const _BackChevron(),
              ),
            ),
          ),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(game.name, style: AppType.serif(28, height: 1.05)),
                Text(meta, style: AppType.sans(12, color: Palette.ink2)),
              ],
            ),
          ),
          Text(
            formatTime(elapsed),
            style: AppType.sans(20, weight: 600, tabular: true, height: 1),
          ),
        ],
      ),
    );
  }
}

class _BackChevron extends StatelessWidget {
  const _BackChevron();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _ChevronPainter()),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.6, size.height * 0.22)
      ..lineTo(size.width * 0.33, size.height * 0.5)
      ..lineTo(size.width * 0.6, size.height * 0.78);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Subbar extends StatelessWidget {
  const _Subbar({
    required this.mode,
    required this.difficulty,
    required this.game,
    required this.onMode,
    required this.onDifficulty,
  });

  final String mode;
  final String difficulty;
  final GameInfo game;
  final void Function(String mode) onMode;
  final void Function(String difficulty) onDifficulty;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.x3,
      runSpacing: Space.x2,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Segment(
              label: 'Daily',
              active: mode == 'daily',
              onTap: () => onMode('daily'),
            ),
            const SizedBox(width: Space.x4),
            _Segment(
              label: 'Practice',
              active: mode == 'practice',
              onTap: () => onMode('practice'),
            ),
          ],
        ),
        if (mode == 'practice')
          Wrap(
            spacing: Space.x2,
            runSpacing: Space.x2,
            children: [
              for (final entry in game.difficulties)
                _Chip(
                  label: entry.label,
                  active: entry.id == difficulty,
                  onTap: () => onDifficulty(entry.id),
                ),
            ],
          ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Space.x1),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? Palette.ink : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppType.sans(
            14,
            weight: 600,
            color: active ? Palette.ink : Palette.ink2,
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      radius: Frame.pillRadius,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: Space.x3),
        decoration: BoxDecoration(
          color: active ? Palette.ink : Palette.card,
          border: Border.all(color: active ? Palette.ink : Palette.line, width: 1),
          borderRadius: BorderRadius.circular(Frame.pillRadius),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppType.sans(
            12,
            weight: 600,
            height: 1,
            color: active ? Palette.card : Palette.ink,
          ),
        ),
      ),
    );
  }
}

class _SolvedBanner extends StatelessWidget {
  const _SolvedBanner({required this.ms});

  final int ms;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.x3, vertical: Space.x2),
      decoration: BoxDecoration(
        color: Palette.goodWash,
        border: Border.all(color: Palette.good, width: 1),
        borderRadius: BorderRadius.circular(Frame.cardRadius),
      ),
      child: Text(
        'Solved today in ${formatTime(ms)}. Playing again won\'t change your time.',
        style: AppType.sans(14, height: 1.4),
      ),
    );
  }
}

class _HowToPlay extends StatelessWidget {
  const _HowToPlay({
    required this.rules,
    required this.open,
    required this.onToggle,
  });

  final List<String> rules;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.card,
        border: Border.all(color: Palette.line, width: 1),
        borderRadius: BorderRadius.circular(Frame.cardRadius),
      ),
      child: Column(
        children: [
          Pressable(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x4,
                vertical: Space.x3,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('How to play', style: AppType.sans(14, weight: 700)),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Palette.ink, width: 2),
                          bottom: BorderSide(color: Palette.ink, width: 2),
                        ),
                      ),
                      transform: Matrix4.rotationZ(0.785398),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.x4,
                0,
                Space.x4,
                Space.x4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < rules.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.x2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 16,
                            child: Text(
                              '${i + 1}.',
                              style: AppType.sans(14, height: 1.45),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              rules[i],
                              style: AppType.sans(14, height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      radius: Frame.pillRadius,
      pressedColor: Palette.ink2,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Palette.ink,
          borderRadius: BorderRadius.circular(Frame.pillRadius),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppType.sans(16, weight: 600, height: 1, color: Palette.card),
        ),
      ),
    );
  }
}
