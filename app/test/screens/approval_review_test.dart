import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';
import '../support/recording_biometric_confirmation.dart';

const ApprovalId _runlessApprovalId = ApprovalId('runless-approval');
const SectionRoute _approvalsRoute = SectionRoute(AppSection.approvals);
const Map<ApprovalDecision, String> _decisionButtons =
    <ApprovalDecision, String>{
      ApprovalDecision.approved: 'Approve with Touch ID',
      ApprovalDecision.denied: 'Deny',
    };

ApprovalAction _randomRunlessAction(Random random) {
  switch (random.nextInt(3)) {
    case 0:
      return DeployAction(target: 'env-${random.nextInt(100)}');
    case 1:
      return DeleteBranchOrFilesAction(
        repository: 'github.com/acme/app',
        what: 'branch old-${random.nextInt(100)}',
      );
    default:
      return PushCommitsAction(
        repository: 'github.com/acme/api',
        branch: 'main',
        commits: <String>['c0ffee${random.nextInt(10)} Tidy up'],
      );
  }
}

AppDependencies _buildDependencies({
  required ApprovalAction action,
  required RecordingBiometricConfirmation confirmation,
}) {
  final AppDependencies base = buildGalleryDependencies();
  final ApprovalRequest runless = ApprovalRequest(
    id: _runlessApprovalId,
    runId: null,
    action: action,
    requestedBy: GalleryDeviceIds.macStudio,
    requestedAt: galleryNow,
    decision: null,
  );

  return replaceRepositories(
    base,
    approvalRepository: FakeApprovalRepository(
      approvals: <ApprovalRequest>[runless],
      clock: base.clock,
      currentDeviceId: GalleryDeviceIds.airLaptop,
    ),
    biometricConfirmation: confirmation,
  );
}

void main() {
  testWidgets('test_review_approval_property_runless_ones_open_the_dialog', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10021);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ApprovalAction action = _randomRunlessAction(random);
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );
      final RecordingBiometricConfirmation confirmation =
          RecordingBiometricConfirmation(answer: random.nextBool());
      final AppDependencies dependencies = _buildDependencies(
        action: action,
        confirmation: confirmation,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpApp(
        tester,
        size: phoneSize,
        route: _approvalsRoute,
        dependencies: dependencies,
      );

      await tester.tap(
        find.text(describeApprovalTitle(action, galleryWorkflows)),
      );
      await pumpFrames(tester);
      expect(find.text('Asked by'), findsOneWidget);
      await tester.tap(find.text(_decisionButtons[decision]!));
      await pumpFrames(tester);

      final ApprovalRequest request = dependencies.approvalRepository
          .findApproval(_runlessApprovalId);
      expect(confirmation.askedReasons, <String>[
        describeDecisionReason(
          decision: decision,
          action: action,
          workflows: galleryWorkflows,
        ),
      ]);
      expect(request.isPending, !confirmation.answer);
      if (confirmation.answer) {
        expect(request.decision?.decision, decision);
      }
    }
  });

  testWidgets('a runless deploy names an agent without a run', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      size: desktopSize,
      route: _approvalsRoute,
      dependencies: _buildDependencies(
        action: const DeployAction(target: 'production'),
        confirmation: RecordingBiometricConfirmation(answer: true),
      ),
    );

    await tester.tap(find.text('Deploy to production'));
    await pumpFrames(tester);

    expect(find.text('Deploy to production?'), findsOneWidget);
    expect(find.text('An agent asks before it does this.'), findsOneWidget);
    expect(find.text('Agent on mac-studio, just now'), findsOneWidget);
  });
}
