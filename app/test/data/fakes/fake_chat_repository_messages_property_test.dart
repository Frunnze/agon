import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import 'support/chat_inputs.dart';
import 'support/notification_counter.dart';

const String _typePrefix = 'test_fake_chat_repository';
const int _longestSequence = 10;

void main() {
  test('${_typePrefix}_send_message_property_follows_the_conversation_'
      'model', () async {
    final Random random = seededRandom(64006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Conversation> seeded = randomConversations(random);
      final FakeChatRepository repository = FakeChatRepository(
        conversations: seeded,
        clock: FixedClock(randomUtcMoment(random)),
      );
      final Map<RunId, Conversation> startedWith = <RunId, Conversation>{};
      final Map<RunId, List<String>> expectedTexts = <RunId, List<String>>{};
      final int count = random.nextInt(_longestSequence);

      for (int message = 0; message < count; message += 1) {
        final RunId runId = pickChatRunId(random, seeded);
        final Conversation current = repository.findConversation(runId);
        startedWith.putIfAbsent(runId, () => current);
        expectedTexts.putIfAbsent(
          runId,
          () => listChatTexts(current.messages),
        );
        final String text = randomChatMessageText(random);
        await repository.sendMessage(runId, text);
        expectedTexts[runId]!.add(text.trim());
      }

      for (final MapEntry<RunId, List<String>> expected
          in expectedTexts.entries) {
        final Conversation after = repository.findConversation(expected.key);
        final Conversation before = startedWith[expected.key]!;
        expect(listChatTexts(after.messages), orderedEquals(expected.value));
        expect(after.link, before.link);
        expect(after.linkLostAt, before.linkLostAt);
        expect(after.agentActivity, before.agentActivity);
      }
      for (final Conversation untouched in seeded) {
        if (!expectedTexts.containsKey(untouched.runId)) {
          final Conversation found = repository.findConversation(
            untouched.runId,
          );
          expect(identical(found, untouched), isTrue);
        }
      }
    }
  });

  test('${_typePrefix}_send_message_property_stamps_the_clock_and_'
      'this_person', () async {
    final Random random = seededRandom(64007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Conversation> seeded = randomConversations(random);
      final DateTime moment = randomUtcMoment(random);
      final FakeChatRepository repository = FakeChatRepository(
        conversations: seeded,
        clock: FixedClock(moment),
      );
      final NotificationCounter notifications = NotificationCounter();
      repository.addListener(notifications.record);
      final RunId runId = pickChatRunId(random, seeded);
      final RunnerLink link = repository.findConversation(runId).link;
      final String text = randomChatMessageText(random);

      final ChatMessage sent = await repository.sendMessage(runId, text);

      expect(sent.at, moment);
      expect(sent.author, ChatAuthor.you);
      expect(sent.text, text.trim());
      expect(sent.isError, isFalse);
      expect(sent.waitingToSend, link == RunnerLink.unreachable);
      final List<ChatMessage> messages = repository
          .findConversation(runId)
          .messages;
      expect(identical(messages.last, sent), isTrue);
      expect(notifications.count, 1);
    }
  });

  test('${_typePrefix}_send_message_property_blank_text_changes_'
      'nothing', () async {
    final Random random = seededRandom(64008);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Conversation> seeded = randomConversations(random);
      final FakeChatRepository repository = FakeChatRepository(
        conversations: seeded,
        clock: FixedClock(randomUtcMoment(random)),
      );
      final NotificationCounter notifications = NotificationCounter();
      repository.addListener(notifications.record);
      final RunId runId = pickChatRunId(random, seeded);
      final Conversation before = repository.findConversation(runId);
      final String blank =
          pickOne(random, blankChatTexts) + pickOne(random, blankChatTexts);

      await expectLater(
        repository.sendMessage(runId, blank),
        throwsArgumentError,
      );

      expectSameConversation(repository.findConversation(runId), before);
      expect(notifications.count, 0);
    }
  });
}
