// The web generators are pinned to this PRNG, so every daily puzzle must come
// out identical on both platforms. All arithmetic is kept as an unsigned 32-bit
// value; the bit patterns are what the parity tests compare.

import 'dart:math' as math;

const int _mask = 0xFFFFFFFF;
const int _goldenGamma = 0x9E3779B9;
const String _digits = '0123456789abcdefghijklmnopqrstuvwxyz';

int _u32(int value) => value & _mask;

/// Low 32 bits of a 32-bit multiply. Dart's int is 64-bit, and 2^32 divides
/// 2^64, so the wrap preserves the low bits.
int _mul32(int a, int b) => (a * b) & _mask;

int hashSeed(String text) {
  var h = 2166136261;
  for (var i = 0; i < text.length; i++) {
    h = _u32(h ^ text.codeUnitAt(i));
    h = _mul32(h, 16777619);
  }
  h = _u32(h ^ (h >> 16));
  h = _mul32(h, 2246822507);
  h = _u32(h ^ (h >> 13));
  h = _mul32(h, 3266489909);
  return _u32(h ^ (h >> 16));
}

/// mulberry32, the generator the web app pins its daily puzzles to.
class Rng {
  Rng(Object seed) : state = _initialState(seed);

  int state;

  static int _initialState(Object seed) {
    final value = switch (seed) {
      int v => _u32(v),
      _ => hashSeed(seed.toString()),
    };
    return value == 0 ? _goldenGamma : value;
  }

  double next() {
    state = _u32(state + 0x6D2B79F5);
    var t = state;
    t = _mul32(t ^ (t >> 15), t | 1);
    t = _u32(t ^ _u32(t + _mul32(t ^ (t >> 7), t | 61)));
    return _u32(t ^ (t >> 14)) / 4294967296;
  }

  int nextInt(int n) => (next() * n).floor();

  bool chance(double p) => next() < p;

  T pick<T>(List<T> list) => list[nextInt(list.length)];

  List<T> shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
    return list;
  }
}

/// Practice seeds mirror the web shape: six base-36 characters plus the low
/// three digits of the clock, so two taps never collide.
String randomSeed() {
  final random = math.Random();
  final head = String.fromCharCodes(
    List.generate(6, (_) => _digits.codeUnitAt(random.nextInt(36))),
  );
  final clock = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  return head + clock.substring(clock.length - 3);
}
