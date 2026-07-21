import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/offline/authenticated_http.dart';
import '../../../core/offline/offline_sync_controller.dart';
import '../../../core/ui/markdown_form_field.dart';
import '../../auth/data/auth_api.dart';
import 'catalog_kind.dart';
import 'catalog_models.dart';

class CatalogApi {
  CatalogApi({http.Client? client, AuthenticatedHttp? httpClient})
      : _http = httpClient ?? OfflineSyncController.instance.httpClient;

  final AuthenticatedHttp _http;

  Uri _uri(CatalogKind kind, [String suffix = '']) => Uri.parse(
        '${AppConfig.apiBaseUrl}${AppConfig.apiPrefix}/catalog/${kind.apiValue}$suffix',
      );

  Map<String, String> _headers(String accessToken) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

  Future<List<CatalogItem>> list(
    String accessToken,
    CatalogKind kind,
  ) async {
    final response = await _http.get(
      uri: _uri(kind),
      headers: _headers(accessToken),
    );
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
        .map((item) => CatalogItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<CatalogLinkTarget>> search(
    String accessToken, {
    String query = '',
    int limit = 20,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}${AppConfig.apiPrefix}/catalog/search',
    ).replace(queryParameters: {
      'q': query,
      'limit': '$limit',
    });
    final response = await _http.get(
      uri: uri,
      headers: _headers(accessToken),
    );
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
        .map(
          (item) =>
              CatalogLinkTarget.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<CatalogItem> get(
    String accessToken,
    CatalogKind kind,
    int itemId,
  ) async {
    final response = await _http.get(
      uri: _uri(kind, '/$itemId'),
      headers: _headers(accessToken),
    );
    if (response.statusCode != 200) {
      throw AuthApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
    return CatalogItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<CatalogItem> create({
    required String accessToken,
    required CatalogKind kind,
    required String name,
    Map<String, dynamic>? payload,
  }) async {
    final listUri = _uri(kind);
    final body = jsonEncode({
      'name': name,
      'payload': ?payload,
    });
    final sync = OfflineSyncController.instance;
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
            'kind': kind.apiValue,
            'name': name,
            'payload': payload,
          },
      applyOptimisticCache: (tempId, optimistic) async {
        final userId = sync.userId;
        if (userId == null) return;
        await sync.cache.applyOptimisticListMutation(
          userId: userId,
          listUri: listUri,
          mutate: (list) => list.add(optimistic),
        );
        await sync.cache.putJson(
          userId: userId,
          uri: _uri(kind, '/$tempId'),
          json: optimistic,
        );
      },
    );
    if (response.statusCode != 201) {
      throw AuthApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
    return CatalogItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<CatalogItem> update({
    required String accessToken,
    required CatalogKind kind,
    required int itemId,
    String? name,
    Map<String, dynamic>? payload,
  }) async {
    final listUri = _uri(kind);
    final entityUri = _uri(kind, '/$itemId');
    final body = jsonEncode({
      'name': ?name,
      'payload': ?payload,
    });
    final sync = OfflineSyncController.instance;
    final response = await _http.mutate(
      method: 'PATCH',
      uri: entityUri,
      headers: _headers(accessToken),
      body: body,
      successStatus: 200,
      listCacheUri: listUri,
      entityCacheUri: entityUri,
      buildOptimisticBody: (tempId) => {
            'id': itemId,
            'user_id': sync.userId ?? 0,
            'kind': kind.apiValue,
            'name': name ?? '',
            'payload': payload,
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
              if (item is Map && item['id'] == itemId) {
                final merged = Map<String, dynamic>.from(item);
                if (name != null) merged['name'] = name;
                if (payload != null) merged['payload'] = payload;
                list[i] = merged;
                return;
              }
            }
          },
        );
        final existing = await sync.cache.get(userId: userId, uri: entityUri);
        if (existing != null) {
          final map = Map<String, dynamic>.from(
            jsonDecode(existing) as Map,
          );
          if (name != null) map['name'] = name;
          if (payload != null) map['payload'] = payload;
          await sync.cache.putJson(userId: userId, uri: entityUri, json: map);
        } else {
          await sync.cache.putJson(
            userId: userId,
            uri: entityUri,
            json: optimistic,
          );
        }
      },
    );
    if (response.statusCode != 200) {
      throw AuthApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
    return CatalogItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> delete({
    required String accessToken,
    required CatalogKind kind,
    required int itemId,
  }) async {
    final listUri = _uri(kind);
    final entityUri = _uri(kind, '/$itemId');
    final sync = OfflineSyncController.instance;
    final response = await _http.mutate(
      method: 'DELETE',
      uri: entityUri,
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
            list.removeWhere(
              (item) => item is Map && item['id'] == itemId,
            );
          },
        );
      },
    );
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
          if (response.statusCode == 409 &&
              detail.toLowerCase().contains('already exists')) {
            return 'Name must be unique for this type';
          }
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
