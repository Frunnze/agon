import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_chat.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../support/app_harness.dart';
import '../support/chat_composer_harness.dart';
import '../support/message_keys.dart';
import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const ChatRoute _chatRoute = ChatRoute(GalleryRunIds.release42);
const List<String> _surroundingBlanks = <String>['', ' ', '\n', ' \t\n '];

String _randomTypedMessage(Random random) {
  final String blankBefore = pickOne(random, _surroundingBlanks);
  final String blankAfter = pickOne(random, _surroundingBlanks);
  return '$blankBefore${randomText(random)}$blankAfter';
}

int _countMessages(AppDependencies dependencies) {
  return dependencies.chatRepository
      .findConversation(GalleryRunIds.release42)
      .messages
      .length;
}

void main() {
  testWidgets('test_chat_composer_property_enter_sends_trimmed_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(6101);
    final List<String> sentMessages = <String>[];

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TargetPlatform platform = pickOne(random, computerPlatformList);
      await pumpComposer(
        tester,
        platform: platform,
        width: desktopWidth,
        sentMessages: sentMessages,
      );
      final String typedMessage = _randomTypedMessage(random);
      await tester.enterText(findComposerField(), typedMessage);
      sentMessages.clear();

      final bool isHandled = await pressEnter(tester);

      final String trimmedMessage = typedMessage.trim();
      final EditableText input = readComposerInput(tester);
      final String reason = '$platform "$typedMessage"';
      expect(isHandled, isTrue, reason: reason);
      expect(input.focusNode.hasFocus, isTrue, reason: reason);
      if (trimmedMessage.isEmpty) {
        expect(sentMessages, isEmpty, reason: reason);
        expect(input.controller.text, typedMessage, reason: reason);
      } else {
        expect(sentMessages, <String>[trimmedMessage], reason: reason);
        expect(input.controller.text, isEmpty, reason: reason);
      }
    }
  });

  testWidgets('test_chat_composer_property_shift_enter_keeps_the_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(6102);
    final List<String> sentMessages = <String>[];

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TargetPlatform platform = pickOne(random, computerPlatformList);
      await pumpComposer(
        tester,
        platform: platform,
        width: desktopWidth,
        sentMessages: sentMessages,
      );
      final String typedMessage = _randomTypedMessage(random);
      await tester.enterText(findComposerField(), typedMessage);

      final bool isHandled = await pressShiftEnter(tester);

      final String reason = '$platform "$typedMessage"';
      expect(isHandled, isFalse, reason: reason);
      expect(sentMessages, isEmpty, reason: reason);
      expect(
        readComposerInput(tester).controller.text,
        typedMessage,
        reason: reason,
      );
    }
  });

  testWidgets(
    'test_chat_composer_property_enter_is_a_new_line_onphonePlatformList',
    (WidgetTester tester) async {
      final Random random = seededRandom(6103);
      final List<String> sentMessages = <String>[];

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TargetPlatform platform = pickOne(random, phonePlatformList);
        await pumpComposer(
          tester,
          platform: platform,
          width: phoneWidth,
          sentMessages: sentMessages,
        );
        final String typedMessage = _randomTypedMessage(random);
        await tester.enterText(findComposerField(), typedMessage);

        final bool isHandled = await pressEnter(tester);

        final String reason = '$platform "$typedMessage"';
        expect(isHandled, isFalse, reason: reason);
        expect(sentMessages, isEmpty, reason: reason);
        expect(
          readComposerInput(tester).controller.text,
          typedMessage,
          reason: reason,
        );
      }
    },
  );

  testWidgets('test_chat_composer_property_composing_enter_does_not_send', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(6104);
    final List<String> sentMessages = <String>[];

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TargetPlatform platform = pickOne(random, computerPlatformList);
      await pumpComposer(
        tester,
        platform: platform,
        width: desktopWidth,
        sentMessages: sentMessages,
      );
      final String composedText = 'にほん${randomText(random)}';
      await tester.showKeyboard(findComposerField());
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: composedText,
          selection: TextSelection.collapsed(offset: composedText.length),
          composing: TextRange(start: 0, end: composedText.length),
        ),
      );
      await tester.pump();

      final bool isHandled = await pressEnter(tester);

      final String reason = '$platform "$composedText"';
      expect(isHandled, isFalse, reason: reason);
      expect(sentMessages, isEmpty, reason: reason);
    }
  });

  testWidgets('test_chat_composer_property_focused_on_open_and_after_send', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildDependenciesWithConversation(
      galleryConversationReplying,
    );
    await pumpApp(
      tester,
      size: windowSizeOn(defaultTargetPlatform),
      route: _chatRoute,
      dependencies: dependencies,
    );
    final int messageCount = _countMessages(dependencies);
    expect(readComposerInput(tester).focusNode.hasFocus, isTrue);

    await tester.enterText(findComposerField(), '  Rebuild it please \n');
    await tester.tap(find.text('Send'));
    await pumpFrames(tester);

    expect(readComposerInput(tester).focusNode.hasFocus, isTrue);
    expect(_countMessages(dependencies), messageCount + 1);
    final String lastMessage = dependencies.chatRepository
        .findConversation(GalleryRunIds.release42)
        .messages
        .last
        .text;
    expect(lastMessage, 'Rebuild it please');
  }, variant: onPhoneAndDesktop);
}
