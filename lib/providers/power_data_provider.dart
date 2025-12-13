import 'package:flutter/foundation.dart';
import '../data/models/power_data_model.dart';
import '../services/api/power_data_service.dart';
import '../services/service_locator.dart';

/// Loading state enumeration
enum LoadingState { initial, loading, loaded, error }

/// Power Data Provider - State management for power operations data
class PowerDataProvider extends ChangeNotifier {
  final PowerDataService _powerDataService;

  PowerDataProvider({PowerDataService? powerDataService})
    : _powerDataService = powerDataService ?? getService<PowerDataService>();

  // State variables
  LoadingState _loadingState = LoadingState.initial;
  String? _errorMessage;

  // Data
  List<PowerDataModel> _powerDataList = [];
  List<PowerDataModel> _latestPowerData = [];
  PowerStatistics? _statistics;
  List<StationModel> _stations = [];
  Map<String, dynamic> _dashboardData = {};

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  bool _hasMoreData = true;

  // Filters
  String? _selectedStation;
  DateTime? _startDate;
  DateTime? _endDate;

  // Getters
  LoadingState get loadingState => _loadingState;
  String? get errorMessage => _errorMessage;
  List<PowerDataModel> get powerDataList => _powerDataList;
  List<PowerDataModel> get latestPowerData => _latestPowerData;
  PowerStatistics? get statistics => _statistics;
  List<StationModel> get stations => _stations;
  Map<String, dynamic> get dashboardData => _dashboardData;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalCount => _totalCount;
  bool get hasMoreData => _hasMoreData;
  String? get selectedStation => _selectedStation;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  bool get isLoading => _loadingState == LoadingState.loading;

  /// Set filter values
  void setFilters({
    String? stationName,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    _selectedStation = stationName;
    _startDate = startDate;
    _endDate = endDate;
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _selectedStation = null;
    _startDate = null;
    _endDate = null;
    notifyListeners();
  }

  /// Fetch power data with pagination
  Future<void> fetchPowerData({bool refresh = false, int pageSize = 50}) async {
    if (refresh) {
      _currentPage = 1;
      _powerDataList = [];
    }

    if (!_hasMoreData && !refresh) return;

    _loadingState = LoadingState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _powerDataService.getPowerData(
        page: _currentPage,
        pageSize: pageSize,
        stationName: _selectedStation,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (refresh) {
        _powerDataList = response.data;
      } else {
        _powerDataList = [..._powerDataList, ...response.data];
      }

      _currentPage = response.page + 1;
      _totalPages = response.totalPages;
      _totalCount = response.totalCount;
      _hasMoreData = response.hasNextPage;

      _loadingState = LoadingState.loaded;
    } catch (e) {
      _loadingState = LoadingState.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  /// Fetch latest power data (optimized for real-time display)
  Future<void> fetchLatestPowerData({int limit = 10}) async {
    try {
      _latestPowerData = await _powerDataService.getLatestPowerData(
        limit: limit,
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Fetch power statistics
  Future<void> fetchStatistics() async {
    try {
      _statistics = await _powerDataService.getPowerStatistics(
        startDate: _startDate,
        endDate: _endDate,
        stationName: _selectedStation,
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Fetch all stations
  Future<void> fetchStations() async {
    try {
      _stations = await _powerDataService.getStations();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Fetch dashboard summary
  Future<void> fetchDashboardData() async {
    _loadingState = LoadingState.loading;
    notifyListeners();

    try {
      _dashboardData = await _powerDataService.getDashboardSummary();
      _loadingState = LoadingState.loaded;
    } catch (e) {
      _loadingState = LoadingState.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  /// Load more data for infinite scroll
  Future<void> loadMore() async {
    if (_hasMoreData && _loadingState != LoadingState.loading) {
      await fetchPowerData();
    }
  }

  /// Refresh all data
  Future<void> refreshAll() async {
    _currentPage = 1;
    _hasMoreData = true;
    _powerDataList = [];

    await Future.wait([
      fetchPowerData(refresh: true),
      fetchLatestPowerData(),
      fetchStatistics(),
      fetchStations(),
    ]);
  }

  /// Cancel ongoing requests
  void cancelRequests() {
    _powerDataService.cancelOngoingRequests();
  }

  @override
  void dispose() {
    cancelRequests();
    super.dispose();
  }
}
