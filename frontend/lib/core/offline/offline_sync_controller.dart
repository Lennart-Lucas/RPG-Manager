import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/auth/data/backend_health_checker.dart';
import '../../features/auth/models/auth_models.dart';
import '../config/app_config.dart';
import '../platform/client_platform.dart';
import 'authenticated_http.dart';
import 'get_response_cache.dart';
import 'mutation_queue.dart';

typedef AccessTokenProvider = Future<String?> Function();

/// Desktop offline connectivity, cache, queue, and sync coordination.
class OfflineSyncController extends ChangeNotifier {
  OfflineSyncController._();
  static final OfflineSyncController instance = OfflineSyncController._();

  final GetResponseCache cache = GetResponseCache();
  final MutationQueue queue = MutationQueue();
  final AuthenticatedHttp httpClient = AuthenticatedHttp();
  final BackendHealthChecker _health = BackendHealthChecker();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _probeTimer;
  AccessTokenProvider? _tokenProvider;
  void Function(String message)? onSyncError;

  bool _enabled = false;
  bool _isOffline = false;
  bool _syncing = false;
  int? _userId;
  int _cacheGeneration = 0;
  DateTime? _lastSyncedAt;
  String? _lastSyncError;

  bool get isEnabled => _enabled;
  bool get isOffline => _enabled && _isOffline;
  bool get isSyncing => _syncing;
  int? get userId => _userId;
  int get pendingMutationCount => queue.length;
  int get cacheGeneration => _cacheGeneration;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get lastSyncError => _lastSyncError;

  Future<void> start({AccessTokenProvider? tokenProvider}) async {
    _tokenProvider = tokenProvider;
    _enabled = detectClientPlatform() == ClientPlatform.desktop;
    if (!_enabled) {
      _isOffline = false;
      notifyListeners();
      return;
    }
    await queue.load();
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasLink = results.any((r) => r != ConnectivityResult.none);
      if (!hasLink) {
        markOffline();
      } else {
        unawaited(_probeAndMaybeSync());
      }
    });
    _probeTimer?.cancel();
    _probeTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_probeAndMaybeSync()),
    );
    await _probeAndMaybeSync();
    notifyListeners();
  }

  Future<void> stop() async {
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _probeTimer?.cancel();
    _probeTimer = null;
  }

  void setUserId(int? id) {
    _userId = id;
  }

  void markOffline() {
    if (!_enabled) return;
    if (_isOffline) return;
    _isOffline = true;
    notifyListeners();
  }

  void markOnline() {
    if (!_enabled) return;
    if (!_isOffline) return;
    _isOffline = false;
    notifyListeners();
  }

  Future<void> onQueueChanged() async {
    notifyListeners();
  }

  void reportSyncError(String message) {
    _lastSyncError = message;
    onSyncError?.call(message);
    notifyListeners();
  }

  void bumpCacheGeneration() {
    _cacheGeneration++;
    notifyListeners();
  }

  Future<void> _probeAndMaybeSync() async {
    if (!_enabled) return;
    final wasOffline = _isOffline;
    final result = await _health.check();
    final online = result.status == BackendConnectionStatus.ok;
    if (online) {
      markOnline();
      if (wasOffline || queue.length > 0) {
        await syncNow();
      }
    } else {
      markOffline();
    }
  }

  Future<void> syncNow() async {
    if (!_enabled || _syncing) return;
    _syncing = true;
    _lastSyncError = null;
    notifyListeners();
    try {
      final provider = _tokenProvider;
      if (provider == null) return;
      await httpClient.drainQueue(accessToken: provider);
      _lastSyncedAt = DateTime.now();
      bumpCacheGeneration();
    } catch (e) {
      if (isNetworkFailure(e)) {
        markOffline();
      } else {
        reportSyncError('$e');
      }
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  // --- User profile soft-offline cache ---

  Future<File> _profileFile(int userId) async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'offline_sync'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'user_$userId.json'));
  }

  Future<void> cacheUserProfile(UserProfile profile) async {
    if (!_enabled) return;
    final file = await _profileFile(profile.id);
    await file.writeAsString(jsonEncode({
      'id': profile.id,
      'email': profile.email,
      'is_active': profile.isActive,
      'is_dm': profile.isDm,
      'ai_integration': profile.aiIntegration,
    }), flush: true);
  }

  Future<UserProfile?> loadCachedUserProfile(int? hintUserId) async {
    if (!_enabled) return null;
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory(p.join(support.path, 'offline_sync'));
      if (!await dir.exists()) return null;
      if (hintUserId != null) {
        final file = await _profileFile(hintUserId);
        if (await file.exists()) {
          return UserProfile.fromJson(
            jsonDecode(await file.readAsString()) as Map<String, dynamic>,
          );
        }
      }
      await for (final entity in dir.list()) {
        if (entity is File &&
            p.basename(entity.path).startsWith('user_') &&
            entity.path.endsWith('.json')) {
          return UserProfile.fromJson(
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Quick API reachability used by auth bootstrap.
  Future<bool> canReachApi() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
