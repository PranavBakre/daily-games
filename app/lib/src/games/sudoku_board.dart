import 'package:material_ui/material_ui.dart';

import '../games/sudoku.dart';
import '../theme.dart';
import '../widgets/pressable.dart';

class SudokuBoard extends StatefulWidget {
  const SudokuBoard({
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
  State<SudokuBoard> createState() => _SudokuBoardState();
}

class _SudokuBoardState extends State<SudokuBoard> {
  late final SudokuPuzzle _puzzle =
      generateSudoku(widget.seed, widget.difficulty);
  late final SudokuLayout _layout = sudokuLayout(_puzzle.size);

  late List<int> _values;
  late List<int> _notes;
  late Set<int> _hinted;
  int _hints = 0;
  int _selected = 0;
  bool _notesMode = false;
  bool _solved = false;
  String _message = '';
  int _flagged = -1;

  int get _n => _puzzle.size;
  int get _total => _layout.cells;

  @override
  void initState() {
    super.initState();
    _values = List<int>.of(_puzzle.givens);
    _notes = List<int>.filled(_total, 0);
    _hints = (widget.saved?['hints'] as num?)?.toInt() ?? 0;
    _notesMode = widget.saved?['notesMode'] == true;
    _restoreValues(widget.saved?['values']);
    _restoreNotes(widget.saved?['notes']);
    _hinted = _restoreHinted(widget.saved?['hinted']);
    final selected = (widget.saved?['selected'] as num?)?.toInt();
    if (selected != null && selected >= 0 && selected < _total) {
      _selected = selected;
    } else {
      _selected = _firstEmpty();
    }
  }

  void _restoreValues(Object? raw) {
    if (raw is! List || raw.length != _total) return;
    for (var i = 0; i < _total; i++) {
      if (_puzzle.givens[i] != 0) continue;
      final value = raw[i];
      if (value is num && value >= 0 && value <= _n) {
        _values[i] = value.toInt();
      }
    }
  }

  void _restoreNotes(Object? raw) {
    if (raw is! List || raw.length != _total) return;
    final all = (1 << _n) - 1;
    for (var i = 0; i < _total; i++) {
      if (_puzzle.givens[i] != 0) continue;
      final mask = raw[i];
      if (mask is num && mask >= 0 && mask <= all) {
        _notes[i] = mask.toInt();
      }
    }
  }

  Set<int> _restoreHinted(Object? raw) {
    final result = <int>{};
    if (raw is! List) return result;
    for (final entry in raw) {
      if (entry is! num) continue;
      final index = entry.toInt();
      if (index < 0 || index >= _total) continue;
      if (_values[index] == _puzzle.solution[index]) result.add(index);
    }
    return result;
  }

  int _firstEmpty() {
    for (var i = 0; i < _total; i++) {
      if (_values[i] == 0) return i;
    }
    return 0;
  }

  Map<String, dynamic> _snapshot() => {
    'values': List<int>.of(_values),
    'notes': List<int>.of(_notes),
    'selected': _selected,
    'notesMode': _notesMode,
    'hints': _hints,
    'hinted': _hinted.toList()..sort(),
  };

  void _notify() => widget.onChanged(_snapshot());

  Set<int> get _conflicts {
    final bad = <int>{};
    for (final unit in _layout.units) {
      final seen = <int, int>{};
      for (final index in unit) {
        final value = _values[index];
        if (value == 0) continue;
        final previous = seen[value];
        if (previous != null) {
          bad
            ..add(index)
            ..add(previous);
        } else {
          seen[value] = index;
        }
      }
    }
    return bad;
  }

  void _select(int index) {
    if (_solved) return;
    setState(() {
      _selected = index;
      _message = '';
      _flagged = -1;
    });
    _notify();
  }

  void _place(int digit) {
    if (_solved || _selected < 0) return;
    if (_puzzle.givens[_selected] != 0) return;
    if (_hinted.contains(_selected)) return;
    setState(() {
      _message = '';
      _flagged = -1;
      if (_notesMode) {
        if (_values[_selected] != 0) return;
        _notes[_selected] ^= 1 << (digit - 1);
      } else if (_values[_selected] == digit) {
        _values[_selected] = 0;
      } else {
        _values[_selected] = digit;
        _notes[_selected] = 0;
        final bit = 1 << (digit - 1);
        for (final peer in _layout.peers[_selected]) {
          _notes[peer] &= ~bit;
        }
      }
    });
    _notify();
    _checkSolved();
  }

  void _erase() {
    if (_solved || _selected < 0) return;
    if (_puzzle.givens[_selected] != 0) return;
    if (_hinted.contains(_selected)) return;
    setState(() {
      _values[_selected] = 0;
      _notes[_selected] = 0;
      _message = '';
      _flagged = -1;
    });
    _notify();
  }

  void _toggleNotes() {
    setState(() {
      _notesMode = !_notesMode;
    });
    _notify();
  }

  void _hint() {
    if (_solved) return;
    _hints++;
    final wrong = _firstWrong();
    if (wrong >= 0) {
      setState(() {
        _selected = wrong;
        _flagged = wrong;
        _message = 'This cell is wrong. Erase it and try again.';
      });
      _notify();
      return;
    }
    final target = _hintTarget();
    if (target < 0) {
      _notify();
      return;
    }
    setState(() {
      _values[target] = _puzzle.solution[target];
      _notes[target] = 0;
      final bit = 1 << (_puzzle.solution[target] - 1);
      for (final peer in _layout.peers[target]) {
        _notes[peer] &= ~bit;
      }
      _hinted.add(target);
      _selected = target;
      _flagged = -1;
      _message = 'Hint: a ${_puzzle.solution[target]} goes here.';
    });
    _notify();
    _checkSolved();
  }

  int _firstWrong() {
    for (var i = 0; i < _total; i++) {
      if (_values[i] != 0 && _values[i] != _puzzle.solution[i]) return i;
    }
    return -1;
  }

  int _hintTarget() {
    if (_selected >= 0 && _values[_selected] == 0) return _selected;
    var best = -1;
    var bestCount = _n + 1;
    for (var i = 0; i < _total; i++) {
      if (_values[i] != 0) continue;
      final count = _candidates(i);
      if (count < bestCount) {
        bestCount = count;
        best = i;
      }
    }
    return best;
  }

  int _candidates(int index) {
    var used = 0;
    for (final peer in _layout.peers[index]) {
      final value = _values[peer];
      if (value != 0) used |= 1 << (value - 1);
    }
    var free = ~used & ((1 << _n) - 1);
    var count = 0;
    while (free != 0) {
      free &= free - 1;
      count++;
    }
    return count;
  }

  void _checkSolved() {
    if (_values.any((value) => value == 0)) return;
    if (_conflicts.isNotEmpty) return;
    setState(() => _solved = true);
    widget.onSolved(_snapshot());
  }

  @override
  Widget build(BuildContext context) {
    final accent = Accents.sudoku;
    final conflicts = _conflicts;
    final filled = _values.where((value) => value != 0).length;
    final status = _message.isNotEmpty
        ? _message
        : conflicts.isNotEmpty
            ? 'That digit repeats in a row, column or box.'
            : '$filled of $_total cells filled';

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Palette.card,
              border: Border.all(color: Palette.ink, width: 2),
              borderRadius: BorderRadius.circular(Frame.cardRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var row = 0; row < _n; row++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var col = 0; col < _n; col++)
                          Expanded(
                            child: _cell(row * _n + col, conflicts, accent),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.x3),
        _Numpad(
          n: _n,
          used: _usedCounts(),
          onDigit: _place,
        ),
        const SizedBox(height: Space.x2),
        Row(
          children: [
            Expanded(
              child: GhostButton(
                label: _notesMode ? 'Notes on' : 'Notes',
                active: _notesMode,
                onPressed: _toggleNotes,
              ),
            ),
            const SizedBox(width: Space.x2),
            Expanded(
              child: GhostButton(label: 'Erase', onPressed: _erase),
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
        const SizedBox(height: Space.x3),
        SizedBox(
          height: 20,
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: AppType.sans(14, color: Palette.ink2),
          ),
        ),
      ],
    );
  }

  List<int> _usedCounts() {
    final counts = List<int>.filled(_n + 1, 0);
    for (final value in _values) {
      if (value != 0) counts[value]++;
    }
    return counts;
  }

  Widget _cell(int index, Set<int> conflicts, GameAccent accent) {
    final value = _values[index];
    final given = _puzzle.givens[index] != 0;
    final selected = _selected == index;
    final row = index ~/ _n;
    final col = index % _n;
    final isPeer = _selected >= 0 && _layout.peers[_selected].contains(index);
    final same = !selected && value != 0 && value == _values[_selected];

    final background = _solved
        ? Palette.goodWash
        : conflicts.contains(index)
            ? Palette.badWash
            : selected || same
                ? Palette.focus
                : isPeer
                    ? Palette.peer
                    : Palette.card;

    final borders = Border(
      right: col == _n - 1
          ? BorderSide.none
          : col % _layout.boxCols == _layout.boxCols - 1
              ? const BorderSide(color: Palette.ink, width: 2)
              : const BorderSide(color: Palette.line, width: 1),
      bottom: row == _n - 1
          ? BorderSide.none
          : row % _layout.boxRows == _layout.boxRows - 1
              ? const BorderSide(color: Palette.ink, width: 2)
              : const BorderSide(color: Palette.line, width: 1),
    );

    return Pressable(
      onTap: () => _select(index),
      pressedColor: Palette.focus,
      child: Container(
        decoration: BoxDecoration(color: background, border: borders),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (value == 0)
              _NotesGrid(n: _n, mask: _notes[index])
            else
              Center(
                child: Text(
                  '$value',
                  style: AppType.serif(
                    _n == 6 ? 30 : 22,
                    weight: given ? 700 : 500,
                    height: 1,
                    color: conflicts.contains(index)
                        ? Palette.bad
                        : given
                            ? Palette.ink
                            : accent.ink,
                  ),
                ),
              ),
            if (selected)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: accent.ink, width: 2),
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
}

class _NotesGrid extends StatelessWidget {
  const _NotesGrid({required this.n, required this.mask});

  final int n;
  final int mask;

  @override
  Widget build(BuildContext context) {
    if (mask == 0) return const SizedBox.shrink();
    final rows = (n / 3).ceil();
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var row = 0; row < rows; row++)
            Expanded(
              child: Row(
                children: [
                  for (var col = 0; col < 3; col++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final digit = row * 3 + col + 1;
                          if (digit > n) return const SizedBox.shrink();
                          final on = mask & (1 << (digit - 1)) != 0;
                          return Center(
                            child: Text(
                              on ? '$digit' : '',
                              style: AppType.sans(
                                n == 6 ? 11 : 9,
                                height: 1,
                                color: Palette.ink2,
                              ),
                            ),
                          );
                        },
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

class _Numpad extends StatelessWidget {
  const _Numpad({required this.n, required this.used, required this.onDigit});

  final int n;
  final List<int> used;
  final void Function(int digit) onDigit;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: Space.x1,
      children: [
        for (var digit = 1; digit <= n; digit++)
          Expanded(
            child: Pressable(
              onTap: () => onDigit(digit),
              radius: Frame.cardRadius,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Palette.card,
                  border: Border.all(color: Palette.line, width: 1),
                  borderRadius: BorderRadius.circular(Frame.cardRadius),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$digit',
                      style: AppType.sans(20, weight: 700, height: 1),
                    ),
                    SizedBox(
                      height: 12,
                      child: Text(
                        used[digit] >= n ? '' : '${n - used[digit]}',
                        style: AppType.sans(10, height: 1, color: Palette.ink2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
