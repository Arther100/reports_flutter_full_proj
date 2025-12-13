import 'package:flutter/foundation.dart';
import '../data/models/power_data_model.dart';
import '../services/api/power_data_service.dart';
import '../services/service_locator.dart';

/// Chart Data Provider - State management for chart visualizations
class ChartDataProvider extends ChangeNotifier {
  final PowerDataService _powerDataService;

  ChartDataProvider({PowerDataService? powerDataService})
    : _powerDataService = powerDataService ?? getService<PowerDataService>();

  // Chart data storage
  List<ChartDataPoint> _powerChartData = [];
  List<ChartDataPoint> _voltageChartData = [];
  List<ChartDataPoint> _efficiencyChartData = [];
  List<ChartDataPoint> _currentChartData = [];

  // Loading states
  bool _isLoadingPowerChart = false;
  bool _isLoadingVoltageChart = false;
  bool _isLoadingEfficiencyChart = false;
  bool _isLoadingCurrentChart = false;

  String? _errorMessage;

  // Chart settings
  String _selectedInterval = 'hour';
  DateTime _chartStartDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _chartEndDate = DateTime.now();
  String? _selectedStation;

  // Getters
  List<ChartDataPoint> get powerChartData => _powerChartData;
  List<ChartDataPoint> get voltageChartData => _voltageChartData;
  List<ChartDataPoint> get efficiencyChartData => _efficiencyChartData;
  List<ChartDataPoint> get currentChartData => _currentChartData;

  bool get isLoadingPowerChart => _isLoadingPowerChart;
  bool get isLoadingVoltageChart => _isLoadingVoltageChart;
  bool get isLoadingEfficiencyChart => _isLoadingEfficiencyChart;
  bool get isLoadingCurrentChart => _isLoadingCurrentChart;
  bool get isAnyChartLoading =>
      _isLoadingPowerChart ||
      _isLoadingVoltageChart ||
      _isLoadingEfficiencyChart ||
      _isLoadingCurrentChart;

  String? get errorMessage => _errorMessage;
  String get selectedInterval => _selectedInterval;
  DateTime get chartStartDate => _chartStartDate;
  DateTime get chartEndDate => _chartEndDate;
  String? get selectedStation => _selectedStation;

  /// Update chart date range
  void setDateRange(DateTime start, DateTime end) {
    _chartStartDate = start;
    _chartEndDate = end;
    notifyListeners();
  }

  /// Update interval
  void setInterval(String interval) {
    _selectedInterval = interval;
    notifyListeners();
  }

  /// Update selected station
  void setStation(String? station) {
    _selectedStation = station;
    notifyListeners();
  }

  /// Fetch power chart data
  Future<void> fetchPowerChartData() async {
    _isLoadingPowerChart = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _powerChartData = await _powerDataService.getChartData(
        chartType: 'power',
        startDate: _chartStartDate,
        endDate: _chartEndDate,
        interval: _selectedInterval,
        stationName: _selectedStation,
      );
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoadingPowerChart = false;
    notifyListeners();
  }

  /// Fetch voltage chart data
  Future<void> fetchVoltageChartData() async {
    _isLoadingVoltageChart = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _voltageChartData = await _powerDataService.getChartData(
        chartType: 'voltage',
        startDate: _chartStartDate,
        endDate: _chartEndDate,
        interval: _selectedInterval,
        stationName: _selectedStation,
      );
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoadingVoltageChart = false;
    notifyListeners();
  }

  /// Fetch efficiency chart data
  Future<void> fetchEfficiencyChartData() async {
    _isLoadingEfficiencyChart = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _efficiencyChartData = await _powerDataService.getChartData(
        chartType: 'efficiency',
        startDate: _chartStartDate,
        endDate: _chartEndDate,
        interval: _selectedInterval,
        stationName: _selectedStation,
      );
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoadingEfficiencyChart = false;
    notifyListeners();
  }

  /// Fetch current chart data
  Future<void> fetchCurrentChartData() async {
    _isLoadingCurrentChart = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentChartData = await _powerDataService.getChartData(
        chartType: 'current',
        startDate: _chartStartDate,
        endDate: _chartEndDate,
        interval: _selectedInterval,
        stationName: _selectedStation,
      );
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoadingCurrentChart = false;
    notifyListeners();
  }

  /// Fetch all chart data in parallel for fast loading
  Future<void> fetchAllChartData() async {
    await Future.wait([
      fetchPowerChartData(),
      fetchVoltageChartData(),
      fetchEfficiencyChartData(),
      fetchCurrentChartData(),
    ]);
  }

  /// Refresh all charts with current settings
  Future<void> refreshCharts() async {
    await fetchAllChartData();
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
