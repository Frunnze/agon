import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/rules/run_step_progress.dart';

import '../../../bridge/support/node_wire_names.dart';
import '../../../bridge/support/random_run_json.dart';
import '../../../support/random_inputs.dart';
import '../../models/support/domain_model_properties.dart';
import '../../models/support/random_run_records.dart';
import 'support/live_run_views.dart';
import 'support/run_mapping_nodes.dart';

const Set<String> _rustFinishedRunStatuses = <String>{
  'done',
  'failed',
  'cancelled',
};

const Set<String> _rustFinishedStepStatuses = <String>{
  'done',
  'failed',
  'skipped',
};

void main() {
  testNodeEnumMappingProperties(
    const NodeEnumMapping<StepStatus, node.StepStatus>(
      testNamePrefix: 'test_map_step_status_from_node_property',
      choices: StepStatus.values,
      nodeChoices: node.StepStatus.values,
      mapFromNode: mapStepStatusFromNode,
    ),
  );

  testNodeEnumMappingProperties(
    const NodeEnumMapping<RunStatus, node.RunStatus>(
      testNamePrefix: 'test_map_run_status_from_node_property',
      choices: RunStatus.values,
      nodeChoices: node.RunStatus.values,
      mapFromNode: mapRunStatusFromNode,
    ),
  );

  testNodeEnumMappingProperties(
    const NodeEnumMapping<ChatAuthor, node.ChatAuthor>(
      testNamePrefix: 'test_map_chat_author_from_node_property',
      choices: ChatAuthor.values,
      nodeChoices: node.ChatAuthor.values,
      mapFromNode: mapChatAuthorFromNode,
    ),
  );

  test('test_map_step_status_from_node_property_finished_matches_rust', () {
    for (final String wireName in nodeStepStatuses) {
      final StepStatus status = mapStepStatusFromNode(
        node.StepStatus.decode(wireName),
      );

      expect(
        isStepFinished(status),
        _rustFinishedStepStatuses.contains(wireName),
      );
    }
  });

  test('test_map_run_status_from_node_property_finished_matches_rust', () {
    for (final String wireName in nodeRunStatuses) {
      final RunStatus status = mapRunStatusFromNode(
        node.RunStatus.decode(wireName),
      );

      expect(
        isRunFinished(status),
        _rustFinishedRunStatuses.contains(wireName),
      );
    }
  });

  test('test_map_log_line_from_node_property_round_trips_hostile_lines', () {
    final Random random = seededRandom(73101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final LogLine line = randomLogLine(random);

      final LogLine mapped = mapLogLineFromNode(buildNodeLogLine(line));

      expect(describeLog(<LogLine>[mapped]), describeLog(<LogLine>[line]));
    }
  });

  test('test_map_log_line_from_node_property_commutes_with_node_json', () {
    final Random random = seededRandom(73102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.LogLine wire = node.LogLine.fromJson(
        randomLogLineJson(random),
      );
      final node.LogLine reread = node.LogLine.fromJson(wire.toJson());

      final LogLine mapped = mapLogLineFromNode(wire);
      final LogLine mappedReread = mapLogLineFromNode(reread);

      expect(
        describeLog(<LogLine>[mappedReread]),
        describeLog(<LogLine>[mapped]),
      );
    }
  });

  test('test_map_chat_message_from_node_property_round_trips_hostile', () {
    final Random random = seededRandom(73103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatMessage message = randomChatMessage(random);

      final ChatMessage mapped = mapChatMessageFromNode(
        buildNodeChatMessage(message),
      );

      expect(
        describeChat(<ChatMessage>[mapped]),
        describeChat(<ChatMessage>[message]),
      );
    }
  });

  test('test_map_chat_message_from_node_property_flags_stay_apart', () {
    final Random random = seededRandom(73104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatMessage message = randomChatMessage(random);
      final bool isError = random.nextBool();
      final bool waitingToSend = !isError;
      final node.ChatMessage wire = node.ChatMessage(
        at: message.at,
        author: node.ChatAuthor.values.byName(message.author.name),
        text: message.text,
        isError: isError,
        waitingToSend: waitingToSend,
      );

      final ChatMessage mapped = mapChatMessageFromNode(wire);

      expect(mapped.isError, isError);
      expect(mapped.waitingToSend, waitingToSend);
    }
  });

  test('test_map_run_failure_from_node_property_round_trips_hostile', () {
    final Random random = seededRandom(73105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunFailure failure = randomRunFailure(random);

      final RunFailure mapped = mapRunFailureFromNode(
        buildNodeRunFailure(failure),
      );

      expect(describeRunFailure(mapped), describeRunFailure(failure));
    }
  });

  test('test_map_run_failure_from_node_property_commutes_with_node_json', () {
    final Random random = seededRandom(73106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.RunFailure wire = node.RunFailure.fromJson(
        randomRunFailureJson(random),
      );
      final node.RunFailure reread = node.RunFailure.fromJson(wire.toJson());

      final RunFailure mapped = mapRunFailureFromNode(wire);
      final RunFailure mappedReread = mapRunFailureFromNode(reread);

      expect(describeRunFailure(mappedReread), describeRunFailure(mapped));
    }
  });
}
