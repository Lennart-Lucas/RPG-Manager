import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../../auth/data/auth_api.dart';
import 'resource_models.dart';

class ResourcesApi {
  ResourcesApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) =>
      Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.apiPrefix}$path');

  Map<String, String> _headers(String accessToken) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

  Future<List<Author>> listAuthors(String accessToken) async {
    final response = await _client.get(
      _uri('/authors'),
      headers: _headers(accessToken),
    );
    return _parseList(response, Author.fromJson);
  }

  Future<Author> createAuthor({
    required String accessToken,
    required String name,
    required List<AuthorLink> links,
  }) async {
    final response = await _client.post(
      _uri('/authors'),
      headers: _headers(accessToken),
      body: jsonEncode({
        'name': name,
        'links': links.map((l) => l.toJson()).toList(),
      }),
    );
    return _parseOne(response, Author.fromJson, created: true);
  }

  Future<Author> updateAuthor({
    required String accessToken,
    required int authorId,
    required String name,
    required List<AuthorLink> links,
  }) async {
    final response = await _client.patch(
      _uri('/authors/$authorId'),
      headers: _headers(accessToken),
      body: jsonEncode({
        'name': name,
        'links': links.map((l) => l.toJson()).toList(),
      }),
    );
    return _parseOne(response, Author.fromJson);
  }

  Future<void> deleteAuthor({
    required String accessToken,
    required int authorId,
  }) async {
    final response = await _client.delete(
      _uri('/authors/$authorId'),
      headers: _headers(accessToken),
    );
    _ensureNoContent(response);
  }

  Future<List<ResourceFile>> listFiles(String accessToken) async {
    final response = await _client.get(
      _uri('/files'),
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
    final response = await _client.post(
      _uri('/files'),
      headers: _headers(accessToken),
      body: jsonEncode({
        'name': name,
        'author_id': authorId,
        'source': ?source,
      }),
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
    final response = await _client.patch(
      _uri('/files/$fileId'),
      headers: _headers(accessToken),
      body: jsonEncode({
        'name': name,
        'author_id': authorId,
        'source': source ?? '',
        'processed': ?processed,
      }),
    );
    return _parseOne(response, ResourceFile.fromJson);
  }

  Future<ResourceFile> setFileProcessed({
    required String accessToken,
    required int fileId,
    required bool processed,
  }) async {
    final response = await _client.patch(
      _uri('/files/$fileId'),
      headers: _headers(accessToken),
      body: jsonEncode({'processed': processed}),
    );
    return _parseOne(response, ResourceFile.fromJson);
  }

  Future<void> deleteFile({
    required String accessToken,
    required int fileId,
  }) async {
    final response = await _client.delete(
      _uri('/files/$fileId'),
      headers: _headers(accessToken),
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
