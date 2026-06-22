import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Connectivity awareness (TH-015).
///
/// Wraps `connectivity_plus` as a [ChangeNotifier] so the UI can react to
/// online/offline transitions (offline banner, sync indicator, retry actions).
/// On a transition back online it invokes [onReconnect], which the app wires to
/// trigger a sync cycle.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService({Connectivity? connectivity, this.onReconnect})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Called when connectivity is regained (e.g. to kick off [SyncEngine.sync]).
  final Future<void> Function()? onReconnect;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _online = true;
  bool get isOnline => _online;
  bool get isOffline => !_online;

  Future<void> start() async {
    final initial = await _connectivity.checkConnectivity();
    _apply(initial);
    _sub = _connectivity.onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    final wasOffline = !_online;
    final online =
        results.any((r) => r != ConnectivityResult.none) || results.isEmpty;
    if (online == _online) return;
    _online = online;
    notifyListeners();
    if (online && wasOffline) {
      onReconnect?.call();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
