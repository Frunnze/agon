import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/device_commands.dart';

import '../../support/random_inputs.dart';
import '../support/device_command_checks.dart';
import '../support/hostile_texts.dart';
import '../support/random_catalog_json.dart';
import '../support/wire_contract_checks.dart';

typedef _ElementJsonBuilder = JsonObject Function(Random random);

typedef _ListReplyDecoder = List<JsonEncodable> Function(Object? reply);

const int _largestReplyLength = 7;
const int _wholeNumberSpan = 1 << 31;
const String _wrappingField = 'items';

const List<String> _deviceViewFields = <String>[
  'device',
  'is_this_device',
  'workspace_names',
  'peer_address_verified',
];

const List<String> _workspaceViewFields = <String>[
  'workspace',
  'project_count',
  'runner_count',
];

List<JsonObject> _randomElementJsons(
  Random random,
  _ElementJsonBuilder buildElementJson,
) {
  final int elementCount = random.nextInt(_largestReplyLength);
  final List<JsonObject> elementJsons = <JsonObject>[];
  for (int i = 0; i < elementCount; i += 1) {
    elementJsons.add(buildElementJson(random));
  }
  return elementJsons;
}

List<JsonObject> _randomElementJsonsWithRepeats(
  Random random,
  _ElementJsonBuilder buildElementJson,
) {
  final List<JsonObject> elementJsons = _randomElementJsons(
    random,
    buildElementJson,
  );
  if (elementJsons.isNotEmpty && random.nextBool()) {
    final JsonObject repeatedElement = pickOne(random, elementJsons);
    final int repeatIndex = random.nextInt(elementJsons.length + 1);
    elementJsons.insert(repeatIndex, repeatedElement);
  }
  return elementJsons;
}

void _expectEveryElementRoundTripsInOrder({
  required int seed,
  required _ElementJsonBuilder buildElementJson,
  required _ListReplyDecoder decodeReply,
}) {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final List<JsonObject> replyJson = _randomElementJsonsWithRepeats(
      random,
      buildElementJson,
    );

    final List<JsonEncodable> decoded = decodeReply(
      rereadJsonThroughText(replyJson),
    );

    expect(decoded.length, replyJson.length);
    for (int index = 0; index < decoded.length; index += 1) {
      final Object? rereadElement = reencodeThroughText(decoded[index]);
      expect(rereadElement, equals(replyJson[index]));
    }
  }
}

void _expectOneBrokenElementRejectsTheReply({
  required int seed,
  required _ElementJsonBuilder buildElementJson,
  required List<String> requiredFields,
  required _ListReplyDecoder decodeReply,
}) {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final List<Object?> replyJson = <Object?>[
      buildElementJson(random),
      ..._randomElementJsons(random, buildElementJson),
    ];
    final int brokenIndex = random.nextInt(replyJson.length);
    final JsonObject brokenElement = withoutField(
      buildElementJson(random),
      pickOne(random, requiredFields),
    );
    final List<Object?> brokenElements = <Object?>[brokenElement, null];
    replyJson[brokenIndex] = pickOne(random, brokenElements);

    expect(
      () => decodeReply(rereadJsonThroughText(replyJson)),
      throwsFormatException,
    );
  }
}

void _expectRepliesThatAreNotListsRejected({
  required int seed,
  required _ElementJsonBuilder buildElementJson,
  required _ListReplyDecoder decodeReply,
}) {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final JsonObject elementJson = buildElementJson(random);
    final List<Object?> notLists = <Object?>[
      elementJson,
      <String, Object?>{
        _wrappingField: <Object?>[elementJson],
      },
      null,
      randomHostileText(random),
      random.nextInt(_wholeNumberSpan),
      random.nextBool(),
    ];
    final Object? replyJson = pickOne(random, notLists);

    expect(
      () => decodeReply(rereadJsonThroughText(replyJson)),
      throwsFormatException,
    );
  }
}

void _expectDecodedListCannotBeChanged({
  required int seed,
  required _ElementJsonBuilder buildElementJson,
  required _ListReplyDecoder decodeReply,
}) {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final List<JsonObject> replyJson = _randomElementJsons(
      random,
      buildElementJson,
    );
    final Object? rereadReply = rereadJsonThroughText(replyJson);
    final List<JsonEncodable> decoded = decodeReply(rereadReply);
    final JsonEncodable extraElement = decodeReply(<Object?>[
      buildElementJson(random),
    ]).single;

    expect(() => decoded.add(extraElement), throwsUnsupportedError);
    expect(encodeList(decodeReply(rereadReply)), equals(replyJson));
  }
}

void main() {
  const ListDevicesCommand listDevices = ListDevicesCommand();
  const ListWorkspacesCommand listWorkspaces = ListWorkspacesCommand();

  test('test_list_devices_command_decode_reply_property_keeps_every_device'
      '_in_order', () {
    _expectEveryElementRoundTripsInOrder(
      seed: 56101,
      buildElementJson: randomDeviceViewJson,
      decodeReply: listDevices.decodeReply,
    );
  });

  test('test_list_devices_command_decode_reply_property_rejects_one_broken'
      '_device', () {
    _expectOneBrokenElementRejectsTheReply(
      seed: 56102,
      buildElementJson: randomDeviceViewJson,
      requiredFields: _deviceViewFields,
      decodeReply: listDevices.decodeReply,
    );
  });

  test(
    'test_list_devices_command_decode_reply_property_rejects_non_lists',
    () {
      _expectRepliesThatAreNotListsRejected(
        seed: 56103,
        buildElementJson: randomDeviceViewJson,
        decodeReply: listDevices.decodeReply,
      );
    },
  );

  test('test_list_devices_command_decode_reply_property_is_unmodifiable', () {
    _expectDecodedListCannotBeChanged(
      seed: 56104,
      buildElementJson: randomDeviceViewJson,
      decodeReply: listDevices.decodeReply,
    );
  });

  test('test_list_workspaces_command_decode_reply_property_keeps_every'
      '_workspace_in_order', () {
    _expectEveryElementRoundTripsInOrder(
      seed: 56111,
      buildElementJson: randomWorkspaceViewJson,
      decodeReply: listWorkspaces.decodeReply,
    );
  });

  test('test_list_workspaces_command_decode_reply_property_rejects_one'
      '_broken_workspace', () {
    _expectOneBrokenElementRejectsTheReply(
      seed: 56112,
      buildElementJson: randomWorkspaceViewJson,
      requiredFields: _workspaceViewFields,
      decodeReply: listWorkspaces.decodeReply,
    );
  });

  test('test_list_workspaces_command_decode_reply_property_rejects'
      '_non_lists', () {
    _expectRepliesThatAreNotListsRejected(
      seed: 56113,
      buildElementJson: randomWorkspaceViewJson,
      decodeReply: listWorkspaces.decodeReply,
    );
  });

  test('test_list_workspaces_command_decode_reply_property_is'
      '_unmodifiable', () {
    _expectDecodedListCannotBeChanged(
      seed: 56114,
      buildElementJson: randomWorkspaceViewJson,
      decodeReply: listWorkspaces.decodeReply,
    );
  });
}
