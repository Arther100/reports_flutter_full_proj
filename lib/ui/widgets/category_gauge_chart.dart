import 'package:flutter/material.dart';

/// Data model for gauge chart
class GaugeChartData {
  final String label;
  final double percentage;
  final double value;
  final Color color;
  final IconData? icon;

  const GaugeChartData({
    required this.label,
    required this.percentage,
    this.value = 0,
    required this.color,
    this.icon,
  });
}

/// Radial Gauge Chart Row - Similar to Analytics Dashboard style
/// Shows multiple circular progress gauges in a responsive grid
class CategoryGaugeChart extends StatefulWidget {
  final List<GaugeChartData> data;
  final String? title;

  const CategoryGaugeChart({super.key, required this.data, this.title});

  @override
  State<CategoryGaugeChart> createState() => _CategoryGaugeChartState();
}

class _CategoryGaugeChartState extends State<CategoryGaugeChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _selectedIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isWeb = screenWidth >= 900;
        final isTablet = screenWidth >= 600 && screenWidth < 900;
        final isSmallPhone = screenWidth < 360;

        final padding = isWeb ? 20.0 : (isSmallPhone ? 12.0 : 16.0);
        final titleSize = isWeb ? 16.0 : (isSmallPhone ? 13.0 : 14.0);

        // Calculate items per row: Web=6, Tablet=3, Mobile=2
        final itemsPerRow = isWeb ? 6 : (isTablet ? 3 : 2);

        return Card(
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.title != null) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.indigo.shade400,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.donut_large,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
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
                  SizedBox(height: isWeb ? 20 : 16),
                ],
                // Gauges Grid
                _buildGaugesGrid(
                  itemsPerRow: itemsPerRow,
                  isWeb: isWeb,
                  isTablet: isTablet,
                  isSmallPhone: isSmallPhone,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGaugesGrid({
    required int itemsPerRow,
    required bool isWeb,
    required bool isTablet,
    required bool isSmallPhone,
  }) {
    // Split into rows
    final rows = <List<int>>[];
    for (var i = 0; i < widget.data.length; i += itemsPerRow) {
      final end = (i + itemsPerRow < widget.data.length)
          ? i + itemsPerRow
          : widget.data.length;
      rows.add(List.generate(end - i, (index) => i + index));
    }

    final gaugeSize = isWeb
        ? 90.0
        : (isTablet ? 80.0 : (isSmallPhone ? 60.0 : 70.0));
    final strokeWidth = isWeb ? 8.0 : (isSmallPhone ? 5.0 : 6.0);
    final rowSpacing = isWeb ? 16.0 : 12.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: rows.asMap().entries.map((entry) {
            final rowIndex = entry.key;
            final rowIndices = entry.value;
            final isLastRow = rowIndex == rows.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLastRow ? 0 : rowSpacing),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: rowIndices.map((index) {
                  final item = widget.data[index];
                  final isSelected = _selectedIndex == index;

                  // Staggered animation
                  final animDelay = index * 0.08;
                  final animProgress =
                      ((_controller.value - animDelay) / (1 - animDelay)).clamp(
                        0.0,
                        1.0,
                      );
                  final curvedProgress = Curves.easeOutCubic.transform(
                    animProgress,
                  );

                  return _buildGaugeItem(
                    item: item,
                    index: index,
                    isSelected: isSelected,
                    gaugeSize: gaugeSize,
                    strokeWidth: strokeWidth,
                    animProgress: curvedProgress,
                    isSmallPhone: isSmallPhone,
                  );
                }).toList(),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildGaugeItem({
    required GaugeChartData item,
    required int index,
    required bool isSelected,
    required double gaugeSize,
    required double strokeWidth,
    required double animProgress,
    required bool isSmallPhone,
  }) {
    final fontSize = isSmallPhone ? 12.0 : 14.0;
    final labelSize = isSmallPhone ? 9.0 : 10.0;
    final iconSize = isSmallPhone ? 14.0 : 16.0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = _selectedIndex == index ? -1 : index;
        });
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _selectedIndex = index),
        onExit: (_) => setState(() => _selectedIndex = -1),
        cursor: SystemMouseCursors.click,
        child: Tooltip(
          message: '${item.label}: ${item.percentage.toStringAsFixed(1)}%',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(isSelected ? 8 : 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? item.color.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gauge
                SizedBox(
                  height: gaugeSize,
                  width: gaugeSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background ring
                      SizedBox(
                        height: gaugeSize - 10,
                        width: gaugeSize - 10,
                        child: CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: strokeWidth,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation(
                            item.color.withValues(alpha: 0.15),
                          ),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      // Progress ring with animation
                      SizedBox(
                        height: gaugeSize - 10,
                        width: gaugeSize - 10,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: (item.percentage / 100 * animProgress).clamp(
                              0.0,
                              1.0,
                            ),
                          ),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return CircularProgressIndicator(
                              value: value,
                              strokeWidth: isSelected
                                  ? strokeWidth + 2
                                  : strokeWidth,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation(item.color),
                              strokeCap: StrokeCap.round,
                            );
                          },
                        ),
                      ),
                      // Center content
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.icon != null)
                            Icon(item.icon, color: item.color, size: iconSize),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: item.color,
                              fontSize: isSelected ? fontSize + 2 : fontSize,
                            ),
                            child: Text(
                              '${(item.percentage * animProgress).toInt()}%',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Label
                SizedBox(
                  width: gaugeSize + 10,
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: labelSize,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected ? item.color : const Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.donut_large, size: 48, color: Colors.black),
              const SizedBox(height: 8),
              Text('No data available', style: TextStyle(color: Colors.black)),
            ],
          ),
        ),
      ),
    );
  }
}
