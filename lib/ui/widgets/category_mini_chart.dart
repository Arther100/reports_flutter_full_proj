import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Data model for category chart
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

/// Modern Mini Bar Chart Card - Fully Responsive
/// Shows categories as animated vertical bars with labels
class CategoryMiniBarChart extends StatefulWidget {
  final List<CategoryChartData> data;
  final String? title;

  const CategoryMiniBarChart({super.key, required this.data, this.title});

  @override
  State<CategoryMiniBarChart> createState() => _CategoryMiniBarChartState();
}

class _CategoryMiniBarChartState extends State<CategoryMiniBarChart>
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

        final padding = isWeb ? 24.0 : (isSmallPhone ? 12.0 : 16.0);
        final titleSize = isWeb ? 18.0 : (isSmallPhone ? 14.0 : 16.0);

        return Container(
          width: constraints.maxWidth,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isWeb ? 20 : 16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
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
                            Colors.purple.shade400,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        color: Colors.white,
                        size: 20,
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
                SizedBox(height: isWeb ? 24 : 16),
              ],
              // Bar Chart Area
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return _buildBarChart(
                    isWeb: isWeb,
                    isTablet: isTablet,
                    isSmallPhone: isSmallPhone,
                    availableWidth: constraints.maxWidth - (padding * 2),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBarChart({
    required bool isWeb,
    required bool isTablet,
    required bool isSmallPhone,
    required double availableWidth,
  }) {
    final barCount = widget.data.length;
    final spacing = isWeb ? 16.0 : (isSmallPhone ? 8.0 : 12.0);
    final barWidth = ((availableWidth - (spacing * (barCount - 1))) / barCount)
        .clamp(30.0, isWeb ? 80.0 : 60.0);
    final maxBarHeight = isWeb ? 140.0 : (isSmallPhone ? 80.0 : 100.0);
    final labelFontSize = isWeb ? 12.0 : (isSmallPhone ? 9.0 : 10.0);
    final valueFontSize = isWeb ? 14.0 : (isSmallPhone ? 10.0 : 11.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bars
        SizedBox(
          height: maxBarHeight + 30, // Extra space for value labels
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: widget.data.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = _selectedIndex == index;

              // Stagger animation
              final animDelay = index * 0.1;
              final animProgress =
                  ((_controller.value - animDelay) / (1 - animDelay)).clamp(
                    0.0,
                    1.0,
                  );
              final curvedProgress = Curves.easeOutBack.transform(animProgress);

              final barHeight =
                  (item.percentage / 100 * maxBarHeight * curvedProgress).clamp(
                    4.0,
                    maxBarHeight,
                  );

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = _selectedIndex == index ? -1 : index;
                  });
                },
                child: MouseRegion(
                  onEnter: (_) => setState(() => _selectedIndex = index),
                  onExit: (_) => setState(() => _selectedIndex = -1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: barWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Value label
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: animProgress > 0.5 ? 1.0 : 0.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? item.color.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${item.percentage.toInt()}%',
                              style: TextStyle(
                                fontSize: valueFontSize,
                                fontWeight: FontWeight.bold,
                                color: item.color,
                              ),
                            ),
                          ),
                        ),
                        // Bar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? barWidth : barWidth - 4,
                          height: barHeight,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                item.color,
                                item.gradientColor ??
                                    item.color.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              isSmallPhone ? 4 : 6,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: item.color.withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: item.color.withValues(alpha: 0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
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
        // Divider line
        Container(
          height: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade200,
                Colors.grey.shade300,
                Colors.grey.shade200,
              ],
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        // Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: widget.data.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = _selectedIndex == index;

            return SizedBox(
              width: barWidth,
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: labelFontSize,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? item.color : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined, size: 48, color: Colors.black),
            const SizedBox(height: 8),
            Text('No data available', style: TextStyle(color: Colors.black)),
          ],
        ),
      ),
    );
  }
}

/// Horizontal Progress Bars Chart - Fully Responsive
/// Alternative design with horizontal animated bars
class CategoryHorizontalBars extends StatefulWidget {
  final List<CategoryChartData> data;
  final String? title;

  const CategoryHorizontalBars({super.key, required this.data, this.title});

  @override
  State<CategoryHorizontalBars> createState() => _CategoryHorizontalBarsState();
}

class _CategoryHorizontalBarsState extends State<CategoryHorizontalBars>
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

        final padding = isWeb ? 24.0 : (isSmallPhone ? 12.0 : 16.0);
        final titleSize = isWeb ? 18.0 : (isSmallPhone ? 14.0 : 16.0);

        return Container(
          width: constraints.maxWidth,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isWeb ? 20 : 16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
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
                            Colors.indigo.shade400,
                            Colors.blue.shade400,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.analytics_outlined,
                        color: Colors.white,
                        size: 20,
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
                SizedBox(height: isWeb ? 24 : 16),
              ],
              ...widget.data.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _buildBarRow(
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

  Widget _buildBarRow({
    required CategoryChartData item,
    required int index,
    required bool isWeb,
    required bool isSmallPhone,
  }) {
    final isHovered = _hoveredIndex == index;
    final labelSize = isWeb ? 13.0 : (isSmallPhone ? 10.0 : 11.0);
    final barHeight = isWeb ? 24.0 : (isSmallPhone ? 16.0 : 20.0);
    final spacing = isWeb ? 14.0 : (isSmallPhone ? 8.0 : 10.0);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Staggered animation
        final animDelay = index * 0.08;
        final animProgress = ((_controller.value - animDelay) / (1 - animDelay))
            .clamp(0.0, 1.0);
        final curvedProgress = Curves.easeOutCubic.transform(animProgress);

        return GestureDetector(
          onTap: () {
            setState(() {
              _hoveredIndex = _hoveredIndex == index ? -1 : index;
            });
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => _hoveredIndex = index),
            onExit: (_) => setState(() => _hoveredIndex = -1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(bottom: spacing),
              padding: EdgeInsets.all(isHovered ? 8 : 4),
              decoration: BoxDecoration(
                color: isHovered
                    ? item.color.withValues(alpha: 0.06)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label and percentage row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: item.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: labelSize,
                                  fontWeight: isHovered
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isHovered
                                      ? const Color(0xFF1F2937)
                                      : const Color(0xFF6B7280),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: isHovered ? labelSize + 1 : labelSize,
                          fontWeight: FontWeight.bold,
                          color: item.color,
                        ),
                        child: Text(
                          '${(item.percentage * curvedProgress).toInt()}%',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Progress bar
                  Stack(
                    children: [
                      // Background
                      Container(
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(barHeight / 2),
                        ),
                      ),
                      // Progress
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: barHeight,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (item.percentage / 100 * curvedProgress)
                              .clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  item.gradientColor ??
                                      item.color.withValues(alpha: 0.8),
                                  item.color,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                barHeight / 2,
                              ),
                              boxShadow: isHovered
                                  ? [
                                      BoxShadow(
                                        color: item.color.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text('No data available', style: TextStyle(color: Colors.black)),
          ],
        ),
      ),
    );
  }
}

/// Mini Donut with Legend - Similar to existing pie_chart_3d.dart style
class CategoryMiniDonut extends StatefulWidget {
  final List<CategoryChartData> data;
  final String? title;

  const CategoryMiniDonut({super.key, required this.data, this.title});

  @override
  State<CategoryMiniDonut> createState() => _CategoryMiniDonutState();
}

class _CategoryMiniDonutState extends State<CategoryMiniDonut>
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

  double get _total {
    if (widget.data.isEmpty) return 1;
    final sum = widget.data.fold<double>(
      0,
      (sum, item) => sum + item.percentage,
    );
    return sum > 0 ? sum : 1;
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

        final padding = isWeb ? 24.0 : (isSmallPhone ? 12.0 : 16.0);
        final titleSize = isWeb ? 18.0 : (isSmallPhone ? 14.0 : 16.0);

        // Chart size based on available width
        final availableWidth = constraints.maxWidth - (padding * 2);
        final chartSize = isWeb
            ? (availableWidth * 0.35).clamp(140.0, 200.0)
            : isTablet
            ? (availableWidth * 0.4).clamp(120.0, 160.0)
            : (availableWidth * 0.45).clamp(100.0, 140.0);

        return Container(
          width: constraints.maxWidth,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isWeb ? 20 : 16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.title != null) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.shade400,
                            Colors.pink.shade400,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.pie_chart_rounded,
                        color: Colors.white,
                        size: 20,
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
                SizedBox(height: isWeb ? 20 : 12),
              ],
              // Chart and Legend
              isWeb || isTablet
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildDonutChart(chartSize),
                        SizedBox(width: isWeb ? 32 : 20),
                        Expanded(child: _buildLegend(isWeb, isSmallPhone)),
                      ],
                    )
                  : Column(
                      children: [
                        _buildDonutChart(chartSize),
                        const SizedBox(height: 16),
                        _buildMobileLegend(isSmallPhone),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDonutChart(double size) {
    final thickness = size * 0.2;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Shadow
              Transform.translate(
                offset: const Offset(2, 4),
                child: CustomPaint(
                  size: Size(size, size),
                  painter: _DonutShadowPainter(
                    data: widget.data,
                    total: _total,
                    animation: _controller.value,
                    thickness: thickness,
                  ),
                ),
              ),
              // Main donut
              MouseRegion(
                onHover: (event) {
                  final index = _getHoveredSection(
                    event.localPosition,
                    size,
                    thickness,
                  );
                  if (index != _hoveredIndex) {
                    setState(() => _hoveredIndex = index);
                  }
                },
                onExit: (_) => setState(() => _hoveredIndex = -1),
                child: GestureDetector(
                  onTapDown: (details) {
                    final index = _getHoveredSection(
                      details.localPosition,
                      size,
                      thickness,
                    );
                    setState(() {
                      _hoveredIndex = _hoveredIndex == index ? -1 : index;
                    });
                  },
                  child: CustomPaint(
                    size: Size(size, size),
                    painter: _DonutChartPainter(
                      data: widget.data,
                      total: _total,
                      hoveredIndex: _hoveredIndex,
                      animation: _controller.value,
                      thickness: thickness,
                    ),
                  ),
                ),
              ),
              // Center icon
              Container(
                width: size - thickness * 2 - 10,
                height: size - thickness * 2 - 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.category_outlined,
                  size: size * 0.18,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _getHoveredSection(Offset position, double size, double thickness) {
    final center = Offset(size / 2, size / 2);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;

    final distance = math.sqrt(dx * dx + dy * dy);
    final outerRadius = size / 2;
    final innerRadius = outerRadius - thickness;

    if (distance < innerRadius || distance > outerRadius) return -1;

    var angle = math.atan2(dy, dx);
    if (angle < 0) angle += 2 * math.pi;
    angle = (angle + math.pi / 2) % (2 * math.pi);

    double currentAngle = 0;
    for (int i = 0; i < widget.data.length; i++) {
      final sweepAngle = (widget.data[i].percentage / _total) * 2 * math.pi;
      if (angle >= currentAngle && angle < currentAngle + sweepAngle) {
        return i;
      }
      currentAngle += sweepAngle;
    }
    return -1;
  }

  Widget _buildLegend(bool isWeb, bool isSmallPhone) {
    final fontSize = isWeb ? 12.0 : 11.0;

    return Wrap(
      spacing: 16,
      runSpacing: 10,
      children: widget.data.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isHovered = _hoveredIndex == index;

        return MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit: (_) => setState(() => _hoveredIndex = -1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isHovered
                  ? item.color.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isHovered ? 14 : 10,
                  height: isHovered ? 14 : 10,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: isHovered
                        ? [
                            BoxShadow(
                              color: item.color.withValues(alpha: 0.4),
                              blurRadius: 6,
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
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: const Color(0xFF4B5563),
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
    final fontSize = isSmallPhone ? 9.0 : 10.0;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
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
                  ? item.color.withValues(alpha: 0.15)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isHovered ? item.color : Colors.grey.shade200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF4B5563),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text('No data available', style: TextStyle(color: Colors.black)),
          ],
        ),
      ),
    );
  }
}

/// Shadow painter for donut chart
class _DonutShadowPainter extends CustomPainter {
  final List<CategoryChartData> data;
  final double total;
  final double animation;
  final double thickness;

  _DonutShadowPainter({
    required this.data,
    required this.total,
    required this.animation,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    double startAngle = -math.pi / 2;
    for (final item in data) {
      final sweepAngle = (item.percentage / total) * 2 * math.pi * animation;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - thickness / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutShadowPainter oldDelegate) =>
      oldDelegate.animation != animation;
}

/// Main donut chart painter
class _DonutChartPainter extends CustomPainter {
  final List<CategoryChartData> data;
  final double total;
  final int hoveredIndex;
  final double animation;
  final double thickness;

  _DonutChartPainter({
    required this.data,
    required this.total,
    required this.hoveredIndex,
    required this.animation,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final sweepAngle = (item.percentage / total) * 2 * math.pi * animation;

      if (sweepAngle <= 0) continue;

      final isHovered = i == hoveredIndex;
      final currentThickness = isHovered ? thickness + 6 : thickness;
      final currentRadius = isHovered ? radius + 3 : radius;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = currentThickness
        ..strokeCap = StrokeCap.butt
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: [
            item.color,
            item.gradientColor ?? item.color.withValues(alpha: 0.7),
          ],
          transform: GradientRotation(startAngle),
        ).createShader(Rect.fromCircle(center: center, radius: currentRadius));

      if (isHovered) {
        final glowPaint = Paint()
          ..color = item.color.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = currentThickness + 10
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

        canvas.drawArc(
          Rect.fromCircle(
            center: center,
            radius: currentRadius - currentThickness / 2,
          ),
          startAngle,
          sweepAngle,
          false,
          glowPaint,
        );
      }

      canvas.drawArc(
        Rect.fromCircle(
          center: center,
          radius: currentRadius - currentThickness / 2,
        ),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      // Separator line
      final separatorPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final innerRadius = radius - thickness;
      final outerX = center.dx + radius * math.cos(startAngle);
      final outerY = center.dy + radius * math.sin(startAngle);
      final innerX = center.dx + innerRadius * math.cos(startAngle);
      final innerY = center.dy + innerRadius * math.sin(startAngle);

      canvas.drawLine(
        Offset(innerX, innerY),
        Offset(outerX, outerY),
        separatorPaint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutChartPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.hoveredIndex != hoveredIndex;
}
