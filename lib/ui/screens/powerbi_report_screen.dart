import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../data/models/powerbi_models.dart';
import '../../services/api/powerbi_service.dart';
import '../../providers/database_provider.dart';
import '../widgets/hierarchical_data_table.dart';
import '../widgets/interactive_pie_chart.dart';
import '../widgets/liquid_fill_gauge.dart';
import '../widgets/category_gauge_chart.dart';
import '../widgets/sales_trend_chart.dart';
import '../widgets/cubie_chatbot.dart';
import '../widgets/powerbi_shimmer_loading.dart';
import 'package:intl/intl.dart';

class PowerBIReportScreen extends StatefulWidget {
  const PowerBIReportScreen({super.key});

  @override
  State<PowerBIReportScreen> createState() => _PowerBIReportScreenState();
}

class _PowerBIReportScreenState extends State<PowerBIReportScreen> {
  final PowerBIService _powerBIService = PowerBIService();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
  );

  List<PowerBICategory> _categories = [];
  List<PowerBIStore> _stores = [];
  Set<String> _selectedStores = {};
  Set<String> _selectedCategories = {};
  PowerBISummary? _summary;
  DynamicDateRange _dateRange = DynamicDateRange.lastNMonths(6);
  String _selectedDuration = 'Last 6 Months';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isLoading = false;
  String? _error;
  String? _lastDatabaseId;

  // Report selection
  String _selectedReport = 'Sales Trend Report';
  final List<String> _reportTypes = ['Sales Trend Report', 'Discount Report'];

  // Sales trend data
  List<SalesTrendData> _salesTrendData = [];

  // Discount report data
  List<Map<String, dynamic>> _discountData = [];
  Map<String, dynamic>? _discountSummary;

  // Drill-down state for discount report
  String? _drillDownType; // 'type' or 'store'
  Map<String, dynamic>? _drillDownItem;
  List<Map<String, dynamic>> _drillDownDetails = [];
  bool _isDrillDownLoading = false;

  @override
  void initState() {
    super.initState();
    // Don't load data in initState - wait for didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dbProvider = context.watch<DatabaseProvider>();

    // Check if database changed and reload data
    if (dbProvider.isPowerBIDatabase &&
        dbProvider.currentDatabase?.id != _lastDatabaseId) {
      _lastDatabaseId = dbProvider.currentDatabase?.id;
      // Reset and reload if database changed
      if (_stores.isNotEmpty) {
        setState(() {
          _stores = [];
          _categories = [];
          _selectedStores = {};
          _summary = null;
        });
      }
      // Defer loading to not block UI
      Future.microtask(() => _loadInitialData());
    } else if (dbProvider.isPowerBIDatabase && !_isLoading && _stores.isEmpty) {
      // Initial load - defer to not block first frame
      _lastDatabaseId = dbProvider.currentDatabase?.id;
      Future.microtask(() => _loadInitialData());
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load available stores
      final stores = await _powerBIService.getStores();

      // Select all stores by default
      final selectedStores = stores.map((s) => s.storeId).toSet();

      setState(() {
        _stores = stores;
        _selectedStores = selectedStores;
      });

      // Load report data
      await _loadReportData();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReportData() async {
    if (_selectedStores.isEmpty) {
      setState(() {
        _categories = [];
        _summary = null;
        _salesTrendData = [];
        _discountData = [];
        _discountSummary = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_selectedReport == 'Sales Trend Report') {
        final results = await Future.wait([
          _powerBIService.getCategoryStoreSales(
            dateRange: _dateRange,
            storeIds: _selectedStores.toList(),
          ),
          _powerBIService.getSummary(
            dateRange: _dateRange,
            storeIds: _selectedStores.toList(),
          ),
          _powerBIService.getCategorySalesTrend(
            dateRange: _dateRange,
            storeIds: _selectedStores.toList(),
          ),
        ]);

        // Convert category sales to SalesTrendData (using index as pseudo-date for display)
        final categorySalesData = results[2] as List<Map<String, dynamic>>;
        final trendData = categorySalesData.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final categoryName = row['CategoryName']?.toString() ?? 'Unknown';
          final sales = _parseDouble(row['TotalSales']);
          final orders = _parseInt(row['TotalOrders']);

          // Use a pseudo date (index-based) for positioning on chart
          final baseDate = DateTime.now().subtract(
            Duration(days: categorySalesData.length - index - 1),
          );

          return SalesTrendData(
            date: baseDate,
            sales: sales,
            orders: orders,
            label: categoryName,
          );
        }).toList();

        print('Category Sales Data loaded: ${trendData.length} categories');
        if (trendData.isNotEmpty) {
          print(
            'First: ${trendData.first.label} - Sales: ${trendData.first.sales}',
          );
          print(
            'Last: ${trendData.last.label} - Sales: ${trendData.last.sales}',
          );
        }

        setState(() {
          _categories = results[0] as List<PowerBICategory>;
          _summary = results[1] as PowerBISummary;
          _salesTrendData = trendData;
          _isLoading = false;
        });
      } else if (_selectedReport == 'Discount Report') {
        await _loadDiscountData();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Additional discount report data
  List<Map<String, dynamic>> _discountByType = [];
  List<Map<String, dynamic>> _discountByStore = [];

  Future<void> _loadDiscountData() async {
    try {
      final dates = _dateRange.getDateRange();
      final startDate = dates['start']!.toIso8601String().split('T')[0];
      final endDate = dates['end']!.toIso8601String().split('T')[0];

      // Query for discount data by store from Discounts table joined with Orders
      final discountByStoreQuery =
          '''
        SELECT 
          d.store as StoreID,
          ISNULL(a.name, d.store) as StoreName,
          COUNT(DISTINCT d.orderId) as TotalOrders,
          COUNT(*) as DiscountCount,
          SUM(CAST(ISNULL(d.totalDiscountAmountStr, '0') AS DECIMAL(18,2))) as TotalDiscount,
          SUM(CAST(ISNULL(d.totalDiscountsStr, '0') AS DECIMAL(18,2))) as TotalDiscounts
        FROM Discounts d
        LEFT JOIN allstoresdetails a ON d.store = a.id
        WHERE CONVERT(date, d.saleDate) >= '$startDate' 
          AND CONVERT(date, d.saleDate) <= '$endDate'
          AND d.store IS NOT NULL
        GROUP BY d.store, a.name
        ORDER BY TotalDiscount DESC
      ''';

      // Query for discount data by discount type/name
      final discountByTypeQuery =
          '''
        SELECT 
          ISNULL(d.discountName, 'Unknown') as DiscountName,
          d.discountType,
          COUNT(*) as TimesApplied,
          COUNT(DISTINCT d.orderId) as OrdersAffected,
          SUM(CAST(ISNULL(d.totalDiscountAmountStr, '0') AS DECIMAL(18,2))) as TotalAmount,
          SUM(CAST(ISNULL(d.quantity, 0) AS INT)) as TotalQuantity
        FROM Discounts d
        WHERE CONVERT(date, d.saleDate) >= '$startDate' 
          AND CONVERT(date, d.saleDate) <= '$endDate'
        GROUP BY d.discountName, d.discountType
        ORDER BY TotalAmount DESC
      ''';

      // Query for overall summary - get discount totals
      final summaryQuery =
          '''
        SELECT 
          COUNT(DISTINCT d.orderId) as TotalOrders,
          COUNT(*) as TotalDiscountApplications,
          SUM(CAST(ISNULL(d.totalDiscountAmountStr, '0') AS DECIMAL(18,2))) as TotalDiscountAmount,
          COUNT(DISTINCT d.discountName) as UniqueDiscounts,
          COUNT(DISTINCT d.store) as StoresWithDiscounts
        FROM Discounts d
        WHERE CONVERT(date, d.saleDate) >= '$startDate' 
          AND CONVERT(date, d.saleDate) <= '$endDate'
      ''';

      // Query for gross sales from Orders table
      final grossSalesQuery =
          '''
        SELECT 
          SUM(CAST(ISNULL(totalStr, '0') AS DECIMAL(18,2))) as GrossSales
        FROM Orders
        WHERE CONVERT(date, orderDate) >= '$startDate' 
          AND CONVERT(date, orderDate) <= '$endDate'
      ''';

      // Execute all queries
      final results = await Future.wait([
        _powerBIService.executeCustomQuery(discountByStoreQuery),
        _powerBIService.executeCustomQuery(discountByTypeQuery),
        _powerBIService.executeCustomQuery(summaryQuery),
        _powerBIService.executeCustomQuery(grossSalesQuery),
      ]);

      final discountByStoreData = results[0];
      final discountByTypeData = results[1];
      final summaryData = results[2];
      final grossSalesData = results[3];

      // Calculate totals
      double totalDiscount = 0;
      int totalOrders = 0;
      int totalApplications = 0;
      double grossSales = 0;

      for (final row in discountByStoreData) {
        totalDiscount += _parseDouble(row['TotalDiscount']);
        totalOrders += _parseInt(row['TotalOrders']);
      }

      if (summaryData.isNotEmpty) {
        totalApplications = _parseInt(
          summaryData.first['TotalDiscountApplications'],
        );
        // Use discount amount from summary if available
        final summaryDiscount = _parseDouble(
          summaryData.first['TotalDiscountAmount'],
        );
        if (summaryDiscount > 0) {
          totalDiscount = summaryDiscount;
        }
      }

      if (grossSalesData.isNotEmpty) {
        grossSales = _parseDouble(grossSalesData.first['GrossSales']);
      }

      // Calculate net sales and discount rate
      final netSales = grossSales - totalDiscount;
      final discountRate = grossSales > 0
          ? (totalDiscount / grossSales * 100)
          : 0.0;

      setState(() {
        _discountByStore = discountByStoreData;
        _discountByType = discountByTypeData;
        _discountData = discountByStoreData; // Keep for backward compatibility
        _discountSummary = {
          'totalDiscount': totalDiscount,
          'totalGrossSales': grossSales,
          'totalNetSales': netSales,
          'discountRate': discountRate,
          'totalOrders': totalOrders,
          'totalApplications': totalApplications,
          'uniqueDiscounts': summaryData.isNotEmpty
              ? _parseInt(summaryData.first['UniqueDiscounts'])
              : 0,
          'storesWithDiscounts': summaryData.isNotEmpty
              ? _parseInt(summaryData.first['StoresWithDiscounts'])
              : 0,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // Drill-down functionality for discount report
  Future<void> _loadDrillDownDetails(
    String type,
    Map<String, dynamic> item,
  ) async {
    setState(() {
      _drillDownType = type;
      _drillDownItem = item;
      _isDrillDownLoading = true;
    });

    try {
      final dates = _dateRange.getDateRange();
      final startDate = dates['start']!.toIso8601String().split('T')[0];
      final endDate = dates['end']!.toIso8601String().split('T')[0];

      String query;
      if (type == 'type') {
        // Drill down by discount type - show orders and stores using this discount
        final discountName = item['DiscountName']?.toString() ?? '';
        query =
            '''
          SELECT 
            d.orderId as OrderID,
            ISNULL(a.name, d.store) as StoreName,
            d.saleDate as SaleDate,
            d.quantity as Quantity,
            CAST(ISNULL(d.totalDiscountAmountStr, '0') AS DECIMAL(18,2)) as DiscountAmount,
            d.discountType as DiscountType
          FROM Discounts d
          LEFT JOIN allstoresdetails a ON d.store = a.id
          WHERE d.discountName = '$discountName'
            AND CONVERT(date, d.saleDate) >= '$startDate' 
            AND CONVERT(date, d.saleDate) <= '$endDate'
          ORDER BY d.saleDate DESC
        ''';
      } else {
        // Drill down by store - show all discounts for this store
        final storeId = item['StoreID']?.toString() ?? '';
        query =
            '''
          SELECT 
            ISNULL(d.discountName, 'Unknown') as DiscountName,
            d.discountType as DiscountType,
            COUNT(*) as TimesApplied,
            COUNT(DISTINCT d.orderId) as OrdersAffected,
            SUM(CAST(ISNULL(d.totalDiscountAmountStr, '0') AS DECIMAL(18,2))) as TotalAmount
          FROM Discounts d
          WHERE d.store = '$storeId'
            AND CONVERT(date, d.saleDate) >= '$startDate' 
            AND CONVERT(date, d.saleDate) <= '$endDate'
          GROUP BY d.discountName, d.discountType
          ORDER BY TotalAmount DESC
        ''';
      }

      final results = await _powerBIService.executeCustomQuery(query);

      setState(() {
        _drillDownDetails = results;
        _isDrillDownLoading = false;
      });

      // Show the drill-down dialog
      _showDrillDownDialog();
    } catch (e) {
      setState(() {
        _isDrillDownLoading = false;
        _drillDownType = null;
        _drillDownItem = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading details: $e')));
    }
  }

  void _closeDrillDown() {
    setState(() {
      _drillDownType = null;
      _drillDownItem = null;
      _drillDownDetails = [];
    });
  }

  void _showDrillDownDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: _buildDrillDownDialog(),
      ),
    );
  }

  Widget _buildDrillDownDialog() {
    final isTypeView = _drillDownType == 'type';
    final String title;
    if (isTypeView) {
      title = _drillDownItem?['DiscountName']?.toString() ?? 'Discount Details';
    } else {
      title = _drillDownItem?['StoreName']?.toString() ?? 'Store Details';
    }

    final String subtitle;
    if (isTypeView) {
      subtitle = 'Usage Details & Transactions';
    } else {
      subtitle = 'Discounts Applied at This Store';
    }

    final Color primaryColor;
    if (isTypeView) {
      primaryColor = const Color(0xFF1E5F8A);
    } else {
      primaryColor = const Color(0xFF6B8E4E);
    }

    final List<Color> gradientColors;
    if (isTypeView) {
      gradientColors = [const Color(0xFF1E5F8A), const Color(0xFF4A90A4)];
    } else {
      gradientColors = [const Color(0xFF6B8E4E), const Color(0xFF8EAD6E)];
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 24,
      insetPadding: EdgeInsets.all(isMobile ? 12 : 24),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: isMobile ? screenWidth * 0.95 : screenWidth * 0.8,
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.85,
          maxWidth: 900,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gradient Header - responsive
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Icon with animation effect
                        Container(
                          padding: EdgeInsets.all(isMobile ? 8 : 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isTypeView ? Icons.local_offer : Icons.store,
                            color: Colors.white,
                            size: isMobile ? 20 : 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: isMobile ? 16 : 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: isMobile ? 12 : 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Close button
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Summary stats - wrap to new row on mobile
                    if (!isMobile) ...[
                      const SizedBox(height: 12),
                      _buildDrillDownHeaderStats(isTypeView),
                    ],
                    if (isMobile) ...[
                      const SizedBox(height: 8),
                      _buildDrillDownHeaderStatsMobile(isTypeView),
                    ],
                  ],
                ),
              ),
              // Content
              Expanded(
                child: _isDrillDownLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: primaryColor),
                            const SizedBox(height: 16),
                            Text(
                              'Loading details...',
                              style: TextStyle(color: Colors.black),
                            ),
                          ],
                        ),
                      )
                    : _drillDownDetails.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No detailed data available',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      )
                    : isTypeView
                    ? _buildTypeDrillDownContent(primaryColor, isMobile)
                    : _buildStoreDrillDownContent(primaryColor, isMobile),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrillDownHeaderStats(bool isTypeView) {
    if (isTypeView && _drillDownItem != null) {
      final totalAmount = _parseDouble(_drillDownItem!['TotalAmount']);
      final timesApplied = _parseInt(_drillDownItem!['TimesApplied']);
      return Row(
        children: [
          _buildHeaderStatBadge(
            'Total Amount',
            _currencyFormat.format(totalAmount),
            Icons.attach_money,
          ),
          const SizedBox(width: 12),
          _buildHeaderStatBadge(
            'Times Applied',
            timesApplied.toString(),
            Icons.replay,
          ),
        ],
      );
    } else if (_drillDownItem != null) {
      final totalDiscount = _parseDouble(_drillDownItem!['TotalDiscount']);
      final totalOrders = _parseInt(_drillDownItem!['TotalOrders']);
      return Row(
        children: [
          _buildHeaderStatBadge(
            'Total Discounts',
            _currencyFormat.format(totalDiscount),
            Icons.discount,
          ),
          const SizedBox(width: 12),
          _buildHeaderStatBadge(
            'Orders',
            totalOrders.toString(),
            Icons.receipt_long,
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildHeaderStatBadge(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrillDownHeaderStatsMobile(bool isTypeView) {
    if (isTypeView && _drillDownItem != null) {
      final totalAmount = _parseDouble(_drillDownItem!['TotalAmount']);
      final timesApplied = _parseInt(_drillDownItem!['TimesApplied']);
      return Row(
        children: [
          Expanded(
            child: _buildCompactStatBadge(
              'Total Amount',
              _currencyFormat.format(totalAmount),
              Icons.attach_money,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCompactStatBadge(
              'Times Applied',
              timesApplied.toString(),
              Icons.replay,
            ),
          ),
        ],
      );
    } else if (_drillDownItem != null) {
      final totalDiscount = _parseDouble(_drillDownItem!['TotalDiscount']);
      final totalOrders = _parseInt(_drillDownItem!['TotalOrders']);
      return Row(
        children: [
          Expanded(
            child: _buildCompactStatBadge(
              'Total Discounts',
              _currencyFormat.format(totalDiscount),
              Icons.discount,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCompactStatBadge(
              'Orders',
              totalOrders.toString(),
              Icons.receipt_long,
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCompactStatBadge(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeDrillDownContent(Color primaryColor, bool isMobile) {
    // Group by store for visualization
    final Map<String, double> byStore = {};
    for (var detail in _drillDownDetails) {
      final store = detail['StoreName']?.toString() ?? 'Unknown';
      final amount = _parseDouble(detail['DiscountAmount']);
      byStore[store] = (byStore[store] ?? 0) + amount;
    }
    final storeEntries = byStore.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxStoreValue = storeEntries.isEmpty ? 1.0 : storeEntries.first.value;

    // Store breakdown widget
    Widget storeBreakdownWidget = Container(
      margin: EdgeInsets.all(isMobile ? 12 : 20),
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.store, color: primaryColor, size: isMobile ? 16 : 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Discount Amount by Store',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(
            storeEntries.length > (isMobile ? 5 : 10)
                ? (isMobile ? 5 : 10)
                : storeEntries.length,
            (index) {
              final entry = storeEntries[index];
              final percentage = (entry.value / maxStoreValue).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(entry.value),
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 13,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: percentage,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor,
                                  primaryColor.withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );

    // Transactions widget
    Widget transactionsWidget = Container(
      margin: EdgeInsets.fromLTRB(
        isMobile ? 12 : 0,
        isMobile ? 0 : 20,
        isMobile ? 12 : 20,
        isMobile ? 12 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: primaryColor,
                  size: isMobile ? 16 : 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_drillDownDetails.length} records',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 10 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Simplified mobile transactions list
          if (isMobile)
            ...List.generate(
              _drillDownDetails.length > 10 ? 10 : _drillDownDetails.length,
              (index) {
                final row = _drillDownDetails[index];
                final store = row['StoreName']?.toString() ?? '-';
                final date = row['SaleDate']?.toString().split('T')[0] ?? '-';
                final amount = _parseDouble(row['DiscountAmount']);

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: index.isEven ? Colors.white : Colors.grey[50],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _currencyFormat.format(amount),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          else ...[
            // Desktop table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      'Order ID',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Store',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      'Date',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      'Qty',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      'Amount',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            // Desktop table rows
            ...List.generate(
              _drillDownDetails.length > 50 ? 50 : _drillDownDetails.length,
              (index) {
                final row = _drillDownDetails[index];
                final orderId = row['OrderID']?.toString() ?? '-';
                final store = row['StoreName']?.toString() ?? '-';
                final date = row['SaleDate']?.toString().split('T')[0] ?? '-';
                final qty = _parseInt(row['Quantity']);
                final amount = _parseDouble(row['DiscountAmount']);

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: index.isEven ? Colors.white : Colors.grey[50],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          orderId.length > 8
                              ? '${orderId.substring(0, 8)}...'
                              : orderId,
                          style: TextStyle(fontSize: 13, color: Colors.black),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          store,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          date,
                          style: TextStyle(fontSize: 13, color: Colors.black),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          qty.toString(),
                          style: const TextStyle(fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          _currencyFormat.format(amount),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );

    if (isMobile) {
      // Vertical layout for mobile
      return SingleChildScrollView(
        child: Column(children: [storeBreakdownWidget, transactionsWidget]),
      );
    }

    // Horizontal layout for desktop - fixed height with internal scroll
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Store breakdown chart (fixed)
        Expanded(
          flex: 4,
          child: SingleChildScrollView(child: storeBreakdownWidget),
        ),
        // Right: Recent transactions with scrollable list
        Expanded(
          flex: 6,
          child: Container(
            margin: const EdgeInsets.fromLTRB(0, 20, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                // Fixed header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long, color: primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Recent Transactions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_drillDownDetails.length} records',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Fixed table header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Order ID',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Store',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Date',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          'Qty',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Amount',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                // Scrollable list
                Expanded(
                  child: ListView.builder(
                    itemCount: _drillDownDetails.length,
                    itemBuilder: (context, index) {
                      final row = _drillDownDetails[index];
                      final orderId = row['OrderID']?.toString() ?? '-';
                      final store = row['StoreName']?.toString() ?? '-';
                      final date =
                          row['SaleDate']?.toString().split('T')[0] ?? '-';
                      final qty = _parseInt(row['Quantity']);
                      final amount = _parseDouble(row['DiscountAmount']);

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: index.isEven ? Colors.white : Colors.grey[50],
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                orderId.length > 8
                                    ? '${orderId.substring(0, 8)}...'
                                    : orderId,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                store,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text(
                                date,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                qty.toString(),
                                style: const TextStyle(fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text(
                                _currencyFormat.format(amount),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreDrillDownContent(Color primaryColor, bool isMobile) {
    // Calculate totals for pie chart
    final total = _drillDownDetails.fold<double>(
      0,
      (sum, row) => sum + _parseDouble(row['TotalAmount']),
    );
    final maxValue = _drillDownDetails.isEmpty
        ? 1.0
        : _drillDownDetails.fold<double>(
            0,
            (max, row) => max > _parseDouble(row['TotalAmount'])
                ? max
                : _parseDouble(row['TotalAmount']),
          );

    final colors = [
      const Color(0xFF6B8E4E),
      const Color(0xFF8EAD6E),
      const Color(0xFFAAC98E),
      const Color(0xFF4A7A3D),
      const Color(0xFF5D9A4D),
      const Color(0xFF7CB86D),
    ];

    // Donut chart widget
    Widget donutChartWidget = Container(
      margin: EdgeInsets.all(isMobile ? 12 : 20),
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart,
                color: primaryColor,
                size: isMobile ? 16 : 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Discount Distribution',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: isMobile ? 120 : 180,
            child: _drillDownDetails.isEmpty
                ? const Center(child: Text('No data'))
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size(isMobile ? 120 : 180, isMobile ? 120 : 180),
                        painter: _DonutChartPainter(
                          data: _drillDownDetails
                              .take(6)
                              .map((r) => _parseDouble(r['TotalAmount']))
                              .toList(),
                          colors: colors,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_drillDownDetails.length}',
                            style: TextStyle(
                              fontSize: isMobile ? 24 : 32,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          Text(
                            'Discounts',
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 12,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: _drillDownDetails.take(6).toList().asMap().entries.map((
              entry,
            ) {
              final name = entry.value['DiscountName']?.toString() ?? 'Unknown';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors[entry.key % colors.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    name.length > (isMobile ? 10 : 15)
                        ? '${name.substring(0, isMobile ? 10 : 15)}...'
                        : name,
                    style: TextStyle(fontSize: isMobile ? 10 : 11),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );

    // Discount list widget
    Widget discountListWidget = Container(
      margin: EdgeInsets.fromLTRB(
        isMobile ? 12 : 0,
        isMobile ? 0 : 20,
        isMobile ? 12 : 20,
        isMobile ? 12 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_offer,
                  color: primaryColor,
                  size: isMobile ? 16 : 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All Discounts Applied',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                Text(
                  'Total: ${_currencyFormat.format(total)}',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
          // Simplified mobile list
          if (isMobile)
            ...List.generate(
              _drillDownDetails.length > 10 ? 10 : _drillDownDetails.length,
              (index) {
                final row = _drillDownDetails[index];
                final name = row['DiscountName']?.toString() ?? 'Unknown';
                final timesApplied = _parseInt(row['TimesApplied']);
                final amount = _parseDouble(row['TotalAmount']);
                final barWidth = (amount / maxValue).clamp(0.0, 1.0);

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: index.isEven ? Colors.white : Colors.grey[50],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _currencyFormat.format(amount),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Applied: $timesApplied',
                            style: TextStyle(fontSize: 10, color: Colors.black),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Stack(
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: barWidth,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor,
                                    primaryColor.withValues(alpha: 0.6),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            )
          else ...[
            // Desktop table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Discount Name',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      'Applied',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      'Orders',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      'Amount',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            // Desktop table rows
            ...List.generate(
              _drillDownDetails.length > 20 ? 20 : _drillDownDetails.length,
              (index) {
                final row = _drillDownDetails[index];
                final name = row['DiscountName']?.toString() ?? 'Unknown';
                final timesApplied = _parseInt(row['TimesApplied']);
                final orders = _parseInt(row['OrdersAffected']);
                final amount = _parseDouble(row['TotalAmount']);
                final barWidth = (amount / maxValue).clamp(0.0, 1.0);

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: index.isEven ? Colors.white : Colors.grey[50],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              timesApplied.toString(),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: Text(
                              orders.toString(),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: Text(
                              _currencyFormat.format(amount),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: barWidth,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor,
                                    primaryColor.withValues(alpha: 0.6),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );

    if (isMobile) {
      // Vertical layout for mobile
      return SingleChildScrollView(
        child: Column(children: [donutChartWidget, discountListWidget]),
      );
    }

    // Horizontal layout for desktop - fixed height with internal scroll
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Donut chart (fixed)
        Expanded(
          flex: 4,
          child: SingleChildScrollView(child: donutChartWidget),
        ),
        // Right: Discount list with scrollable content
        Expanded(
          flex: 6,
          child: Container(
            margin: const EdgeInsets.fromLTRB(0, 20, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                // Fixed header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_offer, color: primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'All Discounts Applied',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Text(
                        'Total: ${_currencyFormat.format(total)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Fixed table header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Discount Name',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          'Applied',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: Text(
                          'Orders',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Amount',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                // Scrollable list
                Expanded(
                  child: ListView.builder(
                    itemCount: _drillDownDetails.length,
                    itemBuilder: (context, index) {
                      final row = _drillDownDetails[index];
                      final name = row['DiscountName']?.toString() ?? 'Unknown';
                      final timesApplied = _parseInt(row['TimesApplied']);
                      final orders = _parseInt(row['OrdersAffected']);
                      final amount = _parseDouble(row['TotalAmount']);
                      final barWidth = (amount / maxValue).clamp(0.0, 1.0);

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: index.isEven ? Colors.white : Colors.grey[50],
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    timesApplied.toString(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    orders.toString(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    _currencyFormat.format(amount),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Stack(
                              children: [
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: barWidth,
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          primaryColor,
                                          primaryColor.withValues(alpha: 0.6),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadCategoryItems(String categoryId) async {
    try {
      final items = await _powerBIService.getCategoryItems(
        categoryId: categoryId,
        dateRange: _dateRange,
        storeIds: _selectedStores.toList(),
      );

      setState(() {
        final categoryIndex = _categories.indexWhere(
          (c) => c.categoryId == categoryId,
        );
        if (categoryIndex != -1) {
          _categories[categoryIndex].items = items;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading items: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showStoreSelector() {
    final availableStores = _stores.map((s) => s.storeId).toSet();
    // Initialize with all selected if empty (means all are selected)
    Set<String> tempSelectedStores = _selectedStores.isEmpty
        ? Set.from(availableStores)
        : Set.from(_selectedStores);
    bool isLoading = true;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;

        return StatefulBuilder(
          builder: (context, setModalState) {
            // Simulate loading for shimmer effect
            if (isLoading) {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (context.mounted) {
                  setModalState(() => isLoading = false);
                }
              });
            }

            final allSelected =
                tempSelectedStores.length == availableStores.length;

            // Filter stores based on search query
            final filteredStores = _stores
                .where(
                  (store) =>
                      store.storeName.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ) ||
                      (store.city?.toLowerCase().contains(
                            searchQuery.toLowerCase(),
                          ) ??
                          false),
                )
                .toList();

            return Container(
              height: screenHeight * (isMobile ? 0.8 : 0.7),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.store,
                          color: Colors.blue[700],
                          size: isMobile ? 22 : 26,
                        ),
                        SizedBox(width: isMobile ? 10 : 12),
                        Expanded(
                          child: Text(
                            'Select Stores',
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 8 : 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${tempSelectedStores.length}/${availableStores.length}',
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                        SizedBox(width: isMobile ? 6 : 8),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              if (allSelected) {
                                tempSelectedStores.clear();
                              } else {
                                tempSelectedStores = Set.from(availableStores);
                              }
                            });
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 8 : 12,
                              vertical: 6,
                            ),
                          ),
                          child: Text(
                            allSelected ? 'Clear All' : 'Select All',
                            style: TextStyle(fontSize: isMobile ? 12 : 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Search field
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 20,
                    ),
                    child: TextField(
                      onChanged: (value) =>
                          setModalState(() => searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search stores...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: isMobile ? 13 : 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[400],
                          size: isMobile ? 20 : 22,
                        ),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.grey[400],
                                  size: isMobile ? 18 : 20,
                                ),
                                onPressed: () =>
                                    setModalState(() => searchQuery = ''),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: isMobile ? 10 : 12,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 8 : 12),
                  const Divider(height: 1),
                  Expanded(
                    child: isLoading
                        ? _buildShimmerList(isMobile)
                        : filteredStores.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: Colors.grey[300],
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No stores found',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(
                              vertical: isMobile ? 4 : 8,
                            ),
                            itemCount: filteredStores.length,
                            itemBuilder: (context, index) {
                              final store = filteredStores[index];
                              final isSelected = tempSelectedStores.contains(
                                store.storeId,
                              );
                              return CheckboxListTile(
                                value: isSelected,
                                dense: isMobile,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 12 : 16,
                                  vertical: isMobile ? 2 : 4,
                                ),
                                onChanged: (value) {
                                  setModalState(() {
                                    if (value == true) {
                                      tempSelectedStores.add(store.storeId);
                                    } else {
                                      tempSelectedStores.remove(store.storeId);
                                    }
                                  });
                                },
                                title: Text(
                                  store.storeName,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                    fontSize: isMobile ? 13 : 15,
                                  ),
                                ),
                                subtitle: store.city != null
                                    ? Text(
                                        store.city!,
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: isMobile ? 11 : 12,
                                        ),
                                      )
                                    : null,
                                secondary: Container(
                                  padding: EdgeInsets.all(isMobile ? 6 : 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.blue[100]
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.store,
                                    size: isMobile ? 18 : 20,
                                    color: isSelected
                                        ? Colors.blue[700]
                                        : Colors.grey[600],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // If all selected, store as empty (means all)
                          _selectedStores =
                              tempSelectedStores.length ==
                                  availableStores.length
                              ? {}
                              : Set.from(tempSelectedStores);
                          Navigator.pop(context);
                          setState(() {});
                          _loadReportData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 12 : 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Apply Filter',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: isMobile ? 14 : 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dbProvider = context.watch<DatabaseProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Show shimmer loading whenever loading AND no data available yet
    if (_isLoading && (_categories.isEmpty || _stores.isEmpty)) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: SafeArea(child: PowerBIShimmerLoading(isMobile: isMobile)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: _error != null ? _buildErrorState() : _buildContent(),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildAppBar(DatabaseProvider dbProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Icon(Icons.analytics, color: Colors.blue[700], size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PowerBI Reports',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    dbProvider.currentDatabase?.name ?? 'No database',
                    style: TextStyle(fontSize: 12, color: Colors.black),
                  ),
                ],
              ),
              const Spacer(),
              if (_stores.isNotEmpty) _buildStoreSelectionButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSelectionButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[800]!],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showStoreSelector,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.store, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stores',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${_selectedStores.length} of ${_stores.length}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final isWideScreen = screenWidth > 900;
        final isMobile = screenWidth < 600;

        return Stack(
          children: [
            Container(
              color: const Color(0xFFF5F7FA),
              child: Column(
                children: [
                  // App Bar with Filters
                  _buildMainAppBar(isWideScreen, isMobile),

                  // Main Content Area
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(
                        isMobile ? 12 : (isWideScreen ? 24 : 16),
                      ),
                      child: _selectedReport == 'Sales Trend Report'
                          ? _buildSalesTrendContent(
                              screenWidth,
                              screenHeight,
                              isWideScreen,
                            )
                          : _buildDiscountReportContent(
                              screenWidth,
                              screenHeight,
                              isWideScreen,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            // Minimal shimmer overlay - shown during filter updates (non-blocking)
            if (_isLoading && _categories.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue[700]!,
                    ),
                  ),
                ),
              ),
            // Cubie Chatbot
            CubieChatbot(
              reportType: _selectedReport,
              reportData: _getCubieReportData(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainAppBar(bool isWideScreen, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: isMobile ? 10 : 14,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[900]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Row - Title and Report Selector
            Row(
              children: [
                // App Icon & Title
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.analytics,
                    color: Colors.white,
                    size: isMobile ? 20 : 24,
                  ),
                ),
                SizedBox(width: isMobile ? 10 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales Analytics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 16 : 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (!isMobile)
                        Text(
                          'Real-time business insights',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                // Report Type Toggle
                _buildReportToggle(isMobile),
              ],
            ),
            SizedBox(height: isMobile ? 10 : 14),
            // Bottom Row - Filter Chips
            _buildFilterChipsRow(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildReportToggle(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _reportTypes.map((report) {
          final isSelected = report == _selectedReport;
          final icon = report == 'Sales Trend Report'
              ? Icons.trending_up
              : Icons.discount;
          final shortName = report == 'Sales Trend Report'
              ? (isMobile ? 'Sales' : 'Sales Trend')
              : (isMobile ? 'Discount' : 'Discounts');

          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                setState(() {
                  _selectedReport = report;
                });
                _loadReportData();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 10 : 14,
                vertical: isMobile ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: isMobile ? 14 : 16,
                    color: isSelected
                        ? Colors.blue[700]
                        : Colors.white.withValues(alpha: 0.9),
                  ),
                  SizedBox(width: isMobile ? 4 : 6),
                  Text(
                    shortName,
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.blue[700]
                          : Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterChipsRow(bool isMobile) {
    if (isMobile) {
      // Row layout for mobile with compact chips
      return Row(
        children: [
          // Date Range Chip
          Expanded(
            child: _buildFilterChip(
              icon: Icons.calendar_today,
              label: _selectedDuration,
              onTap: () => _showDateRangeDialog(),
              isMobile: isMobile,
            ),
          ),
          SizedBox(width: 6),
          // Stores Chip
          Expanded(
            child: _buildFilterChip(
              icon: Icons.store,
              label: _selectedStores.length == _stores.length
                  ? 'All Stores (${_stores.length})'
                  : '${_selectedStores.length}/${_stores.length} Stores',
              onTap: () => _showStoreSelector(),
              isMobile: isMobile,
            ),
          ),
          SizedBox(width: 6),
          // Categories Chip
          Expanded(
            child: _buildFilterChip(
              icon: Icons.category,
              label: _selectedCategories.isEmpty
                  ? 'All Categories'
                  : '${_selectedCategories.length} Categories',
              onTap: () => _showCategorySelector(),
              isMobile: isMobile,
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Date Range Chip
          _buildFilterChip(
            icon: Icons.calendar_today,
            label: _selectedDuration,
            onTap: () => _showDateRangeDialog(),
            isMobile: isMobile,
          ),
          SizedBox(width: 10),
          // Stores Chip
          _buildFilterChip(
            icon: Icons.store,
            label: _selectedStores.length == _stores.length
                ? 'All Stores (${_stores.length})'
                : '${_selectedStores.length} of ${_stores.length} Stores',
            onTap: () => _showStoreSelector(),
            isMobile: isMobile,
          ),
          SizedBox(width: 10),
          // Categories Chip
          _buildFilterChip(
            icon: Icons.category,
            label: _selectedCategories.isEmpty
                ? 'All Categories'
                : '${_selectedCategories.length} Categories',
            onTap: () => _showCategorySelector(),
            isMobile: isMobile,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 14,
            vertical: isMobile ? 5 : 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: isMobile ? 12 : 16, color: Colors.white),
              SizedBox(width: isMobile ? 4 : 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 10 : 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: isMobile ? 2 : 6),
              Icon(
                Icons.keyboard_arrow_down,
                size: isMobile ? 12 : 16,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDateRangeDialog() {
    final durations = [
      'Last 1 Month',
      'Last 3 Months',
      'Last 6 Months',
      'Last 30 Days',
      'Last 90 Days',
      'This Month',
      'This Quarter',
      'This Year',
      'Custom Range',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;

        return Container(
          constraints: BoxConstraints(
            maxHeight: screenHeight * (isMobile ? 0.7 : 0.6),
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Colors.blue[700],
                      size: isMobile ? 22 : 26,
                    ),
                    SizedBox(width: isMobile ? 10 : 12),
                    Text(
                      'Select Date Range',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 8),
                  itemCount: durations.length,
                  itemBuilder: (context, index) {
                    final duration = durations[index];
                    final isSelected = duration == _selectedDuration;
                    final isCustom = duration == 'Custom Range';

                    return ListTile(
                      dense: isMobile,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 16,
                        vertical: isMobile ? 2 : 4,
                      ),
                      leading: Container(
                        padding: EdgeInsets.all(isMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color: isCustom
                              ? Colors.orange[100]
                              : (isSelected
                                    ? Colors.blue[100]
                                    : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isCustom ? Icons.edit_calendar : Icons.date_range,
                          size: isMobile ? 18 : 20,
                          color: isCustom
                              ? Colors.orange[700]
                              : (isSelected
                                    ? Colors.blue[700]
                                    : Colors.grey[600]),
                        ),
                      ),
                      title: Text(
                        duration,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: isMobile ? 13 : 15,
                          color: isCustom
                              ? Colors.orange[800]
                              : (isSelected ? Colors.blue[700] : Colors.black),
                        ),
                      ),
                      trailing: isSelected && !isCustom
                          ? Icon(
                              Icons.check_circle,
                              color: Colors.blue[600],
                              size: isMobile ? 20 : 24,
                            )
                          : (isCustom
                                ? Icon(
                                    Icons.arrow_forward_ios,
                                    size: isMobile ? 14 : 16,
                                    color: Colors.orange[600],
                                  )
                                : null),
                      onTap: () async {
                        Navigator.pop(context);
                        if (isCustom) {
                          _showCustomDatePicker();
                        } else {
                          _onDurationChanged(duration);
                        }
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: isMobile ? 12 : 20),
            ],
          ),
        );
      },
    );
  }

  void _showCustomDatePicker() async {
    final now = DateTime.now();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[700]!,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(isMobile ? 0.9 : 1.0)),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      final startStr =
          '${picked.start.day}/${picked.start.month}/${picked.start.year}';
      final endStr = '${picked.end.day}/${picked.end.month}/${picked.end.year}';
      setState(() {
        _selectedDuration = '$startStr - $endStr';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _dateRange = DynamicDateRange.custom(picked.start, picked.end);
      });
      _loadReportData();
    }
  }

  void _showCategorySelector() {
    // Get unique categories from _categories
    final availableCategories = _categories.map((c) => c.categoryId).toSet();
    // Initialize with all selected if empty (means all are selected)
    Set<String> tempSelectedCategories = _selectedCategories.isEmpty
        ? Set.from(availableCategories)
        : Set.from(_selectedCategories);
    bool isLoading = true;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;

        return StatefulBuilder(
          builder: (context, setModalState) {
            // Simulate loading for shimmer effect
            if (isLoading) {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (context.mounted) {
                  setModalState(() => isLoading = false);
                }
              });
            }

            final allSelected =
                tempSelectedCategories.length == availableCategories.length;

            // Filter categories based on search query
            final filteredCategories = _categories
                .where(
                  (category) => category.categoryName.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ),
                )
                .toList();

            return Container(
              height: screenHeight * (isMobile ? 0.8 : 0.7),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.category,
                          color: Colors.blue[700],
                          size: isMobile ? 22 : 26,
                        ),
                        SizedBox(width: isMobile ? 10 : 12),
                        Expanded(
                          child: Text(
                            'Select Categories',
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 8 : 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${tempSelectedCategories.length}/${availableCategories.length}',
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                        SizedBox(width: isMobile ? 6 : 8),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              if (allSelected) {
                                tempSelectedCategories.clear();
                              } else {
                                tempSelectedCategories = Set.from(
                                  availableCategories,
                                );
                              }
                            });
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 8 : 12,
                              vertical: 6,
                            ),
                          ),
                          child: Text(
                            allSelected ? 'Clear All' : 'Select All',
                            style: TextStyle(fontSize: isMobile ? 12 : 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Search field
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 20,
                    ),
                    child: TextField(
                      onChanged: (value) =>
                          setModalState(() => searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search categories...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: isMobile ? 13 : 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[400],
                          size: isMobile ? 20 : 22,
                        ),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.grey[400],
                                  size: isMobile ? 18 : 20,
                                ),
                                onPressed: () =>
                                    setModalState(() => searchQuery = ''),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: isMobile ? 10 : 12,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 8 : 12),
                  const Divider(height: 1),
                  Expanded(
                    child: isLoading
                        ? _buildShimmerList(isMobile)
                        : filteredCategories.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: Colors.grey[300],
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No categories found',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(
                              vertical: isMobile ? 4 : 8,
                            ),
                            itemCount: filteredCategories.length,
                            itemBuilder: (context, index) {
                              final category = filteredCategories[index];
                              final isSelected = tempSelectedCategories
                                  .contains(category.categoryId);
                              return CheckboxListTile(
                                value: isSelected,
                                dense: isMobile,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 12 : 16,
                                  vertical: isMobile ? 2 : 4,
                                ),
                                onChanged: (value) {
                                  setModalState(() {
                                    if (value == true) {
                                      tempSelectedCategories.add(
                                        category.categoryId,
                                      );
                                    } else {
                                      tempSelectedCategories.remove(
                                        category.categoryId,
                                      );
                                    }
                                  });
                                },
                                title: Text(
                                  category.categoryName,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                    fontSize: isMobile ? 13 : 15,
                                  ),
                                ),
                                subtitle: Text(
                                  '\$${_currencyFormat.format(category.totalSales).replaceAll('\$', '')}',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: isMobile ? 11 : 12,
                                  ),
                                ),
                                secondary: Container(
                                  padding: EdgeInsets.all(isMobile ? 6 : 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.blue[100]
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.category,
                                    size: isMobile ? 18 : 20,
                                    color: isSelected
                                        ? Colors.blue[700]
                                        : Colors.grey[600],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // If all selected, store as empty (means all)
                          _selectedCategories =
                              tempSelectedCategories.length ==
                                  availableCategories.length
                              ? {}
                              : Set.from(tempSelectedCategories);
                          Navigator.pop(context);
                          setState(() {});
                          _loadReportData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 12 : 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Apply Filter',
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Shimmer loading list for dropdowns
  Widget _buildShimmerList(bool isMobile) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 8),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 16,
            vertical: isMobile ? 4 : 6,
          ),
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Checkbox shimmer
              Container(
                width: isMobile ? 20 : 24,
                height: isMobile ? 20 : 24,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _ShimmerEffect(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              // Icon shimmer
              _ShimmerEffect(
                child: Container(
                  width: isMobile ? 32 : 40,
                  height: isMobile ? 32 : 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 10 : 14),
              // Text shimmer
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerEffect(
                      child: Container(
                        height: isMobile ? 14 : 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 6 : 8),
                    _ShimmerEffect(
                      child: Container(
                        height: isMobile ? 10 : 12,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onDurationChanged(String duration) {
    DynamicDateRange newRange;
    switch (duration) {
      case 'Last 1 Month':
        newRange = DynamicDateRange.lastNMonths(1);
        break;
      case 'Last 3 Months':
        newRange = DynamicDateRange.lastNMonths(3);
        break;
      case 'Last 6 Months':
        newRange = DynamicDateRange.lastNMonths(6);
        break;
      case 'Last 30 Days':
        newRange = DynamicDateRange.lastNDays(30);
        break;
      case 'Last 90 Days':
        newRange = DynamicDateRange.lastNDays(90);
        break;
      case 'This Month':
        newRange = DynamicDateRange.thisMonth();
        break;
      case 'This Quarter':
        newRange = DynamicDateRange.thisQuarter();
        break;
      case 'This Year':
        newRange = DynamicDateRange.thisYear();
        break;
      default:
        newRange = DynamicDateRange.lastNMonths(6);
    }

    setState(() {
      _selectedDuration = duration;
      _dateRange = newRange;
    });
    _loadReportData();
  }

  Map<String, dynamic> _getCubieReportData() {
    if (_selectedReport == 'Sales Trend Report') {
      // Get top store
      String topStore = '';
      double topStoreAmount = 0;
      for (var store in _stores) {
        if (store.totalSales > topStoreAmount) {
          topStoreAmount = store.totalSales;
          topStore = store.storeName;
        }
      }

      // Get top category
      String topCategory = '';
      double topCategoryAmount = 0;
      for (var category in _categories) {
        if (category.totalSales > topCategoryAmount) {
          topCategoryAmount = category.totalSales;
          topCategory = category.categoryName;
        }
      }

      // Calculate total sales from categories
      double totalSales = 0;
      for (var category in _categories) {
        totalSales += category.totalSales;
      }

      return {
        'totalSales': totalSales,
        'total': totalSales,
        'topStore': topStore,
        'topStoreAmount': topStoreAmount,
        'topCategory': topCategory,
        'topCategoryAmount': topCategoryAmount,
        'averageOrder': _stores.isNotEmpty ? totalSales / _stores.length : 0,
        'monthlyGrowth':
            5.2, // Placeholder - could be calculated from actual data
      };
    } else {
      // Discount Report
      String topDiscount = '';
      int topDiscountTimes = 0;
      String topDiscountStore = '';
      double topDiscountStoreAmount = 0;

      for (var discount in _discountByType) {
        final times = _parseInt(discount['TimesApplied']);
        if (times > topDiscountTimes) {
          topDiscountTimes = times;
          topDiscount = discount['DiscountName']?.toString() ?? '';
        }
      }

      for (var store in _discountByStore) {
        final amount = _parseDouble(store['TotalDiscount']);
        if (amount > topDiscountStoreAmount) {
          topDiscountStoreAmount = amount;
          topDiscountStore = store['StoreName']?.toString() ?? '';
        }
      }

      return {
        'totalDiscount': _discountSummary?['totalDiscount'] ?? 0.0,
        'topDiscount': topDiscount,
        'topDiscountTimes': topDiscountTimes,
        'topDiscountStore': topDiscountStore,
        'topDiscountStoreAmount': topDiscountStoreAmount,
        'ordersWithDiscount': _discountSummary?['totalOrders'] ?? 0,
        'averageDiscount': _calculateAverageDiscount(),
      };
    }
  }

  double _calculateAverageDiscount() {
    if (_discountSummary == null) return 0.0;
    final totalOrders = _discountSummary!['totalOrders'];
    final totalDiscount = _discountSummary!['totalDiscount'];
    if (totalOrders == null || totalDiscount == null) return 0.0;
    if (totalOrders is int && totalOrders > 0) {
      return (totalDiscount as num).toDouble() / totalOrders;
    }
    return 0.0;
  }

  Widget _buildSalesTrendContent(
    double screenWidth,
    double screenHeight,
    bool isWideScreen,
  ) {
    final isMobile = screenWidth < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Cards Row
        if (_summary != null) _buildModernSummaryCards(isMobile: isMobile),
        SizedBox(height: isMobile ? 12 : (isWideScreen ? 24 : 16)),

        // Charts Row (includes Sales Trend Chart on right side)
        if (_categories.isNotEmpty || _salesTrendData.isNotEmpty || _isLoading)
          _buildChartsRow(screenWidth, screenHeight, isMobile: isMobile),
        SizedBox(height: isMobile ? 12 : (isWideScreen ? 24 : 16)),

        // Data Table with Grand Total inside
        _buildModernDataTable(),
      ],
    );
  }

  Widget _buildDiscountReportContent(
    double screenWidth,
    double screenHeight,
    bool isWideScreen,
  ) {
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    if (_discountData.isEmpty && !_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 24 : 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.discount_outlined,
                size: isMobile ? 48 : 64,
                color: Colors.grey[400],
              ),
              SizedBox(height: isMobile ? 12 : 16),
              Text(
                'No discount data available',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isMobile ? 6 : 8),
              Text(
                'Select filters to view discount report',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Overview Section (similar to reference image)
        _buildDiscountOverview(isMobile: isMobile),
        SizedBox(height: isMobile ? 12 : (isWideScreen ? 24 : 16)),

        // Two Pie Charts Row - Stack on mobile
        if (isMobile)
          Column(
            children: [
              _buildDiscountPieChart(
                'Discount by Type',
                'type',
                isMobile: true,
              ),
              const SizedBox(height: 12),
              _buildDiscountPieChart(
                'Discount by Store',
                'store',
                isMobile: true,
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDiscountPieChart(
                  'Discount by Type',
                  'type',
                  isMobile: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDiscountPieChart(
                  'Discount by Store',
                  'store',
                  isMobile: false,
                ),
              ),
            ],
          ),
        SizedBox(height: isMobile ? 12 : (isWideScreen ? 24 : 16)),

        // Two column layout for bar charts - Stack on mobile
        if (isMobile)
          Column(
            children: [
              _buildDiscountByTypeSection(isMobile: true),
              const SizedBox(height: 12),
              _buildDiscountAmountByStoreSection(isMobile: true),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildDiscountByTypeSection(isMobile: false)),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDiscountAmountByStoreSection(isMobile: false),
              ),
            ],
          ),
        SizedBox(height: isMobile ? 12 : (isWideScreen ? 24 : 16)),

        // Top Discounts Table
        _buildTopDiscountsTable(),
      ],
    );
  }

  Widget _buildDiscountPieChart(
    String title,
    String dataType, {
    bool isMobile = false,
  }) {
    final List<Map<String, dynamic>> data;
    final String nameKey;
    final String valueKey;

    if (dataType == 'type') {
      data = _discountByType.take(isMobile ? 5 : 6).toList();
      nameKey = 'DiscountName';
      valueKey = 'TotalAmount';
    } else {
      data = _discountByStore.take(isMobile ? 5 : 6).toList();
      nameKey = 'StoreName';
      valueKey = 'TotalDiscount';
    }

    if (data.isEmpty) return const SizedBox.shrink();

    final total = data.fold<double>(
      0,
      (sum, row) => sum + _parseDouble(row[valueKey]),
    );

    final colors = [
      const Color(0xFF1E5F8A),
      const Color(0xFF4A90A4),
      const Color(0xFF6B8E4E),
      const Color(0xFFE8A838),
      const Color(0xFFD35F5F),
      const Color(0xFF8E6BB8),
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          SizedBox(
            height: isMobile ? 160 : 200,
            child: isMobile
                ? Column(
                    children: [
                      // Pie Chart centered on mobile
                      Expanded(
                        child: Center(
                          child: Builder(
                            builder: (context) {
                              final pieData = data
                                  .map((row) => _parseDouble(row[valueKey]))
                                  .where((v) => v > 0)
                                  .toList();
                              if (pieData.isEmpty) {
                                return const Text(
                                  'No data',
                                  style: TextStyle(color: Colors.black),
                                );
                              }
                              return CustomPaint(
                                size: const Size(100, 100),
                                painter: _DiscountPieChartPainter(
                                  data: pieData,
                                  colors: colors,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      // Pie Chart
                      Expanded(
                        flex: 3,
                        child: Builder(
                          builder: (context) {
                            final pieData = data
                                .map((row) => _parseDouble(row[valueKey]))
                                .where((v) => v > 0)
                                .toList();
                            if (pieData.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No data',
                                  style: TextStyle(color: Colors.black),
                                ),
                              );
                            }
                            return CustomPaint(
                              size: const Size(150, 150),
                              painter: _DiscountPieChartPainter(
                                data: pieData,
                                colors: colors,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Legend
                      Expanded(
                        flex: 4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: data.asMap().entries.map((entry) {
                            final index = entry.key;
                            final row = entry.value;
                            final name = row[nameKey]?.toString() ?? 'Unknown';
                            final value = _parseDouble(row[valueKey]);
                            final percent = total > 0
                                ? (value / total * 100)
                                : 0.0;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: colors[index % colors.length],
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${percent.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
          ),
          // Mobile legend below chart
          if (isMobile)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: data.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                final name = row[nameKey]?.toString() ?? 'Unknown';
                final value = _parseDouble(row[valueKey]);
                final percent = total > 0 ? (value / total * 100) : 0.0;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors[index % colors.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${name.length > 10 ? '${name.substring(0, 10)}...' : name} ${percent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDiscountByTypeSection({bool isMobile = false}) {
    if (_discountByType.isEmpty) return const SizedBox.shrink();

    final topTypes = _discountByType.take(isMobile ? 5 : 10).toList();
    final maxValue = topTypes.fold<double>(
      0,
      (max, row) => max > _parseInt(row['TimesApplied']).toDouble()
          ? max
          : _parseInt(row['TimesApplied']).toDouble(),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with drill-down indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E5F8A), Color(0xFF4A90A4)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_offer, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'Discounts by Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Click to drill down',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Column headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Discount Name',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    '',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                const SizedBox(
                  width: 80,
                  child: Text(
                    'Times Applied',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 30), // Space for arrow
              ],
            ),
          ),
          // Data rows with bars - now clickable
          ...topTypes.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final name = row['DiscountName']?.toString() ?? 'Unknown';
            final timesApplied = _parseInt(row['TimesApplied']);
            final barWidth = maxValue > 0 ? (timesApplied / maxValue) : 0.0;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _loadDrillDownDetails('type', row),
                hoverColor: const Color(0xFF1E5F8A).withValues(alpha: 0.08),
                splashColor: const Color(0xFF1E5F8A).withValues(alpha: 0.15),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: index.isEven ? Colors.white : Colors.grey[50],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[100]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 24,
                          child: Stack(
                            children: [
                              Container(
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: barWidth.clamp(0.0, 1.0),
                                child: Container(
                                  height: 24,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: index.isEven
                                          ? [
                                              const Color(0xFF5B8BA0),
                                              const Color(0xFF7EAAB8),
                                            ]
                                          : [
                                              const Color(0xFF7EAAB8),
                                              const Color(0xFF9ECAD8),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          timesApplied.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDiscountAmountByStoreSection({bool isMobile = false}) {
    if (_discountByStore.isEmpty) return const SizedBox.shrink();

    final topStores = _discountByStore.take(isMobile ? 5 : 10).toList();
    final maxValue = topStores.fold<double>(
      0,
      (max, row) => max > _parseDouble(row['TotalDiscount'])
          ? max
          : _parseDouble(row['TotalDiscount']),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with drill-down indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6B8E4E), Color(0xFF8EAD6E)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.store, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'Discount Amount by Store',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Click to drill down',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Column headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Store',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    '',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                const SizedBox(
                  width: 100,
                  child: Text(
                    'Discount Amount',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 30), // Space for arrow
              ],
            ),
          ),
          // Data rows with bars - now clickable
          ...topStores.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final name = row['StoreName']?.toString() ?? 'Unknown';
            final amount = _parseDouble(row['TotalDiscount']);
            final barWidth = maxValue > 0 ? (amount / maxValue) : 0.0;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _loadDrillDownDetails('store', row),
                hoverColor: const Color(0xFF6B8E4E).withValues(alpha: 0.08),
                splashColor: const Color(0xFF6B8E4E).withValues(alpha: 0.15),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: index.isEven ? Colors.white : Colors.grey[50],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[100]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 24,
                          child: Stack(
                            children: [
                              Container(
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: barWidth.clamp(0.0, 1.0),
                                child: Container(
                                  height: 24,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: index.isEven
                                          ? [
                                              const Color(0xFF6B8E4E),
                                              const Color(0xFF8EAD6E),
                                            ]
                                          : [
                                              const Color(0xFF8EAD6E),
                                              const Color(0xFFAAC98E),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          _currencyFormat.format(amount),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopDiscountsTable() {
    if (_discountByType.isEmpty) return const SizedBox.shrink();

    final topDiscounts = _discountByType.take(10).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E5F8A),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
            ),
            child: const Text(
              'Top Discounts by Amount',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          // Column headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Discount',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 120,
                  child: Text(
                    'Total Amount',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Data rows
          ...topDiscounts.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final name = row['DiscountName']?.toString() ?? 'Unknown';
            final amount = _parseDouble(row['TotalAmount']);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: index.isEven ? Colors.white : Colors.grey[50],
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text(
                      _currencyFormat.format(amount),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDiscountOverview({bool isMobile = false}) {
    final summary = _discountSummary;
    if (summary == null) return const SizedBox.shrink();

    // Calculate correct values
    final totalDiscount = summary['totalDiscount'] as double? ?? 0.0;
    final totalOrders = summary['totalOrders'] as int? ?? 0;
    final totalApplications = summary['totalApplications'] as int? ?? 0;
    final uniqueDiscounts = summary['uniqueDiscounts'] as int? ?? 0;
    // storesWithDiscounts available in summary if needed

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 8 : 10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.analytics,
                  color: Colors.blue[700],
                  size: isMobile ? 20 : 24,
                ),
              ),
              SizedBox(width: isMobile ? 10 : 12),
              Text(
                'Overview',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 14 : 20),

          // Overview Grid - Mobile: 2x2, Desktop: 1x4
          if (isMobile)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildOverviewCard(
                        'Total Discount',
                        _currencyFormat.format(totalDiscount),
                        Icons.attach_money,
                        Colors.green,
                        isMobile: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildOverviewCard(
                        'Orders',
                        totalOrders.toString(),
                        Icons.receipt,
                        Colors.blue,
                        isMobile: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildOverviewCard(
                        'Times Applied',
                        totalApplications.toString(),
                        Icons.repeat,
                        Colors.orange,
                        isMobile: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildOverviewCard(
                        'Unique',
                        uniqueDiscounts.toString(),
                        Icons.local_offer,
                        Colors.purple,
                        isMobile: true,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Table(
              border: TableBorder.all(color: Colors.grey[300]!, width: 1),
              children: [
                // Header Row
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey[100]),
                  children: [
                    _buildOverviewHeaderCell('Total Discount'),
                    _buildOverviewHeaderCell('Orders with Discounts'),
                    _buildOverviewHeaderCell('Times Applied'),
                    _buildOverviewHeaderCell('Unique Discounts'),
                  ],
                ),
                // Data Row
                TableRow(
                  children: [
                    _buildOverviewDataCell(
                      _currencyFormat.format(totalDiscount),
                    ),
                    _buildOverviewDataCell(totalOrders.toString()),
                    _buildOverviewDataCell(totalApplications.toString()),
                    _buildOverviewDataCell(uniqueDiscounts.toString()),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isMobile = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: isMobile ? 16 : 20, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 14 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildOverviewDataCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildChartsRow(
    double screenWidth,
    double screenHeight, {
    bool isMobile = false,
  }) {
    final chartHeight = isMobile
        ? 280.0
        : (screenHeight * 0.28).clamp(220.0, 320.0);

    if (isMobile) {
      // Stack charts vertically on mobile
      return Column(
        children: [
          SizedBox(
            height: chartHeight,
            child: _build3DDonutChart(isMobile: true),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: chartHeight,
            child: _build3DBarChart(isMobile: true),
          ),
        ],
      );
    }

    return SizedBox(
      height: chartHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Donut Chart
          Expanded(flex: 1, child: _build3DDonutChart()),
          const SizedBox(width: 16),
          // Liquid Gauges
          Expanded(flex: 1, child: _build3DBarChart()),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(double width) {
    final durations = [
      'Last 1 Month',
      'Last 3 Months',
      'Last 6 Months',
      'Last 30 Days',
      'Last 90 Days',
      'This Month',
      'This Quarter',
      'This Year',
    ];

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[600]!, Colors.blue[800]!],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.filter_list,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Filters',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Filter Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range Section
                  _buildFilterSection(
                    'Date Range',
                    Icons.calendar_today,
                    _buildDurationFilterButton(durations),
                  ),
                  const SizedBox(height: 20),

                  // Stores Section
                  _buildFilterSection(
                    'Stores',
                    Icons.store,
                    _buildStoreFilterButton(),
                  ),
                  const SizedBox(height: 20),

                  // Categories Section
                  _buildFilterSection(
                    'Categories',
                    Icons.category,
                    _buildCategoryFilterButton(),
                  ),
                ],
              ),
            ),
          ),

          // Report Selector at Bottom
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: _buildReportSelector(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.assessment, size: 16, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Text(
              'Select Report',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedReport,
              isExpanded: true,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.blue[700],
                  size: 20,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              borderRadius: BorderRadius.circular(12),
              dropdownColor: Colors.white,
              items: _reportTypes.map((String report) {
                final isSelected = report == _selectedReport;
                return DropdownMenuItem<String>(
                  value: report,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue[100]
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          report == 'Sales Trend Report'
                              ? Icons.trending_up
                              : Icons.discount,
                          size: 18,
                          color: isSelected
                              ? Colors.blue[700]
                              : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          report,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.blue[700]
                                : Colors.grey[800],
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: Colors.blue[600],
                          size: 18,
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null && newValue != _selectedReport) {
                  setState(() {
                    _selectedReport = newValue;
                  });
                  _loadReportData();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection(String title, IconData icon, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        content,
      ],
    );
  }

  Widget _buildStoreFilterButton() {
    return InkWell(
      onTap: () => _showStoreSelector(),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _selectedStores.isNotEmpty ? Colors.blue[50] : Colors.grey[50],
          border: Border.all(
            color: _selectedStores.isNotEmpty
                ? Colors.blue[200]!
                : Colors.grey[200]!,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.store, size: 16, color: Colors.blue[700]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_selectedStores.length} Selected',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    'of ${_stores.length} stores',
                    style: TextStyle(fontSize: 11, color: Colors.black),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilterButton() {
    return InkWell(
      onTap: () => _showCategorySelector(),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _selectedCategories.isNotEmpty
              ? Colors.green[50]
              : Colors.grey[50],
          border: Border.all(
            color: _selectedCategories.isNotEmpty
                ? Colors.green[200]!
                : Colors.grey[200]!,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.category, size: 16, color: Colors.green[700]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedCategories.isEmpty
                        ? 'All Categories'
                        : '${_selectedCategories.length} Selected',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    '${_categories.length} available',
                    style: TextStyle(fontSize: 11, color: Colors.black),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationFilterButton(List<String> durations) {
    return InkWell(
      onTap: () => _showDurationSelector(durations),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.purple[50],
          border: Border.all(color: Colors.purple[200]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.purple[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.calendar_today,
                size: 16,
                color: Colors.purple[700],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedDuration,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    'Tap to change',
                    style: TextStyle(fontSize: 11, color: Colors.black),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  void _showDurationSelector(List<String> durations) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DurationSelectionDialog(
        durations: durations,
        selectedDuration: _selectedDuration,
        onSelectionChanged: (selected) async {
          setState(() {
            _selectedDuration = selected;
            _updateDateRangeFromDuration(selected);
          });
          await _loadReportData();
        },
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[50]!, Colors.purple[50]!],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'Quick Stats',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildQuickStatItem(
            'Active Filters',
            '${(_selectedStores.length < _stores.length ? 1 : 0) + (_selectedCategories.isNotEmpty ? 1 : 0) + 1}',
            Colors.orange,
          ),
          const SizedBox(height: 10),
          _buildQuickStatItem('Data Period', _selectedDuration, Colors.blue),
          const SizedBox(height: 10),
          _buildQuickStatItem(
            'Total Records',
            '${_categories.length}',
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatItem(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.black)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildFiltersRow() {
    final durations = [
      'Last 1 Month',
      'Last 3 Months',
      'Last 6 Months',
      'Last 30 Days',
      'Last 90 Days',
      'This Month',
      'This Quarter',
      'This Year',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Duration Dropdown
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDuration,
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down, color: Colors.blue[700]),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  items: durations.map((String duration) {
                    return DropdownMenuItem<String>(
                      value: duration,
                      child: Text(duration),
                    );
                  }).toList(),
                  onChanged: (String? newValue) async {
                    if (newValue != null && newValue != _selectedDuration) {
                      setState(() {
                        _selectedDuration = newValue;
                        _updateDateRangeFromDuration(newValue);
                      });
                      await _loadReportData();
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Stores Multi-Select
          Expanded(flex: 2, child: _buildStoreMultiSelect()),
          const SizedBox(width: 16),
          // Categories Multi-Select
          Expanded(flex: 2, child: _buildCategoryMultiSelect()),
        ],
      ),
    );
  }

  Widget _buildStoreMultiSelect() {
    return InkWell(
      onTap: () => _showStoreSelector(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.store, size: 20, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedStores.isEmpty
                    ? 'Select Stores'
                    : '${_selectedStores.length} Store(s) Selected',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _selectedStores.isEmpty
                      ? Colors.grey[600]
                      : Colors.grey[800],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.black),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryMultiSelect() {
    return InkWell(
      onTap: () => _showCategorySelector(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.category, size: 20, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedCategories.isEmpty
                    ? 'All Categories'
                    : '${_selectedCategories.length} Category(s) Selected',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _selectedCategories.isEmpty
                      ? Colors.grey[600]
                      : Colors.grey[800],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.black),
          ],
        ),
      ),
    );
  }

  // Old category selector removed - using new bottom sheet version in _showCategorySelector above

  void _updateDateRangeFromDuration(String duration) {
    switch (duration) {
      case 'Last 1 Month':
        _dateRange = DynamicDateRange.lastNMonths(1);
        break;
      case 'Last 3 Months':
        _dateRange = DynamicDateRange.lastNMonths(3);
        break;
      case 'Last 6 Months':
        _dateRange = DynamicDateRange.lastNMonths(6);
        break;
      case 'Last 30 Days':
        _dateRange = DynamicDateRange.lastNDays(30);
        break;
      case 'Last 90 Days':
        _dateRange = DynamicDateRange.lastNDays(90);
        break;
      case 'This Month':
        _dateRange = DynamicDateRange.thisMonth();
        break;
      case 'This Quarter':
        _dateRange = DynamicDateRange.thisQuarter();
        break;
      case 'This Year':
        _dateRange = DynamicDateRange.thisYear();
        break;
    }
  }

  // ignore: unused_element
  Widget _build3DEmbossedCharts() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 1, child: _build3DDonutChart()),
        const SizedBox(width: 16),
        Expanded(flex: 1, child: _build3DBarChart()),
      ],
    );
  }

  Widget _build3DDonutChart({bool isMobile = false}) {
    // Get filtered categories based on selection
    final filteredCategories = _selectedCategories.isEmpty
        ? _categories
        : _categories
              .where((cat) => _selectedCategories.contains(cat.categoryId))
              .toList();

    final topStores = _stores.take(isMobile ? 4 : 6).toList();
    final storeSales = topStores.map((store) {
      return filteredCategories.fold<double>(
        0,
        (sum, cat) => sum + (cat.storeSales[store.storeId] ?? 0),
      );
    }).toList();

    final colors = [
      const Color(0xFFFF6B9D),
      const Color(0xFFFA8BFF),
      const Color(0xFF667EEA),
      const Color(0xFF4FACFE),
      const Color(0xFF43E97B),
      const Color(0xFFFFA751),
    ];

    final chartData = topStores.asMap().entries.map((entry) {
      final idx = entry.key;
      final store = entry.value;
      final sales = storeSales[idx];
      return ChartSectionData(
        title: store.storeName,
        value: sales,
        color: colors[idx % colors.length],
        icon: Icons.store,
      );
    }).toList();

    return InteractiveDonutChart(
      data: chartData,
      title: 'Top Stores',
      size: isMobile ? 160 : 220,
      centerWidget: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${topStores.length}',
            style: TextStyle(
              fontSize: isMobile ? 22 : 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Text(
            'Stores',
            style: TextStyle(fontSize: isMobile ? 9 : 11, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _build3DBarChart({bool isMobile = false}) {
    // Get filtered categories based on selection, take top items based on screen
    final filteredCategories = _selectedCategories.isEmpty
        ? _categories
        : _categories
              .where((cat) => _selectedCategories.contains(cat.categoryId))
              .toList();
    final topCategories = filteredCategories.take(6).toList();

    // Show shimmer while loading
    if (topCategories.isEmpty && _isLoading) {
      return Card(
        elevation: 4,
        child: Container(
          padding: EdgeInsets.all(isMobile ? 24 : 40),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (topCategories.isEmpty && !_isLoading) {
      return Card(
        elevation: 4,
        child: Container(
          padding: EdgeInsets.all(isMobile ? 24 : 40),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.donut_large,
                  size: isMobile ? 36 : 48,
                  color: Colors.black,
                ),
                const SizedBox(height: 8),
                Text(
                  'No data available',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final maxSales = topCategories.isNotEmpty
        ? topCategories.map((c) => c.totalSales).reduce((a, b) => a > b ? a : b)
        : 1.0;

    final colors = [
      const Color(0xFFE040FB), // Pink/Magenta
      const Color(0xFF7C4DFF), // Purple
      const Color(0xFF00BCD4), // Teal/Cyan
      const Color(0xFFFF5722), // Orange/Red
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFFEB3B), // Yellow
    ];

    final icons = [
      Icons.local_cafe,
      Icons.cake,
      Icons.emoji_food_beverage,
      Icons.restaurant,
      Icons.fastfood,
      Icons.icecream,
    ];

    // Show sales trend chart instead of gauge chart
    if (_salesTrendData.isEmpty) {
      return Card(
        elevation: 4,
        child: Container(
          padding: EdgeInsets.all(isMobile ? 24 : 40),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.trending_up,
                  size: isMobile ? 36 : 48,
                  color: Colors.black,
                ),
                const SizedBox(height: 8),
                Text(
                  'No sales trend data available',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Use SalesTrendChart with 5 chart types (Line, Bar, Area, Scatter, Step)
    return SalesTrendChart(
      data: _salesTrendData,
      title: 'Sales Trend',
      showChartSelector: true,
      initialChartType: 0, // Start with Line Chart
    );
  }

  Widget _buildModernDataTable() {
    // Show shimmer while loading
    if (_isLoading && _categories.isEmpty) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_categories.isEmpty && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Text(
            'No data available for the selected date range',
            style: TextStyle(fontSize: 16, color: Colors.black),
          ),
        ),
      );
    }

    // Filter categories based on selection
    final displayCategories = _selectedCategories.isEmpty
        ? _categories
        : _categories
              .where((cat) => _selectedCategories.contains(cat.categoryId))
              .toList();

    // Calculate dynamic height based on data rows including grand total
    // Each row ~48px, header ~120px (title + column headers), grand total ~60px, padding ~20px
    final rowCount = displayCategories.length;
    final minHeight = 250.0;
    final calculatedHeight = (120 + (rowCount * 48) + 60 + 20).toDouble();
    final tableHeight = calculatedHeight.clamp(minHeight, 600.0);

    return Container(
      height: tableHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: HierarchicalDataTable(
          key: ValueKey(
            'table_${_selectedCategories.length}_${_selectedStores.length}',
          ),
          categories: displayCategories,
          stores: _stores
              .where((s) => _selectedStores.contains(s.storeId))
              .toList(),
          onCategoryExpand: _loadCategoryItems,
          isLoading:
              false, // Don't show table's loading state, use overlay popup instead
          showGrandTotal:
              true, // Grand total inside table, scrolls with content
        ),
      ),
    );
  }

  Widget _buildModernSummaryCards({bool isMobile = false}) {
    // Calculate filtered values
    final filteredStoreCount = _selectedStores.length;
    final filteredCategories = _selectedCategories.isEmpty
        ? _categories
        : _categories
              .where((cat) => _selectedCategories.contains(cat.categoryId))
              .toList();
    final filteredCategoryCount = filteredCategories.length;

    // Calculate total sales from filtered categories AND filtered stores
    double filteredTotalSales = 0;
    for (final cat in filteredCategories) {
      for (final storeId in _selectedStores) {
        filteredTotalSales += cat.storeSales[storeId] ?? 0;
      }
    }

    if (isMobile) {
      // 3-column compact grid on mobile
      return Row(
        children: [
          Expanded(
            child: _buildCompactSummaryCard(
              'Total\nStores',
              '$filteredStoreCount',
              Icons.store_rounded,
              const LinearGradient(
                colors: [Color(0xFFFF9A56), Color(0xFFFF6B35)],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCompactSummaryCard(
              'Cate\ngories',
              '$filteredCategoryCount',
              Icons.category_rounded,
              const LinearGradient(
                colors: [Color(0xFFB24BF3), Color(0xFF8E2DE2)],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCompactSummaryCard(
              'Total\nSales',
              _formatCompactCurrency(filteredTotalSales),
              Icons.attach_money_rounded,
              const LinearGradient(
                colors: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Stores',
            '$filteredStoreCount',
            Icons.store_rounded,
            const LinearGradient(
              colors: [Color(0xFFFF9A56), Color(0xFFFF6B35)],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Categories',
            '$filteredCategoryCount',
            Icons.category_rounded,
            const LinearGradient(
              colors: [Color(0xFFB24BF3), Color(0xFF8E2DE2)],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Total Sales',
            _currencyFormat.format(filteredTotalSales),
            Icons.attach_money_rounded,
            const LinearGradient(
              colors: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    LinearGradient gradient,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Compact summary card for mobile
  Widget _buildCompactSummaryCard(
    String title,
    String value,
    IconData icon,
    LinearGradient gradient,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Format currency compactly for mobile
  String _formatCompactCurrency(double value) {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}K';
    }
    return '\$${value.toStringAsFixed(0)}';
  }

  // ignore: unused_element
  Widget _buildChartsSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: _buildCategoryPieChart()),
        const SizedBox(width: 24),
        Expanded(flex: 2, child: _buildStorePieChart()),
        const SizedBox(width: 24),
        Expanded(flex: 3, child: _buildTopCategoriesBarChart()),
      ],
    );
  }

  Widget _buildCategoryPieChart() {
    // Top 5 categories by sales
    final topCategories = _categories.take(5).toList();
    final total = topCategories.fold<double>(
      0,
      (sum, cat) => sum + cat.totalSales,
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[700]!, Colors.blue[900]!],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Categories',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ...topCategories.map((cat) {
            final percentage = (cat.totalSales / total * 100);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          cat.categoryName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      minHeight: 8,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStorePieChart() {
    // Calculate sales per store
    final storeSales = <String, double>{};
    for (final store in _stores.where(
      (s) => _selectedStores.contains(s.storeId),
    )) {
      double total = 0;
      for (final cat in _categories) {
        total += cat.storeSales[store.storeId] ?? 0;
      }
      storeSales[store.storeName] = total;
    }

    final sortedStores = storeSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topStores = sortedStores.take(5).toList();
    final total = topStores.fold<double>(0, (sum, entry) => sum + entry.value);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.teal[600]!, Colors.teal[800]!],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Stores',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ...topStores.map((entry) {
            final percentage = (entry.value / total * 100);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      minHeight: 8,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopCategoriesBarChart() {
    final topCategories = _categories.take(8).toList();
    final maxSales = topCategories.isNotEmpty
        ? topCategories.map((c) => c.totalSales).reduce((a, b) => a > b ? a : b)
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple[600]!, Colors.deepPurple[900]!],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales by Category',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ...topCategories.map((cat) {
            final barWidth = (cat.totalSales / maxSales);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          cat.categoryName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(cat.totalSales),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: barWidth,
                      minHeight: 10,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Error Loading Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: TextStyle(fontSize: 14, color: Colors.black),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreSelectionDialog extends StatefulWidget {
  final List<PowerBIStore> stores;
  final Set<String> selectedStores;
  final Function(Set<String>) onSelectionChanged;

  const _StoreSelectionDialog({
    required this.stores,
    required this.selectedStores,
    required this.onSelectionChanged,
  });

  @override
  State<_StoreSelectionDialog> createState() => _StoreSelectionDialogState();
}

class _StoreSelectionDialogState extends State<_StoreSelectionDialog> {
  late Set<String> _tempSelection;

  @override
  void initState() {
    super.initState();
    _tempSelection = Set.from(widget.selectedStores);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[600],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.store, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Select Stores',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _tempSelection = widget.stores
                            .map((s) => s.storeId)
                            .toSet();
                      });
                    },
                    icon: const Icon(Icons.select_all, size: 18),
                    label: const Text('Select All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                      side: BorderSide(color: Colors.blue[300]!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _tempSelection.clear();
                      });
                    },
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_tempSelection.length} of ${widget.stores.length} selected',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Store List
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: widget.stores.length,
                itemBuilder: (context, index) {
                  final store = widget.stores[index];
                  final isSelected = _tempSelection.contains(store.storeId);

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue[50] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? Colors.blue[300]!
                            : Colors.grey[200]!,
                      ),
                    ),
                    child: CheckboxListTile(
                      title: Text(
                        store.storeName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                      subtitle: store.city != null
                          ? Text(
                              store.city!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            )
                          : null,
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _tempSelection.add(store.storeId);
                          } else {
                            _tempSelection.remove(store.storeId);
                          }
                        });
                      },
                      activeColor: Colors.blue[600],
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                  );
                },
              ),
            ),
            // Footer buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      widget.onSelectionChanged(_tempSelection);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Apply Selection',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Category Selection Dialog
class _CategorySelectionDialog extends StatefulWidget {
  final List<PowerBICategory> categories;
  final Set<String> selectedCategories;
  final Function(Set<String>) onSelectionChanged;

  const _CategorySelectionDialog({
    required this.categories,
    required this.selectedCategories,
    required this.onSelectionChanged,
  });

  @override
  State<_CategorySelectionDialog> createState() =>
      _CategorySelectionDialogState();
}

class _CategorySelectionDialogState extends State<_CategorySelectionDialog> {
  late Set<String> _tempSelection;

  @override
  void initState() {
    super.initState();
    // If no categories are selected, default to all selected
    if (widget.selectedCategories.isEmpty) {
      _tempSelection = widget.categories.map((c) => c.categoryId).toSet();
    } else {
      _tempSelection = Set.from(widget.selectedCategories);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 550,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[600]!, Colors.green[800]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.category,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Select Categories',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _tempSelection = widget.categories
                            .map((c) => c.categoryId)
                            .toSet();
                      });
                    },
                    icon: const Icon(Icons.select_all, size: 18),
                    label: const Text('Select All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green[700],
                      side: BorderSide(color: Colors.green[300]!),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _tempSelection.clear();
                      });
                    },
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _tempSelection.isEmpty
                          ? 'All Categories'
                          : '${_tempSelection.length} selected',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Category list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: widget.categories.length,
                itemBuilder: (context, index) {
                  final category = widget.categories[index];
                  final isSelected = _tempSelection.contains(
                    category.categoryId,
                  );

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 0,
                    color: isSelected ? Colors.green[50] : Colors.grey[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.green[300]!
                            : Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _tempSelection.remove(category.categoryId);
                          } else {
                            _tempSelection.add(category.categoryId);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.green[600]
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.green[600]!
                                      : Colors.black87,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                category.categoryName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? Colors.green[800]
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Footer buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      widget.onSelectionChanged(_tempSelection);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Apply Selection',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Duration Selection Dialog
class _DurationSelectionDialog extends StatefulWidget {
  final List<String> durations;
  final String selectedDuration;
  final Function(String) onSelectionChanged;

  const _DurationSelectionDialog({
    required this.durations,
    required this.selectedDuration,
    required this.onSelectionChanged,
  });

  @override
  State<_DurationSelectionDialog> createState() =>
      _DurationSelectionDialogState();
}

class _DurationSelectionDialogState extends State<_DurationSelectionDialog> {
  late String _tempSelection;

  @override
  void initState() {
    super.initState();
    _tempSelection = widget.selectedDuration;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[600]!, Colors.purple[800]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Select Duration',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Duration list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: widget.durations.length,
                itemBuilder: (context, index) {
                  final duration = widget.durations[index];
                  final isSelected = _tempSelection == duration;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 0,
                    color: isSelected ? Colors.purple[50] : Colors.grey[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.purple[300]!
                            : Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _tempSelection = duration;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.purple[600]
                                    : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.purple[600]!
                                      : Colors.grey[400]!,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                duration,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? Colors.purple[800]
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Footer buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      widget.onSelectionChanged(_tempSelection);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Apply Selection',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Discount Pie Chart Painter
class _DiscountPieChartPainter extends CustomPainter {
  final List<double> data;
  final List<Color> colors;

  _DiscountPieChartPainter({required this.data, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final total = data.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius =
        (size.width < size.height ? size.width : size.height) / 2 - 10;

    double startAngle = -3.14159 / 2; // Start from top

    for (int i = 0; i < data.length; i++) {
      final sweepAngle = (data[i] / total) * 2 * 3.14159;

      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Add white border between slices
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_DiscountPieChartPainter oldDelegate) =>
      data != oldDelegate.data || colors != oldDelegate.colors;
}

// ignore: unused_element
class _PieSlicePainter extends CustomPainter {
  final Color color;
  final double percentage;

  _PieSlicePainter({required this.color, required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    // Guard against invalid percentage
    if (percentage <= 0 || percentage.isNaN || percentage.isInfinite) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final startAngle = -3.14159 / 2;
    final sweepAngle = 2 * 3.14159 * percentage.clamp(0.0, 1.0);

    canvas.drawArc(rect, startAngle, sweepAngle, true, paint);

    // Add 3D effect with darker edge
    final edgePaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawArc(rect, startAngle, sweepAngle, true, edgePaint);
  }

  @override
  bool shouldRepaint(_PieSlicePainter oldDelegate) =>
      color != oldDelegate.color || percentage != oldDelegate.percentage;
}

// Donut Chart Painter for drill-down view
class _DonutChartPainter extends CustomPainter {
  final List<double> data;
  final List<Color> colors;

  _DonutChartPainter({required this.data, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final total = data.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius =
        (size.width < size.height ? size.width : size.height) / 2 - 5;
    final innerRadius = outerRadius * 0.55; // Donut hole

    double startAngle = -math.pi / 2; // Start from top

    for (int i = 0; i < data.length; i++) {
      final sweepAngle = (data[i] / total) * 2 * math.pi;

      final path = Path();

      // Outer arc
      path.addArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        startAngle,
        sweepAngle,
      );

      // Line to inner arc
      final endAngle = startAngle + sweepAngle;
      path.lineTo(
        center.dx + innerRadius * math.cos(endAngle),
        center.dy + innerRadius * math.sin(endAngle),
      );

      // Inner arc (reversed)
      path.arcTo(
        Rect.fromCircle(center: center, radius: innerRadius),
        endAngle,
        -sweepAngle,
        false,
      );

      path.close();

      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, paint);

      // Add subtle shadow/border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawPath(path, borderPaint);

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutChartPainter oldDelegate) =>
      data != oldDelegate.data || colors != oldDelegate.colors;
}

// Shimmer effect widget for loading states
class _ShimmerEffect extends StatefulWidget {
  final Widget child;
  const _ShimmerEffect({required this.child});

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.grey[300]!, Colors.grey[100]!, Colors.grey[300]!],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((s) => s.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}
