import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/account_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/pairing_commands.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';

import '../bridge/support/local_orchestration_server.dart';
import '../support/server_group_repositories.dart';
import 'support/real_stack.dart';
import 'support/runner_node_process.dart';
import 'support/stack_settings.dart';
import 'support/stack_waiting.dart';

const String _backupDeviceName = 'studio-mac';
const String _clientRole = 'client';
const String _approvedState = 'approved';
const String _activeText =
    'This device · Active server · relays messages and keeps the run queue. '
    'It sees only encrypted data.';
const String _backupText =
    'Backup · keeps a live copy and takes over when the active server is '
    'off.';
const String _activeHint = 'This computer is the active server.';

Future<RunnerNodeProcess> _startBackupNode(RealStack stack) async {
  final Directory nodeDirectory = Directory(
    '${stack.workingDirectory.path}/$_backupDeviceName',
  )..createSync();
  final int appServerPort = await findFreePort();
  final RunnerNodeProcess backupNode = await RunnerNodeProcess.start(
    configuration: <String, Object?>{
      'data_directory': nodeDirectory.path,
      'identity_store': 'file',
      'peer_relay': 'disabled',
      'runner': 'off',
      'app_server_port': appServerPort,
    },
    environment: const <String, String>{},
  );
  addTearDown(backupNode.stop);
  return backupNode;
}

Future<void> _pairBackupNode(
  RealStack stack,
  RunnerNodeProcess backupNode,
) async {
  final node.StatusView status = await stack.channel.execute(
    const node.StatusCommand(),
  );
  final node.StartedPairing started = await stack.channel.execute(
    const node.StartPairingCommand(),
  );
  final node.PairingRequestScreen session = started.screen;
  await backupNode.run(<String, Object?>{
    'command': 'join_with_code',
    'server_address': status.hostedServerAddress,
    'code': session.displayCode,
    'device_name': _backupDeviceName,
    'role': _clientRole,
  });
  await stack.channel.execute(
    node.ApprovePairingCommand(
      code: session.code,
      workspaceIds: <WorkspaceId>[stack.homeWorkspaceId],
    ),
  );
  final Object? joined = await backupNode.run(<String, Object?>{
    'command': 'join_status',
  });
  if (joined is! Map<String, Object?> || joined['state'] != _approvedState) {
    throw StateError('The backup device was not approved: $joined');
  }
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_start_server_backup_property_settings_show_the_backup_device',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithHostedAccount(tester);
      final RunnerNodeProcess backupNode = await askNode(
        tester,
        () => _startBackupNode(stack),
      );
      await askNode(tester, () => _pairBackupNode(stack, backupNode));
      await askNode(
        tester,
        () => backupNode.run(<String, Object?>{
          'command': 'start_server_backup',
        }),
      );

      await openSettingsTab(
        tester,
        tabLabel: 'Server',
        expected: find.text('App server'),
      );
      await waitUntilShown(tester, find.text(_backupDeviceName));
      await waitUntilShown(tester, find.text(_backupText));

      expect(find.text(_activeText), findsOneWidget);
      expect(find.text(_activeHint), findsOneWidget);
      final SwitchToggle toggle = tester.widget<SwitchToggle>(
        findServerBackupToggle(),
      );
      expect(toggle.value, isTrue);
      expect(toggle.onChanged, isNull);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
