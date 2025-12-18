import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Data model for liquid fill gauge
class LiquidGaugeData {
  final String label;
  final double percentage;
  final Color color;
  final Color? secondaryColor;

  const LiquidGaugeData({
    required this.label,
    required this.percentage,
    required this.color,
    this.secondaryColor,
  });
}

/// A single liquid fill gauge with wave animation
class LiquidFillGauge extends StatefulWidget {
  final double percentage;
  final String label;
  final Color color;
  final Color? secondaryColor;
  final double size;
  final bool showPercentage;

  const LiquidFillGauge({
    super.key,
    required this.percentage,
    required this.label,
    required this.color,
    this.secondaryColor,
    this.size = 120,
    this.showPercentage = true,
  });

  @override
  State<LiquidFillGauge> createState() => _LiquidFillGaugeState();
}

class _LiquidFillGaugeState extends State<LiquidFillGauge>
    with TickerProviderStateMixin {
  late AnimationController _fillController;
  late AnimationController _waveController;
  late Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();

    // Fill animation (runs once)
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fillAnimation =
        Tween<double>(begin: 0, end: widget.percentage.clamp(0, 100)).animate(
          CurvedAnimation(parent: _fillController, curve: Curves.easeOutCubic),
        );

    _fillController.forward();

    // Wave animation (continuous)
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void didUpdateWidget(LiquidFillGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percentage != widget.percentage) {
      _fillAnimation =
          Tween<double>(
            begin: _fillAnimation.value,
            end: widget.percentage.clamp(0, 100),
          ).animate(
            CurvedAnimation(
              parent: _fillController,
              curve: Curves.easeOutCubic,
            ),
          );
      _fillController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fillController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E2140),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: widget.color.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: AnimatedBuilder(
              animation: Listenable.merge([_fillAnimation, _waveController]),
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _LiquidWavePainter(
                    percentage: _fillAnimation.value,
                    wavePhase: _waveController.value * 2 * 3.14159,
                    color: widget.color,
                    secondaryColor:
                        widget.secondaryColor ??
                        widget.color.withValues(alpha: 0.7),
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.showPercentage) ...[
          SizedBox(height: widget.size * 0.06),
          SizedBox(
            width: widget.size + 10,
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: (widget.size * 0.12).clamp(9.0, 14.0),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF667EEA),
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ],
      ],
    );
  }
}

/// Liquid wave painter with animated waves
class _LiquidWavePainter extends CustomPainter {
  final double percentage;
  final double wavePhase;
  final Color color;
  final Color secondaryColor;

  _LiquidWavePainter({
    required this.percentage,
    required this.wavePhase,
    required this.color,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Guard against invalid sizes
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw dark background circle
    final bgPaint = Paint()
      ..color = const Color(0xFF1E2140)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Draw inner glow ring
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius - 6, ringPaint);

    // Clamp percentage to valid range
    final clampedPercentage = percentage.clamp(0.0, 100.0);

    // Skip drawing fill if percentage is 0 or less
    if (clampedPercentage <= 0) {
      _drawPercentageText(canvas, size, center);
      return;
    }

    // Calculate fill level
    final fillHeight = size.height * (1 - clampedPercentage / 100);
    final fillRectHeight = (size.height - fillHeight).clamp(1.0, size.height);

    // Skip if fill height is too small
    if (fillRectHeight < 1) {
      _drawPercentageText(canvas, size, center);
      return;
    }

    // Clip to circle first
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius - 4)),
    );

    // Ensure valid rect for shader
    final shaderRect = Rect.fromLTWH(
      0,
      fillHeight.clamp(0, size.height - 1),
      size.width.clamp(1, double.infinity),
      fillRectHeight.clamp(1, double.infinity),
    );

    // Draw back wave (darker, offset phase)
    final backWavePath = Path();
    backWavePath.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 2) {
      final waveHeight = 8.0 + (clampedPercentage / 100) * 4;
      final y =
          fillHeight +
          math.sin((x / size.width * 2 * math.pi) + wavePhase + math.pi) *
              waveHeight;
      backWavePath.lineTo(x, y);
    }
    backWavePath.lineTo(size.width, size.height);
    backWavePath.close();

    final backWavePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          secondaryColor.withValues(alpha: 0.6),
          secondaryColor.withValues(alpha: 0.8),
        ],
      ).createShader(shaderRect);
    canvas.drawPath(backWavePath, backWavePaint);

    // Draw front wave (main color)
    final frontWavePath = Path();
    frontWavePath.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 2) {
      final waveHeight = 6.0 + (clampedPercentage / 100) * 3;
      final y =
          fillHeight +
          math.sin((x / size.width * 2 * math.pi) + wavePhase) * waveHeight;
      frontWavePath.lineTo(x, y);
    }
    frontWavePath.lineTo(size.width, size.height);
    frontWavePath.close();

    final frontWavePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.85), color],
      ).createShader(shaderRect);
    canvas.drawPath(frontWavePath, frontWavePaint);

    canvas.restore();

    _drawPercentageText(canvas, size, center);
  }

  void _drawPercentageText(Canvas canvas, Size size, Offset center) {
    // Draw percentage text
    final percentText = '${percentage.toInt()}%';
    final textPainter = TextPainter(
      text: TextSpan(
        text: percentText,
        style: TextStyle(
          fontSize: size.width * 0.22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
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
  bool shouldRepaint(_LiquidWavePainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.color != color;
  }
}

/// A row of multiple liquid fill gauges
class LiquidGaugeRow extends StatelessWidget {
  final List<LiquidGaugeData> data;
  final double gaugeSize;
  final MainAxisAlignment mainAxisAlignment;

  const LiquidGaugeRow({
    super.key,
    required this.data,
    this.gaugeSize = 100,
    this.mainAxisAlignment = MainAxisAlignment.spaceEvenly,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.water_drop_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
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
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1B3D), Color(0xFF2D2F5E)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: mainAxisAlignment,
        children: data.map((item) {
          return LiquidFillGauge(
            percentage: item.percentage,
            label: item.label,
            color: item.color,
            secondaryColor: item.secondaryColor,
            size: gaugeSize,
          );
        }).toList(),
      ),
    );
  }
}

/// Interactive liquid gauge card with hover effects
class InteractiveLiquidGaugeCard extends StatefulWidget {
  final List<LiquidGaugeData> data;
  final String? title;
  final double gaugeSize;

  const InteractiveLiquidGaugeCard({
    super.key,
    required this.data,
    this.title,
    this.gaugeSize = 110,
  });

  @override
  State<InteractiveLiquidGaugeCard> createState() =>
      _InteractiveLiquidGaugeCardState();
}

class _InteractiveLiquidGaugeCardState
    extends State<InteractiveLiquidGaugeCard> {
  int _hoveredIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
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
              Icon(
                Icons.water_drop_outlined,
                size: 48,
                color: Colors.grey[500],
              ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use MediaQuery for proper device detection
        final screenWidth = MediaQuery.of(context).size.width;
        final isWeb = screenWidth >= 900;
        final isSmallPhone = screenWidth < 360; // iPhone SE, small Android
        final isMediumPhone = screenWidth >= 360 && screenWidth < 414;

        // Responsive padding based on screen size
        final containerPadding = isWeb ? 20.0 : (isSmallPhone ? 8.0 : 12.0);

        return Container(
          width: constraints.maxWidth,
          padding: EdgeInsets.all(containerPadding),
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
                    fontSize: isWeb ? 18 : (isSmallPhone ? 12 : 14),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: isWeb ? 16 : (isSmallPhone ? 6 : 10)),
              ],
              Flexible(
                child: LayoutBuilder(
                  builder: (context, innerConstraints) {
                    final availableWidth = innerConstraints.maxWidth;

                    // Web: 6 items in one row, Mobile/Tablet: 2 items per row (2x3 grid)
                    final itemsPerRow = isWeb ? 6 : 2;

                    // Calculate responsive horizontal padding
                    final horizontalPadding = isWeb
                        ? 8.0
                        : (isSmallPhone ? 4.0 : 6.0);

                    // Calculate total padding space
                    final totalHorizontalPadding =
                        itemsPerRow * horizontalPadding * 2;
                    final availableForGauges =
                        availableWidth - totalHorizontalPadding;

                    // Calculate responsive gauge size based on device
                    double responsiveGaugeSize;
                    if (isWeb) {
                      responsiveGaugeSize = (availableForGauges / itemsPerRow)
                          .clamp(60.0, widget.gaugeSize);
                    } else {
                      // Calculate optimal size for 2 gauges per row
                      final calculatedSize = availableForGauges / itemsPerRow;

                      // Different max sizes based on phone size
                      final maxSize = isSmallPhone
                          ? 70.0
                          : (isMediumPhone ? 85.0 : 100.0);
                      final minSize = isSmallPhone ? 55.0 : 60.0;

                      responsiveGaugeSize = calculatedSize.clamp(
                        minSize,
                        maxSize,
                      );
                    }

                    // Calculate row spacing based on gauge size
                    final rowSpacing = isWeb
                        ? 12.0
                        : (responsiveGaugeSize * 0.15).clamp(8.0, 16.0);

                    // Split items into rows
                    final rows = <List<int>>[];
                    for (var i = 0; i < widget.data.length; i += itemsPerRow) {
                      final end = (i + itemsPerRow < widget.data.length)
                          ? i + itemsPerRow
                          : widget.data.length;
                      rows.add(List.generate(end - i, (index) => i + index));
                    }

                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: rows.asMap().entries.map((entry) {
                          final rowIndex = entry.key;
                          final rowIndices = entry.value;
                          final isLastRow = rowIndex == rows.length - 1;

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: isLastRow ? 0 : rowSpacing,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: rowIndices.map((index) {
                                final item = widget.data[index];
                                final isHovered = index == _hoveredIndex;

                                return SizedBox(
                                  width:
                                      responsiveGaugeSize +
                                      (horizontalPadding * 2),
                                  child: Center(
                                    child: MouseRegion(
                                      onEnter: (_) =>
                                          setState(() => _hoveredIndex = index),
                                      onExit: (_) =>
                                          setState(() => _hoveredIndex = -1),
                                      child: AnimatedScale(
                                        scale: isHovered ? 1.05 : 1.0,
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          padding: EdgeInsets.all(
                                            isHovered ? 2 : 0,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            boxShadow: isHovered
                                                ? [
                                                    BoxShadow(
                                                      color: item.color
                                                          .withValues(
                                                            alpha: 0.4,
                                                          ),
                                                      blurRadius: 15,
                                                      spreadRadius: 3,
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: LiquidFillGauge(
                                            percentage: item.percentage,
                                            label: item.label,
                                            color: item.color,
                                            secondaryColor: item.secondaryColor,
                                            size: responsiveGaugeSize,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
