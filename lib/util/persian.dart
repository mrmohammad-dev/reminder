import 'dates.dart';

const List<String> persianDayNames = <String>[
  'شنبه',
  'یکشنبه',
  'دوشنبه',
  'سه‌شنبه',
  'چهارشنبه',
  'پنجشنبه',
  'جمعه',
];

const List<String> jalaliMonthNames = <String>[
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

const List<String> gregorianMonthNames = <String>[
  'ژانویه',
  'فوریه',
  'مارس',
  'آوریل',
  'مه',
  'ژوئن',
  'ژوئیه',
  'اوت',
  'سپتامبر',
  'اکتبر',
  'نوامبر',
  'دسامبر',
];

String faDigits(Object value) {
  const latin = '0123456789';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  final s = value.toString();
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = latin.indexOf(ch);
    b.write(i >= 0 ? persian[i] : ch);
  }
  return b.toString();
}

/// Time in 24h format with Persian digits, e.g. ۱۵:۴۵
String faTime(int minute) => faDigits(formatMinute(minute));

class JalaliDate {
  const JalaliDate(this.year, this.month, this.day);
  final int year;
  final int month;
  final int day;
}

/// Gregorian to Jalali conversion (standard arithmetic algorithm).
JalaliDate toJalali(DateTime date) {
  const gDaysInMonth = <int>[0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy = date.year;
  final gm = date.month;
  final gd = date.day;
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days = 355666 +
      (365 * gy) +
      ((gy2 + 3) ~/ 4) -
      ((gy2 + 99) ~/ 100) +
      ((gy2 + 399) ~/ 400) +
      gd +
      gDaysInMonth[gm - 1];
  var jy = -1595 + (33 * (days ~/ 12053));
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  int jm;
  int jd;
  if (days < 186) {
    jm = 1 + days ~/ 31;
    jd = 1 + (days % 31);
  } else {
    jm = 7 + ((days - 186) ~/ 30);
    jd = 1 + ((days - 186) % 30);
  }
  return JalaliDate(jy, jm, jd);
}

String formatJalali(DateTime date) {
  final j = toJalali(date);
  return '${faDigits(j.day)} ${jalaliMonthNames[j.month - 1]} ${faDigits(j.year)}';
}

String formatGregorian(DateTime date) =>
    '${faDigits(date.day)} ${gregorianMonthNames[date.month - 1]} ${faDigits(date.year)}';

String dayName(DateTime date) => persianDayNames[dayIndexOf(date)];
