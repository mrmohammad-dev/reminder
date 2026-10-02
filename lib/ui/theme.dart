import 'package:flutter/material.dart';

import '../models/enums.dart';

class CategoryStyle {
  const CategoryStyle(this.background, this.accent, this.icon);
  final Color background;
  final Color accent;
  final IconData icon;
}

/// Soft, distinct colors per category. Color is never the only signal:
/// the title and the category name are always shown as text.
CategoryStyle categoryStyle(ActivityCategory c) => switch (c) {
  ActivityCategory.school => const CategoryStyle(
    Color(0xFFE3F2FD),
    Color(0xFF1565C0),
    Icons.school_outlined,
  ),
  ActivityCategory.math => const CategoryStyle(
    Color(0xFFEDE7F6),
    Color(0xFF5E35B1),
    Icons.calculate_outlined,
  ),
  ActivityCategory.physics => const CategoryStyle(
    Color(0xFFE0F7FA),
    Color(0xFF00838F),
    Icons.bolt_outlined,
  ),
  ActivityCategory.chemistry => const CategoryStyle(
    Color(0xFFE8F5E9),
    Color(0xFF2E7D32),
    Icons.science_outlined,
  ),
  ActivityCategory.olympiad => const CategoryStyle(
    Color(0xFFFFF8E1),
    Color(0xFFB26A00),
    Icons.emoji_events_outlined,
  ),
  ActivityCategory.german => const CategoryStyle(
    Color(0xFFFFEBEE),
    Color(0xFFC62828),
    Icons.translate,
  ),
  ActivityCategory.english => const CategoryStyle(
    Color(0xFFFCE4EC),
    Color(0xFFAD1457),
    Icons.language,
  ),
  ActivityCategory.python => const CategoryStyle(
    Color(0xFFE8EAF6),
    Color(0xFF283593),
    Icons.code,
  ),
  ActivityCategory.gym => const CategoryStyle(
    Color(0xFFFFF3E0),
    Color(0xFFE65100),
    Icons.fitness_center,
  ),
  ActivityCategory.rest => const CategoryStyle(
    Color(0xFFF1F8E9),
    Color(0xFF558B2F),
    Icons.self_improvement,
  ),
  ActivityCategory.sleep => const CategoryStyle(
    Color(0xFFECEFF1),
    Color(0xFF455A64),
    Icons.bedtime_outlined,
  ),
  ActivityCategory.other => const CategoryStyle(
    Color(0xFFF5F5F5),
    Color(0xFF616161),
    Icons.radio_button_unchecked,
  ),
};

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4F6BED),
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Vazirmatn',
    scaffoldBackgroundColor: const Color(0xFFF8F9FC),
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}
