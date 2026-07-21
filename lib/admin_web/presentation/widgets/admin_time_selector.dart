import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../theme/admin_icons.dart';
import '../theme/admin_theme.dart';

class AdminTimeSelector extends StatelessWidget {
  const AdminTimeSelector({
    super.key,
    required this.hour,
    required this.minute,
    required this.onHourChanged,
    required this.onMinuteChanged,
    this.accentColor = AppColors.primaryBlue,
  });

  final int hour;
  final int minute;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        final hourControl = _TimeDropdown(
          key: const ValueKey('admin-hour-selector'),
          label: 'Hora',
          value: hour,
          values: List<int>.generate(24, (index) => index),
          color: accentColor,
          onChanged: onHourChanged,
        );
        final minuteControl = _TimeDropdown(
          key: const ValueKey('admin-minute-selector'),
          label: 'Minutos',
          value: minute,
          values: List<int>.generate(60, (index) => index),
          color: accentColor,
          onChanged: onMinuteChanged,
        );

        if (compact) {
          return Column(
            children: [hourControl, const SizedBox(height: 12), minuteControl],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: hourControl),
            const SizedBox(width: 12),
            Expanded(child: minuteControl),
          ],
        );
      },
    );
  }
}

class _TimeDropdown extends StatelessWidget {
  const _TimeDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> values;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: _controlDecoration(context, color),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(AdminIcons.scheduleRounded, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.adminPalette.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: context.adminPalette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<int>(
            tooltip: 'Seleccionar ${label.toLowerCase()}',
            initialValue: value,
            position: PopupMenuPosition.under,
            constraints: const BoxConstraints(
              minWidth: 156,
              maxWidth: 188,
              maxHeight: 320,
            ),
            color: context.adminPalette.surfaceElevated,
            surfaceTintColor: Colors.transparent,
            shadowColor: context.adminPalette.shadow,
            elevation: 14,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: context.adminPalette.border),
            ),
            onSelected: onChanged,
            itemBuilder:
                (context) => values
                    .map((option) {
                      final selected = option == value;
                      return PopupMenuItem<int>(
                        value: option,
                        height: 44,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                option.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  color:
                                      selected
                                          ? color
                                          : context.adminPalette.textPrimary,
                                  fontSize: 14,
                                  fontWeight:
                                      selected
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                ),
                              ),
                            ),
                            if (selected)
                              Icon(
                                AdminIcons.checkRounded,
                                color: color,
                                size: 18,
                              ),
                          ],
                        ),
                      );
                    })
                    .toList(growable: false),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                AdminIcons.keyboardArrowDownRounded,
                color: color,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _controlDecoration(BuildContext context, Color color) {
  return BoxDecoration(
    color: context.adminPalette.surfaceMuted,
    borderRadius: BorderRadius.circular(17),
    border: Border.all(color: color.withValues(alpha: 0.18)),
  );
}
