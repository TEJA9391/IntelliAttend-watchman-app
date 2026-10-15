import 'package:flutter/material.dart';

class Responsive {
  final BuildContext context;
  final MediaQueryData _mediaQuery;

  Responsive._(this.context) : _mediaQuery = MediaQuery.of(context);

  static Responsive of(BuildContext context) => Responsive._(context);

  double get screenWidth => _mediaQuery.size.width;
  double get screenHeight => _mediaQuery.size.height;
  double get shortestSide => _mediaQuery.size.shortestSide;

  bool get isSmallPhone => shortestSide < 360;
  bool get isMediumPhone => shortestSide >= 360 && shortestSide < 400;
  bool get isLargePhone => shortestSide >= 400 && shortestSide < 600;
  bool get isTablet => shortestSide >= 600;
  bool get isLandscape => screenWidth > screenHeight;

  double wp(double percent) => screenWidth * percent / 100;
  double hp(double percent) => screenHeight * percent / 100;

  double get paddingXS => wp(1.5);
  double get paddingS => wp(2.5);
  double get paddingM => wp(4);
  double get paddingL => wp(5);

  double get radiusS => wp(2);
  double get radiusM => wp(3);
  double get radiusL => wp(4);

  double get iconS => wp(4);
  double get iconM => wp(5);
  double get iconL => wp(6.5);

  double get fontSizeXS => wp(2.8);
  double get fontSizeS => wp(3.2);
  double get fontSizeM => wp(3.6);
  double get fontSizeL => wp(4.2);
  double get fontSizeXL => wp(5.2);
  double get fontSizeXXL => wp(6.5);

  double get spacingXS => wp(1);
  double get spacingS => wp(2);
  double get spacingM => wp(3);
  double get spacingL => wp(4);
  double get spacingXL => wp(5);

  int gridColumns({double maxItemWidth = 220}) {
    final available = screenWidth - paddingM * 2;
    final cols = (available / maxItemWidth).ceil();
    return cols.clamp(1, 6);
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, Responsive responsive) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = Responsive.of(context);
        return builder(context, responsive);
      },
    );
  }
}

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const ResponsiveWrapper({super.key, required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final constraint = maxWidth ?? (width > 600 ? 600.0 : width);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: constraint),
        child: child,
      ),
    );
  }
}
