import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

final class AgentLoginPointer {
  const AgentLoginPointer({required this.hint, required this.onConnect});

  final String hint;
  final VoidCallback? onConnect;
}

AgentLoginPointer? pointToAgentLogin({
  required String? reason,
  required DeviceId? runner,
  required DeviceRepository deviceRepository,
  required AppNavigation navigation,
}) {
  if (reason == null || runner == null || !isAgentLoginProblem(reason)) {
    return null;
  }

  final DeviceId thisDevice = deviceRepository.currentDevice().id;
  if (runner == thisDevice) {
    return AgentLoginPointer(
      hint: thisComputerLoginHint,
      onConnect: () => navigation.openRoute(RunnerDetailRoute(thisDevice)),
    );
  }
  final DeviceNames deviceNames = DeviceNames(deviceRepository.listDevices());
  return AgentLoginPointer(
    hint: describeOtherRunnerLoginHint(deviceNames.describeDevice(runner)),
    onConnect: null,
  );
}

List<Widget> describeAgentLoginPointer(AgentLoginPointer? pointer) {
  if (pointer == null) {
    return const <Widget>[];
  }
  return <Widget>[MutedNote(pointer.hint)];
}

List<Widget> offerAgentLoginConnection(AgentLoginPointer? pointer) {
  final VoidCallback? onConnect = pointer?.onConnect;
  if (onConnect == null) {
    return const <Widget>[];
  }
  return <Widget>[
    AppButton.secondary(label: connectClaudeCodeLabel, onPressed: onConnect),
  ];
}
