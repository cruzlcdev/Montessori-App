import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/admin_icons.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../theme/admin_theme.dart';
import '../../../features/directory/data/models/school_group_model.dart';
import '../../../features/news/data/models/news_model.dart';
import '../../data/admin_news_repository.dart';
import '../widgets/admin_time_selector.dart';
import '../widgets/admin_segmented_filter.dart';
import '../widgets/admin_feedback.dart';

void _showAdminToast(
  BuildContext context,
  String title, {
  required String message,
  IconData icon = AdminIcons.checkCircleRounded,
  Color color = AppColors.primaryGreen,
}) {
  showAdminFeedback(
    context,
    title: title,
    message: message,
    icon: icon,
    color: color,
  );
}

class AdminNewsScreen extends StatefulWidget {
  const AdminNewsScreen({super.key});

  @override
  State<AdminNewsScreen> createState() => _AdminNewsScreenState();
}

class _AdminNewsScreenState extends State<AdminNewsScreen> {
  final _repository = AdminNewsRepository();
  String _statusFilter = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<SchoolGroupModel>>(
        stream: _repository.watchActiveGroups(),
        builder: (context, groupsSnapshot) {
          final groups = groupsSnapshot.data ?? const <SchoolGroupModel>[];

          return StreamBuilder<List<NewsModel>>(
            stream: _repository.watchNews(),
            builder: (context, newsSnapshot) {
              final allNews = newsSnapshot.data ?? const <NewsModel>[];
              final visibleNews = _filterNews(allNews);

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(34, 30, 34, 20),
                      child: _NewsHeader(
                        totalCount: allNews.length,
                        publishedCount:
                            allNews
                                .where((news) => news.status == 'published')
                                .length,
                        archivedCount:
                            allNews
                                .where((news) => news.status == 'archived')
                                .length,
                        onCreate: () => _openForm(groups: groups),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(34, 0, 34, 18),
                      child: _NewsToolbar(
                        selectedStatus: _statusFilter,
                        onStatusChanged:
                            (value) => setState(() => _statusFilter = value),
                        onQueryChanged:
                            (value) => setState(() => _query = value),
                      ),
                    ),
                  ),
                  if (newsSnapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (visibleNews.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyNewsState(
                        onCreate: () => _openForm(groups: groups),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(34, 0, 34, 34),
                      sliver: SliverList.separated(
                        itemCount: visibleNews.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final news = visibleNews[index];
                          return _NewsAdminCard(
                            news: news,
                            groups: groups,
                            onEdit: () => _openForm(news: news, groups: groups),
                            onArchive: () => _confirmArchive(news),
                            onPublish: () => _publishNews(news),
                            onDelete: () => _confirmDelete(news),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<NewsModel> _filterNews(List<NewsModel> news) {
    final normalizedQuery = _query.trim().toLowerCase();
    return news
        .where((item) {
          final statusMatches =
              _statusFilter == 'all' || item.status == _statusFilter;
          final queryMatches =
              normalizedQuery.isEmpty ||
              item.title.toLowerCase().contains(normalizedQuery) ||
              item.content.toLowerCase().contains(normalizedQuery);

          return statusMatches && queryMatches;
        })
        .toList(growable: false);
  }

  Future<void> _openForm({
    NewsModel? news,
    required List<SchoolGroupModel> groups,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _NewsFormSheet(
          repository: _repository,
          news: news,
          groups: groups,
        );
      },
    );

    if (saved == true && mounted) {
      _showSnack(
        news == null ? 'Noticia publicada' : 'Noticia actualizada',
        news == null
            ? 'El comunicado quedó visible para la audiencia seleccionada y se actualizará en la app en tiempo real.'
            : 'El contenido, la audiencia y la vigencia quedaron guardados y se reflejarán en la app.',
      );
    }
  }

  Future<void> _confirmArchive(NewsModel news) async {
    final confirmed = await _confirm(
      title: 'Archivar noticia',
      message: 'La noticia dejará de mostrarse para padres y profesores.',
      actionLabel: 'Archivar',
    );

    if (!confirmed) return;
    await _repository.archiveNews(news);
    if (mounted) {
      _showSnack(
        'Noticia archivada',
        'El comunicado dejó de mostrarse para padres y profesores, pero permanece disponible en Archivadas.',
        icon: AdminIcons.archiveRounded,
        color: AppColors.primaryOrange,
      );
    }
  }

  Future<void> _publishNews(NewsModel news) async {
    await _repository.publishNews(news);
    if (mounted) {
      _showSnack(
        'Noticia publicada nuevamente',
        'El comunicado volvió a estar visible para su audiencia y se sincronizará con la app.',
      );
    }
  }

  Future<void> _confirmDelete(NewsModel news) async {
    final confirmed = await _confirm(
      title: 'Eliminar noticia',
      message:
          'Esta acción eliminará la noticia y sus copias por grupo. No se recomienda usarlo salvo pruebas o errores.',
      actionLabel: 'Eliminar',
      destructive: true,
    );

    if (!confirmed) return;
    await _repository.deleteNews(news);
    if (mounted) {
      _showSnack(
        'Noticia eliminada',
        'El comunicado y sus copias por grupo se retiraron definitivamente del panel y de la app.',
        icon: AdminIcons.deleteOutlineRounded,
        color: AppColors.primaryRed,
      );
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String actionLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      destructive
                          ? AppColors.primaryRed
                          : AppColors.primaryBlue,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(actionLabel),
              ),
            ],
          ),
    );

    return result == true;
  }

  void _showSnack(
    String title,
    String message, {
    IconData icon = AdminIcons.checkCircleRounded,
    Color color = AppColors.primaryGreen,
  }) {
    _showAdminToast(context, title, message: message, icon: icon, color: color);
  }
}

class _NewsHeader extends StatelessWidget {
  const _NewsHeader({
    required this.totalCount,
    required this.publishedCount,
    required this.archivedCount,
    required this.onCreate,
  });

  final int totalCount;
  final int publishedCount;
  final int archivedCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: context.adminPalette.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: context.adminPalette.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.primaryYellow.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              AdminIcons.campaignRounded,
              color: AppColors.primaryOrange,
              size: 34,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Noticias',
                  style: TextStyle(
                    color: context.adminPalette.textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$publishedCount publicadas · $archivedCount archivadas · $totalCount totales',
                  style: TextStyle(
                    color: context.adminPalette.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onCreate,
            icon: Icon(AdminIcons.addRounded),
            label: Text('Nueva noticia'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 19),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsToolbar extends StatelessWidget {
  const _NewsToolbar({
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.onQueryChanged,
  });

  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.adminPalette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.adminPalette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Buscar por título o contenido',
                prefixIcon: Icon(AdminIcons.searchRounded),
                filled: true,
                fillColor: context.adminPalette.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          AdminSegmentedFilter<String>(
            options: const [
              AdminSegmentedOption(value: 'all', label: 'Todas'),
              AdminSegmentedOption(value: 'published', label: 'Publicadas'),
              AdminSegmentedOption(value: 'archived', label: 'Archivadas'),
            ],
            selected: selectedStatus,
            onChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _NewsAdminCard extends StatelessWidget {
  const _NewsAdminCard({
    required this.news,
    required this.groups,
    required this.onEdit,
    required this.onArchive,
    required this.onPublish,
    required this.onDelete,
  });

  final NewsModel news;
  final List<SchoolGroupModel> groups;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onPublish;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isArchived = news.status == 'archived';
    final accent =
        isArchived ? context.adminPalette.textMuted : AppColors.primaryBlue;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.adminPalette.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: context.adminPalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(AdminIcons.campaignRounded, color: accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusPill(status: news.status),
                    _InfoPill(
                      icon: AdminIcons.groupsRounded,
                      label: _audienceLabel(news, groups),
                      color: AppColors.primaryTurquoise,
                    ),
                    _InfoPill(
                      icon: AdminIcons.calendarMonthRounded,
                      label: DateFormat(
                        'd MMM y',
                        'es_MX',
                      ).format(news.publishedAt),
                      color: AppColors.primaryOrange,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  news.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.adminPalette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  news.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.adminPalette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Wrap(
            spacing: 8,
            children: [
              _IconAction(
                tooltip: 'Editar',
                icon: AdminIcons.editRounded,
                color: AppColors.primaryBlue,
                onTap: onEdit,
              ),
              _IconAction(
                tooltip: isArchived ? 'Publicar' : 'Archivar',
                icon:
                    isArchived
                        ? AdminIcons.uploadRounded
                        : AdminIcons.archiveRounded,
                color: AppColors.primaryBlue,
                onTap: isArchived ? onPublish : onArchive,
              ),
              _IconAction(
                tooltip: 'Eliminar',
                icon: AdminIcons.deleteOutlineRounded,
                color: AppColors.primaryRed,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _audienceLabel(NewsModel news, List<SchoolGroupModel> groups) {
    if (news.targetGroupIds.contains('all')) return 'Toda la escuela';
    if (news.targetGroupIds.length == 1) {
      final group = groups.where(
        (group) => group.id == news.targetGroupIds.first,
      );
      return group.isEmpty ? '1 grupo' : group.first.name;
    }
    return '${news.targetGroupIds.length} grupos';
  }
}

class _NewsFormSheet extends StatefulWidget {
  const _NewsFormSheet({
    required this.repository,
    required this.groups,
    this.news,
  });

  final AdminNewsRepository repository;
  final List<SchoolGroupModel> groups;
  final NewsModel? news;

  @override
  State<_NewsFormSheet> createState() => _NewsFormSheetState();
}

class _NewsFormSheetState extends State<_NewsFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final FocusNode _titleFocusNode;
  late final FocusNode _contentFocusNode;
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final Set<String> _selectedGroupIds;
  late bool _wholeSchool;
  DateTime? _expirationDate;
  TimeOfDay? _expirationTime;
  bool _isSaving = false;

  bool get _isEditing => widget.news != null;

  DateTime? get _expirationDateTime {
    final date = _expirationDate;
    final time = _expirationTime;
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  void initState() {
    super.initState();
    final news = widget.news;
    _titleFocusNode = FocusNode()..addListener(_handleFocusChange);
    _contentFocusNode = FocusNode()..addListener(_handleFocusChange);
    _titleController = TextEditingController(text: news?.title ?? '');
    _contentController = TextEditingController(text: news?.content ?? '');
    _wholeSchool = news == null || news.targetGroupIds.contains('all');
    _selectedGroupIds =
        news == null
            ? <String>{}
            : news.targetGroupIds.where((id) => id != 'all').toSet();
    final expiresAt = news?.expiresAt;
    _expirationDate = expiresAt;
    _expirationTime =
        expiresAt == null
            ? null
            : TimeOfDay(hour: expiresAt.hour, minute: expiresAt.minute);
  }

  @override
  void dispose() {
    _titleFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _contentFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_expirationDate == null) {
      _showLocalError('Selecciona la fecha de finalización.');
      return;
    }

    if (_expirationTime == null) {
      _showLocalError('Selecciona la hora de finalización.');
      return;
    }

    final expiresAt = _expirationDateTime!;

    if (!expiresAt.isAfter(DateTime.now())) {
      _showLocalError(
        'La fecha y hora de finalización deben ser posteriores al momento actual.',
      );
      return;
    }

    final targetGroupIds =
        _wholeSchool
            ? const ['all']
            : _selectedGroupIds.toList(growable: false);

    if (targetGroupIds.isEmpty) {
      _showLocalError('Selecciona toda la escuela o al menos un grupo.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        await widget.repository.updateNews(
          news: widget.news!,
          title: _titleController.text,
          content: _contentController.text,
          targetGroupIds: targetGroupIds,
          expiresAt: expiresAt,
        );
      } else {
        final user = FirebaseAuth.instance.currentUser;
        await widget.repository.createNews(
          title: _titleController.text,
          content: _contentController.text,
          targetGroupIds: targetGroupIds,
          authorId: user?.uid ?? '',
          authorName: user?.displayName ?? user?.email ?? 'Administrador',
          authorEmail: user?.email,
          expiresAt: expiresAt,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        _showLocalError('No se pudo guardar la noticia: $error');
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickExpirationDate() async {
    final now = DateTime.now();
    final currentDate = _expirationDate;
    final selectedDate = await showDialog<DateTime>(
      context: context,
      builder:
          (context) => _ExpirationDatePickerDialog(
            initialDate:
                currentDate != null &&
                        !currentDate.isBefore(
                          DateTime(now.year, now.month, now.day),
                        )
                    ? currentDate
                    : now,
            minDate: DateTime(now.year, now.month, now.day),
            maxDate: DateTime(now.year + 2),
          ),
    );

    if (selectedDate == null || !mounted) return;

    setState(() => _expirationDate = selectedDate);
  }

  Future<void> _pickExpirationTime() async {
    final currentTime =
        _expirationTime ?? const TimeOfDay(hour: 23, minute: 59);
    final selectedTime = await showDialog<TimeOfDay>(
      context: context,
      builder:
          (context) => _ExpirationTimePickerDialog(initialTime: currentTime),
    );

    if (selectedTime == null || !mounted) return;

    setState(() => _expirationTime = selectedTime);
  }

  void _showLocalError(String message) {
    _showAdminToast(
      context,
      'No se pudo guardar la noticia',
      message: message,
      icon: AdminIcons.errorOutlineRounded,
      color: AppColors.primaryRed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 620,
          height: MediaQuery.sizeOf(context).height,
          decoration: BoxDecoration(
            color: context.adminPalette.surface,
            borderRadius: BorderRadius.horizontal(left: Radius.circular(32)),
          ),
          child: SafeArea(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 22, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            AdminIcons.campaignRounded,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _isEditing ? 'Editar noticia' : 'Nueva noticia',
                            style: TextStyle(
                              color: context.adminPalette.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context, false),
                          icon: Icon(AdminIcons.closeRounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(28, 12, 28, 26),
                      children: [
                        _FormBlock(
                          icon: AdminIcons.editNoteRounded,
                          title: 'Contenido del comunicado',
                          subtitle:
                              'Redacta un título claro y un mensaje breve para la comunidad.',
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _titleController,
                                focusNode: _titleFocusNode,
                                maxLength: 120,
                                decoration: _inputDecoration(
                                  hint: 'Título',
                                  icon: AdminIcons.titleRounded,
                                  hideHint: _titleFocusNode.hasFocus,
                                ),
                                validator: (value) {
                                  final title = value?.trim() ?? '';
                                  if (title.isEmpty) return 'Ingresa un título';
                                  if (title.length > 120) {
                                    return 'Máximo 120 caracteres';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _contentController,
                                focusNode: _contentFocusNode,
                                minLines: 7,
                                maxLines: 11,
                                maxLength: 5000,
                                decoration: _inputDecoration(
                                  hint: 'Contenido',
                                  hideHint: _contentFocusNode.hasFocus,
                                ),
                                validator: (value) {
                                  final content = value?.trim() ?? '';
                                  if (content.isEmpty) {
                                    return 'Ingresa el contenido';
                                  }
                                  if (content.length > 5000) {
                                    return 'Máximo 5000 caracteres';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _FormBlock(
                          icon: AdminIcons.groupsRounded,
                          title: 'Audiencia',
                          subtitle:
                              'Define quién podrá ver la noticia desde la app.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                value: _wholeSchool,
                                onChanged:
                                    (value) =>
                                        setState(() => _wholeSchool = value),
                                title: Text(
                                  'Toda la escuela',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                                subtitle: Text(
                                  'Visible para todos los usuarios activos.',
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                tileColor: context.adminPalette.surfaceMuted,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    color: context.adminPalette.border,
                                  ),
                                ),
                              ),
                              if (!_wholeSchool) ...[
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children:
                                      widget.groups.map((group) {
                                        final selected = _selectedGroupIds
                                            .contains(group.id);
                                        return FilterChip(
                                          selected: selected,
                                          label: Text(group.name),
                                          avatar: CircleAvatar(
                                            backgroundColor: _parseColor(
                                              group.colorHex,
                                            ),
                                            child: Text(
                                              group.initials,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          onSelected: (value) {
                                            setState(() {
                                              if (value) {
                                                _selectedGroupIds.add(group.id);
                                              } else {
                                                _selectedGroupIds.remove(
                                                  group.id,
                                                );
                                              }
                                            });
                                          },
                                        );
                                      }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _FormBlock(
                          icon: AdminIcons.scheduleRounded,
                          title: 'Fecha y hora de finalización',
                          subtitle:
                              'Obligatoria. Al finalizar, dejará de mostrarse en la app.',
                          child: _ExpirationScheduleSelector(
                            date: _expirationDate,
                            time: _expirationTime,
                            onPickDate: _pickExpirationDate,
                            onPickTime: _pickExpirationTime,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(28, 18, 28, 24),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: context.adminPalette.border),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 150,
                          child: TextButton(
                            onPressed:
                                _isSaving
                                    ? null
                                    : () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  context.adminPalette.textSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 190,
                          child: FilledButton(
                            onPressed: _isSaving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child:
                                _isSaving
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                    : Text(
                                      _isEditing
                                          ? 'Guardar cambios'
                                          : 'Publicar',
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    IconData? icon,
    bool hideHint = false,
  }) {
    return InputDecoration(
      hintText: hideHint ? null : hint,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      prefixIcon:
          icon == null ? null : Icon(icon, color: AppColors.primaryBlue),
      hintStyle: TextStyle(
        color: context.adminPalette.textSecondary,
        fontWeight: FontWeight.w700,
      ),
      filled: true,
      fillColor: context.adminPalette.inputFill,
      contentPadding: EdgeInsets.fromLTRB(icon == null ? 18 : 0, 18, 18, 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: context.adminPalette.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: context.adminPalette.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5),
      ),
    );
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    final value = int.tryParse(
      clean.length == 6 ? 'FF$clean' : clean,
      radix: 16,
    );
    return value == null ? AppColors.primaryBlue : Color(value);
  }
}

class _ExpirationScheduleSelector extends StatelessWidget {
  const _ExpirationScheduleSelector({
    required this.date,
    required this.time,
    required this.onPickDate,
    required this.onPickTime,
  });

  final DateTime? date;
  final TimeOfDay? time;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final dateCard = _ExpirationPartCard(
      icon: AdminIcons.calendarMonthRounded,
      label: 'Fecha de finalización',
      value:
          date == null
              ? 'Seleccionar fecha'
              : DateFormat('EEEE d MMMM', 'es_MX').format(date!),
      helper:
          date == null
              ? 'Define el último día visible.'
              : 'Puedes cambiarla sin modificar la hora.',
      selected: date != null,
      onTap: onPickDate,
    );
    final timeCard = _ExpirationPartCard(
      icon: AdminIcons.scheduleRounded,
      label: 'Hora de finalización',
      value: time == null ? 'Seleccionar hora' : _formatTime(time!),
      helper:
          time == null
              ? 'Indica el momento exacto de cierre.'
              : 'La noticia se ocultará automáticamente.',
      selected: time != null,
      onTap: onPickTime,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 470) {
          return Column(
            children: [dateCard, const SizedBox(height: 12), timeCard],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: dateCard),
            const SizedBox(width: 12),
            Expanded(child: timeCard),
          ],
        );
      },
    );
  }
}

class _ExpirationPartCard extends StatelessWidget {
  const _ExpirationPartCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String helper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color:
                selected
                    ? AppColors.primaryBlue.withValues(alpha: 0.07)
                    : context.adminPalette.inputFill,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color:
                  selected
                      ? AppColors.primaryBlue.withValues(alpha: 0.24)
                      : context.adminPalette.borderStrong,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      selected
                          ? AppColors.primaryBlue.withValues(alpha: 0.12)
                          : context.adminPalette.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primaryBlue, size: 21),
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
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.adminPalette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      helper,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.adminPalette.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                AdminIcons.chevronRightRounded,
                color: AppColors.primaryBlue,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpirationDatePickerDialog extends StatefulWidget {
  const _ExpirationDatePickerDialog({
    required this.initialDate,
    required this.minDate,
    required this.maxDate,
  });

  final DateTime initialDate;
  final DateTime minDate;
  final DateTime maxDate;

  @override
  State<_ExpirationDatePickerDialog> createState() =>
      _ExpirationDatePickerDialogState();
}

class _ExpirationDatePickerDialogState
    extends State<_ExpirationDatePickerDialog> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.adminPalette.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: context.adminPalette.border),
            boxShadow: [
              BoxShadow(
                color: context.adminPalette.shadow.withValues(alpha: 0.28),
                blurRadius: 38,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PickerHeader(
                  icon: AdminIcons.calendarMonthRounded,
                  title: 'Fecha de finalización',
                  subtitle: 'Selecciona el último día visible de la noticia.',
                ),
                const SizedBox(height: 20),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.adminPalette.surfaceMuted,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: context.adminPalette.border),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: AppColors.primaryBlue,
                        onPrimary: Colors.white,
                        surface: context.adminPalette.surfaceMuted,
                        onSurface: context.adminPalette.textPrimary,
                      ),
                    ),
                    child: CalendarDatePicker(
                      initialDate: _selectedDate,
                      firstDate: widget.minDate,
                      lastDate: widget.maxDate,
                      onDateChanged:
                          (date) => setState(() => _selectedDate = date),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _PickerActions(
                  confirmLabel: 'Aplicar fecha',
                  onConfirm: () => Navigator.pop(context, _selectedDate),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpirationTimePickerDialog extends StatefulWidget {
  const _ExpirationTimePickerDialog({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_ExpirationTimePickerDialog> createState() =>
      _ExpirationTimePickerDialogState();
}

class _ExpirationTimePickerDialogState
    extends State<_ExpirationTimePickerDialog> {
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
  }

  @override
  Widget build(BuildContext context) {
    final selectedTime = TimeOfDay(hour: _hour, minute: _minute);

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.adminPalette.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: context.adminPalette.border),
            boxShadow: [
              BoxShadow(
                color: context.adminPalette.shadow.withValues(alpha: 0.28),
                blurRadius: 38,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PickerHeader(
                  icon: AdminIcons.scheduleRounded,
                  title: 'Hora de finalización',
                  subtitle: 'Define el momento exacto en formato de 24 horas.',
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'La noticia finalizará a las',
                        style: TextStyle(
                          color: context.adminPalette.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(selectedTime),
                        style: TextStyle(
                          color: AppColors.adaptiveBlue(context),
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AdminTimeSelector(
                  hour: _hour,
                  minute: _minute,
                  onHourChanged: (value) => setState(() => _hour = value),
                  onMinuteChanged: (value) => setState(() => _minute = value),
                ),
                const SizedBox(height: 22),
                _PickerActions(
                  confirmLabel: 'Aplicar hora',
                  onConfirm: () => Navigator.pop(context, selectedTime),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerHeader extends StatelessWidget {
  const _PickerHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(icon, color: AppColors.primaryBlue, size: 23),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.adminPalette.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.adminPalette.textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cerrar',
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            AdminIcons.closeRounded,
            color: context.adminPalette.textMuted,
          ),
        ),
      ],
    );
  }
}

class _PickerActions extends StatelessWidget {
  const _PickerActions({required this.confirmLabel, required this.onConfirm});

  final String confirmLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: context.adminPalette.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: onConfirm,
          icon: Icon(AdminIcons.checkRounded, size: 18),
          label: Text(confirmLabel),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatTime(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

class _FormBlock extends StatelessWidget {
  const _FormBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.adminPalette.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.adminPalette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primaryBlue, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: context.adminPalette.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: context.adminPalette.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color =
        status == 'published'
            ? AppColors.primaryGreen
            : AppColors.primaryOrange;
    final label = status == 'published' ? 'Publicada' : 'Archivada';

    return _InfoPill(
      icon: AdminIcons.circleRounded,
      label: label,
      color: color,
    );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
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

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.color = AppColors.primaryBlue,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _EmptyNewsState extends StatelessWidget {
  const _EmptyNewsState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: context.adminPalette.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: context.adminPalette.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.adminPalette.surfaceMuted,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                AdminIcons.campaignRounded,
                color: AppColors.primaryBlue,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Sin noticias registradas',
              style: TextStyle(
                color: context.adminPalette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea el primer comunicado para validar el flujo web, Firestore y app móvil.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.adminPalette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: Icon(AdminIcons.addRounded),
              label: Text('Crear noticia'),
            ),
          ],
        ),
      ),
    );
  }
}
