import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../games/tango.dart';
import '../theme.dart';
import '../widgets/pressable.dart';

class TangoBoard extends StatefulWidget {
  const TangoBoard({
    required this.seed,
    required this.difficulty,
    required this.saved,
    required this.onChanged,
    required this.onSolved,
    super.key,
  });

  final String seed;
  final String difficulty;
  final Map<String, dynamic>? saved;
  final void Function(Map<String, dynamic> state) onChanged;
  final void Function(Map<String, dynamic> state) onSolved;

  @override
  State<TangoBoard> createState() => _TangoBoardState();
}

class _TangoBoardState extends State<TangoBoard> {
  static const _size = tangoSize;

  late final TangoPuzzle _puzzle =
      generateTango(widget.seed, widget.difficulty);
  late List<int> _values;
  late Set<int> _hinted;
  int _hints = 0;
  bool _solved = false;
  String _message = '';
  int _flagged = -1;

  @override
  void initState() {
    super.initState();
    _values = List<int>.of(_puzzle.givens);
    _hints = (widget.saved?['hints'] as num?)?.toInt() ?? 0;
    _hinted = _restoreHinted(widget.saved?['hinted'], widget.saved?['values']);
  }

  Set<int> _restoreHinted(Object? hinted, Object? values) {
    final result = <int>{};
    if (hinted is! List || values is! List || values.length != _size * _size) {
      return result;
    }
    for (final entry in hinted) {
      if (entry is! num) continue;
      final index = entry.toInt();
      if (index < 0 || index >= _size * _size) continue;
      final value = values[index];
      if (value is num && value.toInt() == _puzzle.solution[index]) {
        result.add(index);
      }
    }
    return result;
  }

  Map<String, dynamic> _snapshot() => {
    'values': List<int>.of(_values),
    'hints': _hints,
    'hinted': _hinted.toList()..sort(),
  };

  void _notify() => widget.onChanged(_snapshot());

  Set<int> get _conflicts => tangoConflicts(_values, _puzzle.edges, _size);

  void _tap(int index) {
    if (_solved) return;
    if (_puzzle.givens[index] != 0) return;
    if (_hinted.contains(index)) return;
    setState(() {
      _message = '';
      _flagged = -1;
      _values[index] = switch (_values[index]) {
        0 => tangoSun,
        tangoSun => tangoMoon,
        _ => 0,
      };
    });
    _notify();
    _checkSolved();
  }

  void _clear() {
    if (_solved) return;
    setState(() {
      for (var i = 0; i < _values.length; i++) {
        if (_puzzle.givens[i] == 0 && !_hinted.contains(i)) _values[i] = 0;
      }
      _message = '';
      _flagged = -1;
    });
    _notify();
  }

  void _hint() {
    if (_solved) return;
    _hints++;
    final wrong = _firstWrong();
    if (wrong >= 0) {
      setState(() {
        _flagged = wrong;
        _message = 'This cell is wrong. Tap it to change it.';
      });
      _notify();
      return;
    }
    final target = _bestEmpty();
    if (target < 0) {
      _notify();
      return;
    }
    setState(() {
      _values[target] = _puzzle.solution[target];
      _hinted.add(target);
      _flagged = -1;
      _message =
          'Hint: a ${_values[target] == tangoSun ? 'sun' : 'moon'} goes in the marked cell.';
    });
    _notify();
    _checkSolved();
  }

  int _firstWrong() {
    for (var i = 0; i < _values.length; i++) {
      if (_values[i] != 0 && _values[i] != _puzzle.solution[i]) return i;
    }
    return -1;
  }

  int _bestEmpty() {
    var best = -1;
    var bestScore = -1;
    for (var i = 0; i < _values.length; i++) {
      if (_values[i] != 0) continue;
      final score = _filledAround(i) +
          _puzzle.edges.where((edge) => edge.a == i || edge.b == i).length;
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    return best;
  }

  int _filledAround(int index) {
    var count = 0;
    for (final neighbour in tangoNeighbours(index, _size)) {
      if (_values[neighbour] != 0) count++;
    }
    return count;
  }

  void _checkSolved() {
    final filled = _values.every((value) => value != 0);
    if (!filled || _conflicts.isNotEmpty) return;
    setState(() => _solved = true);
    widget.onSolved(_snapshot());
  }

  @override
  Widget build(BuildContext context) {
    final accent = Accents.tango;
    final conflicts = _conflicts;
    final filled = _values.where((value) => value != 0).length;
    final status = _message.isNotEmpty
        ? _message
        : conflicts.isNotEmpty
            ? 'Something clashes — check the highlighted cells.'
            : '$filled of ${_values.length} cells';

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The stack sits inside the 2 px frame, so badges are placed
              // against the cells' own box, not the outer border.
              final size = Size(
                constraints.maxWidth - 4,
                constraints.maxHeight - 4,
              );
              return Container(
                key: const ValueKey('tango-board'),
                decoration: BoxDecoration(
                  color: Palette.card,
                  border: Border.all(color: Palette.ink, width: 2),
                  borderRadius: BorderRadius.circular(Frame.cardRadius),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        for (var row = 0; row < _size; row++)
                          Expanded(
                            child: Row(
                              children: [
                                for (var col = 0; col < _size; col++)
                                  Expanded(
                                    child: _cell(
                                      row * _size + col,
                                      conflicts,
                                      accent,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    for (final edge in _puzzle.edges) _badge(edge, size),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Space.x3),
        SizedBox(
          height: 20,
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: AppType.sans(14, color: Palette.ink2),
          ),
        ),
        const SizedBox(height: Space.x1),
        Text(
          'Tap a cell: sun, moon, empty',
          style: AppType.sans(12, color: Palette.ink2),
        ),
        const SizedBox(height: Space.x3),
        Row(
          children: [
            Expanded(
              child: GhostButton(
                label: 'Clear',
                onPressed: _solved ? null : _clear,
              ),
            ),
            const SizedBox(width: Space.x2),
            Expanded(
              child: GhostButton(
                label: 'Hint',
                onPressed: _solved ? null : _hint,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cell(int index, Set<int> conflicts, GameAccent accent) {
    final value = _values[index];
    final given = _puzzle.givens[index] != 0;
    final row = index ~/ _size;
    final col = index % _size;
    final background = _solved
        ? Palette.goodWash
        : conflicts.contains(index)
            ? Palette.badWash
            : _hinted.contains(index)
                ? accent.wash
                : given
                    ? Palette.peer
                    : Palette.card;

    return Pressable(
      onTap: () => _tap(index),
      pressedColor: Palette.focus,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          border: Border(
            right: col == _size - 1
                ? BorderSide.none
                : const BorderSide(color: Palette.line, width: 1),
            bottom: row == _size - 1
                ? BorderSide.none
                : const BorderSide(color: Palette.line, width: 1),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (value != 0)
              Center(
                child: FractionallySizedBox(
                  widthFactor: 0.54,
                  heightFactor: 0.54,
                  child: CustomPaint(
                    painter: _TangoSymbolPainter(
                      sun: value == tangoSun,
                      color: value == tangoSun ? Palette.sun : Palette.moon,
                    ),
                  ),
                ),
              ),
            if (_flagged == index)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Palette.bad, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Each badge sits on the midpoint of the border its two cells share.
  Widget _badge(TangoEdge edge, Size size) {
    final cellWidth = size.width / _size;
    final cellHeight = size.height / _size;
    final horizontal = edge.b == edge.a + 1;
    final row = edge.a ~/ _size;
    final col = edge.a % _size;
    final centerX = (horizontal ? col + 1 : col + 0.5) * cellWidth;
    final centerY = (horizontal ? row + 0.5 : row + 1) * cellHeight;
    final diameter = math.min(22.0, cellWidth * 0.36);

    return Positioned(
      left: centerX - diameter / 2,
      top: centerY - diameter / 2,
      width: diameter,
      height: diameter,
      child: Container(
        key: ValueKey('tango-badge-${edge.a}-${edge.b}'),
        decoration: BoxDecoration(
          color: Palette.card,
          shape: BoxShape.circle,
          border: Border.all(color: Palette.ink, width: 1.5),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            edge.same ? '=' : '×',
            style: AppType.sans(14, weight: 700, height: 1),
          ),
        ),
      ),
    );
  }
}

class _TangoSymbolPainter extends CustomPainter {
  _TangoSymbolPainter({required this.sun, required this.color});

  final bool sun;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final unit = size.width / 24;
    final paint = Paint()..color = color;

    if (sun) {
      canvas.drawCircle(center, 4.1 * unit, paint);
      final rays = Paint()
        ..color = color
        ..strokeWidth = 1.7 * unit
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final direction = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          center + direction * (6.2 * unit),
          center + direction * (9.4 * unit),
          rays,
        );
      }
      return;
    }

    final outer = Path()
      ..addOval(Rect.fromCircle(center: center, radius: 8.7 * unit));
    final cut = Path()
      ..addOval(
        Rect.fromCircle(
          center: center + Offset(4.5 * unit, -5.5 * unit),
          radius: 7.1 * unit,
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, cut),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TangoSymbolPainter oldDelegate) =>
      oldDelegate.sun != sun || oldDelegate.color != color;
}
