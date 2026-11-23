import 'dart:convert';
import 'dart:io';

import 'package:daily_games/src/rng.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _goldens() =>
    jsonDecode(File('test/fixtures/goldens.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('hashSeed', () {
    test('matches the web FNV-1a + fmix32 implementation', () {
      final cases = (_goldens()['hashSeeds'] as List).cast<List>();
      for (final entry in cases) {
        expect(hashSeed(entry[0] as String), entry[1], reason: entry[0]);
      }
    });
  });

  group('Rng', () {
    test('replays the web stream int for int', () {
      final streams = (_goldens()['rngStreams'] as List).cast<Map>();
      for (final stream in streams) {
        final seed = stream['seed'] as String;
        final rng = Rng(seed);
        final ints = (stream['ints'] as List).cast<int>();
        expect(
          [for (var i = 0; i < ints.length; i++) rng.nextInt(1000)],
          ints,
          reason: seed,
        );
      }
    });

    test('replays the web stream double for double', () {
      final streams = (_goldens()['rngStreams'] as List).cast<Map>();
      for (final stream in streams) {
        final seed = stream['seed'] as String;
        final rng = Rng(seed);
        final floats = (stream['floats'] as List).cast<num>();
        for (var i = 0; i < floats.length; i++) {
          expect(rng.next(), floats[i], reason: '$seed at $i');
        }
      }
    });
  });
}
