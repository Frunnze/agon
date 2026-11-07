import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart' as node;
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../../bridge/support/node_json_primitives.dart';
import '../../../bridge/support/random_account_json.dart';
import '../../../bridge/support/random_catalog_json.dart';
import '../../../bridge/support/random_wire_values.dart';
import '../../../support/random_inputs.dart';

node.JoiningDevice _randomJoining(Random random) {
  return node.JoiningDevice.fromJson(randomJoiningDeviceJson(random));
}

List<node.DeviceView> _randomViewsWithoutKey(
  Random random,
  List<int> sealingPublicKey,
) {
  final List<node.DeviceView> views = <node.DeviceView>[];
  for (final Object? json in randomListOf(random, randomDeviceViewJson)) {
    final node.DeviceView view = node.DeviceView.fromJson(json);
    if (!listEquals(view.device.sealingPublicKey, sealingPublicKey)) {
      views.add(view);
    }
  }
  return views;
}

node.DeviceView _randomViewWithKey(Random random, List<int> sealingKey) {
  final Map<String, Object?> deviceJson = randomDeviceJson(random);
  deviceJson['sealing_public_key'] = sealingKey;
  final Map<String, Object?> viewJson = randomDeviceViewJson(random);
  viewJson['device'] = deviceJson;
  return node.DeviceView.fromJson(viewJson);
}

node.JoiningDevice _joiningWith(
  Random random, {
  required node.DeviceRole role,
  required node.HardwareKeyKind keyKind,
}) {
  final Map<String, Object?> joiningJson = randomJoiningDeviceJson(random);
  joiningJson['role'] = role.wireName;
  joiningJson['key_kind'] = keyKind.wireName;
  return node.JoiningDevice.fromJson(joiningJson);
}

void main() {
  test('test_map_pairing_request_from_node_property_roles_and_key_kinds_'
      'map_one_to_one', () {
    final Random random = seededRandom(72201);
    final Set<DeviceRole> roles = <DeviceRole>{};
    final Set<HardwareKeyKind> keyKinds = <HardwareKeyKind>{};

    for (final node.DeviceRole role in node.DeviceRole.values) {
      for (final node.HardwareKeyKind keyKind in node.HardwareKeyKind.values) {
        final PairingRequest request = mapPairingRequestFromNode(
          _joiningWith(random, role: role, keyKind: keyKind),
          codeUsed: randomText(random),
        );
        roles.add(request.role);
        keyKinds.add(request.keyKind);

        expect(mapDeviceRoleToNode(request.role), role);
        expect(request.keyKind.name, keyKind.name);
      }
    }
    expect(roles, DeviceRole.values.toSet());
    expect(keyKinds, HardwareKeyKind.values.toSet());
  });

  test('test_map_pairing_request_from_node_property_words_are_frozen_'
      'in_order', () {
    final Random random = seededRandom(72202);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.JoiningDevice joining = _randomJoining(random);
      final String codeUsed = randomText(random);

      final PairingRequest request = mapPairingRequestFromNode(
        joining,
        codeUsed: codeUsed,
      );

      expect(
        request.fingerprintWords,
        orderedEquals(joining.fingerprintWords),
      );
      expect(request.codeUsed, codeUsed);
      expect(
        () => request.fingerprintWords.add(randomText(random)),
        throwsUnsupportedError,
      );
    }
  });

  test('test_map_waiting_join_from_node_property_words_are_frozen', () {
    final Random random = seededRandom(72203);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> words = <String>[
        randomText(random),
        ...randomTextList(random),
      ];
      final node.PendingJoin pending = node.PendingJoin.fromJson(
        randomPendingJoinJson(random),
      );

      final WaitingJoin? waiting = mapWaitingJoinFromNode(
        pending,
        node.JoinWaiting(fingerprintWords: words),
      );

      expect(waiting, isNotNull);
      expect(waiting!.fingerprintWords, orderedEquals(words));
      expect(waiting.fingerprintWords.clear, throwsUnsupportedError);
    }
  });

  test('test_map_waiting_join_from_node_property_shows_the_display_code', () {
    final Random random = seededRandom(72204);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String joinId = randomUuidText(random);
      final String displayCode = 'code-${randomText(random)}';
      final node.PendingJoin pending = node.PendingJoin(
        joinId: joinId,
        displayCode: displayCode,
      );

      final WaitingJoin? waiting = mapWaitingJoinFromNode(
        pending,
        node.JoinWaiting(fingerprintWords: <String>[randomText(random)]),
      );

      expect(waiting?.code, displayCode);
      expect(waiting?.code, isNot(joinId));
    }
  });

  test('test_map_pairing_outcome_from_node_property_does_not_follow_the_'
      'callers_list', () {
    final Random random = seededRandom(72205);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> runnerLabels = randomTextList(random);
      final List<String> labelsBefore = List<String>.of(runnerLabels);

      final PairingOutcome outcome = mapPairingOutcomeFromNode(
        node.AccountSummary.fromJson(randomAccountSummaryJson(random)),
        runnerLabels: runnerLabels,
        approverName: randomOptionalText(random),
      );
      runnerLabels.add(randomText(random));

      expect(outcome.runnerLabels, orderedEquals(labelsBefore));
      expect(outcome.runnerLabels.clear, throwsUnsupportedError);
      expect(outcome.workspaceNames.clear, throwsUnsupportedError);
    }
  });

  test('test_map_pairing_outcome_from_node_property_names_every_workspace_'
      'in_order', () {
    final Random random = seededRandom(72206);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AccountSummary account = node.AccountSummary.fromJson(
        randomAccountSummaryJson(random),
      );

      final PairingOutcome outcome = mapPairingOutcomeFromNode(
        account,
        runnerLabels: const <String>[],
        approverName: null,
      );

      expect(outcome.workspaceNames, hasLength(account.workspaces.length));
      for (int index = 0; index < account.workspaces.length; index += 1) {
        expect(outcome.workspaceNames[index], account.workspaces[index].name);
      }
      expect(outcome.approverName, isNull);
    }
  });

  test('test_find_joined_device_property_finds_it_anywhere_in_the_list', () {
    final Random random = seededRandom(72207);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.JoiningDevice joining = _randomJoining(random);
      final List<node.DeviceView> devices = _randomViewsWithoutKey(
        random,
        joining.sealingPublicKey,
      );
      final node.DeviceView joinedView = _randomViewWithKey(
        random,
        joining.sealingPublicKey,
      );
      devices.insert(random.nextInt(devices.length + 1), joinedView);

      final Device device = findJoinedDevice(devices, joining);

      expect(device.id, joinedView.device.id);
      expect(device.name, joinedView.device.name);
      expect(device.revoked, joinedView.device.revoked);
    }
  });

  test('test_find_joined_device_property_missing_device_is_named', () {
    final Random random = seededRandom(72208);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.JoiningDevice joining = _randomJoining(random);
      final List<node.DeviceView> devices = _randomViewsWithoutKey(
        random,
        joining.sealingPublicKey,
      );

      expect(
        () => findJoinedDevice(devices, joining),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            contains(joining.name),
          ),
        ),
      );
    }
  });

  test('test_find_device_name_property_ignores_the_order_of_devices', () {
    final Random random = seededRandom(72209);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.DeviceView> devices = <node.DeviceView>[
        for (final Object? json in randomListOf(random, randomDeviceViewJson))
          node.DeviceView.fromJson(json),
      ];
      final List<node.DeviceView> shuffled = List<node.DeviceView>.of(devices);
      shuffled.shuffle(random);

      for (final node.DeviceView view in devices) {
        final DeviceId deviceId = view.device.id;
        expect(
          findDeviceName(shuffled, deviceId),
          findDeviceName(devices, deviceId),
        );
      }
    }
  });

  test('test_find_device_name_property_missing_device_names_the_id', () {
    final Random random = seededRandom(72210);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.DeviceView> devices = <node.DeviceView>[
        for (final Object? json in randomListOf(random, randomDeviceViewJson))
          node.DeviceView.fromJson(json),
      ];
      final DeviceId missingId = DeviceId('missing-${randomText(random)}');

      expect(
        () => findDeviceName(devices, missingId),
        throwsA(
          isA<RecordNotFound>()
              .having(
                (RecordNotFound error) => error.identifier,
                'identifier',
                missingId.value,
              )
              .having((RecordNotFound error) => error.kind, 'kind', 'device'),
        ),
      );
    }
  });
}
