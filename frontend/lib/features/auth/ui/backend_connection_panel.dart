import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../data/backend_health_checker.dart';

/// Dev-only banner that probes `/health` and `/health/db`.
class BackendConnectionPanel extends StatefulWidget {
  const BackendConnectionPanel({super.key});

  @override
  State<BackendConnectionPanel> createState() => _BackendConnectionPanelState();
}

class _BackendConnectionPanelState extends State<BackendConnectionPanel> {
  final _checker = BackendHealthChecker();
  BackendHealthResult _result = const BackendHealthResult(
    status: BackendConnectionStatus.checking,
  );
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _check();
    }
  }

  Future<void> _check() async {
    if (_checking) {
      return;
    }
    setState(() {
      _checking = true;
      _result = const BackendHealthResult(
        status: BackendConnectionStatus.checking,
      );
    });
    final result = await _checker.check();
    if (!mounted) {
      return;
    }
    setState(() {
      _result = result;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final (label, color, icon) = switch (_result.status) {
      BackendConnectionStatus.checking => (
          'Checking backend…',
          scheme.outline,
          Icons.hourglass_empty,
        ),
      BackendConnectionStatus.ok => (
          'Backend connected (API + DB)',
          scheme.primary,
          Icons.check_circle_outline,
        ),
      BackendConnectionStatus.apiUnreachable => (
          _result.detail != null &&
                  _result.detail!.contains('refused the network connection')
              ? 'No API on ${AppConfig.apiBaseUrl} (start local backend or set API_BASE_URL)'
              : 'Backend unreachable',
          scheme.error,
          Icons.cloud_off_outlined,
        ),
      BackendConnectionStatus.dbUnreachable => (
          'API up, database unreachable',
          scheme.error,
          Icons.storage_outlined,
        ),
    };

    return Card(
      margin: const EdgeInsets.only(top: 24),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Dev connection',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              AppConfig.apiBaseUrl,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: _checking ? null : _check,
                  child: const Text('Retry'),
                ),
              ],
            ),
            if (_result.detail != null &&
                _result.status != BackendConnectionStatus.ok) ...[
              const SizedBox(height: 4),
              Text(
                _result.detail!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
