import 'dart:async';

import 'package:flutter/src/widgets/_window.dart';
import 'package:flutter/src/widgets/_window_macos.dart';
import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/windows/native_windows.dart';
import 'package:agent_orchestration/windows/window_channel.dart';

const String _keepOnTopMethod = 'keepOnTop';
const String _stopKeepingOnTopMethod = 'stopKeepingOnTop';
const String _windowArgument = 'window';

final class FlutterNativeWindows implements NativeWindows {
  const FlutterNativeWindows();

  @override
  NativeWindow openWindow({
    required NativeWindowShape shape,
    required ClosedWindowListener onClosed,
  }) {
    return FlutterNativeWindow(shape: shape, onClosed: onClosed);
  }

  @override
  Widget arrangeWindows(List<Widget> windowViews) {
    return ViewCollection(views: windowViews);
  }
}

final class FlutterNativeWindow
    with RegularWindowControllerDelegate
    implements NativeWindow {
  FlutterNativeWindow({
    required NativeWindowShape shape,
    required ClosedWindowListener onClosed,
  }) : _onClosed = onClosed {
    _controller = RegularWindowController(
      size: shape.size,
      constraints: BoxConstraints(
        minWidth: shape.smallestSize.width,
        minHeight: shape.smallestSize.height,
      ),
      title: shape.title,
      delegate: this,
    );
  }

  final ClosedWindowListener _onClosed;
  late final RegularWindowController _controller;

  @override
  Widget showContent(Widget content) {
    return RegularWindow(controller: _controller, child: content);
  }

  @override
  void bringToFront() {
    _controller.setMinimized(false);
    _controller.activate();
  }

  @override
  void keepOnTop() {
    _sendLevel(_keepOnTopMethod);
  }

  @override
  void stopKeepingOnTop() {
    _sendLevel(_stopKeepingOnTopMethod);
  }

  @override
  void onWindowDestroyed() {
    super.onWindowDestroyed();
    _onClosed(this);
    WidgetsBinding.instance.addPostFrameCallback(_disposeController);
  }

  void _disposeController(Duration _) {
    _controller.dispose();
  }

  void _sendLevel(String method) {
    final Object controller = _controller;
    if (controller is! WindowControllerMacOS) {
      throw UnsupportedError('Keeping a window on top needs macOS');
    }

    final int windowAddress = controller.windowHandle.address;
    unawaited(
      windowChannel.invokeMethod<void>(method, <String, Object>{
        _windowArgument: windowAddress,
      }),
    );
  }
}
