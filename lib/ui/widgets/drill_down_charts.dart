import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart' as fl;
import 'dart:math' as math;

/// Data model for pie chart slices (renamed to avoid conflict with fl_chart)
class PieSliceData {
  final String id;
  final String label;
  final double value;
  final Color color;
  final Map<String, dynamic>? metadata;

  PieSliceData({
    required this.id,
    required this.label,
    required this.value,
    required this.color,
    this.metadata,
  });
}

/// Data model for bar chart items
class BarChartItem {
  final String id;
  final String label;
  final double value;
  final Color color;
  final Map<String, dynamic>? metadata;

  BarChartItem({
    required this.id,
    required this.label,
    required this.value,
    required this.color,
    this.metadata,
  });
}

/// Drill-down capable pie chart
class DrillDownPieChart extends StatefulWidget {
  final String title;
  final List<PieSliceData> data;
  final Function(PieSliceData)? onSliceTap;
  final double height;

  const DrillDownPieChart({
    super.key,
    required this.title,
    required this.data,
    this.onSliceTap,
    this.height = 300,
  });

  @override
  State<DrillDownPieChart> createState() => _DrillDownPieChartState();
}

class _DrillDownPieChartState extends State<DrillDownPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: fl.PieChart(
                    fl.PieChartData(
                      pieTouchData: fl.PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response == null ||
                                response.touchedSection == null) {
                              touchedIndex = -1;
                              return;
                            }
                            touchedIndex =
                                response.touchedSection!.touchedSectionIndex;
                          });

                          if (event is fl.FlTapUpEvent &&
                              touchedIndex >= 0 &&
                              touchedIndex < widget.data.length) {
                            widget.onSliceTap?.call(widget.data[touchedIndex]);
                          }
                        },
                      ),
                      borderData: fl.FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: _buildSections(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildLegend()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<fl.PieChartSectionData> _buildSections() {
    final total = widget.data.fold<double>(0, (sum, d) => sum + d.value);

    return widget.data.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final isTouched = index == touchedIndex;
      final percentage = total > 0 ? (data.value / total * 100) : 0;

      return fl.PieChartSectionData(
        color: data.color,
        value: data.value,
        title: percentage > 5 ? '${percentage.toStringAsFixed(1)}%' : '',
        radius: isTouched ? 60 : 50,
        titleStyle: TextStyle(
          fontSize: isTouched ? 14 : 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: isTouched ? _buildBadge(data) : null,
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();
  }

  Widget _buildBadge(PieSliceData data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: data.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        data.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: widget.data.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          final isTouched = index == touchedIndex;

          return InkWell(
            onTap: () {
              widget.onSliceTap?.call(data);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: data.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isTouched
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatValue(data.value),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isTouched ? data.color : null,
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

  String _formatValue(double value) {
    if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}K';
    return '₹${value.toStringAsFixed(0)}';
  }
}

/// Interactive bar chart with drill-down
class DrillDownBarChart extends StatefulWidget {
  final String title;
  final List<BarChartItem> data;
  final Function(BarChartItem)? onBarTap;
  final double height;
  final bool horizontal;

  const DrillDownBarChart({
    super.key,
    required this.title,
    required this.data,
    this.onBarTap,
    this.height = 300,
    this.horizontal = false,
  });

  @override
  State<DrillDownBarChart> createState() => _DrillDownBarChartState();
}

class _DrillDownBarChartState extends State<DrillDownBarChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: widget.horizontal
                ? _buildHorizontalBars()
                : _buildVerticalBars(),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalBars() {
    final maxValue = widget.data.fold<double>(
      0,
      (max, d) => math.max(max, d.value),
    );

    return fl.BarChart(
      fl.BarChartData(
        alignment: fl.BarChartAlignment.spaceAround,
        maxY: maxValue * 1.2,
        barTouchData: fl.BarTouchData(
          touchCallback: (event, response) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  response == null ||
                  response.spot == null) {
                touchedIndex = -1;
                return;
              }
              touchedIndex = response.spot!.touchedBarGroupIndex;
            });

            if (event is fl.FlTapUpEvent &&
                touchedIndex >= 0 &&
                touchedIndex < widget.data.length) {
              widget.onBarTap?.call(widget.data[touchedIndex]);
            }
          },
          touchTooltipData: fl.BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return fl.BarTooltipItem(
                '${widget.data[groupIndex].label}\n${_formatValue(rod.toY)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: fl.FlTitlesData(
          bottomTitles: fl.AxisTitles(
            sideTitles: fl.SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= widget.data.length)
                  return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: RotatedBox(
                    quarterTurns: -1,
                    child: Text(
                      widget.data[value.toInt()].label,
                      style: const TextStyle(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
              reservedSize: 60,
            ),
          ),
          leftTitles: fl.AxisTitles(
            sideTitles: fl.SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatShortValue(value),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const fl.AxisTitles(
            sideTitles: fl.SideTitles(showTitles: false),
          ),
          rightTitles: const fl.AxisTitles(
            sideTitles: fl.SideTitles(showTitles: false),
          ),
        ),
        borderData: fl.FlBorderData(show: false),
        gridData: fl.FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) =>
              fl.FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
        ),
        barGroups: widget.data.asMap().entries.map((e) {
          final isTouched = e.key == touchedIndex;
          return fl.BarChartGroupData(
            x: e.key,
            barRods: [
              fl.BarChartRodData(
                toY: e.value.value,
                color: e.value.color.withOpacity(isTouched ? 1 : 0.8),
                width: isTouched ? 24 : 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHorizontalBars() {
    return ListView.builder(
      itemCount: widget.data.length,
      itemBuilder: (context, index) {
        final item = widget.data[index];
        final maxValue = widget.data.fold<double>(
          0,
          (max, d) => math.max(max, d.value),
        );
        final percentage = maxValue > 0 ? (item.value / maxValue) : 0;
        final isTouched = index == touchedIndex;

        return GestureDetector(
          onTap: () {
            setState(() => touchedIndex = index);
            widget.onBarTap?.call(item);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: EdgeInsets.all(isTouched ? 12 : 8),
            decoration: BoxDecoration(
              color: isTouched
                  ? item.color.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontWeight: isTouched
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatValue(item.value),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: item.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage.toDouble(),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(item.color),
                    minHeight: isTouched ? 8 : 6,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatValue(double value) {
    if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}K';
    return '₹${value.toStringAsFixed(0)}';
  }

  String _formatShortValue(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(0)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }
}

/// Mini sparkline chart for compact displays
class MiniSparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double width;
  final double height;
  final bool showFill;

  const MiniSparkline({
    super.key,
    required this.data,
    this.color = Colors.blue,
    this.width = 100,
    this.height = 40,
    this.showFill = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return SizedBox(width: width, height: height);

    return CustomPaint(
      size: Size(width, height),
      painter: SparklinePainter(data: data, color: color, showFill: showFill),
    );
  }
}

class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool showFill;

  SparklinePainter({
    required this.data,
    required this.color,
    required this.showFill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxValue = data.reduce(math.max);
    final minValue = data.reduce(math.min);
    final range = maxValue - minValue;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y =
          size.height -
          (range > 0
              ? (data[i] - minValue) / range * size.height
              : size.height / 2);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    if (showFill) {
      canvas.drawPath(fillPath, fillPaint);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Donut chart with center value
class DonutChartWithCenter extends StatelessWidget {
  final String title;
  final String centerValue;
  final String centerLabel;
  final List<DonutSegment> segments;
  final double size;

  const DonutChartWithCenter({
    super.key,
    required this.title,
    required this.centerValue,
    required this.centerLabel,
    required this.segments,
    this.size = 150,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                fl.PieChart(
                  fl.PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: size * 0.35,
                    sections: segments
                        .map(
                          (s) => fl.PieChartSectionData(
                            value: s.value,
                            color: s.color,
                            radius: size * 0.15,
                            title: '',
                          ),
                        )
                        .toList(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerValue,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      centerLabel,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DonutSegment {
  final double value;
  final Color color;
  final String label;

  DonutSegment({required this.value, required this.color, required this.label});
}

/// Comparison chart for side-by-side analysis
class ComparisonChart extends StatelessWidget {
  final String title;
  final String leftLabel;
  final String rightLabel;
  final double leftValue;
  final double rightValue;
  final Color leftColor;
  final Color rightColor;

  const ComparisonChart({
    super.key,
    required this.title,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftValue,
    required this.rightValue,
    this.leftColor = Colors.blue,
    this.rightColor = Colors.orange,
  });

  @override
  Widget build(BuildContext context) {
    final total = leftValue + rightValue;
    final leftPercentage = total > 0 ? (leftValue / total) : 0.5;
    final rightPercentage = total > 0 ? (rightValue / total) : 0.5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: (leftPercentage * 100).round(),
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: leftColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${(leftPercentage * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: (rightPercentage * 100).round(),
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: rightColor,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(16),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${(rightPercentage * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem(leftLabel, leftColor, _formatValue(leftValue)),
              _buildLegendItem(
                rightLabel,
                rightColor,
                _formatValue(rightValue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String value) {
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
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11)),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  String _formatValue(double value) {
    if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}K';
    return '₹${value.toStringAsFixed(0)}';
  }
}
