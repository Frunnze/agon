import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/run_conversation.dart';

import '../../support/random_inputs.dart';
import 'support/chat_inputs.dart';
import 'support/notification_counter.dart';

const String _typePrefix = 'test_fake_chat_repository';
const String _runKind = 'run';

typedef _ChatFixture = ({
  FakeChatRepository repository,
  FakeTaskRepository runs,
  List<Conversation> seeded,
  NotificationCounter notifications,
});

_ChatFixture _buildFixture(Random random) {
  final List<Conversation> seeded = randomConversations(random);
  final FakeTaskRepository runs = buildChatTaskRepository(random);
  final FakeChatRepository repository = FakeChatRepository(
    conversations: seeded,
    taskRepository: runs,
    clock: FixedClock(randomUtcMoment(random)),
  );
  final NotificationCounter notifications = NotificationCounter();
  repository.addListener(notifications.record);
  return (
    repository: repository,
    runs: runs,
    seeded: seeded,
    notifications: notifications,
  );
}

Matcher _isMissingRun(RunId runId) {
  return isA<RecordNotFound>()
      .having((RecordNotFound e) => e.kind, 'kind', _runKind)
      .having((RecordNotFound e) => e.identifier, 'identifier', runId.value);
}

void _expectSeedsUnchanged(_ChatFixture fixture) {
  for (final Conversation conversation in fixture.seeded) {
    final Conversation found = fixture.repository.findConversation(
      conversation.runId,
    );
    expect(identical(found, conversation), isTrue);
  }
}

List<Conversation> _withDuplicate(Random random, List<Conversation> seeded) {
  final Conversation original = pickOne(random, seeded);
  final List<Conversation> duplicated = List<Conversation>.of(seeded);
  final int position = random.nextInt(duplicated.length + 1);
  duplicated.insert(position, randomConversation(random, original.runId));
  return duplicated;
}

void main() {
  test('${_typePrefix}_find_conversation_property_unknown_run_is_record_'
      'not_found', () {
    final Random random = seededRandom(66101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ChatFixture fixture = _buildFixture(random);
      final RunId runId = randomMissingChatRunId(random);

      expect(
        () => fixture.repository.findConversation(runId),
        throwsA(_isMissingRun(runId)),
      );

      expect(fixture.notifications.count, 0);
      _expectSeedsUnchanged(fixture);
    }
  });

  test('${_typePrefix}_find_conversation_property_unseeded_run_shows_the_'
      'run_chat', () {
    final Random random = seededRandom(66102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ChatFixture fixture = _buildFixture(random);
      final RunId runId = RunId(
        '$otherChatRunPrefix${random.nextInt(otherChatRunCount)}',
      );
      final Run run = fixture.runs.findRun(runId);

      final Conversation found = fixture.repository.findConversation(runId);

      expectSameConversation(found, buildConversationFromRun(run));
    }
  });

  test('${_typePrefix}_send_message_property_unknown_run_is_refused_and_'
      'changes_nothing', () async {
    final Random random = seededRandom(66103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ChatFixture fixture = _buildFixture(random);
      final RunId runId = randomMissingChatRunId(random);

      await expectLater(
        fixture.repository.sendMessage(runId, randomChatMessageText(random)),
        throwsA(_isMissingRun(runId)),
      );

      expect(fixture.notifications.count, 0);
      expect(
        () => fixture.repository.findConversation(runId),
        throwsA(_isMissingRun(runId)),
      );
      _expectSeedsUnchanged(fixture);
    }
  });

  test('${_typePrefix}_send_message_property_blank_text_is_refused_before_'
      'the_run_lookup', () async {
    final Random random = seededRandom(66104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ChatFixture fixture = _buildFixture(random);
      final String blank =
          pickOne(random, blankChatTexts) + pickOne(random, blankChatTexts);

      await expectLater(
        fixture.repository.sendMessage(randomMissingChatRunId(random), blank),
        throwsArgumentError,
      );

      expect(fixture.notifications.count, 0);
    }
  });

  test('${_typePrefix}_send_message_property_unseeded_run_continues_the_'
      'run_chat', () async {
    final Random random = seededRandom(66105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ChatFixture fixture = _buildFixture(random);
      final RunId runId = RunId(
        '$otherChatRunPrefix${random.nextInt(otherChatRunCount)}',
      );
      final List<String> expectedTexts = listChatTexts(
        fixture.runs.findRun(runId).chat,
      );
      final String text = randomChatMessageText(random);

      await fixture.repository.sendMessage(runId, text);
      expectedTexts.add(text.trim());

      final Conversation after = fixture.repository.findConversation(runId);
      expect(listChatTexts(after.messages), orderedEquals(expectedTexts));
      expect(fixture.notifications.count, 1);
    }
  });

  test('${_typePrefix}_constructor_property_refuses_duplicate_run_ids', () {
    final Random random = seededRandom(66106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Conversation> seeded = randomConversations(random);
      if (seeded.isEmpty) {
        continue;
      }
      final List<Conversation> duplicated = _withDuplicate(random, seeded);

      expect(
        () => FakeChatRepository(
          conversations: duplicated,
          taskRepository: buildChatTaskRepository(random),
          clock: FixedClock(randomUtcMoment(random)),
        ),
        throwsArgumentError,
      );
    }
  });

  test('${_typePrefix}_constructor_property_names_the_duplicate_run', () {
    final Random random = seededRandom(66107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunId runId = RunId(randomText(random));
      final List<Conversation> duplicated = <Conversation>[
        randomConversation(random, runId),
        randomConversation(random, runId),
      ];

      expect(
        () => FakeChatRepository(
          conversations: duplicated,
          taskRepository: buildChatTaskRepository(random),
          clock: FixedClock(randomUtcMoment(random)),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.invalidValue,
            'invalidValue',
            runId.value,
          ),
        ),
      );
    }
  });

  test('${_typePrefix}_constructor_property_unique_runs_in_any_order_are_'
      'kept', () {
    final Random random = seededRandom(66108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Conversation> seeded = randomConversations(random);
      seeded.shuffle(random);

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
}
