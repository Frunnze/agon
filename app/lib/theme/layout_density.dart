import 'package:flutter/material.dart';

enum LayoutDensity {
  dense,
  touch;

  static LayoutDensity forPlatform(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return LayoutDensity.dense;
      case TargetPlatform.iOS:
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return LayoutDensity.touch;
    }
  }

  static LayoutDensity of(BuildContext context) {
    return forPlatform(Theme.of(context).platform);
  }

  bool get isTouch => this == LayoutDensity.touch;
}
