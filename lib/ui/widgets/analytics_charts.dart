import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../../data/models/analytics_model.dart';

/// Interactive Hourly Sales Heat Map Chart
class HourlySalesChart extends StatefulWidget {
  final List<HourlySales> hourlyData;

  const HourlySalesChart({super.key, required this.hourlyData});

  @override
  State<HourlySalesChart> createState() => _HourlySalesChartState();
}

class _HourlySalesChartState extends State<HourlySalesChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final maxSales = widget.hourlyData.isNotEmpty
        ? widget.hourlyData.map((h) => h.sales).reduce(math.max)
        : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sales by Hour',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: widget.hourlyData.isEmpty
              ? const Center(child: Text('No hourly data'))
              : BarChart(
                  BarChartData(
                    maxY: maxSales * 1.2,
                    barGroups: widget.hourlyData.asMap().entries.map((e) {
                      final isTouched = e.key == _touchedIndex;
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.sales,
                            width: isTouched ? 14 : 10,
                            gradient: LinearGradient(
                              colors: [
                                _getHeatColor(e.value.sales, maxSales),
                                _getHeatColor(
                                  e.value.sales,
                                  maxSales,
                                ).withOpacity(0.6),
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                        showingTooltipIndicators: isTouched ? [0] : [],
                      );
                    }).toList(),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final hour = value.toInt();
                            if (hour % 3 != 0) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _formatHour(hour),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final hourData = widget.hourlyData[group.x.toInt()];
                          return BarTooltipItem(
                            '${hourData.hourLabel}\n₹${hourData.sales.toStringAsFixed(0)}\n${hourData.orders} orders',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        },
                      ),
                      touchCallback: (FlTouchEvent event, barTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              barTouchResponse == null ||
                              barTouchResponse.spot == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex =
                              barTouchResponse.spot!.touchedBarGroupIndex;
                        });
                      },
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildHeatLegendItem('Low', Colors.blue.shade200),
            const SizedBox(width: 12),
            _buildHeatLegendItem('Medium', Colors.orange.shade400),
            const SizedBox(width: 12),
            _buildHeatLegendItem('High', Colors.red.shade600),
          ],
        ),
      ],
    );
  }

  Color _getHeatColor(double value, double max) {
    final ratio = value / math.max(max, 1);
    if (ratio < 0.33) return Colors.blue.shade400;
    if (ratio < 0.66) return Colors.orange.shade500;
    return Colors.red.shade500;
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12AM';
    if (hour == 12) return '12PM';
    if (hour > 12) return '${hour - 12}PM';
    return '${hour}AM';
  }

  Widget _buildHeatLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

/// Fill Rate Gauge Chart
class FillRateGauge extends StatelessWidget {
  final double fillRate;
  final String label;
  final double size;

  const FillRateGauge({
    super.key,
    required this.fillRate,
    this.label = 'Fill Rate',
    this.size = 150,
  });

  @override
  Widget build(BuildContext context) {
    final color = fillRate >= 95
        ? Colors.green
        : (fillRate >= 80 ? Colors.orange : Colors.red);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: fillRate / 100,
              strokeWidth: 12,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${fillRate.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: size / 5,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: size / 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fill Rate Details Card
class FillRateCard extends StatelessWidget {
  final OverallFillRate? fillRate;

  const FillRateCard({super.key, this.fillRate});

  @override
  Widget build(BuildContext context) {
    if (fillRate == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No fill rate data available')),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Fill Rate Analysis',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FillRateGauge(
                    fillRate: fillRate!.overallPercentage,
                    label: 'Overall',
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatRow(
                        'Total Ordered',
                        fillRate!.totalOrdered.toString(),
                        Icons.shopping_cart,
                      ),
                      const SizedBox(height: 8),
                      _buildStatRow(
                        'Fulfilled',
                        fillRate!.totalFulfilled.toString(),
                        Icons.check_circle,
                      ),
                      const SizedBox(height: 8),
                      _buildStatRow(
                        'Stockouts',
                        fillRate!.totalStockouts.toString(),
                        Icons.warning,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (fillRate!.productFillRates.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Product Fill Rates',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...fillRate!.productFillRates
                  .take(5)
                  .map((pf) => _buildProductFillRate(context, pf)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildProductFillRate(BuildContext context, FillRate pf) {
    final color = pf.status == 'healthy'
        ? Colors.green
        : (pf.status == 'warning' ? Colors.orange : Colors.red);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              pf.productName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: LinearProgressIndicator(
              value: pf.fillRatePercentage / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 45,
            child: Text(
              '${pf.fillRatePercentage.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sales Prediction Card
class SalesPredictionCard extends StatelessWidget {
  final List<SalesPrediction> predictions;

  const SalesPredictionCard({super.key, required this.predictions});

  @override
  Widget build(BuildContext context) {
    if (predictions.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('Not enough data for predictions')),
        ),
      );
    }

    final totalPredicted = predictions.fold<double>(
      0,
      (sum, p) => sum + p.predictedSales,
    );
    final avgConfidence =
        predictions.fold<double>(0, (sum, p) => sum + p.confidenceLevel) /
        predictions.length;
    final trend = predictions.first.trend;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_graph, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Sales Forecast',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getTrendColor(trend).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getTrendIcon(trend),
                        size: 14,
                        color: _getTrendColor(trend),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trend.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _getTrendColor(trend),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  context,
                  'Next 7 Days',
                  _formatCurrency(totalPredicted),
                  Icons.calendar_month,
                ),
                _buildStatColumn(
                  context,
                  'Confidence',
                  '${(avgConfidence * 100).toStringAsFixed(0)}%',
                  Icons.verified,
                ),
                _buildStatColumn(
                  context,
                  'Avg Daily',
                  _formatCurrency(totalPredicted / 7),
                  Icons.today,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: predictions
                          .asMap()
                          .entries
                          .map(
                            (e) => FlSpot(
                              e.key.toDouble(),
                              e.value.predictedSales,
                            ),
                          )
                          .toList(),
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.3),
                            Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                              radius: 3,
                              color: Theme.of(context).colorScheme.primary,
                              strokeWidth: 1,
                              strokeColor: Colors.white,
                            ),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= predictions.length)
                            return const SizedBox();
                          final date = predictions[value.toInt()].predictedDate;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${date.day}/${date.month}',
                              style: const TextStyle(fontSize: 9),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Color _getTrendColor(String trend) {
    switch (trend) {
      case 'up':
        return Colors.green;
      case 'down':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _getTrendIcon(String trend) {
    switch (trend) {
      case 'up':
        return Icons.trending_up;
      case 'down':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }
}

/// Animated KPI Counter Widget
class AnimatedKPICard extends StatefulWidget {
  final String title;
  final double value;
  final String suffix;
  final IconData icon;
  final Color color;
  final String? changeText;
  final bool isPositiveChange;

  const AnimatedKPICard({
    super.key,
    required this.title,
    required this.value,
    this.suffix = '',
    required this.icon,
    required this.color,
    this.changeText,
    this.isPositiveChange = true,
  });

  @override
  State<AnimatedKPICard> createState() => _AnimatedKPICardState();
}

class _AnimatedKPICardState extends State<AnimatedKPICard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.value,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedKPICard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(begin: _animation.value, end: widget.value)
          .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: widget.color.withOpacity(0.3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              widget.color.withOpacity(0.15),
              widget.color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 24),
                  ),
                  if (widget.changeText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isPositiveChange
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.isPositiveChange
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 14,
                            color: widget.isPositiveChange
                                ? Colors.green
                                : Colors.red,
                          ),
                          Text(
                            widget.changeText!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: widget.isPositiveChange
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Text(
                    _formatValue(_animation.value),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: widget.color,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                widget.title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatValue(double value) {
    if (widget.suffix == '%') {
      return '${value.toStringAsFixed(1)}%';
    }
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(2)}Cr${widget.suffix}';
    } else if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)}L${widget.suffix}';
    } else if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)}K${widget.suffix}';
    }
    return '₹${value.toStringAsFixed(0)}${widget.suffix}';
  }
}

/// Store Performance Comparison Chart
class StoreComparisonChart extends StatelessWidget {
  final List<StoreSales> stores;

  const StoreComparisonChart({super.key, required this.stores});

  @override
  Widget build(BuildContext context) {
    if (stores.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No store data available')),
        ),
      );
    }

    final maxSales = stores.map((s) => s.totalSales).reduce(math.max);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Store Performance',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...stores
                .take(5)
                .map((store) => _buildStoreRow(context, store, maxSales)),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreRow(
    BuildContext context,
    StoreSales store,
    double maxSales,
  ) {
    final ratio = store.totalSales / maxSales;
    final color = _getPerformanceColor(ratio);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  store.storeName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                _formatCurrency(store.totalSales),
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: ratio,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 2),
          Text(
            '${store.orderCount} orders • Avg ₹${store.avgOrderValue.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPerformanceColor(double ratio) {
    if (ratio >= 0.7) return Colors.green;
    if (ratio >= 0.4) return Colors.orange;
    return Colors.red;
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }
}
