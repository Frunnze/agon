import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_views.dart';
import 'package:agent_orchestration/bridge/codecs/audit_values.dart';
import 'package:agent_orchestration/bridge/codecs/catalog_views.dart';
import 'package:agent_orchestration/bridge/codecs/change_values.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_progress_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_round_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';
import 'package:agent_orchestration/bridge/codecs/server_group_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import '../../support/random_inputs.dart';
import '../support/node_shapes.dart' show NodeValueDecoder;
import '../support/random_account_json.dart';
import '../support/random_branching_json.dart';
import '../support/random_catalog_json.dart';
import '../support/random_file_json.dart';
import '../support/random_run_json.dart';
import '../support/random_wire_counts.dart';
import '../support/random_wire_values.dart';
import '../support/random_work_json.dart';
import '../support/wire_json_edits.dart';

typedef _WireJsonBuilder = JsonObject Function(Random random);

final class _CountFields {
  const _CountFields(this.typeName, this.buildJson, this.decode, this.fields);

  final String typeName;
  final _WireJsonBuilder buildJson;
  final NodeValueDecoder decode;
  final List<String> fields;
}

JsonObject _randomImagePreviewJson(Random random) {
  return <String, Object?>{
    'kind': 'image',
    'width': randomWholeNumber(random),
    'height': randomWholeNumber(random),
    'base64_content': randomText(random),
  };
}

const List<_CountFields> _countFields = <_CountFields>[
  _CountFields('run', randomRunJson, Run.fromJson, <String>['number']),
  _CountFields(
    'current_step',
    randomCurrentStepJson,
    CurrentStep.fromJson,
    <String>['number'],
  ),
  _CountFields(
    'run_progress',
    randomRunProgressJson,
    RunProgress.fromJson,
    <String>['number', 'step_count'],
  ),
  _CountFields(
    'audit_entry_view',
    randomAuditEntryJson,
    AuditEntryView.fromJson,
    <String>['index'],
  ),
  _CountFields('audit_view', randomAuditViewJson, AuditView.fromJson, <String>[
    'entry_count',
  ]),
  _CountFields(
    'task_summary',
    randomTaskSummaryJson,
    TaskSummary.fromJson,
    <String>['to_do', 'running', 'waiting_for_approval', 'failed', 'done'],
  ),
  _CountFields(
    'loop_rounds',
    randomLoopRoundsJson,
    LoopRounds.fromJson,
    <String>['rounds'],
  ),
  _CountFields(
    'agent_connection',
    randomAgentConnectionJson,
    AgentConnection.fromJson,
    <String>['round_limit'],
  ),
  _CountFields('runner', randomRunnerJson, Runner.fromJson, <String>[
    'slots_total',
    'slots_busy',
  ]),
  _CountFields(
    'workspace_view',
    randomWorkspaceViewJson,
    WorkspaceView.fromJson,
    <String>['project_count', 'runner_count'],
  ),
  _CountFields(
    'project_view',
    randomProjectViewJson,
    ProjectView.fromJson,
    <String>['task_count', 'running_task_count'],
  ),
  _CountFields(
    'runner_summary',
    randomRunnerSummaryJson,
    RunnerSummary.fromJson,
    <String>['runner_count', 'online_count', 'free_slot_count'],
  ),
  _CountFields(
    'runner_view',
    randomRunnerViewJson,
    RunnerView.fromJson,
    <String>['free_slots'],
  ),
  _CountFields(
    'approvals_view',
    randomApprovalsViewJson,
    ApprovalsView.fromJson,
    <String>['waiting_count'],
  ),
  _CountFields(
    'backup_copy_view',
    randomBackupCopyJson,
    BackupCopyView.fromJson,
    <String>['changes_behind'],
  ),
  _CountFields(
    'change_notification',
    randomChangeNotificationJson,
    ChangeNotification.fromJson,
    <String>['sequence'],
  ),
  _CountFields(
    'events_response',
    randomEventsResponseJson,
    EventsResponse.fromJson,
    <String>['latest_sequence'],
  ),
  _CountFields(
    'repository_entry',
    randomRepositoryEntryJson,
    RepositoryEntry.fromJson,
    <String>['size'],
  ),
  _CountFields(
    'repository_file_view',
    randomRepositoryFileJson,
    RepositoryFileView.fromJson,
    <String>['size'],
  ),
  _CountFields(
    'file_preview',
    _randomImagePreviewJson,
    FilePreview.fromJson,
    <String>['width', 'height'],
  ),
  _CountFields(
    'runner_settings',
    randomRunnerSettingsJson,
    RunnerSettings.fromJson,
    <String>['slot_capacity'],
  ),
];

void _testRejectsNegativeCount(_CountFields shape, String field, int seed) {
  test('test_${shape.typeName}_from_json_property_'
      'rejects_a_negative_$field', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject brokenJson = replaceWireField(
        shape.buildJson(random),
        field,
        randomNegativeWholeNumber(random),
      );

      expect(() => shape.decode(brokenJson), throwsFormatException);
    }
  });
}

void _testKeepsAnyCount(_CountFields shape, String field, int seed) {
  test('test_${shape.typeName}_from_json_property_'
      'keeps_any_count_in_$field', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = randomWholeNumber(random);
      final JsonObject wireJson = replaceWireField(
        shape.buildJson(random),
        field,
        count,
      );

      final JsonEncodable decoded = shape.decode(wireJson);
      final JsonObject reencoded = decodeObject(reencodeAsJsonText(decoded));

      expect(reencoded[field], count);
    }
  });
}

void main() {
  int seed = 77200;
  for (final _CountFields shape in _countFields) {
    for (final String field in shape.fields) {
      _testRejectsNegativeCount(shape, field, seed);
      _testKeepsAnyCount(shape, field, seed + 1);
      seed += 2;
    }
  }
}
