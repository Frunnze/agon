import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/approval_views.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/approval_commands.dart';

import '../../support/random_inputs.dart';
import '../support/random_run_json.dart';
import '../support/simple_command_properties.dart';
import '../support/wire_contract_checks.dart';

const int _listFieldsSeed = 86100;
const int _listFrozenSeed = 86110;
const int _listBrokenSeed = 86120;
const int _createFieldsSeed = 86130;
const int _createWideningSeed = 86140;
const int _createBrokenSeed = 86150;

const List<String> _approvalsFields = <String>['waiting_count', 'approvals'];
const List<String> _requestRequiredFields = <String>[
  'id',
  'action',
  'requested_by',
  'requested_at',
];
const List<String> _requestOptionalFields = <String>['run_id', 'decision'];

void main() {
  test('test_list_approvals_command_decode_reply_property_reads_in_order', () {
    final Random random = seededRandom(_listFieldsSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject approvalsJson = randomApprovalsViewJson(random);
      final ApprovalsView approvals = const ListApprovalsCommand().decodeReply(
        approvalsJson,
      );
      final List<Object?> approvalJsons =
          approvalsJson['approvals']! as List<Object?>;

      expect(approvals.waitingCount, approvalsJson['waiting_count']);
      expect(approvals.approvals.length, approvalJsons.length);
      for (int j = 0; j < approvalJsons.length; j += 1) {
        final JsonObject approvalJson = decodeObject(approvalJsons[j]);
        final JsonObject requestJson = decodeObject(approvalJson['approval']);
        final ApprovalView approval = approvals.approvals[j];

        expect(approval.approval.id.value, requestJson['id']);
        expect(approval.description, approvalJson['description']);
        expect(approval.isWaiting, approvalJson['is_waiting']);
      }
    }
  });

  test('test_list_approvals_command_decode_reply_property_list_is_frozen', () {
    final Random random = seededRandom(_listFrozenSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalsView approvals = const ListApprovalsCommand().decodeReply(
        randomApprovalsViewJson(random),
      );
      final ApprovalView extraApproval = ApprovalView.fromJson(
        randomApprovalViewJson(random),
      );

      expectListRefusesChanges(approvals.approvals, extraApproval);
    }
  });

  test('test_list_approvals_command_decode_reply_property_rejects_broken', () {
    final Random random = seededRandom(_listBrokenSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject approvalsJson = randomApprovalsViewJson(random);
      final String field = pickOne(random, _approvalsFields);
      final List<Object?> brokenReplies = <Object?>[
        withoutField(approvalsJson, field),
        withFieldValue(approvalsJson, field, null),
        withFieldValue(approvalsJson, 'waiting_count', 1.5),
        null,
        ...nullLookAlikeReplies,
      ];

      for (final Object? brokenReply in brokenReplies) {
        expect(
          () => const ListApprovalsCommand().decodeReply(brokenReply),
          throwsFormatException,
          reason: '$brokenReply',
        );
      }
    }
  });

  test('test_create_approval_command_decode_reply_property_reads_fields', () {
    final Random random = seededRandom(_createFieldsSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject requestJson = randomApprovalRequestJson(random);
      final ApprovalRequest request = _randomCreateApproval(random)
          .decodeReply(requestJson);
      final Object? decisionJson = requestJson['decision'];
      final Object? decisionName = decisionJson == null
          ? null
          : decodeObject(decisionJson)['decision'];

      expect(request.id.value, requestJson['id']);
      expect(request.runId?.value, requestJson['run_id']);
      expect(request.action.toJson(), equals(requestJson['action']));
      expect(request.requestedBy.value, requestJson['requested_by']);
      expectSameMoment(request.requestedAt, requestJson['requested_at']);
      expect(request.decision?.decision.wireName, decisionName);
    }
  });

  test('test_create_approval_command_decode_reply_property_'
      'ignores_unknown_and_absent_optional_fields', () {
    final Random random = seededRandom(_createWideningSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject requestJson = randomApprovalRequestJson(random);
      JsonObject trimmedJson = requestJson;
      for (final String field in _requestOptionalFields) {
        trimmedJson = withoutField(trimmedJson, field);
      }
      final JsonObject widenedJson = withUnknownFields(random, trimmedJson);
      final ApprovalRequest request = _randomCreateApproval(random)
          .decodeReply(widenedJson);

      expect(request.id.value, requestJson['id']);
      expect(request.runId, isNull);
      expect(request.decision, isNull);
      expect(request.action.toJson(), equals(requestJson['action']));
      expectSameMoment(request.requestedAt, requestJson['requested_at']);
    }
  });

  test(
    'test_create_approval_command_decode_reply_property_rejects_broken',
    () {
      final Random random = seededRandom(_createBrokenSeed);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject requestJson = randomApprovalRequestJson(random);
        final String field = pickOne(random, _requestRequiredFields);
        final List<Object?> brokenReplies = <Object?>[
          withoutField(requestJson, field),
          withFieldValue(requestJson, field, null),
          withFieldValue(requestJson, 'requested_at', randomText(random)),
          null,
          ...nullLookAlikeReplies,
        ];

        for (final Object? brokenReply in brokenReplies) {
          expect(
            () => _randomCreateApproval(random).decodeReply(brokenReply),
            throwsFormatException,
            reason: '$brokenReply',
          );
        }
      }
    },
  );
}

CreateApprovalCommand _randomCreateApproval(Random random) {
  return CreateApprovalCommand(
    runId: null,
    action: ApprovalAction.fromJson(randomApprovalActionJson(random)),
  );
}
