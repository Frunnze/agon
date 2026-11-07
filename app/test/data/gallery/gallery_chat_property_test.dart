import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_chat.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';

final Map<String, Conversation> _conversationsByName = <String, Conversation>{
  'awaiting_approval': galleryConversationAwaitingApproval,
  'replying': galleryConversationReplying,
  'reconnecting': galleryConversationReconnecting,
};

Run _findRun(Conversation conversation) {
  return galleryRuns.singleWhere((Run run) => run.id == conversation.runId);
}

void _expectInTimeOrderUpToNow(List<ChatMessage> messages) {
  for (int index = 0; index < messages.length; index += 1) {
    final ChatMessage message = messages[index];
    expect(message.at.isAfter(galleryNow), isFalse, reason: message.text);
    if (index > 0) {
      final DateTime earlierAt = messages[index - 1].at;
      expect(message.at.isBefore(earlierAt), isFalse, reason: message.text);
    }
  }
}

void main() {
  test('test_gallery_run_chat_property_in_time_order_up_to_now', () {
    expect(galleryRunChat, isNotEmpty);
    _expectInTimeOrderUpToNow(galleryRunChat);
  });

  test('test_gallery_run_chat_property_sent_and_only_tools_fail', () {
    for (final ChatMessage message in galleryRunChat) {
      expect(message.waitingToSend, isFalse, reason: message.text);
      expect(message.text.trim(), isNotEmpty);
      if (message.isError) {
        expect(message.author, ChatAuthor.tool, reason: message.text);
      }
    }
  });

  test('test_gallery_run_chat_property_is_the_running_run_chat', () {
    final Run run = _findRun(galleryConversationAwaitingApproval);

    expect(run.chat, galleryRunChat);
    expect(galleryRunChat.last.author, ChatAuthor.agent);
    expect(
      () => galleryRunChat.add(galleryRunChat.first),
      throwsUnsupportedError,
    );
  });

  for (final MapEntry<String, Conversation> named
      in _conversationsByName.entries) {
    final String name = named.key;
    final Conversation conversation = named.value;

    test('test_gallery_conversation_${name}_property_belongs_to_a_live_'
        'run', () {
      final Run run = _findRun(conversation);

      expect(run.status, RunStatus.running);
      expect(run.agentSession, isNotNull);
    });

    test('test_gallery_conversation_${name}_property_link_loss_has_a_'
        'moment', () {
      final DateTime? linkLostAt = conversation.linkLostAt;
      final bool isUnreachable = conversation.link == RunnerLink.unreachable;

      expect(linkLostAt != null, isUnreachable);
      if (linkLostAt != null) {
        expect(linkLostAt.isAfter(galleryNow), isFalse);
      }
    });

    test('test_gallery_conversation_${name}_property_messages_in_time_'
        'order', () {
      _expectInTimeOrderUpToNow(conversation.messages);
    });
  }

  test('test_gallery_conversation_awaiting_approval_property_mirrors_the_'
      'run', () {
    final Run run = _findRun(galleryConversationAwaitingApproval);

    expect(galleryConversationAwaitingApproval.messages, run.chat);
    expect(galleryConversationAwaitingApproval.link, run.link);
    expect(
      galleryConversationAwaitingApproval.agentActivity,
      AgentActivity.idle,
    );
  });

  test('test_gallery_conversation_replying_property_streams_the_last_'
      'reply', () {
    final List<ChatMessage> streaming = galleryConversationReplying.messages;
    final List<ChatMessage> finished = galleryRunChat;
    final int lastIndex = finished.length - 1;

    expect(streaming.length, finished.length);
    for (int index = 0; index < lastIndex; index += 1) {
      expect(streaming[index].text, finished[index].text);
      expect(streaming[index].at, finished[index].at);
    }
    expect(finished[lastIndex].text, startsWith(streaming[lastIndex].text));
    expect(
      streaming[lastIndex].text.length,
      lessThan(finished[lastIndex].text.length),
    );
    expect(galleryConversationReplying.agentActivity, AgentActivity.replying);
  });

  test('test_gallery_conversation_reconnecting_property_queues_after_the_'
      'link_is_lost', () {
    final Conversation conversation = galleryConversationReconnecting;
    final DateTime linkLostAt = conversation.linkLostAt!;
    final List<ChatMessage> waiting = <ChatMessage>[
      for (final ChatMessage message in conversation.messages)
        if (message.waitingToSend) message,
    ];
    final List<ChatMessage> sent = <ChatMessage>[
      for (final ChatMessage message in conversation.messages)
        if (!message.waitingToSend) message,
    ];

    expect(waiting, isNotEmpty);
    expect(sent, galleryRunChat);
    for (final ChatMessage message in waiting) {
      expect(message.author, ChatAuthor.you);
      expect(message.at.isBefore(linkLostAt), isFalse);
    }
    expect(sent.last.at.isAfter(linkLostAt), isFalse);
  });
}
