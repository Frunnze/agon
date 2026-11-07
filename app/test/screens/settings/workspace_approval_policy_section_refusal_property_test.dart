import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/tab_strip.dart';

import '../../support/app_harness.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_place_repositories.dart';

const String _autoTitle = 'Auto';
const String _askMeTitle = 'Ask me';

RefusedActionCase _buildChangeApprovalPolicyCase() {
  late WorkspaceRepository workspaceRepository;
  late ApprovalPolicy policyBeforeTap;

  return RefusedActionCase(
    functionName: 'change_approval_policy',
    actionLabel: changeSettingLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: (tester, {required size, required refusal}) async {
      final AppDependencies gallery = buildGalleryDependencies();
      workspaceRepository = RefusingWorkspaceRepository(
        stored: gallery.workspaceRepository,
        refusal: refusal,
      );
      await pumpApp(
        tester,
        size: size,
        route: const SectionRoute(AppSection.settings),
        dependencies: replaceRepositories(
          gallery,
          workspaceRepository: workspaceRepository,
        ),
      );
      final Finder tab = find.descendant(
        of: find.byType(TabStrip),
        matching: find.text(approvalPolicyLabel),
      );
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await pumpFrames(tester);
    },
    performAction: (tester) async {
      policyBeforeTap = workspaceRepository.currentWorkspace().approvalPolicy;
      final String otherTitle = policyBeforeTap == ApprovalPolicy.neverAsk
          ? _askMeTitle
          : _autoTitle;
      final Finder otherChoice = find.text(otherTitle);
      await tester.ensureVisible(otherChoice);
      await tester.tap(otherChoice);
      await pumpFrames(tester);
    },
    expectSucceeded: (tester) {
      final ApprovalPolicy policyAfterTap = workspaceRepository
          .currentWorkspace()
          .approvalPolicy;
      expect(policyAfterTap, isNot(policyBeforeTap));
    },
  );
}

void main() {
  registerRefusedActionProperties(
    _buildChangeApprovalPolicyCase(),
    seed: 91601,
  );
}
