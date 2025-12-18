import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';
import '../../data/models/powerbi_models.dart';

class PowerBIService {
  static String get baseUrl => ApiConfig.apiBaseUrl;

  /// Execute SQL query
  Future<List<Map<String, dynamic>>> _executeQuery(String query) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('Query error: $e');
      return [];
    }
  }

  /// Execute custom SQL query (public method)
  Future<List<Map<String, dynamic>>> executeCustomQuery(String query) async {
    return _executeQuery(query);
  }

  /// Get category-store sales report
  Future<List<PowerBICategory>> getCategoryStoreSales({
    required DynamicDateRange dateRange,
    required List<String> storeIds,
  }) async {
    if (storeIds.isEmpty) return [];

    final dates = dateRange.getDateRange();
    final startDate = dates['start']!.toIso8601String().split('T')[0];
    final endDate = dates['end']!.toIso8601String().split('T')[0];

    // Get actual distinct store values from Orders table
    final storeCheckQuery =
        '''
      SELECT DISTINCT o.store 
      FROM Orders o
      WHERE CONVERT(date, o.orderDate) >= '$startDate' 
        AND CONVERT(date, o.orderDate) <= '$endDate'
        AND o.isVoid = 0
        AND o.isVoidOrder = 0
        AND o.store IS NOT NULL
        AND LEN(o.store) > 0
      ORDER BY o.store
    ''';

    print('Getting actual store values from Orders...');
    final storesFromOrders = await _executeQuery(storeCheckQuery);
    final actualStores = storesFromOrders
        .map((row) => row['store']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    print('Actual stores in Orders: $actualStores');
    print('Store IDs from allstoresdetails: $storeIds');

    // Use actual store values from Orders table
    final storeColumns = actualStores
        .map((storeValue) {
          final safeId = storeValue.replaceAll(RegExp(r'[^\w]'), '_');
          return "SUM(CASE WHEN o.store = '$storeValue' THEN CAST(ISNULL(o.netSalesStr, '0') AS DECIMAL(18,2)) ELSE 0 END) as Store_$safeId";
        })
        .join(',\n        ');

    final query =
        '''
      SELECT 
        ISNULL(o.categoryName, 'Uncategorized') as CategoryName,
        $storeColumns,
        SUM(CAST(ISNULL(o.netSalesStr, '0') AS DECIMAL(18,2))) as Total
      FROM Orders o
      WHERE CONVERT(date, o.orderDate) >= '$startDate' 
        AND CONVERT(date, o.orderDate) <= '$endDate'
        AND o.isVoid = 0
        AND o.isVoidOrder = 0
      GROUP BY o.categoryName
      HAVING SUM(CAST(ISNULL(o.netSalesStr, '0') AS DECIMAL(18,2))) > 0
      ORDER BY Total DESC
    ''';

    print('Category Sales Query: $query');
    final result = await _executeQuery(query);
    print('Category Sales Result: ${result.length} rows');
    if (result.isNotEmpty) {
      print('First row sample: ${result.first}');
    }
    // Use actualStores for parsing instead of storeIds
    return result
        .map((e) => PowerBICategory.fromJson(e, actualStores))
        .toList();
  }

  /// Get category items (subcategories/products) for drill-down
  Future<List<PowerBICategoryItem>> getCategoryItems({
    required String categoryId,
    required DynamicDateRange dateRange,
    required List<String> storeIds,
  }) async {
    if (storeIds.isEmpty) return [];

    final dates = dateRange.getDateRange();
    final startDate = dates['start']!.toIso8601String().split('T')[0];
    final endDate = dates['end']!.toIso8601String().split('T')[0];

    // storeIds already contains actual store values from Orders table
    // Query with proper column aliases using actual store values
    final storeColumns = storeIds
        .map((storeValue) {
          final safeId = storeValue.replaceAll(RegExp(r'[^\w]'), '_');
          return "SUM(CASE WHEN o.store = '$storeValue' THEN CAST(ISNULL(o.netSalesStr, '0') AS DECIMAL(18,2)) ELSE 0 END) as Store_$safeId";
        })
        .join(',\n        ');

    // Simpler query for menu items within a category
    final query =
        '''
      SELECT 
        o.menuName as ItemName,
        $storeColumns,
        SUM(CAST(ISNULL(o.netSalesStr, '0') AS DECIMAL(18,2))) as Total
      FROM Orders o
      WHERE CONVERT(date, o.orderDate) >= '$startDate' 
        AND CONVERT(date, o.orderDate) <= '$endDate'
        AND ISNULL(o.categoryName, 'Uncategorized') = '$categoryId'
        AND o.isVoid = 0
        AND o.isVoidOrder = 0
      GROUP BY o.menuName
      HAVING SUM(CAST(ISNULL(o.netSalesStr, '0') AS DECIMAL(18,2))) > 0
      ORDER BY Total DESC
    ''';

    print('Category Items Query: $query');
    final result = await _executeQuery(query);
    print('Category Items Result: ${result.length} rows');
    return result
        .map((e) => PowerBICategoryItem.fromJson(e, storeIds))
        .toList();
  }

  /// Get stores list - get store IDs from Orders, names from allstoresdetails
  Future<List<PowerBIStore>> getStores() async {
    // JOIN Orders.store with allstoresdetails.id to get store names
    final query = '''
      SELECT DISTINCT
        o.store as StoreID,
        ISNULL(a.name, o.store) as StoreName,
        '' as City,
        '' as State,
        0 as TotalSales
      FROM Orders o
      LEFT JOIN allstoresdetails a ON o.store = a.id
      WHERE o.store IS NOT NULL 
        AND LEN(o.store) > 0
        AND o.isVoid = 0
        AND o.isVoidOrder = 0
      ORDER BY ISNULL(a.name, o.store)
    ''';

    print('Stores Query: $query');
    final result = await _executeQuery(query);
    print('Stores Result: ${result.length} stores loaded');
    if (result.isNotEmpty) {
      print('First store sample: ${result.first}');
    }
    return result.map((e) => PowerBIStore.fromJson(e)).toList();
  }

  /// Get summary statistics from Orders table
  Future<PowerBISummary?> getSummary({
    required DynamicDateRange dateRange,
    required List<String> storeIds,
  }) async {
    if (storeIds.isEmpty) return null;

    final dates = dateRange.getDateRange();
    final startDate = dates['start']!.toIso8601String().split('T')[0];
    final endDate = dates['end']!.toIso8601String().split('T')[0];

    final query =
        '''
      SELECT 
        COUNT(DISTINCT o.store) as StoreCount,
        COUNT(DISTINCT ISNULL(o.categoryName, 'Uncategorized')) as CategoryCount,
        ISNULL(SUM(CAST(ISNULL(o.netSalesStr, '0') AS DECIMAL(18,2))), 0) as NetSales,
        '$startDate' as StartDate,
        '$endDate' as EndDate
      FROM Orders o
      WHERE CONVERT(date, o.orderDate) >= '$startDate' 
        AND CONVERT(date, o.orderDate) <= '$endDate'
        AND o.isVoid = 0
        AND o.isVoidOrder = 0
    ''';

    print('Summary Query: $query');
    final result = await _executeQuery(query);
    print('Summary Result: $result');
    if (result.isNotEmpty) {
      return PowerBISummary.fromJson(result.first);
    }
    return null;
  }

  /// Get sales by category (aggregated for trend display)
  Future<List<Map<String, dynamic>>> getCategorySalesTrend({
    required DynamicDateRange dateRange,
    required List<String> storeIds,
  }) async {
    if (storeIds.isEmpty) return [];

    final dates = dateRange.getDateRange();
    final startDate = dates['start']!.toIso8601String().split('T')[0];
    final endDate = dates['end']!.toIso8601String().split('T')[0];

    final query =
        '''
      SELECT 
        ISNULL(o.categoryName, 'Uncategorized') as CategoryName,
        SUM(CAST(ISNULL(o.netSalesStr, '0') AS DECIMAL(18,2))) as TotalSales,
        COUNT(*) as TotalOrders
      FROM Orders o
      WHERE CONVERT(date, o.orderDate) >= '$startDate' 
        AND CONVERT(date, o.orderDate) <= '$endDate'
        AND o.isVoid = 0
        AND o.isVoidOrder = 0
      GROUP BY o.categoryName
      HAVING SUM(CAST(ISNULL(o.netSalesStr, '0') AS DECIMAL(18,2))) > 0
      ORDER BY TotalSales DESC
    ''';

    print('Category Sales Trend Query: $query');
    final result = await _executeQuery(query);
    print('Category Sales Trend Result: ${result.length} categories');
    return result;
  }

  /// Get daily sales trend data
  Future<List<Map<String, dynamic>>> getDailySalesTrend({
    required DynamicDateRange dateRange,
    required List<String> storeIds,
  }) async {
    if (storeIds.isEmpty) return [];

    final dates = dateRange.getDateRange();
    final startDate = dates['start']!.toIso8601String().split('T')[0];
    final endDate = dates['end']!.toIso8601String().split('T')[0];

    final query =
        '''
      SELECT 
        CONVERT(date, o.orderDate) as SaleDate,
        SUM(CAST(ISNULL(o.netSalesStr, '0') AS DECIMAL(18,2))) as TotalSales,
        COUNT(*) as TotalOrders
      FROM Orders o
      WHERE CONVERT(date, o.orderDate) >= '$startDate' 
        AND CONVERT(date, o.orderDate) <= '$endDate'
        AND o.isVoid = 0
        AND o.isVoidOrder = 0
      GROUP BY CONVERT(date, o.orderDate)
      ORDER BY CONVERT(date, o.orderDate) ASC
    ''';

    print('Daily Sales Trend Query: $query');
    final result = await _executeQuery(query);
    print('Daily Sales Trend Result: ${result.length} days');
    return result;
  }

  /// Get available tables in current database (for debugging)
  Future<List<String>> getTables() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tables'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<String>.from(
            (data['data'] as List).map((e) => e['TABLE_NAME'].toString()),
          );
        }
      }
      return [];
    } catch (e) {
      print('Error fetching tables: $e');
      return [];
    }
  }
}
