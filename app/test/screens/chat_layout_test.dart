import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_chat.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/screens/chat/conversation_view.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';

const ChatRoute _chatRoute = ChatRoute(GalleryRunIds.release42);
const Size _tabletSize = Size(834, 1112);
const List<String> _blankCharacters = <String>[' ', '\t', '\n'];

String _randomBlankMessage(Random random) {
  final StringBuffer message = StringBuffer();
  for (int i = 0; i < random.nextInt(6); i += 1) {
    message.write(pickOne(random, _blankCharacters));
  }
  return message.toString();
}

int _countMessages(AppDependencies dependencies) {
  return dependencies.chatRepository
      .findConversation(GalleryRunIds.release42)
      .messages
      .length;
}

Finder _findButtonLabelled(String label) {
  return find.ancestor(
    of: find.text(label),
    matching: find.byType(TextButton),
  );
}

void main() {
  testWidgets('test_chat_composer_property_blank_messages_are_not_sent', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2701);
    final AppDependencies dependencies = buildDependenciesWithConversation(
      galleryConversationReplying,
    );
    await pumpApp(
      tester,
      size: desktopSize,
      route: _chatRoute,
      dependencies: dependencies,
    );
    final int messageCount = _countMessages(dependencies);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await tester.enterText(
        find.byType(TextField),
        _randomBlankMessage(random),
      );
      await tester.tap(find.text('Send'));
      await pumpFrames(tester);

      expect(_countMessages(dependencies), messageCount);
    }
  });

  testWidgets('send looks ready while the message is empty', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      size: phoneSize,
      route: _chatRoute,
      dependencies: buildDependenciesWithConversation(
        galleryConversationReplying,
      ),
    );

    final TextButton send = tester.widget(_findButtonLabelled('Send'));
    expect(send.onPressed, isNotNull);
  });

  testWidgets('this run panel spaces its parts and stretches Open run', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      size: desktopSize,
      route: _chatRoute,
      dependencies: buildDependenciesWithConversation(
        galleryConversationReplying,
      ),
    );

    final Rect title = tester.getRect(find.text('This run'));
    final Rect firstTerm = tester.getRect(find.text('Task'));
    final Rect openRun = tester.getRect(_findButtonLabelled('Open run'));
    expect(firstTerm.top - title.bottom, AppSpacing.space5);
    expect(
      openRun.width,
      AppSizes.chatContextWidth - AppSpacing.space6 - AppBorders.thin,
    );
  });

  testWidgets('a short conversation starts at the top', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      size: _tabletSize,
      route: _chatRoute,
      dependencies: buildDependenciesWithConversation(
        galleryConversationReplying,
      ),
    );

    final Rect conversation = tester.getRect(find.byType(ConversationView));
    final Rect firstStep = tester.getRect(
      find.text('Ran xcodebuild -scheme App -configuration Release').last,
    );
    expect(firstStep.top, closeTo(conversation.top, 2));
  });
}
