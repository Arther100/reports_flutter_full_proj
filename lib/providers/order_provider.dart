import 'package:flutter/foundation.dart';
import '../data/models/order_model.dart';
import '../services/api/order_service.dart';

/// Order Provider - State management for Orders
class OrderProvider extends ChangeNotifier {
  final OrderService _orderService;

  List<OrderModel> _orders = [];
  OrderStatistics? _statistics;
  List<Map<String, dynamic>> _dailySales = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;

  OrderProvider({OrderService? orderService})
    : _orderService = orderService ?? OrderService();

  // Getters
  List<OrderModel> get orders => _orders;
  OrderStatistics? get statistics => _statistics;
  List<Map<String, dynamic>> get dailySales => _dailySales;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  /// Load initial orders
  Future<void> loadOrders({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _orders = [];
    }

    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newOrders = await _orderService.getOrders(
        page: _currentPage,
        pageSize: 50,
      );

      if (newOrders.isEmpty) {
        _hasMore = false;
      } else {
        if (refresh) {
          _orders = newOrders;
        } else {
          _orders.addAll(newOrders);
        }
        _currentPage++;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load more orders (pagination)
  Future<void> loadMoreOrders() async {
    if (!_hasMore || _isLoading) return;
    await loadOrders();
  }

  /// Refresh orders
  Future<void> refreshOrders() async {
    await loadOrders(refresh: true);
  }

  /// Load order statistics
  Future<void> loadStatistics() async {
    try {
      _statistics = await _orderService.getOrderStatistics();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Load daily sales for charts
  Future<void> loadDailySales({int days = 30}) async {
    try {
      _dailySales = await _orderService.getDailySales(days: days);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Load all data (orders + statistics + daily sales)
  Future<void> loadAllData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        loadOrders(refresh: true),
        loadStatistics(),
        loadDailySales(),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get recent orders for dashboard
  Future<List<OrderModel>> getRecentOrders({int limit = 5}) async {
    try {
      return await _orderService.getRecentOrders(limit: limit);
    } catch (e) {
      return [];
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _orderService.dispose();
    super.dispose();
  }
}
