import 'package:flutter/widgets.dart';

final class NativeWindowShape {
  const NativeWindowShape({
    required this.title,
    required this.size,
    required this.smallestSize,
  });

  final String title;
  final Size size;
  final Size smallestSize;
}

abstract interface class OnTopSwitch {
  void keepOnTop();

  void stopKeepingOnTop();
}

abstract interface class NativeWindow implements OnTopSwitch {
  Widget showContent(Widget content);

  void bringToFront();
}

typedef ClosedWindowListener = void Function(NativeWindow closedWindow);

abstract interface class NativeWindows {
  NativeWindow openWindow({
    required NativeWindowShape shape,
    required ClosedWindowListener onClosed,
  });

  Widget arrangeWindows(List<Widget> windowViews);
}
