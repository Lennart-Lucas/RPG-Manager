import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalFilePathStore {
  static const _prefsKey = 'resources.local_file_paths';

  Future<Map<String, String>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return {};
      }
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeAll(Map<String, String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(paths));
  }

  Future<String?> getPath(int fileId) async {
    final paths = await _readAll();
    return paths['$fileId'];
  }

  Future<void> setPath(int fileId, String absolutePath) async {
    final paths = await _readAll();
    paths['$fileId'] = absolutePath;
    await _writeAll(paths);
  }

  Future<void> removePath(int fileId) async {
    final paths = await _readAll();
    if (paths.remove('$fileId') != null) {
      await _writeAll(paths);
    }
  }

  Future<Map<int, String>> allPaths() async {
    final paths = await _readAll();
    return {
      for (final entry in paths.entries)
        if (int.tryParse(entry.key) != null) int.parse(entry.key): entry.value,
    };
  }
}
