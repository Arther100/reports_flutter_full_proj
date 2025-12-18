import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/power_data_provider.dart';
import '../../providers/chart_data_provider.dart';
import '../widgets/common/common_widgets.dart';
import '../widgets/charts/power_charts.dart';

/// Dashboard Screen - Main screen showing power operations overview
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final powerProvider = context.read<PowerDataProvider>();
    final chartProvider = context.read<ChartDataProvider>();

    // Load data in parallel for fast loading
    await Future.wait([
      powerProvider.fetchLatestPowerData(),
      powerProvider.fetchStatistics(),
      powerProvider.fetchStations(),
      chartProvider.fetchPowerChartData(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Power Operations Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatisticsSection(),
              const SizedBox(height: 24),
              _buildChartSection(),
              const SizedBox(height: 24),
              _buildLatestDataSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Consumer<PowerDataProvider>(
      builder: (context, provider, child) {
        final stats = provider.statistics;

        if (provider.isLoading && stats == null) {
          return const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                final cardWidth = isWide
                    ? (constraints.maxWidth - 48) / 4
                    : (constraints.maxWidth - 16) / 2;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      height: 140,
                      child: StatsCard(
                        title: 'Total Generated',
                        value:
                            '${stats?.totalGenerated.toStringAsFixed(1) ?? '0'} MW',
                        icon: Icons.bolt,
                        color: AppColors.success,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      height: 140,
                      child: StatsCard(
                        title: 'Total Consumed',
                        value:
                            '${stats?.totalConsumed.toStringAsFixed(1) ?? '0'} MW',
                        icon: Icons.power,
                        color: AppColors.error,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      height: 140,
                      child: StatsCard(
                        title: 'Avg Efficiency',
                        value:
                            '${stats?.averageEfficiency.toStringAsFixed(1) ?? '0'}%',
                        icon: Icons.speed,
                        color: AppColors.info,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      height: 140,
                      child: StatsCard(
                        title: 'Net Power',
                        value:
                            '${stats?.netPower.toStringAsFixed(1) ?? '0'} MW',
                        icon: Icons.trending_up,
                        color: (stats?.netPower ?? 0) >= 0
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildChartSection() {
    return Consumer<ChartDataProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Power Trends',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: provider.selectedInterval,
                  elevation: 24,
                  items: const [
                    DropdownMenuItem(value: 'minute', child: Text('Minute')),
                    DropdownMenuItem(value: 'hour', child: Text('Hourly')),
                    DropdownMenuItem(value: 'day', child: Text('Daily')),
                    DropdownMenuItem(value: 'week', child: Text('Weekly')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      provider.setInterval(value);
                      provider.fetchPowerChartData();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: PowerLineChart(
                dataPoints: provider.powerChartData,
                title: 'Power Generation',
                yAxisLabel: 'MW',
                lineColor: AppColors.primary,
                isLoading: provider.isLoadingPowerChart,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLatestDataSection() {
    return Consumer<PowerDataProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Latest Readings',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to full list
                    Navigator.pushNamed(context, '/power-data');
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (provider.latestPowerData.isEmpty)
              const EmptyStateWidget(
                message: 'No recent data available',
                icon: Icons.data_usage,
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.latestPowerData.length,
                itemBuilder: (context, index) {
                  final data = provider.latestPowerData[index];
                  return PowerDataListItem(
                    stationName: data.stationName,
                    powerGenerated: data.powerGenerated,
                    powerConsumed: data.powerConsumed,
                    status: data.status,
                    timestamp: data.timestamp,
                    onTap: () {
                      // Show detail
                    },
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
