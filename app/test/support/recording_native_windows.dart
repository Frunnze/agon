import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/windows/native_windows.dart';

final class RecordingOnTopSwitch implements OnTopSwitch {
  bool isKeptOnTop = false;
  int switchCount = 0;

  @override
  void keepOnTop() {
    isKeptOnTop = true;
    switchCount += 1;
  }

  @override
  void stopKeepingOnTop() {
    isKeptOnTop = false;
    switchCount += 1;
  }
}

final class RecordingNativeWindow extends RecordingOnTopSwitch
    implements NativeWindow {
  RecordingNativeWindow({required this.shape, required this.onClosed});

  final NativeWindowShape shape;
  final ClosedWindowListener onClosed;
  int frontRequests = 0;

  void closeByPerson() {
    onClosed(this);
  }

  @override
  Widget showContent(Widget content) => content;

  @override
  void bringToFront() {
    frontRequests += 1;
  }
}

final class RecordingNativeWindows implements NativeWindows {
  final List<RecordingNativeWindow> opened = <RecordingNativeWindow>[];

  @override
  NativeWindow openWindow({
    required NativeWindowShape shape,
    required ClosedWindowListener onClosed,
  }) {
    final RecordingNativeWindow window = RecordingNativeWindow(
      shape: shape,
      onClosed: onClosed,
    );
    opened.add(window);
    return window;
  }

  @override
  Widget arrangeWindows(List<Widget> windowViews) {
    final List<Widget> sideBySide = <Widget>[
      for (final Widget windowView in windowViews) Expanded(child: windowView),
    ];
    return Row(textDirection: TextDirection.ltr, children: sideBySide);
  }
}
