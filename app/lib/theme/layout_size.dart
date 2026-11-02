import 'package:flutter/widgets.dart';

enum LayoutSize {
  compact,
  medium,
  large;

  static const double mediumMinimumWidth = 768;
  static const double largeMinimumWidth = 1024;

  static LayoutSize forWidth(double width) {
    if (width >= largeMinimumWidth) {
      return LayoutSize.large;
    }
    if (width >= mediumMinimumWidth) {
      return LayoutSize.medium;
    }
    return LayoutSize.compact;
  }

  static LayoutSize of(BuildContext context) {
    return forWidth(MediaQuery.sizeOf(context).width);
  }

  bool get isCompact => this == LayoutSize.compact;

  bool get isLarge => this == LayoutSize.large;
}
