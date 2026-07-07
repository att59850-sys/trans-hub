import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/network/connectivity_service.dart';
import '../../data/datasources/remote/sync_engine.dart';

/// Offline banner + sync indicator with a retry action (TH-015).
///
/// Renders nothing when online and idle; shows an amber offline banner when
/// disconnected, and a sync progress / error strip otherwise. Place at the top
/// of a [Scaffold] body or under the app bar.
class SyncStatusBar extends StatelessWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = sl<ConnectivityService>();
    final sync = sl<SyncEngine>();

    return AnimatedBuilder(
      animation: Listenable.merge([connectivity, sync]),
      builder: (context, _) {
        if (connectivity.isOffline) {
          return _Bar(
            color: Colors.amber.shade700,
            icon: Icons.cloud_off,
            label: 'You are offline — changes are saved locally and will sync.',
          );
        }
        switch (sync.state) {
          case SyncState.syncing:
            return _Bar(
              color: Theme.of(context).colorScheme.primary,
              icon: Icons.sync,
              label: 'Syncing${_pending(sync)}…',
            );
          case SyncState.error:
            return _Bar(
              color: Theme.of(context).colorScheme.error,
              icon: Icons.error_outline,
              label: 'Sync failed. ${_pending(sync)}',
              action: 'Retry',
              onAction: sync.sync,
            );
          case SyncState.offline:
          case SyncState.idle:
            return const SizedBox.shrink();
        }
      },
    );
  }

  String _pending(SyncEngine s) =>
      s.pendingCount > 0 ? '${s.pendingCount} pending' : '';
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.color,
    required this.icon,
    required this.label,
    this.action,
    this.onAction,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            if (action != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: Text(action!),
              ),
          ],
        ),
      ),
    );
  }
}
