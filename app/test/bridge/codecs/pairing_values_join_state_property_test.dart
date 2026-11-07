import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart';

import '../../support/random_inputs.dart';
import '../support/node_json_primitives.dart';
import '../support/random_account_json.dart';
import 'support/account_codec_rows.dart';
import 'support/codec_rows.dart';

const int _firstSeed = 9490500;
const int _seedsPerRow = 3;
const String _stateField = 'state';
const List<String> _nodeJoinStates = <String>[
  'waiting',
  'approved',
  'rejected',
  'expired',
];
const List<_JoinStateRow> _joinStateRows = <_JoinStateRow>[
  _JoinStateRow(
    typeName: 'join_waiting',
    nodeState: 'waiting',
    buildJson: randomJoinWaitingJson,
  ),
  _JoinStateRow(
    typeName: 'join_approved',
    nodeState: 'approved',
    buildJson: randomJoinApprovedJson,
  ),
  _JoinStateRow(
    typeName: 'join_rejected',
    nodeState: 'rejected',
    buildJson: randomJoinRejectedJson,
  ),
  _JoinStateRow(
    typeName: 'join_expired',
    nodeState: 'expired',
    buildJson: randomJoinExpiredJson,
  ),
];

final class _JoinStateRow {
  const _JoinStateRow({
    required this.typeName,
    required this.nodeState,
    required this.buildJson,
  });

  final String typeName;
  final String nodeState;
  final NodeJsonBuilder buildJson;
}

void _testJoinStateRow({required _JoinStateRow row, required int seed}) {
  final String testPrefix = 'test_${row.typeName}_join_state_property';

  test('${testPrefix}_is_the_node_state_name', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JoinStatusView status = JoinStatusView.fromJson(
        row.buildJson(random),
      );

      expect(status.joinState, row.nodeState);
    }
  });

  test('${testPrefix}_is_the_state_written_to_the_wire', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JoinStatusView status = JoinStatusView.fromJson(
        row.buildJson(random),
      );
      final JsonObject json = status.toJson();

      expect(json[_stateField], status.joinState);
    }
  });

  test('${testPrefix}_belongs_to_no_other_kind', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JoinStatusView status = JoinStatusView.fromJson(
        row.buildJson(random),
      );
      final JoinStatusView other = JoinStatusView.fromJson(
        randomJoinStatusJson(random),
      );
      final bool isSameKind = other.runtimeType == status.runtimeType;

      expect(other.joinState == status.joinState, isSameKind);
    }
  });
}

void main() {
  for (int i = 0; i < _joinStateRows.length; i += 1) {
    _testJoinStateRow(
      row: _joinStateRows[i],
      seed: _firstSeed + i * _seedsPerRow,
    );
  }

  test('test_join_status_view_join_state_property_is_a_node_state', () {
    final Random random = seededRandom(_firstSeed + 20);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JoinStatusView status = JoinStatusView.fromJson(
        randomJoinStatusJson(random),
      );

      expect(_nodeJoinStates, contains(status.joinState));
    }
  });

  test('test_join_status_view_join_state_property_survives_the_wire', () {
    final Random random = seededRandom(_firstSeed + 21);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JoinStatusView status = JoinStatusView.fromJson(
        randomJoinStatusJson(random),
      );
      final JoinStatusView reread = JoinStatusView.fromJson(
        rereadThroughWire(status.toJson()),
      );

      expect(reread.joinState, status.joinState);
      expect(reread.runtimeType, status.runtimeType);
    }
  });

  test(
    'test_join_status_view_join_state_property_is_the_state_field_read',
    () {
      final Random random = seededRandom(_firstSeed + 22);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject json = randomJoinStatusJson(random);
        final JoinStatusView status = JoinStatusView.fromJson(json);

        expect(status.joinState, json[_stateField]);
      }
    },
  );
}
