/// Application-wide constants
class AppConstants {
  // App Info
  static const String appName = 'Power Operations';
  static const String appVersion = '1.0.0';

  // Date Formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String displayDateFormat = 'MMM dd, yyyy';
  static const String displayTimeFormat = 'HH:mm:ss';

  // Chart Settings
  static const int maxChartDataPoints = 100;
  static const int chartAnimationDuration = 300;

  // Data Refresh Intervals (in seconds)
  static const int autoRefreshInterval = 30;
  static const int chartRefreshInterval = 10;

  // Error Messages
  static const String networkError =
      'Network error. Please check your connection.';
  static const String serverError = 'Server error. Please try again later.';
  static const String noDataError = 'No data available.';
  static const String timeoutError = 'Request timed out. Please try again.';
}
