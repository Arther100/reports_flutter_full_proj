import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/power_data_provider.dart';
import '../widgets/common/common_widgets.dart';

/// Power Data List Screen with infinite scroll
class PowerDataListScreen extends StatefulWidget {
  const PowerDataListScreen({super.key});

  @override
  State<PowerDataListScreen> createState() => _PowerDataListScreenState();
}

class _PowerDataListScreenState extends State<PowerDataListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await context.read<PowerDataProvider>().fetchPowerData(refresh: true);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<PowerDataProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Power Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          ),
        ],
      ),
      body: Consumer<PowerDataProvider>(
        builder: (context, provider, child) {
          if (provider.loadingState == LoadingState.error) {
            return ErrorStateWidget(
              message: provider.errorMessage ?? 'An error occurred',
              onRetry: _loadInitialData,
            );
          }

          if (provider.powerDataList.isEmpty && provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.powerDataList.isEmpty) {
            return EmptyStateWidget(
              message: 'No power data available',
              icon: Icons.data_usage,
              onRetry: _loadInitialData,
            );
          }

          return RefreshIndicator(
            onRefresh: _loadInitialData,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount:
                  provider.powerDataList.length +
                  (provider.hasMoreData ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= provider.powerDataList.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final data = provider.powerDataList[index];
                return PowerDataListItem(
                  stationName: data.stationName,
                  powerGenerated: data.powerGenerated,
                  powerConsumed: data.powerConsumed,
                  status: data.status,
                  timestamp: data.timestamp,
                  onTap: () => _showDetailDialog(data),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showFilterDialog() {
    final provider = context.read<PowerDataProvider>();
    String? selectedStation = provider.selectedStation;
    DateTime? startDate = provider.startDate;
    DateTime? endDate = provider.endDate;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Data'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer<PowerDataProvider>(
                builder: (context, provider, _) {
                  return DropdownButtonFormField<String>(
                    value: selectedStation,
                    decoration: const InputDecoration(labelText: 'Station'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Stations'),
                      ),
                      ...provider.stations.map(
                        (station) => DropdownMenuItem(
                          value: station.name,
                          child: Text(station.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      selectedStation = value;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Start Date'),
                subtitle: Text(
                  startDate?.toString().split(' ')[0] ?? 'Not set',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate:
                        startDate ??
                        DateTime.now().subtract(const Duration(days: 7)),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    startDate = date;
                  }
                },
              ),
              ListTile(
                title: const Text('End Date'),
                subtitle: Text(endDate?.toString().split(' ')[0] ?? 'Not set'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: endDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    endDate = date;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              provider.clearFilters();
              Navigator.pop(context);
              _loadInitialData();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.setFilters(
                stationName: selectedStation,
                startDate: startDate,
                endDate: endDate,
              );
              Navigator.pop(context);
              _loadInitialData();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(dynamic data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data.stationName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                'Power Generated',
                '${data.powerGenerated.toStringAsFixed(2)} MW',
              ),
              _buildDetailRow(
                'Power Consumed',
                '${data.powerConsumed.toStringAsFixed(2)} MW',
              ),
              _buildDetailRow(
                'Net Power',
                '${data.netPower.toStringAsFixed(2)} MW',
              ),
              _buildDetailRow(
                'Voltage',
                '${data.voltage.toStringAsFixed(2)} V',
              ),
              _buildDetailRow(
                'Current',
                '${data.current.toStringAsFixed(2)} A',
              ),
              _buildDetailRow(
                'Frequency',
                '${data.frequency.toStringAsFixed(2)} Hz',
              ),
              _buildDetailRow(
                'Power Factor',
                '${data.powerFactor.toStringAsFixed(3)}',
              ),
              _buildDetailRow(
                'Efficiency',
                '${data.efficiency.toStringAsFixed(2)}%',
              ),
              _buildDetailRow('Status', data.status),
              _buildDetailRow('Timestamp', data.timestamp.toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
