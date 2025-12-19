import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Data model for 3D pie chart sections
class PieSection3D {
  final String label;
  final double value;
  final Color color;
  final String? percentage;

  const PieSection3D({
    required this.label,
    required this.value,
    required this.color,
    this.percentage,
  });
}

/// Modern 3D Donut Chart with percentage labels on slices
class PieChart3D extends StatefulWidget {
  final List<PieSection3D> data;
  final String? title;
  final double size;
  final IconData? centerIcon;
  final double thickness;

  const PieChart3D({
    super.key,
    required this.data,
    this.title,
    this.size = 220,
    this.centerIcon,
    this.thickness = 45,
  });

  @override
  State<PieChart3D> createState() => _PieChart3DState();
}

class _PieChart3DState extends State<PieChart3D>
    with SingleTickerProviderStateMixin {
  int _hoveredIndex = -1;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
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
    if (widget.data.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      padding: const EdgeInsets.all(24),
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 20),
          ],
          // Donut Chart
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return SizedBox(
                width: widget.size,
                height: widget.size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Shadow layer
                    Transform.translate(
                      offset: const Offset(3, 6),
                      child: CustomPaint(
                        size: Size(widget.size, widget.size),
                        painter: _ShadowPainter(
                          sections: widget.data,
                          total: _total,
                          animationValue: _animation.value,
                          thickness: widget.thickness,
                        ),
                      ),
                    ),
                    // Main donut
                    MouseRegion(
                      onHover: (event) {
                        final index = _getHoveredSection(event.localPosition);
                        if (index != _hoveredIndex) {
                          setState(() => _hoveredIndex = index);
                        }
                      },
                      onExit: (_) => setState(() => _hoveredIndex = -1),
                      child: CustomPaint(
                        size: Size(widget.size, widget.size),
                        painter: _ModernDonutPainter(
                          sections: widget.data,
                          total: _total,
                          hoveredIndex: _hoveredIndex,
                          animationValue: _animation.value,
                          thickness: widget.thickness,
                        ),
                      ),
                    ),
                    // Center circle with icon
                    Container(
                      width: widget.size - widget.thickness * 2 - 20,
                      height: widget.size - widget.thickness * 2 - 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.centerIcon ?? Icons.monetization_on_outlined,
                        size: 36,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pie_chart_outline, size: 48, color: Colors.black),
            const SizedBox(height: 8),
            Text(
              'No data available',
              style: TextStyle(color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  int _getHoveredSection(Offset position) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;

    final distance = math.sqrt(dx * dx + dy * dy);
    final outerRadius = widget.size / 2;
    final innerRadius = outerRadius - widget.thickness;

    if (distance < innerRadius || distance > outerRadius) return -1;

    var angle = math.atan2(dy, dx);
    if (angle < 0) angle += 2 * math.pi;
    angle = (angle + math.pi / 2) % (2 * math.pi);

    double currentAngle = 0;
    for (int i = 0; i < widget.data.length; i++) {
      final sweepAngle = (widget.data[i].value / _total) * 2 * math.pi;
      if (angle >= currentAngle && angle < currentAngle + sweepAngle) {
        return i;
      }
      currentAngle += sweepAngle;
    }
    return -1;
  }
}

/// Shadow painter for 3D effect
class _ShadowPainter extends CustomPainter {
  final List<PieSection3D> sections;
  final double total;
  final double animationValue;
  final double thickness;

  _ShadowPainter({
    required this.sections,
    required this.total,
    required this.animationValue,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;

    double startAngle = -math.pi / 2;
    for (final section in sections) {
      final sweepAngle = (section.value / total) * 2 * math.pi * animationValue;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - thickness / 2),
        startAngle,
        sweepAngle,
        false,
        shadowPaint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_ShadowPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

/// Modern donut painter with gradient slices and percentage labels
class _ModernDonutPainter extends CustomPainter {
  final List<PieSection3D> sections;
  final double total;
  final int hoveredIndex;
  final double animationValue;
  final double thickness;

  _ModernDonutPainter({
    required this.sections,
    required this.total,
    required this.hoveredIndex,
    required this.animationValue,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (sections.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < sections.length; i++) {
      final section = sections[i];
      final sweepAngle = (section.value / total) * 2 * math.pi * animationValue;

      if (sweepAngle <= 0) continue;

      final isHovered = i == hoveredIndex;
      final currentThickness = isHovered ? thickness + 8 : thickness;
      final currentRadius = isHovered ? radius + 4 : radius;

      // Create gradient for slice
      final rect = Rect.fromCircle(center: center, radius: currentRadius);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = currentThickness
        ..strokeCap = StrokeCap.butt
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: [
            _lightenColor(section.color, 1.15),
            section.color,
            _darkenColor(section.color, 0.85),
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: GradientRotation(startAngle),
        ).createShader(rect);

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

      // Draw percentage label on the slice
      if (animationValue > 0.5) {
        _drawPercentageLabel(
          canvas,
          center,
          radius,
          startAngle,
          sweepAngle,
          section,
          i,
        );
      }

      // Draw separator line
      final separatorPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

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

  void _drawPercentageLabel(
    Canvas canvas,
    Offset center,
    double radius,
    double startAngle,
    double sweepAngle,
    PieSection3D section,
    int index,
  ) {
    final percentage = (section.value / total * 100).toStringAsFixed(0);

    // Position label in the middle of the arc
    final midAngle = startAngle + sweepAngle / 2;
    final labelRadius = radius - thickness / 2;
    final labelX = center.dx + labelRadius * math.cos(midAngle);
    final labelY = center.dy + labelRadius * math.sin(midAngle);

    // Only draw if slice is big enough
    if (sweepAngle < 0.3) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$percentage%',
        style: TextStyle(
          fontSize: sweepAngle > 0.8 ? 14 : 11,
          fontWeight: FontWeight.bold,
          color: _getContrastColor(section.color),
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 2,
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    canvas.save();
    canvas.translate(labelX, labelY);

    // Rotate text to follow the arc, but keep it readable
    double rotation = midAngle + math.pi / 2;
    if (midAngle > math.pi / 2 && midAngle < 3 * math.pi / 2) {
      rotation += math.pi;
    }
    canvas.rotate(rotation);

    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  Color _darkenColor(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      (color.red * factor).clamp(0, 255).toInt(),
      (color.green * factor).clamp(0, 255).toInt(),
      (color.blue * factor).clamp(0, 255).toInt(),
    );
  }

  Color _lightenColor(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      (color.red + (255 - color.red) * (factor - 1)).clamp(0, 255).toInt(),
      (color.green + (255 - color.green) * (factor - 1)).clamp(0, 255).toInt(),
      (color.blue + (255 - color.blue) * (factor - 1)).clamp(0, 255).toInt(),
    );
  }

  @override
  bool shouldRepaint(_ModernDonutPainter oldDelegate) {
    return oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.animationValue != animationValue;
  }
}

// ignore: unused_element
class _Pie3DPainter extends CustomPainter {
  final List<PieSection3D> sections;
  final double total;
  final int hoveredIndex;
  final double animationValue;
  final double tiltAngle;
  final double thickness;

  _Pie3DPainter({
    required this.sections,
    required this.total,
    required this.hoveredIndex,
    required this.animationValue,
    required this.tiltAngle,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (sections.isEmpty) return;

    final center = Offset(size.width / 2, size.height * 0.45);
    final radius = math.min(size.width, size.height) * 0.38;
    final depth = thickness * animationValue;

    // Apply animation to sweep angles
    final animatedSweeps = sections
        .map((s) => (s.value / total) * 2 * math.pi * animationValue)
        .toList();

    // Draw the 3D side walls first (from back to front)
    _draw3DSides(canvas, center, radius, depth, animatedSweeps);

    // Draw top ellipse surface
    _drawTopSurface(canvas, center, radius, animatedSweeps);
  }

  void _draw3DSides(
    Canvas canvas,
    Offset center,
    double radius,
    double depth,
    List<double> sweeps,
  ) {
    double startAngle = -math.pi / 2;

    // Draw each section's 3D side
    for (int i = 0; i < sections.length; i++) {
      final section = sections[i];
      final sweepAngle = sweeps[i];

      if (sweepAngle <= 0) continue;

      final isHovered = i == hoveredIndex;
      final hoverOffset = isHovered ? 6.0 : 0.0;

      // Calculate offset direction for hover
      final midAngle = startAngle + sweepAngle / 2;
      final offsetX = math.cos(midAngle) * hoverOffset;
      final offsetY = math.sin(midAngle) * hoverOffset * tiltAngle;
      final sectionCenter = center + Offset(offsetX, offsetY);

      // Draw the 3D depth/side of this slice
      _drawSliceSide(
        canvas,
        sectionCenter,
        radius,
        depth,
        startAngle,
        sweepAngle,
        section.color,
        isHovered,
      );

      startAngle += sweepAngle;
    }
  }

  void _drawSliceSide(
    Canvas canvas,
    Offset center,
    double radius,
    double depth,
    double startAngle,
    double sweepAngle,
    Color color,
    bool isHovered,
  ) {
    // Draw the curved side wall using multiple small segments
    final segments = (sweepAngle * 30).ceil().clamp(8, 60);
    final angleStep = sweepAngle / segments;

    for (int seg = 0; seg <= segments; seg++) {
      final angle = startAngle + seg * angleStep;
      final nextAngle = startAngle + (seg + 1) * angleStep;

      if (seg >= segments) break;

      // Only draw sides that face the viewer (front half of pie)
      if (angle > -math.pi * 0.1 && angle < math.pi * 1.1) {
        final x1 = center.dx + radius * math.cos(angle);
        final y1Top = center.dy + radius * math.sin(angle) * tiltAngle;
        final y1Bottom = y1Top + depth;

        final x2 = center.dx + radius * math.cos(nextAngle);
        final y2Top = center.dy + radius * math.sin(nextAngle) * tiltAngle;
        final y2Bottom = y2Top + depth;

        final sidePath = Path()
          ..moveTo(x1, y1Top)
          ..lineTo(x1, y1Bottom)
          ..lineTo(x2, y2Bottom)
          ..lineTo(x2, y2Top)
          ..close();

        // Gradient based on angle for realistic lighting
        final lightFactor = 0.5 + 0.5 * math.cos(angle - math.pi / 4);
        final gradientColor = _darkenColor(color, 0.55 + lightFactor * 0.25);

        canvas.drawPath(
          sidePath,
          Paint()
            ..color = gradientColor
            ..style = PaintingStyle.fill,
        );
      }
    }

    // Draw the flat edge faces at start and end of slice
    _drawSliceEdge(canvas, center, radius, depth, startAngle, color);
    _drawSliceEdge(
      canvas,
      center,
      radius,
      depth,
      startAngle + sweepAngle,
      color,
    );
  }

  void _drawSliceEdge(
    Canvas canvas,
    Offset center,
    double radius,
    double depth,
    double angle,
    Color color,
  ) {
    // Only draw edges that are visible (facing viewer)
    final normalAngle = angle + math.pi / 2;
    if (math.cos(normalAngle) < -0.3) return; // Skip back-facing edges

    final edgeColor = _darkenColor(color, 0.75);

    final outerX = center.dx + radius * math.cos(angle);
    final outerYTop = center.dy + radius * math.sin(angle) * tiltAngle;
    final outerYBottom = outerYTop + depth;

    final edgePath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx, center.dy + depth)
      ..lineTo(outerX, outerYBottom)
      ..lineTo(outerX, outerYTop)
      ..close();

    canvas.drawPath(
      edgePath,
      Paint()
        ..color = edgeColor
        ..style = PaintingStyle.fill,
    );
  }

  void _drawTopSurface(
    Canvas canvas,
    Offset center,
    double radius,
    List<double> sweeps,
  ) {
    double startAngle = -math.pi / 2;

    for (int i = 0; i < sections.length; i++) {
      final section = sections[i];
      final sweepAngle = sweeps[i];

      if (sweepAngle <= 0) continue;

      final isHovered = i == hoveredIndex;
      final hoverOffset = isHovered ? 6.0 : 0.0;

      // Calculate offset direction for hover effect
      final midAngle = startAngle + sweepAngle / 2;
      final offsetX = math.cos(midAngle) * hoverOffset;
      final offsetY = math.sin(midAngle) * hoverOffset * tiltAngle;
      final sectionCenter = center + Offset(offsetX, offsetY);

      // Draw top ellipse arc
      final rect = Rect.fromCenter(
        center: sectionCenter,
        width: radius * 2,
        height: radius * 2 * tiltAngle,
      );

      // Create gradient for 3D look on top
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.4),
          radius: 1.0,
          colors: [
            _lightenColor(section.color, 1.25),
            section.color,
            _darkenColor(section.color, 0.9),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(rect);

      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);

      // Add subtle highlight on edge
      if (isHovered) {
        final highlightPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawArc(rect, startAngle, sweepAngle, false, highlightPaint);
      }

      // Draw thin line between slices for definition
      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      final lineX = sectionCenter.dx + radius * math.cos(startAngle);
      final lineY =
          sectionCenter.dy + radius * math.sin(startAngle) * tiltAngle;
      canvas.drawLine(sectionCenter, Offset(lineX, lineY), linePaint);

      startAngle += sweepAngle;
    }
  }

  Color _darkenColor(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      (color.red * factor).clamp(0, 255).toInt(),
      (color.green * factor).clamp(0, 255).toInt(),
      (color.blue * factor).clamp(0, 255).toInt(),
    );
  }

  Color _lightenColor(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      (color.red + (255 - color.red) * (factor - 1)).clamp(0, 255).toInt(),
      (color.green + (255 - color.green) * (factor - 1)).clamp(0, 255).toInt(),
      (color.blue + (255 - color.blue) * (factor - 1)).clamp(0, 255).toInt(),
    );
  }

  @override
  bool shouldRepaint(_Pie3DPainter oldDelegate) {
    return oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.animationValue != animationValue;
  }
}
