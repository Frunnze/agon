import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/commands/device_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/runner_commands.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';

import 'real_stack.dart';

Future<WorkspaceId> fetchNodeWorkspaceId({
  required RealStack stack,
  required String workspaceName,
}) async {
  final List<node.WorkspaceView> workspaces = await stack.channel.execute(
    const node.ListWorkspacesCommand(),
  );
  final node.WorkspaceView named = workspaces.singleWhere(
    (node.WorkspaceView view) => view.workspace.name == workspaceName,
  );
  return named.workspace.id;
}

Future<node.DeviceView> fetchNodeDevice({
  required RealStack stack,
  required String deviceName,
}) async {
  final List<node.DeviceView> devices = await stack.channel.execute(
    const node.ListDevicesCommand(),
  );
  return devices.singleWhere(
    (node.DeviceView view) => view.device.name == deviceName,
  );
}

Future<node.RunnerView?> findNodeRunner({
  required RealStack stack,
  required String deviceName,
}) async {
  final node.RunnersView runners = await stack.channel.execute(
    node.ListRunnersCommand(workspaceId: stack.homeWorkspaceId),
  );
  for (final node.RunnerView runner in runners.runners) {
    if (runner.deviceName == deviceName) {
      return runner;
    }
  }
  return null;
}
