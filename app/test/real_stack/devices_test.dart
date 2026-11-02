import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;

import 'support/real_stack.dart';
import 'support/runner_device.dart';
import 'support/stack_navigation.dart';
import 'support/stack_node_reads.dart';
import 'support/stack_pairing.dart';
import 'support/stack_waiting.dart';

const String _revokedWord = 'revoked';

void main() {
  testWidgets(
    'test_device_revoke_property_revoked_runner_is_refused_everywhere',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final RunnerDevice runner = await startPairedRunner(
        tester,
        stack: stack,
      );

      await openYourDevices(tester);
      await waitUntilShown(tester, find.text(runnerDeviceName));
      await tapWhenShown(tester, find.text('Revoke'));
      await waitUntilShown(tester, find.text('Revoke $runnerDeviceName?'));
      await tapWhenShown(
        tester,
        find.text('Revoke with $confirmationMethodName'),
      );
      await waitUntilGone(tester, find.text('Revoke $runnerDeviceName?'));
      await waitUntilGone(tester, find.text(runnerDeviceName));

      final node.DeviceView revoked = await askNode(
        tester,
        () => fetchNodeDevice(stack: stack, deviceName: runnerDeviceName),
      );
      final String? refusal = await askNode(
        tester,
        runner.readDeviceListRefusal,
      );

      expect(revoked.device.revoked, isTrue);
      expect(revoked.device.id, isNot(stack.appDeviceId));
      expect(refusal, contains(_revokedWord));
      expect(find.text(appDeviceName), findsOneWidget);
      expect(findPageTitle('Your devices'), findsOneWidget);
      await stack.close(tester);
    },
    skip: findRealStackSkipReason() != null,
    timeout: realStackTimeout,
  );
}
