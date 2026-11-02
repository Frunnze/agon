import 'package:flutter/services.dart';

import 'package:agent_orchestration/background/login_item.dart';
import 'package:agent_orchestration/background/tray_presence.dart';

const String runnerPresenceChannelName = 'agent_orchestration/runner_presence';
const String registerLoginItemMethod = 'registerLoginItem';
const String unregisterLoginItemMethod = 'unregisterLoginItem';
const String stayInTrayMethod = 'stayInTray';
const String leaveTrayMethod = 'leaveTray';
const String stayInTrayProblem =
    'could not keep the app running in the menu bar or tray';
const String leaveTrayProblem =
    'could not take the app out of the menu bar or tray';

Future<void> _callPresenceMethod({
  required MethodChannel channel,
  required String method,
  required String problem,
}) async {
  try {
    await channel.invokeMethod<void>(method);
  } on PlatformException catch (failure, stackTrace) {
    final String reason = failure.message ?? failure.code;
    Error.throwWithStackTrace(StateError('$problem: $reason'), stackTrace);
  } on MissingPluginException catch (failure, stackTrace) {
    final String reason = failure.message ?? method;
    Error.throwWithStackTrace(StateError('$problem: $reason'), stackTrace);
  }
}

final class ChannelLoginItem implements LoginItem {
  const ChannelLoginItem({required this.channel});

  final MethodChannel channel;

  @override
  Future<void> register() {
    return _callPresenceMethod(
      channel: channel,
      method: registerLoginItemMethod,
      problem: startAtLoginProblem,
    );
  }

  @override
  Future<void> unregister() {
    return _callPresenceMethod(
      channel: channel,
      method: unregisterLoginItemMethod,
      problem: stopStartingAtLoginProblem,
    );
  }
}

final class ChannelTrayPresence implements TrayPresence {
  const ChannelTrayPresence({required this.channel});

  final MethodChannel channel;

  @override
  Future<void> stayInTray() {
    return _callPresenceMethod(
      channel: channel,
      method: stayInTrayMethod,
      problem: stayInTrayProblem,
    );
  }

  @override
  Future<void> leaveTray() {
    return _callPresenceMethod(
      channel: channel,
      method: leaveTrayMethod,
      problem: leaveTrayProblem,
    );
  }
}
