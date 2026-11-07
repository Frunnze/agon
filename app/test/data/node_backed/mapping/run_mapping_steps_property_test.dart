import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/run_round_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/random_branching_json.dart';
import '../../../bridge/support/random_run_json.dart';
import '../../../support/random_inputs.dart';
import '../../models/support/random_run_records.dart';
import 'support/live_run_views.dart';
import 'support/run_mapping_nodes.dart';

const int _largestRoundCount = 1 << 31;

void main() {
  test('test_map_earlier_round_from_node_property_round_trips_hostile', () {
    final Random random = seededRandom(73201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EarlierRound round = randomEarlierRound(random);

      final EarlierRound mapped = mapEarlierRoundFromNode(
        buildNodeEarlierRound(round),
      );

      expect(describeEarlierRound(mapped), describeEarlierRound(round));
    }
  });

  test('test_map_earlier_round_from_node_property_commutes_with_json', () {
    final Random random = seededRandom(73202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.EarlierRound wire = node.EarlierRound.fromJson(
        randomEarlierRoundJson(random),
      );
      final node.EarlierRound reread = node.EarlierRound.fromJson(
        wire.toJson(),
      );

      final EarlierRound mapped = mapEarlierRoundFromNode(wire);
      final EarlierRound mappedReread = mapEarlierRoundFromNode(reread);

      expect(describeEarlierRound(mappedReread), describeEarlierRound(mapped));
    }
  });

  test('test_map_earlier_round_from_node_property_step_keeps_round_order', () {
    final Random random = seededRandom(73203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.RunStep wire = node.RunStep.fromJson(
        randomRunStepJson(random),
      );

      final RunStep step = mapRunStepFromNode(wire);

      expect(
        <ShownRecord>[
          for (final EarlierRound round in step.earlierRounds)
            describeEarlierRound(round),
        ],
        <ShownRecord>[
          for (final node.EarlierRound round in wire.earlierRounds)
            describeEarlierRound(mapEarlierRoundFromNode(round)),
        ],
      );
    }
  });

  test('test_map_run_step_from_node_property_round_trips_hostile_steps', () {
    final Random random = seededRandom(73204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunStep step = randomRunStep(random);

      final RunStep mapped = mapRunStepFromNode(buildNodeRunStep(step));

      expect(describeWholeStep(mapped), describeWholeStep(step));
    }
  });

  test('test_map_run_step_from_node_property_earlier_rounds_are_frozen', () {
    final Random random = seededRandom(73205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunStep step = mapRunStepFromNode(
        node.RunStep.fromJson(randomRunStepJson(random)),
      );

      expect(
        () => step.earlierRounds.add(randomEarlierRound(random)),
        throwsUnsupportedError,
      );
    }
  });

  test('test_map_loop_rounds_from_node_property_round_trips_hostile', () {
    final Random random = seededRandom(73206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final LoopRounds loopRounds = randomLoopRounds(random);

      final LoopRounds mapped = mapLoopRoundsFromNode(
        buildNodeLoopRounds(loopRounds),
      );

      expect(describeLoopRounds(mapped), describeLoopRounds(loopRounds));
    }
  });

  test('test_map_loop_rounds_from_node_property_from_and_to_stay_apart', () {
    final Random random = seededRandom(73207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String from = 'from ${randomText(random)}';
      final String to = 'to ${randomText(random)}';
      final int rounds = random.nextInt(_largestRoundCount);

      final LoopRounds mapped = mapLoopRoundsFromNode(
        node.LoopRounds(from: from, to: to, rounds: rounds),
      );

      expect(describeLoopRounds(mapped), <Object?>[from, to, rounds]);
    }
  });

  test('test_map_loop_rounds_from_node_property_commutes_with_json', () {
    final Random random = seededRandom(73208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.LoopRounds wire = node.LoopRounds.fromJson(
        randomLoopRoundsJson(random),
      );
      final node.LoopRounds reread = node.LoopRounds.fromJson(wire.toJson());

      expect(
        describeLoopRounds(mapLoopRoundsFromNode(reread)),
        describeLoopRounds(mapLoopRoundsFromNode(wire)),
      );
    }
  });

  test('test_map_run_note_from_node_property_round_trips_hostile_notes', () {
    final Random random = seededRandom(73209);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunNote note = randomRunNote(random);

      final RunNote mapped = mapRunNoteFromNode(buildNodeRunNote(note));

      expect(describeRunNote(mapped), describeRunNote(note));
    }
  });

  test('test_map_run_note_from_node_property_commutes_with_json', () {
    final Random random = seededRandom(73210);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.RunNote wire = node.RunNote.fromJson(
        randomRunNoteJson(random),
      );
      final node.RunNote reread = node.RunNote.fromJson(wire.toJson());

      expect(
        describeRunNote(mapRunNoteFromNode(reread)),
        describeRunNote(mapRunNoteFromNode(wire)),
      );
    }
  });

  test('test_map_run_note_from_node_property_run_keeps_note_order', () {
    final Random random = seededRandom(73211);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomLiveRun(random);

      final Run mapped = mapRunFromNode(buildNodeRun(run));

      expect(
        <ShownRecord>[
          for (final RunNote note in mapped.notes) describeRunNote(note),
        ],
        <ShownRecord>[
          for (final RunNote note in run.notes) describeRunNote(note),
        ],
      );
    }
  });
}
