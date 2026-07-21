import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import 'connectivity_probe.dart';

class NetworkStatusController extends ChangeNotifier
    with WidgetsBindingObserver {
  NetworkStatusController({
    Connectivity? connectivity,
    bool autoInitialize = true,
    bool initialOffline = false,
  }) : _connectivity = connectivity ?? Connectivity(),
       _isOffline = initialOffline,
       _checksEnabled = autoInitialize,
       _isChecking = autoInitialize {
    if (!autoInitialize) return;
    WidgetsBinding.instance.addObserver(this);
    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) => unawaited(_handleConnectivityResults(results)),
      onError: (_) {},
    );
    unawaited(checkNow());
  }

  final Connectivity _connectivity;
  final bool _checksEnabled;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _offlineDebounce;

  bool _isOffline;
  bool _isChecking;
  int _onlineRevision = 0;
  int _probeGeneration = 0;

  bool get isOffline => _isOffline;
  bool get isChecking => _isChecking;
  int get onlineRevision => _onlineRevision;

  Future<void> checkNow() async {
    if (!_checksEnabled) return;
    _isChecking = true;
    notifyListeners();

    try {
      await _handleConnectivityResults(
        await _connectivity.checkConnectivity(),
        debounceOffline: false,
      );
    } finally {
      if (_isChecking) {
        _isChecking = false;
        notifyListeners();
      }
    }
  }

  Future<void> _handleConnectivityResults(
    List<ConnectivityResult> results, {
    bool debounceOffline = true,
  }) async {
    final probeGeneration = ++_probeGeneration;
    final hasTransport = results.any(
      (result) => result != ConnectivityResult.none,
    );

    if (!hasTransport) {
      if (debounceOffline) {
        _scheduleOffline(probeGeneration);
      } else {
        _setOffline(true);
      }
      return;
    }

    _offlineDebounce?.cancel();
    _offlineDebounce = null;
    final isReachable = await hasInternetReachability();
    if (probeGeneration != _probeGeneration) return;

    if (isReachable) {
      _setOffline(false);
    } else if (debounceOffline) {
      _scheduleOffline(probeGeneration);
    } else {
      _setOffline(true);
    }
  }

  void _scheduleOffline(int probeGeneration) {
    _offlineDebounce?.cancel();
    _offlineDebounce = Timer(const Duration(milliseconds: 550), () {
      if (probeGeneration != _probeGeneration) return;
      _setOffline(true);
    });
  }

  void _setOffline(bool value) {
    final wasOffline = _isOffline;
    _isChecking = false;
    if (_isOffline == value) {
      notifyListeners();
      return;
    }

    _isOffline = value;
    if (wasOffline && !value) _onlineRevision++;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(checkNow());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _offlineDebounce?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
