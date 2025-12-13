import 'package:dio/dio.dart';
import '../../core/config/api_config.dart';
import '../../data/models/api_response.dart';
import '../../data/models/power_data_model.dart';
import 'api_client.dart';

/// Power Data Service - Thin layer for MS SQL database operations
/// Handles all power operations data fetching with optimized performance
class PowerDataService {
  final ApiClient _apiClient;

  PowerDataService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  // Cancel tokens for request cancellation
  CancelToken? _currentCancelToken;

  /// Cancel any ongoing requests
  void cancelOngoingRequests() {
    _currentCancelToken?.cancel('Request cancelled');
    _currentCancelToken = null;
  }

  /// Get all power data with pagination for fast loading
  Future<PaginatedResponse<PowerDataModel>> getPowerData({
    int page = 1,
    int pageSize = ApiConfig.defaultPageSize,
    String? stationName,
    DateTime? startDate,
    DateTime? endDate,
    String? sortBy,
    bool descending = true,
  }) async {
    cancelOngoingRequests();
    _currentCancelToken = CancelToken();

    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        if (stationName != null) 'stationName': stationName,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
        if (sortBy != null) 'sortBy': sortBy,
        'descending': descending,
      };

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiConfig.powerDataEndpoint,
        queryParameters: queryParams,
        cancelToken: _currentCancelToken,
      );

      return PaginatedResponse<PowerDataModel>.fromJson(
        response.data!,
        (json) => PowerDataModel.fromJson(json),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw Exception('Request was cancelled');
      }
      throw Exception(e.message ?? 'Failed to fetch power data');
    }
  }

  /// Get latest power data for all stations (optimized for dashboard)
  Future<List<PowerDataModel>> getLatestPowerData({int limit = 10}) async {
    cancelOngoingRequests();
    _currentCancelToken = CancelToken();

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${ApiConfig.powerDataEndpoint}/latest',
        queryParameters: {'limit': limit},
        cancelToken: _currentCancelToken,
      );

      final List<dynamic> dataList = response.data!['data'] ?? [];
      return dataList
          .map((json) => PowerDataModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw Exception('Request was cancelled');
      }
      throw Exception(e.message ?? 'Failed to fetch latest power data');
    }
  }

  /// Get power data by ID
  Future<PowerDataModel> getPowerDataById(int id) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${ApiConfig.powerDataEndpoint}/$id',
      );

      return PowerDataModel.fromJson(response.data!['data']);
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to fetch power data');
    }
  }

  /// Get power statistics summary
  Future<PowerStatistics> getPowerStatistics({
    DateTime? startDate,
    DateTime? endDate,
    String? stationName,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
        if (stationName != null) 'stationName': stationName,
      };

      final response = await _apiClient.get<Map<String, dynamic>>(
        '${ApiConfig.powerDataEndpoint}/statistics',
        queryParameters: queryParams,
      );

      return PowerStatistics.fromJson(response.data!['data']);
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to fetch power statistics');
    }
  }

  /// Get chart data for visualization
  Future<List<ChartDataPoint>> getChartData({
    required String chartType, // 'power', 'voltage', 'efficiency', etc.
    required DateTime startDate,
    required DateTime endDate,
    String? stationName,
    String interval = 'hour', // 'minute', 'hour', 'day', 'week', 'month'
  }) async {
    cancelOngoingRequests();
    _currentCancelToken = CancelToken();

    try {
      final queryParams = <String, dynamic>{
        'chartType': chartType,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'interval': interval,
        if (stationName != null) 'stationName': stationName,
      };

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiConfig.chartDataEndpoint,
        queryParameters: queryParams,
        cancelToken: _currentCancelToken,
      );

      final List<dynamic> dataList = response.data!['data'] ?? [];
      return dataList
          .map((json) => ChartDataPoint.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw Exception('Request was cancelled');
      }
      throw Exception(e.message ?? 'Failed to fetch chart data');
    }
  }

  /// Get all stations
  Future<List<StationModel>> getStations() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${ApiConfig.powerOperationsEndpoint}/stations',
      );

      final List<dynamic> dataList = response.data!['data'] ?? [];
      return dataList
          .map((json) => StationModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to fetch stations');
    }
  }

  /// Get dashboard summary data
  Future<Map<String, dynamic>> getDashboardSummary() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiConfig.dashboardEndpoint,
      );

      return response.data!['data'] ?? {};
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to fetch dashboard data');
    }
  }

  /// Stream power data updates (for real-time updates)
  Stream<PowerDataModel> streamPowerDataUpdates({
    Duration interval = const Duration(seconds: 5),
  }) async* {
    while (true) {
      try {
        final data = await getLatestPowerData(limit: 1);
        if (data.isNotEmpty) {
          yield data.first;
        }
      } catch (e) {
        // Continue streaming even on error
        print('Stream error: $e');
      }
      await Future.delayed(interval);
    }
  }
}
