import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/ui/markdown_form_field.dart';
import '../../auth/data/auth_api.dart';
import 'catalog_kind.dart';
import 'catalog_models.dart';

class CatalogApi {
  CatalogApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

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
    final response = await _client.get(
      _uri(kind),
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
    final response = await _client.get(
      uri,
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
    final response = await _client.get(
      _uri(kind, '/$itemId'),
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
    final response = await _client.post(
      _uri(kind),
      headers: _headers(accessToken),
      body: jsonEncode({
        'name': name,
        'payload': ?payload,
      }),
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
    final response = await _client.patch(
      _uri(kind, '/$itemId'),
      headers: _headers(accessToken),
      body: jsonEncode({
        'name': ?name,
        'payload': ?payload,
      }),
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
    final response = await _client.delete(
      _uri(kind, '/$itemId'),
      headers: _headers(accessToken),
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
