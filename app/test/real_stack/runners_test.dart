import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/widgets/slots_indicator.dart';

import 'support/real_stack.dart';
import 'support/stack_navigation.dart';
import 'support/stack_node_reads.dart';
import 'support/stack_pairing.dart';
import 'support/stack_settings.dart';
import 'support/stack_waiting.dart';

const String _runnerLabel = 'mac';
const String _serverDownTitle = "Can't reach the app server";

Finder _findInRunnersTab(String text) {
  return find.descendant(
    of: find.byType(RunnersSettingsTab),
    matching: find.text(text),
  );
}

Future<bool?> _readAcceptingNewRuns({required RealStack stack}) async {
  final node.RunnerView? runner = await findNodeRunner(
    stack: stack,
    deviceName: runnerDeviceName,
  );
  if (runner == null || !runner.runner.online) {
    return null;
  }
  return runner.runner.acceptingNewRuns;
}

Future<bool> _isRunnerAcceptingNewRuns({required RealStack stack}) async {
  final bool? isAccepting = await _readAcceptingNewRuns(stack: stack);
  return isAccepting == true;
}

Future<bool> _isRunnerPaused({required RealStack stack}) async {
  final bool? isAccepting = await _readAcceptingNewRuns(stack: stack);
  return isAccepting == false;
}

Future<void> _openRunnersWithPairedRunner(
  WidgetTester tester, {
  required RealStack stack,
}) async {
  await startPairedRunner(tester, stack: stack);
  await waitUntilNodeAgrees(
    tester,
    description: 'the paired runner online',
    check: () => _isRunnerAcceptingNewRuns(stack: stack),
  );
  await openSettingsTab(
    tester,
    tabLabel: 'Runners',
    expected: find.byType(RunnersSettingsTab),
  );
  await waitUntilShown(tester, _findInRunnersTab(runnerDeviceName));
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_runners_property_paired_runner_shows_its_labels_and_slots',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      await _openRunnersWithPairedRunner(tester, stack: stack);
      await waitUntilShown(tester, _findInRunnersTab('Online'));

      final node.RunnerView? nodeRunner = await askNode(
        tester,
        () => findNodeRunner(stack: stack, deviceName: runnerDeviceName),
      );
      final SlotsIndicator slots = tester.widget<SlotsIndicator>(
        find.descendant(
          of: find.byType(RunnersSettingsTab),
          matching: find.byType(SlotsIndicator),
        ),
      );

      expect(nodeRunner, isNotNull);
      expect(nodeRunner!.runner.labels, <String>[_runnerLabel]);
      expect(_findInRunnersTab(_runnerLabel), findsOneWidget);
      expect(slots.total, nodeRunner.runner.slotsTotal);
      expect(slots.busy, nodeRunner.runner.slotsBusy);
      expect(_findInRunnersTab('1 of 1 online · 1 free slot'), findsOneWidget);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_runner_detail_property_pause_and_resume_reach_the_node',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      await _openRunnersWithPairedRunner(tester, stack: stack);
      await tapAndWait(
        tester,
        _findInRunnersTab(runnerDeviceName),
        expected: findPageTitle(runnerDeviceName),
      );
      await waitUntilGone(tester, find.byType(RunnersSettingsTab));

      await tapWhenShown(tester, find.text('Pause new runs'));
      await waitUntilShown(tester, find.text('Resume new runs'));
      await waitUntilNodeAgrees(
        tester,
        description: 'the runner paused',
        check: () => _isRunnerPaused(stack: stack),
      );
      expect(find.text('Paused · 0 of 1 slots busy'), findsOneWidget);

      await tapWhenShown(tester, find.text('Resume new runs'));
      await waitUntilShown(tester, find.text('Pause new runs'));
      await waitUntilNodeAgrees(
        tester,
        description: 'the runner accepting new runs again',
        check: () => _isRunnerAcceptingNewRuns(stack: stack),
      );
      expect(find.text('Online · 0 of 1 slots busy'), findsOneWidget);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_runners_server_down_property_banner_clears_by_itself',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      await _openRunnersWithPairedRunner(tester, stack: stack);
      expect(find.text(_serverDownTitle), findsNothing);

      await askNode(tester, stack.server.stop);
      await waitUntilShown(tester, find.text(_serverDownTitle));
      expect(_findInRunnersTab(runnerDeviceName), findsOneWidget);

      await stack.restartServer(tester);
      await waitUntilGone(tester, find.text(_serverDownTitle));
      expect(_findInRunnersTab(runnerDeviceName), findsOneWidget);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
