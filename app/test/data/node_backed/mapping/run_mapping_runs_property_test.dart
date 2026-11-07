import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/run_progress_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/random_run_json.dart';
import '../../../support/random_inputs.dart';
import '../../models/support/random_run_records.dart';
import 'support/live_run_views.dart';
import 'support/run_mapping_nodes.dart';

node.RunView _buildViewAround(
  Random random, {
  required node.Run run,
  required DateTime? linkLostAt,
}) {
  return node.RunView(
    run: run,
    progress: node.RunProgress.fromJson(randomRunProgressJson(random)),
    link: pickOne(random, node.RunnerLink.values),
    linkLostAt: linkLostAt,
  );
}

void main() {
  test('test_map_run_from_node_property_round_trips_hostile_runs', () {
    final Random random = seededRandom(73301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomLiveRun(random);

      final Run mapped = mapRunFromNode(buildNodeRun(run));

      expect(describeEveryRunField(mapped), describeEveryRunField(run));
    }
  });

  test('test_map_run_from_node_property_record_lists_are_frozen', () {
    final Random random = seededRandom(73302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = mapRunFromNode(node.Run.fromJson(randomRunJson(random)));

      expect(
        () => run.steps.add(randomRunStep(random)),
        throwsUnsupportedError,
      );
      expect(() => run.log.add(randomLogLine(random)), throwsUnsupportedError);
      expect(
        () => run.chat.add(randomChatMessage(random)),
        throwsUnsupportedError,
      );
      expect(
        () => run.loopRounds.add(randomLoopRounds(random)),
        throwsUnsupportedError,
      );
      expect(
        () => run.notes.add(randomRunNote(random)),
        throwsUnsupportedError,
      );
    }
  });

  test('test_map_run_view_from_node_property_keeps_the_run_fields', () {
    final Random random = seededRandom(73303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomLiveRun(random);
      final node.RunView view = _buildViewAround(
        random,
        run: buildNodeRun(run),
        linkLostAt: randomOptionalMoment(random),
      );

      final Run mapped = mapRunViewFromNode(view);

      expect(describeRunBesidesLink(mapped), describeRunBesidesLink(run));
    }
  });

  test('test_map_run_view_from_node_property_link_loss_comes_from_view', () {
    final Random random = seededRandom(73304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Run run = node.Run.fromJson(randomRunJson(random));
      final DateTime? viewLinkLostAt = randomOptionalMoment(random);
      final node.RunView view = _buildViewAround(
        random,
        run: run,
        linkLostAt: viewLinkLostAt,
      );

      final Run mapped = mapRunViewFromNode(view);

      expect(mapped.linkLostAt, viewLinkLostAt);
      expect(mapped.link.name, view.link.name);
    }
  });
}
