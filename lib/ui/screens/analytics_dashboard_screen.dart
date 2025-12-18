import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../../providers/analytics_provider.dart';
import '../../providers/database_provider.dart';
import '../../data/models/analytics_model.dart';
import '../widgets/shimmer_widgets.dart';
import '../widgets/drill_down_dialog.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedChartType = 0; // 0: Line, 1: Bar, 2: Area, 3: Scatter, 4: Step
  bool _showAdvancedMetrics = true;
  String? _lastDatabaseId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataIfNeeded();
    });
  }

  void _loadDataIfNeeded() {
    final dbProvider = context.read<DatabaseProvider>();
    // Only load if we have the correct database
    if (dbProvider.isPOSDatabase) {
      _lastDatabaseId = dbProvider.currentDatabase?.id;
      context.read<AnalyticsProvider>().loadDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dbProvider = context.watch<DatabaseProvider>();

    // Show loading if database is being switched
    if (dbProvider.isLoading && !dbProvider.isPOSDatabase) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Switching to POS Database...',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      );
    }

    // Check if database changed and reload data
    if (dbProvider.isPOSDatabase &&
        dbProvider.currentDatabase?.id != _lastDatabaseId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDataIfNeeded();
      });
    }

    // Check if we're on the wrong database (and not loading)
    if (!dbProvider.isPOSDatabase) {
      return Scaffold(
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 64, color: Colors.orange[400]),
                const SizedBox(height: 16),
                Text(
                  'Wrong Database',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'POS Analytics requires the RuposPreProd database.\nCurrently connected to: ${dbProvider.currentDatabase?.name ?? "None"}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    final posDb = dbProvider.availableDatabases.firstWhere(
                      (db) => db.id == 'rupos_preprod',
                    );
                    dbProvider.switchDatabase(posDb);
                  },
                  icon: const Icon(Icons.sync),
                  label: const Text('Switch to POS Database'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Consumer<AnalyticsProvider>(
        builder: (context, provider, _) {
          // Show shimmer loading for initial load
          if (provider.isLoading && provider.salesOverview.totalOrders == 0) {
            return _buildShimmerLoading(context);
          }

          return FilterLoadingOverlay(
            isLoading:
                provider.isLoading && provider.salesOverview.totalOrders > 0,
            child: RefreshIndicator(
              onRefresh: provider.loadDashboard,
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(context, provider),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildFilterBar(context, provider),
                        _buildOverallSummary(context, provider),
                        _buildSalesTrendChart(context, provider),
                        _buildComparisonChartsRow(context, provider),
                        _buildHourlySalesHeatmap(context, provider),
                        _buildSalesByTypeSection(context, provider),
                        _buildTopPerformersSection(context, provider),
                        const SizedBox(height: 80), // Space for FAB
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: _buildChatbotFAB(context),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 1200 ? 4 : (screenWidth > 800 ? 3 : 2);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: const Text('Analytics Dashboard'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              // Shimmer filter chips
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 8,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: MinimalShimmer(
                      width: 80,
                      height: 32,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              // Shimmer KPI cards
              ShimmerKPIGrid(count: 8, crossAxisCount: crossAxisCount),
              // Shimmer chart
              const ShimmerChart(height: 300),
              // Shimmer tabs
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: List.generate(
                    6,
                    (i) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: MinimalShimmer(
                          height: 40,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Shimmer list items
              const ShimmerList(count: 5),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context, AnalyticsProvider provider) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return SliverAppBar(
      expandedHeight: isMobile ? 56 : 70,
      floating: true,
      pinned: true,
      elevation: 2,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(left: isMobile ? 16 : 24, bottom: 12),
        title: Text(
          'Analytics Dashboard',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 16 : 18,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 22),
          onPressed: provider.loadDashboard,
          tooltip: 'Refresh',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.file_download_outlined, size: 22),
          tooltip: 'Export',
          elevation: 16,
          onSelected: (value) => _handleExport(context, provider, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'pdf',
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Export as PDF'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'excel',
              child: Row(
                children: [
                  Icon(Icons.table_chart, size: 20, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Export as Excel'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'csv',
              child: Row(
                children: [
                  Icon(Icons.description, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Export as CSV'),
                ],
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.calendar_month, size: 22),
          onPressed: () => _showDateRangePicker(context, provider),
          tooltip: 'Custom Date Range',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ==================== MODERN FILTER BAR ====================

  Widget _buildFilterBar(BuildContext context, AnalyticsProvider provider) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.2),
            Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
            ),
            child: isMobile
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDateRangeDropdown(context, provider),
                      const SizedBox(height: 12),
                      _buildStoreDropdown(context, provider),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: isTablet ? 3 : 2,
                        child: _buildDateRangeDropdown(context, provider),
                      ),
                      SizedBox(width: isMobile ? 8 : 16),
                      Expanded(
                        flex: isTablet ? 2 : 1,
                        child: _buildStoreDropdown(context, provider),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeDropdown(
    BuildContext context,
    AnalyticsProvider provider,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final filterOptions = [
      ('Today', 'today', Icons.today, Colors.orange),
      ('Yesterday', 'yesterday', Icons.calendar_today, Colors.blue),
      ('This Week', 'this_week', Icons.view_week, Colors.purple),
      ('Last 7 Days', 'last_7_days', Icons.date_range, Colors.cyan),
      ('This Month', 'this_month', Icons.calendar_month, Colors.green),
      ('Last 30 Days', 'last_30_days', Icons.calendar_view_month, Colors.teal),
      ('This Quarter', 'this_quarter', Icons.pie_chart, Colors.indigo),
      ('This Year', 'this_year', Icons.calendar_view_week, Colors.deepPurple),
      ('Last 365 Days', 'last_365_days', Icons.history, Colors.amber),
      ('All Time', 'all_time', Icons.all_inclusive, Colors.pink),
      ('Custom Range', 'custom', Icons.edit_calendar, Colors.red),
    ];

    final currentFilterType = provider.currentFilter.filterType;
    final selectedOption = filterOptions.firstWhere(
      (opt) => opt.$2 == currentFilterType,
      orElse: () => filterOptions[0],
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            selectedOption.$4.withOpacity(0.15),
            selectedOption.$4.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selectedOption.$4.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: selectedOption.$4.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {}, // Handled by dropdown
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 10 : 12,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedOption.$2,
                isExpanded: true,
                isDense: false,
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: selectedOption.$4.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: selectedOption.$4,
                    size: 20,
                  ),
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: isMobile ? 14 : 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
                dropdownColor: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                elevation: 24,
                items: filterOptions.map((option) {
                  final isSelected = option.$2 == selectedOption.$2;
                  return DropdownMenuItem<String>(
                    value: option.$2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      decoration: isSelected
                          ? BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  option.$4.withOpacity(0.15),
                                  option.$4.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            )
                          : null,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: option.$4.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(option.$3, size: 18, color: option.$4),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option.$1,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? option.$4
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: option.$4,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (String? value) async {
                  if (value == null) return;

                  if (value == 'custom') {
                    await _showCustomDateRangePicker(context, provider);
                  } else {
                    // Apply predefined filter
                    switch (value) {
                      case 'today':
                        provider.filterToday();
                        break;
                      case 'yesterday':
                        provider.filterYesterday();
                        break;
                      case 'this_week':
                        provider.filterThisWeek();
                        break;
                      case 'last_7_days':
                        provider.filterLast7Days();
                        break;
                      case 'this_month':
                        provider.filterThisMonth();
                        break;
                      case 'last_30_days':
                        provider.filterLast30Days();
                        break;
                      case 'this_quarter':
                        provider.filterThisQuarter();
                        break;
                      case 'this_year':
                        provider.filterThisYear();
                        break;
                      case 'last_365_days':
                        provider.filterLast365Days();
                        break;
                      case 'all_time':
                        provider.filterAllTime();
                        break;
                    }
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreDropdown(BuildContext context, AnalyticsProvider provider) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final hasSelection = provider.hasStoreFilter;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: hasSelection
            ? LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                  Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.8),
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasSelection
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          width: hasSelection ? 2 : 1.5,
        ),
        boxShadow: hasSelection
            ? [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showStoreSelectionDialog(context, provider),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 12 : 14,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: hasSelection
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasSelection
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    size: 18,
                    color: hasSelection
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasSelection
                            ? '${provider.selectedStores.length} Store${provider.selectedStores.length > 1 ? 's' : ''} Selected'
                            : 'All Stores',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 14 : 15,
                          color: hasSelection
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (hasSelection && !isMobile)
                        Text(
                          'Tap to change',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ),
                if (hasSelection)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          provider.clearStoreSelection();
                          provider.loadDashboard();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCustomDateRangePicker(
    BuildContext context,
    AnalyticsProvider provider,
  ) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: provider.currentFilter.startDate,
        end: provider.currentFilter.endDate,
      ),
      helpText: 'Select Custom Date Range',
      cancelText: 'Cancel',
      confirmText: 'Apply',
      saveText: 'Done',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 16,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
              headerBackgroundColor: Theme.of(context).colorScheme.primary,
              headerForegroundColor: Theme.of(context).colorScheme.onPrimary,
              dayStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              rangePickerBackgroundColor: Theme.of(
                context,
              ).colorScheme.primaryContainer,
              rangeSelectionBackgroundColor: Theme.of(
                context,
              ).colorScheme.primaryContainer.withOpacity(0.3),
              todayBorder: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final customFilter = DateRangeFilter.custom(picked.start, picked.end);
      await provider.applyFilter(customFilter);
    }
  }

  // ignore: unused_element
  Widget _buildDateFilterChips(
    BuildContext context,
    AnalyticsProvider provider,
  ) {
    final filters = [
      ('Today', provider.filterToday, 'today'),
      ('Yesterday', provider.filterYesterday, 'yesterday'),
      ('This Week', provider.filterThisWeek, 'this_week'),
      ('Last 7 Days', provider.filterLast7Days, 'last_7_days'),
      ('This Month', provider.filterThisMonth, 'this_month'),
      ('Last 30 Days', provider.filterLast30Days, 'last_30_days'),
      ('This Quarter', provider.filterThisQuarter, 'this_quarter'),
      ('This Year', provider.filterThisYear, 'this_year'),
      ('Last 365 Days', provider.filterLast365Days, 'last_365_days'),
      ('All Time', provider.filterAllTime, 'all_time'),
    ];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final isSelected =
              provider.currentFilter.filterType == filters[index].$3;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filters[index].$1),
              selected: isSelected,
              onSelected: (_) => filters[index].$2(),
              backgroundColor: Theme.of(context).colorScheme.surface,
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== STORE SELECTOR ====================

  // ignore: unused_element
  Widget _buildStoreSelector(BuildContext context, AnalyticsProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _showStoreSelectionDialog(context, provider),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: provider.hasStoreFilter
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: provider.hasStoreFilter
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.store,
                      size: 20,
                      color: provider.hasStoreFilter
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        provider.hasStoreFilter
                            ? '${provider.selectedStores.length} Store${provider.selectedStores.length > 1 ? 's' : ''} Selected'
                            : 'All Stores',
                        style: TextStyle(
                          fontWeight: provider.hasStoreFilter
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: provider.hasStoreFilter
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: provider.hasStoreFilter
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (provider.hasStoreFilter) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                provider.clearStoreSelection();
                provider.loadDashboard();
              },
              icon: const Icon(Icons.clear, size: 20),
              tooltip: 'Clear store filter',
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showStoreSelectionDialog(
    BuildContext context,
    AnalyticsProvider provider,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _StoreSelectionDialog(provider: provider),
    );
  }

  // ==================== OVERALL SUMMARY SECTION ====================

  Widget _buildOverallSummary(
    BuildContext context,
    AnalyticsProvider provider,
  ) {
    final overview = provider.salesOverview;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    final crossAxisCount = isMobile ? 2 : (isTablet ? 4 : 4);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Summary Cards Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: isMobile ? 1.6 : 2.2,
            children: [
              _buildSummaryCard(
                context,
                'Total Sales',
                _formatCurrency(overview.totalSales),
                Icons.currency_rupee,
                Colors.green,
                subtitle: overview.growthPercentage != 0
                    ? '${overview.growthPercentage >= 0 ? '+' : ''}${overview.growthPercentage.toStringAsFixed(1)}%'
                    : null,
                isPositive: overview.growthPercentage >= 0,
              ),
              _buildSummaryCard(
                context,
                'Total Orders',
                overview.totalOrders.toString(),
                Icons.receipt_long,
                Colors.blue,
              ),
              _buildSummaryCard(
                context,
                'Net Revenue',
                _formatCurrency(overview.netRevenue),
                Icons.account_balance_wallet,
                Colors.purple,
              ),
              _buildSummaryCard(
                context,
                'Avg Order Value',
                _formatCurrency(overview.avgOrderValue),
                Icons.analytics,
                Colors.orange,
              ),
              _buildSummaryCard(
                context,
                'Tax Collected',
                _formatCurrency(overview.taxCollected),
                Icons.account_balance,
                Colors.teal,
              ),
              _buildSummaryCard(
                context,
                'Discounts Given',
                _formatCurrency(overview.discountGiven),
                Icons.discount,
                Colors.red,
              ),
              _buildSummaryCard(
                context,
                'Customers',
                overview.uniqueCustomers.toString(),
                Icons.people,
                Colors.indigo,
              ),
              _buildSummaryCard(
                context,
                'Products Sold',
                overview.totalProducts.toString(),
                Icons.inventory_2,
                Colors.amber.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
    bool isPositive = true,
  }) {
    return Card(
      elevation: 2,
      shadowColor: color.withOpacity(0.2),
      margin: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.03)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (subtitle != null)
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  size: 14,
                  color: isPositive ? Colors.green : Colors.red,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildKPICards(BuildContext context, AnalyticsProvider provider) {
    final overview = provider.salesOverview;

    // Create KPI items with their values for sorting
    final kpiItems = [
      _KPIItem(
        'Total Sales',
        overview.totalSales,
        _formatCurrency(overview.totalSales),
        Icons.attach_money,
        Colors.green,
        overview.growthPercentage,
      ),
      _KPIItem(
        'Total Orders',
        overview.totalOrders.toDouble(),
        overview.totalOrders.toString(),
        Icons.shopping_cart,
        Colors.blue,
        null,
      ),
      _KPIItem(
        'Avg Order Value',
        overview.avgOrderValue,
        _formatCurrency(overview.avgOrderValue),
        Icons.trending_up,
        Colors.orange,
        null,
      ),
      _KPIItem(
        'Customers',
        overview.uniqueCustomers.toDouble(),
        overview.uniqueCustomers.toString(),
        Icons.people,
        Colors.purple,
        null,
      ),
      _KPIItem(
        'Tax Collected',
        overview.taxCollected,
        _formatCurrency(overview.taxCollected),
        Icons.account_balance,
        Colors.teal,
        null,
      ),
      _KPIItem(
        'Discounts',
        overview.discountGiven,
        _formatCurrency(overview.discountGiven),
        Icons.discount,
        Colors.red,
        null,
      ),
      _KPIItem(
        'Products Sold',
        overview.totalProducts.toDouble(),
        overview.totalProducts.toString(),
        Icons.inventory,
        Colors.indigo,
        null,
      ),
      _KPIItem(
        'Fill Rate',
        provider.fillRate?.overallPercentage ?? 0,
        '${provider.fillRate?.overallPercentage.toStringAsFixed(1) ?? '0'}%',
        Icons.check_circle,
        Colors.cyan,
        null,
      ),
    ];

    // Sort: items with data first, then by value descending
    kpiItems.sort((a, b) {
      if (a.rawValue > 0 && b.rawValue == 0) return -1;
      if (a.rawValue == 0 && b.rawValue > 0) return 1;
      return b.rawValue.compareTo(a.rawValue);
    });

    // Separate items with data and without
    final itemsWithData = kpiItems.where((k) => k.rawValue > 0).toList();
    final itemsWithoutData = kpiItems.where((k) => k.rawValue == 0).toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Stats Row - Top 3 with data
          if (itemsWithData.isNotEmpty) ...[
            _buildHeroStatsRow(context, itemsWithData.take(3).toList()),
            const SizedBox(height: 16),
          ],

          // Secondary Stats - Remaining with data
          if (itemsWithData.length > 3) ...[
            _buildSecondaryStats(context, itemsWithData.skip(3).toList()),
            const SizedBox(height: 16),
          ],

          // Gauge Charts Row
          if (itemsWithData.isNotEmpty)
            _buildGaugeChartsRow(context, overview, provider),

          // No Data Section (collapsed)
          if (itemsWithoutData.isNotEmpty)
            _buildNoDataSection(context, itemsWithoutData),
        ],
      ),
    );
  }

  Widget _buildHeroStatsRow(BuildContext context, List<_KPIItem> items) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return SizedBox(
      height: isMobile ? 140 : 160,
      child: Row(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isFirst = index == 0;

          return Expanded(
            flex: isFirst ? 2 : 1,
            child: Padding(
              padding: EdgeInsets.only(
                right: index < items.length - 1 ? 12 : 0,
              ),
              child: isFirst
                  ? _buildHeroCard(context, item)
                  : _buildCompactCard(context, item),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, _KPIItem item) {
    return Card(
      elevation: 8,
      shadowColor: item.color.withOpacity(0.4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              item.color.withOpacity(0.15),
              item.color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                item.icon,
                size: 100,
                color: item.color.withOpacity(0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, color: item.color, size: 24),
                      ),
                      if (item.change != null)
                        _buildChangeChip(item.change!, item.change! >= 0),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.displayValue,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: item.color,
                              ),
                        ),
                      ),
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context, _KPIItem item) {
    return Card(
      elevation: 4,
      shadowColor: item.color.withOpacity(0.3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [item.color.withOpacity(0.1), item.color.withOpacity(0.03)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.displayValue,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: item.color,
                  ),
                ),
              ),
              Text(
                item.title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryStats(BuildContext context, List<_KPIItem> items) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              elevation: 2,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border(left: BorderSide(color: item.color, width: 4)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(item.icon, color: item.color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.displayValue,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: item.color,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGaugeChartsRow(
    BuildContext context,
    SalesOverview overview,
    AnalyticsProvider provider,
  ) {
    final fillRate = provider.fillRate?.overallPercentage ?? 0;
    final avgOrderValue = overview.avgOrderValue;
    final maxExpectedAOV = 5000.0; // Expected max AOV for gauge
    final aovPercentage = (avgOrderValue / maxExpectedAOV * 100).clamp(0, 100);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Metrics',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildRadialGauge(
                    context,
                    'Fill Rate',
                    fillRate,
                    fillRate >= 95
                        ? Colors.green
                        : (fillRate >= 80 ? Colors.orange : Colors.red),
                    Icons.check_circle_outline,
                  ),
                ),
                Expanded(
                  child: _buildRadialGauge(
                    context,
                    'AOV Score',
                    aovPercentage.toDouble(),
                    Colors.blue,
                    Icons.trending_up,
                  ),
                ),
                Expanded(
                  child: _buildProgressRing(
                    context,
                    'Orders Today',
                    overview.totalOrders,
                    100, // Target
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadialGauge(
    BuildContext context,
    String label,
    double percentage,
    Color color,
    IconData icon,
  ) {
    return Tooltip(
      message: '$label: ${percentage.toStringAsFixed(1)}%',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          children: [
            SizedBox(
              height: 100,
              width: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 90,
                    width: 90,
                    child: CircularProgressIndicator(
                      value: percentage / 100,
                      strokeWidth: 8,
                      backgroundColor: color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(color),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: color, size: 20),
                      Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRing(
    BuildContext context,
    String label,
    int current,
    int target,
    Color color,
  ) {
    final percentage = (current / target * 100).clamp(0, 100);

    return Tooltip(
      message: '$label: $current / $target (${percentage.toStringAsFixed(1)}%)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          children: [
            SizedBox(
              height: 100,
              width: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 90,
                    width: 90,
                    child: CircularProgressIndicator(
                      value: percentage / 100,
                      strokeWidth: 8,
                      backgroundColor: color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(color),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$current',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '/ $target',
                        style: TextStyle(
                          color: color.withOpacity(0.6),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataSection(BuildContext context, List<_KPIItem> items) {
    return ExpansionTile(
      initiallyExpanded: false,
      title: Text(
        'Awaiting Data (${items.length})',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
      leading: Icon(
        Icons.hourglass_empty,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map(
                (item) => Chip(
                  avatar: Icon(
                    item.icon,
                    size: 16,
                    color: item.color.withOpacity(0.5),
                  ),
                  label: Text(
                    item.title,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: item.color.withOpacity(0.05),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildChangeChip(double change, bool isPositive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPositive
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            size: 14,
            color: isPositive ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  // Removed old _buildKPICard method - replaced with new design

  // ==================== NEW BUSINESS METRICS SECTION ====================

  // ignore: unused_element
  Widget _buildBusinessMetricsSection(
    BuildContext context,
    AnalyticsProvider provider,
  ) {
    final overview = provider.salesOverview;
    final fillRate = provider.fillRate;

    // Calculate business metrics
    final avgItemsPerOrder = overview.totalOrders > 0
        ? (overview.totalProducts / overview.totalOrders)
        : 0.0;
    final revenuePerCustomer = overview.uniqueCustomers > 0
        ? (overview.totalSales / overview.uniqueCustomers)
        : 0.0;
    final discountRate = overview.totalSales > 0
        ? (overview.discountGiven /
              (overview.totalSales + overview.discountGiven) *
              100)
        : 0.0;
    final taxRate = overview.totalSales > 0
        ? (overview.taxCollected / overview.totalSales * 100)
        : 0.0;
    final ordersPerCustomer = overview.uniqueCustomers > 0
        ? (overview.totalOrders / overview.uniqueCustomers)
        : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.insights,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Business Intelligence',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    _showAdvancedMetrics
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  onPressed: () {
                    setState(() {
                      _showAdvancedMetrics = !_showAdvancedMetrics;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Row 1: Fill Rate & Revenue Metrics
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context,
                    'Fill Rate',
                    '${fillRate?.overallPercentage.toStringAsFixed(1) ?? '0'}%',
                    _getFillRateStatus(fillRate?.overallPercentage ?? 0),
                    Icons.inventory_2,
                    _getFillRateColor(fillRate?.overallPercentage ?? 0),
                    tooltip: 'Order fulfillment rate - Target: 95%+',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    'Basket Size',
                    avgItemsPerOrder.toStringAsFixed(1),
                    'items/order',
                    Icons.shopping_basket,
                    Colors.purple,
                    tooltip: 'Average items per order',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    'Revenue/Customer',
                    _formatCurrency(revenuePerCustomer),
                    'lifetime value',
                    Icons.person_pin,
                    Colors.blue,
                    tooltip: 'Average revenue per unique customer',
                  ),
                ),
              ],
            ),

            if (_showAdvancedMetrics) ...[
              const SizedBox(height: 16),

              // Row 2: Transaction Metrics
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      context,
                      'Orders/Customer',
                      ordersPerCustomer.toStringAsFixed(2),
                      'frequency',
                      Icons.repeat,
                      Colors.teal,
                      tooltip: 'Average orders per customer',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      context,
                      'Discount Rate',
                      '${discountRate.toStringAsFixed(1)}%',
                      _formatCurrency(overview.discountGiven),
                      Icons.discount,
                      discountRate > 10 ? Colors.orange : Colors.green,
                      tooltip: 'Discount as % of gross sales',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      context,
                      'Tax Rate',
                      '${taxRate.toStringAsFixed(1)}%',
                      _formatCurrency(overview.taxCollected),
                      Icons.receipt_long,
                      Colors.indigo,
                      tooltip: 'Tax collected as % of sales',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Revenue Breakdown Bar
              _buildRevenueBreakdownBar(context, overview),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color, {
    String? tooltip,
  }) {
    final tile = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    return tooltip != null ? Tooltip(message: tooltip, child: tile) : tile;
  }

  Widget _buildRevenueBreakdownBar(
    BuildContext context,
    SalesOverview overview,
  ) {
    final grossSales = overview.totalSales + overview.discountGiven;
    final netAfterTax = overview.netRevenue;

    if (grossSales == 0) return const SizedBox.shrink();

    final discountPercent = (overview.discountGiven / grossSales * 100);
    final taxPercent = (overview.taxCollected / grossSales * 100);
    final netPercent = (netAfterTax / grossSales * 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Revenue Breakdown',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            Text(
              'Gross: ${_formatCurrency(grossSales)}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 24,
            child: Row(
              children: [
                Expanded(
                  flex: netPercent.round(),
                  child: Tooltip(
                    message:
                        'Net Revenue: ${_formatCurrency(netAfterTax)} (${netPercent.toStringAsFixed(1)}%)',
                    child: Container(
                      color: Colors.green,
                      alignment: Alignment.center,
                      child: Text(
                        netPercent > 15
                            ? 'Net ${netPercent.toStringAsFixed(0)}%'
                            : '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                if (taxPercent > 0)
                  Expanded(
                    flex: taxPercent.round().clamp(1, 100),
                    child: Tooltip(
                      message:
                          'Tax: ${_formatCurrency(overview.taxCollected)} (${taxPercent.toStringAsFixed(1)}%)',
                      child: Container(
                        color: Colors.indigo,
                        alignment: Alignment.center,
                        child: Text(
                          taxPercent > 8 ? 'Tax' : '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (discountPercent > 0)
                  Expanded(
                    flex: discountPercent.round().clamp(1, 100),
                    child: Tooltip(
                      message:
                          'Discount: ${_formatCurrency(overview.discountGiven)} (${discountPercent.toStringAsFixed(1)}%)',
                      child: Container(
                        color: Colors.red.shade400,
                        alignment: Alignment.center,
                        child: Text(
                          discountPercent > 5 ? 'Disc' : '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBreakdownLegend(
              'Net Revenue',
              Colors.green,
              _formatCurrency(netAfterTax),
            ),
            _buildBreakdownLegend(
              'Tax',
              Colors.indigo,
              _formatCurrency(overview.taxCollected),
            ),
            _buildBreakdownLegend(
              'Discount',
              Colors.red.shade400,
              _formatCurrency(overview.discountGiven),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBreakdownLegend(String label, Color color, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text('$label: $value', style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  String _getFillRateStatus(double rate) {
    if (rate >= 95) return 'Excellent';
    if (rate >= 85) return 'Good';
    if (rate >= 70) return 'Warning';
    return 'Critical';
  }

  Color _getFillRateColor(double rate) {
    if (rate >= 95) return Colors.green;
    if (rate >= 85) return Colors.lightGreen;
    if (rate >= 70) return Colors.orange;
    return Colors.red;
  }

  // ==================== HOURLY SALES HEATMAP ====================

  Widget _buildHourlySalesHeatmap(
    BuildContext context,
    AnalyticsProvider provider,
  ) {
    final hourlySales = provider.hourlySales;

    if (hourlySales.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxSales = hourlySales.fold<double>(
      0,
      (max, h) => h.sales > max ? h.sales : max,
    );

    // Find peak hour
    final peakHour = hourlySales.isNotEmpty
        ? hourlySales.reduce((a, b) => a.sales > b.sales ? a : b)
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sales by Hour',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (peakHour != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Peak: ${peakHour.hourLabel}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                children: hourlySales.map((hourData) {
                  final intensity = maxSales > 0
                      ? (hourData.sales / maxSales)
                      : 0.0;
                  final color = _getHeatmapColor(intensity);

                  return Expanded(
                    child: Tooltip(
                      message:
                          '${hourData.hourLabel}\nSales: ${_formatCurrency(hourData.sales)}\nOrders: ${hourData.orders}',
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (hourData == peakHour)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${hourData.hour}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: intensity > 0.4
                                      ? Colors.white
                                      : Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            // Heatmap Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Low', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 8),
                ...List.generate(5, (i) {
                  return Container(
                    width: 20,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: _getHeatmapColor(i / 4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                const Text('High', style: TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getHeatmapColor(double intensity) {
    if (intensity < 0.2) return Colors.green.shade100;
    if (intensity < 0.4) return Colors.green.shade300;
    if (intensity < 0.6) return Colors.orange.shade300;
    if (intensity < 0.8) return Colors.orange.shade500;
    return Colors.red.shade500;
  }

  // ==================== SALES BY TYPE SECTION ====================

  Widget _buildSalesByTypeSection(
    BuildContext context,
    AnalyticsProvider provider,
  ) {
    final storeTypeSummaries = provider.storeTypeSummaries;
    final customerTypeSummaries = provider.customerTypeSummaries;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final isDesktop = screenWidth >= 900;

    // Calculate responsive values
    final cardWidth = isDesktop ? 280.0 : (isTablet ? 240.0 : 200.0);
    final cardHeight = isDesktop ? 170.0 : (isTablet ? 160.0 : 150.0);
    final gridCrossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);
    final gridAspectRatio = isDesktop ? 1.3 : (isTablet ? 1.4 : 2.5);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Type Section
            Row(
              children: [
                Icon(
                  Icons.people_alt,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sales by Customer Type',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (customerTypeSummaries.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No customer type data'),
                ),
              )
            else
              SizedBox(
                height: cardHeight,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: customerTypeSummaries.length,
                  itemBuilder: (context, index) {
                    return SizedBox(
                      width: cardWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: CustomerTypeSummaryCard(
                          summary: customerTypeSummaries[index],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),

            // Store Type Section with Drill-Down
            Row(
              children: [
                Icon(Icons.store, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Sales by Store Type',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Tap to drill down',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (storeTypeSummaries.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No store type data'),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridCrossAxisCount,
                  childAspectRatio: gridAspectRatio,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: storeTypeSummaries.length,
                itemBuilder: (context, index) {
                  final summary = storeTypeSummaries[index];
                  return StoreTypeDrillDownCard(
                    summary: summary,
                    onTap: () =>
                        _showStoreTypeDrillDown(context, provider, summary),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showStoreTypeDrillDown(
    BuildContext context,
    AnalyticsProvider provider,
    StoreTypeSummary summary,
  ) async {
    // Pre-build drill-down data from the summary we already have
    final drillDownData = DrillDownData(
      title: summary.storeType.displayName,
      subtitle: summary.storeType.description,
      items: summary.stores
          .map(
            (s) => DrillDownItem(
              id: s.storeId,
              name: s.storeName,
              subtitle: s.city.isNotEmpty ? s.city : null,
              value: s.totalSales,
              percentage: summary.totalSales > 0
                  ? (s.totalSales / summary.totalSales) * 100
                  : 0,
              count: s.orderCount,
              metadata: {
                'avgOrderValue': s.avgOrderValue,
                'storeType': s.storeType.displayName,
              },
            ),
          )
          .toList(),
      totalValue: summary.totalSales,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DrillDownDialog(data: drillDownData),
    );
  }

  // ==================== TOP PERFORMERS SECTION ====================

  Widget _buildTopPerformersSection(
    BuildContext context,
    AnalyticsProvider provider,
  ) {
    final products = provider.topProducts;
    final customers = provider.topCustomers;
    final categories = provider.categorySales;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Products & Categories Row
          isMobile
              ? Column(
                  children: [
                    _buildTopProductsCard(context, products),
                    const SizedBox(height: 12),
                    _buildTopCategoriesCard(context, categories),
                    const SizedBox(height: 12),
                    _buildTopCustomersCard(context, customers),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTopProductsCard(context, products),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          _buildTopCategoriesCard(context, categories),
                          const SizedBox(height: 12),
                          _buildTopCustomersCard(context, customers),
                        ],
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildTopProductsCard(
    BuildContext context,
    List<ProductSales> products,
  ) {
    if (products.isEmpty) return const SizedBox.shrink();

    final top5 = products.take(5).toList();
    final maxRevenue = top5.fold<double>(
      0,
      (max, p) => p.totalRevenue > max ? p.totalRevenue : max,
    );

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Top Products',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${products.length} items',
                    style: const TextStyle(fontSize: 11, color: Colors.amber),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...top5.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              final progress = maxRevenue > 0
                  ? (product.totalRevenue / maxRevenue)
                  : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildRankBadge(index + 1),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            product.productName,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatCurrency(product.totalRevenue),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getProductColor(index),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 32),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: _getProductColor(
                                index,
                              ).withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation(
                                _getProductColor(index),
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${product.quantitySold} units',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    final colors = [
      Colors.amber,
      Colors.grey.shade400,
      Colors.brown.shade300,
      Colors.blue,
      Colors.purple,
    ];
    final color = rank <= 3 ? colors[rank - 1] : colors[3 + (rank % 2)];

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(
        child: Text(
          '$rank',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildTopCategoriesCard(
    BuildContext context,
    List<CategorySales> categories,
  ) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final top4 = categories.take(4).toList();
    final total = top4.fold<double>(0, (sum, c) => sum + c.totalRevenue);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.category, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Top Categories',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...top4.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value;
              final percent = total > 0
                  ? (category.totalRevenue / total * 100)
                  : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(index),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        category.categoryName,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${percent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getCategoryColor(index),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCustomersCard(
    BuildContext context,
    List<CustomerAnalytics> customers,
  ) {
    if (customers.isEmpty) return const SizedBox.shrink();

    final top3 = customers.take(3).toList();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Top Customers',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...top3.asMap().entries.map((entry) {
              final customer = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: _getLoyaltyColor(customer.loyaltyTier),
                      child: Text(
                        customer.customerName.isNotEmpty
                            ? customer.customerName[0].toUpperCase()
                            : 'G',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.customerName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${customer.orderCount} orders • ${customer.loyaltyTier}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatCurrency(customer.totalSpent),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getLoyaltyColor(customer.loyaltyTier),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTrendChart(
    BuildContext context,
    AnalyticsProvider provider,
  ) {
    final trends = provider.salesTrend;
    final predictions = provider.salesPredictions;

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sales Trend & Predictions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        icon: Icon(Icons.show_chart, size: 16),
                        tooltip: 'Line Chart',
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: Icon(Icons.bar_chart, size: 16),
                        tooltip: 'Bar Chart',
                      ),
                      ButtonSegment(
                        value: 2,
                        icon: Icon(Icons.area_chart, size: 16),
                        tooltip: 'Area Chart',
                      ),
                      ButtonSegment(
                        value: 3,
                        icon: Icon(Icons.bubble_chart, size: 16),
                        tooltip: 'Scatter Chart',
                      ),
                      ButtonSegment(
                        value: 4,
                        icon: Icon(Icons.candlestick_chart, size: 16),
                        tooltip: 'Step Chart',
                      ),
                    ],
                    selected: {_selectedChartType},
                    onSelectionChanged: (Set<int> newSelection) {
                      setState(() {
                        _selectedChartType = newSelection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: trends.isEmpty
                  ? const Center(child: Text('No trend data available'))
                  : _buildChart(trends, predictions),
            ),
            if (predictions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(
                    'Actual Sales',
                    Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  _buildLegendItem('Predicted', Colors.orange),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChart(
    List<SalesTrend> trends,
    List<SalesPrediction> predictions,
  ) {
    final spots = trends
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.sales))
        .toList();
    final predictionSpots = predictions
        .asMap()
        .entries
        .map(
          (e) => FlSpot(
            (trends.length + e.key).toDouble(),
            e.value.predictedSales,
          ),
        )
        .toList();

    final maxY =
        [
          ...spots.map((s) => s.y),
          ...predictionSpots.map((s) => s.y),
        ].reduce(math.max) *
        1.2;

    switch (_selectedChartType) {
      case 1: // Bar Chart with tooltips
        return BarChart(
          BarChartData(
            maxY: maxY,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final date = trends[group.x].date;
                  return BarTooltipItem(
                    '${date.day}/${date.month}\n${_formatCurrency(rod.toY)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            barGroups: spots
                .map(
                  (spot) => BarChartGroupData(
                    x: spot.x.toInt(),
                    barRods: [
                      BarChartRodData(
                        toY: spot.y,
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.6),
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
            titlesData: _buildTitlesData(trends, maxY),
            borderData: FlBorderData(show: false),
            gridData: _buildGridData(),
          ),
        );
      case 2: // Area Chart with tooltips
        return LineChart(
          LineChartData(
            maxY: maxY,
            minY: 0,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Theme.of(context).colorScheme.primary,
                barWidth: 3,
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      Theme.of(context).colorScheme.primary.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                dotData: const FlDotData(show: false),
              ),
              if (predictionSpots.isNotEmpty)
                LineChartBarData(
                  spots: [spots.last, ...predictionSpots],
                  isCurved: true,
                  color: Colors.orange,
                  barWidth: 2,
                  dashArray: [5, 5],
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.withOpacity(0.2),
                        Colors.orange.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  dotData: const FlDotData(show: false),
                ),
            ],
            titlesData: _buildTitlesData(trends, maxY),
            borderData: FlBorderData(show: false),
            gridData: _buildGridData(),
            lineTouchData: _buildLineTouchData(trends),
          ),
        );
      case 3: // Scatter Chart
        return ScatterChart(
          ScatterChartData(
            maxY: maxY,
            minY: 0,
            scatterTouchData: ScatterTouchData(
              enabled: true,
              touchTooltipData: ScatterTouchTooltipData(
                getTooltipItems: (ScatterSpot spot) {
                  final index = spot.x.toInt();
                  if (index < trends.length) {
                    final date = trends[index].date;
                    return ScatterTooltipItem(
                      '${date.day}/${date.month}\n${_formatCurrency(spot.y)}',
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }
                  return ScatterTooltipItem(
                    'Predicted\n${_formatCurrency(spot.y)}',
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            scatterSpots: [
              ...spots.asMap().entries.map((e) {
                final colors = [
                  Colors.blue,
                  Colors.green,
                  Colors.purple,
                  Colors.teal,
                ];
                return ScatterSpot(
                  e.value.x,
                  e.value.y,
                  dotPainter: FlDotCirclePainter(
                    radius: 8 + (e.value.y / maxY) * 8,
                    color: colors[e.key % colors.length].withOpacity(0.7),
                    strokeWidth: 2,
                    strokeColor: colors[e.key % colors.length],
                  ),
                );
              }),
              ...predictionSpots.map(
                (spot) => ScatterSpot(
                  spot.x,
                  spot.y,
                  dotPainter: FlDotCirclePainter(
                    radius: 6,
                    color: Colors.orange.withOpacity(0.5),
                    strokeWidth: 2,
                    strokeColor: Colors.orange,
                  ),
                ),
              ),
            ],
            titlesData: _buildTitlesData(trends, maxY),
            borderData: FlBorderData(show: false),
            gridData: _buildGridData(),
          ),
        );
      case 4: // Step Chart
        return LineChart(
          LineChartData(
            maxY: maxY,
            minY: 0,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                isStepLineChart: true,
                lineChartStepData: const LineChartStepData(
                  stepDirection: LineChartStepData.stepDirectionMiddle,
                ),
                color: Theme.of(context).colorScheme.primary,
                barWidth: 3,
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      Theme.of(context).colorScheme.primary.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                        radius: 5,
                        color: Theme.of(context).colorScheme.primary,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                ),
              ),
              if (predictionSpots.isNotEmpty)
                LineChartBarData(
                  spots: [spots.last, ...predictionSpots],
                  isCurved: false,
                  isStepLineChart: true,
                  lineChartStepData: const LineChartStepData(
                    stepDirection: LineChartStepData.stepDirectionMiddle,
                  ),
                  color: Colors.orange,
                  barWidth: 2,
                  dashArray: [5, 5],
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                          radius: 4,
                          color: Colors.orange,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                  ),
                ),
            ],
            titlesData: _buildTitlesData(trends, maxY),
            borderData: FlBorderData(show: false),
            gridData: _buildGridData(),
            lineTouchData: _buildLineTouchData(trends),
          ),
        );
      default: // Line Chart
        return LineChart(
          LineChartData(
            maxY: maxY,
            minY: 0,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Theme.of(context).colorScheme.primary,
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                        radius: 4,
                        color: Theme.of(context).colorScheme.primary,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                ),
              ),
              if (predictionSpots.isNotEmpty)
                LineChartBarData(
                  spots: [spots.last, ...predictionSpots],
                  isCurved: true,
                  color: Colors.orange,
                  barWidth: 2,
                  dashArray: [5, 5],
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                          radius: 3,
                          color: Colors.orange,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                  ),
                ),
            ],
            titlesData: _buildTitlesData(trends, maxY),
            borderData: FlBorderData(show: false),
            gridData: _buildGridData(),
            lineTouchData: _buildLineTouchData(trends),
          ),
        );
    }
  }

  FlTitlesData _buildTitlesData(List<SalesTrend> trends, double maxY) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 50,
          getTitlesWidget: (value, meta) {
            return Text(
              _formatShortCurrency(value),
              style: const TextStyle(fontSize: 10),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            if (value.toInt() >= trends.length || value < 0) {
              return const SizedBox();
            }
            final date = trends[value.toInt()].date;
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${date.day}/${date.month}',
                style: const TextStyle(fontSize: 10),
              ),
            );
          },
          interval: trends.length > 10 ? (trends.length / 5).ceilToDouble() : 1,
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  FlGridData _buildGridData() {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: null,
      getDrawingHorizontalLine: (value) =>
          FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
    );
  }

  LineTouchData _buildLineTouchData(List<SalesTrend> trends) {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            final index = spot.x.toInt();
            String label;
            if (index < trends.length) {
              final date = trends[index].date;
              label = '${date.day}/${date.month}/${date.year}\n';
            } else {
              label = 'Predicted\n';
            }
            return LineTooltipItem(
              '$label${_formatCurrency(spot.y)}',
              TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            );
          }).toList();
        },
      ),
      handleBuiltInTouches: true,
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  // New Comparison Charts Row with Horizontal Bar Chart and Donut Chart
  Widget _buildComparisonChartsRow(
    BuildContext context,
    AnalyticsProvider provider,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;
    final storeSales = provider.storeSales;
    final paymentAnalytics = provider.paymentAnalytics;

    if (storeSales.isEmpty && paymentAnalytics.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: isMobile
          ? Column(
              children: [
                if (storeSales.isNotEmpty)
                  _buildHorizontalBarChart(context, storeSales),
                const SizedBox(height: 12),
                if (paymentAnalytics.isNotEmpty)
                  _buildDonutChartCard(context, paymentAnalytics),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (storeSales.isNotEmpty)
                  Expanded(
                    flex: 3,
                    child: _buildHorizontalBarChart(context, storeSales),
                  ),
                if (storeSales.isNotEmpty && paymentAnalytics.isNotEmpty)
                  const SizedBox(width: 12),
                if (paymentAnalytics.isNotEmpty)
                  Expanded(
                    flex: 2,
                    child: _buildDonutChartCard(context, paymentAnalytics),
                  ),
              ],
            ),
    );
  }

  // Horizontal Bar Chart - Top Stores Performance
  Widget _buildHorizontalBarChart(
    BuildContext context,
    List<StoreSales> stores,
  ) {
    final topStores = stores.take(6).toList();
    if (topStores.isEmpty) return const SizedBox.shrink();

    final maxSales = topStores.fold<double>(
      0,
      (max, s) => s.totalSales > max ? s.totalSales : max,
    );

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top Performing Stores',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${stores.length} stores',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...topStores.asMap().entries.map((entry) {
              final index = entry.key;
              final store = entry.value;
              final percentage = maxSales > 0
                  ? (store.totalSales / maxSales)
                  : 0.0;
              final barColor = _getStoreBarColor(index);

              return Tooltip(
                message:
                    '${store.storeName}\nSales: ${_formatCurrency(store.totalSales)}\nOrders: ${store.orderCount}\nContribution: ${(percentage * 100).toStringAsFixed(1)}%',
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: barColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: barColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    store.storeName,
                                    style: const TextStyle(fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatCurrency(store.totalSales),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: barColor,
                              fontSize: 13,
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
                              color: barColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: percentage,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [barColor, barColor.withOpacity(0.7)],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getStoreBarColor(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }

  // Donut Chart - Payment Methods Distribution
  Widget _buildDonutChartCard(
    BuildContext context,
    List<PaymentAnalytics> payments,
  ) {
    if (payments.isEmpty) return const SizedBox.shrink();

    final total = payments.fold<double>(0, (sum, p) => sum + p.totalAmount);
    final colors = [
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
    ];

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Methods',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        enabled: true,
                        touchCallback:
                            (FlTouchEvent event, pieTouchResponse) {},
                      ),
                      sectionsSpace: 3,
                      centerSpaceRadius: 50,
                      sections: payments.asMap().entries.map((entry) {
                        final index = entry.key;
                        final payment = entry.value;
                        final color = colors[index % colors.length];

                        return PieChartSectionData(
                          color: color,
                          value: payment.totalAmount,
                          title: payment.percentage > 15
                              ? '${payment.percentage.toStringAsFixed(0)}%'
                              : '',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          radius: 40,
                          badgeWidget: payment.percentage > 10
                              ? Tooltip(
                                  message:
                                      '${payment.paymentMethodName}\n${_formatCurrency(payment.totalAmount)}\n${payment.transactionCount} transactions',
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _getPaymentIcon(
                                        payment.paymentMethodName,
                                      ),
                                      size: 16,
                                      color: color,
                                    ),
                                  ),
                                )
                              : null,
                          badgePositionPercentageOffset: 1.3,
                        );
                      }).toList(),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatShortCurrency(total),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Legend with tooltips
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: payments.asMap().entries.map((entry) {
                final index = entry.key;
                final payment = entry.value;
                final color = colors[index % colors.length];

                return Tooltip(
                  message:
                      '${_formatCurrency(payment.totalAmount)}\n${payment.transactionCount} transactions',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${payment.paymentMethodName} (${payment.percentage.toStringAsFixed(0)}%)',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'card':
        return Icons.credit_card;
      case 'upi':
        return Icons.phone_android;
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'net banking':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  Future<void> _showDateRangePicker(
    BuildContext context,
    AnalyticsProvider provider,
  ) async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: provider.currentFilter.startDate,
        end: provider.currentFilter.endDate,
      ),
    );

    if (result != null) {
      provider.filterCustom(result.start, result.end);
    }
  }

  // Helper methods
  String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₹${amount.toStringAsFixed(2)}';
  }

  String _formatShortCurrency(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  Color _getProductColor(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
      Colors.deepOrange,
    ];
    return colors[index % colors.length];
  }

  Color _getCategoryColor(int index) {
    final colors = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.teal.shade400,
      Colors.pink.shade400,
      Colors.indigo.shade400,
      Colors.amber.shade400,
    ];
    return colors[index % colors.length];
  }

  // ignore: unused_element
  Color _getPaymentColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Colors.green;
      case 'card':
        return Colors.blue;
      case 'upi':
        return Colors.purple;
      case 'wallet':
        return Colors.orange;
      case 'net banking':
        return Colors.teal;
      case 'credit':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getLoyaltyColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum':
        return Colors.blueGrey.shade800;
      case 'gold':
        return Colors.amber.shade700;
      case 'silver':
        return Colors.grey.shade500;
      default:
        return Colors.brown.shade400;
    }
  }

  // Export handler
  void _handleExport(
    BuildContext context,
    AnalyticsProvider provider,
    String format,
  ) {
    final overview = provider.salesOverview;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              format == 'pdf'
                  ? Icons.picture_as_pdf
                  : format == 'excel'
                  ? Icons.table_chart
                  : Icons.description,
              color: format == 'pdf'
                  ? Colors.red
                  : format == 'excel'
                  ? Colors.green
                  : Colors.blue,
            ),
            const SizedBox(width: 8),
            Text('Export as ${format.toUpperCase()}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export analytics data for:'),
            const SizedBox(height: 8),
            Text(
              '• Date Range: ${provider.currentFilter.formattedRange}',
              style: const TextStyle(fontSize: 13),
            ),
            if (provider.hasStoreFilter)
              Text(
                '• Stores: ${provider.selectedStores.length} selected',
                style: const TextStyle(fontSize: 13),
              ),
            const SizedBox(height: 16),
            const Text(
              'Data to export:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '• Total Sales: ${_formatCurrency(overview.totalSales)}',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              '• Total Orders: ${overview.totalOrders}',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              '• Products: ${overview.totalProducts}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Exporting as ${format.toUpperCase()}...'),
                  backgroundColor: Colors.green,
                ),
              );
              // TODO: Implement actual export logic
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Export'),
          ),
        ],
      ),
    );
  }

  // Chatbot FAB
  Widget _buildChatbotFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showChatbotDialog(context),
      icon: const Icon(Icons.smart_toy),
      label: const Text('Ask AI'),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
    );
  }

  void _showChatbotDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _ChatbotSheet(provider: context.read<AnalyticsProvider>()),
    );
  }
}

// Chatbot Bottom Sheet
class _ChatbotSheet extends StatefulWidget {
  final AnalyticsProvider provider;

  const _ChatbotSheet({required this.provider});

  @override
  State<_ChatbotSheet> createState() => _ChatbotSheetState();
}

class _ChatbotSheetState extends State<_ChatbotSheet> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  // Predefined quick questions
  final List<Map<String, dynamic>> _quickQuestions = [
    {
      'question': 'What are total sales today?',
      'icon': Icons.attach_money,
      'color': Colors.green,
    },
    {
      'question': 'Which product is selling the most?',
      'icon': Icons.trending_up,
      'color': Colors.blue,
    },
    {
      'question': 'What is the average order value?',
      'icon': Icons.analytics,
      'color': Colors.orange,
    },
    {
      'question': 'Show top 5 customers',
      'icon': Icons.people,
      'color': Colors.purple,
    },
    {
      'question': 'Which store has highest sales?',
      'icon': Icons.store,
      'color': Colors.teal,
    },
    {
      'question': 'What are peak sales hours?',
      'icon': Icons.access_time,
      'color': Colors.red,
    },
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleQuestion(String question) {
    setState(() {
      _messages.add(_ChatMessage(text: question, isUser: true));
      _isLoading = true;
    });

    // Generate response based on question and actual data
    Future.delayed(const Duration(milliseconds: 500), () {
      final response = _generateResponse(question);
      setState(() {
        _messages.add(_ChatMessage(text: response, isUser: false));
        _isLoading = false;
      });
    });
  }

  String _generateResponse(String question) {
    final overview = widget.provider.salesOverview;
    final topProducts = widget.provider.topProducts;
    final topCustomers = widget.provider.topCustomers;
    final storeSales = widget.provider.storeSales;
    final hourlySales = widget.provider.hourlySales;
    final filter = widget.provider.currentFilter;

    final q = question.toLowerCase();

    // Total sales
    if (q.contains('total sales') ||
        q.contains('sales today') ||
        q.contains('revenue')) {
      return '''📊 **Sales Summary** (${filter.formattedRange})

💰 **Total Sales:** ₹${_formatNumber(overview.totalSales)}
📦 **Total Orders:** ${overview.totalOrders}
💵 **Net Revenue:** ₹${_formatNumber(overview.netRevenue)}
🧾 **Tax Collected:** ₹${_formatNumber(overview.taxCollected)}

Average Order Value: ₹${_formatNumber(overview.avgOrderValue)}''';
    }

    // Top products
    if (q.contains('product') &&
        (q.contains('selling') || q.contains('top') || q.contains('best'))) {
      if (topProducts.isEmpty) {
        return '❌ No product data available for the selected period.';
      }

      final top5 = topProducts.take(5);
      var response = '🏆 **Top Selling Products:**\n\n';
      int rank = 1;
      for (final p in top5) {
        response +=
            '$rank. **${p.productName}**\n   └ ₹${_formatNumber(p.totalRevenue)} (${p.quantitySold} units)\n';
        rank++;
      }
      return response;
    }

    // Average order value
    if (q.contains('average') && q.contains('order')) {
      return '''📈 **Order Analytics**

💵 **Average Order Value:** ₹${_formatNumber(overview.avgOrderValue)}
📦 **Total Orders:** ${overview.totalOrders}
👥 **Unique Customers:** ${overview.uniqueCustomers}

Orders per Customer: ${overview.uniqueCustomers > 0 ? (overview.totalOrders / overview.uniqueCustomers).toStringAsFixed(1) : 'N/A'}''';
    }

    // Top customers
    if (q.contains('customer') && (q.contains('top') || q.contains('best'))) {
      if (topCustomers.isEmpty) {
        return '❌ No customer data available for the selected period.';
      }

      final top5 = topCustomers.take(5);
      var response = '👥 **Top Customers:**\n\n';
      int rank = 1;
      for (final c in top5) {
        response +=
            '$rank. **${c.customerName}**\n   └ ₹${_formatNumber(c.totalSpent)} (${c.orderCount} orders)\n';
        rank++;
      }
      return response;
    }

    // Store sales
    if (q.contains('store') &&
        (q.contains('highest') || q.contains('top') || q.contains('best'))) {
      if (storeSales.isEmpty) {
        return '❌ No store data available for the selected period.';
      }

      var response = '🏪 **Top Performing Stores:**\n\n';
      int rank = 1;
      for (final s in storeSales.take(5)) {
        response +=
            '$rank. **${s.storeName}** (${s.city})\n   └ ₹${_formatNumber(s.totalSales)} (${s.orderCount} orders)\n';
        rank++;
      }
      return response;
    }

    // Peak hours
    if (q.contains('peak') || q.contains('hour') || q.contains('time')) {
      if (hourlySales.isEmpty) return '❌ No hourly data available.';

      final sortedHours = List<HourlySales>.from(hourlySales)
        ..sort((a, b) => b.sales.compareTo(a.sales));
      final peakHours = sortedHours.take(3).toList();

      var response = '⏰ **Peak Sales Hours:**\n\n';
      for (final h in peakHours) {
        final hourStr = '${h.hour.toString().padLeft(2, '0')}:00';
        response +=
            '🕐 **$hourStr** - ₹${_formatNumber(h.sales)} (${h.orders} orders)\n';
      }

      // Find slowest hours
      final slowHours = sortedHours.reversed.take(2).toList();
      response += '\n📉 **Slowest Hours:**\n';
      for (final h in slowHours) {
        final hourStr = '${h.hour.toString().padLeft(2, '0')}:00';
        response += '🕐 $hourStr - ₹${_formatNumber(h.sales)}\n';
      }

      return response;
    }

    // Default response
    return '''🤖 I can help you with:

• Total sales and revenue
• Top selling products
• Average order value
• Top customers
• Best performing stores
• Peak sales hours

Try asking one of the quick questions above or type your own!''';
  }

  String _formatNumber(double value) {
    if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(2)}Cr';
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(2)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)}K';
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.smart_toy,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Analytics Assistant',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Ask questions about your data',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Quick questions (adaptive cards)
          if (_messages.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Quick Questions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickQuestions.map((q) {
                      return ActionChip(
                        avatar: Icon(q['icon'], size: 18, color: q['color']),
                        label: Text(
                          q['question'],
                          style: TextStyle(fontSize: isMobile ? 12 : 13),
                        ),
                        onPressed: () => _handleQuestion(q['question']),
                        backgroundColor: (q['color'] as Color).withOpacity(0.1),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // Messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Start a conversation',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isLoading) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),

          // Input
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ask about your data...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (text) {
                        if (text.trim().isNotEmpty) {
                          _handleQuestion(text.trim());
                          _controller.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () {
                      final text = _controller.text.trim();
                      if (text.isNotEmpty) {
                        _handleQuestion(text);
                        _controller.clear();
                      }
                    },
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Analyzing...'),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});
}

// KPI Item model for sorting and display
class _KPIItem {
  final String title;
  final double rawValue;
  final String displayValue;
  final IconData icon;
  final Color color;
  final double? change;

  _KPIItem(
    this.title,
    this.rawValue,
    this.displayValue,
    this.icon,
    this.color,
    this.change,
  );
}

// Store Selection Dialog
class _StoreSelectionDialog extends StatefulWidget {
  final AnalyticsProvider provider;

  const _StoreSelectionDialog({required this.provider});

  @override
  State<_StoreSelectionDialog> createState() => _StoreSelectionDialogState();
}

class _StoreSelectionDialogState extends State<_StoreSelectionDialog> {
  late List<Store> _selectedStores;
  String _searchQuery = '';
  String _selectedType = 'all';

  @override
  void initState() {
    super.initState();
    _selectedStores = List.from(widget.provider.selectedStores);
  }

  List<Store> get _filteredStores {
    return widget.provider.allStores.where((store) {
      final matchesSearch =
          store.storeName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          store.city.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType =
          _selectedType == 'all' || store.storeType.toString() == _selectedType;
      return matchesSearch && matchesType;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.store,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select Stores',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  Text(
                    '${_selectedStores.length} selected',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Search & Filter
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search stores...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration: InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All Types'),
                        ),
                        DropdownMenuItem(value: '1', child: Text('Walk-in')),
                        DropdownMenuItem(value: '2', child: Text('Advance')),
                        DropdownMenuItem(
                          value: '3',
                          child: Text('Centralized Kitchen'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedType = v ?? 'all'),
                    ),
                  ),
                ],
              ),
            ),

            // Quick Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(
                      () => _selectedStores = List.from(_filteredStores),
                    ),
                    icon: const Icon(Icons.select_all, size: 18),
                    label: const Text('Select All'),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedStores.clear()),
                    icon: const Icon(Icons.deselect, size: 18),
                    label: const Text('Clear All'),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Store List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _filteredStores.length,
                itemBuilder: (context, index) {
                  final store = _filteredStores[index];
                  final isSelected = _selectedStores.contains(store);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedStores.add(store);
                        } else {
                          _selectedStores.remove(store);
                        }
                      });
                    },
                    title: Text(
                      store.storeName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(store.city),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getStoreTypeColor(
                              store.storeType,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            store.storeTypeName,
                            style: TextStyle(
                              fontSize: 11,
                              color: _getStoreTypeColor(store.storeType),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Actions
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      // Update provider with selected stores
                      widget.provider.clearStoreSelection();
                      for (final store in _selectedStores) {
                        widget.provider.toggleStoreSelection(store);
                      }
                      widget.provider.loadDashboard();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: Text('Apply (${_selectedStores.length})'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStoreTypeColor(int type) {
    switch (type) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
