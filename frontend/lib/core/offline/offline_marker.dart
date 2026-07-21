import 'package:flutter/material.dart';

import 'offline_sync_controller.dart';

/// Cloud-off icon for the shell AppBar when desktop offline mode is active.
class OfflineAppBarMarker extends StatelessWidget {
  const OfflineAppBarMarker({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = OfflineSyncController.instance;
    return AnimatedBuilder(
      animation: sync,
      builder: (context, _) {
        if (!sync.isOffline) return const SizedBox.shrink();
        final pending = sync.pendingMutationCount;
        final tip = pending > 0
            ? 'Offline · $pending change${pending == 1 ? '' : 's'} pending'
            : 'Offline · showing cached data';
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Tooltip(
            message: tip,
            child: Icon(
              Icons.cloud_off_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        );
      },
    );
  }
}

/// Top-right overlay so pushed routes with their own AppBars also show offline.
class OfflineStatusOverlay extends StatelessWidget {
  const OfflineStatusOverlay({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final sync = OfflineSyncController.instance;
    return AnimatedBuilder(
      animation: sync,
      builder: (context, _) {
        return Stack(
          children: [
            ?child,
            if (sync.isOffline)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 6,
                right: 12,
                child: IgnorePointer(
                  child: Material(
                    elevation: 2,
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            sync.pendingMutationCount > 0
                                ? 'Offline · ${sync.pendingMutationCount}'
                                : 'Offline',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
