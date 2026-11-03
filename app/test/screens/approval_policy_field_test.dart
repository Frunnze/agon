import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';
import 'package:agent_orchestration/screens/shared/approval_policy_field.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

void main() {
  testWidgets('test_approval_policy_field_property_tap_reports_that_policy', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2401);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ApprovalPolicy selected = pickOne(random, ApprovalPolicy.values);
      final ApprovalPolicy tapped = pickOne(random, ApprovalPolicy.values);
      ApprovalPolicy? reported;
      await pumpScrollableAtWidth(
        tester,
        width: phoneWidth,
        child: ApprovalPolicyField(
          selected: selected,
          onChanged: (ApprovalPolicy policy) => reported = policy,
        ),
      );

      expect(find.text('Commands'), findsOneWidget);
      for (final ApprovalPolicy policy in ApprovalPolicy.values) {
        expect(
          find.text(describeApprovalPolicyDetail(policy)),
          findsOneWidget,
        );
      }
      await tester.tap(find.text(describeApprovalPolicyTitle(tapped)));
      expect(reported, tapped);
    }
  });
}
