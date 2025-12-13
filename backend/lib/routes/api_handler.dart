import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../repositories/power_data_repository.dart';
import '../services/database_service.dart';

/// API Routes Handler - Thin API layer endpoints
class ApiHandler {
  final PowerDataRepository _repository;
  final DatabaseService _db;

  ApiHandler({PowerDataRepository? repository, DatabaseService? db})
      : _repository = repository ?? PowerDataRepository(),
        _db = db ?? DatabaseService();

  Router get router {
    final router = Router();

    // Power Data endpoints
    router.get('/api/power-data', _getPowerData);
    router.get('/api/power-data/latest', _getLatestPowerData);
    router.get('/api/power-data/<id>', _getPowerDataById);
    router.get('/api/power-data/statistics', _getStatistics);

    // Chart data endpoint
    router.get('/api/chart-data', _getChartData);

    // Stations endpoint
    router.get('/api/power-operations/stations', _getStations);

    // Dashboard endpoint
    router.get('/api/dashboard', _getDashboard);

    // Database endpoints (new)
    router.get('/api/tables', _getTables);
    router.get('/api/tables/<tableName>/columns', _getTableColumns);
    router.get('/api/tables/<tableName>/data', _getTableData);
    router.post('/api/query', _executeQuery);

    // Health check
    router.get('/api/health', _healthCheck);

    return router;
  }

  /// GET /api/power-data - Get paginated power data
  Future<Response> _getPowerData(Request request) async {
    try {
      final params = request.url.queryParameters;

      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final pageSize = int.tryParse(params['pageSize'] ?? '50') ?? 50;
      final stationName = params['stationName'];
      final startDate = params['startDate'] != null
          ? DateTime.tryParse(params['startDate']!)
          : null;
      final endDate = params['endDate'] != null
          ? DateTime.tryParse(params['endDate']!)
          : null;
      final sortBy = params['sortBy'];
      final descending = params['descending']?.toLowerCase() != 'false';

      final result = await _repository.getPowerData(
        page: page,
        pageSize: pageSize,
        stationName: stationName,
        startDate: startDate,
        endDate: endDate,
        sortBy: sortBy,
        descending: descending,
      );

      return _jsonResponse({
        'success': true,
        'data': result['data'],
        'page': result['page'],
        'pageSize': result['pageSize'],
        'totalCount': result['totalCount'],
      });
    } catch (e) {
      return _errorResponse('Failed to fetch power data: $e');
    }
  }

  /// GET /api/power-data/latest - Get latest power data
  Future<Response> _getLatestPowerData(Request request) async {
    try {
      final limit =
          int.tryParse(request.url.queryParameters['limit'] ?? '10') ?? 10;

      final data = await _repository.getLatestPowerData(limit: limit);

      return _jsonResponse({
        'success': true,
        'data': data,
      });
    } catch (e) {
      return _errorResponse('Failed to fetch latest power data: $e');
    }
  }

  /// GET /api/power-data/:id - Get power data by ID
  Future<Response> _getPowerDataById(Request request, String id) async {
    try {
      final dataId = int.tryParse(id);
      if (dataId == null) {
        return _errorResponse('Invalid ID', statusCode: 400);
      }

      final data = await _repository.getPowerDataById(dataId);

      if (data == null) {
        return _errorResponse('Power data not found', statusCode: 404);
      }

      return _jsonResponse({
        'success': true,
        'data': data,
      });
    } catch (e) {
      return _errorResponse('Failed to fetch power data: $e');
    }
  }

  /// GET /api/power-data/statistics - Get power statistics
  Future<Response> _getStatistics(Request request) async {
    try {
      final params = request.url.queryParameters;

      final stationName = params['stationName'];
      final startDate = params['startDate'] != null
          ? DateTime.tryParse(params['startDate']!)
          : null;
      final endDate = params['endDate'] != null
          ? DateTime.tryParse(params['endDate']!)
          : null;

      final data = await _repository.getPowerStatistics(
        stationName: stationName,
        startDate: startDate,
        endDate: endDate,
      );

      return _jsonResponse({
        'success': true,
        'data': data,
      });
    } catch (e) {
      return _errorResponse('Failed to fetch statistics: $e');
    }
  }

  /// GET /api/chart-data - Get chart data
  Future<Response> _getChartData(Request request) async {
    try {
      final params = request.url.queryParameters;

      final chartType = params['chartType'] ?? 'power';
      final startDate = DateTime.tryParse(params['startDate'] ?? '') ??
          DateTime.now().subtract(const Duration(days: 7));
      final endDate =
          DateTime.tryParse(params['endDate'] ?? '') ?? DateTime.now();
      final interval = params['interval'] ?? 'hour';
      final stationName = params['stationName'];

      final data = await _repository.getChartData(
        chartType: chartType,
        startDate: startDate,
        endDate: endDate,
        interval: interval,
        stationName: stationName,
      );

      return _jsonResponse({
        'success': true,
        'data': data,
      });
    } catch (e) {
      return _errorResponse('Failed to fetch chart data: $e');
    }
  }

  /// GET /api/power-operations/stations - Get all stations
  Future<Response> _getStations(Request request) async {
    try {
      final data = await _repository.getStations();

      return _jsonResponse({
        'success': true,
        'data': data,
      });
    } catch (e) {
      return _errorResponse('Failed to fetch stations: $e');
    }
  }

  /// GET /api/dashboard - Get dashboard summary
  Future<Response> _getDashboard(Request request) async {
    try {
      final data = await _repository.getDashboardSummary();

      return _jsonResponse({
        'success': true,
        'data': data,
      });
    } catch (e) {
      return _errorResponse('Failed to fetch dashboard data: $e');
    }
  }

  /// GET /api/health - Health check endpoint
  Future<Response> _healthCheck(Request request) async {
    return _jsonResponse({
      'status': 'healthy',
      'timestamp': DateTime.now().toIso8601String(),
      'database': _db.isConnected ? 'connected' : 'disconnected',
    });
  }

  /// GET /api/tables - Get all database tables
  Future<Response> _getTables(Request request) async {
    try {
      final tables = await _db.getTables();
      return _jsonResponse({
        'success': true,
        'data': tables.map((t) => {'TABLE_NAME': t}).toList(),
      });
    } catch (e) {
      return _errorResponse('Failed to fetch tables: $e');
    }
  }

  /// GET /api/tables/:tableName/columns - Get table columns
  Future<Response> _getTableColumns(Request request, String tableName) async {
    try {
      final columns = await _db.getTableColumns(tableName);
      return _jsonResponse({
        'success': true,
        'data': columns,
      });
    } catch (e) {
      return _errorResponse('Failed to fetch columns: $e');
    }
  }

  /// GET /api/tables/:tableName/data - Get table data with pagination
  Future<Response> _getTableData(Request request, String tableName) async {
    try {
      final params = request.url.queryParameters;
      final limit = int.tryParse(params['limit'] ?? '100') ?? 100;
      final offset = int.tryParse(params['offset'] ?? '0') ?? 0;

      final sql =
          'SELECT * FROM $tableName ORDER BY 1 OFFSET $offset ROWS FETCH NEXT $limit ROWS ONLY';
      final data = await _db.query(sql);

      return _jsonResponse({
        'success': true,
        'data': data,
        'table': tableName,
        'limit': limit,
        'offset': offset,
      });
    } catch (e) {
      return _errorResponse('Failed to fetch table data: $e');
    }
  }

  /// POST /api/query - Execute raw SQL query
  Future<Response> _executeQuery(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body);
      final sql = json['query'] as String?;

      if (sql == null || sql.isEmpty) {
        return _errorResponse('Query is required', statusCode: 400);
      }

      // Security: Block dangerous operations
      final sqlLower = sql.toLowerCase();
      if (sqlLower.contains('drop ') ||
          sqlLower.contains('truncate ') ||
          sqlLower.contains('delete ') && !sqlLower.contains('where')) {
        return _errorResponse('Dangerous operation blocked', statusCode: 403);
      }

      final data = await _db.query(sql);

      return _jsonResponse({
        'success': true,
        'data': data,
        'rowCount': data.length,
      });
    } catch (e) {
      return _errorResponse('Query failed: $e');
    }
  }

  /// Create JSON response
  Response _jsonResponse(Map<String, dynamic> data, {int statusCode = 200}) {
    return Response(
      statusCode,
      body: jsonEncode(data),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }

  /// Create error response
  Response _errorResponse(String message, {int statusCode = 500}) {
    return Response(
      statusCode,
      body: jsonEncode({
        'success': false,
        'message': message,
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }
}
