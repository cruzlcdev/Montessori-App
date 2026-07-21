import 'dart:math' as math;

import 'package:flutter/material.dart';

class ResponsiveLayout {
  const ResponsiveLayout._();

  static Size sizeOf(BuildContext context) => MediaQuery.sizeOf(context);

  static bool isCompactPhone(BuildContext context) =>
      sizeOf(context).width < 360;

  static bool isNarrowPhone(BuildContext context) =>
      sizeOf(context).width < 430;

  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600;

  static bool isShortScreen(BuildContext context) =>
      sizeOf(context).height < 700;

  static double horizontalPadding(BuildContext context) {
    final width = sizeOf(context).width;

    if (width < 360) return 16;
    if (width < 430) return 20;
    if (width < 600) return 24;
    if (width < 900) return 32;
    return 40;
  }

  static EdgeInsets pagePadding(
    BuildContext context, {
    double top = 20,
    double bottom = 28,
  }) {
    final horizontal = horizontalPadding(context);
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

    return EdgeInsets.fromLTRB(
      horizontal,
      top,
      horizontal,
      math.max(bottom, safeBottom + 16),
    );
  }

  static double contentMaxWidth(BuildContext context) {
    if (isTablet(context)) return 720;
    return double.infinity;
  }

  static double cardRadius(BuildContext context) =>
      isCompactPhone(context) ? 20 : 24;

  static double cardPadding(BuildContext context) =>
      isCompactPhone(context) ? 14 : 18;

  static double iconBoxSize(BuildContext context) =>
      isCompactPhone(context) ? 48 : 54;

  static double titleSize(BuildContext context, double base) =>
      isCompactPhone(context) ? base - 2 : base;

  static double homeCardExtent(BuildContext context, int crossAxisCount) {
    if (crossAxisCount == 1) return isShortScreen(context) ? 132 : 146;
    if (isCompactPhone(context)) return 148;
    return 164;
  }
}
