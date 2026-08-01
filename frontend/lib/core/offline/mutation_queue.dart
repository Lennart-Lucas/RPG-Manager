import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../platform/client_platform.dart';

class QueuedMutation {
  QueuedMutation({
    required this.id,
    required this.method,
    required this.uri,
    required this.body,
    required this.createdAt,
    this.tempEntityId,
    this.listCacheUri,
    this.entityCacheUri,
  });

  final String id;
  final String method;
  final String uri;
  final String? body;
  final DateTime createdAt;
  final int? tempEntityId;
  final String? listCacheUri;
  final String? entityCacheUri;

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'uri': uri,
        'body': body,
        'created_at': createdAt.toUtc().toIso8601String(),
        'temp_entity_id': tempEntityId,
        'list_cache_uri': listCacheUri,
        'entity_cache_uri': entityCacheUri,
      };

  factory QueuedMutation.fromJson(Map<String, dynamic> json) {
    return QueuedMutation(
      id: json['id'] as String,
      method: json['method'] as String,
      uri: json['uri'] as String,
      body: json['body'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      tempEntityId: json['temp_entity_id'] as int?,
      listCacheUri: json['list_cache_uri'] as String?,
      entityCacheUri: json['entity_cache_uri'] as String?,
    );
  }
}

/// Persistent FIFO queue of offline mutations (desktop only).
class MutationQueue {
  final List<QueuedMutation> _ops = [];
  int _tempIdSeq = 0;
  File? _file;

  bool get isEnabled => detectClientPlatform() == ClientPlatform.desktop;

  int get length => _ops.length;

  List<QueuedMutation> get ops => List.unmodifiable(_ops);

  int nextTempId() {
    _tempIdSeq -= 1;
    return _tempIdSeq;
  }

  Future<File> _queueFile() async {
    final existing = _file;
    if (existing != null) return existing;
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'offline_sync'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, 'mutation_queue.json'));
    _file = file;
    return file;
  }

  Future<void> load() async {
    if (!isEnabled) return;
    final file = await _queueFile();
    if (!await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return;
      final ops = decoded['ops'];
      if (ops is List) {
        _ops
          ..clear()
          ..addAll(
            ops.map(
              (e) => QueuedMutation.fromJson(Map<String, dynamic>.from(e as Map)),
            ),
          );
      }
      final seq = decoded['temp_id_seq'];
      if (seq is int) _tempIdSeq = seq;
    } catch (_) {}
  }

  Future<void> _persist() async {
    if (!isEnabled) return;
    final file = await _queueFile();
    await file.writeAsString(
      jsonEncode({
        'temp_id_seq': _tempIdSeq,
        'ops': _ops.map((o) => o.toJson()).toList(),
      }),
      flush: true,
    );
  }

  Future<void> enqueue(QueuedMutation op) async {
    if (!isEnabled) return;
    _ops.add(op);
    await _persist();
  }

  Future<QueuedMutation?> dequeue() async {
    if (_ops.isEmpty) return null;
    final op = _ops.removeAt(0);
    await _persist();
    return op;
  }

  Future<void> removeById(String id) async {
    _ops.removeWhere((o) => o.id == id);
    await _persist();
  }

  Future<void> clear() async {
    _ops.clear();
    await _persist();
  }

  /// Rewrites temp entity ids embedded in pending mutation URIs after a create syncs.
  Future<int> rewriteTempIdsInUris({
    required int tempId,
    required int realId,
  }) async {
    if (tempId >= 0 || tempId == realId) return 0;
    final from = '/$tempId';
    final to = '/$realId';
    var changed = 0;
    for (var i = 0; i < _ops.length; i++) {
      final op = _ops[i];
      final uri = op.uri.contains(from) ? op.uri.replaceAll(from, to) : op.uri;
      final listUri = op.listCacheUri?.contains(from) == true
          ? op.listCacheUri!.replaceAll(from, to)
          : op.listCacheUri;
      final entityUri = op.entityCacheUri?.contains(from) == true
          ? op.entityCacheUri!.replaceAll(from, to)
          : op.entityCacheUri;
      if (uri == op.uri &&
          listUri == op.listCacheUri &&
          entityUri == op.entityCacheUri) {
        continue;
      }
      _ops[i] = QueuedMutation(
        id: op.id,
        method: op.method,
        uri: uri,
        body: op.body,
        createdAt: op.createdAt,
        tempEntityId: op.tempEntityId,
        listCacheUri: listUri,
        entityCacheUri: entityUri,
      );
      changed++;
    }
    if (changed > 0) await _persist();
    return changed;
  }
}
