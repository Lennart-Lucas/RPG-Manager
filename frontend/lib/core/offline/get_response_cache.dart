import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../platform/client_platform.dart';

/// File-backed cache of authenticated GET response bodies (desktop only).
class GetResponseCache {
  Directory? _root;

  bool get isEnabled => detectClientPlatform() == ClientPlatform.desktop;

  Future<Directory> _ensureRoot() async {
    final existing = _root;
    if (existing != null) return existing;
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'http_get_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _root = dir;
    return dir;
  }

  String _key(int userId, Uri uri) {
    final raw = '$userId|GET|${uri.toString()}';
    return base64Url.encode(utf8.encode(raw)).replaceAll('=', '');
  }

  Future<File> _fileFor(int userId, Uri uri) async {
    final root = await _ensureRoot();
    final key = _key(userId, uri);
    final short = key.length > 120 ? key.substring(0, 120) : key;
    return File(p.join(root.path, '$short.json'));
  }

  Future<void> put({
    required int userId,
    required Uri uri,
    required String body,
  }) async {
    if (!isEnabled) return;
    final file = await _fileFor(userId, uri);
    final payload = jsonEncode({
      'uri': uri.toString(),
      'cached_at': DateTime.now().toUtc().toIso8601String(),
      'body': body,
    });
    await file.writeAsString(payload, flush: true);
  }

  Future<String?> get({
    required int userId,
    required Uri uri,
  }) async {
    if (!isEnabled) return null;
    final file = await _fileFor(userId, uri);
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map && decoded['body'] is String) {
        return decoded['body'] as String;
      }
    } catch (_) {}
    return null;
  }

  Future<void> rewriteTempId({
    required int userId,
    required int tempId,
    required int realId,
  }) async {
    if (!isEnabled) return;
    final root = await _ensureRoot();
    await for (final entity in root.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final decoded = jsonDecode(await entity.readAsString());
        if (decoded is! Map || decoded['body'] is! String) continue;
        final body = decoded['body'] as String;
        final parsed = jsonDecode(body);
        final updated = _replaceIds(parsed, tempId, realId);
        if (identical(updated, parsed)) continue;
        decoded['body'] = jsonEncode(updated);
        await entity.writeAsString(jsonEncode(decoded), flush: true);
      } catch (_) {}
    }
  }

  Object? _replaceIds(Object? node, int from, int to) {
    if (node is Map) {
      final out = <String, dynamic>{};
      var changed = false;
      for (final entry in node.entries) {
        final key = '${entry.key}';
        var value = entry.value;
        if ((key == 'id' || key.endsWith('_id')) && value == from) {
          value = to;
          changed = true;
        } else {
          final nested = _replaceIds(value, from, to);
          if (!identical(nested, value)) {
            value = nested;
            changed = true;
          }
        }
        out[key] = value;
      }
      return changed ? out : node;
    }
    if (node is List) {
      var changed = false;
      final out = <dynamic>[];
      for (final item in node) {
        final nested = _replaceIds(item, from, to);
        if (!identical(nested, item)) changed = true;
        out.add(nested);
      }
      return changed ? out : node;
    }
    return node;
  }

  Future<void> applyOptimisticListMutation({
    required int userId,
    required Uri listUri,
    required void Function(List<dynamic> list) mutate,
  }) async {
    if (!isEnabled) return;
    final raw = await get(userId: userId, uri: listUri);
    if (raw == null) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    final list = List<dynamic>.from(decoded);
    mutate(list);
    await put(userId: userId, uri: listUri, body: jsonEncode(list));
  }

  Future<void> putJson({
    required int userId,
    required Uri uri,
    required Object json,
  }) async {
    await put(userId: userId, uri: uri, body: jsonEncode(json));
  }
}
