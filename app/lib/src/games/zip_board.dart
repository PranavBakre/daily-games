import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../games/zip.dart';
import '../theme.dart';
import '../widgets/drag_surface.dart';
import '../widgets/pressable.dart';

class ZipBoard extends StatefulWidget {
  const ZipBoard({
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
  State<ZipBoard> createState() => _ZipBoardState();
}

class _ZipBoardState extends State<ZipBoard> {
  late final ZipPuzzle _puzzle = generateZip(widget.seed, widget.difficulty);
  late List<int> _path;
  int _hints = 0;
  bool _solved = false;
  String _message = '';
  bool _dragging = false;

  int get _size => _puzzle.size;

  @override
  void initState() {
    super.initState();
    _path = [];
    _hints = (widget.saved?['hints'] as num?)?.toInt() ?? 0;
    final saved = widget.saved?['path'];
    if (saved is List) {
      for (final entry in saved) {
        if (entry is! num) break;
        final index = entry.toInt();
        if (index < 0 || index >= _size) break;
        if (!_apply(index, notify: false)) break;
      }
      if (_path.length == _size && _path.last == _finish) _solved = true;
    }
  }

  int get _finish {
    var bestLabel = 0;
    var cell = 0;
    for (var i = 0; i < _puzzle.numbers.length; i++) {
      if (_puzzle.numbers[i] > bestLabel) {
        bestLabel = _puzzle.numbers[i];
        cell = i;
      }
    }
    return cell;
  }

  List<(int cell, int label)> get _checkpoints {
    final list = <(int, int)>[];
    for (var i = 0; i < _puzzle.numbers.length; i++) {
      if (_puzzle.numbers[i] != 0) list.add((i, _puzzle.numbers[i]));
    }
    list.sort((a, b) => a.$2.compareTo(b.$2));
    return list;
  }

  int get _expectedLabel {
    for (final checkpoint in _checkpoints) {
      if (!_path.contains(checkpoint.$1)) return checkpoint.$2;
    }
    return 1 << 30;
  }

  List<int> _neighbours(int cell) {
    final table = zipNeighbours(_puzzle.width, _puzzle.height);
    return table[cell];
  }

  bool _walled(int a, int b) {
    final key = a < b ? a * 1000 + b : b * 1000 + a;
    for (final wall in _puzzle.walls) {
      final other = wall[0] < wall[1]
          ? wall[0] * 1000 + wall[1]
          : wall[1] * 1000 + wall[0];
      if (other == key) return true;
    }
    return false;
  }

  bool _canAppend(int index) {
    if (_path.isEmpty) return _puzzle.numbers[index] == 1;
    if (_path.contains(index)) return false;
    final head = _path.last;
    if (head == _finish) return false;
    if (!_neighbours(head).contains(index)) return false;
    if (_walled(head, index)) return false;
    final label = _puzzle.numbers[index];
    if (label != 0 && label != _expectedLabel) return false;
    return true;
  }

  bool _extendStraight(int index) {
    final head = _path.last;
    final headRow = head ~/ _puzzle.width;
    final headCol = head % _puzzle.width;
    final row = index ~/ _puzzle.width;
    final col = index % _puzzle.width;
    if (headRow != row && headCol != col) return false;
    final step = headRow == row
        ? (col > headCol ? 1 : -1)
        : (row > headRow ? _puzzle.width : -_puzzle.width);
    final added = <int>[];
    var cell = head + step;
    while (true) {
      if (!_canAppend(cell)) {
        _path.removeRange(_path.length - added.length, _path.length);
        return false;
      }
      _path.add(cell);
      added.add(cell);
      if (cell == index) return true;
      cell += step;
    }
  }

  bool _apply(int index, {bool notify = true}) {
    if (index < 0 || _solved) return false;
    _message = '';
    final at = _path.indexOf(index);
    if (at >= 0) {
      if (at == _path.length - 1) return false;
      _path = _path.sublist(0, at + 1);
      if (notify) _afterChange();
      return true;
    }
    if (_puzzle.numbers[index] == 1) {
      _path = [index];
      if (notify) _afterChange();
      return true;
    }
    if (_canAppend(index)) {
      _path = [..._path, index];
      if (notify) _afterChange();
      return true;
    }
    if (_path.isEmpty) return false;
    final extended = _extendStraight(index);
    if (extended && notify) _afterChange();
    return extended;
  }

  void _afterChange() {
    final complete =
        _path.length == _size && _path.isNotEmpty && _path.last == _finish;
    setState(() {
      _solved = complete;
      if (complete) _message = 'Solved';
    });
    if (complete) {
      widget.onSolved(_snapshot());
    } else {
      _notify();
    }
  }

  /// A line that reaches the highest number with cells still empty can never
  /// grow again, so the board has to say why it stopped accepting a drag.
  bool get _stuckAtFinish =>
      !_solved &&
      _path.isNotEmpty &&
      _path.last == _finish &&
      _path.length < _size;

  String get _status {
    if (_message.isNotEmpty) return _message;
    if (_stuckAtFinish) {
      final left = _size - _path.length;
      return 'The line reached ${_puzzle.numbers[_finish]} with $left '
          '${left == 1 ? 'cell' : 'cells'} still empty — drag back to reroute.';
    }
    return '${_path.length} of $_size cells';
  }

  Map<String, dynamic> _snapshot() => {
    'path': List<int>.of(_path),
    'hints': _hints,
  };

  void _notify() => widget.onChanged(_snapshot());

  void _undo() {
    if (_solved || _path.isEmpty) return;
    setState(() {
      _path = _path.sublist(0, _path.length - 1);
      _message = '';
    });
    _notify();
  }

  void _clear() {
    if (_solved) return;
    setState(() {
      _path = [];
      _message = '';
    });
    _notify();
  }

  void _hint() {
    if (_solved) return;
    _hints++;
    var correct = 0;
    while (correct < _path.length &&
        correct < _puzzle.solution.length &&
        _path[correct] == _puzzle.solution[correct]) {
      correct++;
    }
    setState(() {
      if (correct < _path.length) {
        _path = _puzzle.solution.sublist(0, math.max(1, correct));
        _message = 'Your line went off track here. Keep going from the end.';
      } else {
        _path = _puzzle.solution.sublist(0, math.min(_size, correct + 3));
        _message = 'Hint: the line continues like this.';
      }
    });
    _notify();
  }

  int? _cellAt(Offset position, Size size) {
    final cellWidth = size.width / _puzzle.width;
    final cellHeight = size.height / _puzzle.height;
    final col = (position.dx / cellWidth).floor();
    final row = (position.dy / cellHeight).floor();
    if (row < 0 || row >= _puzzle.height || col < 0 || col >= _puzzle.width) {
      return null;
    }
    return row * _puzzle.width + col;
  }

  @override
  Widget build(BuildContext context) {
    final accent = Accents.zip;
    final status = _status;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: _puzzle.width / _puzzle.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return DragSurface(
                onStart: (details) {
                  final cell = _cellAt(details.localPosition, size);
                  if (cell == null) return;
                  _dragging = true;
                  _apply(cell);
                },
                onUpdate: (details) {
                  if (!_dragging) return;
                  final cell = _cellAt(details.localPosition, size);
                  if (cell != null) _apply(cell);
                },
                onEnd: () => _dragging = false,
                onCancel: () => _dragging = false,
                child: Container(
                  decoration: BoxDecoration(
                    color: Palette.card,
                    border: Border.all(color: Palette.ink, width: 2),
                    borderRadius: BorderRadius.circular(Frame.cardRadius),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ZipPainter(
                            puzzle: _puzzle,
                            path: _path,
                            solved: _solved,
                            accent: accent,
                          ),
                        ),
                      ),
                      for (final checkpoint in _checkpoints)
                        _badge(checkpoint, size, accent),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Space.x3),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 20),
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: AppType.sans(14, color: Palette.ink2),
          ),
        ),
        const SizedBox(height: Space.x3),
        Row(
          children: [
            Expanded(
              child: GhostButton(
                label: 'Undo',
                onPressed: _solved || _path.isEmpty ? null : _undo,
              ),
            ),
            const SizedBox(width: Space.x2),
            Expanded(
              child: GhostButton(
                label: 'Clear',
                onPressed: _solved || _path.isEmpty ? null : _clear,
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

  Widget _badge((int, int) checkpoint, Size size, GameAccent accent) {
    final cellWidth = size.width / _puzzle.width;
    final cellHeight = size.height / _puzzle.height;
    final index = checkpoint.$1;
    final row = index ~/ _puzzle.width;
    final col = index % _puzzle.width;
    final diameter = cellWidth * 0.56;
    final reached = _path.contains(index);
    final fontSize = (cellWidth * 0.34).clamp(11.0, 22.0);

    return Positioned(
      left: col * cellWidth + cellWidth / 2 - diameter / 2,
      top: row * cellHeight + cellHeight / 2 - diameter / 2,
      width: diameter,
      height: diameter,
      child: Container(
        decoration: BoxDecoration(
          color: Palette.ink,
          shape: BoxShape.circle,
          boxShadow: reached
              ? [BoxShadow(color: accent.ink, blurRadius: 0, spreadRadius: 3)]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '${checkpoint.$2}',
          style: AppType.serif(fontSize, height: 1, color: Palette.card),
        ),
      ),
    );
  }
}

class _ZipPainter extends CustomPainter {
  _ZipPainter({
    required this.puzzle,
    required this.path,
    required this.solved,
    required this.accent,
  });

  final ZipPuzzle puzzle;
  final List<int> path;
  final bool solved;
  final GameAccent accent;

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / puzzle.width;
    final cellHeight = size.height / puzzle.height;

    Offset center(int index) {
      final row = index ~/ puzzle.width;
      final col = index % puzzle.width;
      return Offset(
        col * cellWidth + cellWidth / 2,
        row * cellHeight + cellHeight / 2,
      );
    }

    final grid = Paint()
      ..color = Palette.line
      ..strokeWidth = 1;
    for (var col = 1; col < puzzle.width; col++) {
      final x = col * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var row = 1; row < puzzle.height; row++) {
      final y = row * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (path.isNotEmpty) {
      final line = Paint()
        ..color = solved ? accent.ink : accent.block
        ..style = PaintingStyle.stroke
        ..strokeWidth = cellWidth * 0.38
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final trace = Path()
        ..moveTo(center(path.first).dx, center(path.first).dy);
      for (var i = 1; i < path.length; i++) {
        final point = center(path[i]);
        trace.lineTo(point.dx, point.dy);
      }
      if (path.length == 1) {
        final point = center(path.first);
        trace.lineTo(point.dx + 0.1, point.dy);
      }
      canvas.drawPath(trace, line);
    }

    final wall = Paint()
      ..color = Palette.ink
      ..strokeWidth = cellWidth * 0.09
      ..strokeCap = StrokeCap.round;
    for (final pair in puzzle.walls) {
      final a = pair[0];
      final b = pair[1];
      final row = a ~/ puzzle.width;
      final col = a % puzzle.width;
      if (b == a + 1) {
        final x = (col + 1) * cellWidth;
        canvas.drawLine(
          Offset(x, row * cellHeight + cellHeight * 0.04),
          Offset(x, row * cellHeight + cellHeight * 0.96),
          wall,
        );
      } else {
        final y = (row + 1) * cellHeight;
        canvas.drawLine(
          Offset(col * cellWidth + cellWidth * 0.04, y),
          Offset(col * cellWidth + cellWidth * 0.96, y),
          wall,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ZipPainter oldDelegate) =>
      !listEquals(oldDelegate.path, path) ||
      oldDelegate.solved != solved ||
      oldDelegate.puzzle != puzzle;
}
