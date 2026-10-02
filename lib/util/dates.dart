/// Date helpers.
///
/// Convention used across the app:
/// * A "date" is a date-only value created with `DateTime.utc(y, m, d)`.
/// * A "wall" value is `DateTime.utc(y, m, d, h, min)` holding the local
///   wall-clock time in the schedule timezone (device or Asia/Tehran).
///
/// Using UTC-flagged values for pure calendar math means daylight saving
/// time or a timezone change can never shift a day or a week boundary.
library;

DateTime dateOnly(DateTime t) => DateTime.utc(t.year, t.month, t.day);

DateTime addDays(DateTime date, int days) =>
    DateTime.utc(date.year, date.month, date.day + days);

/// Number of calendar days since 1970-01-01 for a date.
int epochDay(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

String two(int v) => v.toString().padLeft(2, '0');

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}';

final RegExp _dateKeyPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

bool isValidDateKey(String key) {
  final m = _dateKeyPattern.firstMatch(key);
  if (m == null) return false;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final dt = DateTime.utc(y, mo, d);
  return dt.year == y && dt.month == mo && dt.day == d;
}

DateTime parseDateKey(String key) {
  if (!isValidDateKey(key)) {
    throw FormatException('Invalid date key: $key');
  }
  final p = key.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// 0 = Saturday (شنبه) ... 6 = Friday (جمعه).
int dayIndexOf(DateTime date) => (date.weekday + 1) % 7;

DateTime atMinute(DateTime date, int minuteOfDay) => DateTime.utc(
  date.year,
  date.month,
  date.day,
  minuteOfDay ~/ 60,
  minuteOfDay % 60,
);

int minuteOfDay(DateTime wall) => wall.hour * 60 + wall.minute;

String formatMinute(int minute) => '${two(minute ~/ 60)}:${two(minute % 60)}';

final RegExp _hm = RegExp(r'^(\d{1,2}):(\d{2})$');

int? parseHm(String text) {
  final m = _hm.firstMatch(text.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

bool isValidMinute(int? m) => m == null || (m >= 0 && m < 24 * 60);
