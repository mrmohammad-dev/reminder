/// Which week an activity template applies to.
enum WeekType { both, a, b }

extension WeekTypeText on WeekType {
  String get label => switch (this) {
    WeekType.both => 'هر دو هفته',
    WeekType.a => 'فقط هفته A',
    WeekType.b => 'فقط هفته B',
  };

  String get shortLabel => switch (this) {
    WeekType.both => 'A و B',
    WeekType.a => 'هفته A',
    WeekType.b => 'هفته B',
  };

  WeekType get other => switch (this) {
    WeekType.a => WeekType.b,
    WeekType.b => WeekType.a,
    WeekType.both => WeekType.both,
  };
}

WeekType weekTypeFromName(String name) {
  for (final w in WeekType.values) {
    if (w.name == name) return w;
  }
  throw FormatException('Unknown week type: $name');
}

enum ActivityCategory {
  school,
  math,
  physics,
  chemistry,
  olympiad,
  german,
  english,
  python,
  gym,
  rest,
  sleep,
  other,
}

extension ActivityCategoryText on ActivityCategory {
  String get label => switch (this) {
    ActivityCategory.school => 'مدرسه',
    ActivityCategory.math => 'ریاضی',
    ActivityCategory.physics => 'فیزیک',
    ActivityCategory.chemistry => 'شیمی',
    ActivityCategory.olympiad => 'المپیاد',
    ActivityCategory.german => 'آلمانی',
    ActivityCategory.english => 'انگلیسی',
    ActivityCategory.python => 'پایتون',
    ActivityCategory.gym => 'باشگاه',
    ActivityCategory.rest => 'استراحت',
    ActivityCategory.sleep => 'خواب',
    ActivityCategory.other => 'سایر',
  };
}

ActivityCategory categoryFromName(String name) {
  for (final c in ActivityCategory.values) {
    if (c.name == name) return c;
  }
  throw FormatException('Unknown category: $name');
}
