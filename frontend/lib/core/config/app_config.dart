class AppConfig {
  /// Override at build/run time: `--dart-define=API_BASE_URL=http://host:8011`
  /// Default targets the deployed VPS (RPG Manager uses host port 8011).
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://64.226.92.89:8011',
  );

  static const apiPrefix = '/api/v1';
}
