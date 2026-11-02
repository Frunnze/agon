import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_approvals.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';
import '../support/recording_biometric_confirmation.dart';

const ChatRoute _chatRoute = ChatRoute(GalleryRunIds.release42);
const Map<ApprovalDecision, String> _decisionButtons =
    <ApprovalDecision, String>{
      ApprovalDecision.approved: 'Approve with Touch ID',
      ApprovalDecision.denied: 'Deny',
    };

void main() {
  testWidgets('test_review_approval_property_decides_only_when_confirmed', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10011);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );
      final RecordingBiometricConfirmation confirmation =
          RecordingBiometricConfirmation(answer: random.nextBool());
      final AppDependencies dependencies = replaceRepositories(
        buildGalleryDependencies(),
        biometricConfirmation: confirmation,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpApp(
        tester,
        size: phoneSize,
        route: _chatRoute,
        dependencies: dependencies,
      );
      await pumpFrames(tester);

      await tester.tap(find.text(_decisionButtons[decision]!));
      await pumpFrames(tester);

      final ApprovalRequest request = dependencies.approvalRepository
          .findApproval(GalleryApprovalIds.pushRelease);
      expect(confirmation.askedReasons, <String>[
        describeDecisionReason(
          decision: decision,
          action: request.action,
          workflows: galleryWorkflows,
        ),
      ]);
      if (confirmation.answer) {
        expect(request.decision?.decision, decision);
      } else {
        expect(request.isPending, isTrue);
      }
    }
  });

  test('test_describe_decision_reason_property_names_verb_and_action', () {
    final Random random = seededRandom(10012);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalRequest request = pickOne(random, galleryApprovals);
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );
      final String reason = describeDecisionReason(
        decision: decision,
        action: request.action,
        workflows: galleryWorkflows,
      );
      final String verb = decision == ApprovalDecision.approved
          ? 'Approve'
          : 'Deny';

      expect(reason, startsWith(verb));
      expect(
        reason,
        endsWith(describeApprovalTitle(request.action, galleryWorkflows)),
      );
    }
  });
}
