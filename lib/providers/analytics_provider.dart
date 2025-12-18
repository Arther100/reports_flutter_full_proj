import 'package:flutter/foundation.dart';
import '../data/models/analytics_model.dart';
import '../services/analytics_service.dart';

class AnalyticsProvider with ChangeNotifier {
  final AnalyticsService _service = AnalyticsService();

  AnalyticsDashboard _dashboard = AnalyticsDashboard.empty();
  bool _isLoading = false;
  String? _error;
  DateRangeFilter _currentFilter = DateRangeFilter.last365Days();

  // Store filter
  List<Store> _allStores = [];
  List<Store> _selectedStores = [];
  bool _isStoresLoading = false;

  // Separate loading states for different sections
  bool _isSalesLoading = false;
  bool _isProductsLoading = false;
  final bool _isCustomersLoading = false;
  bool _isPredictionsLoading = false;
  final bool _isStoreTypesLoading = false;
  bool _isDrillDownLoading = false;

  // Store type and customer type summaries
  List<StoreTypeSummary> _storeTypeSummaries = [];
  List<CustomerTypeSummary> _customerTypeSummaries = [];
  DrillDownData? _currentDrillDown;

  // Getters
  AnalyticsDashboard get dashboard => _dashboard;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateRangeFilter get currentFilter => _currentFilter;

  // Store filter getters
  List<Store> get allStores => _allStores;
  List<Store> get selectedStores => _selectedStores;
  bool get isStoresLoading => _isStoresLoading;
  bool get hasStoreFilter => _selectedStores.isNotEmpty;
  List<String> get selectedStoreIds =>
      _selectedStores.map((s) => s.storeId).toList();

  bool get isSalesLoading => _isSalesLoading;
  bool get isProductsLoading => _isProductsLoading;
  bool get isCustomersLoading => _isCustomersLoading;
  bool get isPredictionsLoading => _isPredictionsLoading;
  bool get isStoreTypesLoading => _isStoreTypesLoading;
  bool get isDrillDownLoading => _isDrillDownLoading;

  // Store and customer type getters
  List<StoreTypeSummary> get storeTypeSummaries => _storeTypeSummaries;
  List<CustomerTypeSummary> get customerTypeSummaries => _customerTypeSummaries;
  DrillDownData? get currentDrillDown => _currentDrillDown;

  // Quick access getters
  SalesOverview get salesOverview => _dashboard.salesOverview;
  List<SalesTrend> get salesTrend => _dashboard.salesTrend;
  List<ProductSales> get topProducts => _dashboard.topProducts;
  List<CategorySales> get categorySales => _dashboard.categorySales;
  List<PaymentAnalytics> get paymentAnalytics => _dashboard.paymentAnalytics;
  List<CustomerAnalytics> get topCustomers => _dashboard.topCustomers;
  List<StoreSales> get storeSales => _dashboard.storeSales;
  List<HourlySales> get hourlySales => _dashboard.hourlySales;
  List<SalesPrediction> get salesPredictions => _dashboard.salesPredictions;
  List<ProductPrediction> get productPredictions =>
      _dashboard.productPredictions;
  OverallFillRate? get fillRate => _dashboard.fillRate;

  // Load stores list
  Future<void> loadStores() async {
    if (_allStores.isNotEmpty) return; // Already loaded

    _isStoresLoading = true;
    notifyListeners();

    try {
      _allStores = await _service.getAllStores();
    } catch (e) {
      print('Error loading stores: $e');
    } finally {
      _isStoresLoading = false;
      notifyListeners();
    }
  }

  // Toggle store selection
  void toggleStoreSelection(Store store) {
    if (_selectedStores.contains(store)) {
      _selectedStores.remove(store);
    } else {
      _selectedStores.add(store);
    }
    notifyListeners();
  }

  // Select all stores
  void selectAllStores() {
    _selectedStores = List.from(_allStores);
    notifyListeners();
  }

  // Clear store selection
  void clearStoreSelection() {
    _selectedStores.clear();
    notifyListeners();
  }

  // Apply store filter and reload data
  Future<void> applyStoreFilter() async {
    await loadDashboard();
  }

  // Load all dashboard data
  Future<void> loadDashboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load stores if not loaded
      if (_allStores.isEmpty) {
        _allStores = await _service.getAllStores();
      }

      // Load main dashboard data and store/customer summaries in parallel
      final results = await Future.wait([
        _service.getDashboardData(_currentFilter, storeIds: selectedStoreIds),
        _service.getStoreTypeSummary(
          _currentFilter,
          storeIds: selectedStoreIds,
        ),
        _service.getCustomerTypeSummary(
          _currentFilter,
          storeIds: selectedStoreIds,
        ),
      ]);

      _dashboard = results[0] as AnalyticsDashboard;
      _storeTypeSummaries = results[1] as List<StoreTypeSummary>;
      _customerTypeSummaries = results[2] as List<CustomerTypeSummary>;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load drill-down data for a store type
  Future<void> loadStoreTypeDrillDown(StoreType type) async {
    _isDrillDownLoading = true;
    notifyListeners();

    try {
      _currentDrillDown = await _service.getStoreTypeDrillDown(
        type,
        _currentFilter,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isDrillDownLoading = false;
      notifyListeners();
    }
  }

  // Clear drill-down data
  void clearDrillDown() {
    _currentDrillDown = null;
    notifyListeners();
  }

  // Load with new filter
  Future<void> applyFilter(DateRangeFilter filter) async {
    _currentFilter = filter;
    await loadDashboard();
  }

  // Quick filter methods
  Future<void> filterToday() => applyFilter(DateRangeFilter.today());
  Future<void> filterYesterday() => applyFilter(DateRangeFilter.yesterday());
  Future<void> filterThisWeek() => applyFilter(DateRangeFilter.thisWeek());
  Future<void> filterLastWeek() => applyFilter(DateRangeFilter.lastWeek());
  Future<void> filterThisMonth() => applyFilter(DateRangeFilter.thisMonth());
  Future<void> filterLastMonth() => applyFilter(DateRangeFilter.lastMonth());
  Future<void> filterThisQuarter() =>
      applyFilter(DateRangeFilter.thisQuarter());
  Future<void> filterThisYear() => applyFilter(DateRangeFilter.thisYear());
  Future<void> filterLast7Days() => applyFilter(DateRangeFilter.last7Days());
  Future<void> filterLast30Days() => applyFilter(DateRangeFilter.last30Days());
  Future<void> filterLast365Days() =>
      applyFilter(DateRangeFilter.last365Days());
  Future<void> filterAllTime() => applyFilter(DateRangeFilter.allTime());

  Future<void> filterCustom(DateTime start, DateTime end) =>
      applyFilter(DateRangeFilter.custom(start, end));

  // Refresh specific sections (for incremental loading)
  Future<void> refreshSalesOverview() async {
    _isSalesLoading = true;
    notifyListeners();

    try {
      final overview = await _service.getSalesOverview(_currentFilter);
      _dashboard = AnalyticsDashboard(
        salesOverview: overview,
        salesTrend: _dashboard.salesTrend,
        topProducts: _dashboard.topProducts,
        categorySales: _dashboard.categorySales,
        paymentAnalytics: _dashboard.paymentAnalytics,
        topCustomers: _dashboard.topCustomers,
        storeSales: _dashboard.storeSales,
        hourlySales: _dashboard.hourlySales,
        salesPredictions: _dashboard.salesPredictions,
        productPredictions: _dashboard.productPredictions,
        fillRate: _dashboard.fillRate,
        dateFilter: _currentFilter,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isSalesLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshTopProducts() async {
    _isProductsLoading = true;
    notifyListeners();

    try {
      final products = await _service.getTopProducts(_currentFilter);
      _dashboard = AnalyticsDashboard(
        salesOverview: _dashboard.salesOverview,
        salesTrend: _dashboard.salesTrend,
        topProducts: products,
        categorySales: _dashboard.categorySales,
        paymentAnalytics: _dashboard.paymentAnalytics,
        topCustomers: _dashboard.topCustomers,
        storeSales: _dashboard.storeSales,
        hourlySales: _dashboard.hourlySales,
        salesPredictions: _dashboard.salesPredictions,
        productPredictions: _dashboard.productPredictions,
        fillRate: _dashboard.fillRate,
        dateFilter: _currentFilter,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isProductsLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshPredictions() async {
    _isPredictionsLoading = true;
    notifyListeners();

    try {
      final productPreds = await _service.generateProductPredictions(
        _currentFilter,
      );
      final salesPreds = _service.generateSalesPredictions(
        _dashboard.salesTrend,
      );

      _dashboard = AnalyticsDashboard(
        salesOverview: _dashboard.salesOverview,
        salesTrend: _dashboard.salesTrend,
        topProducts: _dashboard.topProducts,
        categorySales: _dashboard.categorySales,
        paymentAnalytics: _dashboard.paymentAnalytics,
        topCustomers: _dashboard.topCustomers,
        storeSales: _dashboard.storeSales,
        hourlySales: _dashboard.hourlySales,
        salesPredictions: salesPreds,
        productPredictions: productPreds,
        fillRate: _dashboard.fillRate,
        dateFilter: _currentFilter,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isPredictionsLoading = false;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
