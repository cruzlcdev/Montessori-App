import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/app_icons.dart';
import 'package:provider/provider.dart';
import 'package:prototipo_2/academics/group_subject_screen.dart';
import 'package:prototipo_2/core/layout/responsive_layout.dart';
import 'package:prototipo_2/core/theme/colors.dart';
import 'package:prototipo_2/core/widgets/app_loading_skeleton.dart';
import 'package:prototipo_2/core/widgets/network_aware_module.dart';
import 'package:prototipo_2/features/auth/presentation/screens/unauthorized_screen.dart';
import 'package:prototipo_2/features/auth/presentation/controllers/current_user_controller.dart';
import 'package:prototipo_2/features/directory/data/models/school_group_model.dart';
import 'package:prototipo_2/features/directory/data/repositories/firestore_directory_repository.dart';
import 'package:prototipo_2/features/directory/presentation/controllers/directory_controller.dart';

class TeacherGroupsScreen extends StatefulWidget {
  const TeacherGroupsScreen({super.key});

  @override
  State<TeacherGroupsScreen> createState() => _TeacherGroupsScreenState();
}

class _TeacherGroupsScreenState extends State<TeacherGroupsScreen> {
  late final DirectoryController _controller;
  String? _loadedGroupIdsKey;

  @override
  void initState() {
    super.initState();
    _controller = DirectoryController(
      repository: FirestoreDirectoryRepository(),
    );
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final currentUser = context.watch<CurrentUserController>();
    if (currentUser.isLoading) return;

    if (!currentUser.isTeacher) {
      if (_loadedGroupIdsKey != '') {
        _loadedGroupIdsKey = '';
        _controller.loadGroupsByIds(const []);
      }
      return;
    }

    final groupIds = currentUser.user?.groupIds ?? const <String>[];
    final nextKey = _idsKey(groupIds);
    if (_loadedGroupIdsKey == nextKey) return;

    _loadedGroupIdsKey = nextKey;
    _controller.loadGroupsByIds(groupIds);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reloadGroups() async {
    final currentUser = context.read<CurrentUserController>();
    if (!currentUser.isTeacher) return;

    await _controller.loadGroupsByIds(currentUser.user?.groupIds ?? const []);
  }

  String _idsKey(List<String> ids) {
    final sortedIds = ids.toSet().toList()..sort();
    return sortedIds.join('|');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentUser = context.watch<CurrentUserController>();

    if (!currentUser.isLoading && !currentUser.isTeacher) {
      return const UnauthorizedScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Mis Grupos'),
        backgroundColor:
            isDarkMode ? AppColors.brandBlueSurface : AppColors.primaryBlue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(AppIcons.arrowBack),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: NetworkAwareModule(
        layout: AppSkeletonLayout.directory,
        child:
            currentUser.isLoading
                ? const ModuleLoadingSkeleton(
                  layout: AppSkeletonLayout.directory,
                )
                : RefreshIndicator(
                  onRefresh: _reloadGroups,
                  child: _buildBody(isDarkMode),
                ),
      ),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (_controller.isLoading) {
      return const ModuleLoadingSkeleton(layout: AppSkeletonLayout.directory);
    }

    if (_controller.errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          _StateCard(
            icon: AppIcons.errorOutlineRounded,
            title: 'No se pudieron cargar tus grupos',
            message: _controller.errorMessage!,
            isDarkMode: isDarkMode,
          ),
        ],
      );
    }

    if (_controller.groups.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          _StateCard(
            icon: AppIcons.groupsOutlined,
            title: 'Sin grupos asignados',
            message:
                'Cuando la administración te asigne un grupo, aparecerá en esta sección.',
            isDarkMode: isDarkMode,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: ResponsiveLayout.pagePadding(context, top: 20, bottom: 28),
      itemCount: _controller.groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final group = GroupInfo.fromSchoolGroup(_controller.groups[index]);
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TeacherGroupsHeader(groupCount: _controller.groups.length),
              const SizedBox(height: 18),
              _GroupCard(group: group, onTap: _navigateToGroupSubjects),
            ],
          );
        }

        return _GroupCard(group: group, onTap: _navigateToGroupSubjects);
      },
    );
  }

  void _navigateToGroupSubjects(GroupInfo group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupSubjectsScreen(group: group),
      ),
    );
  }
}

class _TeacherGroupsHeader extends StatelessWidget {
  const _TeacherGroupsHeader({required this.groupCount});

  final int groupCount;

  @override
  Widget build(BuildContext context) {
    final label = groupCount == 1 ? 'grupo asignado' : 'grupos asignados';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grupos asignados',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Selecciona un grupo para capturar evaluaciones.',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.25,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 14),
        _InfoPill(
          icon: AppIcons.groupsRounded,
          label: '$groupCount $label',
          color: AppColors.primaryBlue,
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onTap});

  final GroupInfo group;
  final void Function(GroupInfo group) onTap;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final compact = ResponsiveLayout.isCompactPhone(context);
    final iconSize = compact ? 52.0 : 58.0;
    final actionSize = compact ? 34.0 : 38.0;
    final cardRadius = ResponsiveLayout.cardRadius(context) - 2;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white10
                  : Colors.white.withValues(alpha: 0.92),
        ),
        boxShadow: _softShadows(isDarkMode),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(cardRadius),
          onTap: () => onTap(group),
          child: Padding(
            padding: EdgeInsets.all(compact ? 14 : 16),
            child: Row(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: group.color.withValues(
                      alpha: isDarkMode ? 0.22 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    group.initials.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: group.color,
                      fontSize: compact ? 16 : 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                SizedBox(width: compact ? 12 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: ResponsiveLayout.titleSize(context, 18),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _InfoPill(
                          icon: AppIcons.editNoteRounded,
                          label: 'Ver materias',
                          color: AppColors.primaryRed,
                          dense: compact,
                          showIcon: !compact,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: compact ? 8 : 10),
                Container(
                  width: actionSize,
                  height: actionSize,
                  decoration: BoxDecoration(
                    color: group.color.withValues(
                      alpha: isDarkMode ? 0.18 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    AppIcons.arrowForwardRounded,
                    color: group.color,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
    this.dense = false,
    this.showIcon = true,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool dense;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxWidth:
            MediaQuery.sizeOf(context).width -
            (ResponsiveLayout.horizontalPadding(context) * 2),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, color: color, size: dense ? 13 : 14),
            SizedBox(width: dense ? 4 : 5),
          ],
          Flexible(
            child:
                dense
                    ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : AppColors.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    )
                    : Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : AppColors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.isDarkMode,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white10
                  : Colors.white.withValues(alpha: 0.92),
        ),
        boxShadow: _softShadows(isDarkMode),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryBlue, size: 34),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GroupInfo {
  const GroupInfo({
    required this.id,
    required this.name,
    required this.initials,
    required this.colorHex,
    required this.level,
  });

  final String id;
  final String name;
  final String initials;
  final String colorHex;
  final String level;

  Color get color => _colorFromHex(colorHex);

  factory GroupInfo.fromSchoolGroup(SchoolGroupModel group) {
    return GroupInfo(
      id: group.id,
      name: group.name,
      initials: group.initials,
      colorHex: group.colorHex,
      level: group.level,
    );
  }
}

Color _colorFromHex(String value) {
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse('FF$normalized', radix: 16);
  return parsed == null ? const Color(0xFF607D8B) : Color(parsed);
}

List<BoxShadow> _softShadows(bool isDarkMode) {
  if (isDarkMode) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.24),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ];
  }

  return [
    BoxShadow(
      color: const Color(0xFFC9D8E8).withValues(alpha: 0.46),
      blurRadius: 22,
      offset: const Offset(8, 12),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.95),
      blurRadius: 18,
      offset: const Offset(-8, -10),
    ),
  ];
}
