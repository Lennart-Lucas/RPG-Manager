import 'package:flutter/foundation.dart';

class AppConfig {
  /// Override at build/run time:
  /// `--dart-define=API_BASE_URL=http://host:8011`
  ///
  /// For the player website served from the same origin as the API, build with
  /// `--dart-define=API_BASE_URL=` (empty) or `SAME_ORIGIN` so requests use
  /// [Uri.base.origin].
  ///
  /// When the define is omitted, defaults to the deployed VPS (desktop clients).
  static const _apiBaseUrlDefine = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '__UNSET__',
  );

  static const _defaultApiBaseUrl = 'http://64.226.92.89:8011';

  static String get apiBaseUrl {
    const defined = _apiBaseUrlDefine;
    if (defined == '__UNSET__') {
      return _defaultApiBaseUrl;
    }
    final trimmed = defined.trim();
    if (trimmed.isEmpty ||
        trimmed.toUpperCase() == 'SAME_ORIGIN') {
      if (kIsWeb) {
        return Uri.base.origin;
      }
      return _defaultApiBaseUrl;
    }
    return trimmed;
  }

  static const apiPrefix = '/api/v1';
}
