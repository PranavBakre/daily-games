import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dates.dart';

/// The same shape the web app keeps in `localStorage`, so the rules for
/// results, streaks and saved boards can be read side by side.
class AppStore extends ChangeNotifier {
  AppStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const storageKey = 'daily-games:v1';
  static const maxSaved = 24;
  static const maxHistory = 200;

  final DateTime Function() _clock;
  SharedPreferences? _prefs;
  Map<String, dynamic> _state = _emptyState();

  static Map<String, dynamic> _emptyState() => {
    'results': <String, dynamic>{},
    'best': <String, dynamic>{},
    'streaks': <String, dynamic>{},
    'saved': <String, dynamic>{},
    'history': <dynamic>[],
    'prefs': <String, dynamic>{},
  };

  Map<String, dynamic> get state => _state;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(storageKey);
    if (raw == null) return;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) {
        _state = {..._emptyState(), ...parsed};
      }
    } on FormatException {
      _state = _emptyState();
    }
  }

  void _persist() {
    _prefs?.setString(storageKey, jsonEncode(_state));
  }

  Map<String, dynamic> _map(String bucket, String game) {
    final root = _state[bucket];
    if (root is! Map) {
      final fresh = <String, dynamic>{};
      _state[bucket] = fresh;
      return fresh;
    }
    final entry = root[game];
    if (entry is Map) return entry.cast<String, dynamic>();
    final fresh = <String, dynamic>{};
    root[game] = fresh;
    return fresh;
  }

  ({int ms, String difficulty, int at})? result(String game, String key) {
    final results = _state['results'];
    if (results is! Map) return null;
    final entry = (results[game] as Map?)?[key];
    if (entry is! Map) return null;
    return (
      ms: (entry['ms'] as num?)?.toInt() ?? 0,
      difficulty: entry['difficulty'] as String? ?? '',
      at: (entry['at'] as num?)?.toInt() ?? 0,
    );
  }

  bool solvedToday(String game) => result(game, dateKey()) != null;

  int solvedTodayCount() => gamesSolvedOn(dateKey());

  int gamesSolvedOn(String key) =>
      [for (final game in const ['zip', 'tango', 'sudoku', 'merge'])
        if (result(game, key) != null) game].length;

  /// Distinct result keys, which includes practice seeds — this is the
  /// results screen's "Played" number.
  int solvedCount(String game) {
    final results = _state['results'];
    if (results is! Map) return 0;
    final map = results[game];
    return map is Map ? map.length : 0;
  }

  int? best(String game, String difficulty) {
    final bests = _state['best'];
    if (bests is! Map) return null;
    final map = bests[game];
    if (map is! Map) return null;
    return (map[difficulty] as num?)?.toInt();
  }

  ({int count, String? last}) streak(String game) {
    final streaks = _state['streaks'];
    final entry = streaks is Map ? streaks[game] : null;
    if (entry is! Map) return (count: 0, last: null);
    return (
      count: (entry['count'] as num?)?.toInt() ?? 0,
      last: entry['last'] as String?,
    );
  }

  /// A streak that broke displays as 0 without touching storage.
  int liveStreak(String game) {
    final saved = streak(game);
    final today = dateKey(_clock());
    final yesterday = previousDateKey(_clock());
    return saved.last == today || saved.last == yesterday ? saved.count : 0;
  }

  void saveResult({
    required String game,
    required String key,
    required String mode,
    required String difficulty,
    required int ms,
  }) {
    final results = _map('results', game);
    final previous = results[key];
    final previousMs = previous is Map ? (previous['ms'] as num?)?.toInt() : null;
    results[key] = {
      'ms': previousMs != null && previousMs < ms ? previousMs : ms,
      'difficulty': difficulty,
      'at': (previous is Map ? (previous['at'] as num?)?.toInt() : null) ??
          _clock().millisecondsSinceEpoch,
    };

    final bests = _map('best', game);
    final currentBest = (bests[difficulty] as num?)?.toInt();
    if (currentBest == null || ms < currentBest) bests[difficulty] = ms;

    if (mode == 'daily') {
      final streaks = _map('streaks', game);
      final last = streaks['last'] as String?;
      if (last != key) {
        final count = (streaks['count'] as num?)?.toInt() ?? 0;
        streaks['count'] = last == previousDateKey(_clock()) ? count + 1 : 1;
        streaks['last'] = key;
      }
      final history = _state['history'];
      if (history is List) {
        history.insert(0, {
          'game': game,
          'key': key,
          'mode': mode,
          'difficulty': difficulty,
          'ms': ms,
          'at': _clock().millisecondsSinceEpoch,
        });
        if (history.length > maxHistory) history.removeRange(maxHistory, history.length);
      }
    }

    _persist();
    notifyListeners();
  }

  String sessionId(String game, String mode, String key) => '$game:$mode:$key';

  ({Map<String, dynamic> data, int elapsed})? loadSession(String id) {
    final saved = _state['saved'];
    if (saved is! Map) return null;
    final entry = saved[id];
    if (entry is! Map) return null;
    final data = entry['data'];
    if (data is! Map) return null;
    return (
      data: data.cast<String, dynamic>(),
      elapsed: (entry['elapsed'] as num?)?.toInt() ?? 0,
    );
  }

  void saveSession(String id, Map<String, dynamic> data, int elapsed) {
    final saved = _state['saved'];
    if (saved is! Map) return;
    saved[id] = {
      'data': data,
      'elapsed': elapsed,
      'at': _clock().millisecondsSinceEpoch,
    };
    if (saved.length > maxSaved) {
      final entries = saved.entries.toList()
        ..sort((a, b) {
          final left = (a.value is Map ? (a.value as Map)['at'] as num? : null) ?? 0;
          final right = (b.value is Map ? (b.value as Map)['at'] as num? : null) ?? 0;
          return left.compareTo(right);
        });
      for (final entry in entries.take(entries.length - maxSaved)) {
        saved.remove(entry.key);
      }
    }
    _persist();
  }

  void clearSession(String id) {
    final saved = _state['saved'];
    if (saved is! Map) return;
    saved.remove(id);
    _persist();
  }

  T pref<T>(String name, T fallback) {
    final prefs = _state['prefs'];
    final value = prefs is Map ? prefs[name] : null;
    return value is T ? value : fallback;
  }

  void setPref(String name, Object? value) {
    final prefs = _state['prefs'];
    if (prefs is! Map) return;
    if (value == null) {
      prefs.remove(name);
    } else {
      prefs[name] = value;
    }
    _persist();
    notifyListeners();
  }

  bool howToSeen(String game) => pref('howto-$game', false);

  void markHowToSeen(String game) => setPref('howto-$game', true);
}
