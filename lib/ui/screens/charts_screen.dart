import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/chart_data_provider.dart';
import '../widgets/charts/power_charts.dart';

/// Charts Screen - Full screen chart visualization
class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadChartData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChartData() async {
    await context.read<ChartDataProvider>().fetchAllChartData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Power Charts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _showDateRangePicker,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChartData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Power'),
            Tab(text: 'Voltage'),
            Tab(text: 'Efficiency'),
            Tab(text: 'Current'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildDateRangeHeader(),
          _buildIntervalSelector(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPowerTab(),
                _buildVoltageTab(),
                _buildEfficiencyTab(),
                _buildCurrentTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeHeader() {
    return Consumer<ChartDataProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.primary.withValues(alpha: 0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.date_range, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                '${_formatDate(provider.chartStartDate)} - ${_formatDate(provider.chartEndDate)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIntervalSelector() {
    return Consumer<ChartDataProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Interval: '),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'minute', label: Text('Min')),
                  ButtonSegment(value: 'hour', label: Text('Hour')),
                  ButtonSegment(value: 'day', label: Text('Day')),
                  ButtonSegment(value: 'week', label: Text('Week')),
                ],
                selected: {provider.selectedInterval},
                onSelectionChanged: (values) {
                  provider.setInterval(values.first);
                  _loadChartData();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPowerTab() {
    return Consumer<ChartDataProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: PowerLineChart(
                  dataPoints: provider.powerChartData,
                  title: 'Power Generation Over Time',
                  yAxisLabel: 'MW',
                  lineColor: AppColors.primary,
                  isLoading: provider.isLoadingPowerChart,
                ),
              ),
              const SizedBox(height: 16),
              _buildChartLegend([('Power Generated', AppColors.primary)]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVoltageTab() {
    return Consumer<ChartDataProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: PowerLineChart(
                  dataPoints: provider.voltageChartData,
                  title: 'Voltage Over Time',
                  yAxisLabel: 'V',
                  lineColor: AppColors.secondary,
                  isLoading: provider.isLoadingVoltageChart,
                ),
              ),
              const SizedBox(height: 16),
              _buildChartLegend([('Voltage', AppColors.secondary)]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEfficiencyTab() {
    return Consumer<ChartDataProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: PowerLineChart(
                  dataPoints: provider.efficiencyChartData,
                  title: 'Efficiency Over Time',
                  yAxisLabel: '%',
                  lineColor: AppColors.success,
                  isLoading: provider.isLoadingEfficiencyChart,
                ),
              ),
              const SizedBox(height: 16),
              _buildChartLegend([('Efficiency', AppColors.success)]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentTab() {
    return Consumer<ChartDataProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: PowerLineChart(
                  dataPoints: provider.currentChartData,
                  title: 'Current Over Time',
                  yAxisLabel: 'A',
                  lineColor: AppColors.warning,
                  isLoading: provider.isLoadingCurrentChart,
                ),
              ),
              const SizedBox(height: 16),
              _buildChartLegend([('Current', AppColors.warning)]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartLegend(List<(String, Color)> items) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: item.$2,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(item.$1, style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showDateRangePicker() async {
    final provider = context.read<ChartDataProvider>();

    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: provider.chartStartDate,
        end: provider.chartEndDate,
      ),
    );

    if (dateRange != null) {
      provider.setDateRange(dateRange.start, dateRange.end);
      await _loadChartData();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
