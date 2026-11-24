import 'package:material_ui/material_ui.dart';

import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import 'pressable.dart';

Future<void> showReminderSheet(
  BuildContext context, {
  required AppStore store,
  required Reminders reminders,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Palette.paper,
    barrierColor: Palette.ink.withValues(alpha: 0.4),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      side: BorderSide(color: Palette.ink, width: 2),
      borderRadius: BorderRadius.vertical(top: Radius.circular(Frame.cardRadius)),
    ),
    builder: (context) => _ReminderSheet(store: store, reminders: reminders),
  );
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({required this.store, required this.reminders});

  final AppStore store;
  final Reminders reminders;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late bool _enabled = widget.store.pref('reminderEnabled', false);
  late int _hour = widget.store.pref('reminderHour', 9);
  late int _minute = widget.store.pref('reminderMinute', 0);
  String? _note;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked == null) return;
    setState(() {
      _hour = picked.hour;
      _minute = picked.minute;
    });
    if (_enabled) await _schedule();
  }

  Future<void> _schedule() async {
    final granted = await widget.reminders.requestPermission();
    if (!granted) {
      setState(() {
        _enabled = false;
        _note = 'Notifications are off for Daily Games in Settings.';
      });
      widget.store.setPref('reminderEnabled', false);
      await widget.reminders.cancel();
      return;
    }
    await widget.reminders.scheduleDaily(_hour, _minute);
    widget.store.setPref('reminderEnabled', true);
    widget.store.setPref('reminderHour', _hour);
    widget.store.setPref('reminderMinute', _minute);
    if (mounted) {
      setState(() => _note = 'Reminder set.');
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() {
      _enabled = value;
      _note = null;
    });
    if (value) {
      await _schedule();
    } else {
      await widget.reminders.cancel();
      widget.store.setPref('reminderEnabled', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay(hour: _hour, minute: _minute));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.x4, Space.x5, Space.x4, Space.x5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Daily reminder', style: AppType.serif(28, height: 1.1)),
            const SizedBox(height: Space.x2),
            Text(
              'One notification a day, scheduled on this device. It works offline and needs no account.',
              style: AppType.sans(14, color: Palette.ink2),
            ),
            const SizedBox(height: Space.x4),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Palette.line, width: 1),
                borderRadius: BorderRadius.circular(Frame.cardRadius),
              ),
              child: Column(
                children: [
                  Pressable(
                    onTap: () => _toggle(!_enabled),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.x4,
                        vertical: Space.x2,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Remind me every day',
                              style: AppType.sans(14, weight: 600),
                            ),
                          ),
                          Switch(
                            value: _enabled,
                            activeThumbColor: Palette.card,
                            activeTrackColor: Palette.ink,
                            onChanged: _toggle,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(height: 1, color: Palette.line),
                  Pressable(
                    onTap: _pickTime,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.x4,
                        vertical: Space.x3,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Time', style: AppType.sans(14)),
                          ),
                          Text(
                            label,
                            style: AppType.sans(
                              14,
                              weight: 600,
                              tabular: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_note != null) ...[
              const SizedBox(height: Space.x3),
              Text(_note!, style: AppType.sans(12, color: Palette.ink2)),
            ],
            const SizedBox(height: Space.x5),
            PillButton(
              label: 'Done',
              primary: true,
              fullWidth: true,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}
