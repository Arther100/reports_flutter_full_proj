import 'package:flutter/material.dart';

/// Responsive layout helper for dynamic UI across all devices
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  static const int mobileBreakpoint = 600;
  static const int tabletBreakpoint = 900;
  static const int desktopBreakpoint = 1200;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint &&
      MediaQuery.of(context).size.width < desktopBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  static int getGridCrossAxisCount(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 4,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  static double getGridChildAspectRatio(
    BuildContext context, {
    double mobile = 1.5,
    double tablet = 1.6,
    double desktop = 1.8,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isDesktop(context)) return const EdgeInsets.all(24);
    if (isTablet(context)) return const EdgeInsets.all(16);
    return const EdgeInsets.all(12);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= desktopBreakpoint) {
          return desktop ?? tablet ?? mobile;
        } else if (constraints.maxWidth >= mobileBreakpoint) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
  }
}

/// Responsive Grid that adapts to screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;
  final double childAspectRatio;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 4,
    this.spacing = 12,
    this.childAspectRatio = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns;
        double ratio = childAspectRatio;

        if (constraints.maxWidth >= ResponsiveLayout.desktopBreakpoint) {
          columns = desktopColumns;
          ratio = childAspectRatio * 1.2;
        } else if (constraints.maxWidth >= ResponsiveLayout.mobileBreakpoint) {
          columns = tabletColumns;
          ratio = childAspectRatio * 1.1;
        } else {
          columns = mobileColumns;
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          childAspectRatio: ratio,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          children: children,
        );
      },
    );
  }
}

/// Responsive Row/Column that switches based on screen size
class ResponsiveRowColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;
  final bool forceColumn;

  const ResponsiveRowColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.spacing = 12,
    this.forceColumn = false,
  });

  @override
  Widget build(BuildContext context) {
    if (forceColumn || ResponsiveLayout.isMobile(context)) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: _addSpacing(children, isVertical: true),
      );
    }

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: _addSpacing(
        children.map((c) => Expanded(child: c)).toList(),
        isVertical: false,
      ),
    );
  }

  List<Widget> _addSpacing(List<Widget> widgets, {required bool isVertical}) {
    if (widgets.isEmpty) return widgets;

    final spacer = isVertical
        ? SizedBox(height: spacing)
        : SizedBox(width: spacing);

    final result = <Widget>[];
    for (int i = 0; i < widgets.length; i++) {
      result.add(widgets[i]);
      if (i < widgets.length - 1) {
        result.add(spacer);
      }
    }
    return result;
  }
}

/// Screen size aware builder
class ScreenSizeBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    ScreenSize size,
    BoxConstraints constraints,
  )
  builder;

  const ScreenSizeBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        ScreenSize size;
        if (constraints.maxWidth >= ResponsiveLayout.desktopBreakpoint) {
          size = ScreenSize.desktop;
        } else if (constraints.maxWidth >= ResponsiveLayout.mobileBreakpoint) {
          size = ScreenSize.tablet;
        } else {
          size = ScreenSize.mobile;
        }
        return builder(context, size, constraints);
      },
    );
  }
}

enum ScreenSize { mobile, tablet, desktop }

/// Responsive text that scales with screen size
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final double mobileSize;
  final double tabletSize;
  final double desktopSize;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ResponsiveText(
    this.text, {
    super.key,
    this.style,
    this.mobileSize = 14,
    this.tabletSize = 16,
    this.desktopSize = 18,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    double fontSize;
    if (ResponsiveLayout.isDesktop(context)) {
      fontSize = desktopSize;
    } else if (ResponsiveLayout.isTablet(context)) {
      fontSize = tabletSize;
    } else {
      fontSize = mobileSize;
    }

    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(fontSize: fontSize),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
