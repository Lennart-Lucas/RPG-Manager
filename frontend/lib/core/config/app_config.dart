class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8011',
  );

  static const apiPrefix = '/api/v1';
}
