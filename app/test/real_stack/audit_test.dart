import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/audit_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/device_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/pairing_commands.dart'
    as node;
import 'package:agent_orchestration/presentation/audit_text.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/settings.dart';

import 'support/real_stack.dart';
import 'support/runner_device.dart';
import 'support/stack_pairing.dart';
import 'support/stack_settings.dart';
import 'support/stack_waiting.dart';

const String _intactTitle = 'The log is intact';
const String _rejectedRunnerName = 'stranger-runner';
const String _rejectedJoinEvent = '$_rejectedRunnerName asked to join';
const List<String> _eventsMadeInTheBackground = <String>[
  'Published the peer address of $appDeviceName',
  '$runnerDeviceName reported 0 of 1 slots busy',
];

Finder _findInAuditTab(String text) {
  return find.descendant(
    of: find.byType(AuditLogTab),
    matching: find.text(text),
  );
}

String _describeShownChain(node.AuditView audit) {
  return '${describeEntryCount(audit.entryCount)}. Each one is signed by '
      'the device that made it, and every device keeps the latest hash.';
}

String _readShownLatestHash(WidgetTester tester) {
  final Finder latest = find.descendant(
    of: find.byType(AuditLogTab),
    matching: find.textContaining('Latest '),
  );
  final Text latestText = tester.widget<Text>(latest);
  return latestText.textSpan!.toPlainText();
}

bool _isChainShown(WidgetTester tester, node.AuditView audit) {
  final Finder shownCount = _findInAuditTab(_describeShownChain(audit));
  if (shownCount.evaluate().isEmpty) {
    return false;
  }
  final String latestHash = 'Latest ${shortenIdentifier(audit.headHash)}';
  return _readShownLatestHash(tester) == latestHash;
}

Future<void> _rejectJoiningRunner(
  WidgetTester tester, {
  required RealStack stack,
}) async {
  final RunnerDevice stranger = await stack.startRunner(
    tester,
    deviceName: _rejectedRunnerName,
  );
  final node.StartedPairing started = await askNode(
    tester,
    () => stack.channel.execute(const node.StartPairingCommand()),
  );
  final node.PairingRequestScreen session = started.screen;
  await askNode(
    tester,
    () => stranger.joinWithCode(
      serverAddress: stack.server.address,
      code: session.displayCode,
    ),
  );
  await askNode(
    tester,
    () => stack.channel.execute(node.RejectPairingCommand(code: session.code)),
  );
}

Future<bool> _hasBackgroundEvents({required RealStack stack}) async {
  final node.AuditView audit = await stack.channel.execute(
    const node.ListAuditCommand(),
  );
  final Set<String> events = <String>{
    for (final node.AuditEntryView entry in audit.entries) entry.event,
  };
  return events.containsAll(_eventsMadeInTheBackground);
}

void main() {
  testWidgets(
    'test_audit_log_property_shown_chain_matches_the_node',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      await startPairedRunner(tester, stack: stack);
      await _rejectJoiningRunner(tester, stack: stack);
      await waitUntilNodeAgrees(
        tester,
        description: 'the background audit entries',
        check: () => _hasBackgroundEvents(stack: stack),
      );

      await openSettingsTab(
        tester,
        tabLabel: 'Audit log',
        expected: _findInAuditTab(_intactTitle),
      );
      final node.AuditView audit = await waitUntilScreenShowsNodeAnswer(
        tester,
        description: "the node's latest audit chain",
        question: () => stack.channel.execute(const node.ListAuditCommand()),
        isShown: (node.AuditView latest) => _isChainShown(tester, latest),
      );

      expect(audit.intact, isTrue);
      expect(audit.entries, hasLength(audit.entryCount));
      final node.AuditEntryView rejectedJoin = audit.entries.singleWhere(
        (node.AuditEntryView entry) => entry.event == _rejectedJoinEvent,
      );
      expect(
        _findInAuditTab(shortenIdentifier(rejectedJoin.deviceId.value)),
        findsOneWidget,
      );
      for (final node.AuditEntryView entry in audit.entries) {
        expect(_findInAuditTab(entry.event), findsWidgets);
        expect(_findInAuditTab(shortenIdentifier(entry.hash)), findsOneWidget);
      }
      await stack.close(tester);
    },
    skip: findRealStackSkipReason() != null,
    timeout: realStackTimeout,
  );
}
