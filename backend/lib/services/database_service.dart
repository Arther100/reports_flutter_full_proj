import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../config/db_config.dart';

/// Database Service - Pure Dart MS SQL connectivity via HTTP bridge
///
/// Architecture:
/// Flutter App (Dart) → Dart API Server (shelf) → Node.js Bridge → MS SQL Server
///
/// The Node.js bridge handles the MS SQL TDS protocol (which has no pure Dart implementation)
/// while this Dart server provides a clean API layer for the Flutter frontend
class DatabaseService {
  static DatabaseService? _instance;
  bool _isConnected = false;
  final String _bridgeUrl = 'http://localhost:5000/api';
  final HttpClient _httpClient = HttpClient();

  factory DatabaseService() {
    _instance ??= DatabaseService._internal();
    return _instance!;
  }

  DatabaseService._internal() {
    _httpClient.connectionTimeout = const Duration(seconds: 30);
  }

  bool get isConnected => _isConnected;

  /// Test connection to the database via the Node.js bridge
  Future<void> connect() async {
    try {
      final request = await _httpClient.getUrl(Uri.parse('$_bridgeUrl/health'));
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body);

        if (json['status'] == 'healthy') {
          _isConnected = true;
          print('');
          print('═══════════════════════════════════════════════════════════');
          print('  ✅ Dart Backend Connected to MS SQL via Bridge');
          print('═══════════════════════════════════════════════════════════');
          print('   Database Bridge: $_bridgeUrl');
          print('   Server: ${DbConfig.server}');
          print('   Database: ${DbConfig.database}');
          print('═══════════════════════════════════════════════════════════');
          print('');
          return;
        }
      }
      throw Exception('Bridge health check failed');
    } catch (e) {
      print('');
      print('⚠️  Database bridge not available');
      print('   Start Node.js bridge: node api/server.js');
      print('   Running in mock data mode');
      print('');
      _isConnected = false;
    }
  }

  /// Execute a SQL query via the bridge
  Future<List<Map<String, dynamic>>> query(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    if (!_isConnected) {
      return _getMockData(sql);
    }

    try {
      final request = await _httpClient.postUrl(Uri.parse('$_bridgeUrl/query'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'query': sql}));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body);

      if (json['success'] == true && json['data'] != null) {
        return List<Map<String, dynamic>>.from(json['data']);
      }

      return [];
    } catch (e) {
      print('❌ Query error: $e');
      return _getMockData(sql);
    }
  }

  /// Execute a scalar query (returns single value)
  Future<dynamic> queryScalar(String sql) async {
    final results = await query(sql);
    if (results.isNotEmpty && results.first.isNotEmpty) {
      return results.first.values.first;
    }
    return null;
  }

  /// Get list of all tables in the database
  Future<List<String>> getTables() async {
    try {
      final request = await _httpClient.getUrl(Uri.parse('$_bridgeUrl/tables'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body);

      if (json['success'] == true && json['data'] != null) {
        return List<Map<String, dynamic>>.from(json['data'])
            .map((row) => row['TABLE_NAME'].toString())
            .toList();
      }
      return _getDefaultTables();
    } catch (e) {
      print('❌ Get tables error: $e');
      return _getDefaultTables();
    }
  }

  /// Get columns for a specific table
  Future<List<Map<String, dynamic>>> getTableColumns(String tableName) async {
    final sql = '''
      SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, CHARACTER_MAXIMUM_LENGTH
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_NAME = '$tableName'
      ORDER BY ORDINAL_POSITION
    ''';
    return await query(sql);
  }

  /// Execute non-query command (INSERT, UPDATE, DELETE)
  Future<int> execute(String sql) async {
    final result = await query(sql);
    return result.length;
  }

  /// Close connection
  Future<void> close() async {
    _httpClient.close();
    _isConnected = false;
    print('Database connection closed');
  }

  List<String> _getDefaultTables() {
    return [
      'ORDERS',
      'ORDERDETAILS',
      'PRODUCTS',
      'CUSTOMERS',
      'STORES',
      'PAYMENTS',
      'CATEGORY',
      'USERS'
    ];
  }

  /// Mock data generator for development/testing when bridge not available
  List<Map<String, dynamic>> _getMockData(String sql) {
    final now = DateTime.now();
    final sqlLower = sql.toLowerCase();

    // Mock for TABLE_NAME (information schema)
    if (sqlLower.contains('table_name') ||
        sqlLower.contains('information_schema.tables')) {
      return _getDefaultTables().map((t) => {'TABLE_NAME': t}).toList();
    }

    // Mock for COLUMNS (information schema)
    if (sqlLower.contains('information_schema.columns')) {
      return [
        {
          'COLUMN_NAME': 'Id',
          'DATA_TYPE': 'int',
          'IS_NULLABLE': 'NO',
          'CHARACTER_MAXIMUM_LENGTH': null
        },
        {
          'COLUMN_NAME': 'Name',
          'DATA_TYPE': 'nvarchar',
          'IS_NULLABLE': 'YES',
          'CHARACTER_MAXIMUM_LENGTH': 255
        },
        {
          'COLUMN_NAME': 'CreatedAt',
          'DATA_TYPE': 'datetime',
          'IS_NULLABLE': 'YES',
          'CHARACTER_MAXIMUM_LENGTH': null
        },
        {
          'COLUMN_NAME': 'Amount',
          'DATA_TYPE': 'decimal',
          'IS_NULLABLE': 'YES',
          'CHARACTER_MAXIMUM_LENGTH': null
        },
      ];
    }

    // Mock for ORDERS table
    if (sqlLower.contains('orders')) {
      return List.generate(20, (index) {
        return {
          'OrderId': index + 1,
          'OrderDate': now.subtract(Duration(days: index)).toIso8601String(),
          'TotalAmount': 100.0 + (index * 25.5),
          'Status': index % 3 == 0
              ? 'Completed'
              : (index % 3 == 1 ? 'Pending' : 'Processing'),
          'CustomerId': (index % 10) + 1,
        };
      });
    }

    // Mock for PRODUCTS table
    if (sqlLower.contains('products')) {
      return List.generate(15, (index) {
        return {
          'ProductId': index + 1,
          'ProductName': 'Product ${index + 1}',
          'Price': 10.0 + (index * 5.0),
          'Category': 'Category ${(index % 5) + 1}',
          'Stock': 50 + (index * 10),
        };
      });
    }

    // Mock for STORES table
    if (sqlLower.contains('stores')) {
      return List.generate(5, (index) {
        return {
          'StoreId': index + 1,
          'StoreName': 'Store ${index + 1}',
          'Location': 'Location ${index + 1}',
          'IsActive': true,
        };
      });
    }

    // Mock for CUSTOMERS table
    if (sqlLower.contains('customers')) {
      return List.generate(10, (index) {
        return {
          'CustomerId': index + 1,
          'CustomerName': 'Customer ${index + 1}',
          'Email': 'customer${index + 1}@example.com',
          'Phone': '555-000${index}',
        };
      });
    }

    // Mock for power data
    if (sqlLower.contains('power_data') || sqlLower.contains('latest')) {
      return List.generate(10, (index) {
        return {
          'id': index + 1,
          'stationName': 'Station ${index + 1}',
          'powerGenerated': 150.0 + (index * 10) + (index % 3) * 5,
          'powerConsumed': 120.0 + (index * 8) + (index % 2) * 3,
          'voltage': 220.0 + (index % 10),
          'current': 50.0 + (index % 5),
          'frequency': 50.0 + (index % 3) * 0.1,
          'powerFactor': 0.85 + (index % 10) * 0.01,
          'efficiency': 85.0 + (index % 15),
          'timestamp': now.subtract(Duration(hours: index)).toIso8601String(),
          'status': index % 3 == 0
              ? 'active'
              : (index % 3 == 1 ? 'warning' : 'active'),
        };
      });
    }

    // Mock for statistics
    if (sqlLower.contains('count') ||
        sqlLower.contains('sum') ||
        sqlLower.contains('avg')) {
      return [
        {
          'TotalOrders': 1500,
          'TotalRevenue': 125000.0,
          'AverageOrderValue': 83.33,
          'TotalCustomers': 450,
        }
      ];
    }

    // Mock for chart data
    if (sqlLower.contains('chart')) {
      return List.generate(24, (index) {
        return {
          'timestamp':
              now.subtract(Duration(hours: 23 - index)).toIso8601String(),
          'value': 100.0 + (index * 5) + (index % 5) * 3,
          'label': '${(now.subtract(Duration(hours: 23 - index))).hour}:00',
          'category': 'power',
        };
      });
    }

    // Default mock data
    return List.generate(10, (index) {
      return {
        'id': index + 1,
        'name': 'Item ${index + 1}',
        'value': 100.0 + (index * 10),
        'timestamp': now.subtract(Duration(hours: index)).toIso8601String(),
      };
    });
  }
}
