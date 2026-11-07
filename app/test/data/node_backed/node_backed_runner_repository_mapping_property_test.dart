import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'support/runner_repository_rig.dart';
import 'support/simulated_work_node.dart' show WireRecord;

const String _typePrefix = 'test_node_backed_runner_repository';
const int _iterations = 40;
const Map<String, AgentPlace> _placesByWireName = <String, AgentPlace>{
  'local_process': AgentPlace.localProcess,
  'container': AgentPlace.container,
};
const Map<String, RunnerLink> _linksByWireName = <String, RunnerLink>{
  'direct': RunnerLink.direct,
  'relay': RunnerLink.relay,
  'local_network': RunnerLink.localNetwork,
  'unreachable': RunnerLink.unreachable,
};

void _expectRunnerMatchesWire(Runner runner, WireRecord wire) {
  expect(runner.deviceId, DeviceId(wire['device_id']! as String));
  expect(runner.labels, wire['labels']);
  expect(runner.slotsTotal, wire['slots_total']);
  expect(runner.slotsBusy, wire['slots_busy']);
  expect(runner.link, _linksByWireName[wire['link']]);
  expect(runner.online, wire['online']);
  expect(runner.acceptingNewRuns, wire['accepting_new_runs']);
  expect(runner.offers, <AgentPlace>[
    for (final Object? place in wire['offers']! as List<Object?>)
      _placesByWireName[place]!,
  ]);
  expect(runner.allowedHosts, wire['allowed_hosts']);
}

void main() {
  test('${_typePrefix}_map_runners_property_keeps_every_runner_'
      'field', () async {
    final Random random = seededRandom(81227);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      rig.node.addRunnerIn(random, rig.workspaces.currentWorkspace().id);

      await rig.repository.load();

      for (final Runner runner in rig.repository.listRunners()) {
        _expectRunnerMatchesWire(
          runner,
          rig.node.device.runners[runner.deviceId.value]!,
        );
      }
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_map_runners_property_result_is_a_frozen_'
      'copy', () async {
    final Random random = seededRandom(81228);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      final String deviceId = rig.node.addRunnerIn(
        random,
        rig.workspaces.currentWorkspace().id,
      );
      await rig.repository.load();
      final Runner before = rig.repository.findRunner(DeviceId(deviceId));
      final List<String> labelsBefore = List<String>.of(before.labels);

      final WireRecord wire = rig.node.device.runners[deviceId]!;
      (wire['labels']! as List<Object?>).add(randomHostileText(random));
      wire['accepting_new_runs'] = !before.acceptingNewRuns;

      final Runner after = rig.repository.findRunner(DeviceId(deviceId));
      expect(after.labels, labelsBefore);
      expect(after.acceptingNewRuns, before.acceptingNewRuns);
      expect(() => after.labels.add('more'), throwsUnsupportedError);
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_map_runners_property_hostile_labels_and_hosts_'
      'survive', () async {
    final Random random = seededRandom(81229);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      final String deviceId = rig.node.addRunnerIn(
        random,
        rig.workspaces.currentWorkspace().id,
      );
      final List<String> labels = randomHostileTexts(random);
      final List<String> hosts = randomHostileTexts(random);
      rig.node.device.runners[deviceId]!['labels'] = labels;
      rig.node.device.runners[deviceId]!['allowed_hosts'] = hosts;

      await rig.repository.load();

      final Runner runner = rig.repository.findRunner(DeviceId(deviceId));
      expect(runner.labels, labels);
      expect(runner.allowedHosts, hosts);
      closeRunnerRig(rig);
    }
  });
}
