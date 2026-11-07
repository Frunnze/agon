import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'support/domain_model_properties.dart';
import 'support/random_run_records.dart';
import 'support/value_equality_properties.dart';

const List<WorkflowAgentId> _closeAgentIds = <WorkflowAgentId>[
  WorkflowAgentId('plan'),
  WorkflowAgentId('build'),
  WorkflowAgentId('plan '),
];

const List<String?> _closeConditions = <String?>[null, '', 'pass', 'Pass'];

const List<int?> _roundLimits = <int?>[null, 0, 1, 2, 10, 4294967295];

WorkflowAgentId _randomAgentId(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _closeAgentIds);
  }
  return WorkflowAgentId(randomHostileText(random));
}

int? _randomRoundLimit(Random random) => pickOne(random, _roundLimits);

ModelFieldValues _randomConnectionFields(Random random) {
  return <Object?>[
    _randomAgentId(random),
    _randomAgentId(random),
    randomOptionalHostileText(random),
    _randomRoundLimit(random),
  ];
}

AgentConnection _buildConnection(ModelFieldValues fieldValues) {
  return AgentConnection(
    from: fieldValues[0]! as WorkflowAgentId,
    to: fieldValues[1]! as WorkflowAgentId,
    condition: fieldValues[2] as String?,
    roundLimit: fieldValues[3] as int?,
  );
}

ModelFieldValues _readConnectionFields(AgentConnection connection) {
  return <Object?>[
    connection.from,
    connection.to,
    connection.condition,
    connection.roundLimit,
  ];
}

AgentConnection _randomConnection(Random random) {
  return _buildConnection(_randomConnectionFields(random));
}

AgentConnection _randomCloseConnection(Random random) {
  return AgentConnection(
    from: pickOne(random, _closeAgentIds),
    to: pickOne(random, _closeAgentIds),
    condition: pickOne(random, _closeConditions),
    roundLimit: pickOne(random, const <int?>[null, 1]),
  );
}

AgentConnection _copyConnection(AgentConnection connection) {
  return _buildConnection(_readConnectionFields(connection));
}

AgentConnection _reverseConnection(AgentConnection connection) {
  return AgentConnection(
    from: connection.to,
    to: connection.from,
    condition: connection.condition,
    roundLimit: connection.roundLimit,
  );
}

bool _haveSameConnectionFields(AgentConnection first, AgentConnection second) {
  return first.from == second.from &&
      first.to == second.to &&
      first.condition == second.condition &&
      first.roundLimit == second.roundLimit;
}

void main() {
  testModelConstructorProperties(
    const ModelConstructor<AgentConnection>(
      testNamePrefix: 'test_agent_connection_constructor_property',
      seed: 703801,
      randomFieldValues: _randomConnectionFields,
      construct: _buildConnection,
      readFieldValues: _readConnectionFields,
    ),
  );

  test('test_is_loop_property_only_with_a_round_limit', () {
    final Random random = seededRandom(703811);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentConnection connection = _randomConnection(random);

      expect(connection.isLoop, connection.roundLimit != null);
    }
  });

  test('test_is_loop_property_follows_the_newest_round_limit', () {
    final Random random = seededRandom(703821);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int? roundLimit = _randomRoundLimit(random);

      final AgentConnection changed = _randomConnection(random)
          .withRoundLimit(roundLimit);

      expect(changed.isLoop, roundLimit != null);
      expect(changed.withRoundLimit(null).isLoop, isFalse);
    }
  });

  test('test_is_loop_property_ignores_the_ends_and_the_condition', () {
    final Random random = seededRandom(703831);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentConnection connection = _randomConnection(random);
      final String? condition = randomOptionalHostileText(random);

      final AgentConnection reworded = connection.withCondition(condition);

      expect(reworded.isLoop, connection.isLoop);
      expect(_reverseConnection(connection).isLoop, connection.isLoop);
    }
  });

  test('test_joins_same_steps_property_matches_the_end_comparison', () {
    final Random random = seededRandom(703841);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentConnection first = _randomCloseConnection(random);
      final AgentConnection second = _randomCloseConnection(random);
      final bool haveSameEnds =
          first.from == second.from && first.to == second.to;

      expect(first.joinsSameSteps(second), haveSameEnds);
      expect(second.joinsSameSteps(first), haveSameEnds);
    }
  });

  test('test_joins_same_steps_property_ignores_condition_and_limit', () {
    final Random random = seededRandom(703851);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentConnection connection = _randomConnection(random);
      final AgentConnection changed = connection
          .withCondition(randomOptionalHostileText(random))
          .withRoundLimit(_randomRoundLimit(random));

      expect(connection.joinsSameSteps(connection), isTrue);
      expect(connection.joinsSameSteps(changed), isTrue);
      expect(changed.joinsSameSteps(connection), isTrue);
    }
  });

  test('test_joins_same_steps_property_direction_matters', () {
    final Random random = seededRandom(703861);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentConnection connection = _randomCloseConnection(random);
      final bool isSelfLoop = connection.from == connection.to;

      final AgentConnection reversed = _reverseConnection(connection);

      expect(connection.joinsSameSteps(reversed), isSelfLoop);
    }
  });

  testModelCopyProperties(
    ModelCopy<AgentConnection, String?>(
      testNamePrefix: 'test_with_condition_property',
      seed: 703871,
      randomModel: _randomConnection,
      randomChange: randomOptionalHostileText,
      applyChange: (AgentConnection connection, String? condition) =>
          connection.withCondition(condition),
      readChangedField: (AgentConnection connection) => connection.condition,
      readOtherFields: (AgentConnection connection) => <Object?>[
        connection.from,
        connection.to,
        connection.roundLimit,
      ],
    ),
  );

  testModelCopyProperties(
    ModelCopy<AgentConnection, int?>(
      testNamePrefix: 'test_with_round_limit_property',
      seed: 703881,
      randomModel: _randomConnection,
      randomChange: _randomRoundLimit,
      applyChange: (AgentConnection connection, int? roundLimit) =>
          connection.withRoundLimit(roundLimit),
      readChangedField: (AgentConnection connection) => connection.roundLimit,
      readOtherFields: (AgentConnection connection) => <Object?>[
        connection.from,
        connection.to,
        connection.condition,
      ],
    ),
  );

  testValueEqualityProperties(
    const ValueEquality<AgentConnection>(
      typeName: 'agent_connection',
      seed: 703891,
      randomValue: _randomCloseConnection,
      copyValue: _copyConnection,
      haveSameFields: _haveSameConnectionFields,
      otherKinds: <Object>[
        WorkflowAgentId('plan'),
        'plan',
        <WorkflowAgentId>[WorkflowAgentId('plan')],
      ],
    ),
  );
}
