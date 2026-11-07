import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/pairing_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/pairing_commands.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';

import 'real_stack.dart';
import 'runner_device.dart';
import 'stack_waiting.dart';

Future<RunnerDevice> startPairedRunner(
  WidgetTester tester, {
  required RealStack stack,
}) async {
  final RunnerDevice runner = await stack.startRunner(
    tester,
    deviceName: runnerDeviceName,
  );
  final node.StartedPairing started = await askNode(
    tester,
    () => stack.channel.execute(const node.StartPairingCommand()),
  );
  final node.PairingRequestScreen session = started.screen;
  await askNode(
    tester,
    () => runner.joinWithCode(
      serverAddress: stack.server.address,
      code: session.displayCode,
    ),
  );
  await askNode(
    tester,
    () => stack.channel.execute(
      node.ApprovePairingCommand(
        code: session.code,
        workspaceIds: <WorkspaceId>[stack.homeWorkspaceId],
      ),
    ),
  );
  await waitUntilNodeAgrees(
    tester,
    description: 'the runner join approved',
    check: runner.isApproved,
  );
  return runner;
}
