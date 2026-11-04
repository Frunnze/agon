import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_approvals.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/list_harness.dart';
import '../support/random_inputs.dart';
import '../support/recording_native_windows.dart';
import '../support/run_window_harness.dart';

const ChatRoute _chatRoute = ChatRoute(GalleryRunIds.release42);
const SectionRoute _approvalsRoute = SectionRoute(AppSection.approvals);
const String _runLabel = 'release #42';
const int _longestFolderWords = 12;
const int _rounds = 3;

String _buildLongCommand(Random random) {
  final StringBuffer folders = StringBuffer();
  final int folderCount = 6 + random.nextInt(_longestFolderWords);
  for (int i = 0; i < folderCount; i += 1) {
    folders.write('/${randomWordPhrase(random).replaceAll(' ', '-')}');
  }
  return 'C="the task folder$folders"; cd "\$C" && '
      'npx markdownlint-cli2 "**/*.md" --config the task folder/.lint.jsonc '
      '${randomWordPhrase(random)} ${'x' * 120}';
}

ApprovalRequest _buildApproval(String summary, String command) {
  return ApprovalRequest(
    id: galleryRunCommandApproval.id,
    runId: galleryRunCommandApproval.runId,
    action: RunCommandAction(tool: 'Bash', summary: summary, command: command),
    requestedBy: galleryRunCommandApproval.requestedBy,
    requestedAt: galleryRunCommandApproval.requestedAt,
    decision: null,
  );
}

bool _scrollsSideways(Widget widget) {
  return widget is SingleChildScrollView &&
      widget.scrollDirection == Axis.horizontal;
}

void _expectShownInFull(WidgetTester tester, Finder shownText) {
  expect(shownText, findsOneWidget);
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: shownText, matching: find.byType(RichText)),
  );
  final Rect box = tester.getRect(shownText);
  final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;

  expect(paragraph.maxLines, isNull);
  expect(paragraph.overflow, isNot(TextOverflow.ellipsis));
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(box.left, greaterThanOrEqualTo(0));
  expect(box.right, lessThanOrEqualTo(screen.width));
  expect(
    find.ancestor(
      of: shownText,
      matching: find.byWidgetPredicate(_scrollsSideways),
    ),
    findsNothing,
  );
}

Future<void> _expectDialogShowsAll(
  WidgetTester tester, {
  required String summary,
  required String command,
}) async {
  expect(find.text('$summary?'), findsOneWidget);
  await tester.ensureVisible(find.text(command));
  await pumpFrames(tester);
  _expectShownInFull(tester, find.text(command));
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets(
      'test_approvals_list_property_long_command_wraps_at_${size.width}',
      (WidgetTester tester) async {
        final Random random = seededRandom(7201);
        for (int i = 0; i < _rounds; i += 1) {
          final String summary = 'Run ${randomWordPhrase(random)}';
          final String command = _buildLongCommand(random);
          final AppDependencies dependencies = buildDependenciesWithApprovals(
            <ApprovalRequest>[_buildApproval(summary, command)],
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await pumpApp(
            tester,
            size: size,
            route: _approvalsRoute,
            dependencies: dependencies,
          );

          expect(find.text(summary), findsOneWidget);
          _expectShownInFull(tester, find.text('$_runLabel · $command'));
        }
      },
    );
  }

  testWidgets('test_chat_approval_property_long_command_wraps_in_full', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7202);
    for (int i = 0; i < _rounds; i += 1) {
      final String summary = 'Run ${randomWordPhrase(random)}';
      final String command = _buildLongCommand(random);
      final AppDependencies dependencies = buildDependenciesWithApprovals(
        <ApprovalRequest>[_buildApproval(summary, command)],
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpApp(
        tester,
        size: phoneSize,
        route: _chatRoute,
        dependencies: dependencies,
      );
      await pumpFrames(tester);

      await _expectDialogShowsAll(tester, summary: summary, command: command);
    }
  });

  testWidgets('test_run_window_approval_property_long_command_wraps', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7203);
    for (int i = 0; i < _rounds; i += 1) {
      final String summary = 'Run ${randomWordPhrase(random)}';
      final String command = _buildLongCommand(random);
      final AppDependencies dependencies = buildDependenciesWithApprovals(
        <ApprovalRequest>[_buildApproval(summary, command)],
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpRunWindow(
        tester,
        runId: GalleryRunIds.release42,
        dependencies: dependencies,
        onTopSwitch: RecordingOnTopSwitch(),
      );
      await pumpFrames(tester);

      await _expectDialogShowsAll(tester, summary: summary, command: command);
    }
  });
}
