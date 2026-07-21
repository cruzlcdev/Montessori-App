import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/app_icons.dart';
import 'package:provider/provider.dart';
import 'package:prototipo_2/core/theme/colors.dart';
import 'package:prototipo_2/core/widgets/app_loading_skeleton.dart';
import 'package:prototipo_2/core/widgets/network_aware_module.dart';
import 'package:prototipo_2/features/auth/presentation/controllers/current_user_controller.dart';
import 'package:prototipo_2/features/directory/data/models/school_group_model.dart';
import 'package:prototipo_2/features/directory/data/repositories/firestore_directory_repository.dart';
import 'package:prototipo_2/features/directory/presentation/controllers/directory_controller.dart';
import 'package:prototipo_2/screens/grades/group_report_cards_screen.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  late final DirectoryController _controller;
  String? _loadedAccessKey;

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

    final nextKey = _accessKey(currentUser);
    if (_loadedAccessKey == nextKey) return;
    _loadedAccessKey = nextKey;

    if (currentUser.isAdmin) {
      _controller.loadGroups();
    } else if (currentUser.isTeacher) {
      _controller.loadGroupsByIds(currentUser.user?.groupIds ?? const []);
    } else if (currentUser.isParent) {
      _controller.loadGroupsByIds(currentUser.user?.groupIds ?? const []);
    } else {
      _controller.loadGroupsByIds(const []);
    }
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
    if (currentUser.isAdmin) {
      await _controller.loadGroups();
      return;
    }

    if (currentUser.isTeacher) {
      await _controller.loadGroupsByIds(currentUser.user?.groupIds ?? const []);
      return;
    }

    if (currentUser.isParent) {
      await _controller.loadGroupsByIds(currentUser.user?.groupIds ?? const []);
      return;
    }

    await _controller.loadGroupsByIds(const []);
  }

  String _accessKey(CurrentUserController currentUser) {
    final user = currentUser.user;
    if (user == null) return 'none';

    final groupIds = user.groupIds.toSet().toList()..sort();
    final studentIds = user.studentIds.toSet().toList()..sort();
    return [
      user.uid,
      user.role,
      user.status,
      groupIds.join('|'),
      studentIds.join('|'),
    ].join('::');
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<CurrentUserController>();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(title: const Text('Boletas')),
      body: NetworkAwareModule(
        layout: AppSkeletonLayout.directory,
        child:
            currentUser.isLoading
                ? const ModuleLoadingSkeleton(
                  layout: AppSkeletonLayout.directory,
                )
                : RefreshIndicator(
                  onRefresh: _reloadGroups,
                  child: _buildBody(context, currentUser),
                ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CurrentUserController currentUser) {
    if (!currentUser.hasAppAccess) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          _buildStateCard(
            context,
            icon: AppIcons.lockOutlineRounded,
            title: 'Acceso no disponible',
            message:
                currentUser.errorMessage ??
                'No tienes permisos para consultar boletas.',
          ),
        ],
      );
    }

    if (_controller.isLoading) {
      return const ModuleLoadingSkeleton(layout: AppSkeletonLayout.directory);
    }

    if (_controller.errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          _buildStateCard(
            context,
            icon: AppIcons.errorOutlineRounded,
            title: 'No se pudieron cargar las boletas',
            message: _controller.errorMessage!,
          ),
        ],
      );
    }

    if (_controller.groups.isEmpty) {
      final message =
          currentUser.isParent
              ? 'No hay alumnos vinculados a tu cuenta para consultar boletas.'
              : 'No hay grupos disponibles para consultar boletas.';

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          _buildStateCard(
            context,
            icon: AppIcons.assignmentOutlined,
            title: 'Sin boletas disponibles',
            message: message,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      itemCount: _controller.groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final group = _controller.groups[index];
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildScreenHeader(context, currentUser),
              const SizedBox(height: 18),
              _buildGroupCard(context, group),
            ],
          );
        }

        return _buildGroupCard(context, group);
      },
    );
  }

  Widget _buildScreenHeader(
    BuildContext context,
    CurrentUserController currentUser,
  ) {
    final isTeacher = currentUser.isTeacher;
    final isParent = currentUser.isParent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isTeacher
              ? 'Grupos asignados'
              : isParent
              ? 'Boleta de tu hijo'
              : 'Boletas disponibles',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          isTeacher
              ? 'Selecciona un grupo para revisar sus boletas.'
              : isParent
              ? 'Consulta el avance académico del grupo vinculado a tu hijo.'
              : 'Selecciona el grupo vinculado para consultar la boleta.',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.25,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildGroupCard(BuildContext context, SchoolGroupModel group) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final color = _colorFromHex(group.colorHex);
    final statusLabel =
        group.status == 'active' ? 'Activo' : group.status.toUpperCase();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(22),
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
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openGroupGrades(context, group),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDarkMode ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    group.initials.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (group.level.trim().isNotEmpty)
                            _buildMetaPill(
                              context,
                              group.level,
                              AppIcons.schoolRounded,
                              color,
                            ),
                          _buildMetaPill(
                            context,
                            statusLabel,
                            AppIcons.checkCircleOutlineRounded,
                            AppColors.primaryGreen,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDarkMode ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    AppIcons.arrowForwardRounded,
                    color: color,
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

  Widget _buildStateCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF111827) : Colors.white,
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
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(
                  alpha: isDarkMode ? 0.18 : 0.10,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: AppColors.primaryBlue, size: 30),
            ),
            const SizedBox(height: 16),
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

  Widget _buildMetaPill(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: isDarkMode ? Colors.white : AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
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

  void _openGroupGrades(BuildContext context, SchoolGroupModel group) {
    final currentUser = context.read<CurrentUserController>();
    final visibleStudentIds =
        currentUser.isParent ? currentUser.user?.studentIds : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => GroupReportCardsScreen(
              groupId: group.id,
              groupName: group.name,
              visibleStudentIds: visibleStudentIds,
            ),
      ),
    );
  }
}

Color _colorFromHex(String value) {
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse('FF$normalized', radix: 16);
  return parsed == null ? AppColors.primaryBlue : Color(parsed);
}
