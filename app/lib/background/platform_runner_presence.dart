import 'dart:io';

import 'package:flutter/services.dart';

import 'package:agent_orchestration/background/channel_presence.dart';
import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/background/xdg_autostart_login_item.dart';
import 'package:agent_orchestration/storage/shared_preferences_start_at_login_choice_store.dart';

const MethodChannel _runnerPresenceChannel = MethodChannel(
  runnerPresenceChannelName,
);
const ChannelTrayPresence _channelTrayPresence = ChannelTrayPresence(
  channel: _runnerPresenceChannel,
);
const SharedPreferencesStartAtLoginChoiceStore _startAtLoginChoiceStore =
    SharedPreferencesStartAtLoginChoiceStore();

RunnerPresence? buildPlatformRunnerPresence(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.macOS:
      return RunnerPresence(
        loginItem: const ChannelLoginItem(channel: _runnerPresenceChannel),
        trayPresence: _channelTrayPresence,
        startAtLoginChoiceStore: _startAtLoginChoiceStore,
      );
    case TargetPlatform.linux:
      return RunnerPresence(
        loginItem: XdgAutostartLoginItem(
          environment: Platform.environment,
          executablePath: Platform.resolvedExecutable,
        ),
        trayPresence: _channelTrayPresence,
        startAtLoginChoiceStore: _startAtLoginChoiceStore,
      );
    case TargetPlatform.windows:
    case TargetPlatform.iOS:
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
      return null;
  }
}
