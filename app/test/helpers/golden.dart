import 'dart:io';

import 'package:daily_games/src/theme.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _serifWeights = ['400', '500', '600', '700'];
const _sansFiles = ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf'];

/// Goldens need real glyphs. The serif is bundled with the app; the sans face
/// is borrowed from the Flutter SDK so the host render matches the phone's
/// system font closely enough to judge layout.
Future<void> loadGoldenFonts() async {
  final serif = FontLoader('SourceSerif4');
  for (final weight in _serifWeights) {
    serif.addFont(rootBundle.load('assets/fonts/SourceSerif4-$weight.ttf'));
  }
  await serif.load();

  final fontsDir = _materialFontsDir();
  if (fontsDir == null) return;
  final sans = FontLoader('Roboto');
  for (final file in _sansFiles) {
    final bytes = File('$fontsDir/$file').readAsBytesSync();
    sans.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await sans.load();
}

String? _materialFontsDir() {
  var directory = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 5; i++) {
    directory = directory.parent;
  }
  final path = '${directory.path}/bin/cache/artifacts/material_fonts';
  return Directory(path).existsSync() ? path : null;
}

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(fontFamily: 'Roboto'),
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> expectGolden(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}
