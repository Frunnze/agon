import 'dart:io';

import 'package:flutter/services.dart';

import 'package:agent_orchestration/background/channel_presence.dart';
import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/background/xdg_autostart_login_item.dart';

const MethodChannel _runnerPresenceChannel = MethodChannel(
  runnerPresenceChannelName,
);
const ChannelTrayPresence _channelTrayPresence = ChannelTrayPresence(
  channel: _runnerPresenceChannel,
);

RunnerPresence? buildPlatformRunnerPresence(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.macOS:
      return const RunnerPresence(
        loginItem: ChannelLoginItem(channel: _runnerPresenceChannel),
        trayPresence: _channelTrayPresence,
      );
    case TargetPlatform.linux:
      return RunnerPresence(
        loginItem: XdgAutostartLoginItem(
          environment: Platform.environment,
          executablePath: Platform.resolvedExecutable,
        ),
        trayPresence: _channelTrayPresence,
      );
    case TargetPlatform.windows:
    case TargetPlatform.iOS:
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
      return null;
  }
}
