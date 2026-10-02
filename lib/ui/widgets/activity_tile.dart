import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../services/schedule_service.dart';
import '../theme.dart';
import 'badge_chip.dart';

class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.instance,
    required this.now,
    this.onToggle,
    this.showCheckbox = true,
    this.isCurrent = false,
    this.showStatus = true,
  });

  final DayInstance instance;
  final DateTime now;
  final ValueChanged<bool>? onToggle;
  final bool showCheckbox;
  final bool isCurrent;

  /// Week templates (no concrete date) hide overdue/progress badges.
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final a = instance.activity;
    final style = categoryStyle(a.category);
    final theme = Theme.of(context);
    final overdue = showStatus && ScheduleService.isOverdue(instance, now);
    final note = a.scheduleNote;
    final timeText = instance.timeLabel;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: style.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCurrent ? style.accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onToggle == null ? null : () => onToggle!(!instance.done),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (showCheckbox)
                Semantics(
                  label: instance.done ? 'انجام شده' : 'انجام نشده',
                  child: Checkbox(
                    value: instance.done,
                    onChanged: onToggle == null
                        ? null
                        : (v) => onToggle!(v ?? false),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(style.icon, color: style.accent),
                ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      a.title,
                      softWrap: true,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: instance.done
                            ? theme.colorScheme.onSurface.withAlpha(150)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (timeText != note)
                      Text(
                        timeText,
                        softWrap: true,
                        style: theme.textTheme.bodyMedium,
                      ),
                    if (note != null)
                      Text(
                        note,
                        softWrap: true,
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        BadgeChip(
                          a.category.label,
                          color: style.accent,
                          icon: style.icon,
                        ),
                        if (a.weekType != WeekType.both)
                          BadgeChip(a.weekType.shortLabel),
                        if (showStatus && instance.done)
                          const BadgeChip(
                            'انجام شد',
                            color: Color(0xFF2E7D32),
                            icon: Icons.check,
                          ),
                        if (isCurrent && !instance.done)
                          BadgeChip(
                            'در حال انجام',
                            color: style.accent,
                            icon: Icons.play_arrow,
                          ),
                        if (overdue)
                          const BadgeChip(
                            'عقب‌افتاده',
                            color: Color(0xFFC62828),
                            icon: Icons.schedule,
                          ),
                        if (instance.needsSetup)
                          const BadgeChip(
                            'نیازمند تنظیم ساعت شروع',
                            color: Color(0xFF8D6E63),
                            icon: Icons.tune,
                          ),
                        if (instance.conflict)
                          const BadgeChip(
                            'تداخل زمانی',
                            color: Color(0xFFD84315),
                            icon: Icons.warning_amber,
                          ),
                        if (!a.reminderEnabled)
                          const BadgeChip(
                            'یادآور خاموش',
                            color: Color(0xFF757575),
                            icon: Icons.notifications_off_outlined,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
