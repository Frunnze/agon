import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/chat_inputs.dart';
import 'support/notification_counter.dart';

const String _typePrefix = 'test_fake_chat_repository';
const int _longestSequence = 10;
const RunId _unseededRunId = RunId('${otherChatRunPrefix}0');

void main() {
  test('${_typePrefix}_constructor_property_finds_every_seeded_'
      'conversation', () {
    final Random random = seededRandom(64001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Conversation> seeded = randomConversations(random);

      final FakeChatRepository repository = FakeChatRepository(
        conversations: seeded,
        taskRepository: buildChatTaskRepository(random),
        clock: FixedClock(randomUtcMoment(random)),
      );

      for (final Conversation conversation in seeded) {
        final Conversation found = repository.findConversation(
          conversation.runId,
        );
        expect(identical(found, conversation), isTrue);
      }
    }
  });

  test('${_typePrefix}_constructor_property_ignores_later_caller_'
      'changes', () {
    final Random random = seededRandom(64002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Conversation> seeded = randomConversations(random);
      final List<Conversation> atConstruction = List<Conversation>.of(seeded);
      final FakeTaskRepository runs = buildChatTaskRepository(random);
      final FakeChatRepository repository = FakeChatRepository(
        conversations: seeded,
        taskRepository: runs,
        clock: FixedClock(randomUtcMoment(random)),
      );

      seeded.add(randomConversation(random, _unseededRunId));
      seeded.removeAt(0);
      if (random.nextBool()) {
        seeded.clear();
      }

      for (final Conversation conversation in atConstruction) {
        final Conversation found = repository.findConversation(
          conversation.runId,
        );
        expect(identical(found, conversation), isTrue);
      }
      expect(
        repository.findConversation(_unseededRunId).messages,
        orderedEquals(runs.findRun(_unseededRunId).chat),
      );
    }
  });

  test('${_typePrefix}_constructor_property_unknown_runs_are_not_'
      'found', () {
    final Random random = seededRandom(64003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeChatRepository repository = FakeChatRepository(
        conversations: randomConversations(random),
        taskRepository: buildChatTaskRepository(random),
        clock: FixedClock(randomUtcMoment(random)),
      );
      final RunId runId = randomMissingChatRunId(random);

      expect(
        () => repository.findConversation(runId),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('${_typePrefix}_find_conversation_property_reading_changes_'
      'nothing', () {
    final Random random = seededRandom(64004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Conversation> seeded = randomConversations(random);
      final FakeChatRepository repository = FakeChatRepository(
        conversations: seeded,
        taskRepository: buildChatTaskRepository(random),
        clock: FixedClock(randomUtcMoment(random)),
      );
      final NotificationCounter notifications = NotificationCounter();
      repository.addListener(notifications.record);
      final RunId runId = pickChatRunId(random, seeded);

      final Conversation firstRead = repository.findConversation(runId);
      final Conversation secondRead = repository.findConversation(runId);

      expectSameConversation(secondRead, firstRead);
      expect(notifications.count, 0);
    }
  });

  test('${_typePrefix}_find_conversation_property_ends_with_every_sent_'
      'message', () async {
    final Random random = seededRandom(64005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Conversation> seeded = randomConversations(random);
      final FakeChatRepository repository = FakeChatRepository(
        conversations: seeded,
        taskRepository: buildChatTaskRepository(random),
        clock: FixedClock(randomUtcMoment(random)),
      );
      final RunId runId = pickChatRunId(random, seeded);
      final List<String> before = listChatTexts(
        repository.findConversation(runId).messages,
      );
      final List<String> sentTexts = <String>[];
      final int count = random.nextInt(_longestSequence);

      for (int message = 0; message < count; message += 1) {
        final String text = randomChatMessageText(random);
        await repository.sendMessage(runId, text);
        sentTexts.add(text.trim());
      }

      expect(
        listChatTexts(repository.findConversation(runId).messages),
        orderedEquals(<String>[...before, ...sentTexts]),
      );
    }
  });
}
