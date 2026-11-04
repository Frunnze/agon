import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const String _leaveLabel = 'Leave';
const String _submitLabel = 'Submit';

void main() {
  testWidgets('test_form_action_buttons_property_each_action_runs_its_own', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9911);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool isSubmitting = random.nextBool();
      final List<String> pressed = <String>[];
      final List<FormAction<String>> actions = <FormAction<String>>[
        LeaveFormAction<String>(
          label: _leaveLabel,
          onPressed: () => pressed.add(_leaveLabel),
        ),
        SubmitFormAction<String>(
          label: _submitLabel,
          tone: ButtonTone.primary,
          onSubmitted: (String _) async {},
        ),
      ];
      await pumpScrollableAtWidth(
        tester,
        width: desktopWidth,
        child: FormActionButtons<String>(
          actions: actions,
          isSubmitting: isSubmitting,
          onSubmit: (SubmitFormAction<String> action) =>
              pressed.add(action.label),
        ),
      );

      await tester.tap(find.text(_leaveLabel));
      await tester.tap(find.text(_submitLabel));

      final List<String> expected = isSubmitting
          ? const <String>[]
          : const <String>[_leaveLabel, _submitLabel];
      expect(pressed, expected, reason: 'submitting $isSubmitting');
    }
  });

  test(
    'test_build_review_actions_property_cancel_leaves_approve_submits',
    () async {
      final Random random = seededRandom(9912);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String values = randomText(random);
        final List<String> approved = <String>[];
        final List<FormAction<String>> actions = buildReviewActions<String>(
          onCancelled: () {},
          onApproved: (String approvedValues) async =>
              approved.add(approvedValues),
        );

        final FormAction<String> cancel = actions.first;
        final FormAction<String> approve = actions.last;
        expect(cancel, isA<LeaveFormAction<String>>());
        expect(cancel.label, cancelReviewLabel);
        expect(approve.label, approveLabel);
        expect(approve.tone, ButtonTone.primary);
        if (approve is SubmitFormAction<String>) {
          await approve.onSubmitted(values);
        }
        expect(approved, <String>[values]);
      }
    },
  );
}
