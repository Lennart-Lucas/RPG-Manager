import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../../../core/offline/authenticated_http.dart';
import '../../../../core/offline/offline_sync_controller.dart';
import '../../../auth/data/auth_api.dart';
import 'resource_models.dart';

class ResourcesApi {
  ResourcesApi({http.Client? client, AuthenticatedHttp? httpClient})
      : _http = httpClient ?? OfflineSyncController.instance.httpClient;

  final AuthenticatedHttp _http;

  Uri _uri(String path) =>
      Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.apiPrefix}$path');

  Map<String, String> _headers(String accessToken) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

  Future<List<Author>> listAuthors(String accessToken) async {
    final response = await _http.get(
      uri: _uri('/authors'),
      headers: _headers(accessToken),
    );
    return _parseList(response, Author.fromJson);
  }

  Future<Author> createAuthor({
    required String accessToken,
    required String name,
    required List<AuthorLink> links,
  }) async {
    final listUri = _uri('/authors');
    final body = jsonEncode({
      'name': name,
      'links': links.map((l) => l.toJson()).toList(),
    });
    final sync = OfflineSyncController.instance;
    final now = DateTime.now().toUtc().toIso8601String();
    final response = await _http.mutate(
      method: 'POST',
      uri: listUri,
      headers: _headers(accessToken),
      body: body,
      successStatus: 201,
      listCacheUri: listUri,
      buildOptimisticBody: (tempId) => {
            'id': tempId,
            'user_id': sync.userId ?? 0,
            'name': name,
            'links': links.map((l) => l.toJson()).toList(),
            'created_at': now,
            'updated_at': now,
          },
      applyOptimisticCache: (_, optimistic) async {
        final userId = sync.userId;
        if (userId == null) return;
        await sync.cache.applyOptimisticListMutation(
          userId: userId,
          listUri: listUri,
          mutate: (list) => list.add(optimistic),
        );
      },
    );
    return _parseOne(response, Author.fromJson, created: true);
  }

  Future<Author> updateAuthor({
    required String accessToken,
    required int authorId,
    required String name,
    required List<AuthorLink> links,
  }) async {
    final listUri = _uri('/authors');
    final uri = _uri('/authors/$authorId');
    final body = jsonEncode({
      'name': name,
      'links': links.map((l) => l.toJson()).toList(),
    });
    final sync = OfflineSyncController.instance;
    final now = DateTime.now().toUtc().toIso8601String();
    final response = await _http.mutate(
      method: 'PATCH',
      uri: uri,
      headers: _headers(accessToken),
      body: body,
      successStatus: 200,
      listCacheUri: listUri,
      buildOptimisticBody: (_) => {
            'id': authorId,
            'user_id': sync.userId ?? 0,
            'name': name,
            'links': links.map((l) => l.toJson()).toList(),
            'created_at': now,
            'updated_at': now,
          },
      applyOptimisticCache: (_, optimistic) async {
        final userId = sync.userId;
        if (userId == null) return;
        await sync.cache.applyOptimisticListMutation(
          userId: userId,
          listUri: listUri,
          mutate: (list) {
            for (var i = 0; i < list.length; i++) {
              final item = list[i];
              if (item is Map && item['id'] == authorId) {
                list[i] = {
                  ...Map<String, dynamic>.from(item),
                  'name': name,
                  'links': links.map((l) => l.toJson()).toList(),
                  'updated_at': now,
                };
                return;
              }
            }
          },
        );
      },
    );
    return _parseOne(response, Author.fromJson);
  }

  Future<void> deleteAuthor({
    required String accessToken,
    required int authorId,
  }) async {
    final listUri = _uri('/authors');
    final sync = OfflineSyncController.instance;
    final response = await _http.mutate(
      method: 'DELETE',
      uri: _uri('/authors/$authorId'),
      headers: _headers(accessToken),
      successStatus: 204,
      alternateSuccessStatus: 200,
      listCacheUri: listUri,
      buildOptimisticBody: (_) => <String, dynamic>{},
      applyOptimisticCache: (tempId, optimistic) async {
        final userId = sync.userId;
        if (userId == null) return;
        await sync.cache.applyOptimisticListMutation(
          userId: userId,
          listUri: listUri,
          mutate: (list) {
            list.removeWhere((item) => item is Map && item['id'] == authorId);
          },
        );
      },
    );
    _ensureNoContent(response);
  }

  Future<List<ResourceFile>> listFiles(String accessToken) async {
    final response = await _http.get(
      uri: _uri('/files'),
      headers: _headers(accessToken),
    );
    return _parseList(response, ResourceFile.fromJson);
  }

  Future<ResourceFile> createFile({
    required String accessToken,
    required String name,
    required int authorId,
    String? source,
  }) async {
    final listUri = _uri('/files');
    final body = jsonEncode({
      'name': name,
      'author_id': authorId,
      'source': ?source,
    });
    final sync = OfflineSyncController.instance;
    final now = DateTime.now().toUtc().toIso8601String();
    final response = await _http.mutate(
      method: 'POST',
      uri: listUri,
      headers: _headers(accessToken),
      body: body,
      successStatus: 201,
      listCacheUri: listUri,
      buildOptimisticBody: (tempId) => {
            'id': tempId,
            'user_id': sync.userId ?? 0,
            'author_id': authorId,
            'name': name,
            'source': source,
            'processed': false,
            'created_at': now,
            'updated_at': now,
          },
      applyOptimisticCache: (_, optimistic) async {
        final userId = sync.userId;
        if (userId == null) return;
        await sync.cache.applyOptimisticListMutation(
          userId: userId,
          listUri: listUri,
          mutate: (list) => list.add(optimistic),
        );
      },
    );
    return _parseOne(response, ResourceFile.fromJson, created: true);
  }

  Future<ResourceFile> updateFile({
    required String accessToken,
    required int fileId,
    required String name,
    required int authorId,
    String? source,
    bool? processed,
  }) async {
    final listUri = _uri('/files');
    final body = jsonEncode({
      'name': name,
      'author_id': authorId,
      'source': source ?? '',
      'processed': ?processed,
    });
    final sync = OfflineSyncController.instance;
    final now = DateTime.now().toUtc().toIso8601String();
    final response = await _http.mutate(
      method: 'PATCH',
      uri: _uri('/files/$fileId'),
      headers: _headers(accessToken),
      body: body,
      successStatus: 200,
      listCacheUri: listUri,
      buildOptimisticBody: (_) => {
            'id': fileId,
            'user_id': sync.userId ?? 0,
            'author_id': authorId,
            'name': name,
            'source': source,
            'processed': processed ?? false,
            'created_at': now,
            'updated_at': now,
          },
      applyOptimisticCache: (tempId, optimistic) async {
        final userId = sync.userId;
        if (userId == null) return;
        await sync.cache.applyOptimisticListMutation(
          userId: userId,
          listUri: listUri,
          mutate: (list) {
            for (var i = 0; i < list.length; i++) {
              final item = list[i];
              if (item is Map && item['id'] == fileId) {
                final merged = Map<String, dynamic>.from(item);
                merged['name'] = name;
                merged['author_id'] = authorId;
                merged['source'] = source;
                if (processed != null) merged['processed'] = processed;
                merged['updated_at'] = now;
                list[i] = merged;
                return;
              }
            }
          },
        );
      },
    );
    return _parseOne(response, ResourceFile.fromJson);
  }

  Future<ResourceFile> setFileProcessed({
    required String accessToken,
    required int fileId,
    required bool processed,
  }) async {
    final listUri = _uri('/files');
    final sync = OfflineSyncController.instance;
    final now = DateTime.now().toUtc().toIso8601String();
    final response = await _http.mutate(
      method: 'PATCH',
      uri: _uri('/files/$fileId'),
      headers: _headers(accessToken),
      body: jsonEncode({'processed': processed}),
      successStatus: 200,
      listCacheUri: listUri,
      buildOptimisticBody: (_) => {
            'id': fileId,
            'user_id': sync.userId ?? 0,
            'author_id': 0,
            'name': '',
            'source': null,
            'processed': processed,
            'created_at': now,
            'updated_at': now,
          },
      applyOptimisticCache: (tempId, optimistic) async {
        final userId = sync.userId;
        if (userId == null) return;
        await sync.cache.applyOptimisticListMutation(
          userId: userId,
          listUri: listUri,
          mutate: (list) {
            for (var i = 0; i < list.length; i++) {
              final item = list[i];
              if (item is Map && item['id'] == fileId) {
                final merged = Map<String, dynamic>.from(item);
                merged['processed'] = processed;
                merged['updated_at'] = now;
                list[i] = merged;
                return;
              }
            }
          },
        );
      },
    );
    return _parseOne(response, ResourceFile.fromJson);
  }

  Future<void> deleteFile({
    required String accessToken,
    required int fileId,
  }) async {
    final listUri = _uri('/files');
    final sync = OfflineSyncController.instance;
    final response = await _http.mutate(
      method: 'DELETE',
      uri: _uri('/files/$fileId'),
      headers: _headers(accessToken),
      successStatus: 204,
      alternateSuccessStatus: 200,
      listCacheUri: listUri,
      buildOptimisticBody: (_) => <String, dynamic>{},
      applyOptimisticCache: (tempId, optimistic) async {
        final userId = sync.userId;
        if (userId == null) return;
        await sync.cache.applyOptimisticListMutation(
          userId: userId,
          listUri: listUri,
          mutate: (list) {
            list.removeWhere((item) => item is Map && item['id'] == fileId);
          },
        );
      },
    );
    _ensureNoContent(response);
  }

  List<T> _parseList<T>(
    http.Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (response.statusCode != 200) {
      throw AuthApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
    final body = jsonDecode(response.body);
    if (body is! List) {
      throw AuthApiException('Unexpected response');
    }
    return body
        .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  T _parseOne<T>(
    http.Response response,
    T Function(Map<String, dynamic>) fromJson, {
    bool created = false,
  }) {
    final ok = created
        ? response.statusCode == 201
        : response.statusCode == 200;
    if (!ok) {
      throw AuthApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
    return fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  void _ensureNoContent(http.Response response) {
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw AuthApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
  }

  String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] != null) {
        final detail = body['detail'];
        if (detail is String) {
          return detail;
        }
        return detail.toString();
      }
    } catch (_) {
      // fall through
    }
    return 'Request failed (${response.statusCode})';
  }
}
