import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/node/runner_settings.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_scopes.dart';
import 'support/domain_model_properties.dart';

const String _placeOfTasksSavedBeforePlaces = 'local_process';
const int _largestSlotCount = 64;
const int _labelsFieldIndex = 1;
const int _acceptingNewRunsFieldIndex = 6;
const int _offersFieldIndex = 7;
const int _allowedHostsFieldIndex = 8;

ModelFieldValues _randomRunnerFields(Random random) {
  final int slotsTotal = random.nextInt(_largestSlotCount);
  return <Object?>[
    randomDeviceId(random),
    randomHostileTexts(random),
    slotsTotal,
    random.nextInt(slotsTotal + 1),
    pickOne(random, RunnerLink.values),
    random.nextBool(),
    random.nextBool(),
    pickSome(random, AgentPlace.values),
    randomHostileTexts(random),
  ];
}

Runner _buildRunner(ModelFieldValues fieldValues) {
  return Runner(
    deviceId: fieldValues[0]! as DeviceId,
    labels: fieldValues[_labelsFieldIndex]! as List<String>,
    slotsTotal: fieldValues[2]! as int,
    slotsBusy: fieldValues[3]! as int,
    link: fieldValues[4]! as RunnerLink,
    online: fieldValues[5]! as bool,
    acceptingNewRuns: fieldValues[_acceptingNewRunsFieldIndex]! as bool,
    offers: fieldValues[_offersFieldIndex]! as List<AgentPlace>,
    allowedHosts: fieldValues[_allowedHostsFieldIndex]! as List<String>,
  );
}

ModelFieldValues _readFieldsBesidesAcceptingNewRuns(Runner runner) {
  return <Object?>[
    runner.deviceId,
    runner.labels,
    runner.slotsTotal,
    runner.slotsBusy,
    runner.link,
    runner.online,
    runner.offers,
    runner.allowedHosts,
  ];
}

Runner _randomRunner(Random random) =>
    _buildRunner(_randomRunnerFields(random));

Runner _runnerWithList(Random random, int listIndex, List<Object?> list) {
  final ModelFieldValues fieldValues = _randomRunnerFields(random);
  return _buildRunner(<Object?>[
    for (int i = 0; i < fieldValues.length; i += 1)
      if (i == listIndex) list else fieldValues[i],
  ]);
}

void main() {
  testNodeEnumMappingProperties(
    const NodeEnumMapping<RunnerLink, node.RunnerLink>(
      testNamePrefix: 'test_runner_link_values_property',
      choices: RunnerLink.values,
      nodeChoices: node.RunnerLink.values,
      mapFromNode: mapRunnerLinkFromNode,
    ),
  );

  const NodeEnumMapping<AgentPlace, node.AgentPlace> placeMapping =
      NodeEnumMapping<AgentPlace, node.AgentPlace>(
        testNamePrefix: 'test_agent_place_values_property',
        choices: AgentPlace.values,
        nodeChoices: node.AgentPlace.values,
        mapFromNode: mapAgentPlaceFromNode,
      );
  testNodeEnumMappingProperties(placeMapping);
  testNodeEnumRoundTripProperty(placeMapping, mapAgentPlaceToNode);

  test('test_default_agent_place_property_matches_the_node_default', () {
    final node.AgentPlace nodePlace = mapAgentPlaceToNode(defaultAgentPlace);

    expect(nodePlace.wireName, _placeOfTasksSavedBeforePlaces);
  });

  test('test_default_agent_place_property_round_trips_the_node', () {
    final AgentPlace roundTripped = mapAgentPlaceFromNode(
      mapAgentPlaceToNode(defaultAgentPlace),
    );

    expect(roundTripped, same(defaultAgentPlace));
  });

  test('test_default_agent_place_property_is_a_known_place', () {
    expect(AgentPlace.values, contains(defaultAgentPlace));
    expect(defaultAgentPlace, isNot(AgentPlace.container));
  });

  testModelConstructorProperties(
    ModelConstructor<Runner>(
      testNamePrefix: 'test_runner_constructor_property',
      seed: 692001,
      randomFieldValues: _randomRunnerFields,
      construct: _buildRunner,
      readFieldValues: (Runner runner) => <Object?>[
        runner.deviceId,
        runner.labels,
        runner.slotsTotal,
        runner.slotsBusy,
        runner.link,
        runner.online,
        runner.acceptingNewRuns,
        runner.offers,
        runner.allowedHosts,
      ],
    ),
  );

  testListCopyProperties(
    ListCopy<Runner, String>(
      testNamePrefix: 'test_runner_constructor_property_labels',
      seed: 692011,
      buildElement: randomHostileText,
      construct: (Random random, List<String> labels) =>
          _runnerWithList(random, _labelsFieldIndex, labels),
      readList: (Runner runner) => runner.labels,
    ),
  );

  testListCopyProperties(
    ListCopy<Runner, AgentPlace>(
      testNamePrefix: 'test_runner_constructor_property_offers',
      seed: 692021,
      buildElement: (Random random) => pickOne(random, AgentPlace.values),
      construct: (Random random, List<AgentPlace> offers) =>
          _runnerWithList(random, _offersFieldIndex, offers),
      readList: (Runner runner) => runner.offers,
    ),
  );

  testListCopyProperties(
    ListCopy<Runner, String>(
      testNamePrefix: 'test_runner_constructor_property_allowed_hosts',
      seed: 692031,
      buildElement: randomHostileText,
      construct: (Random random, List<String> allowedHosts) =>
          _runnerWithList(random, _allowedHostsFieldIndex, allowedHosts),
      readList: (Runner runner) => runner.allowedHosts,
    ),
  );

  testModelCopyProperties(
    ModelCopy<Runner, bool>(
      testNamePrefix: 'test_as_paused_property',
      seed: 692041,
      randomModel: _randomRunner,
      randomChange: (Random random) => false,
      applyChange: (Runner runner, bool accepting) => runner.asPaused(),
      readChangedField: (Runner runner) => runner.acceptingNewRuns,
      readOtherFields: _readFieldsBesidesAcceptingNewRuns,
    ),
  );

  testModelCopyProperties(
    ModelCopy<Runner, bool>(
      testNamePrefix: 'test_as_accepting_new_runs_property',
      seed: 692051,
      randomModel: _randomRunner,
      randomChange: (Random random) => true,
      applyChange: (Runner runner, bool accepting) =>
          runner.asAcceptingNewRuns(),
      readChangedField: (Runner runner) => runner.acceptingNewRuns,
      readOtherFields: _readFieldsBesidesAcceptingNewRuns,
    ),
  );
}
