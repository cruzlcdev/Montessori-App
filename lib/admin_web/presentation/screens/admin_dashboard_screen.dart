import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/admin_icons.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../theme/admin_theme.dart';
import '../../../features/auth/data/models/app_user.dart';
import '../../data/admin_dashboard_repository.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _repository = AdminDashboardRepository();

  late final Stream<AdminMetricSnapshot> _studentsMetric;
  late final Stream<AdminMetricSnapshot> _teachersMetric;
  late final Stream<AdminMetricSnapshot> _familiesMetric;
  late final Stream<AdminMetricSnapshot> _newsMetric;
  late final Stream<AdminMetricSnapshot> _eventsMetric;

  @override
  void initState() {
    super.initState();
    _studentsMetric = _repository.activeMetric('students');
    _teachersMetric = _repository.activeMetric('teachers');
    _familiesMetric = _repository.activeFamiliesMetric();
    _newsMetric = _repository.publishedMetric('news');
    _eventsMetric = _repository.upcomingEventsMetric();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.adminPalette.canvas,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 28, 32, 18),
                child: _DashboardHeader(user: widget.user),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 18),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final columns = switch (constraints.crossAxisExtent) {
                    >= 1080 => 4,
                    >= 620 => 2,
                    _ => 1,
                  };
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: 194,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildListDelegate.fixed([
                      _MetricCard(
                        title: 'Alumnos activos',
                        description: 'Participación estudiantil',
                        stream: _studentsMetric,
                        icon: AdminIcons.faceRounded,
                        color: AppColors.primaryBlue,
                      ),
                      _MetricCard(
                        title: 'Profesores activos',
                        description: 'Equipo docente disponible',
                        stream: _teachersMetric,
                        icon: AdminIcons.coPresentRounded,
                        color: AppColors.primaryGreen,
                      ),
                      _MetricCard(
                        title: 'Noticias publicadas',
                        description: 'Comunicados visibles',
                        stream: _newsMetric,
                        icon: AdminIcons.campaignRounded,
                        color: AppColors.primaryOrange,
                      ),
                      _MetricCard(
                        title: 'Eventos próximos',
                        description: 'Agenda escolar vigente',
                        stream: _eventsMetric,
                        icon: AdminIcons.calendarMonthRounded,
                        color: AppColors.primaryTurquoise,
                      ),
                    ]),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 18),
                child: _ResponsiveDashboardPair(
                  first: _CommunityHealthPanel(
                    students: _studentsMetric,
                    teachers: _teachersMetric,
                    families: _familiesMetric,
                  ),
                  second: _PublishingHealthPanel(
                    news: _newsMetric,
                    events: _eventsMetric,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: _ResponsiveDashboardPair(
                  first: _ActivityPanel(
                    title: 'Noticias recientes',
                    subtitle: 'Últimos comunicados de la comunidad',
                    icon: AdminIcons.campaignRounded,
                    color: AppColors.primaryOrange,
                    emptyTitle: 'Sin noticias recientes',
                    emptyText:
                        'Los comunicados publicados aparecerán en este espacio.',
                    stream: _repository.recentNews(),
                  ),
                  second: _ActivityPanel(
                    title: 'Próximos eventos',
                    subtitle: 'Agenda institucional por venir',
                    icon: AdminIcons.eventRounded,
                    color: AppColors.primaryTurquoise,
                    emptyTitle: 'Agenda sin eventos próximos',
                    emptyText:
                        'Cuando se publique un evento futuro podrás consultarlo aquí.',
                    stream: _repository.upcomingEvents(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat(
      "EEEE, d 'de' MMMM",
      'es_MX',
    ).format(DateTime.now());
    final date = formattedDate[0].toUpperCase() + formattedDate.substring(1);
    final firstName = user.name.trim().split(RegExp(r'\s+')).firstOrNull;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 24, 24),
      decoration: _dashboardPanelDecoration(context, AppColors.primaryBlue),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _HeaderPill(
                      icon: AdminIcons.calendarTodayRounded,
                      label: date,
                      color: AppColors.primaryBlue,
                    ),
                    const _HeaderPill(
                      icon: AdminIcons.cloudDoneRounded,
                      label: 'Datos en tiempo real',
                      color: AppColors.primaryGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  firstName == null || firstName.isEmpty
                      ? 'Resumen administrativo'
                      : 'Hola, $firstName',
                  style: TextStyle(
                    color: context.adminPalette.textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Consulta la operación escolar y detecta rápidamente dónde requiere atención.',
                  style: TextStyle(
                    color: context.adminPalette.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: context.adminPalette.surfaceMuted,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.12),
              ),
            ),
            child: Icon(
              AdminIcons.insightsRounded,
              color: AppColors.primaryBlue,
              size: 42,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.description,
    required this.stream,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final Stream<AdminMetricSnapshot> stream;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminMetricSnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        final metric = snapshot.data;
        final percentage = metric?.percentage ?? 0;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: _dashboardPanelDecoration(context, color, radius: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      metric == null || metric.total == 0
                          ? 'Sin datos'
                          : '$percentage%',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    metric?.value.toString() ?? '-',
                    style: TextStyle(
                      color: context.adminPalette.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      metric == null ? '' : 'de ${metric.total}',
                      style: TextStyle(
                        color: context.adminPalette.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.adminPalette.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.adminPalette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _ProgressTrack(value: metric?.ratio ?? 0, color: color),
            ],
          ),
        );
      },
    );
  }
}

class _ResponsiveDashboardPair extends StatelessWidget {
  const _ResponsiveDashboardPair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              SizedBox(height: 340, child: first),
              const SizedBox(height: 16),
              SizedBox(height: 340, child: second),
            ],
          );
        }
        return SizedBox(
          height: 340,
          child: Row(
            children: [
              Expanded(child: first),
              const SizedBox(width: 16),
              Expanded(child: second),
            ],
          ),
        );
      },
    );
  }
}

class _CommunityHealthPanel extends StatelessWidget {
  const _CommunityHealthPanel({
    required this.students,
    required this.teachers,
    required this.families,
  });

  final Stream<AdminMetricSnapshot> students;
  final Stream<AdminMetricSnapshot> teachers;
  final Stream<AdminMetricSnapshot> families;

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      icon: AdminIcons.groupsRounded,
      color: AppColors.primaryBlue,
      title: 'Pulso de la comunidad',
      subtitle: 'Perfiles activos por tipo de usuario',
      child: StreamBuilder<AdminMetricSnapshot>(
        stream: students,
        builder:
            (context, studentsSnapshot) => StreamBuilder<AdminMetricSnapshot>(
              stream: teachers,
              builder:
                  (context, teachersSnapshot) =>
                      StreamBuilder<AdminMetricSnapshot>(
                        stream: families,
                        builder: (context, familiesSnapshot) {
                          return Row(
                            children: [
                              Expanded(
                                child: _RingMetric(
                                  label: 'Alumnos',
                                  metric: studentsSnapshot.data,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                              const _VerticalPanelDivider(),
                              Expanded(
                                child: _RingMetric(
                                  label: 'Profesores',
                                  metric: teachersSnapshot.data,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                              const _VerticalPanelDivider(),
                              Expanded(
                                child: _RingMetric(
                                  label: 'Familias',
                                  metric: familiesSnapshot.data,
                                  color: AppColors.primaryTurquoise,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
            ),
      ),
    );
  }
}

class _PublishingHealthPanel extends StatelessWidget {
  const _PublishingHealthPanel({required this.news, required this.events});

  final Stream<AdminMetricSnapshot> news;
  final Stream<AdminMetricSnapshot> events;

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      icon: AdminIcons.autoGraphRounded,
      color: AppColors.primaryOrange,
      title: 'Cobertura institucional',
      subtitle: 'Visibilidad de comunicados y agenda',
      child: StreamBuilder<AdminMetricSnapshot>(
        stream: news,
        builder:
            (context, newsSnapshot) => StreamBuilder<AdminMetricSnapshot>(
              stream: events,
              builder: (context, eventsSnapshot) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CoverageRow(
                      icon: AdminIcons.campaignRounded,
                      title: 'Noticias visibles',
                      metric: newsSnapshot.data,
                      color: AppColors.primaryOrange,
                    ),
                    const SizedBox(height: 24),
                    _CoverageRow(
                      icon: AdminIcons.eventAvailableRounded,
                      title: 'Agenda futura',
                      metric: eventsSnapshot.data,
                      color: AppColors.primaryTurquoise,
                    ),
                  ],
                );
              },
            ),
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _dashboardPanelDecoration(context, color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: icon,
            color: color,
            title: title,
            subtitle: subtitle,
          ),
          const SizedBox(height: 18),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: color, size: 23),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.adminPalette.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.adminPalette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RingMetric extends StatelessWidget {
  const _RingMetric({
    required this.label,
    required this.metric,
    required this.color,
  });

  final String label;
  final AdminMetricSnapshot? metric;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = metric?.ratio ?? 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 92,
          height: 92,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder:
                (context, value, _) => CustomPaint(
                  painter: _RingPainter(
                    value: value,
                    color: color,
                    backgroundColor: context.adminPalette.border,
                  ),
                  child: Center(
                    child: Text(
                      metric == null || metric!.total == 0
                          ? '--'
                          : '${(value * 100).round()}%',
                      style: TextStyle(
                        color: context.adminPalette.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
          ),
        ),
        const SizedBox(height: 11),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.adminPalette.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          metric == null ? 'Cargando' : '${metric!.value} de ${metric!.total}',
          style: TextStyle(
            color: context.adminPalette.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.backgroundColor,
  });

  final double value;
  final Color color;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 7;
    final backgroundPaint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round;
    final foregroundPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);
    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        foregroundPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class _VerticalPanelDivider extends StatelessWidget {
  const _VerticalPanelDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 126, color: context.adminPalette.border);
  }
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({
    required this.icon,
    required this.title,
    required this.metric,
    required this.color,
  });

  final IconData icon;
  final String title;
  final AdminMetricSnapshot? metric;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percentage = metric?.percentage ?? 0;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: context.adminPalette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    metric == null || metric!.total == 0
                        ? 'Sin datos'
                        : '$percentage%',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ProgressTrack(value: metric?.ratio ?? 0, color: color),
              const SizedBox(height: 6),
              Text(
                metric == null
                    ? 'Actualizando información'
                    : '${metric!.value} de ${metric!.total} registros visibles',
                style: TextStyle(
                  color: context.adminPalette.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder:
            (context, animatedValue, _) => LinearProgressIndicator(
              value: animatedValue,
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation(color),
            ),
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.emptyTitle,
    required this.emptyText,
    required this.stream,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String emptyTitle;
  final String emptyText;
  final Stream<List<AdminActivityItem>> stream;

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      icon: icon,
      color: color,
      title: title,
      subtitle: subtitle,
      child: StreamBuilder<List<AdminActivityItem>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return _EmptyActivityState(
              title: emptyTitle,
              message: emptyText,
              icon: icon,
              color: color,
            );
          }

          return ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 9),
            itemBuilder: (context, index) {
              return _ActivityTile(item: items[index], color: color);
            },
          );
        },
      ),
    );
  }
}

class _EmptyActivityState extends StatelessWidget {
  const _EmptyActivityState({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.adminPalette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.adminPalette.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item, required this.color});

  final AdminActivityItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: context.adminPalette.surfaceElevated,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: context.adminPalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(AdminIcons.arrowOutwardRounded, color: color, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.adminPalette.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.subtitle} · ${DateFormat('d MMM', 'es_MX').format(item.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.adminPalette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusPill(status: item.status),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final published = status == 'published';
    final color = published ? AppColors.primaryGreen : AppColors.primaryOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        published ? 'Publicado' : status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

BoxDecoration _dashboardPanelDecoration(
  BuildContext context,
  Color color, {
  double radius = 30,
}) {
  return BoxDecoration(
    color: context.adminPalette.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: context.adminPalette.border),
    boxShadow: [
      BoxShadow(
        color: color.withValues(alpha: 0.065),
        blurRadius: 26,
        offset: const Offset(0, 14),
      ),
    ],
  );
}

extension _FirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
