import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/arbitrary_json.dart';
import '../../bridge/support/decoding_outcome.dart';
import '../../bridge/support/random_run_json.dart';
import '../../support/random_inputs.dart';

void main() {
  test('test_map_step_status_from_node_property_keeps_name', () {
    for (final node.StepStatus wire in node.StepStatus.values) {
      expect(mapStepStatusFromNode(wire).name, wire.name);
    }
  });

  test('test_map_run_status_from_node_property_keeps_name', () {
    for (final node.RunStatus wire in node.RunStatus.values) {
      expect(mapRunStatusFromNode(wire).name, wire.name);
    }
  });

  test('test_map_chat_author_from_node_property_keeps_name', () {
    for (final node.ChatAuthor wire in node.ChatAuthor.values) {
      expect(mapChatAuthorFromNode(wire).name, wire.name);
    }
  });

  test('test_map_run_step_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(9601);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.RunStep wire = node.RunStep.fromJson(
        randomRunStepJson(random),
      );
      final RunStep step = mapRunStepFromNode(wire);

      expect(step.name, wire.name);
      expect(step.agentId, wire.agentId);
      expect(step.runner, wire.runner);
      expect(step.status.name, wire.status.name);
      expect(step.startedAt, wire.startedAt);
      expect(step.finishedAt, wire.finishedAt);
    }
  });

  test('test_map_log_line_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(9602);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.LogLine wire = node.LogLine.fromJson(
        randomLogLineJson(random),
      );
      final LogLine line = mapLogLineFromNode(wire);

      expect(line.at, wire.at);
      expect(line.stepName, wire.stepName);
      expect(line.text, wire.text);
      expect(line.isError, wire.isError);
    }
  });

  test('test_map_chat_message_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(9603);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ChatMessage wire = node.ChatMessage.fromJson(
        randomChatMessageJson(random),
      );
      final ChatMessage message = mapChatMessageFromNode(wire);

      expect(message.at, wire.at);
      expect(message.author.name, wire.author.name);
      expect(message.text, wire.text);
      expect(message.isError, wire.isError);
      expect(message.waitingToSend, wire.waitingToSend);
    }
  });

  test('test_map_run_failure_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(9604);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.RunFailure wire = node.RunFailure.fromJson(
        randomRunFailureJson(random),
      );
      final RunFailure failure = mapRunFailureFromNode(wire);

      expect(failure.stepName, wire.stepName);
      expect(failure.runner, wire.runner);
      expect(failure.reason, wire.reason);
      expect(failure.retryRunsOnSameRunner, wire.retryRunsOnSameRunner);
    }
  });

  test('test_map_run_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(9605);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Run wire = node.Run.fromJson(randomRunJson(random));
      final Run run = mapRunFromNode(wire);

      expect(run.id, wire.id);
      expect(run.taskId, wire.taskId);
      expect(run.number, wire.number);
      expect(run.status.name, wire.status.name);
      expect(run.steps.map((RunStep step) => step.name), <String>[
        for (final node.RunStep step in wire.steps) step.name,
      ]);
      expect(run.log.map((LogLine line) => line.text), <String>[
        for (final node.LogLine line in wire.log) line.text,
      ]);
      expect(run.chat.map((ChatMessage message) => message.text), <String>[
        for (final node.ChatMessage message in wire.chat) message.text,
      ]);
      expect(run.failure == null, wire.failure == null);
      expect(run.link.name, wire.link.name);
      expect(run.agentSession, wire.agentSession);
      expect(run.worktreeBranch, wire.worktreeBranch);
      expect(run.startedBy, wire.startedBy);
      expect(run.startedAt, wire.startedAt);
      expect(run.finishedAt, wire.finishedAt);
    }
  });

  test('test_map_run_from_node_property_malformed_json_only_format', () {
    final Random random = seededRandom(9606);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Object? mutated = mutateJson(random, randomRunJson(random));
      expect(
        attemptDecoding(() => mapRunFromNode(node.Run.fromJson(mutated))),
        isIn(DecodingOutcome.values),
      );
    }
  });
}
