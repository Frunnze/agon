import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';
import 'package:agent_orchestration/screens/shared/approval_policy_field.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';

import '../support/random_inputs.dart';
import '../support/sample_records.dart';
import '../support/widget_harness.dart';

String _describeChoiceTitle({
  required ApprovalPolicy? policy,
  required ApprovalPolicyFallback fallback,
}) {
  if (policy == null) {
    return fallback.title;
  }
  return describeApprovalPolicyTitle(policy);
}

void main() {
  test('test_build_approval_policy_choices_property_follows_choice_order', () {
    final List<ChoiceOption<ApprovalPolicy>> choices =
        buildApprovalPolicyChoices();

    expect(<ApprovalPolicy>[
      for (final ChoiceOption<ApprovalPolicy> choice in choices) choice.value,
    ], approvalPolicyChoiceOrder);
    for (final ChoiceOption<ApprovalPolicy> choice in choices) {
      expect(choice.title, describeApprovalPolicyTitle(choice.value));
      expect(choice.detail, describeApprovalPolicyDetail(choice.value));
    }
  });

  test(
    'test_build_inheritable_approval_policy_choices_property_fallback_first',
    () {
      for (final ApprovalPolicyFallback fallback
          in ApprovalPolicyFallback.values) {
        final List<ChoiceOption<ApprovalPolicy?>> choices =
            buildInheritableApprovalPolicyChoices(fallback);

        expect(choices.first.value, isNull);
        expect(choices.first.title, fallback.title);
        expect(choices.first.detail, fallback.detail);
        expect(<ApprovalPolicy?>[
          for (final ChoiceOption<ApprovalPolicy?> choice in choices.skip(1))
            choice.value,
        ], approvalPolicyChoiceOrder);
      }
    },
  );

  testWidgets('test_approval_policy_field_property_tap_reports_that_choice', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2401);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ApprovalPolicyFallback fallback = pickOne(
        random,
        ApprovalPolicyFallback.values,
      );
      final ApprovalPolicy? selected = randomInheritableApprovalPolicy(random);
      final ApprovalPolicy? tapped = randomInheritableApprovalPolicy(random);
      final List<ApprovalPolicy?> reported = <ApprovalPolicy?>[];
      await pumpScrollableAtWidth(
        tester,
        width: phoneWidth,
        child: ApprovalPolicyField(
          fallback: fallback,
          selected: selected,
          onChanged: reported.add,
        ),
      );

      expect(find.text('Commands and pushes'), findsOneWidget);
      expect(find.text(fallback.detail), findsOneWidget);
      for (final ApprovalPolicy policy in ApprovalPolicy.values) {
        expect(
          find.text(describeApprovalPolicyDetail(policy)),
          findsOneWidget,
        );
      }
      await tester.tap(
        find.text(_describeChoiceTitle(policy: tapped, fallback: fallback)),
      );
      expect(reported, <ApprovalPolicy?>[tapped]);
    }
  });
}
