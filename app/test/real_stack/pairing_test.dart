import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/commands/device_commands.dart'
    as node;
import 'package:agent_orchestration/screens/pairing/fingerprint_words.dart';

import 'support/real_stack.dart';
import 'support/runner_device.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';

const String _secondRunnerName = 'second-runner';
const String _rejectedState = 'rejected';

Future<String> _showPairingCode(WidgetTester tester) async {
  await openYourDevices(tester);
  await tapAndWait(
    tester,
    find.text('Add device'),
    expected: findShownPairingCode(),
  );
  return readShownPairingCode(tester);
}

Future<List<String>> _joinAndOpenRequest(
  WidgetTester tester, {
  required RealStack stack,
  required RunnerDevice runner,
  required String code,
}) async {
  await askNode(
    tester,
    () => runner.joinWithCode(serverAddress: stack.server.address, code: code),
  );
  await tapAndWait(
    tester,
    find.text('Check ${runner.deviceName}'),
    expected: findPageTitle('Approve ${runner.deviceName}?'),
  );
  return askNode(tester, runner.readJoinWords);
}

List<String> _readShownWords(WidgetTester tester) {
  return tester.widget<FingerprintWords>(find.byType(FingerprintWords)).words;
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_pair_show_code_property_cancel_ends_the_code',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final RunnerDevice runner = await stack.startRunner(
        tester,
        deviceName: runnerDeviceName,
      );

      final String code = await _showPairingCode(tester);
      expect(find.text('Waiting for the new device'), findsOneWidget);
      await tapWhenShown(tester, find.text('Cancel'));
      await waitUntilGone(tester, findPageTitle('Add a device'));
      final String? joinProblem = await askNode(
        tester,
        () => runner.readJoinProblem(
          serverAddress: stack.server.address,
          code: code,
        ),
      );

      expect(joinProblem, isNotNull);
      expect(findPageTitle('Your devices'), findsOneWidget);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_pair_approve_property_matching_words_pair_and_reject_ends',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final RunnerDevice runner = await stack.startRunner(
        tester,
        deviceName: runnerDeviceName,
      );

      final String code = await _showPairingCode(tester);
      final List<String> joinWords = await _joinAndOpenRequest(
        tester,
        stack: stack,
        runner: runner,
        code: code,
      );
      expect(_readShownWords(tester), joinWords);
      expect(joinWords, hasLength(4));
      await tapWhenShown(tester, find.text('Approve'));
      await waitUntilGone(tester, findPageTitle('Approve $runnerDeviceName?'));
      await waitUntilShown(tester, find.text(runnerDeviceName));
      await waitUntilNodeAgrees(
        tester,
        description: 'the runner join approved',
        check: runner.isApproved,
      );
      final List<node.DeviceView> devices = await askNode(
        tester,
        () => stack.channel.execute(const node.ListDevicesCommand()),
      );
      expect(
        devices.map((node.DeviceView view) => view.device.name),
        contains(runnerDeviceName),
      );

      final RunnerDevice secondRunner = await stack.startRunner(
        tester,
        deviceName: _secondRunnerName,
      );
      await tapAndWait(
        tester,
        find.text('Add device'),
        expected: findShownPairingCode(),
      );
      await _joinAndOpenRequest(
        tester,
        stack: stack,
        runner: secondRunner,
        code: readShownPairingCode(tester),
      );
      await tapWhenShown(tester, find.text('Reject'));
      await waitUntilGone(
        tester,
        findPageTitle('Approve $_secondRunnerName?'),
      );
      final String joinState = await askNode(
        tester,
        secondRunner.readJoinState,
      );

      expect(joinState, _rejectedState);
      expect(find.text(_secondRunnerName), findsNothing);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
