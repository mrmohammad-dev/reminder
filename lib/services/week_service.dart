import '../models/enums.dart';
import '../models/settings.dart';
import '../util/dates.dart';

/// A/B week calculation based on local calendar dates.
///
/// Weeks start on Saturday. The number of weeks between two Saturdays is
/// computed from calendar day numbers (not elapsed milliseconds), so DST or
/// timezone changes cannot move a week boundary.
class WeekService {
  const WeekService._();

  static DateTime saturdayOf(DateTime date) {
    final d = dateOnly(date);
    return addDays(d, -dayIndexOf(d));
  }

  static WeekType weekTypeFor(
    DateTime date, {
    required DateTime baseSaturday,
    required WeekType baseType,
  }) {
    final base = saturdayOf(baseSaturday);
    final current = saturdayOf(date);
    final weeks = (epochDay(current) - epochDay(base)) ~/ 7;
    // Dart's % always returns a non-negative value for a positive divisor,
    // so dates before the base Saturday work too.
    return weeks % 2 == 0 ? baseType : baseType.other;
  }

  /// Week type for [date] using the reference week from settings.
  /// Falls back to A until the user picks a reference week.
  static WeekType forSettings(DateTime date, AppSettings settings) {
    final base = settings.baseSaturday;
    if (base == null) return WeekType.a;
    return weekTypeFor(
      date,
      baseSaturday: base,
      baseType: settings.baseWeekType,
    );
  }
}
