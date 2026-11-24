import 'package:material_ui/material_ui.dart';

import '../games/merge.dart';
import '../theme.dart';
import '../widgets/drag_surface.dart';
import '../widgets/pressable.dart';

class MergeBoard extends StatefulWidget {
  const MergeBoard({
    required this.seed,
    required this.saved,
    required this.onChanged,
    required this.onSolved,
    super.key,
  });

  final String seed;
  final Map<String, dynamic>? saved;
  final void Function(Map<String, dynamic> state) onChanged;
  final void Function(Map<String, dynamic> state) onSolved;

  @override
  State<MergeBoard> createState() => _MergeBoardState();
}

class _MergeBoardState extends State<MergeBoard> {
  static const _size = mergeBoardSize;

  late final MergePuzzle _puzzle = generateMerge(widget.seed);
  late List<int> _cells;
  late List<List<int>> _history;
  int _hints = 0;
  int? _selected;
  int? _destination;
  String _message = '';
  bool _solved = false;

  int? _dragFrom;
  Offset _start = Offset.zero;
  Offset _offset = Offset.zero;
  String? _axis;
  double _pitch = 0;

  @override
  void initState() {
    super.initState();
    _cells = _restoreCells(widget.saved?['cells']);
    _history = _restoreHistory(widget.saved?['history']);
    _hints = (widget.saved?['hints'] as num?)?.toInt() ?? 0;
    _solved = _cells.where((value) => value != 0).length == 1;
  }

  List<int> _restoreCells(Object? raw) {
    if (raw is List && raw.length == _size * _size) {
      final values = raw.map((value) => value is num ? value.toInt() : 0).toList();
      if (values.every((value) => value >= 0)) return values;
      return values;
    }
    return List<int>.of(_puzzle.cells);
  }

  List<List<int>> _restoreHistory(Object? raw) {
    if (raw is! List) return [];
    return [
      for (final entry in raw)
        if (entry is List && entry.length == _size * _size)
          [for (final value in entry) value is num ? value.toInt() : 0],
    ];
  }

  Map<String, dynamic> _snapshot() => {
    'cells': List<int>.of(_cells),
    'history': [for (final entry in _history) List<int>.of(entry)],
    'hints': _hints,
  };

  void _notify() => widget.onChanged(_snapshot());

  int _tiles() => _cells.where((value) => value != 0).length;

  bool get _stuck => mergeIsStuck(_cells, _size);

  void _applyMerge(int from, int to) {
    final next = mergeTiles(_cells, _size, from, to);
    if (next == null) return;
    _history.add(List<int>.of(_cells));
    _cells = next;
    _selected = null;
    _destination = null;
    _message = '';
    final solved = _tiles() == 1;
    setState(() => _solved = solved);
    if (solved) {
      widget.onSolved(_snapshot());
    } else {
      _notify();
    }
  }

  void _tapIndex(int index) {
    if (_solved) return;
    final value = _cells[index];
    if (_selected == null) {
      if (value == 0) return;
      setState(() {
        _selected = index;
        _destination = null;
        _message = '';
      });
      return;
    }
    if (_selected == index) {
      setState(() => _selected = null);
      return;
    }
    final from = _selected!;
    final merges = mergeTiles(_cells, _size, from, index) != null;
    _applyMerge(from, index);
    if (!merges) {
      setState(() {
        _selected = value == 0 ? null : index;
        _destination = null;
      });
    }
  }

  int? _indexAt(Offset position) {
    if (_pitch <= 0) return null;
    final col = (position.dx / (_pitch + 1)).floor();
    final row = (position.dy / (_pitch + 1)).floor();
    if (row < 0 || row >= _size || col < 0 || col >= _size) return null;
    return row * _size + col;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final from = _dragFrom;
    if (from == null) return;
    final delta = details.localPosition - _start;
    var axis = _axis;
    if (axis == null) {
      if (delta.dx.abs() < 6 && delta.dy.abs() < 6) return;
      axis = delta.dx.abs() >= delta.dy.abs() ? 'x' : 'y';
      _axis = axis;
    }
    final distance = (axis == 'x' ? delta.dx : delta.dy).clamp(-_pitch, _pitch);
    final neighbour = _project(from, axis, distance);
    setState(() {
      _offset = axis == 'x' ? Offset(distance, 0) : Offset(0, distance);
      _destination = neighbour;
    });
  }

  void _onPanEnd() {
    final from = _dragFrom;
    final to = _destination;
    final moved = _axis != null;
    setState(() {
      _dragFrom = null;
      _offset = Offset.zero;
      _axis = null;
      _destination = null;
    });
    if (from == null) return;
    if (!moved) {
      _tapIndex(from);
      return;
    }
    if (to != null) _applyMerge(from, to);
  }

  int? _project(int from, String axis, double distance) {
    final direction = distance.sign.toInt();
    final neighbour = from + direction * (axis == 'x' ? 1 : _size);
    if (direction == 0) return null;
    if (!mergeNeighbours(from, _size).contains(neighbour)) return null;
    return distance.abs() >= _pitch / 2 ? neighbour : null;
  }

  void _undo() {
    if (_history.isEmpty || _solved) return;
    setState(() {
      _cells = _history.removeLast();
      _selected = null;
      _destination = null;
      _message = 'Move undone.';
    });
    _notify();
  }

  void _hint() {
    if (_solved) return;
    final solution = findMergeSolution(_cells, _size);
    if (solution == null || solution.isEmpty) {
      setState(() => _message = 'Undo a move to find a way forward.');
      return;
    }
    final move = solution.first;
    setState(() {
      _hints++;
      _selected = move[0];
      _destination = move[1];
      _message =
          'Drag the filled tile to the outlined tile in row ${move[1] ~/ _size + 1}, column ${move[1] % _size + 1}.';
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Accents.merge;
    final status = _stuck
        ? 'No legal moves. Undo a move to keep playing.'
        : _message.isNotEmpty
            ? _message
            : '${_tiles()} tiles remaining';

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _pitch = (constraints.maxWidth - 3) / _size;
              return DragSurface(
                onStart: (details) {
                  final index = _indexAt(details.localPosition);
                  if (_solved || index == null || _cells[index] == 0) {
                    _dragFrom = null;
                    return;
                  }
                  setState(() {
                    _dragFrom = index;
                    _start = details.localPosition;
                    _offset = Offset.zero;
                    _axis = null;
                    _destination = null;
                    _message = '';
                  });
                },
                onUpdate: _onPanUpdate,
                onEnd: _onPanEnd,
                onCancel: () {
                  setState(() {
                    _dragFrom = null;
                    _offset = Offset.zero;
                    _axis = null;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Palette.line,
                    border: Border.all(
                      color: _stuck ? Palette.bad : Palette.ink,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(Frame.cardRadius),
                  ),
                  child: Column(
                    spacing: 1,
                    children: [
                      for (var row = 0; row < _size; row++)
                        Expanded(
                          child: Row(
                            spacing: 1,
                            children: [
                              for (var col = 0; col < _size; col++)
                                Expanded(
                                  child: _tile(row * _size + col, accent),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
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
        const SizedBox(height: Space.x3),
        Row(
          children: [
            Expanded(
              child: GhostButton(
                label: 'Undo',
                onPressed: _history.isEmpty || _solved ? null : _undo,
              ),
            ),
            const SizedBox(width: Space.x2),
            Expanded(
              child: GhostButton(
                label: 'Hint',
                onPressed: _solved || _stuck ? null : _hint,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tile(int index, GameAccent accent) {
    final value = _cells[index];
    final dragging = _dragFrom == index;
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: value == 0
            ? Palette.card
            : _solved
                ? Palette.goodWash
                : _selected == index
                    ? accent.block
                    : accent.wash,
        border: _destination == index
            ? Border.all(color: accent.ink, width: 2)
            : null,
      ),
      alignment: Alignment.center,
      child: value == 0
          ? null
          : Text(
              '$value',
              style: AppType.serif(
                28,
                height: 1,
                color: _stuck ? Palette.bad : Palette.ink,
              ),
            ),
    );

    final Widget body = dragging
        ? Transform.translate(
            offset: _offset,
            child: Opacity(opacity: 0.96, child: tile),
          )
        : tile;

    return KeyedSubtree(key: ValueKey('merge-tile-$index'), child: body);
  }
}
