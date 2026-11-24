/// Dates are device-local and the daily set is pinned to them, exactly as the
/// web app does, so both platforms open the same puzzle.
String dateKey([DateTime? when]) {
  final date = when ?? DateTime.now();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String previousDateKey([DateTime? when]) {
  final date = when ?? DateTime.now();
  return dateKey(DateTime(date.year, date.month, date.day - 1));
}

const _firstDay = (year: 2026, month: 11, day: 14);

int puzzleNumber([DateTime? when]) {
  final date = when ?? DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final start = DateTime(_firstDay.year, _firstDay.month, _firstDay.day);
  final days = day.difference(start).inHours / 24;
  final number = days.round() + 1;
  return number < 1 ? 1 : number;
}

class WeekDay {
  const WeekDay({required this.key, required this.date, required this.isToday});

  final String key;
  final DateTime date;
  final bool isToday;
}

/// Seven rolling days, oldest first — the strip under the masthead is not a
/// calendar week and never shows future days.
List<WeekDay> lastSevenDays([DateTime? when]) {
  final now = when ?? DateTime.now();
  return [
    for (var offset = 6; offset >= 0; offset--)
      () {
        final date = DateTime(now.year, now.month, now.day - offset);
        return WeekDay(key: dateKey(date), date: date, isToday: offset == 0);
      }(),
  ];
}

String weekdayLetter(DateTime date) {
  const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return letters[date.weekday - 1];
}

/// Rounds to the nearest second, like the web timer.
String formatTime(int milliseconds) {
  final total = milliseconds <= 0 ? 0 : (milliseconds / 1000).round();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${two(minutes)}:${two(seconds)}';
  return '$minutes:${two(seconds)}';
}

String longDate(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
}
