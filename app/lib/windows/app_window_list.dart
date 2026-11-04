import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/product_name.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/windows/app_window_page.dart';
import 'package:agent_orchestration/windows/native_windows.dart';
import 'package:agent_orchestration/windows/open_app_window.dart';
import 'package:agent_orchestration/windows/run_window_opener.dart';

const NativeWindowShape mainWindowShape = NativeWindowShape(
  title: productName,
  size: Size(1280, 800),
  smallestSize: Size(640, 480),
);
const Size runWindowSize = Size(480, 720);
const Size smallestRunWindowSize = Size(360, 420);

final class AppWindowList extends ChangeNotifier implements RunWindowOpener {
  AppWindowList({required NativeWindows nativeWindows})
    : _nativeWindows = nativeWindows;

  final NativeWindows _nativeWindows;
  List<OpenAppWindow> _windows = const <OpenAppWindow>[];

  List<OpenAppWindow> get windows => _windows;

  void openStartingWindow() {
    _open(page: const StartingWindowPage(), shape: mainWindowShape);
  }

  void openSectionWindow() {
    final AppNavigation navigation = AppNavigation(
      initialRoute: const SectionRoute(AppSection.tasks),
    );
    _open(page: SectionWindowPage(navigation), shape: mainWindowShape);
  }

  @override
  void openRunWindow({required RunId runId, required String title}) {
    final NativeWindowShape shape = NativeWindowShape(
      title: title,
      size: runWindowSize,
      smallestSize: smallestRunWindowSize,
    );
    final AppNavigation navigation = AppNavigation.limitedToRunPages(
      runId: runId,
    );
    _open(page: RunWindowPage(navigation), shape: shape);
  }

  void reopen() {
    if (_windows.isEmpty) {
      openStartingWindow();
      return;
    }
    _windows.first.nativeWindow.bringToFront();
  }

  void _open({required AppWindowPage page, required NativeWindowShape shape}) {
    final NativeWindow nativeWindow = _nativeWindows.openWindow(
      shape: shape,
      onClosed: _forget,
    );
    final OpenAppWindow opened = OpenAppWindow(
      page: page,
      nativeWindow: nativeWindow,
    );

    _windows = List<OpenAppWindow>.unmodifiable(<OpenAppWindow>[
      ..._windows,
      opened,
    ]);
    notifyListeners();
  }

  void _forget(NativeWindow closedWindow) {
    _windows = List<OpenAppWindow>.unmodifiable(<OpenAppWindow>[
      for (final OpenAppWindow window in _windows)
        if (!identical(window.nativeWindow, closedWindow)) window,
    ]);
    notifyListeners();
  }
}
