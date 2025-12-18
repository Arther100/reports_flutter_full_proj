import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Data model for category sales chart
class CategoryChartData {
  final String label;
  final double percentage;
  final double value;
  final Color color;
  final Color? gradientColor;

  const CategoryChartData({
    required this.label,
    required this.percentage,
    this.value = 0,
    required this.color,
    this.gradientColor,
  });
}

/// Modern animated horizontal bar chart for category sales
class CategorySalesChart extends StatefulWidget {
  final List<CategoryChartData> data;
  final String? title;

  const CategorySalesChart({super.key, required this.data, this.title});

  @override
  State<CategorySalesChart> createState() => _CategorySalesChartState();
}

class _CategorySalesChartState extends State<CategorySalesChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _hoveredIndex = -1;

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
        final isSmallPhone = screenWidth < 360;

        // Responsive padding
        final padding = isWeb ? 24.0 : (isSmallPhone ? 12.0 : 16.0);
        final titleSize = isWeb ? 18.0 : (isSmallPhone ? 14.0 : 16.0);

        return Container(
          width: constraints.maxWidth,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1B3D), Color(0xFF2D2F5E)],
            ),
            borderRadius: BorderRadius.circular(isWeb ? 24 : 16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.title != null) ...[
                Text(
                  widget.title!,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: isWeb ? 20 : 16),
              ],
              ...widget.data.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _buildBarItem(
                  item: item,
                  index: index,
                  isWeb: isWeb,
                  isSmallPhone: isSmallPhone,
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBarItem({
    required CategoryChartData item,
    required int index,
    required bool isWeb,
    required bool isSmallPhone,
  }) {
    final isHovered = _hoveredIndex == index;
    final labelSize = isWeb ? 14.0 : (isSmallPhone ? 11.0 : 12.0);
    final percentSize = isWeb ? 14.0 : (isSmallPhone ? 11.0 : 12.0);
    final barHeight = isWeb ? 28.0 : (isSmallPhone ? 20.0 : 24.0);
    final spacing = isWeb ? 16.0 : (isSmallPhone ? 10.0 : 12.0);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final animValue = CurvedAnimation(
          parent: _controller,
          curve: Interval(
            (index * 0.1).clamp(0.0, 0.5),
            ((index * 0.1) + 0.5).clamp(0.5, 1.0),
            curve: Curves.easeOutCubic,
          ),
        ).value;

        return MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit: (_) => setState(() => _hoveredIndex = -1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(bottom: spacing),
            padding: EdgeInsets.all(isHovered ? 8 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isHovered
                  ? item.color.withValues(alpha: 0.1)
                  : Colors.transparent,
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
                          fontSize: labelSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: isHovered ? percentSize + 2 : percentSize,
                        fontWeight: FontWeight.bold,
                        color: item.color,
                      ),
                      child: Text('${(item.percentage * animValue).toInt()}%'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    // Background bar
                    Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(barHeight / 2),
                      ),
                    ),
                    // Animated progress bar
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: barHeight,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (item.percentage / 100 * animValue).clamp(
                          0.0,
                          1.0,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                item.color,
                                item.gradientColor ??
                                    item.color.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(barHeight / 2),
                            boxShadow: isHovered
                                ? [
                                    BoxShadow(
                                      color: item.color.withValues(alpha: 0.5),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: item.color.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1B3D), Color(0xFF2D2F5E)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey[500]),
            const SizedBox(height: 8),
            Text(
              'No data available',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modern Radial/Donut chart for category sales - fully responsive
class CategoryRadialChart extends StatefulWidget {
  final List<CategoryChartData> data;
  final String? title;

  const CategoryRadialChart({super.key, required this.data, this.title});

  @override
  State<CategoryRadialChart> createState() => _CategoryRadialChartState();
}

class _CategoryRadialChartState extends State<CategoryRadialChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _hoveredIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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

        // Responsive sizing
        final padding = isWeb ? 24.0 : (isSmallPhone ? 12.0 : 16.0);
        final titleSize = isWeb ? 18.0 : (isSmallPhone ? 14.0 : 16.0);

        // Calculate chart size based on available width
        final availableWidth = constraints.maxWidth - (padding * 2);
        final chartSize = isWeb
            ? (availableWidth * 0.35).clamp(180.0, 280.0)
            : isTablet
            ? (availableWidth * 0.45).clamp(150.0, 220.0)
            : (availableWidth * 0.55).clamp(120.0, 180.0);

        return Container(
          width: constraints.maxWidth,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1B3D), Color(0xFF2D2F5E)],
            ),
            borderRadius: BorderRadius.circular(isWeb ? 24 : 16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.title != null) ...[
                Text(
                  widget.title!,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: isWeb ? 20 : 12),
              ],
              // Responsive layout: Row for web/tablet, Column for mobile
              if (isWeb || isTablet)
                _buildHorizontalLayout(chartSize, isWeb, isSmallPhone)
              else
                _buildVerticalLayout(chartSize, isSmallPhone),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHorizontalLayout(
    double chartSize,
    bool isWeb,
    bool isSmallPhone,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Donut chart
        _buildDonutChart(chartSize),
        SizedBox(width: isWeb ? 32 : 20),
        // Legend
        Expanded(child: _buildLegend(isWeb, isSmallPhone)),
      ],
    );
  }

  Widget _buildVerticalLayout(double chartSize, bool isSmallPhone) {
    return Column(
      children: [
        // Donut chart
        _buildDonutChart(chartSize),
        const SizedBox(height: 16),
        // Legend as grid on mobile
        _buildMobileLegend(isSmallPhone),
      ],
    );
  }

  Widget _buildDonutChart(double size) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _DonutChartPainter(
              data: widget.data,
              animation: _controller.value,
              hoveredIndex: _hoveredIndex,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegend(bool isWeb, bool isSmallPhone) {
    final fontSize = isWeb ? 13.0 : 11.0;
    final dotSize = isWeb ? 12.0 : 10.0;
    final spacing = isWeb ? 12.0 : 8.0;

    return Wrap(
      spacing: 16,
      runSpacing: spacing,
      children: widget.data.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isHovered = _hoveredIndex == index;

        return MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit: (_) => setState(() => _hoveredIndex = -1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isHovered
                  ? item.color.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isHovered ? dotSize + 4 : dotSize,
                  height: isHovered ? dotSize + 4 : dotSize,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                    boxShadow: isHovered
                        ? [
                            BoxShadow(
                              color: item.color.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: isHovered
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    Text(
                      '${item.percentage.toInt()}%',
                      style: TextStyle(
                        fontSize: fontSize - 1,
                        fontWeight: FontWeight.bold,
                        color: item.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobileLegend(bool isSmallPhone) {
    final fontSize = isSmallPhone ? 10.0 : 11.0;
    final dotSize = isSmallPhone ? 8.0 : 10.0;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: widget.data.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isHovered = _hoveredIndex == index;

        return GestureDetector(
          onTap: () {
            setState(() {
              _hoveredIndex = _hoveredIndex == index ? -1 : index;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isSmallPhone ? 6 : 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: isHovered
                  ? item.color.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isHovered ? item.color : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${item.percentage.toInt()}%',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: item.color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1B3D), Color(0xFF2D2F5E)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey[500]),
            const SizedBox(height: 8),
            Text(
              'No data available',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for animated donut chart
class _DonutChartPainter extends CustomPainter {
  final List<CategoryChartData> data;
  final double animation;
  final int hoveredIndex;

  _DonutChartPainter({
    required this.data,
    required this.animation,
    required this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = radius * 0.35;

    // Background ring
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    // Calculate total for percentage
    final total = data.fold<double>(0, (sum, item) => sum + item.percentage);
    if (total <= 0) return;

    double startAngle = -math.pi / 2; // Start from top

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final sweepAngle = (item.percentage / total) * 2 * math.pi * animation;
      final isHovered = i == hoveredIndex;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHovered ? strokeWidth + 8 : strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: [
            item.color,
            item.gradientColor ?? item.color.withValues(alpha: 0.7),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      // Add glow effect for hovered segment
      if (isHovered) {
        final glowPaint = Paint()
          ..color = item.color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 16
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
          startAngle,
          sweepAngle,
          false,
          glowPaint,
        );
      }

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Center circle (creates donut effect)
    final centerPaint = Paint()
      ..color = const Color(0xFF1A1B3D)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius - strokeWidth, centerPaint);

    // Center text
    final totalPercent = (animation * 100).toInt();
    _drawCenterText(canvas, center, '$totalPercent%', size.width * 0.18);
  }

  void _drawCenterText(
    Canvas canvas,
    Offset center,
    String text,
    double fontSize,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_DonutChartPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.hoveredIndex != hoveredIndex;
  }
}
