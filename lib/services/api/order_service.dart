import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../data/models/order_model.dart';

/// Order Service - Fetches orders from MS SQL via Node.js bridge
class OrderService {
  final String baseUrl;
  final http.Client _client;

  OrderService({
    this.baseUrl = 'http://localhost:5000/api', // Node.js bridge with CORS
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Get all orders with pagination
  Future<List<OrderModel>> getOrders({
    int page = 1,
    int pageSize = 50,
    String? orderBy,
    bool descending = true,
  }) async {
    try {
      // Simple SQL query without OFFSET for compatibility
      final sql =
          '''
        SELECT TOP $pageSize 
          OrderID, OrderNumber, TransDate, TransAmount, NetAmount, 
          TaxAmount, DiscountAmount, OrderStatus, PaymentMode, IsPOS,
          StoreID, CustomerID, SoldBy, IsDeleted, CreatedDate
        FROM ORDERS 
        WHERE IsDeleted = 0
        ORDER BY TransDate DESC
      ''';

      print('Fetching orders from: $baseUrl/query');

      final response = await _client.post(
        Uri.parse('$baseUrl/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': sql}),
      );

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        print(
          'Response success: ${json['success']}, data count: ${(json['data'] as List?)?.length ?? 0}',
        );
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map((item) => OrderModel.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching orders: $e');
      return [];
    }
  }

  /// Get recent orders (for dashboard)
  Future<List<OrderModel>> getRecentOrders({int limit = 10}) async {
    try {
      final sql =
          '''
        SELECT TOP $limit 
          OrderID, OrderNumber, TransDate, TransAmount, NetAmount, 
          TaxAmount, DiscountAmount, OrderStatus, PaymentMode, IsPOS,
          StoreID, CustomerID, SoldBy, IsDeleted, CreatedDate
        FROM ORDERS 
        WHERE IsDeleted = 0
        ORDER BY TransDate DESC
      ''';

      final response = await _client.post(
        Uri.parse('$baseUrl/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': sql}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map((item) => OrderModel.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching recent orders: $e');
      return [];
    }
  }

  /// Get order statistics
  Future<OrderStatistics> getOrderStatistics() async {
    try {
      final sql = '''
        SELECT 
          COUNT(*) as totalOrders,
          SUM(NetAmount) as totalRevenue,
          SUM(TaxAmount) as totalTax,
          AVG(NetAmount) as averageOrderValue,
          SUM(CASE WHEN OrderStatus = 6 THEN 1 ELSE 0 END) as completedOrders,
          SUM(CASE WHEN OrderStatus IN (0, 1, 2) THEN 1 ELSE 0 END) as pendingOrders
        FROM ORDERS 
        WHERE IsDeleted = 0
      ''';

      final response = await _client.post(
        Uri.parse('$baseUrl/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': sql}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true &&
            json['data'] != null &&
            (json['data'] as List).isNotEmpty) {
          return OrderStatistics.fromJson(json['data'][0]);
        }
      }
      return OrderStatistics(
        totalOrders: 0,
        totalRevenue: 0,
        totalTax: 0,
        averageOrderValue: 0,
        completedOrders: 0,
        pendingOrders: 0,
      );
    } catch (e) {
      print('Error fetching order statistics: $e');
      return OrderStatistics(
        totalOrders: 0,
        totalRevenue: 0,
        totalTax: 0,
        averageOrderValue: 0,
        completedOrders: 0,
        pendingOrders: 0,
      );
    }
  }

  /// Get orders by date range
  Future<List<OrderModel>> getOrdersByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final sql =
          '''
        SELECT 
          OrderID, OrderNumber, TransDate, TransAmount, NetAmount, 
          TaxAmount, DiscountAmount, OrderStatus, PaymentMode, IsPOS,
          StoreID, CustomerID, SoldBy, IsDeleted, CreatedDate
        FROM ORDERS 
        WHERE IsDeleted = 0
          AND TransDate >= '${startDate.toIso8601String()}'
          AND TransDate <= '${endDate.toIso8601String()}'
        ORDER BY TransDate DESC
      ''';

      final response = await _client.post(
        Uri.parse('$baseUrl/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': sql}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map((item) => OrderModel.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching orders by date range: $e');
      return [];
    }
  }

  /// Get daily sales data for charts
  Future<List<Map<String, dynamic>>> getDailySales({int days = 30}) async {
    try {
      final sql =
          '''
        SELECT 
          CAST(TransDate AS DATE) as OrderDate,
          COUNT(*) as OrderCount,
          SUM(NetAmount) as TotalSales,
          SUM(TaxAmount) as TotalTax
        FROM ORDERS 
        WHERE IsDeleted = 0
          AND TransDate >= DATEADD(day, -$days, GETDATE())
        GROUP BY CAST(TransDate AS DATE)
        ORDER BY OrderDate DESC
      ''';

      final response = await _client.post(
        Uri.parse('$baseUrl/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': sql}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return List<Map<String, dynamic>>.from(json['data']);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching daily sales: $e');
      return [];
    }
  }

  void dispose() {
    _client.close();
  }
}
