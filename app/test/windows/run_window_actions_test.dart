import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_chat.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/screens/chat/chat_screen.dart';
import 'package:agent_orchestration/screens/task_run/task_run_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../support/app_harness.dart';
import '../support/arriving_approval_repository.dart';
import '../support/person_step_dependencies.dart';
import '../support/random_inputs.dart';
import '../support/recording_native_windows.dart';
import '../support/run_window_harness.dart';

const TaskRunRoute _releaseRunRoute = TaskRunRoute(GalleryRunIds.release42);
const ChatRoute _releaseChatRoute = ChatRoute(GalleryRunIds.release42);
const Map<ApprovalDecision, String> _decisionButtons =
    <ApprovalDecision, String>{
      ApprovalDecision.approved: 'Approve',
      ApprovalDecision.denied: 'Deny',
    };

Future<AppNavigation> _pumpReleaseWindow(
  WidgetTester tester,
  AppDependencies dependencies,
) {
  return pumpRunWindow(
    tester,
    runId: GalleryRunIds.release42,
    dependencies: dependencies,
    onTopSwitch: RecordingOnTopSwitch(),
  );
}

Future<void> _openChat(WidgetTester tester) async {
  await tester.tap(find.text('Chat with agent'));
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_run_window_screen_property_chat_opens_here_and_sends', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9201);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildDependenciesWithConversation(
        galleryConversationAwaitingApproval,
      );
      final AppNavigation navigation = await _pumpReleaseWindow(
        tester,
        dependencies,
      );
      await _openChat(tester);
      final String message = '${randomWordPhrase(random)} $i'.trim();

      await tester.enterText(find.byType(TextField), message);
      await pumpFrames(tester);
      await tester.tap(find.text('Send'));
      await pumpFrames(tester);

      final Conversation conversation = dependencies.chatRepository
          .findConversation(GalleryRunIds.release42);
      expect(navigation.currentRoute, _releaseChatRoute);
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(conversation.messages.last.text, message);
      expect(find.text(message), findsOneWidget);
    }
  });

  testWidgets('test_run_window_screen_property_back_returns_to_the_run', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9202);
    final AppNavigation navigation = await _pumpReleaseWindow(
      tester,
      buildDependenciesWithConversation(galleryConversationAwaitingApproval),
    );
    final int visits = 1 + random.nextInt(widgetPropertyIterations);

    for (int visit = 0; visit < visits; visit += 1) {
      await _openChat(tester);
      await tester.tap(find.byType(BackLinkButton));
      await pumpFrames(tester);

      expect(navigation.routes, const <AppRoute>[_releaseRunRoute]);
      expect(find.byType(TaskRunScreen), findsOneWidget);
      expect(find.byType(ChatScreen), findsNothing);
    }
  });

  testWidgets('test_run_approval_prompts_property_one_tap_decides_here', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9203);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );
      final AppDependencies dependencies = buildGalleryDependencies();
      await _pumpReleaseWindow(tester, dependencies);
      expect(find.byType(AppDialog), findsOneWidget);

      await tester.tap(find.text(_decisionButtons[decision]!));
      await pumpFrames(tester);

      final ApprovalRequest request = dependencies.approvalRepository
          .findApproval(GalleryApprovalIds.pushRelease);
      expect(request.decision?.decision, decision);
      expect(find.byType(AppDialog), findsNothing);
    }
  });

  testWidgets('test_run_approval_prompts_property_arrivals_ask_on_any_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9204);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ArrivingApprovalRepository approvals =
          ArrivingApprovalRepository();
      final AppDependencies dependencies = replaceRepositories(
        buildDependenciesWithConversation(galleryConversationAwaitingApproval),
        approvalRepository: approvals,
      );
      await _pumpReleaseWindow(tester, dependencies);
      final bool isOnChat = random.nextBool();
      if (isOnChat) {
        await _openChat(tester);
      }
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );

      approvals.raiseApproval(_askToPush(GalleryRunIds.release41, i));
      await pumpFrames(tester);
      expect(find.byType(AppDialog), findsNothing);
      approvals.raiseApproval(_askToPush(GalleryRunIds.release42, i));
      await pumpFrames(tester);
      expect(find.byType(AppDialog), findsOneWidget);
      await tester.tap(find.text(_decisionButtons[decision]!));
      await pumpFrames(tester);

      final ApprovalRequest decided = approvals.listApprovals().last;
      expect(decided.decision?.decision, decision);
      expect(approvals.listPendingApprovals(), hasLength(1));
      expect(find.byType(AppDialog), findsNothing);
      expect(find.byType(ChatScreen), isOnChat ? findsOneWidget : findsNothing);
    }
  });

  testWidgets('test_run_window_screen_property_answer_buttons_answer', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9205);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = removeApprovals(
        buildDependenciesWithQuestion(notes: const <RunNote>[]),
      );
      await _pumpReleaseWindow(tester, dependencies);
      final String choice = pickOne(random, questionChoices);

      await tester.tap(find.widgetWithText(AppButton, choice));
      await pumpFrames(tester);

      final int openQuestions = dependencies.personStepRepository
          .listOpenPersonSteps()
          .length;
      expect(openQuestions, 0);
      expect(find.text(questionText), findsNothing);
    }
  });

  testWidgets('test_run_window_screen_property_cancel_run_stops_it_here', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = removeApprovals(
      buildGalleryDependencies(),
    );
    final AppNavigation navigation = await _pumpReleaseWindow(
      tester,
      dependencies,
    );

    await tester.tap(find.text('Cancel run'));
    await pumpFrames(tester);

    final Run cancelled = dependencies.taskRepository.findRun(
      GalleryRunIds.release42,
    );
    expect(isRunActive(cancelled), isFalse);
    expect(navigation.routes, const <AppRoute>[_releaseRunRoute]);
    expect(find.text('Cancel run'), findsNothing);
    expect(find.text('Ask the agent'), findsOneWidget);
  });

  testWidgets('test_run_window_screen_property_retry_shows_the_new_run', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = removeApprovals(
      buildGalleryDependencies(),
    );
    final AppNavigation navigation = await pumpRunWindow(
      tester,
      runId: galleryFailedRun.id,
      dependencies: dependencies,
      onTopSwitch: RecordingOnTopSwitch(),
    );

    await tester.tap(find.textContaining('Retry'));
    await pumpFrames(tester);

    final AppRoute shown = navigation.currentRoute;
    expect(shown, isA<TaskRunRoute>());
    final Run retried = dependencies.taskRepository.findRun(
      (shown as TaskRunRoute).runId,
    );
    expect(retried.id, isNot(galleryFailedRun.id));
    expect(isRunActive(retried), isTrue);
    expect(find.text('Cancel run'), findsOneWidget);
  });
}

ApprovalRequest _askToPush(RunId runId, int round) {
  return ApprovalRequest(
    id: ApprovalId('approval-${runId.value}-$round'),
    runId: runId,
    action: PushCommitsAction(
      repository: 'github.com/acme/app',
      branch: 'release',
      commits: <String>['a41f2c0 Round $round'],
    ),
    requestedBy: GalleryDeviceIds.macStudio,
    requestedAt: galleryNow,
    decision: null,
  );
}
