import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'src/app.dart';
import 'src/notifications.dart';
import 'src/store.dart';
import 'src/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Palette.paper,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Palette.line,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  final store = AppStore();
  await store.load();
  final reminders = Reminders();
  await reminders.init();
  runApp(DailyGamesApp(store: store, reminders: reminders));
}
