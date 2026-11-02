import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/live_run_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_progress_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/random_live_json.dart';
import '../../bridge/support/random_run_json.dart';
import '../../support/random_inputs.dart';

Run _randomRun(Random random) {
  return mapRunFromNode(node.Run.fromJson(randomRunJson(random)));
}

node.WatchView _randomWatchView(Random random) {
  return node.WatchView.fromJson(randomWatchViewJson(random));
}

int _countEvents<Event extends node.RunEvent>(node.WatchView view) {
  return view.events.whereType<Event>().length;
}

void main() {
  test('test_apply_live_run_view_property_takes_the_live_link', () {
    final Random random = seededRandom(10071);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WatchView view = _randomWatchView(random);
      final Run applied = applyLiveRunView(
        run: _randomRun(random),
        view: view,
      );

      expect(applied.link.name, view.link.name);
      expect(applied.linkLostAt, view.linkLostAt);
    }
  });

  test('test_apply_live_run_view_property_appends_new_lines_in_order', () {
    final Random random = seededRandom(10072);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _randomRun(random);
      final node.WatchView view = _randomWatchView(random);
      final Run applied = applyLiveRunView(run: run, view: view);

      expect(applied.log.sublist(0, run.log.length), run.log);
      expect(applied.chat.sublist(0, run.chat.length), run.chat);
      expect(
        applied.log.length,
        lessThanOrEqualTo(
          run.log.length + _countEvents<node.LogAppended>(view),
        ),
      );
      expect(
        applied.chat.length,
        lessThanOrEqualTo(
          run.chat.length + _countEvents<node.ChatAppended>(view),
        ),
      );
      expect(applied.id, run.id);
      expect(applied.steps.length, run.steps.length);
    }
  });

  test('test_apply_live_run_view_property_second_delivery_adds_nothing', () {
    final Random random = seededRandom(10073);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WatchView view = _randomWatchView(random);
      final Run once = applyLiveRunView(run: _randomRun(random), view: view);
      final Run twice = applyLiveRunView(run: once, view: view);

      expect(twice.log.length, once.log.length);
      expect(twice.chat.length, once.chat.length);
    }
  });

  test('test_apply_live_run_view_property_step_status_follows_events', () {
    final Random random = seededRandom(10074);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _randomRun(random);
      if (run.steps.isEmpty) {
        continue;
      }
      final RunStep step = pickOne(random, run.steps);
      final node.StepStatus status = pickOne(random, node.StepStatus.values);
      final node.WatchView view = node.WatchView(
        link: node.RunnerLink.direct,
        linkLostAt: null,
        problem: null,
        events: <node.RunEvent>[
          node.StepStatusChanged(stepName: step.name, status: status),
        ],
      );

      final Run applied = applyLiveRunView(run: run, view: view);
      for (final RunStep changed in applied.steps) {
        if (changed.name == step.name) {
          expect(changed.status.name, status.name);
        }
      }
    }
  });

  test('test_map_run_view_from_node_property_link_comes_from_the_view', () {
    final Random random = seededRandom(10075);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.RunView view = node.RunView.fromJson(
        randomRunViewJson(random),
      );
      final Run run = mapRunViewFromNode(view);

      expect(run.id, view.run.id);
      expect(run.link.name, view.link.name);
      expect(run.linkLostAt, view.linkLostAt);
    }
  });
}
