import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart' as fl;

/// Data model for pie chart sections
class ChartSectionData {
  final String title;
  final double value;
  final Color color;
  final IconData? icon;
  final String? description;

  ChartSectionData({
    required this.title,
    required this.value,
    required this.color,
    this.icon,
    this.description,
  });
}

/// Interactive 3D-style Pie Chart with hover effects and tooltips
class InteractivePieChart extends StatefulWidget {
  final List<ChartSectionData> data;
  final String? title;
  final String? subtitle;
  final double size;
  final bool showLegend;
  final bool showPercentages;
  final double centerSpaceRadius;

  const InteractivePieChart({
    super.key,
    required this.data,
    this.title,
    this.subtitle,
    this.size = 300,
    this.showLegend = true,
    this.showPercentages = true,
    this.centerSpaceRadius = 50,
  });

  @override
  State<InteractivePieChart> createState() => _InteractivePieChartState();
}

class _InteractivePieChartState extends State<InteractivePieChart>
    with SingleTickerProviderStateMixin {
  int _touchedIndex = -1;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double get _total {
    if (widget.data.isEmpty) return 1;
    final sum = widget.data.fold<double>(0, (sum, item) => sum + item.value);
    return sum > 0 ? sum : 1;
  }

  @override
  Widget build(BuildContext context) {
    // Handle empty data
    if (widget.data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No data available',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.title != null) ...[
            Text(
              widget.title!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.subtitle!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
              ),
            ],
            const SizedBox(height: 20),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Pie Chart
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return SizedBox(
                    height: widget.size,
                    width: widget.size,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 3D Shadow effect
                        Transform.translate(
                          offset: const Offset(4, 8),
                          child: fl.PieChart(
                            fl.PieChartData(
                              sections: _buildShadowSections(),
                              centerSpaceRadius: widget.centerSpaceRadius,
                              sectionsSpace: 3,
                            ),
                          ),
                        ),
                        // Main Chart
                        fl.PieChart(
                          fl.PieChartData(
                            pieTouchData: fl.PieTouchData(
                              touchCallback: (event, response) {
                                setState(() {
                                  if (!event.isInterestedForInteractions ||
                                      response == null ||
                                      response.touchedSection == null) {
                                    _touchedIndex = -1;
                                    return;
                                  }
                                  _touchedIndex = response
                                      .touchedSection!
                                      .touchedSectionIndex;
                                });
                              },
                            ),
                            sections: _buildSections(),
                            centerSpaceRadius: widget.centerSpaceRadius,
                            sectionsSpace: 3,
                          ),
                        ),
                        // Center content
                        if (_touchedIndex >= 0 &&
                            _touchedIndex < widget.data.length)
                          _buildCenterTooltip()
                        else
                          _buildCenterDefault(),
                      ],
                    ),
                  );
                },
              ),
              if (widget.showLegend) ...[
                const SizedBox(width: 30),
                _buildLegend(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCenterDefault() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Total', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        Text(
          _formatValue(_total),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildCenterTooltip() {
    final item = widget.data[_touchedIndex];
    final percentage = (item.value / _total * 100).toStringAsFixed(1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.icon != null) Icon(item.icon, color: item.color, size: 24),
          const SizedBox(height: 4),
          Text(
            item.title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: item.color,
            ),
          ),
          Text(
            _formatValue(item.value),
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  List<fl.PieChartSectionData> _buildSections() {
    return widget.data.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final isTouched = index == _touchedIndex;
      final percentage = (item.value / _total * 100).toStringAsFixed(0);

      // Calculate animation value
      final animValue = _animation.value;

      return fl.PieChartSectionData(
        value: item.value * animValue,
        title: widget.showPercentages ? '$percentage%' : '',
        color: item.color,
        radius: isTouched ? 85 : 70,
        titleStyle: TextStyle(
          fontSize: isTouched ? 16 : 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
          ],
        ),
        badgeWidget: isTouched && item.icon != null
            ? _buildBadge(item.icon!, item.color)
            : null,
        badgePositionPercentageOffset: 1.1,
      );
    }).toList();
  }

  List<fl.PieChartSectionData> _buildShadowSections() {
    return widget.data.map((item) {
      return fl.PieChartSectionData(
        value: item.value * _animation.value,
        title: '',
        color: Colors.black.withValues(alpha: 0.1),
        radius: 70,
      );
    }).toList();
  }

  Widget _buildBadge(IconData icon, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildLegend() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.data.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isTouched = index == _touchedIndex;
        final percentage = (item.value / _total * 100).toStringAsFixed(1);

        return MouseRegion(
          onEnter: (_) => setState(() => _touchedIndex = index),
          onExit: (_) => setState(() => _touchedIndex = -1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isTouched
                  ? item.color.withValues(alpha: 0.1)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isTouched ? item.color : Colors.transparent,
                width: 2,
              ),
              boxShadow: isTouched
                  ? [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Number badge
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}'.padLeft(2, '0'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Icon
                if (item.icon != null) ...[
                  Icon(
                    item.icon,
                    color: isTouched ? item.color : Colors.grey[600],
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                ],
                // Title and info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isTouched ? item.color : Colors.grey[800],
                      ),
                    ),
                    if (item.description != null)
                      Text(
                        item.description!,
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Percentage
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isTouched
                        ? item.color.withValues(alpha: 0.2)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$percentage%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isTouched ? item.color : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatValue(double value) {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}K';
    }
    return '\$${value.toStringAsFixed(0)}';
  }
}

/// Compact version of the pie chart for smaller spaces
class CompactPieChart extends StatefulWidget {
  final List<ChartSectionData> data;
  final double size;
  final String? centerLabel;

  const CompactPieChart({
    super.key,
    required this.data,
    this.size = 150,
    this.centerLabel,
  });

  @override
  State<CompactPieChart> createState() => _CompactPieChartState();
}

class _CompactPieChartState extends State<CompactPieChart> {
  int _hoveredIndex = -1;
  OverlayEntry? _overlayEntry;

  double get _total {
    if (widget.data.isEmpty) return 1;
    final sum = widget.data.fold<double>(0, (sum, item) => sum + item.value);
    return sum > 0 ? sum : 1;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showTooltip(BuildContext context, int index, Offset globalPosition) {
    _removeOverlay();
    if (index < 0 || index >= widget.data.length) return;

    final item = widget.data[index];
    final percentage = (item.value / _total * 100).toStringAsFixed(1);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: globalPosition.dx + 10,
        top: globalPosition.dy - 60,
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: item.color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: item.color, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: item.color,
                  ),
                ),
                Text(
                  _formatValue(item.value),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (item.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    // Handle empty data
    if (widget.data.isEmpty) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(widget.size / 2),
        ),
        child: Center(
          child: Icon(
            Icons.pie_chart_outline,
            size: 32,
            color: Colors.grey[400],
          ),
        ),
      );
    }

    return MouseRegion(
      onExit: (_) {
        setState(() => _hoveredIndex = -1);
        _removeOverlay();
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Shadow layer
            Transform.translate(
              offset: const Offset(3, 6),
              child: fl.PieChart(
                fl.PieChartData(
                  sections: widget.data.map((item) {
                    return fl.PieChartSectionData(
                      value: item.value,
                      title: '',
                      color: Colors.black.withValues(alpha: 0.08),
                      radius: 45,
                    );
                  }).toList(),
                  centerSpaceRadius: 30,
                  sectionsSpace: 2,
                ),
              ),
            ),
            // Main chart
            fl.PieChart(
              fl.PieChartData(
                pieTouchData: fl.PieTouchData(
                  touchCallback: (event, response) {
                    if (event is fl.FlPointerHoverEvent ||
                        event is fl.FlLongPressStart ||
                        event is fl.FlTapDownEvent) {
                      final index =
                          response?.touchedSection?.touchedSectionIndex ?? -1;
                      if (index != _hoveredIndex) {
                        setState(() => _hoveredIndex = index);
                        if (index >= 0) {
                          // Get the position from the event
                          final pos = event.localPosition;
                          if (pos != null) {
                            final renderBox =
                                context.findRenderObject() as RenderBox;
                            final globalPos = renderBox.localToGlobal(pos);
                            _showTooltip(context, index, globalPos);
                          }
                        } else {
                          _removeOverlay();
                        }
                      }
                    }
                    if (event is fl.FlPointerExitEvent) {
                      setState(() => _hoveredIndex = -1);
                      _removeOverlay();
                    }
                  },
                ),
                sections: _buildSections(),
                centerSpaceRadius: 30,
                sectionsSpace: 2,
              ),
            ),
            // Center label
            if (widget.centerLabel != null)
              Text(
                widget.centerLabel!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  List<fl.PieChartSectionData> _buildSections() {
    return widget.data.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final isHovered = index == _hoveredIndex;
      final percentage = (item.value / _total * 100).toStringAsFixed(0);

      return fl.PieChartSectionData(
        value: item.value,
        title: isHovered ? '$percentage%' : '',
        color: item.color,
        radius: isHovered ? 55 : 45,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  String _formatValue(double value) {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}K';
    }
    return '\$${value.toStringAsFixed(0)}';
  }
}

/// Donut chart variant with inner ring
class InteractiveDonutChart extends StatefulWidget {
  final List<ChartSectionData> data;
  final String? title;
  final double size;
  final Widget? centerWidget;

  const InteractiveDonutChart({
    super.key,
    required this.data,
    this.title,
    this.size = 250,
    this.centerWidget,
  });

  @override
  State<InteractiveDonutChart> createState() => _InteractiveDonutChartState();
}

class _InteractiveDonutChartState extends State<InteractiveDonutChart> {
  int _touchedIndex = -1;

  double get _total {
    if (widget.data.isEmpty) return 1;
    final sum = widget.data.fold<double>(0, (sum, item) => sum + item.value);
    return sum > 0 ? sum : 1;
  }

  @override
  Widget build(BuildContext context) {
    // Handle empty data
    if (widget.data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No data available',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[50]!, Colors.white],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate chart size based on available space
          final availableHeight = constraints.maxHeight;
          final availableWidth = constraints.maxWidth;
          final titleHeight = widget.title != null ? 30.0 : 0.0;
          final chartSize = (availableHeight - titleHeight - 24).clamp(
            80.0,
            availableWidth * 0.45,
          );

          return Column(
            children: [
              if (widget.title != null) ...[
                Text(
                  widget.title!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: Row(
                  children: [
                    // Chart on Left
                    SizedBox(
                      width: chartSize,
                      height: chartSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Static background ring
                          Container(
                            width: chartSize * 0.85,
                            height: chartSize * 0.85,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [
                                  Colors.blue.withValues(alpha: 0.1),
                                  Colors.purple.withValues(alpha: 0.1),
                                  Colors.pink.withValues(alpha: 0.1),
                                  Colors.orange.withValues(alpha: 0.1),
                                  Colors.blue.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                          ),
                          // Shadow
                          Transform.translate(
                            offset: const Offset(3, 5),
                            child: fl.PieChart(
                              fl.PieChartData(
                                sections: widget.data.map((item) {
                                  return fl.PieChartSectionData(
                                    value: item.value,
                                    title: '',
                                    color: Colors.black.withValues(alpha: 0.08),
                                    radius: chartSize * 0.18,
                                  );
                                }).toList(),
                                centerSpaceRadius: chartSize * 0.25,
                                sectionsSpace: 3,
                              ),
                            ),
                          ),
                          // Main donut
                          fl.PieChart(
                            fl.PieChartData(
                              pieTouchData: fl.PieTouchData(
                                touchCallback: (event, response) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        response == null ||
                                        response.touchedSection == null) {
                                      _touchedIndex = -1;
                                      return;
                                    }
                                    _touchedIndex = response
                                        .touchedSection!
                                        .touchedSectionIndex;
                                  });
                                },
                              ),
                              sections: _buildSections(chartSize),
                              centerSpaceRadius: chartSize * 0.25,
                              sectionsSpace: 3,
                            ),
                          ),
                          // Center content
                          _buildCenterContent(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Legend on Right
                    Expanded(child: _buildVerticalLegend()),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVerticalLegend() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: widget.data.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isTouched = index == _touchedIndex;
          final percentage = (item.value / _total * 100).toStringAsFixed(0);
          // Truncate name if too long
          final displayName = item.title.length > 15
              ? '${item.title.substring(0, 15)}...'
              : item.title;

          return MouseRegion(
            onEnter: (_) => setState(() => _touchedIndex = index),
            onExit: (_) => setState(() => _touchedIndex = -1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isTouched
                    ? item.color.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
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
                      displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isTouched
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isTouched ? item.color : Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isTouched ? item.color : Colors.grey[500],
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

  Widget _buildCenterContent() {
    if (_touchedIndex >= 0 && _touchedIndex < widget.data.length) {
      final item = widget.data[_touchedIndex];
      final percentage = (item.value / _total * 100).toStringAsFixed(1);

      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.icon != null) Icon(item.icon, color: item.color, size: 20),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: item.color,
              ),
            ),
            Text(
              item.title,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return widget.centerWidget ??
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pie_chart, color: Colors.grey[400], size: 20),
            Text(
              'Hover for',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
            Text(
              'details',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        );
  }

  List<fl.PieChartSectionData> _buildSections(double chartSize) {
    return widget.data.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final isTouched = index == _touchedIndex;
      final baseRadius = chartSize * 0.18;

      return fl.PieChartSectionData(
        value: item.value,
        title: '',
        color: item.color,
        radius: isTouched ? baseRadius * 1.2 : baseRadius,
        borderSide: isTouched
            ? const BorderSide(color: Colors.white, width: 2)
            : BorderSide.none,
      );
    }).toList();
  }

  Widget _buildCompactLegend() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: widget.data.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isTouched = index == _touchedIndex;
          final percentage = (item.value / _total * 100).toStringAsFixed(0);

          return MouseRegion(
            onEnter: (_) => setState(() => _touchedIndex = index),
            onExit: (_) => setState(() => _touchedIndex = -1),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isTouched
                    ? item.color.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
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
                    '${item.title.length > 12 ? '${item.title.substring(0, 12)}...' : item.title} $percentage%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isTouched
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isTouched ? item.color : Colors.grey[600],
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

  // ignore: unused_element
  Widget _buildHorizontalLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: widget.data.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isTouched = index == _touchedIndex;
        final percentage = (item.value / _total * 100).toStringAsFixed(0);

        return MouseRegion(
          onEnter: (_) => setState(() => _touchedIndex = index),
          onExit: (_) => setState(() => _touchedIndex = -1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isTouched
                  ? item.color.withValues(alpha: 0.15)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isTouched ? item.color : Colors.grey[300]!,
                width: isTouched ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                    color: isTouched ? item.color : Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isTouched ? item.color : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Default colors for pie charts
class PieChartColors {
  static const List<Color> vibrant = [
    Color(0xFF3366FF), // Blue
    Color(0xFFFF6B35), // Orange
    Color(0xFF4ECDC4), // Teal
    Color(0xFFFF69B4), // Pink
    Color(0xFFFFC107), // Yellow
    Color(0xFF9B59B6), // Purple
    Color(0xFF2ECC71), // Green
    Color(0xFFE74C3C), // Red
  ];

  static const List<Color> pastel = [
    Color(0xFF7EB5FF),
    Color(0xFFFFB347),
    Color(0xFF98D8C8),
    Color(0xFFF7CAC9),
    Color(0xFFFFE066),
    Color(0xFFDDA0DD),
    Color(0xFF90EE90),
    Color(0xFFF08080),
  ];

  static const List<Color> bold = [
    Color(0xFF1A237E),
    Color(0xFFBF360C),
    Color(0xFF004D40),
    Color(0xFF880E4F),
    Color(0xFFF57F17),
    Color(0xFF4A148C),
    Color(0xFF1B5E20),
    Color(0xFFB71C1C),
  ];
}
