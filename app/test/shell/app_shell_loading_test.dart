import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_shell.dart';
import 'package:agent_orchestration/shell/side_rail.dart';

import '../bridge/support/node_json_primitives.dart';
import '../bridge/support/random_catalog_json.dart';
import '../data/node_backed/support/node_backed_harness.dart';
import '../data/node_backed/support/simulated_device_node.dart';
import '../data/node_backed/support/simulated_work_node.dart';
import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';

NodeBackedDeviceRepository _buildUnloadedDevices(Random random) {
  final SimulatedDeviceNode simulated = SimulatedDeviceNode(
    thisDeviceId: randomDeviceIdText(random),
  );
  final WireRecord thisDevice = randomDeviceJson(random);
  thisDevice['id'] = simulated.thisDeviceId;
  simulated.devices[simulated.thisDeviceId] = thisDevice;
  return NodeBackedDeviceRepository(
    channel: buildSimulatedChannel(simulated.answer),
  );
}

PairingOutcome _buildClientOutcome(Random random) {
  return PairingOutcome(
    deviceName: 'device-${random.nextInt(1000)}',
    role: DeviceRole.client,
    workspaceNames: <String>['workspace-${random.nextInt(1000)}'],
    runnerLabels: const <String>[],
    approverName: null,
  );
}

void main() {
  testWidgets('test_app_shell_property_setup_exit_waits_for_this_device', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(3141);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeBackedDeviceRepository devices = _buildUnloadedDevices(random);
      final AppDependencies dependencies = replaceRepositories(
        buildDependenciesWithoutTasks(),
        deviceRepository: devices,
      );
      await pumpApp(
        tester,
        size: desktopSize,
        route: PairingDoneRoute(_buildClientOutcome(random)),
        dependencies: dependencies,
      );

      await tapVisible(tester, find.text('Done'));
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(accountLoadingText), findsOneWidget);

      final Future<void> loading = devices.load();
      await pumpFrames(tester);
      await loading;
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(accountLoadingText), findsNothing);
      expect(find.byType(SideRail), findsOneWidget);
    }
  });
}
