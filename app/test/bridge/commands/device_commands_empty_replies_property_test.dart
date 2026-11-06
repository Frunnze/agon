import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/commands/device_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/decoding_outcome.dart';
import '../support/device_command_checks.dart';
import '../support/hostile_texts.dart';
import '../support/random_catalog_json.dart';

typedef _EmptyReplyDecoder = void Function(Object? reply);

typedef _EmptyReplyCommandBuilder = _EmptyReplyDecoder Function(Random random);

_EmptyReplyDecoder _buildRevokeDevice(Random random) {
  return RevokeDeviceCommand(deviceId: DeviceId(randomHostileText(random)))
      .decodeReply;
}

_EmptyReplyDecoder _buildAddDeviceToWorkspace(Random random) {
  return AddDeviceToWorkspaceCommand(
    workspaceId: WorkspaceId(randomHostileText(random)),
    deviceId: DeviceId(randomHostileText(random)),
  ).decodeReply;
}

_EmptyReplyDecoder _buildRemoveDeviceFromWorkspace(Random random) {
  return RemoveDeviceFromWorkspaceCommand(
    workspaceId: WorkspaceId(randomHostileText(random)),
    deviceId: DeviceId(randomHostileText(random)),
  ).decodeReply;
}

Object? _randomNonNullReply(Random random) {
  final List<Object?> replies = <Object?>[
    randomArbitraryJson(random),
    mutateJson(random, randomDeviceViewJson(random)),
    randomWorkspaceJson(random),
    randomHostileText(random),
  ];
  final Object? reply = pickOne(random, replies);
  if (reply == null) {
    return randomHostileText(random);
  }
  return reply;
}

void _expectNullReplyAccepted(
  int seed,
  _EmptyReplyCommandBuilder buildCommand,
) {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final _EmptyReplyDecoder decodeReply = buildCommand(random);

    final DecodingOutcome outcome = attemptDecoding(
      () => decodeReply(rereadJsonThroughText(null)),
    );

    expect(outcome, DecodingOutcome.decoded);
  }
}

void _expectEveryOtherReplyRejected(
  int seed,
  _EmptyReplyCommandBuilder buildCommand,
) {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final _EmptyReplyDecoder decodeReply = buildCommand(random);
    final Object? replyJson = rereadJsonThroughText(
      _randomNonNullReply(random),
    );

    expect(() => decodeReply(replyJson), throwsFormatException);
  }
}

void _expectEmptyLookingRepliesRejected(
  int seed,
  _EmptyReplyCommandBuilder buildCommand,
) {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final _EmptyReplyDecoder decodeReply = buildCommand(random);
    final Object? replyJson = rereadJsonThroughText(
      pickOne(random, emptyLookingReplies),
    );

    expect(() => decodeReply(replyJson), throwsFormatException);
  }
}

void main() {
  test('test_revoke_device_command_decode_reply_property_accepts_null', () {
    _expectNullReplyAccepted(56301, _buildRevokeDevice);
  });

  test('test_revoke_device_command_decode_reply_property_rejects_values', () {
    _expectEveryOtherReplyRejected(56302, _buildRevokeDevice);
  });

  test('test_revoke_device_command_decode_reply_property_rejects_empty'
      '_looking_values', () {
    _expectEmptyLookingRepliesRejected(56303, _buildRevokeDevice);
  });

  test('test_add_device_to_workspace_command_decode_reply_property_accepts'
      '_null', () {
    _expectNullReplyAccepted(56311, _buildAddDeviceToWorkspace);
  });

  test('test_add_device_to_workspace_command_decode_reply_property_rejects'
      '_values', () {
    _expectEveryOtherReplyRejected(56312, _buildAddDeviceToWorkspace);
  });

  test('test_add_device_to_workspace_command_decode_reply_property_rejects'
      '_empty_looking_values', () {
    _expectEmptyLookingRepliesRejected(56313, _buildAddDeviceToWorkspace);
  });

  test('test_remove_device_from_workspace_command_decode_reply_property_'
      'accepts_null', () {
    _expectNullReplyAccepted(56321, _buildRemoveDeviceFromWorkspace);
  });

  test('test_remove_device_from_workspace_command_decode_reply_property_'
      'rejects_values', () {
    _expectEveryOtherReplyRejected(56322, _buildRemoveDeviceFromWorkspace);
  });

  test('test_remove_device_from_workspace_command_decode_reply_property_'
      'rejects_empty_looking_values', () {
    _expectEmptyLookingRepliesRejected(56323, _buildRemoveDeviceFromWorkspace);
  });
}
