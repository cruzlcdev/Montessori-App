import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connectivity/network_status_controller.dart';
import '../layout/responsive_layout.dart';
import '../theme/app_icons.dart';
import '../theme/colors.dart';
import 'app_loading_skeleton.dart';

class NetworkAwareModule extends StatefulWidget {
  const NetworkAwareModule({
    super.key,
    required this.layout,
    required this.child,
  });

  final AppSkeletonLayout layout;
  final Widget child;

  @override
  State<NetworkAwareModule> createState() => _NetworkAwareModuleState();
}

class _NetworkAwareModuleState extends State<NetworkAwareModule> {
  NetworkStatusController? _network;
  Timer? _offlineStateTimer;
  bool _showOfflineState = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextNetwork = context.read<NetworkStatusController>();
    if (identical(_network, nextNetwork)) return;

    _network?.removeListener(_handleNetworkChanged);
    _network = nextNetwork..addListener(_handleNetworkChanged);
    _handleNetworkChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(nextNetwork.checkNow());
    });
  }

  void _handleNetworkChanged() {
    final isOffline = _network?.isOffline ?? false;
    if (!isOffline) {
      _offlineStateTimer?.cancel();
      _offlineStateTimer = null;
      _showOfflineState = false;
      return;
    }

    if (_offlineStateTimer != null || _showOfflineState) return;
    _offlineStateTimer = Timer(const Duration(milliseconds: 1200), () {
      _offlineStateTimer = null;
      if (!mounted || _network?.isOffline != true) return;
      setState(() => _showOfflineState = true);
    });
  }

  @override
  void dispose() {
    _offlineStateTimer?.cancel();
    _network?.removeListener(_handleNetworkChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final network = context.watch<NetworkStatusController>();
    if (network.isChecking) {
      return ModuleLoadingSkeleton(layout: widget.layout);
    }

    if (!network.isOffline) {
      return KeyedSubtree(
        key: ValueKey(network.onlineRevision),
        child: widget.child,
      );
    }

    if (!_showOfflineState) {
      return ModuleLoadingSkeleton(layout: widget.layout);
    }

    return _OfflineModuleState(onRetry: network.checkNow);
  }
}

class _OfflineModuleState extends StatelessWidget {
  const _OfflineModuleState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: ResponsiveLayout.pagePadding(context, top: 28, bottom: 28),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDarkMode ? Colors.white12 : const Color(0xFFD9E8F5),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(
                    alpha: isDarkMode ? 0.18 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Icon(
                  AppIcons.wifiOffRounded,
                  color: AppColors.adaptiveBlue(context),
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Sin conexión a internet',
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
                'Revisa tu Wi-Fi o datos móviles. La información se actualizará automáticamente cuando vuelva la conexión.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(AppIcons.refreshRounded, size: 18),
                label: const Text('Reintentar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
