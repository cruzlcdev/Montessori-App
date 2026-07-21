import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/app_icons.dart';
import 'package:intl/intl.dart';
import 'package:prototipo_2/core/layout/responsive_layout.dart';
import 'package:prototipo_2/core/theme/colors.dart';
import 'package:prototipo_2/core/widgets/custom_drawer.dart';
import 'package:prototipo_2/core/widgets/app_loading_skeleton.dart';
import 'package:prototipo_2/core/widgets/network_aware_module.dart';
import 'package:prototipo_2/features/news/data/models/news_model.dart';
import 'package:prototipo_2/features/news/data/repositories/firestore_news_repository.dart';
import 'package:prototipo_2/features/news/presentation/controllers/news_controller.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late final NewsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = NewsController(repository: FirestoreNewsRepository());
    _controller.addListener(_onControllerChanged);
    _controller.initialize();
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

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Noticias'),
        backgroundColor: isDarkMode ? Colors.grey[900] : AppColors.primaryBlue,
        foregroundColor: Colors.white,
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: const Icon(AppIcons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
      ),
      drawer: const CustomDrawer(),
      body: NetworkAwareModule(
        layout: AppSkeletonLayout.news,
        child: _buildBody(isDarkMode),
      ),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (_controller.isLoading) {
      return const ModuleLoadingSkeleton(
        layout: AppSkeletonLayout.news,
        itemCount: 2,
      );
    }

    if (_controller.errorMessage != null) {
      return RefreshIndicator(
        onRefresh: _controller.loadNews,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: ResponsiveLayout.pagePadding(context, top: 20, bottom: 28),
          children: [
            _buildHeader(isDarkMode, latestNews: null, newsCount: 0),
            const SizedBox(height: 18),
            _buildStateCard(
              icon: AppIcons.errorOutlineRounded,
              title: 'No se pudieron cargar las noticias',
              message: _controller.errorMessage!,
              isDarkMode: isDarkMode,
            ),
          ],
        ),
      );
    }

    if (_controller.news.isEmpty) {
      return RefreshIndicator(
        onRefresh: _controller.loadNews,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: ResponsiveLayout.pagePadding(context, top: 20, bottom: 28),
          children: [
            _buildHeader(isDarkMode, latestNews: null, newsCount: 0),
            const SizedBox(height: 18),
            _buildStateCard(
              icon: AppIcons.newspaperRounded,
              title: 'Sin noticias por ahora',
              message:
                  'Cuando la escuela publique comunicados, aparecerán en esta sección.',
              isDarkMode: isDarkMode,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _controller.loadNews,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                ResponsiveLayout.horizontalPadding(context),
                20,
                ResponsiveLayout.horizontalPadding(context),
                18,
              ),
              child: _buildHeader(
                isDarkMode,
                latestNews: _controller.news.first,
                newsCount: _controller.news.length,
              ),
            ),
          ),
          SliverPadding(
            padding: ResponsiveLayout.pagePadding(context, top: 0, bottom: 28),
            sliver: SliverList.separated(
              itemCount: _controller.news.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final news = _controller.news[index];
                return _buildNewsCard(context, news, index, isDarkMode);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    bool isDarkMode, {
    required NewsModel? latestNews,
    required int newsCount,
  }) {
    final countLabel = newsCount == 1 ? 'noticia activa' : 'noticias activas';
    final hasLatestNews = latestNews != null;
    final compact = ResponsiveLayout.isCompactPhone(context);
    final iconSize = compact ? 50.0 : 58.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white10
                  : Colors.white.withValues(alpha: 0.92),
        ),
        boxShadow: _softShadows(isDarkMode),
      ),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveLayout.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: AppColors.primaryYellow.withValues(
                      alpha: isDarkMode ? 0.20 : 0.11,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    AppIcons.autoStoriesRounded,
                    color: AppColors.primaryOrange,
                    size: compact ? 28 : 31,
                  ),
                ),
                SizedBox(width: compact ? 12 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mural informativo',
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: ResponsiveLayout.titleSize(context, 22),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Avisos y comunicados de Cintli Montessori',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildInfoPill(
                  icon: AppIcons.newspaperRounded,
                  label: '$newsCount $countLabel',
                  color: AppColors.primaryBlue,
                ),
                _buildInfoPill(
                  icon: AppIcons.scheduleRounded,
                  label:
                      hasLatestNews
                          ? 'Última: ${_shortDate(latestNews.publishedAt)}'
                          : 'Sin publicaciones',
                  color:
                      hasLatestNews
                          ? AppColors.primaryGreen
                          : AppColors.primaryOrange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsCard(
    BuildContext context,
    NewsModel news,
    int index,
    bool isDarkMode,
  ) {
    final accent = _accentColor(index);
    final hasImage = news.imageUrl != null && news.imageUrl!.trim().isNotEmpty;
    final radius = ResponsiveLayout.cardRadius(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(radius),
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
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: () => _showNewsDetails(context, news),
          child: Padding(
            padding: EdgeInsets.all(
              ResponsiveLayout.isCompactPhone(context) ? 14 : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _buildNetworkImage(
                        context,
                        news.imageUrl!,
                        fallbackColor: accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  _buildNewsTopStrip(accent, isDarkMode),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildInfoPill(
                            icon: AppIcons.calendarMonthRounded,
                            label: _shortDate(news.publishedAt),
                            color: accent,
                          ),
                          _buildInfoPill(
                            icon: AppIcons.groupsRounded,
                            label: _audienceLabel(news),
                            color: AppColors.primaryTurquoise,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(
                          alpha: isDarkMode ? 0.18 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        AppIcons.arrowForwardRounded,
                        color: accent,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  news.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary(context),
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  news.content,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.38,
                    color: AppColors.textSecondary(context),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Spacer(),
                    Text(
                      'Leer comunicado',
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewsTopStrip(Color accent, bool isDarkMode) {
    return Container(
      height: 82,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDarkMode ? 0.20 : 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDarkMode ? 0.22 : 0.15),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(AppIcons.campaignRounded, color: accent, size: 28),
            ),
          ),
          Expanded(
            child: Text(
              'Comunicado institucional',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDarkMode ? Colors.white : AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                _BrandDot(color: AppColors.primaryRed),
                const SizedBox(width: 5),
                _BrandDot(color: AppColors.primaryYellow),
                const SizedBox(width: 5),
                _BrandDot(color: AppColors.primaryGreen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageFallback(Color accent) {
    return Container(
      color: accent.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Icon(AppIcons.imageNotSupportedRounded, color: accent, size: 34),
    );
  }

  Widget _buildStateCard({
    required IconData icon,
    required String title,
    required String message,
    required bool isDarkMode,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white10
                  : Colors.white.withValues(alpha: 0.92),
        ),
        boxShadow: _softShadows(isDarkMode),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(
                  alpha: isDarkMode ? 0.20 : 0.11,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, color: AppColors.primaryBlue, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 20,
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
                height: 1.35,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxWidth:
            MediaQuery.sizeOf(context).width -
            (ResponsiveLayout.horizontalPadding(context) * 2),
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

  Color _accentColor(int index) {
    const colors = [
      AppColors.primaryBlue,
      AppColors.primaryGreen,
      AppColors.primaryOrange,
      AppColors.primaryTurquoise,
      AppColors.primaryRed,
    ];

    return colors[index % colors.length];
  }

  String _shortDate(DateTime date) {
    return DateFormat('d MMM').format(date);
  }

  String _detailDate(DateTime date) {
    return DateFormat('dd MMMM, yyyy').format(date);
  }

  String _audienceLabel(NewsModel news) {
    if (news.targetGroupIds.contains('all')) return 'Toda la escuela';
    return 'Tu grupo';
  }

  void _showNewsDetails(BuildContext context, NewsModel news) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.42,
          maxChildSize: 0.94,
          expand: false,
          builder: (context, scrollController) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF111827) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color:
                            isDarkMode
                                ? Colors.white24
                                : const Color(0xFFD8E0EA),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (news.imageUrl != null &&
                      news.imageUrl!.trim().isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _buildNetworkImage(
                          context,
                          news.imageUrl!,
                          fallbackColor: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ] else ...[
                    _buildNewsTopStrip(AppColors.primaryBlue, isDarkMode),
                    const SizedBox(height: 18),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoPill(
                        icon: AppIcons.calendarMonthRounded,
                        label: _detailDate(news.publishedAt),
                        color: AppColors.primaryBlue,
                      ),
                      _buildInfoPill(
                        icon: AppIcons.groupsRounded,
                        label: _audienceLabel(news),
                        color: AppColors.primaryTurquoise,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    news.title,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 24,
                      height: 1.12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    news.content,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 16,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(AppIcons.closeRounded),
                      label: const Text(
                        'Cerrar comunicado',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNetworkImage(
    BuildContext context,
    String imageUrl, {
    required Color fallbackColor,
  }) {
    final logicalWidth = MediaQuery.sizeOf(context).width.clamp(320.0, 720.0);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    final cacheWidth = (logicalWidth * pixelRatio).round().clamp(320, 2048);

    return Image.network(
      imageUrl,
      width: double.infinity,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _buildImageFallback(fallbackColor),
    );
  }
}

class _BrandDot extends StatelessWidget {
  const _BrandDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
