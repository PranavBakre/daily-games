import 'package:material_ui/material_ui.dart';

import 'src/app.dart';
import 'src/notifications.dart';
import 'src/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  final reminders = Reminders();
  await reminders.init();
  runApp(DailyGamesApp(store: store, reminders: reminders));
}
