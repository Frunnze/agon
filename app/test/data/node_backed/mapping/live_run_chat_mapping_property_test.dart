import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/live_run_values.dart'
    as node;
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/random_live_json.dart';
import '../../../support/random_inputs.dart';
import '../../models/support/random_run_records.dart';
import 'support/live_run_views.dart';

ChatMessage _newChatMessage(Random random, int index) {
  final ChatMessage message = randomChatMessage(random);
  return ChatMessage(
    at: message.at,
    author: message.author,
    text: '${message.text}$newRecordMark$index',
    isError: message.isError,
    waitingToSend: message.waitingToSend,
  );
}

ChatMessage _chatMessageVariant(Random random, ChatMessage message) {
  final bool changesMoment = random.nextBool();
  final int otherAuthorIndex =
      (message.author.index + 1) % ChatAuthor.values.length;
  final ChatAuthor otherAuthor = ChatAuthor.values[otherAuthorIndex];
  return ChatMessage(
    at: changesMoment ? message.at.add(oneMicrosecond) : message.at,
    author: changesMoment ? message.author : otherAuthor,
    text: message.text,
    isError: message.isError,
    waitingToSend: message.waitingToSend,
  );
}

final DateTime _appliedAt = DateTime.utc(2026, 11, 7, 9, 30);

void main() {
  test('test_is_same_chat_message_property_redelivery_is_not_repeated', () {
    final Random random = seededRandom(72104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomLiveRunWithRecords(random);
      final List<node.RunEvent> events = <node.RunEvent>[
        for (final ChatMessage message in run.chat) buildChatEvent(message),
      ];

      final Run applied = applyLiveRunView(
        run: run,
        view: buildLiveView(events),
        at: _appliedAt,
      );

      expect(describeChat(applied.chat), describeChat(run.chat));
    }
  });

  test('test_is_same_chat_message_property_other_author_or_moment_is_new', () {
    final Random random = seededRandom(72105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomLiveRunWithRecords(random);
      final ChatMessage variant = _chatMessageVariant(
        random,
        pickOne(random, run.chat),
      );

      final Run applied = applyLiveRunView(
        run: run,
        view: buildLiveView(<node.RunEvent>[buildChatEvent(variant)]),
        at: _appliedAt,
      );

      expect(
        describeChat(applied.chat),
        describeChat(<ChatMessage>[...run.chat, variant]),
      );
    }
  });

  test('test_is_same_chat_message_property_other_text_is_a_new_message', () {
    final Random random = seededRandom(72106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomLiveRunWithRecords(random);
      final ChatMessage existing = pickOne(random, run.chat);
      final ChatMessage variant = ChatMessage(
        at: existing.at,
        author: existing.author,
        text: '${existing.text}$newRecordMark',
        isError: existing.isError,
        waitingToSend: existing.waitingToSend,
      );

      final Run applied = applyLiveRunView(
        run: run,
        view: buildLiveView(<node.RunEvent>[
          buildChatEvent(existing),
          buildChatEvent(variant),
        ]),
        at: _appliedAt,
      );

      expect(
        describeChat(applied.chat),
        describeChat(<ChatMessage>[...run.chat, variant]),
      );
    }
  });

  test('test_has_chat_message_property_new_messages_land_at_the_end', () {
    final Random random = seededRandom(72110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomLiveRun(random);
      final int newMessageCount = random.nextInt(largestNewRecordCount);
      final List<ChatMessage> newMessages = <ChatMessage>[
        for (int index = 0; index < newMessageCount; index += 1)
          _newChatMessage(random, index),
      ];

      final Run applied = applyLiveRunView(
        run: run,
        view: buildLiveView(<node.RunEvent>[
          for (final ChatMessage message in newMessages)
            buildChatEvent(message),
        ]),
        at: _appliedAt,
      );

      expect(
        describeChat(applied.chat),
        describeChat(<ChatMessage>[...run.chat, ...newMessages]),
      );
    }
  });

  test('test_has_chat_message_property_second_delivery_is_identical', () {
    final Random random = seededRandom(72111);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WatchView view = node.WatchView.fromJson(
        randomWatchViewJson(random),
      );

      final Run once = applyLiveRunView(
        run: randomLiveRun(random),
        view: view,
        at: _appliedAt,
      );
      final Run twice = applyLiveRunView(
        run: once,
        view: view,
        at: _appliedAt,
      );

      expect(describeChat(twice.chat), describeChat(once.chat));
      expect(describeLog(twice.log), describeLog(once.log));
    }
  });

  test('test_has_chat_message_property_other_events_leave_chat_alone', () {
    final Random random = seededRandom(72112);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomLiveRun(random);
      final node.WatchView view = node.WatchView.fromJson(
        randomWatchViewJson(random),
      );
      final List<node.RunEvent> chatEvents = <node.RunEvent>[
        ...view.events.whereType<node.ChatAppended>(),
      ];

      final Run applied = applyLiveRunView(
        run: run,
        view: view,
        at: _appliedAt,
      );
      final Run onlyChat = applyLiveRunView(
        run: run,
        view: buildLiveView(chatEvents),
        at: _appliedAt,
      );

      expect(describeChat(applied.chat), describeChat(onlyChat.chat));
    }
  });
}
