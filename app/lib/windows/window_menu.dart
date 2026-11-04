import 'package:flutter/services.dart';

import 'package:agent_orchestration/windows/app_window_list.dart';
import 'package:agent_orchestration/windows/window_channel.dart';

const String openNewWindowMethod = 'openNewWindow';
const String reopenMethod = 'reopen';

void answerWindowMenu(MethodCall call, {required AppWindowList windowList}) {
  switch (call.method) {
    case openNewWindowMethod:
      windowList.openSectionWindow();
    case reopenMethod:
      windowList.reopen();
    default:
      throw MissingPluginException('No window menu item ${call.method}');
  }
}

void listenToWindowMenu(AppWindowList windowList) {
  windowChannel.setMethodCallHandler(
    (MethodCall call) async => answerWindowMenu(call, windowList: windowList),
  );
}
