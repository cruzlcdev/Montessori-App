import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../theme/admin_icons.dart';
import '../theme/admin_theme.dart';

OverlayEntry? _activeFeedbackEntry;
Timer? _activeFeedbackTimer;

void showAdminFeedback(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = AdminIcons.checkCircleRounded,
  Color color = AppColors.primaryGreen,
  Duration duration = const Duration(seconds: 5),
}) {
  _activeFeedbackTimer?.cancel();
  if (_activeFeedbackEntry?.mounted ?? false) {
    _activeFeedbackEntry?.remove();
  }

  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;

  void dismiss() {
    _activeFeedbackTimer?.cancel();
    if (entry.mounted) entry.remove();
    if (identical(_activeFeedbackEntry, entry)) {
      _activeFeedbackEntry = null;
    }
  }

  entry = OverlayEntry(
    builder: (overlayContext) {
      final compact = MediaQuery.sizeOf(overlayContext).width < 640;
      return Positioned(
        right: compact ? 16 : 28,
        left: compact ? 16 : null,
        bottom: compact ? 18 : 28,
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: overlayContext.adminPalette.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.24)),
                boxShadow: [
                  BoxShadow(
                    color: overlayContext.adminPalette.shadow.withValues(
                      alpha: 0.24,
                    ),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 5, color: color),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(15, 14, 8, 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(icon, color: color, size: 21),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        color:
                                            overlayContext
                                                .adminPalette
                                                .textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      message,
                                      style: TextStyle(
                                        color:
                                            overlayContext
                                                .adminPalette
                                                .textSecondary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Cerrar mensaje',
                                onPressed: dismiss,
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  AdminIcons.closeRounded,
                                  size: 18,
                                  color: overlayContext.adminPalette.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  _activeFeedbackEntry = entry;
  overlay.insert(entry);
  _activeFeedbackTimer = Timer(duration, dismiss);
}
