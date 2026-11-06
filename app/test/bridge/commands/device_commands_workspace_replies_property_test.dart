import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/commands/device_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/device_command_checks.dart';
import '../support/hostile_texts.dart';
import '../support/random_catalog_json.dart';
import '../support/wire_contract_checks.dart';

typedef _WorkspaceReplyDecoder = Workspace Function(Object? reply);

typedef _WorkspaceCommandBuilder = _WorkspaceReplyDecoder Function(
  Random random,
);

const int _wholeNumberSpan = 1 << 31;
const String _approvalPolicyField = 'approval_policy';

const List<String> _requiredWorkspaceFields = <String>[
  'id',
  'name',
  'app_server_address',
  'protected_files',
];

WorkspaceId _randomHostileWorkspaceId(Random random) {
  return WorkspaceId(randomHostileText(random));
}

_WorkspaceReplyDecoder _buildCreateWorkspace(Random random) {
  return CreateWorkspaceCommand(workspaceName: randomHostileText(random))
      .decodeReply;
}

_WorkspaceReplyDecoder _buildSetProtectedFiles(Random random) {
  return SetProtectedFilesCommand(
    workspaceId: _randomHostileWorkspaceId(random),
    patterns: randomHostileTexts(random),
  ).decodeReply;
}

_WorkspaceReplyDecoder _buildResetProtectedFiles(Random random) {
  return ResetProtectedFilesCommand(
    workspaceId: _randomHostileWorkspaceId(random),
  ).decodeReply;
}

_WorkspaceReplyDecoder _buildChangeApprovalPolicy(Random random) {
  return ChangeWorkspaceApprovalPolicyCommand(
    workspaceId: _randomHostileWorkspaceId(random),
    approvalPolicy: pickOne(random, ApprovalPolicy.values),
  ).decodeReply;
}

void _expectReplyWorkspaceKeptAsSent(
  int seed,
  _WorkspaceCommandBuilder buildCommand,
) {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final _WorkspaceReplyDecoder decodeReply = buildCommand(random);
    final JsonObject replyJson = randomWorkspaceJson(random);

    final Workspace decoded = decodeReply(rereadJsonThroughText(replyJson));

    expect(reencodeThroughText(decoded), equals(replyJson));
  }
}

void _expectBrokenFieldRejected(
  int seed,
  _WorkspaceCommandBuilder buildCommand,
) {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final _WorkspaceReplyDecoder decodeReply = buildCommand(random);
    final JsonObject workspaceJson = randomWorkspaceJson(random);
    final JsonObject replyJson = withoutField(
      workspaceJson,
      pickOne(random, _requiredWorkspaceFields),
    );

    expect(
      () => decodeReply(rereadJsonThroughText(replyJson)),
      throwsFormatException,
    );
    expectWrongKindValuesAreRejected(random, workspaceJson, decodeReply);
  }
}

void _expectRepliesThatAreNotObjectsRejected(
  int seed,
  _WorkspaceCommandBuilder buildCommand,
) {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final _WorkspaceReplyDecoder decodeReply = buildCommand(random);
    final List<Object?> notObjects = <Object?>[
      <Object?>[randomWorkspaceJson(random)],
      null,
      randomHostileText(random),
      random.nextInt(_wholeNumberSpan),
      random.nextBool(),
    ];
    final Object? replyJson = pickOne(random, notObjects);

    expect(
      () => decodeReply(rereadJsonThroughText(replyJson)),
      throwsFormatException,
    );
  }
}

void _expectMissingApprovalPolicyMeansNeverAsk(
  int seed,
  _WorkspaceCommandBuilder buildCommand,
) {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final _WorkspaceReplyDecoder decodeReply = buildCommand(random);
    final JsonObject replyJson = randomWorkspaceJson(random);
    final JsonObject replyWithoutPolicy = withoutField(
      replyJson,
      _approvalPolicyField,
    );

    final Workspace decoded = decodeReply(
      rereadJsonThroughText(replyWithoutPolicy),
    );
    final Object? rereadWorkspace = reencodeThroughText(decoded);
    final JsonObject expectedWorkspace = withFieldValue(
      replyJson,
      _approvalPolicyField,
      ApprovalPolicy.neverAsk.wireName,
    );

    expect(rereadWorkspace, equals(expectedWorkspace));
  }
}

void main() {
  test('test_create_workspace_command_decode_reply_property_keeps_the'
      '_workspace_sent', () {
    _expectReplyWorkspaceKeptAsSent(56201, _buildCreateWorkspace);
  });

  test('test_create_workspace_command_decode_reply_property_rejects_a'
      '_broken_field', () {
    _expectBrokenFieldRejected(56202, _buildCreateWorkspace);
  });

  test('test_create_workspace_command_decode_reply_property_rejects_non'
      '_objects', () {
    _expectRepliesThatAreNotObjectsRejected(56203, _buildCreateWorkspace);
  });

  test('test_create_workspace_command_decode_reply_property_defaults_the'
      '_policy_to_never_ask', () {
    _expectMissingApprovalPolicyMeansNeverAsk(56204, _buildCreateWorkspace);
  });

  test('test_set_protected_files_command_decode_reply_property_keeps_the'
      '_workspace_sent', () {
    _expectReplyWorkspaceKeptAsSent(56211, _buildSetProtectedFiles);
  });

  test('test_set_protected_files_command_decode_reply_property_rejects_a'
      '_broken_field', () {
    _expectBrokenFieldRejected(56212, _buildSetProtectedFiles);
  });

  test('test_set_protected_files_command_decode_reply_property_rejects_non'
      '_objects', () {
    _expectRepliesThatAreNotObjectsRejected(56213, _buildSetProtectedFiles);
  });

  test('test_set_protected_files_command_decode_reply_property_defaults_the'
      '_policy_to_never_ask', () {
    _expectMissingApprovalPolicyMeansNeverAsk(56214, _buildSetProtectedFiles);
  });

  test('test_reset_protected_files_command_decode_reply_property_keeps_the'
      '_workspace_sent', () {
    _expectReplyWorkspaceKeptAsSent(56221, _buildResetProtectedFiles);
  });

  test('test_reset_protected_files_command_decode_reply_property_rejects_a'
      '_broken_field', () {
    _expectBrokenFieldRejected(56222, _buildResetProtectedFiles);
  });

  test('test_reset_protected_files_command_decode_reply_property_rejects'
      '_non_objects', () {
    _expectRepliesThatAreNotObjectsRejected(56223, _buildResetProtectedFiles);
  });

  test('test_reset_protected_files_command_decode_reply_property_defaults'
      '_the_policy_to_never_ask', () {
    _expectMissingApprovalPolicyMeansNeverAsk(
      56224,
      _buildResetProtectedFiles,
    );
  });

  test('test_change_workspace_approval_policy_command_decode_reply_property'
      '_keeps_the_workspace_sent', () {
    _expectReplyWorkspaceKeptAsSent(56231, _buildChangeApprovalPolicy);
  });

  test('test_change_workspace_approval_policy_command_decode_reply_property'
      '_rejects_a_broken_field', () {
    _expectBrokenFieldRejected(56232, _buildChangeApprovalPolicy);
  });

  test('test_change_workspace_approval_policy_command_decode_reply_property'
      '_rejects_non_objects', () {
    _expectRepliesThatAreNotObjectsRejected(56233, _buildChangeApprovalPolicy);
  });

  test('test_change_workspace_approval_policy_command_decode_reply_property'
      '_defaults_the_policy_to_never_ask', () {
    _expectMissingApprovalPolicyMeansNeverAsk(
      56234,
      _buildChangeApprovalPolicy,
    );
  });
}
