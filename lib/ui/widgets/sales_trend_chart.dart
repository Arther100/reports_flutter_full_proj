import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';

/// Data model for sales trend chart
class SalesTrendData {
  final DateTime date;
  final double sales;
  final int orders;
  final String? label;

  const SalesTrendData({
    required this.date,
    required this.sales,
    this.orders = 0,
    this.label,
  });
}

/// Multi-Type Sales Trend Chart - Light Mode & Responsive
/// Supports: Line, Bar, Area, Scatter (Bubble), Step charts
class SalesTrendChart extends StatefulWidget {
  final List<SalesTrendData> data;
  final List<SalesTrendData>? predictions;
  final String? title;
  final bool showChartSelector;
  final int initialChartType;

  const SalesTrendChart({
    super.key,
    required this.data,
    this.predictions,
    this.title,
    this.showChartSelector = true,
    this.initialChartType = 0,
  });

  @override
  State<SalesTrendChart> createState() => _SalesTrendChartState();
}

class _SalesTrendChartState extends State<SalesTrendChart> {
  late int _selectedChartType;
  final NumberFormat _currencyFormat = NumberFormat.compact();

  @override
  void initState() {
    super.initState();
    _selectedChartType = widget.initialChartType;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 900;

        // Responsive sizing - REDUCED heights to fix overflow
        final chartHeight = isMobile ? 160.0 : (isTablet ? 170.0 : 180.0);
        final padding = isMobile ? 10.0 : 12.0;
        final titleSize = isMobile ? 13.0 : 15.0;

        return Card(
          elevation: 2,
          color: Colors.white,
          shadowColor: Colors.black.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobile ? 10 : 14),
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and chart selector
                _buildHeader(isMobile, titleSize),
                SizedBox(height: isMobile ? 8 : 12),
                // Chart - responsive height
                SizedBox(height: chartHeight, child: _buildChart(isMobile)),
                // Legend
                if (widget.predictions != null &&
                    widget.predictions!.isNotEmpty) ...[
                  SizedBox(height: isMobile ? 6 : 10),
                  _buildLegend(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile, double titleSize) {
    if (isMobile) {
      // Stack layout for mobile
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.indigo.shade400],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.title!,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF374151),
                  ),
                ),
              ],
            ),
          if (widget.showChartSelector) ...[
            const SizedBox(height: 8),
            _buildChartSelector(isMobile),
          ],
        ],
      );
    }

    // Row layout for tablet/desktop
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (widget.title != null)
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.indigo.shade400],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    widget.title!,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (widget.showChartSelector) _buildChartSelector(isMobile),
      ],
    );
  }

  Widget _buildChartSelector(bool isMobile) {
    final buttonStyle = ButtonStyle(
      visualDensity: VisualDensity.compact,
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<int>(
        style: buttonStyle,
        segments: [
          ButtonSegment(
            value: 0,
            icon: Icon(Icons.show_chart, size: isMobile ? 12 : 14),
            tooltip: 'Line',
          ),
          ButtonSegment(
            value: 1,
            icon: Icon(Icons.bar_chart, size: isMobile ? 12 : 14),
            tooltip: 'Bar',
          ),
          ButtonSegment(
            value: 2,
            icon: Icon(Icons.area_chart, size: isMobile ? 12 : 14),
            tooltip: 'Area',
          ),
          ButtonSegment(
            value: 3,
            icon: Icon(Icons.bubble_chart, size: isMobile ? 12 : 14),
            tooltip: 'Scatter',
          ),
          ButtonSegment(
            value: 4,
            icon: Icon(Icons.candlestick_chart, size: isMobile ? 12 : 14),
            tooltip: 'Step',
          ),
        ],
        selected: {_selectedChartType},
        onSelectionChanged: (Set<int> newSelection) {
          setState(() {
            _selectedChartType = newSelection.first;
          });
        },
      ),
    );
  }

  Widget _buildChart(bool isMobile) {
    final spots = widget.data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.sales))
        .toList();

    final predictionSpots =
        widget.predictions
            ?.asMap()
            .entries
            .map(
              (e) => FlSpot(
                (widget.data.length + e.key).toDouble(),
                e.value.sales,
              ),
            )
            .toList() ??
        [];

    final maxY =
        [
          ...spots.map((s) => s.y),
          ...predictionSpots.map((s) => s.y),
        ].fold<double>(0, (max, val) => math.max(max, val)) *
        1.2;

    switch (_selectedChartType) {
      case 1:
        return _buildBarChart(spots, maxY, isMobile);
      case 2:
        return _buildAreaChart(spots, predictionSpots, maxY, isMobile);
      case 3:
        return _buildScatterChart(spots, predictionSpots, maxY, isMobile);
      case 4:
        return _buildStepChart(spots, predictionSpots, maxY, isMobile);
      default:
        return _buildLineChart(spots, predictionSpots, maxY, isMobile);
    }
  }

  // Line Chart
  Widget _buildLineChart(
    List<FlSpot> spots,
    List<FlSpot> predictionSpots,
    double maxY,
    bool isMobile,
  ) {
    return LineChart(
      LineChartData(
        maxY: maxY,
        minY: 0,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue.shade600,
            barWidth: isMobile ? 2 : 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: isMobile ? 2 : 3,
                    color: Colors.blue.shade600,
                    strokeWidth: 1.5,
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
                      radius: 2,
                      color: Colors.orange,
                      strokeWidth: 1.5,
                      strokeColor: Colors.white,
                    ),
              ),
            ),
        ],
        titlesData: _buildTitlesData(maxY, isMobile),
        borderData: FlBorderData(show: false),
        gridData: _buildGridData(),
        lineTouchData: _buildLineTouchData(),
      ),
    );
  }

  // Bar Chart
  Widget _buildBarChart(List<FlSpot> spots, double maxY, bool isMobile) {
    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Colors.grey.shade800,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (group.x >= widget.data.length) return null;
              final dataPoint = widget.data[group.x];
              final label =
                  dataPoint.label ??
                  '${dataPoint.date.day}/${dataPoint.date.month}';
              return BarTooltipItem(
                '$label\n${_formatCurrency(rod.toY)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
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
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: isMobile ? 10 : 14,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
        titlesData: _buildTitlesData(maxY, isMobile),
        borderData: FlBorderData(show: false),
        gridData: _buildGridData(),
      ),
    );
  }

  // Area Chart
  Widget _buildAreaChart(
    List<FlSpot> spots,
    List<FlSpot> predictionSpots,
    double maxY,
    bool isMobile,
  ) {
    return LineChart(
      LineChartData(
        maxY: maxY,
        minY: 0,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue.shade600,
            barWidth: isMobile ? 2 : 2.5,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade400.withOpacity(0.4),
                  Colors.blue.shade100.withOpacity(0.1),
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
                    Colors.orange.withOpacity(0.3),
                    Colors.orange.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              dotData: const FlDotData(show: false),
            ),
        ],
        titlesData: _buildTitlesData(maxY, isMobile),
        borderData: FlBorderData(show: false),
        gridData: _buildGridData(),
        lineTouchData: _buildLineTouchData(),
      ),
    );
  }

  // Scatter Chart
  Widget _buildScatterChart(
    List<FlSpot> spots,
    List<FlSpot> predictionSpots,
    double maxY,
    bool isMobile,
  ) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.cyan,
    ];

    return ScatterChart(
      ScatterChartData(
        maxY: maxY,
        minY: 0,
        scatterTouchData: ScatterTouchData(
          enabled: true,
          touchTooltipData: ScatterTouchTooltipData(
            getTooltipColor: (spot) => Colors.grey.shade800,
            getTooltipItems: (ScatterSpot spot) {
              final index = spot.x.toInt();
              if (index < widget.data.length) {
                final dataPoint = widget.data[index];
                final label =
                    dataPoint.label ??
                    '${dataPoint.date.day}/${dataPoint.date.month}';
                return ScatterTooltipItem(
                  '$label\n${_formatCurrency(spot.y)}',
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                );
              }
              return ScatterTooltipItem(
                'Predicted\n${_formatCurrency(spot.y)}',
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
        scatterSpots: [
          ...spots.asMap().entries.map((e) {
            final baseRadius = isMobile ? 5.0 : 6.0;
            return ScatterSpot(
              e.value.x,
              e.value.y,
              dotPainter: FlDotCirclePainter(
                radius: baseRadius + (e.value.y / maxY) * baseRadius,
                color: colors[e.key % colors.length].withOpacity(0.7),
                strokeWidth: 1.5,
                strokeColor: colors[e.key % colors.length],
              ),
            );
          }),
          ...predictionSpots.map(
            (spot) => ScatterSpot(
              spot.x,
              spot.y,
              dotPainter: FlDotCirclePainter(
                radius: 4,
                color: Colors.orange.withOpacity(0.5),
                strokeWidth: 1.5,
                strokeColor: Colors.orange,
              ),
            ),
          ),
        ],
        titlesData: _buildTitlesData(maxY, isMobile),
        borderData: FlBorderData(show: false),
        gridData: _buildGridData(),
      ),
    );
  }

  // Step Chart
  Widget _buildStepChart(
    List<FlSpot> spots,
    List<FlSpot> predictionSpots,
    double maxY,
    bool isMobile,
  ) {
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
            color: Colors.blue.shade600,
            barWidth: isMobile ? 2 : 2.5,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade300.withOpacity(0.3),
                  Colors.blue.shade100.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: isMobile ? 3 : 4,
                    color: Colors.blue.shade600,
                    strokeWidth: 1.5,
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
                      radius: 3,
                      color: Colors.orange,
                      strokeWidth: 1.5,
                      strokeColor: Colors.white,
                    ),
              ),
            ),
        ],
        titlesData: _buildTitlesData(maxY, isMobile),
        borderData: FlBorderData(show: false),
        gridData: _buildGridData(),
        lineTouchData: _buildLineTouchData(),
      ),
    );
  }

  FlTitlesData _buildTitlesData(double maxY, bool isMobile) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: isMobile ? 35 : 45,
          getTitlesWidget: (value, meta) {
            return Text(
              _formatShortCurrency(value),
              style: TextStyle(
                fontSize: isMobile ? 8 : 9,
                color: const Color(0xFF6B7280),
              ),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: isMobile ? 22 : 26,
          getTitlesWidget: (value, meta) {
            if (value.toInt() >= widget.data.length || value < 0) {
              return const SizedBox();
            }
            final dataPoint = widget.data[value.toInt()];
            final label = dataPoint.label != null && dataPoint.label!.isNotEmpty
                ? _truncateLabel(dataPoint.label!, isMobile ? 5 : 7)
                : '${dataPoint.date.day}/${dataPoint.date.month}';

            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isMobile ? 7 : 8,
                  color: const Color(0xFF6B7280),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
          interval: widget.data.length > 5 ? 2 : 1,
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
          FlLine(color: Colors.grey.shade200, strokeWidth: 1),
    );
  }

  LineTouchData _buildLineTouchData() {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (spot) => Colors.grey.shade800,
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            final index = spot.x.toInt();
            String label;
            if (index < widget.data.length) {
              final dataPoint = widget.data[index];
              label =
                  dataPoint.label ??
                  '${dataPoint.date.day}/${dataPoint.date.month}/${dataPoint.date.year}';
            } else {
              label = 'Predicted';
            }
            return LineTooltipItem(
              '$label\n${_formatCurrency(spot.y)}',
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            );
          }).toList();
        },
      ),
      handleBuiltInTouches: true,
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Actual Sales', Colors.blue.shade600),
        const SizedBox(width: 12),
        _buildLegendItem('Predicted', Colors.orange),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 2,
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.trending_up, size: 32, color: Colors.grey.shade400),
              const SizedBox(height: 6),
              Text(
                'No sales trend data available',
                style: TextStyle(color: Colors.black, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    return '\$${_currencyFormat.format(value)}';
  }

  String _formatShortCurrency(double value) {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}K';
    }
    return '\$${value.toStringAsFixed(0)}';
  }

  String _truncateLabel(String label, int maxLength) {
    if (label.length <= maxLength) return label;
    return '${label.substring(0, maxLength - 1)}…';
  }
}
