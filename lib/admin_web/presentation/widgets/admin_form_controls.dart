import 'package:flutter/material.dart';

import '../theme/admin_icons.dart';

import '../../../core/theme/colors.dart';
import '../theme/admin_theme.dart';
import '../../../features/directory/data/models/school_group_model.dart';

const String _closeGroupMenuValue = '__close_group_menu__';

class AdminGroupSelectField extends StatelessWidget {
  const AdminGroupSelectField({
    super.key,
    required this.groups,
    required this.selectedGroupId,
    required this.onChanged,
    this.includeAllOption = false,
    this.allLabel = 'Todos los grupos',
    this.emptyLabel = 'Selecciona un grupo',
  });

  final List<SchoolGroupModel> groups;
  final String selectedGroupId;
  final ValueChanged<String> onChanged;
  final bool includeAllOption;
  final String allLabel;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final selectedGroup = _selectedGroup;
    final selectedAll = includeAllOption && selectedGroupId == 'all';
    final label = selectedAll ? allLabel : selectedGroup?.name ?? emptyLabel;
    final color =
        selectedAll || selectedGroup == null
            ? AppColors.primaryBlue
            : _parseColor(selectedGroup.colorHex);

    return PopupMenuButton<String>(
      tooltip: 'Seleccionar grupo',
      color: context.adminPalette.surfaceElevated,
      elevation: 16,
      offset: const Offset(0, 12),
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      onSelected: (value) {
        if (value == _closeGroupMenuValue) return;
        onChanged(value);
      },
      itemBuilder:
          (context) => [
            PopupMenuItem(
              value: _closeGroupMenuValue,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Seleccionar grupo',
                      style: TextStyle(
                        color: context.adminPalette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: context.adminPalette.surfaceMuted,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      AdminIcons.closeRounded,
                      color: context.adminPalette.textSecondary,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            if (includeAllOption)
              PopupMenuItem(
                value: 'all',
                child: _GroupSelectMenuItem(
                  icon: AdminIcons.groupsRounded,
                  label: allLabel,
                  color: AppColors.primaryBlue,
                  selected: selectedAll,
                ),
              ),
            ...groups.map(
              (group) => PopupMenuItem(
                value: group.id,
                child: _GroupSelectMenuItem(
                  initials: group.initials,
                  label: group.name,
                  color: _parseColor(group.colorHex),
                  selected: selectedGroupId == group.id,
                ),
              ),
            ),
          ],
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  selectedGroup == null
                      ? Icon(AdminIcons.groupsRounded, color: color, size: 18)
                      : Text(
                        selectedGroup.initials,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.adminPalette.textPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              AdminIcons.keyboardArrowDownRounded,
              color: context.adminPalette.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  SchoolGroupModel? get _selectedGroup {
    for (final group in groups) {
      if (group.id == selectedGroupId) return group;
    }
    return null;
  }
}

class _GroupSelectMenuItem extends StatelessWidget {
  const _GroupSelectMenuItem({
    required this.label,
    required this.color,
    required this.selected,
    this.icon,
    this.initials,
  });

  final String label;
  final Color color;
  final bool selected;
  final IconData? icon;
  final String? initials;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                icon != null
                    ? Icon(icon, color: color, size: 18)
                    : Text(
                      initials ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.adminPalette.textPrimary,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          if (selected) Icon(AdminIcons.checkRounded, color: color, size: 20),
        ],
      ),
    );
  }
}

class AdminDeleteConfirmDialog extends StatefulWidget {
  const AdminDeleteConfirmDialog({
    super.key,
    required this.title,
    required this.itemName,
    required this.message,
    required this.actionLabel,
  });

  final String title;
  final String itemName;
  final String message;
  final String actionLabel;

  @override
  State<AdminDeleteConfirmDialog> createState() =>
      _AdminDeleteConfirmDialogState();
}

class _AdminDeleteConfirmDialogState extends State<AdminDeleteConfirmDialog> {
  final _controller = TextEditingController();

  bool get _canDelete => _controller.text.trim().toUpperCase() == 'ELIMINAR';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.adminPalette.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: context.adminPalette.border),
          boxShadow: [
            BoxShadow(
              color: context.adminPalette.textPrimary.withValues(alpha: 0.16),
              blurRadius: 34,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    AdminIcons.deleteOutlineRounded,
                    color: AppColors.primaryRed,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: context.adminPalette.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.adminPalette.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context, false),
                  icon: Icon(AdminIcons.closeRounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primaryRed.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    AdminIcons.warningAmberRounded,
                    color: AppColors.primaryRed,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: context.adminPalette.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Para confirmar escribe ELIMINAR',
              style: TextStyle(
                color: context.adminPalette.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'ELIMINAR',
                hintStyle: TextStyle(
                  color: context.adminPalette.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
                prefixIcon: Icon(
                  AdminIcons.keyboardRounded,
                  color: AppColors.primaryBlue,
                ),
                filled: true,
                fillColor: context.adminPalette.inputFill,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: context.adminPalette.borderStrong,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: AppColors.primaryBlue,
                    width: 1.4,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 130,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      foregroundColor: context.adminPalette.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primaryRed.withValues(
                        alpha: 0.28,
                      ),
                      disabledForegroundColor: Colors.white.withValues(
                        alpha: 0.70,
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed:
                        _canDelete ? () => Navigator.pop(context, true) : null,
                    icon: Icon(AdminIcons.deleteOutlineRounded),
                    label: Text(widget.actionLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AdminStatusSwitch extends StatelessWidget {
  const AdminStatusSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    required this.activeSubtitle,
    required this.inactiveSubtitle,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String activeSubtitle;
  final String inactiveSubtitle;

  @override
  Widget build(BuildContext context) {
    final color = value ? AppColors.primaryGreen : AppColors.primaryOrange;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: value ? 0.08 : 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: value ? 0.22 : 0.24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.adminPalette.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value ? activeSubtitle : inactiveSubtitle,
                  style: TextStyle(
                    color: context.adminPalette.textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppColors.primaryGreen,
            activeTrackColor: AppColors.primaryGreen.withValues(alpha: 0.25),
            inactiveThumbColor: AppColors.primaryOrange,
            inactiveTrackColor: AppColors.primaryOrange.withValues(alpha: 0.20),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

Color _parseColor(String value) {
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse('FF$normalized', radix: 16);
  if (parsed == null) return AppColors.primaryBlue;
  return Color(parsed);
}
