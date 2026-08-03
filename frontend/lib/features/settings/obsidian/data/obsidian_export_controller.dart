import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../auth/data/auth_api.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../../core/offline/offline_sync_controller.dart';
import '../../../../core/platform/client_platform.dart';
import 'obsidian_export_service.dart';
import 'obsidian_import_service.dart';
import 'obsidian_vault_store.dart';
import 'obsidian_vault_validator.dart';

typedef ObsidianAccessTokenProvider = Future<String?> Function();

/// Desktop-only debounced catalog → Obsidian vault sync.
class ObsidianExportController extends ChangeNotifier
    with WidgetsBindingObserver {
  ObsidianExportController._();
  static final ObsidianExportController instance = ObsidianExportController._();

  final ObsidianVaultStore _store = ObsidianVaultStore();
  final ObsidianExportService _service = ObsidianExportService();
  final ObsidianImportService _importService = ObsidianImportService();

  ObsidianAccessTokenProvider? _tokenProvider;
  Timer? _debounce;
  bool _enabled = false;
  bool _autoSyncEnabled = true;
  bool _exporting = false;
  bool _importing = false;
  bool _pending = false;
  String? _vaultPath;
  DateTime? _lastExportAt;
  String? _lastError;
  bool _started = false;

  bool get isEnabled => _enabled;
  bool get isAutoSyncEnabled => _autoSyncEnabled;
  bool get isExporting => _exporting;
  bool get isImporting => _importing;
  String? get vaultPath => _vaultPath;
  DateTime? get lastExportAt => _lastExportAt;
  String? get lastError => _lastError;
  bool get hasValidVault =>
      _vaultPath != null && isValidObsidianVault(_vaultPath!);

  Future<void> start({required ObsidianAccessTokenProvider tokenProvider}) async {
    if (detectClientPlatform() != ClientPlatform.desktop) {
      _enabled = false;
      return;
    }
    _tokenProvider = tokenProvider;
    _enabled = true;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addObserver(this);
      CatalogApi.onCatalogMutated = scheduleExport;
      final sync = OfflineSyncController.instance;
      sync.addListener(_onOfflineSyncChanged);
    }
    await reloadFromStore();
    if (hasValidVault && _autoSyncEnabled) {
      scheduleExport();
    }
  }

  Future<void> stop() async {
    _debounce?.cancel();
    _debounce = null;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      CatalogApi.onCatalogMutated = null;
      OfflineSyncController.instance.removeListener(_onOfflineSyncChanged);
      _started = false;
    }
  }

  int? _lastPendingCount;

  void _onOfflineSyncChanged() {
    final sync = OfflineSyncController.instance;
    final pending = sync.pendingMutationCount;
    final prev = _lastPendingCount;
    _lastPendingCount = pending;
    // After a sync drains the queue, refresh the vault from server truth.
    if (prev != null && prev > 0 && pending == 0 && !sync.isOffline) {
      scheduleExport();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && hasValidVault) {
      scheduleExport();
    }
  }

  Future<void> reloadFromStore() async {
    _vaultPath = await _store.getVaultPath();
    _autoSyncEnabled = await _store.getAutoSyncEnabled();
    _lastExportAt = await _store.getLastExportAt();
    _lastError = await _store.getLastError();
    if (_vaultPath != null && !isValidObsidianVault(_vaultPath!)) {
      _lastError = obsidianVaultValidationError(_vaultPath!);
    }
    notifyListeners();
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    if (!_enabled) return;
    await _store.setAutoSyncEnabled(enabled);
    _autoSyncEnabled = enabled;
    notifyListeners();
    if (enabled && hasValidVault) {
      scheduleExport();
    } else {
      _debounce?.cancel();
      _debounce = null;
      _pending = false;
    }
  }

  /// Validates and persists [path]. Clears when null/empty.
  /// Returns an error message if the path is invalid.
  Future<String?> setVaultPath(String? path) async {
    if (!_enabled) return 'Obsidian export is only available on desktop';
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _store.setVaultPath(null);
      await _store.setLastError(null);
      _vaultPath = null;
      _lastError = null;
      notifyListeners();
      return null;
    }
    final error = obsidianVaultValidationError(trimmed);
    if (error != null) {
      return error;
    }
    await _store.setVaultPath(trimmed);
    await _store.setLastError(null);
    _vaultPath = trimmed;
    _lastError = null;
    notifyListeners();
    if (_autoSyncEnabled) {
      scheduleExport();
    }
    return null;
  }

  void scheduleExport() {
    if (!_enabled || !_autoSyncEnabled || !hasValidVault) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () {
      unawaited(exportNow());
    });
  }

  Future<void> exportNow() async {
    if (!_enabled) return;
    if (_exporting) {
      _pending = true;
      return;
    }
    final path = _vaultPath ?? await _store.getVaultPath();
    if (path == null || !isValidObsidianVault(path)) {
      return;
    }
    final tokenProvider = _tokenProvider;
    if (tokenProvider == null) return;

    _exporting = true;
    _pending = false;
    notifyListeners();

    try {
      final token = await tokenProvider();
      if (token == null) {
        // Not signed in yet — try again after login via scheduleExport.
        return;
      }
      final result = await _service.exportAll(
        accessToken: token,
        vaultPath: path,
      );
      final at = DateTime.now();
      await _store.setLastExportAt(at);
      await _store.setLastError(null);
      _lastExportAt = at;
      _lastError = null;
      debugPrint(
        'Obsidian export: wrote ${result.notesWritten} notes, '
        'deleted ${result.filesDeleted} orphans',
      );
    } catch (e) {
      final message = e is AuthApiException ? e.message : '$e';
      await _store.setLastError(message);
      _lastError = message;
      debugPrint('Obsidian export failed: $e');
    } finally {
      _exporting = false;
      notifyListeners();
      if (_pending) {
        _pending = false;
        scheduleExport();
      }
    }
  }

  /// Reverse-imports a single Obsidian `.md` note into the database.
  ///
  /// Returns a user-facing error message, or null on success. On success,
  /// [onSuccess] receives a short summary (record name + kind label).
  Future<String?> importNoteFile(
    String absolutePath, {
    void Function(String summary)? onSuccess,
  }) async {
    if (!_enabled) {
      return 'Obsidian import is only available on desktop';
    }
    if (_importing) return 'An import is already in progress';
    final tokenProvider = _tokenProvider;
    if (tokenProvider == null) return 'Not signed in';

    _importing = true;
    notifyListeners();
    try {
      final token = await tokenProvider();
      if (token == null) return 'Not signed in';
      final result = await _importService.importFile(
        accessToken: token,
        absolutePath: absolutePath,
      );
      onSuccess?.call(
        '${result.name} (${result.kind.singularLabel})',
      );
      return null;
    } catch (e) {
      if (e is AuthApiException) return e.message;
      if (e is StateError) return e.message;
      return '$e';
    } finally {
      _importing = false;
      notifyListeners();
    }
  }
}
