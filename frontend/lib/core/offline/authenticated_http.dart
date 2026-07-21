import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../features/auth/data/auth_api.dart';
import 'get_response_cache.dart';
import 'mutation_queue.dart';
import 'offline_sync_controller.dart';

bool isNetworkFailure(Object error) {
  if (error is SocketException) return true;
  if (error is TimeoutException) return true;
  if (error is http.ClientException) return true;
  final text = error.toString().toLowerCase();
  return text.contains('socket') ||
      text.contains('network') ||
      text.contains('connection') ||
      text.contains('failed host lookup') ||
      text.contains('timed out');
}

/// Shared authenticated HTTP with desktop GET cache + mutation queue.
class AuthenticatedHttp {
  AuthenticatedHttp({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  OfflineSyncController get _sync => OfflineSyncController.instance;
  GetResponseCache get _cache => _sync.cache;
  MutationQueue get _queue => _sync.queue;

  Future<http.Response> get({
    required Uri uri,
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final userId = _sync.userId;
    try {
      final response = await _client.get(uri, headers: headers).timeout(timeout);
      if (response.statusCode == 200 && userId != null) {
        await _cache.put(userId: userId, uri: uri, body: response.body);
      }
      return response;
    } catch (e) {
      if (userId != null && (isNetworkFailure(e) || _sync.isOffline)) {
        final cached = await _cache.get(userId: userId, uri: uri);
        if (cached != null) {
          _sync.markOffline();
          return http.Response(
            cached,
            200,
            headers: {'content-type': 'application/json', 'x-from-cache': '1'},
            request: http.Request('GET', uri),
          );
        }
      }
      rethrow;
    }
  }

  /// Performs a mutation online, or queues it when offline (desktop).
  ///
  /// [buildOptimisticBody] returns the JSON object to treat as the success
  /// response when queuing (e.g. created/updated entity map).
  /// [applyOptimisticCache] updates GET caches for local UI.
  Future<http.Response> mutate({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
    required int successStatus,
    int? alternateSuccessStatus,
    Uri? listCacheUri,
    Uri? entityCacheUri,
    required Map<String, dynamic> Function(int tempId) buildOptimisticBody,
    Future<void> Function(int tempId, Map<String, dynamic> optimistic)?
        applyOptimisticCache,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final userId = _sync.userId;
    final shouldQueue = _sync.isOffline &&
        _queue.isEnabled &&
        userId != null;

    Future<http.Response> send() {
      final m = method.toUpperCase();
      if (m == 'POST') {
        return _client
            .post(uri, headers: headers, body: body)
            .timeout(timeout);
      }
      if (m == 'PATCH') {
        return _client
            .patch(uri, headers: headers, body: body)
            .timeout(timeout);
      }
      if (m == 'DELETE') {
        return _client.delete(uri, headers: headers).timeout(timeout);
      }
      throw ArgumentError('Unsupported method $method');
    }

    if (!shouldQueue) {
      try {
        final response = await send();
        final ok = response.statusCode == successStatus ||
            (alternateSuccessStatus != null &&
                response.statusCode == alternateSuccessStatus);
        if (ok && userId != null && response.body.isNotEmpty) {
          // Refresh entity/list caches opportunistically when present.
          if (entityCacheUri != null) {
            await _cache.put(
              userId: userId,
              uri: entityCacheUri,
              body: response.body,
            );
          }
        }
        return response;
      } catch (e) {
        if (!(isNetworkFailure(e) && _queue.isEnabled && userId != null)) {
          rethrow;
        }
        _sync.markOffline();
        // fall through to queue
      }
    } else {
      // already offline
    }

    final tempId = _queue.nextTempId();
    final optimistic = buildOptimisticBody(tempId);
    if (applyOptimisticCache != null) {
      await applyOptimisticCache(tempId, optimistic);
    }

    await _queue.enqueue(
      QueuedMutation(
        id: '${DateTime.now().microsecondsSinceEpoch}_$tempId',
        method: method.toUpperCase(),
        uri: uri.toString(),
        body: body,
        createdAt: DateTime.now().toUtc(),
        tempEntityId: tempId,
        listCacheUri: listCacheUri?.toString(),
        entityCacheUri: entityCacheUri?.toString(),
      ),
    );
    await _sync.onQueueChanged();

    final encoded = jsonEncode(optimistic);
    return http.Response(
      encoded,
      successStatus,
      headers: {'content-type': 'application/json', 'x-offline-queued': '1'},
      request: http.Request(method.toUpperCase(), uri),
    );
  }

  Future<void> drainQueue({
    required Future<String?> Function() accessToken,
  }) async {
    if (!_queue.isEnabled) return;
    while (_queue.length > 0) {
      final op = _queue.ops.first;
      final token = await accessToken();
      if (token == null) {
        throw AuthApiException('Not authenticated');
      }
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final uri = Uri.parse(op.uri);
      try {
        late http.Response response;
        switch (op.method) {
          case 'POST':
            response = await _client
                .post(uri, headers: headers, body: op.body)
                .timeout(const Duration(seconds: 20));
          case 'PATCH':
            response = await _client
                .patch(uri, headers: headers, body: op.body)
                .timeout(const Duration(seconds: 20));
          case 'DELETE':
            response = await _client
                .delete(uri, headers: headers)
                .timeout(const Duration(seconds: 20));
          default:
            await _queue.dequeue();
            continue;
        }

        final ok = response.statusCode == 200 ||
            response.statusCode == 201 ||
            response.statusCode == 204;
        if (!ok) {
          // Hard failure: drop and continue.
          await _queue.dequeue();
          await _sync.onQueueChanged();
          _sync.reportSyncError(
            'Sync failed (${response.statusCode}) for ${op.method} ${op.uri}',
          );
          continue;
        }

        await _queue.dequeue();
        final userId = _sync.userId;
        if (userId != null &&
            op.tempEntityId != null &&
            response.body.isNotEmpty) {
          try {
            final map = jsonDecode(response.body);
            if (map is Map && map['id'] is int) {
              await _cache.rewriteTempId(
                userId: userId,
                tempId: op.tempEntityId!,
                realId: map['id'] as int,
              );
            }
          } catch (_) {}
        }
        await _sync.onQueueChanged();
      } catch (e) {
        if (isNetworkFailure(e)) {
          _sync.markOffline();
          rethrow;
        }
        await _queue.dequeue();
        await _sync.onQueueChanged();
        _sync.reportSyncError('Sync error: $e');
      }
    }
  }
}
