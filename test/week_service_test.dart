import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/models/enums.dart';
import 'package:reminder/services/week_service.dart';

void main() {
  final base = DateTime.utc(2026, 9, 26); // Saturday, week A

  WeekType w(DateTime d) =>
      WeekService.weekTypeFor(d, baseSaturday: base, baseType: WeekType.a);

  test('Saturday..Friday of the base week are A', () {
    for (var i = 0; i < 7; i++) {
      expect(w(DateTime.utc(2026, 9, 26 + i)), WeekType.a, reason: 'day $i');
    }
  });

  test('switches exactly at the Saturday boundary', () {
    expect(w(DateTime.utc(2026, 10, 2)), WeekType.a); // Friday
    expect(w(DateTime.utc(2026, 10, 3)), WeekType.b); // Saturday
    expect(w(DateTime.utc(2026, 10, 9)), WeekType.b); // Friday
    expect(w(DateTime.utc(2026, 10, 10)), WeekType.a); // Saturday
  });

  test('dates before the base date alternate correctly', () {
    expect(w(DateTime.utc(2026, 9, 25)), WeekType.b); // Friday before
    expect(w(DateTime.utc(2026, 9, 19)), WeekType.b); // Saturday before
    expect(w(DateTime.utc(2026, 9, 18)), WeekType.a); // two weeks before
    expect(w(DateTime.utc(2025, 1, 4)), isNotNull);
  });

  test('far dates and a B base type', () {
    // 52 weeks later -> even -> same type
    expect(w(DateTime.utc(2027, 9, 25)), WeekType.a);
    expect(
      WeekService.weekTypeFor(
        DateTime.utc(2026, 10, 5),
        baseSaturday: base,
        baseType: WeekType.b,
      ),
      WeekType.a,
    );
  });

  test('a non-Saturday base date is normalised to its Saturday', () {
    expect(
      WeekService.weekTypeFor(
        DateTime.utc(2026, 10, 3),
        baseSaturday: DateTime.utc(2026, 9, 30),
        baseType: WeekType.a,
      ),
      WeekType.b,
    );
  });

  test('local wall time with hours does not affect the result', () {
    // Calendar-based, so the time of day / timezone never matters.
    expect(w(DateTime.utc(2026, 10, 2, 23, 59)), WeekType.a);
    expect(w(DateTime.utc(2026, 10, 3, 0, 0)), WeekType.b);
    expect(w(DateTime(2026, 10, 3, 0, 30)), WeekType.b);
  });

  test('saturdayOf', () {
    expect(WeekService.saturdayOf(DateTime.utc(2026, 10, 2)), base);
    expect(WeekService.saturdayOf(base), base);
  });
}
