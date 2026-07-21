import 'package:flutter/material.dart';

import '../theme/admin_icons.dart';

import '../../../core/theme/colors.dart';
import '../theme/admin_theme.dart';

class AdminSegmentedOption<T> {
  const AdminSegmentedOption({required this.value, required this.label});

  final T value;
  final String label;
}

class AdminSegmentedFilter<T> extends StatelessWidget {
  const AdminSegmentedFilter({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<AdminSegmentedOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.adminPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.adminPalette.borderStrong),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children:
                  options.map((option) {
                    final isSelected = option.value == selected;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _SegmentPill(
                        label: option.label,
                        isSelected: isSelected,
                        onTap: () => onChanged(option.value),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color:
                isSelected ? context.adminPalette.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  isSelected
                      ? AppColors.primaryBlue.withValues(alpha: 0.18)
                      : Colors.transparent,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.10),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                    : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                child:
                    isSelected
                        ? Padding(
                          key: ValueKey('selected'),
                          padding: EdgeInsets.only(right: 7),
                          child: Icon(
                            AdminIcons.checkRounded,
                            color: AppColors.primaryBlue,
                            size: 17,
                          ),
                        )
                        : const SizedBox.shrink(key: ValueKey('empty')),
              ),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color:
                      isSelected
                          ? AppColors.primaryBlue
                          : context.adminPalette.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
