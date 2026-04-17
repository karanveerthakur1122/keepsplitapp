import 'package:flutter/material.dart';

class Responsive {
  Responsive._(this._size);

  factory Responsive.of(BuildContext context) =>
      Responsive._(MediaQuery.sizeOf(context));

  final Size _size;

  double get width => _size.width;
  double get height => _size.height;
  double get shortSide => _size.shortestSide;

  bool get isCompact => width < 600;
  bool get isMedium => width >= 600 && width < 840;
  bool get isExpanded => width >= 840;

  int get gridCrossAxisCount {
    if (width > 1200) return 5;
    if (width > 900) return 4;
    if (width > 600) return 3;
    return 2;
  }

  double get horizontalPadding {
    if (isExpanded) return 32;
    if (isMedium) return 20;
    return 12;
  }

  double get cardBorderRadius {
    if (isCompact) return 18;
    return 22;
  }

  double get gridSpacing {
    if (isCompact) return 10;
    return 14;
  }

  /// Adaptive value: returns [compact] on phones, [medium] on tablets, [expanded] on desktop.
  T adaptive<T>({required T compact, T? medium, required T expanded}) {
    if (isExpanded) return expanded;
    if (isMedium) return medium ?? expanded;
    return compact;
  }
}

extension ResponsiveContext on BuildContext {
  Responsive get responsive => Responsive.of(this);
}
