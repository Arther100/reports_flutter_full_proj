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

  /// Get category-store sales report
  Future<List<PowerBICategory>> getCategoryStoreSales({
    required DynamicDateRange dateRange,
    required List<String> storeIds,
  }) async {
    if (storeIds.isEmpty) return [];

    final dates = dateRange.getDateRange();
    final startDate = dates['start']!.toIso8601String().split('T')[0];
    final endDate = dates['end']!.toIso8601String().split('T')[0];

    // Build dynamic columns for each store
    final storeColumns = storeIds
        .map((id) => "ISNULL(SUM(CASE WHEN StoreID = '$id' THEN SalesAmount ELSE 0 END), 0) as [$id]")
        .join(', ');

    // Adjust table and column names based on actual database schema
    final query = '''
      SELECT 
        c.CategoryID,
        c.CategoryName,
        $storeColumns,
        ISNULL(SUM(s.SalesAmount), 0) as Total
      FROM Categories c
      LEFT JOIN Sales s ON c.CategoryID = s.CategoryID
      WHERE s.SaleDate >= '$startDate' AND s.SaleDate <= '$endDate 23:59:59'
        AND s.StoreID IN (${storeIds.map((id) => "'$id'").join(', ')})
      GROUP BY c.CategoryID, c.CategoryName
      ORDER BY Total DESC
    ''';

    final result = await _executeQuery(query);
    return result.map((e) => PowerBICategory.fromJson(e, storeIds)).toList();
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

    final storeColumns = storeIds
        .map((id) => "ISNULL(SUM(CASE WHEN StoreID = '$id' THEN SalesAmount ELSE 0 END), 0) as [$id]")
        .join(', ');

    final query = '''
      SELECT 
        p.ProductID as ItemID,
        p.ProductName as ItemName,
        'product' as Type,
        $storeColumns,
        ISNULL(SUM(s.SalesAmount), 0) as Total
      FROM Products p
      LEFT JOIN Sales s ON p.ProductID = s.ProductID
      WHERE p.CategoryID = '$categoryId'
        AND s.SaleDate >= '$startDate' AND s.SaleDate <= '$endDate 23:59:59'
        AND s.StoreID IN (${storeIds.map((id) => "'$id'").join(', ')})
      GROUP BY p.ProductID, p.ProductName
      ORDER BY Total DESC
    ''';

    final result = await _executeQuery(query);
    return result.map((e) => PowerBICategoryItem.fromJson(e, storeIds)).toList();
  }

  /// Get stores list
  Future<List<PowerBIStore>> getStores() async {
    final query = '''
      SELECT 
        StoreID,
        StoreName,
        City,
        State,
        0 as TotalSales
      FROM Stores
      ORDER BY StoreName
    ''';

    final result = await _executeQuery(query);
    return result.map((e) => PowerBIStore.fromJson(e)).toList();
  }

  /// Get summary statistics
  Future<PowerBISummary?> getSummary({
    required DynamicDateRange dateRange,
    required List<String> storeIds,
  }) async {
    if (storeIds.isEmpty) return null;

    final dates = dateRange.getDateRange();
    final startDate = dates['start']!.toIso8601String().split('T')[0];
    final endDate = dates['end']!.toIso8601String().split('T')[0];

    final query = '''
      SELECT 
        COUNT(DISTINCT StoreID) as StoreCount,
        COUNT(DISTINCT CategoryID) as CategoryCount,
        ISNULL(SUM(SalesAmount), 0) as NetSales,
        '$startDate' as StartDate,
        '$endDate' as EndDate
      FROM Sales
      WHERE SaleDate >= '$startDate' AND SaleDate <= '$endDate 23:59:59'
        AND StoreID IN (${storeIds.map((id) => "'$id'").join(', ')})
    ''';

    final result = await _executeQuery(query);
    if (result.isNotEmpty) {
      return PowerBISummary.fromJson(result.first);
    }
    return null;
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
