import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../layout/responsive_layout.dart';
import '../theme/colors.dart';

enum AppSkeletonLayout {
  directory,
  academic,
  reportCards,
  statistics,
  news,
  calendar,
}

class ModuleLoadingSkeleton extends StatelessWidget {
  const ModuleLoadingSkeleton({
    super.key,
    this.layout = AppSkeletonLayout.directory,
    this.itemCount = 3,
  });

  final AppSkeletonLayout layout;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Skeletonizer.zone(
      key: ValueKey('module-loading-skeleton-${layout.name}'),
      effect: _loadingEffect(context, isDarkMode),
      child: IgnorePointer(
        child: ListView(
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          padding: ResponsiveLayout.pagePadding(context, top: 18, bottom: 28),
          children: _contentForLayout(context, isDarkMode),
        ),
      ),
    );
  }

  List<Widget> _contentForLayout(BuildContext context, bool isDarkMode) {
    switch (layout) {
      case AppSkeletonLayout.news:
        return [
          _SkeletonPanel(
            isDarkMode: isDarkMode,
            height: 154,
            child: const _SkeletonHeaderContent(),
          ),
          const SizedBox(height: 18),
          ..._spacedCards(isDarkMode, count: itemCount, height: 174),
        ];
      case AppSkeletonLayout.calendar:
        return [
          _SkeletonPanel(
            isDarkMode: isDarkMode,
            height: 112,
            child: const _SkeletonHeaderContent(compact: true),
          ),
          const SizedBox(height: 16),
          _SkeletonPanel(
            isDarkMode: isDarkMode,
            height: 326,
            child: const _CalendarGridSkeleton(),
          ),
          const SizedBox(height: 22),
          const Bone(width: 178, height: 20, uniRadius: 7),
          const SizedBox(height: 12),
          ..._spacedCards(isDarkMode, count: 2, height: 92),
        ];
      case AppSkeletonLayout.statistics:
        return [
          _SkeletonPanel(
            isDarkMode: isDarkMode,
            height: 126,
            child: const _SkeletonHeaderContent(compact: true),
          ),
          const SizedBox(height: 14),
          _SkeletonPanel(
            isDarkMode: isDarkMode,
            height: 58,
            child: const _SegmentSkeleton(),
          ),
          const SizedBox(height: 18),
          _SkeletonPanel(
            isDarkMode: isDarkMode,
            height: 208,
            child: const _StatisticsContentSkeleton(),
          ),
          const SizedBox(height: 22),
          const Bone(width: 196, height: 20, uniRadius: 7),
          const SizedBox(height: 12),
          ..._spacedCards(isDarkMode, count: itemCount, height: 96),
        ];
      case AppSkeletonLayout.academic:
      case AppSkeletonLayout.reportCards:
        return [
          _SkeletonPanel(
            isDarkMode: isDarkMode,
            height: 122,
            child: const _SkeletonHeaderContent(compact: true),
          ),
          const SizedBox(height: 14),
          _SkeletonPanel(
            isDarkMode: isDarkMode,
            height: 58,
            child: const _SegmentSkeleton(),
          ),
          const SizedBox(height: 16),
          ..._spacedCards(
            isDarkMode,
            count: itemCount,
            height: layout == AppSkeletonLayout.reportCards ? 148 : 94,
          ),
        ];
      case AppSkeletonLayout.directory:
        return [
          _SkeletonPanel(
            isDarkMode: isDarkMode,
            height: 116,
            child: const _SkeletonHeaderContent(compact: true),
          ),
          const SizedBox(height: 16),
          ..._spacedCards(isDarkMode, count: itemCount, height: 104),
        ];
    }
  }

  List<Widget> _spacedCards(
    bool isDarkMode, {
    required int count,
    required double height,
  }) {
    return List.generate(
      count,
      (index) => Padding(
        padding: EdgeInsets.only(bottom: index == count - 1 ? 0 : 14),
        child: _SkeletonPanel(
          isDarkMode: isDarkMode,
          height: height,
          child: const _SkeletonRowContent(),
        ),
      ),
    );
  }
}

class _SkeletonPanel extends StatelessWidget {
  const _SkeletonPanel({
    required this.isDarkMode,
    required this.height,
    required this.child,
  });

  final bool isDarkMode;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.all(ResponsiveLayout.cardPadding(context)),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveLayout.cardRadius(context),
        ),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE3ECF5),
        ),
      ),
      child: child,
    );
  }
}

class _SkeletonHeaderContent extends StatelessWidget {
  const _SkeletonHeaderContent({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Bone.square(size: compact ? 46 : 54, uniRadius: 15),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Bone(width: 176, height: 20, uniRadius: 7),
                  SizedBox(height: 9),
                  Bone(width: 226, height: 12, uniRadius: 5),
                ],
              ),
            ),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 18),
          const Row(
            children: [
              Bone(width: 112, height: 28, uniRadius: 14),
              SizedBox(width: 9),
              Bone(width: 92, height: 28, uniRadius: 14),
            ],
          ),
        ],
      ],
    );
  }
}

class _SkeletonRowContent extends StatelessWidget {
  const _SkeletonRowContent();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Bone.square(size: 48, uniRadius: 15),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Bone(width: 168, height: 17, uniRadius: 7),
              SizedBox(height: 9),
              Bone(width: 218, height: 11, uniRadius: 5),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Bone.square(size: 30, uniRadius: 10),
      ],
    );
  }
}

class _SegmentSkeleton extends StatelessWidget {
  const _SegmentSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Bone(height: 32, uniRadius: 12)),
        SizedBox(width: 8),
        Expanded(child: Bone(height: 32, uniRadius: 12)),
        SizedBox(width: 8),
        Expanded(child: Bone(height: 32, uniRadius: 12)),
      ],
    );
  }
}

class _CalendarGridSkeleton extends StatelessWidget {
  const _CalendarGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          children: [
            Bone(width: 112, height: 18, uniRadius: 6),
            Spacer(),
            Bone.square(size: 30, uniRadius: 9),
            SizedBox(width: 8),
            Bone.square(size: 30, uniRadius: 9),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            childAspectRatio: 2.4,
            mainAxisSpacing: 13,
            crossAxisSpacing: 13,
            children: List.generate(
              35,
              (_) => const Center(child: Bone.circle(size: 18)),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatisticsContentSkeleton extends StatelessWidget {
  const _StatisticsContentSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Bone.circle(size: 118),
        SizedBox(width: 22),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Bone(width: 142, height: 20, uniRadius: 7),
              SizedBox(height: 12),
              Bone(width: 190, height: 12, uniRadius: 5),
              SizedBox(height: 9),
              Bone(width: 162, height: 12, uniRadius: 5),
            ],
          ),
        ),
      ],
    );
  }
}

class AppLoadingSkeleton extends StatelessWidget {
  const AppLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Skeletonizer.zone(
      effect: _loadingEffect(context, isDarkMode),
      child: Scaffold(
        key: const ValueKey('app-loading-skeleton'),
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const Padding(
            padding: EdgeInsets.all(11),
            child: Bone.square(size: 34, uniRadius: 11),
          ),
          title: const Bone(width: 174, height: 20, uniRadius: 8),
        ),
        body: _HomeLoadingContent(isDarkMode: isDarkMode),
      ),
    );
  }
}

class HomeLoadingSkeleton extends StatelessWidget {
  const HomeLoadingSkeleton({super.key, this.isDarkMode});

  final bool? isDarkMode;

  @override
  Widget build(BuildContext context) {
    final useDarkMode =
        isDarkMode ?? Theme.of(context).brightness == Brightness.dark;
    return Skeletonizer.zone(
      key: const ValueKey('home-loading-skeleton'),
      effect: _loadingEffect(context, useDarkMode),
      child: IgnorePointer(child: _HomeLoadingContent(isDarkMode: useDarkMode)),
    );
  }
}

class _HomeLoadingContent extends StatelessWidget {
  const _HomeLoadingContent({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: ResponsiveLayout.pagePadding(context, top: 24, bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Bone(width: 190, height: 24, uniRadius: 9),
          const SizedBox(height: 9),
          const Bone(width: 286, height: 13, uniRadius: 6),
          const SizedBox(height: 16),
          const Bone(width: 128, height: 32, uniRadius: 16),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 3 : 2;
              final spacing =
                  ResponsiveLayout.isCompactPhone(context) ? 12.0 : 16.0;
              final itemWidth =
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: List.generate(
                  columns == 3 ? 3 : 2,
                  (index) => SizedBox(
                    width: itemWidth,
                    child: _SkeletonFeatureCard(isDarkMode: isDarkMode),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SkeletonFeatureCard extends StatelessWidget {
  const _SkeletonFeatureCard({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: ResponsiveLayout.homeCardExtent(context, 2),
      padding: EdgeInsets.all(
        ResponsiveLayout.isCompactPhone(context) ? 14 : 15,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveLayout.cardRadius(context),
        ),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE5EDF5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Bone.square(
            size: ResponsiveLayout.iconBoxSize(context),
            uniRadius: 17,
          ),
          const Spacer(),
          const Bone(width: 104, height: 18, uniRadius: 7),
          const SizedBox(height: 8),
          const Bone(width: 126, height: 11, uniRadius: 5),
        ],
      ),
    );
  }
}

PaintingEffect _loadingEffect(BuildContext context, bool isDarkMode) {
  final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  final baseColor =
      isDarkMode ? const Color(0xFF26374D) : const Color(0xFFDCE7F2);

  if (reduceMotion) return SolidColorEffect(color: baseColor);

  return ShimmerEffect(
    baseColor: baseColor,
    highlightColor:
        isDarkMode ? const Color(0xFF354B67) : const Color(0xFFF5F9FC),
    duration: const Duration(milliseconds: 1350),
  );
}
