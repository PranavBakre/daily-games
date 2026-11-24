import 'theme.dart';

class GameDifficulty {
  const GameDifficulty(this.id, this.label);

  final String id;
  final String label;
}

class GameInfo {
  const GameInfo({
    required this.id,
    required this.name,
    required this.tagline,
    required this.rules,
    required this.defaultDifficulty,
    required this.difficulties,
    required this.accent,
  });

  final String id;
  final String name;
  final String tagline;
  final List<String> rules;
  final String defaultDifficulty;
  final List<GameDifficulty> difficulties;
  final GameAccent accent;

  String labelFor(String difficultyId) => difficulties
      .firstWhere(
        (difficulty) => difficulty.id == difficultyId,
        orElse: () => difficulties.first,
      )
      .label;

  bool hasDifficulty(String id) =>
      difficulties.any((difficulty) => difficulty.id == id);
}

const _standardDifficulties = [
  GameDifficulty('easy', 'Easy'),
  GameDifficulty('medium', 'Medium'),
  GameDifficulty('hard', 'Hard'),
];

const zipGame = GameInfo(
  id: 'zip',
  name: 'Zip',
  tagline: 'Draw one line through every cell.',
  rules: [
    'Draw one line from 1 to the highest number, through every cell once.',
    'Pass the numbers in order. Walls block the line.',
    'Drag back over the line to undo. Hint shows the next few cells.',
  ],
  defaultDifficulty: 'medium',
  difficulties: _standardDifficulties,
  accent: Accents.zip,
);

const tangoGame = GameInfo(
  id: 'tango',
  name: 'Tango',
  tagline: 'Fill the grid with suns and moons.',
  rules: [
    'Each row and column holds three suns and three moons.',
    'No more than two of the same symbol side by side.',
    'Cells joined by = match; cells joined by × differ.',
  ],
  defaultDifficulty: 'medium',
  difficulties: _standardDifficulties,
  accent: Accents.tango,
);

const sudokuGame = GameInfo(
  id: 'sudoku',
  name: 'Sudoku',
  tagline: 'Fill every row, column and box.',
  rules: [
    'Fill every row, column and box with each number once.',
    'Tap a cell, then a number. Notes pencils in candidates.',
    'Hint points out a wrong number, or fills one cell for you.',
  ],
  defaultDifficulty: 'mini',
  difficulties: [
    GameDifficulty('mini', 'Mini 6×6'),
    GameDifficulty('easy', 'Easy'),
    GameDifficulty('medium', 'Medium'),
    GameDifficulty('hard', 'Hard'),
  ],
  accent: Accents.sudoku,
);

const mergeGame = GameInfo(
  id: 'merge',
  name: 'Number Merge',
  tagline: 'Join matching numbers until one tile remains.',
  rules: [
    'Drag a number onto an equal number that shares an edge.',
    'The sum lands on the second tile. The first tile becomes empty.',
    'Keep merging until one tile remains. Use Undo if you get stuck.',
  ],
  defaultDifficulty: 'classic',
  difficulties: [GameDifficulty('classic', 'Classic')],
  accent: Accents.merge,
);

const games = [zipGame, tangoGame, sudokuGame, mergeGame];

GameInfo gameById(String id) =>
    games.firstWhere((game) => game.id == id, orElse: () => zipGame);
