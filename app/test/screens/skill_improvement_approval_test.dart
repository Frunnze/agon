import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_approvals.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';
import 'package:agent_orchestration/widgets/code_block.dart';

import '../support/app_harness.dart';
import '../support/list_harness.dart';
import '../support/random_inputs.dart';

const SectionRoute _approvalsRoute = SectionRoute(AppSection.approvals);
const String _rowTitle = 'Improve skill changelog-entries';
const String _rowSubtitle = 'release #41 · 2 lines added, 1 line removed';
const Map<ApprovalDecision, String> _decisionButtons =
    <ApprovalDecision, String>{
      ApprovalDecision.approved: 'Approve',
      ApprovalDecision.denied: 'Deny',
    };

const String _dialogNote =
    "Approving saves it as the skill's new version. You can undo it from "
    "the skill's history.";

const List<String> _dialogTexts = <String>[
  'Improve skill changelog-entries?',
  'The agent in release #41 wants to change these instructions.',
  'Asked by',
  'Agent on mac-studio, 5 min ago',
  'Change',
  '2 lines added, 1 line removed',
  '  Add one entry per merged pull request.',
  '- Write each entry in the past tense.',
  '+ Write each entry in the present tense.',
  '+ Start with the area it changes, like Login.',
  '  Skip changes to tests and tooling.',
  _dialogNote,
  'Deny',
  'Approve',
];

ApprovalRequest _withAction(ApprovalAction action, {required RunId? runId}) {
  return ApprovalRequest(
    id: galleryImproveSkillApproval.id,
    runId: runId,
    action: action,
    requestedBy: galleryImproveSkillApproval.requestedBy,
    requestedAt: galleryImproveSkillApproval.requestedAt,
    decision: null,
  );
}

ImproveSkillAction _readGalleryAction() {
  return galleryImproveSkillApproval.action as ImproveSkillAction;
}

AppDependencies _buildGallerySkillDependencies() {
  return buildDependenciesWithApprovals(<ApprovalRequest>[
    galleryImproveSkillApproval,
    galleryApprovals.last,
  ]);
}

Future<AppNavigation> _openApprovals(
  WidgetTester tester,
  AppDependencies dependencies,
) {
  return pumpApp(
    tester,
    size: phoneSize,
    route: _approvalsRoute,
    dependencies: dependencies,
  );
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets(
      'a skill improvement row matches the design at ${size.width}',
      (WidgetTester tester) async {
        await pumpApp(
          tester,
          size: size,
          route: _approvalsRoute,
          dependencies: _buildGallerySkillDependencies(),
        );

        expect(
          find.text('2 waiting. Each one needs your approval.'),
          findsOneWidget,
        );
        expect(find.text(_rowTitle), findsOneWidget);
        expect(find.text(_rowSubtitle), findsOneWidget);
        expect(find.text('5 min ago'), findsOneWidget);
        expect(find.text('Sign workflow train-ranker'), findsOneWidget);
      },
    );
  }

  testWidgets('opening the row shows the diff right there', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await _openApprovals(
      tester,
      _buildGallerySkillDependencies(),
    );

    await tester.tap(find.text(_rowTitle));
    await pumpFrames(tester);

    expect(navigation.currentRoute, _approvalsRoute);
    for (final String text in _dialogTexts) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    final CodeBlock diff = tester.widget<CodeBlock>(find.byType(CodeBlock));
    expect(
      <LineChange>[for (final CodeBlockLine line in diff.lines) line.change],
      <LineChange>[
        LineChange.unchanged,
        LineChange.removed,
        LineChange.added,
        LineChange.added,
        LineChange.unchanged,
      ],
    );
  });

  testWidgets('test_review_approval_property_skill_change_one_tap_decides', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10041);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );
      final AppDependencies dependencies = buildDependenciesWithApprovals(
        <ApprovalRequest>[galleryImproveSkillApproval],
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _openApprovals(tester, dependencies);

      await tester.tap(find.text(_rowTitle));
      await pumpFrames(tester);
      await tester.tap(find.text(_decisionButtons[decision]!));
      await pumpFrames(tester);

      final ApprovalRequest request = dependencies.approvalRepository
          .findApproval(galleryImproveSkillApproval.id);
      expect(request.decision?.decision, decision);
      expect(find.byType(AppDialog), findsNothing);
      expect(find.text(_rowTitle), findsNothing);
    }
  });

  testWidgets('an improvement of a deleted skill shows no diff', (
    WidgetTester tester,
  ) async {
    final ImproveSkillAction galleryAction = _readGalleryAction();
    final ImproveSkillAction deleted = ImproveSkillAction(
      skillId: galleryAction.skillId,
      summary: galleryAction.summary,
      preview: null,
    );
    await _openApprovals(
      tester,
      buildDependenciesWithApprovals(<ApprovalRequest>[
        _withAction(deleted, runId: null),
      ]),
    );

    expect(find.text('Improve a deleted skill'), findsOneWidget);
    expect(find.text('2 lines added, 1 line removed'), findsOneWidget);
    await tester.tap(find.text('Improve a deleted skill'));
    await pumpFrames(tester);

    expect(find.text('Improve a deleted skill?'), findsOneWidget);
    expect(
      find.text('An agent wants to change these instructions.'),
      findsOneWidget,
    );
    expect(find.byType(CodeBlock), findsNothing);
    expect(find.text('Approve'), findsOneWidget);
  });

  testWidgets('the chat of the run asks about the skill change', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildDependenciesWithApprovals(
      <ApprovalRequest>[
        _withAction(_readGalleryAction(), runId: GalleryRunIds.release42),
      ],
    );
    final AppNavigation navigation = await pumpApp(
      tester,
      size: phoneSize,
      route: const ChatRoute(GalleryRunIds.release42),
      dependencies: dependencies,
    );
    await pumpFrames(tester);

    expect(navigation.currentRoute, const ChatRoute(GalleryRunIds.release42));
    expect(find.text('Improve skill changelog-entries?'), findsOneWidget);
    expect(
      find.text(
        'The agent in release #42 wants to change these instructions.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Approve'));
    await pumpFrames(tester);

    final ApprovalRequest request = dependencies.approvalRepository
        .findApproval(galleryImproveSkillApproval.id);
    expect(request.decision?.decision, ApprovalDecision.approved);
  });
}
