import 'package:shared_preferences/shared_preferences.dart';

/// Device-local Obsidian vault preferences (not synced to the server).
class ObsidianVaultStore {
  static const vaultPathKey = 'obsidian.vault_path';
  static const autoSyncKey = 'obsidian.auto_sync';
  static const lastExportAtKey = 'obsidian.last_export_at';
  static const lastErrorKey = 'obsidian.last_error';

  Future<String?> getVaultPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(vaultPathKey)?.trim();
    if (path == null || path.isEmpty) return null;
    return path;
  }

  Future<void> setVaultPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(vaultPathKey);
    } else {
      await prefs.setString(vaultPathKey, trimmed);
    }
  }

  /// Defaults to true when unset (existing installs keep auto-exporting).
  Future<bool> getAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(autoSyncKey) ?? true;
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(autoSyncKey, enabled);
  }

  Future<DateTime?> getLastExportAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(lastExportAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setLastExportAt(DateTime? at) async {
    final prefs = await SharedPreferences.getInstance();
    if (at == null) {
      await prefs.remove(lastExportAtKey);
    } else {
      await prefs.setString(lastExportAtKey, at.toUtc().toIso8601String());
    }
  }

  Future<String?> getLastError() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(lastErrorKey)?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  Future<void> setLastError(String? message) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = message?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(lastErrorKey);
    } else {
      await prefs.setString(lastErrorKey, trimmed);
    }
  }
}
