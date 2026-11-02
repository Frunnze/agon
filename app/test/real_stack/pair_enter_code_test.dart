import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/account_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/device_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/commands/pairing_commands.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';
import 'package:agent_orchestration/screens/pairing/fingerprint_words.dart';

import 'support/real_stack.dart';
import 'support/runner_device.dart';
import 'support/stack_setup_forms.dart';
import 'support/stack_waiting.dart';

const String _hostDeviceName = 'desk';

Future<Result> _askHost<Result>(
  RunnerDevice host,
  NodeCommand<Result> command,
) async {
  final Object? okValue = await host.node.run(encodeNodeCommand(command));
  return command.decodeReply(okValue);
}

Future<node.JoiningDevice?> _findJoiningDevice({
  required RunnerDevice host,
  required String code,
}) async {
  final node.PairingRequestScreen session = await _askHost(
    host,
    node.PairingRequestCommand(code: code),
  );
  return session.joining;
}

Future<bool> _hasJoiningDevice({
  required RunnerDevice host,
  required String code,
}) async {
  final node.JoiningDevice? joining = await _findJoiningDevice(
    host: host,
    code: code,
  );
  return joining != null;
}

void main() {
  testWidgets(
    'test_pair_enter_code_property_code_alone_finds_the_host_and_pairs',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openForSetup(tester);
      final RunnerDevice host = await stack.startRunner(
        tester,
        deviceName: _hostDeviceName,
      );
      final node.AccountSummary hostAccount = await askNode(
        tester,
        () => _askHost(
          host,
          const node.CreateHostedAccountCommand(
            workspaceName: homeWorkspaceName,
            deviceName: _hostDeviceName,
            role: node.DeviceRole.client,
          ),
        ),
      );
      final node.PairingRequestScreen session = await askNode(
        tester,
        () => _askHost(host, const node.StartPairingCommand()),
      );

      await tapWhenShown(tester, find.text('Client only'));
      await tapAndWait(
        tester,
        find.text('Continue'),
        expected: find.text('Enter the pairing code'),
      );
      await enterPairingCodeThroughSetup(
        tester,
        code: session.displayCode,
        submitLabel: 'Pair this Mac',
      );
      await waitUntilNodeAgrees(
        tester,
        description: 'the app asking to join',
        check: () => _hasJoiningDevice(host: host, code: session.code),
      );
      final node.JoiningDevice? joining = await askNode(
        tester,
        () => _findJoiningDevice(host: host, code: session.code),
      );
      await waitUntilShown(tester, find.byType(FingerprintWords));
      expect(
        tester.widget<FingerprintWords>(find.byType(FingerprintWords)).words,
        joining?.fingerprintWords,
      );
      await askNode(
        tester,
        () => _askHost(
          host,
          node.ApprovePairingCommand(
            code: session.code,
            workspaceIds: <WorkspaceId>[hostAccount.workspaces.single.id],
          ),
        ),
      );
      await waitUntilShown(tester, find.text('Paired'));

      final String appDeviceName = suggestDeviceName(Platform.localHostname);
      final node.StatusView status = await askNode(
        tester,
        () => stack.channel.execute(const node.StatusCommand()),
      );
      final List<node.DeviceView> hostDevices = await askNode(
        tester,
        () => _askHost(host, const node.ListDevicesCommand()),
      );
      final node.DeviceView paired = hostDevices.singleWhere(
        (node.DeviceView view) => view.device.name == appDeviceName,
      );

      expect(find.text('Approved by'), findsOneWidget);
      expect(find.text(_hostDeviceName), findsOneWidget);
      expect(find.text(homeWorkspaceName), findsOneWidget);
      expect(status.account?.device.name, appDeviceName);
      expect(paired.device.approvedBy, hostAccount.device.id);
      expect(paired.device.workspaces, <WorkspaceId>[
        hostAccount.workspaces.single.id,
      ]);
      await stack.close(tester);
    },
    skip: findRealStackSkipReason() != null,
    timeout: realStackTimeout,
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
