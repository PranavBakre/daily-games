import 'package:material_ui/material_ui.dart';

abstract final class Palette {
  static const paper = Color(0xFFF7F4EC);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF121212);
  static const ink2 = Color(0xFF5C5A55);
  static const line = Color(0xFFD9D3C5);
  static const lineSoft = Color(0xFFECE7DB);
  static const peer = Color(0xFFF3EFE5);
  static const focus = Color(0xFFE6DFCD);
  static const good = Color(0xFF2F7D32);
  static const goodWash = Color(0xFFE3F2DF);
  static const bad = Color(0xFFC0362C);
  static const badWash = Color(0xFFFBE2DF);
  static const sun = Color(0xFFD98200);
  static const moon = Color(0xFF2C5BB5);
}

/// Each game owns one flat colour, used three ways: the block behind its icon
/// and the results page, the marks drawn in it, and its filled-cell wash.
class GameAccent {
  const GameAccent(this.block, this.ink, this.wash);

  final Color block;
  final Color ink;
  final Color wash;
}

abstract final class Accents {
  static const zip = GameAccent(Color(0xFFFC8B5E), Color(0xFFC24D1C), Color(0xFFFDE4D8));
  static const tango = GameAccent(Color(0xFF8FB6F5), Color(0xFF2C5BB5), Color(0xFFE2ECFD));
  static const sudoku = GameAccent(Color(0xFF8FCF86), Color(0xFF2F7D32), Color(0xFFE3F2DF));
  static const merge = GameAccent(Color(0xFFE2B9DF), Color(0xFF70336C), Color(0xFFF5E5F4));
  static const neutral = GameAccent(Palette.ink, Palette.ink, Palette.peer);
}

abstract final class Space {
  static const x0 = 2.0;
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 24.0;
  static const x6 = 32.0;
}

abstract final class Frame {
  static const hairline = 1.0;
  static const border = 1.5;
  static const board = 2.0;
  static const cardRadius = 6.0;
  static const pillRadius = 999.0;
}

abstract final class AppType {
  static const serifFamily = 'SourceSerif4';

  static TextStyle serif(
    double size, {
    int weight = 700,
    double height = 1.1,
    double? letterSpacing,
    Color color = Palette.ink,
  }) {
    return TextStyle(
      fontFamily: serifFamily,
      fontSize: size,
      fontWeight: FontWeight.values[weight ~/ 100 - 1],
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle sans(
    double size, {
    int weight = 400,
    double height = 1.4,
    Color color = Palette.ink,
    bool tabular = false,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.values[weight ~/ 100 - 1],
      height: height,
      color: color,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );
  }
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Palette.paper,
    canvasColor: Palette.paper,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    colorScheme: const ColorScheme.light(
      primary: Palette.ink,
      onPrimary: Palette.card,
      surface: Palette.paper,
      onSurface: Palette.ink,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Palette.ink,
      selectionColor: Palette.focus,
    ),
  );
}
