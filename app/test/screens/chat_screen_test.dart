import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_chat.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/screens/chat/conversation_view.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';
import 'package:agent_orchestration/widgets/blinking_cursor.dart';
import 'package:agent_orchestration/widgets/route_line.dart';
import 'package:agent_orchestration/widgets/route_line_painter.dart';

import '../support/app_harness.dart';

const ChatRoute _chatRoute = ChatRoute(GalleryRunIds.release42);

Future<void> expectGalleryConversation(WidgetTester tester) async {
  expect(find.text('release #42'), findsOneWidget);
  expect(find.text('Agent on mac-studio'), findsOneWidget);
  expect(find.text('Claude Code · step build-ios'), findsOneWidget);
  expect(find.text('air-laptop'), findsWidgets);
  expect(find.text('Message the agent'), findsOneWidget);
  expect(find.text('Send'), findsOneWidget);

  final Finder conversationScroll = find.descendant(
    of: find.byType(ConversationView),
    matching: find.byType(Scrollable),
  );
  for (final String text in <String>[
    'Build succeeded in 3 min 41 s',
    'Edited ios/App.xcodeproj/project.pbxproj',
    'Do that, then push to the release branch.',
    'Build failed: no Apple Distribution certificate',
  ]) {
    await tester.scrollUntilVisible(
      find.text(text),
      120,
      scrollable: conversationScroll,
    );
    expect(find.text(text), findsOneWidget);
  }
}

void expectContextPanel(Size size) {
  final Matcher shown = size == desktopSize ? findsOneWidget : findsNothing;
  expect(find.text('This run'), shown);
  expect(find.text('Ship release 2.4 · build-ios'), shown);
  expect(find.text('7c1e…a90f'), shown);
  expect(
    find.text('New container for this run. Sees only its workspace.'),
    shown,
  );
  expect(
    find.text('api.anthropic.com through the hub, github.com read-only'),
    shown,
  );
  expect(find.text('Open run'), shown);
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('chat matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: _chatRoute,
        dependencies: buildDependenciesWithConversation(
          galleryConversationReplying,
        ),
      );

      expectContextPanel(size);
      expect(find.text('Direct · encrypted'), findsOneWidget);
      expect(find.byType(BlinkingCursor), findsOneWidget);
      await expectGalleryConversation(tester);
      expect(find.byType(AppDialog), findsNothing);
    });

    testWidgets('approval request matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: _chatRoute,
        dependencies: buildGalleryDependencies(),
      );
      await pumpFrames(tester);

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Approve push to GitHub?'), findsOneWidget);
      expect(
        find.text('The agent in release #42 wants to push 3 commits.'),
        findsOneWidget,
      );
      expect(find.text('github.com/acme/app'), findsOneWidget);
      expect(find.text('Agent on mac-studio, just now'), findsOneWidget);
      expect(find.text('9be07d1 Bump build number to 214'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      final Rect dialog = tester.getRect(find.byType(AppDialog));
      if (size == phoneSize) {
        expect(dialog.bottom, closeTo(size.height, 1));
      } else {
        expect(dialog.center.dx, closeTo(size.width / 2, 1));
      }
    });

    testWidgets('reconnecting matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: _chatRoute,
        dependencies: buildDependenciesWithConversation(
          galleryConversationReconnecting,
        ),
      );

      expect(find.text('Reconnecting'), findsOneWidget);
      final RouteLine route = tester.widget(find.byType(RouteLine));
      expect(route.path, RoutePath.broken);
      expect(find.text('Also bump the build number to 215.'), findsOneWidget);
      expect(find.text('Sends when mac-studio is back'), findsOneWidget);
      expect(find.text('Lost the direct link at 14:09'), findsOneWidget);
      await expectGalleryConversation(tester);
    });
  }

  testWidgets('approving the push updates the request', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await pumpApp(
      tester,
      size: phoneSize,
      route: _chatRoute,
      dependencies: dependencies,
    );
    await pumpFrames(tester);

    await tester.tap(find.text('Approve'));
    await pumpFrames(tester);

    final ApprovalRequest request = dependencies.approvalRepository
        .findApproval(GalleryApprovalIds.pushRelease);
    expect(request.decision?.decision, ApprovalDecision.approved);
    expect(dependencies.approvalRepository.listPendingApprovals().length, 1);
    expect(find.byType(AppDialog), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('sending a message adds it to the conversation', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildDependenciesWithConversation(
      galleryConversationReconnecting,
    );
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: _chatRoute,
      dependencies: dependencies,
    );

    await tester.enterText(find.byType(TextField), 'Tag the build too.');
    await pumpFrames(tester);
    await tester.tap(find.text('Send'));
    await pumpFrames(tester);

    final Conversation conversation = dependencies.chatRepository
        .findConversation(GalleryRunIds.release42);
    final ChatMessage last = conversation.messages.last;
    expect(last.text, 'Tag the build too.');
    expect(last.waitingToSend, isTrue);
    expect(find.text('Tag the build too.'), findsOneWidget);
    expect(find.text('Sends when mac-studio is back'), findsNWidgets(2));

    await tester.tap(find.text('Open run'));
    await pumpFrames(tester);
    expect(
      navigation.currentRoute,
      const TaskRunRoute(GalleryRunIds.release42),
    );
  });
}
