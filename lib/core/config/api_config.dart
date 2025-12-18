/// API Configuration for POS Analytics
/// Supports both local development and production deployment
class ApiConfig {
  // Production API URL - UPDATE THIS after deploying to Render
  static const String productionUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://reports-flutter.onrender.com',
  );

  // Local development URL
  // static const String localUrl = 'http://127.0.0.1:5000';

  // Check if running in production mode
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');

  // Check if custom API_URL is provided
  static const String _envUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: '',
  );

  // Get the appropriate API URL based on environment
  static String get baseUrl {
    // If API_URL is provided via --dart-define, use it
    if (_envUrl.isNotEmpty) {
      return _envUrl;
    }
    // For web builds, always use production URL
    // For debug/local development, use local URL
    return isProduction
        ? productionUrl
        : productionUrl; // Always use production for deployed apps
  }

  // API Base URL with /api prefix
  static String get apiBaseUrl => '$baseUrl/api';

  // Timeout settings
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Pagination settings
  static const int defaultPageSize = 50;
  static const int maxPageSize = 500;

  // API Endpoints (for backward compatibility)
  static const String powerDataEndpoint = '/power-data';
  static const String powerOperationsEndpoint = '/power-operations';
  static const String chartDataEndpoint = '/chart-data';
  static const String dashboardEndpoint = '/dashboard';
  static const String reportsEndpoint = '/reports';
}
