import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/rules/run_conversation.dart';

import '../../bridge/support/random_run_json.dart';
import '../../support/random_inputs.dart';
import 'support/chat_repository_rig.dart';

void _expectConversationOf(Conversation conversation, Run run) {
  final Conversation expected = buildConversationFromRun(run);
  expect(conversation.runId, run.id);
  expect(conversation.messages, expected.messages);
  expect(conversation.link, expected.link);
  expect(conversation.linkLostAt, expected.linkLostAt);
  expect(conversation.agentActivity, expected.agentActivity);
}

void main() {
  test(
    'test_node_backed_chat_repository_constructor_property_reads_its_source',
    () {
      final Random random = seededRandom(76601);
      for (int i = 0; i < propertyIterations; i += 1) {
        final ChatRig fixture = buildChatRig(random);

        for (final Run run in fixture.runSource.runs.values) {
          _expectConversationOf(fixture.chat.findConversation(run.id), run);
        }
        expect(fixture.node.commands, isEmpty);
      }
    },
  );

  test(
    'test_node_backed_chat_repository_constructor_property_sends_where_shown',
    () async {
      final Random random = seededRandom(76602);
      for (int i = 0; i < propertyIterations; i += 1) {
        final ChatRig fixture = buildChatRig(random);
        final List<Workspace> workspaces = fixture.workspaces.listWorkspaces();
        await fixture.workspaces.switchWorkspace(
          pickOne(random, workspaces).id,
        );
        final RunId runId = pickOne(
          random,
          fixture.runSource.runs.keys.toList(),
        );

        await fixture.chat.sendMessage(runId, 'hello ${randomText(random)}');

        final JsonObject sent = fixture.node.commands.single;
        expect(sent['command'], 'send_chat_message');
        expect(
          sent['workspace_id'],
          fixture.workspaces.currentWorkspace().id.value,
        );
        expect(sent['run_id'], runId.value);
        expect(fixture.runSource.refreshedRunIds, <RunId>[runId]);
      }
    },
  );

  test(
    'test_node_backed_chat_repository_constructor_property_isolates_sources',
    () async {
      final Random random = seededRandom(76603);
      for (int i = 0; i < propertyIterations; i += 1) {
        final ChatRig first = buildChatRig(random);
        final ChatRig second = buildChatRig(random);
        final RunId runId = first.runSource.runs.keys.first;

        await first.chat.sendMessage(runId, 'only here');

        expect(first.node.commands.length, 1);
        expect(second.node.commands, isEmpty);
        expect(second.runSource.refreshedRunIds, isEmpty);
      }
    },
  );

  test('test_find_conversation_property_follows_the_newest_run', () {
    final Random random = seededRandom(76604);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRig fixture = buildChatRig(random);
      final RunId runId = pickOne(
        random,
        fixture.runSource.runs.keys.toList(),
      );
      final Map<String, Object?> newestJson = <String, Object?>{
        ...randomRunJson(random),
        'id': runId.value,
      };
      final Run newest = mapRunFromNode(node.Run.fromJson(newestJson));

      fixture.chat.findConversation(runId);
      fixture.runSource.storeRun(newest);

      _expectConversationOf(fixture.chat.findConversation(runId), newest);
    }
  });

  test('test_find_conversation_property_is_stable_without_changes', () {
    final Random random = seededRandom(76605);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRig fixture = buildChatRig(random);
      final RunId runId = pickOne(
        random,
        fixture.runSource.runs.keys.toList(),
      );

      final Conversation first = fixture.chat.findConversation(runId);
      final Conversation second = fixture.chat.findConversation(runId);

      expect(second.runId, first.runId);
      expect(second.messages, first.messages);
      expect(second.agentActivity, first.agentActivity);
    }
  });
}
