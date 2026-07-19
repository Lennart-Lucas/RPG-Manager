import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/platform/client_platform.dart';
import '../models/auth_models.dart';

class AuthApiException implements Exception {
  AuthApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) =>
      Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.apiPrefix}$path');

  Future<TokenPair> register({
    required String email,
    required String password,
    required ClientPlatform platform,
  }) async {
    final response = await _client.post(
      _uri('/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'client_platform': platform.apiValue,
      }),
    );
    return _parseTokens(response);
  }

  Future<TokenPair> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    return _parseTokens(response);
  }

  Future<TokenPair> refresh(String refreshToken) async {
    final response = await _client.post(
      _uri('/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    return _parseTokens(response);
  }

  Future<UserProfile> me(String accessToken) async {
    final response = await _client.get(
      _uri('/auth/me'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw AuthApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
    return UserProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<UserProfile> updatePreferences({
    required String accessToken,
    required bool aiIntegration,
  }) async {
    final response = await _client.patch(
      _uri('/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'ai_integration': aiIntegration,
      }),
    );
    if (response.statusCode != 200) {
      throw AuthApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
    return UserProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> logout({
    required String accessToken,
    String? refreshToken,
    bool logoutAll = false,
  }) async {
    final response = await _client.post(
      _uri('/auth/logout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'refresh_token': ?refreshToken,
        'logout_all': logoutAll,
      }),
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw AuthApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
  }

  TokenPair _parseTokens(http.Response response) {
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AuthApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
    return TokenPair.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
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
