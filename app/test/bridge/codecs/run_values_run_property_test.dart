import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_round_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/node_json_primitives.dart';
import '../support/random_branching_json.dart';
import '../support/random_run_json.dart';
import '../support/random_typed_values.dart';
import '../support/random_wire_values.dart';
import '../support/wire_contract_checks.dart';

const WireFields _runFields = WireFields(
  requiredFields: <String>[
    'id',
    'task_id',
    'number',
    'status',
    'steps',
    'log',
    'chat',
    'link',
    'started_by',
    'started_at',
  ],
  optionalFields: <String>[
    'failure',
    'link_lost_at',
    'agent_session',
    'worktree_branch',
    'finished_at',
  ],
  defaultedListFields: <String>['loop_rounds', 'notes'],
);

final class _RunLists {
  _RunLists(Random random)
    : steps = _decodeEach(random, randomRunStepJson, RunStep.fromJson),
      log = _decodeEach(random, randomLogLineJson, LogLine.fromJson),
      chat = _decodeEach(random, randomChatMessageJson, ChatMessage.fromJson),
      loopRounds = _decodeEach(
        random,
        randomLoopRoundsJson,
        LoopRounds.fromJson,
      ),
      notes = _decodeEach(random, randomRunNoteJson, RunNote.fromJson);

  final List<RunStep> steps;
  final List<LogLine> log;
  final List<ChatMessage> chat;
  final List<LoopRounds> loopRounds;
  final List<RunNote> notes;
}

final class _RunExtras {
  _RunExtras(Random random)
    : step = RunStep.fromJson(randomRunStepJson(random)),
      logLine = LogLine.fromJson(randomLogLineJson(random)),
      message = ChatMessage.fromJson(randomChatMessageJson(random)),
      loop = LoopRounds.fromJson(randomLoopRoundsJson(random)),
      note = RunNote.fromJson(randomRunNoteJson(random));

  final RunStep step;
  final LogLine logLine;
  final ChatMessage message;
  final LoopRounds loop;
  final RunNote note;
}

List<Value> _decodeEach<Value>(
  Random random,
  NodeJsonBuilder buildJson,
  JsonValueDecoder<Value> decode,
) {
  final List<Object?> jsons = randomListOf(random, buildJson);
  return List<Value>.of(decodeList(jsons, decode));
}

Run _buildLocalRun(Random random, _RunLists lists) {
  final bool hasFailure = random.nextBool();
  return Run(
    id: randomRunId(random),
    taskId: randomTaskId(random),
    number: randomWholeNumber(random),
    status: pickOne(random, RunStatus.values),
    steps: lists.steps,
    log: lists.log,
    chat: lists.chat,
    failure: hasFailure
        ? RunFailure.fromJson(randomRunFailureJson(random))
        : null,
    link: pickOne(random, RunnerLink.values),
    linkLostAt: randomOptionalLocalMoment(random),
    agentSession: randomOptionalText(random),
    worktreeBranch: randomOptionalText(random),
    startedBy: randomDeviceId(random),
    startedAt: randomLocalMoment(random),
    finishedAt: randomOptionalLocalMoment(random),
    loopRounds: lists.loopRounds,
    notes: lists.notes,
  );
}

void main() {
  test('test_run_property_keeps_every_list_in_order', () {
    final Random random = seededRandom(53201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RunLists lists = _RunLists(random);

      final Run run = _buildLocalRun(random, lists);

      expect(run.steps, orderedEquals(lists.steps));
      expect(run.log, orderedEquals(lists.log));
      expect(run.chat, orderedEquals(lists.chat));
      expect(run.loopRounds, orderedEquals(lists.loopRounds));
      expect(run.notes, orderedEquals(lists.notes));
    }
  });

  test('test_run_property_ignores_later_caller_changes', () {
    final Random random = seededRandom(53202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RunLists lists = _RunLists(random);
      final _RunExtras extras = _RunExtras(random);

      final Run run = _buildLocalRun(random, lists);

      expectListIgnoresCallerChanges(lists.steps, run.steps, extras.step);
      expectListIgnoresCallerChanges(lists.log, run.log, extras.logLine);
      expectListIgnoresCallerChanges(lists.chat, run.chat, extras.message);
      expectListIgnoresCallerChanges(
        lists.loopRounds,
        run.loopRounds,
        extras.loop,
      );
      expectListIgnoresCallerChanges(lists.notes, run.notes, extras.note);
    }
  });

  test('test_run_property_lists_refuse_changes', () {
    final Random random = seededRandom(53203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RunExtras extras = _RunExtras(random);

      final Run run = _buildLocalRun(random, _RunLists(random));

      expectListRefusesChanges(run.steps, extras.step);
      expectListRefusesChanges(run.log, extras.logLine);
      expectListRefusesChanges(run.chat, extras.message);
      expectListRefusesChanges(run.loopRounds, extras.loop);
      expectListRefusesChanges(run.notes, extras.note);
    }
  });

  test('test_run_from_json_property_missing_fields_follow_node', () {
    final Random random = seededRandom(53204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRunJson(random);

      expectRequiredFieldsAreNeeded(json, _runFields, Run.fromJson);
      expectOptionalFieldsMayBeLeftOut(random, json, _runFields, Run.fromJson);
    }
  });

  test('test_run_from_json_property_wrong_kinds_raise_format', () {
    final Random random = seededRandom(53205);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectWrongKindValuesAreRejected(
        random,
        randomRunJson(random),
        Run.fromJson,
      );
    }
  });

  test('test_run_from_json_property_reads_each_field_by_name', () {
    final Random random = seededRandom(53206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRunJson(random);

      final Run run = Run.fromJson(withUnknownFields(random, json));

      expect(run.id, RunId(json['id']!.toString()));
      expect(run.taskId, TaskId(json['task_id']!.toString()));
      expect(run.number, json['number']);
      expect(run.status.wireName, json['status']);
      expect(encodeList(run.steps), equals(json['steps']));
      expect(encodeList(run.log), equals(json['log']));
      expect(encodeList(run.chat), equals(json['chat']));
      expect(run.failure?.toJson(), equals(json['failure']));
      expect(run.link.wireName, json['link']);
      expectSameMoment(run.linkLostAt, json['link_lost_at']);
      expect(run.agentSession, json['agent_session']);
      expect(run.worktreeBranch, json['worktree_branch']);
      expect(run.startedBy, DeviceId(json['started_by']!.toString()));
      expectSameMoment(run.startedAt, json['started_at']);
      expectSameMoment(run.finishedAt, json['finished_at']);
      expect(encodeList(run.loopRounds), equals(json['loop_rounds']));
      expect(encodeList(run.notes), equals(json['notes']));
    }
  });

  test('test_run_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(53207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _buildLocalRun(random, _RunLists(random));

      expect(run.toJson().keys.toSet(), equals(_runFields.everyField));
    }
  });

  test('test_run_to_json_property_values_mirror_the_run_in_utc', () {
    final Random random = seededRandom(53208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _buildLocalRun(random, _RunLists(random));

      final JsonObject encoded = run.toJson();

      expect(encoded['id'], run.id.value);
      expect(encoded['task_id'], run.taskId.value);
      expect(encoded['number'], run.number);
      expect(encoded['status'], run.status.wireName);
      expect(encoded['steps'], equals(encodeList(run.steps)));
      expect(encoded['log'], equals(encodeList(run.log)));
      expect(encoded['chat'], equals(encodeList(run.chat)));
      expect(encoded['failure'], equals(run.failure?.toJson()));
      expect(encoded['link'], run.link.wireName);
      expectOptionalUtcMomentText(encoded['link_lost_at'], run.linkLostAt);
      expect(encoded['agent_session'], run.agentSession);
      expect(encoded['worktree_branch'], run.worktreeBranch);
      expect(encoded['started_by'], run.startedBy.value);
      expectUtcMomentText(encoded['started_at'], run.startedAt);
      expectOptionalUtcMomentText(encoded['finished_at'], run.finishedAt);
      expect(encoded['loop_rounds'], equals(encodeList(run.loopRounds)));
      expect(encoded['notes'], equals(encodeList(run.notes)));
    }
  });

  test('test_run_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(53209);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectPlainJsonThatDecodesBack(
        _buildLocalRun(random, _RunLists(random)),
        Run.fromJson,
      );
    }
  });
}
