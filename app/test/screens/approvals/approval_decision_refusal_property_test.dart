import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_approvals.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/repository/approval_repository.dart';
import 'package:agent_orchestration/screens/approvals/approval_dialog.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/arriving_approval_repository.dart';
import '../../support/list_harness.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_work_repositories.dart';

const String _improvementRowTitle = 'Improve skill changelog-entries';

RefusedActionCase _buildApprovalsScreenCase({
  required String functionName,
  required String decisionLabel,
}) {
  late ApprovalRepository approvalRepository;

  return RefusedActionCase(
    functionName: functionName,
    actionLabel: decisionLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: (tester, {required size, required refusal}) async {
      final AppDependencies base = buildDependenciesWithApprovals(
        <ApprovalRequest>[galleryImproveSkillApproval],
      );
      approvalRepository = RefusingApprovalRepository(
        stored: base.approvalRepository,
        refusal: refusal,
      );
      await pumpApp(
        tester,
        size: size,
        route: const SectionRoute(AppSection.approvals),
        dependencies: replaceRepositories(
          base,
          approvalRepository: approvalRepository,
        ),
      );
    },
    performAction: (tester) async {
      final Finder row = find.text(_improvementRowTitle);
      await tester.ensureVisible(row);
      await tester.tap(row);
      await pumpFrames(tester);
      await tapButtonLabelled(tester, decisionLabel);
    },
    expectSucceeded: (tester) {
      expect(approvalRepository.listPendingApprovals(), isEmpty);
    },
  );
}

RefusedActionCase _buildRunPromptCase() {
  final ApprovalRequest pushRequest = galleryApprovals.first;
  late ArrivingApprovalRepository arrivingApprovals;

  return RefusedActionCase(
    functionName: 'review_next_approval',
    actionLabel: approveDecisionLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: (tester, {required size, required refusal}) async {
      final AppDependencies gallery = buildGalleryDependencies();
      arrivingApprovals = ArrivingApprovalRepository();
      await pumpApp(
        tester,
        size: size,
        route: ChatRoute(pushRequest.runId!),
        dependencies: replaceRepositories(
          gallery,
          approvalRepository: RefusingApprovalRepository(
            stored: arrivingApprovals,
            refusal: refusal,
          ),
        ),
      );
    },
    performAction: (tester) async {
      arrivingApprovals.raiseApproval(pushRequest);
      await pumpFrames(tester);
      await tapButtonLabelled(tester, approveDecisionLabel);
    },
    expectSucceeded: (tester) {
      expect(arrivingApprovals.listPendingApprovals(), isEmpty);
    },
  );
}

void main() {
  registerRefusedActionProperties(
    _buildApprovalsScreenCase(
      functionName: 'approval_review_review',
      decisionLabel: approveDecisionLabel,
    ),
    seed: 92201,
  );
  registerRefusedActionProperties(
    _buildApprovalsScreenCase(
      functionName: 'approval_review_decide',
      decisionLabel: denyDecisionLabel,
    ),
    seed: 92211,
  );
  registerRefusedActionProperties(_buildRunPromptCase(), seed: 92221);
}
