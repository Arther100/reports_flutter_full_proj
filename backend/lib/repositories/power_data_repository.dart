import '../services/database_service.dart';

/// Power Data Repository - Data access layer for power operations
class PowerDataRepository {
  final DatabaseService _db;

  PowerDataRepository({DatabaseService? db}) : _db = db ?? DatabaseService();

  /// Get paginated power data
  Future<Map<String, dynamic>> getPowerData({
    required int page,
    required int pageSize,
    String? stationName,
    DateTime? startDate,
    DateTime? endDate,
    String? sortBy,
    bool descending = true,
  }) async {
    final offset = (page - 1) * pageSize;

    var whereClause = 'WHERE 1=1';
    if (stationName != null && stationName.isNotEmpty) {
      whereClause += " AND station_name = '$stationName'";
    }
    if (startDate != null) {
      whereClause += " AND timestamp >= '${startDate.toIso8601String()}'";
    }
    if (endDate != null) {
      whereClause += " AND timestamp <= '${endDate.toIso8601String()}'";
    }

    final orderBy = sortBy ?? 'timestamp';
    final orderDirection = descending ? 'DESC' : 'ASC';

    // Get total count
    final countSql = '''
      SELECT COUNT(*) as total FROM power_data $whereClause
    ''';
    final countResult = await _db.query(countSql);
    final totalCount =
        countResult.isNotEmpty ? (countResult.first['total'] ?? 0) : 0;

    // Get paginated data
    final dataSql = '''
      SELECT * FROM power_data 
      $whereClause
      ORDER BY $orderBy $orderDirection
      OFFSET $offset ROWS
      FETCH NEXT $pageSize ROWS ONLY
    ''';
    final data = await _db.query(dataSql);

    return {
      'data': data,
      'page': page,
      'pageSize': pageSize,
      'totalCount': totalCount is int
          ? totalCount
          : int.tryParse(totalCount.toString()) ?? data.length,
    };
  }

  /// Get latest power data for all stations
  Future<List<Map<String, dynamic>>> getLatestPowerData(
      {int limit = 10}) async {
    final sql = '''
      SELECT TOP $limit * FROM power_data 
      ORDER BY timestamp DESC
    ''';
    return await _db.query(sql);
  }

  /// Get power data by ID
  Future<Map<String, dynamic>?> getPowerDataById(int id) async {
    final sql = 'SELECT * FROM power_data WHERE id = $id';
    final results = await _db.query(sql);
    return results.isNotEmpty ? results.first : null;
  }

  /// Get power statistics
  Future<Map<String, dynamic>> getPowerStatistics({
    String? stationName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var whereClause = 'WHERE 1=1';
    if (stationName != null && stationName.isNotEmpty) {
      whereClause += " AND station_name = '$stationName'";
    }
    if (startDate != null) {
      whereClause += " AND timestamp >= '${startDate.toIso8601String()}'";
    }
    if (endDate != null) {
      whereClause += " AND timestamp <= '${endDate.toIso8601String()}'";
    }

    final sql = '''
      SELECT 
        SUM(power_generated) as totalGenerated,
        SUM(power_consumed) as totalConsumed,
        AVG(efficiency) as averageEfficiency,
        MAX(power_generated) as peakPower,
        MIN(power_generated) as minPower,
        AVG(power_factor) as averagePowerFactor,
        COUNT(*) as totalReadings,
        MAX(timestamp) as lastUpdated
      FROM power_data
      $whereClause
    ''';

    final results = await _db.query(sql);
    return results.isNotEmpty ? results.first : {};
  }

  /// Get chart data
  Future<List<Map<String, dynamic>>> getChartData({
    required String chartType,
    required DateTime startDate,
    required DateTime endDate,
    String interval = 'hour',
    String? stationName,
  }) async {
    var whereClause =
        "WHERE timestamp BETWEEN '${startDate.toIso8601String()}' AND '${endDate.toIso8601String()}'";
    if (stationName != null && stationName.isNotEmpty) {
      whereClause += " AND station_name = '$stationName'";
    }

    String valueColumn;
    switch (chartType) {
      case 'power':
        valueColumn = 'power_generated';
        break;
      case 'voltage':
        valueColumn = 'voltage';
        break;
      case 'efficiency':
        valueColumn = 'efficiency';
        break;
      case 'current':
        valueColumn = 'current';
        break;
      default:
        valueColumn = 'power_generated';
    }

    // Group by interval
    String groupByFormat;
    switch (interval) {
      case 'minute':
        groupByFormat =
            'DATEPART(YEAR, timestamp), DATEPART(MONTH, timestamp), DATEPART(DAY, timestamp), DATEPART(HOUR, timestamp), DATEPART(MINUTE, timestamp)';
        break;
      case 'hour':
        groupByFormat =
            'DATEPART(YEAR, timestamp), DATEPART(MONTH, timestamp), DATEPART(DAY, timestamp), DATEPART(HOUR, timestamp)';
        break;
      case 'day':
        groupByFormat =
            'DATEPART(YEAR, timestamp), DATEPART(MONTH, timestamp), DATEPART(DAY, timestamp)';
        break;
      case 'week':
        groupByFormat = 'DATEPART(YEAR, timestamp), DATEPART(WEEK, timestamp)';
        break;
      default:
        groupByFormat =
            'DATEPART(YEAR, timestamp), DATEPART(MONTH, timestamp), DATEPART(DAY, timestamp), DATEPART(HOUR, timestamp)';
    }

    final sql = '''
      SELECT 
        MIN(timestamp) as timestamp,
        AVG($valueColumn) as value,
        '$chartType' as category
      FROM power_data
      $whereClause
      GROUP BY $groupByFormat
      ORDER BY timestamp
    ''';

    return await _db.query(sql);
  }

  /// Get all stations
  Future<List<Map<String, dynamic>>> getStations() async {
    const sql = 'SELECT * FROM stations ORDER BY name';
    return await _db.query(sql);
  }

  /// Get dashboard summary
  Future<Map<String, dynamic>> getDashboardSummary() async {
    final statistics = await getPowerStatistics();
    final latestData = await getLatestPowerData(limit: 5);
    final stations = await getStations();

    return {
      'statistics': statistics,
      'latestData': latestData,
      'stationCount': stations.length,
      'activeStations': stations.where((s) => s['isActive'] == true).length,
    };
  }
}
