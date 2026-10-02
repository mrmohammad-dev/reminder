import 'package:timezone/timezone.dart' as tz;

/// Injectable clock. Returns the current wall-clock time in the schedule
/// timezone as a UTC-flagged DateTime (see util/dates.dart).
abstract class WallClock {
  DateTime now({required bool useTehran});
}

class SystemWallClock implements WallClock {
  const SystemWallClock();

  @override
  DateTime now({required bool useTehran}) {
    final DateTime t = useTehran
        ? tz.TZDateTime.now(tz.getLocation('Asia/Tehran'))
        : DateTime.now();
    return DateTime.utc(t.year, t.month, t.day, t.hour, t.minute, t.second);
  }
}

/// Fixed/adjustable clock for tests.
class FixedWallClock implements WallClock {
  FixedWallClock(this.value);
  DateTime value;

  @override
  DateTime now({required bool useTehran}) => value;
}
