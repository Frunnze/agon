import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/account_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/device_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';

import 'package:agent_orchestration/screens/setup.dart';

import '../bridge/support/local_orchestration_server.dart';
import '../support/recording_runner_presence.dart';
import 'support/real_stack.dart';
import 'support/stack_setup_forms.dart';
import 'support/stack_waiting.dart';

const String _addressQueryStart = '?';

String _serverKeyPart(String peerAddress) {
  return peerAddress.split(_addressQueryStart).first;
}

Future<node.AccountSummary?> _createHostedRunnerAccount(
  NodeCommandChannel channel,
  LocalOrchestrationServer server,
) {
  return channel.execute(
    const node.CreateHostedAccountCommand(
      workspaceName: homeWorkspaceName,
      deviceName: appDeviceName,
      role: node.DeviceRole.clientAndRunner,
    ),
  );
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_start_app_on_node_property_existing_account_opens_tasks',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);

      await waitUntilShown(tester, find.text('No tasks yet'));
      final node.StatusView status = await askNode(
        tester,
        () => stack.channel.execute(const node.StatusCommand()),
      );

      expect(status.account?.device.id, stack.appDeviceId);
      expect(find.text(homeWorkspaceName), findsOneWidget);
      expect(stack.runnerPresence.isUntouched, isTrue);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_start_app_on_node_property_runner_account_stays_behind_at_start',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openPrepared(
        tester,
        prepareNode: _createHostedRunnerAccount,
      );

      await waitUntilShown(tester, find.text('No tasks yet'));
      expect(stack.runnerPresence.isKeptInBackground, isTrue);
      expect(stack.runnerPresence.loginItem.calls, <String>[registerCall]);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_setup_role_property_this_computer_becomes_the_server',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openForSetup(tester);
      await waitUntilShown(tester, find.text('Client only'));

      await createAccountThroughSetup(tester, roleTitle: 'Client only');

      expect(find.text(firstWorkspaceName), findsOneWidget);
      final node.StatusView status = await askNode(
        tester,
        () => stack.channel.execute(const node.StatusCommand()),
      );
      final List<node.WorkspaceView> workspaces = await askNode(
        tester,
        () => stack.channel.execute(const node.ListWorkspacesCommand()),
      );
      final String hostedAddress = status.hostedServerAddress ?? '';
      expect(status.account?.device.role, node.DeviceRole.client);
      expect(status.serverReachable, isTrue);
      expect(hostedAddress, startsWith('peer://'));
      expect(status.serverAddress, isNot(stack.server.address));
      expect(workspaces.single.workspace.name, firstWorkspaceName);
      expect(
        _serverKeyPart(workspaces.single.workspace.appServerAddress),
        _serverKeyPart(hostedAddress),
      );

      await tapAndWait(
        tester,
        find.text('Done'),
        expected: find.text('No tasks yet'),
      );
      expect(stack.runnerPresence.isUntouched, isTrue);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'test_start_app_on_node_property_runner_setup_keeps_running_behind',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openForSetup(tester);
      await waitUntilShown(tester, find.text('Client and runner'));

      await createAccountThroughSetup(tester, roleTitle: 'Client and runner');

      expect(find.textContaining('stays in the menu bar'), findsOneWidget);
      await waitUntilTrue(
        tester,
        description: 'the runner to stay in the menu bar and start at login',
        isReached: () => stack.runnerPresence.isKeptInBackground,
      );
      final node.StatusView status = await askNode(
        tester,
        () => stack.channel.execute(const node.StatusCommand()),
      );
      expect(status.account?.device.role, node.DeviceRole.clientAndRunner);
      expect(stack.runnerPresence.loginItem.calls, <String>[registerCall]);
      expect(stack.runnerPresence.trayPresence.calls, <String>[
        stayInTrayCall,
      ]);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
