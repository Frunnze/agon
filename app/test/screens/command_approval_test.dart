import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_approvals.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';

import '../support/app_harness.dart';
import '../support/list_harness.dart';
import '../support/random_inputs.dart';

const ChatRoute _chatRoute = ChatRoute(GalleryRunIds.release42);
const SectionRoute _approvalsRoute = SectionRoute(AppSection.approvals);
const String _galleryCommand = 'xcodebuild test -scheme App';
const String _galleryRowTitle = 'Run the tests';
const String _galleryRowContext = 'release #42 · $_galleryCommand';
const List<String> _toolNames = <String>[
  'Bash',
  'WebFetch',
  'WebSearch',
  'Read',
  'Edit',
];
const Map<ApprovalDecision, String> _decisionButtons =
    <ApprovalDecision, String>{
      ApprovalDecision.approved: 'Approve',
      ApprovalDecision.denied: 'Deny',
    };

AppDependencies _buildGalleryCommandDependencies() {
  return buildDependenciesWithApprovals(<ApprovalRequest>[
    galleryRunCommandApproval,
    galleryApprovals.last,
  ]);
}

ApprovalRequest _buildCommandApproval(RunCommandAction action) {
  return ApprovalRequest(
    id: galleryRunCommandApproval.id,
    runId: galleryRunCommandApproval.runId,
    action: action,
    requestedBy: galleryRunCommandApproval.requestedBy,
    requestedAt: galleryRunCommandApproval.requestedAt,
    decision: null,
  );
}

TextStyle? _readLastSpanStyle(WidgetTester tester, String text) {
  final Text title = tester.widget<Text>(find.text(text));
  final TextSpan titleSpan = title.textSpan! as TextSpan;
  final List<InlineSpan> spans = titleSpan.children!;
  final TextSpan lastSpan = spans.last as TextSpan;
  return lastSpan.style;
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('a waiting command matches the design at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: _approvalsRoute,
        dependencies: _buildGalleryCommandDependencies(),
      );

      expect(
        find.text('2 waiting. Each one needs your approval.'),
        findsOneWidget,
      );
      expect(find.text(_galleryRowTitle), findsOneWidget);
      expect(find.text(_galleryRowContext), findsOneWidget);
      expect(find.text('Sign workflow train-ranker'), findsOneWidget);
      expect(
        _readLastSpanStyle(tester, _galleryRowContext),
        AppTextStyles.monospace,
      );
    });
  }

  testWidgets('the chat asks about the command as the design does', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await pumpApp(
      tester,
      size: phoneSize,
      route: _approvalsRoute,
      dependencies: _buildGalleryCommandDependencies(),
    );

    await tester.tap(find.text(_galleryRowTitle));
    await pumpFrames(tester);

    expect(navigation.currentRoute, isA<ChatRoute>());
    for (final String text in <String>[
      'Run the tests?',
      'The agent in release #42 wants to run a command.',
      'Asked by',
      'Agent on mac-studio, just now',
      _galleryCommand,
      'The run waits until you decide.',
      'Deny',
      'Approve',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
  });

  testWidgets('test_review_approval_property_command_one_tap_decides', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10031);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunCommandAction action = RunCommandAction(
        tool: pickOne(random, _toolNames),
        summary: 'Fetch ${randomWordPhrase(random)}',
        command: 'https://example.com/${randomWordPhrase(random)}',
      );
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );
      final AppDependencies dependencies = buildDependenciesWithApprovals(
        <ApprovalRequest>[_buildCommandApproval(action)],
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpApp(
        tester,
        size: phoneSize,
        route: _chatRoute,
        dependencies: dependencies,
      );
      await pumpFrames(tester);

      expect(find.text('${action.summary}?'), findsOneWidget);
      expect(find.text(action.command), findsOneWidget);
      await tester.tap(find.text(_decisionButtons[decision]!));
      await pumpFrames(tester);

      final ApprovalRequest request = dependencies.approvalRepository
          .findApproval(galleryRunCommandApproval.id);
      expect(request.decision?.decision, decision);
      expect(find.byType(AppDialog), findsNothing);
    }
  });
}
