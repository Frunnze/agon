import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import '../support/node_json_primitives.dart';
import '../support/node_wire_names.dart';
import '../support/random_catalog_json.dart';
import '../support/random_devices.dart';
import '../support/random_moments.dart';
import '../support/random_typed_values.dart';
import '../support/wire_contract_checks.dart';

const Set<String> _nodeDeviceFields = <String>{
  'id',
  'name',
  'role',
  'kind',
  'key_kind',
  'signing_public_key',
  'sealing_public_key',
  'workspaces',
  'paired_at',
  'approved_by',
  'last_seen',
  'revoked',
};

const Set<String> _fieldsTheNodeAlwaysRequires = <String>{
  'id',
  'name',
  'role',
  'key_kind',
  'signing_public_key',
  'sealing_public_key',
  'workspaces',
  'paired_at',
  'last_seen',
  'revoked',
};

const int _byteValueCount = 256;

const List<String> _momentFields = <String>['paired_at', 'last_seen'];

const List<String> _listFields = <String>[
  'signing_public_key',
  'sealing_public_key',
  'workspaces',
];

const List<Object?> _valuesNoListElementMayHold = <Object?>[
  null,
  true,
  1.5,
  <Object?>[],
  <String, Object?>{},
];

void main() {
  test('test_device_constructor_property_keeps_its_own_list_copies', () {
    final Random random = seededRandom(50301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device template = randomDevice(random);
      final List<int> signingKey = List<int>.of(template.signingPublicKey);
      final List<int> sealingKey = List<int>.of(template.sealingPublicKey);
      final List<WorkspaceId> workspaces = List<WorkspaceId>.of(
        template.workspaces,
      );

      final Device device = copyDeviceWithLists(
        template,
        signingKey,
        sealingKey,
        workspaces,
      );
      expectListIgnoresCallerChanges(
        signingKey,
        device.signingPublicKey,
        random.nextInt(_byteValueCount),
      );
      expectListIgnoresCallerChanges(
        sealingKey,
        device.sealingPublicKey,
        random.nextInt(_byteValueCount),
      );
      expectListIgnoresCallerChanges(
        workspaces,
        device.workspaces,
        randomWorkspaceId(random),
      );

      expectSameDevice(device, template);
    }
  });

  test('test_device_constructor_property_lists_reject_changes', () {
    final Random random = seededRandom(50302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = randomDevice(random);

      expectListRefusesChanges(
        device.signingPublicKey,
        random.nextInt(_byteValueCount),
      );
      expectListRefusesChanges(
        device.sealingPublicKey,
        random.nextInt(_byteValueCount),
      );
      expectListRefusesChanges(device.workspaces, randomWorkspaceId(random));
    }
  });

  test('test_device_constructor_property_keeps_lists_in_given_order', () {
    final Random random = seededRandom(50303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<int> repeatedKey = <int>[
        ...randomBytes(random),
        ...randomBytes(random),
      ];
      final WorkspaceId workspaceId = randomWorkspaceId(random);
      final List<WorkspaceId> repeatedWorkspaces = <WorkspaceId>[
        workspaceId,
        randomWorkspaceId(random),
        workspaceId,
      ];

      final Device device = copyDeviceWithLists(
        randomDevice(random),
        repeatedKey,
        repeatedKey.reversed.toList(),
        repeatedWorkspaces,
      );

      expect(device.signingPublicKey, orderedEquals(repeatedKey));
      expect(device.sealingPublicKey, orderedEquals(repeatedKey.reversed));
      expect(device.workspaces, orderedEquals(repeatedWorkspaces));
    }
  });

  test('test_device_from_json_property_keeps_the_instant_of_any_offset', () {
    final Random random = seededRandom(50304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomDeviceJson(random);
      final DateTime pairedAt = randomPreciseMoment(random).toUtc();
      final DateTime lastSeen = randomPreciseMoment(random).toUtc();
      json['paired_at'] = writeMomentWithRandomOffset(random, pairedAt);
      json['last_seen'] = writeMomentWithRandomOffset(random, lastSeen);

      final Device device = Device.fromJson(json);

      expect(device.pairedAt.isUtc, isTrue);
      expect(device.lastSeen.isUtc, isTrue);
      expect(device.pairedAt, pairedAt);
      expect(device.lastSeen, lastSeen);
    }
  });

  test('test_device_from_json_property_rejects_a_missing_node_field', () {
    final Random random = seededRandom(50305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomDeviceJson(random);
      final String missingField = pickOne(
        random,
        _fieldsTheNodeAlwaysRequires.toList(),
      );
      final JsonObject withoutApprover = Map<String, Object?>.of(json);
      withoutApprover.remove('approved_by');
      json.remove(missingField);

      expect(() => Device.fromJson(json), throwsFormatException);
      expect(Device.fromJson(withoutApprover).approvedBy, isNull);
    }
  });

  test('test_device_from_json_property_rejects_a_wrong_typed_value', () {
    final Random random = seededRandom(50306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject listJson = randomDeviceJson(random);
      final String listField = pickOne(random, _listFields);
      final List<Object?> elements = List<Object?>.of(
        listJson[listField]! as List<Object?>,
      );
      final int position = random.nextInt(elements.length + 1);
      elements.insert(position, pickOne(random, _valuesNoListElementMayHold));
      listJson[listField] = elements;
      final JsonObject momentJson = randomDeviceJson(random);
      momentJson[pickOne(random, _momentFields)] = randomHostileText(random);

      expect(() => Device.fromJson(listJson), throwsFormatException);
      expect(() => Device.fromJson(momentJson), throwsFormatException);
    }
  });

  test('test_device_to_json_property_round_trips_through_json_text', () {
    final Random random = seededRandom(50307);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = randomDevice(random);

      final String jsonText = jsonEncode(device.toJson());

      expectSameDevice(Device.fromJson(jsonDecode(jsonText)), device);
    }
  });

  test('test_device_to_json_property_writes_exactly_the_node_fields', () {
    final Random random = seededRandom(50308);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = randomDevice(random);

      final JsonObject json = device.toJson();

      expect(json.keys.toSet(), equals(_nodeDeviceFields));
      expect(json['id'], device.id.value);
      expect(json['approved_by'], device.approvedBy?.value);
      expect(nodeDeviceRoles, contains(json['role']));
      expect(nodeDeviceKinds, contains(json['kind']));
      expect(nodeHardwareKeyKinds, contains(json['key_kind']));
    }
  });

  test('test_device_to_json_property_sends_moments_as_utc_text', () {
    final Random random = seededRandom(50309);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = randomDevice(random);

      final JsonObject json = device.toJson();
      final String pairedAtText = json['paired_at']! as String;
      final String lastSeenText = json['last_seen']! as String;

      expect(pairedAtText, endsWith('Z'));
      expect(lastSeenText, endsWith('Z'));
      expect(DateTime.parse(pairedAtText), device.pairedAt.toUtc());
      expect(DateTime.parse(lastSeenText), device.lastSeen.toUtc());
    }
  });
}
