import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/app_icons.dart';
import 'package:provider/provider.dart';
import 'package:prototipo_2/academics/subject_evaluations.screen.dart';
import 'package:prototipo_2/core/theme/colors.dart';
import 'package:prototipo_2/core/widgets/app_loading_skeleton.dart';
import 'package:prototipo_2/core/widgets/network_aware_module.dart';
import 'package:prototipo_2/features/auth/presentation/controllers/current_user_controller.dart';
import 'package:prototipo_2/features/auth/presentation/screens/unauthorized_screen.dart';
import 'package:prototipo_2/features/academics/data/models/subject_model.dart';
import 'package:prototipo_2/features/academics/data/repositories/firestore_academic_repository.dart';
import 'package:prototipo_2/features/academics/presentation/controllers/academic_controller.dart';
import 'package:prototipo_2/screens/teacher_group_screen.dart';

class GroupSubjectsScreen extends StatefulWidget {
  const GroupSubjectsScreen({super.key, required this.group});

  final GroupInfo group;

  @override
  State<GroupSubjectsScreen> createState() => _GroupSubjectsScreenState();
}

class _GroupSubjectsScreenState extends State<GroupSubjectsScreen> {
  late final AcademicController _controller;
  bool _didLoadSubjects = false;

  @override
  void initState() {
    super.initState();
    _controller = AcademicController(repository: FirestoreAcademicRepository());
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadSubjects) return;

    final currentUser = context.watch<CurrentUserController>();
    if (currentUser.isLoading) return;
    if (!_canAccessEvaluations(currentUser)) return;

    _didLoadSubjects = true;
    _controller.loadSubjectsByGroup(widget.group.id);
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentUser = context.watch<CurrentUserController>();

    if (currentUser.isLoading) {
      return const Scaffold(
        body: ModuleLoadingSkeleton(layout: AppSkeletonLayout.academic),
      );
    }

    if (!_canAccessEvaluations(currentUser)) {
      return const UnauthorizedScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Materias'),
        backgroundColor:
            isDarkMode ? AppColors.brandBlueSurface : AppColors.primaryBlue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(AppIcons.arrowBack),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: NetworkAwareModule(
        layout: AppSkeletonLayout.academic,
        child: RefreshIndicator(
          onRefresh: () => _controller.loadSubjectsByGroup(widget.group.id),
          child: _buildBody(isDarkMode),
        ),
      ),
    );
  }

  bool _canAccessEvaluations(CurrentUserController currentUser) {
    final user = currentUser.user;
    return currentUser.isTeacher == true &&
        user != null &&
        user.groupIds.contains(widget.group.id);
  }

  Widget _buildBody(bool isDarkMode) {
    if (_controller.isLoading) {
      return const ModuleLoadingSkeleton(layout: AppSkeletonLayout.academic);
    }

    if (_controller.errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          _StateCard(
            icon: AppIcons.errorOutlineRounded,
            title: 'No se pudieron cargar las materias',
            message: _controller.errorMessage!,
            isDarkMode: isDarkMode,
          ),
        ],
      );
    }

    if (_controller.subjects.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          _StateCard(
            icon: AppIcons.menuBookOutlined,
            title: 'Sin materias asignadas',
            message:
                'Cuando este grupo tenga materias vinculadas, aparecerán aquí.',
            isDarkMode: isDarkMode,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      itemCount: _controller.subjects.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final subject = _controller.subjects[index];
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SubjectsHeader(
                group: widget.group,
                subjectCount: _controller.subjects.length,
              ),
              const SizedBox(height: 18),
              _SubjectCard(
                group: widget.group,
                subject: subject,
                onTap: _navigateToEvaluations,
              ),
            ],
          );
        }

        return _SubjectCard(
          group: widget.group,
          subject: subject,
          onTap: _navigateToEvaluations,
        );
      },
    );
  }

  void _navigateToEvaluations(SubjectModel subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                SubjectEvaluationsScreen(group: widget.group, subject: subject),
      ),
    );
  }
}

class _SubjectsHeader extends StatelessWidget {
  const _SubjectsHeader({required this.group, required this.subjectCount});

  final GroupInfo group;
  final int subjectCount;

  @override
  Widget build(BuildContext context) {
    final label = subjectCount == 1 ? 'materia' : 'materias';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Materias del grupo',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Selecciona una materia para evaluar alumnos.',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.25,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _InfoPill(
              icon: AppIcons.groupsRounded,
              label: group.name,
              color: group.color,
            ),
            _InfoPill(
              icon: AppIcons.menuBookRounded,
              label: '$subjectCount $label',
              color: AppColors.primaryBlue,
            ),
          ],
        ),
      ],
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.group,
    required this.subject,
    required this.onTap,
  });

  final GroupInfo group;
  final SubjectModel subject;
  final void Function(SubjectModel subject) onTap;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final subjectColor =
        subject.isQualitative ? AppColors.primaryOrange : AppColors.primaryBlue;

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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => onTap(subject),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: subjectColor.withValues(
                      alpha: isDarkMode ? 0.20 : 0.11,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _getSubjectIcon(subject),
                    color: subjectColor,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
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
                          _InfoPill(
                            icon: AppIcons.editRounded,
                            label: 'Evaluar',
                            color: AppColors.primaryRed,
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
                    color: subjectColor.withValues(
                      alpha: isDarkMode ? 0.18 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    AppIcons.arrowForwardRounded,
                    color: subjectColor,
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

  IconData _getSubjectIcon(SubjectModel subject) {
    final iconName = subject.iconName?.toLowerCase();
    final subjectName = subject.name.toLowerCase();

    if (iconName == 'language' || subjectName.contains('lenguaje')) {
      return AppIcons.language;
    }
    if (iconName == 'calculate' || subjectName.contains('matemática')) {
      return AppIcons.calculate;
    }
    if (iconName == 'science' || subjectName.contains('ciencia')) {
      return AppIcons.science;
    }
    if (iconName == 'history' || subjectName.contains('historia')) {
      return AppIcons.history;
    }
    if (iconName == 'sensorial' || subjectName.contains('sensorial')) {
      return AppIcons.colorLens;
    }
    if (iconName == 'home' || subjectName.contains('vida práctica')) {
      return AppIcons.home;
    }

    return AppIcons.book;
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 48,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
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
