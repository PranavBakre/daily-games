import 'dart:convert';
import 'dart:io';

import 'package:daily_games/src/games/merge.dart';
import 'package:daily_games/src/games/sudoku.dart';
import 'package:daily_games/src/games/tango.dart';
import 'package:daily_games/src/games/zip.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> _puzzles(String game) {
  final goldens =
      jsonDecode(File('test/fixtures/goldens.json').readAsStringSync())
          as Map<String, dynamic>;
  return (goldens['puzzles'] as List)
      .cast<Map<String, dynamic>>()
      .where((entry) => entry['game'] == game)
      .toList();
}

void main() {
  group('Number Merge', () {
    test('reproduces every recorded board', () {
      for (final entry in _puzzles('merge')) {
        final expected = entry['puzzle'] as Map<String, dynamic>;
        final puzzle = generateMerge(entry['seed'] as String);
        expect(puzzle.size, expected['size'], reason: entry['seed']);
        expect(puzzle.cells, (expected['cells'] as List).cast<int>(),
            reason: entry['seed']);
      }
    });

    test('every generated board solves in seven merges', () {
      for (var i = 0; i < 50; i++) {
        final puzzle = generateMerge('merge-parity-$i');
        final solution = findMergeSolution(puzzle.cells, puzzle.size);
        expect(solution, isNotNull, reason: 'seed $i');
        expect(solution!.length, 7, reason: 'seed $i');
      }
    });
  });

  group('Tango', () {
    test('reproduces every recorded board', () {
      for (final entry in _puzzles('tango')) {
        final expected = entry['puzzle'] as Map<String, dynamic>;
        final puzzle = generateTango(
          entry['seed'] as String,
          entry['difficulty'] as String,
        );
        expect(puzzle.solution, (expected['solution'] as List).cast<int>(),
            reason: entry['seed']);
        expect(puzzle.givens, (expected['givens'] as List).cast<int>(),
            reason: entry['seed']);
        final edges = (expected['edges'] as List).cast<Map<String, dynamic>>();
        expect(puzzle.edges.length, edges.length, reason: entry['seed']);
        for (var i = 0; i < edges.length; i++) {
          expect(puzzle.edges[i].a, edges[i]['a'], reason: entry['seed']);
          expect(puzzle.edges[i].b, edges[i]['b'], reason: entry['seed']);
          expect(puzzle.edges[i].same, edges[i]['same'], reason: entry['seed']);
        }
      }
    });

    test('every recorded board has exactly one solution', () {
      for (final entry in _puzzles('tango')) {
        final expected = entry['puzzle'] as Map<String, dynamic>;
        final edges = [
          for (final edge in (expected['edges'] as List).cast<Map<String, dynamic>>())
            TangoEdge(edge['a'] as int, edge['b'] as int, edge['same'] as bool),
        ];
        final puzzle = TangoPuzzle(
          size: expected['size'] as int,
          givens: (expected['givens'] as List).cast<int>(),
          edges: edges,
          solution: (expected['solution'] as List).cast<int>(),
          difficulty: entry['difficulty'] as String,
        );
        expect(tangoCountSolutions(puzzle), 1, reason: entry['seed']);
      }
    });
  });

  group('Zip', () {
    test('reproduces every recorded board', () {
      for (final entry in _puzzles('zip')) {
        final expected = entry['puzzle'] as Map<String, dynamic>;
        final puzzle = generateZip(
          entry['seed'] as String,
          entry['difficulty'] as String,
        );
        expect(puzzle.width, expected['width'], reason: entry['seed']);
        expect(puzzle.height, expected['height'], reason: entry['seed']);
        expect(puzzle.numbers, (expected['numbers'] as List).cast<int>(),
            reason: entry['seed']);
        expect(puzzle.solution, (expected['solution'] as List).cast<int>(),
            reason: entry['seed']);
        final walls = (expected['walls'] as List).cast<List>();
        expect(puzzle.walls.length, walls.length, reason: entry['seed']);
        for (var i = 0; i < walls.length; i++) {
          expect(puzzle.walls[i], walls[i].cast<int>(),
              reason: entry['seed']);
        }
      }
    });

    test('every recorded board has exactly one solution', () {
      for (final entry in _puzzles('zip')) {
        final expected = entry['puzzle'] as Map<String, dynamic>;
        final puzzle = ZipPuzzle(
          width: expected['width'] as int,
          height: expected['height'] as int,
          numbers: (expected['numbers'] as List).cast<int>(),
          walls: [
            for (final wall in (expected['walls'] as List).cast<List>())
              wall.cast<int>(),
          ],
          solution: (expected['solution'] as List).cast<int>(),
          difficulty: entry['difficulty'] as String,
        );
        final check = zipCountSolutions(puzzle, limit: 2, budget: 2000000);
        expect(check.count, 1, reason: entry['seed']);
        expect(check.aborted, isFalse, reason: entry['seed']);
      }
    });
  });

  group('Sudoku', () {
    test('reproduces every recorded board', () {
      for (final entry in _puzzles('sudoku')) {
        final expected = entry['puzzle'] as Map<String, dynamic>;
        final puzzle = generateSudoku(
          entry['seed'] as String,
          entry['difficulty'] as String,
        );
        expect(puzzle.size, expected['size'], reason: entry['seed']);
        expect(puzzle.clues, expected['clues'], reason: entry['seed']);
        expect(puzzle.solution, (expected['solution'] as List).cast<int>(),
            reason: entry['seed']);
        expect(puzzle.givens, (expected['givens'] as List).cast<int>(),
            reason: entry['seed']);
      }
    });

    test('every recorded board has exactly one solution', () {
      for (final entry in _puzzles('sudoku')) {
        final expected = entry['puzzle'] as Map<String, dynamic>;
        final givens = (expected['givens'] as List).cast<int>();
        expect(sudokuCountSolutions(givens), 1, reason: entry['seed']);
      }
    });
  });
}
