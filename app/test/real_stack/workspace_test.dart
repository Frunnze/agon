import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/commands/device_commands.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import 'support/real_stack.dart';
import 'support/stack_navigation.dart';
import 'support/stack_node_reads.dart';
import 'support/stack_pairing.dart';
import 'support/stack_waiting.dart';
import 'support/stack_workspaces.dart';

const String _secondWorkspaceName = 'lab';

Future<bool> _isRunnerInWorkspace({
  required RealStack stack,
  required WorkspaceId workspaceId,
}) async {
  final node.DeviceView runner = await fetchNodeDevice(
    stack: stack,
    deviceName: runnerDeviceName,
  );
  return runner.device.workspaces.contains(workspaceId);
}

Future<List<node.WorkspaceView>> _listNodeWorkspaces(
  WidgetTester tester, {
  required RealStack stack,
}) {
  return askNode(
    tester,
    () => stack.channel.execute(const node.ListWorkspacesCommand()),
  );
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_workspace_switcher_property_created_workspace_can_be_switched',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      await waitUntilShown(tester, findRailWorkspaceName(homeWorkspaceName));

      await createWorkspaceThroughSwitcher(
        tester,
        workspaceName: _secondWorkspaceName,
      );
      await waitUntilShown(
        tester,
        findRailWorkspaceName(_secondWorkspaceName),
      );
      final List<node.WorkspaceView> workspaces = await _listNodeWorkspaces(
        tester,
        stack: stack,
      );
      final node.WorkspaceView created = workspaces.singleWhere(
        (node.WorkspaceView view) =>
            view.workspace.name == _secondWorkspaceName,
      );
      final node.WorkspaceView home = workspaces.singleWhere(
        (node.WorkspaceView view) =>
            view.workspace.id == stack.homeWorkspaceId,
      );
      expect(
        created.workspace.appServerAddress,
        home.workspace.appServerAddress,
      );
      expect(
        stack.dependencies.workspaceRepository.currentWorkspace().id,
        created.workspace.id,
      );

      await switchWorkspaceThroughSwitcher(
        tester,
        workspaceName: homeWorkspaceName,
      );
      await waitUntilShown(tester, findRailWorkspaceName(homeWorkspaceName));
      final List<node.WorkspaceView> afterSwitch = await _listNodeWorkspaces(
        tester,
        stack: stack,
      );

      expect(findRailWorkspaceName(_secondWorkspaceName), findsNothing);
      expect(
        afterSwitch.map((node.WorkspaceView view) => view.workspace.id),
        unorderedEquals(<WorkspaceId>[
          stack.homeWorkspaceId,
          created.workspace.id,
        ]),
      );
      expect(
        stack.dependencies.workspaceRepository.currentWorkspace().id,
        stack.homeWorkspaceId,
      );
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_workspace_settings_property_add_and_remove_change_membership',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      await startPairedRunner(tester, stack: stack);
      await createWorkspaceThroughSwitcher(
        tester,
        workspaceName: _secondWorkspaceName,
      );
      final WorkspaceId secondWorkspaceId = await askNode(
        tester,
        () => fetchNodeWorkspaceId(
          stack: stack,
          workspaceName: _secondWorkspaceName,
        ),
      );

      await openRailSection(tester, label: 'Settings', pageTitle: 'Settings');
      await waitUntilShown(
        tester,
        find.text('Devices in $_secondWorkspaceName'),
      );
      expect(find.text(runnerDeviceName), findsNothing);
      await tapWhenShown(tester, find.text('Add one of your devices'));
      await tapWhenShown(tester, find.widgetWithText(AppButton, 'Add'));
      await waitUntilGone(
        tester,
        find.text('Add a device to $_secondWorkspaceName'),
      );
      await waitUntilShown(tester, find.text(runnerDeviceName));
      await waitUntilNodeAgrees(
        tester,
        description: 'the runner in the second workspace',
        check: () =>
            _isRunnerInWorkspace(stack: stack, workspaceId: secondWorkspaceId),
      );

      await tapWhenShown(tester, find.widgetWithText(AppButton, 'Remove'));
      await waitUntilGone(tester, find.text(runnerDeviceName));
      final node.DeviceView removed = await askNode(
        tester,
        () => fetchNodeDevice(stack: stack, deviceName: runnerDeviceName),
      );

      expect(removed.device.workspaces, isNot(contains(secondWorkspaceId)));
      expect(removed.device.workspaces, contains(stack.homeWorkspaceId));
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
