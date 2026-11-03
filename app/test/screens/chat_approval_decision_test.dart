import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';

const ChatRoute _chatRoute = ChatRoute(GalleryRunIds.release42);
const Map<ApprovalDecision, String> _decisionButtons =
    <ApprovalDecision, String>{
      ApprovalDecision.approved: 'Approve',
      ApprovalDecision.denied: 'Deny',
    };

void main() {
  testWidgets('test_review_approval_property_one_tap_decides_at_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10011);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );
      final AppDependencies dependencies = buildGalleryDependencies();
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
      expect(request.decision?.decision, decision);
      expect(find.byType(AppDialog), findsNothing);
    }
  });
}
