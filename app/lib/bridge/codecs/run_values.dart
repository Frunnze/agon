import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_round_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

enum StepStatus implements WireNamed {
  waiting('waiting'),
  running('running'),
  waitingForApproval('waiting_for_approval'),
  waitingForPerson('waiting_for_person'),
  done('done'),
  failed('failed'),
  skipped('skipped');

  const StepStatus(this.wireName);

  @override
  final String wireName;

  static StepStatus decode(Object? json) => decodeWireName(values, json);
}

enum RunStatus implements WireNamed {
  queued('queued'),
  running('running'),
  waitingForApproval('waiting_for_approval'),
  failed('failed'),
  cancelled('cancelled'),
  done('done');

  const RunStatus(this.wireName);

  @override
  final String wireName;

  static RunStatus decode(Object? json) => decodeWireName(values, json);
}

final class RunStep implements JsonEncodable {
  RunStep({
    required this.name,
    required this.agentId,
    required this.runner,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    required this.result,
    required this.outcome,
    required this.loopSource,
    required List<EarlierRound> earlierRounds,
  }) : earlierRounds = List<EarlierRound>.unmodifiable(earlierRounds);

  factory RunStep.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return RunStep(
      name: readField(fields, 'name', decodeText),
      agentId: readOptionalField(fields, 'agent_id', decodeWorkflowAgentId),
      runner: readOptionalField(fields, 'runner', decodeDeviceId),
      status: readField(fields, 'status', StepStatus.decode),
      startedAt: readOptionalField(fields, 'started_at', decodeMoment),
      finishedAt: readOptionalField(fields, 'finished_at', decodeMoment),
      result: readOptionalField(fields, 'result', decodeText),
      outcome: readOptionalField(fields, 'outcome', decodeText),
      loopSource: readOptionalField(fields, 'loop_source', decodeText),
      earlierRounds: readListFieldWhenPresent(
        fields,
        'earlier_rounds',
        EarlierRound.fromJson,
      ),
    );
  }

  final String name;
  final WorkflowAgentId? agentId;
  final DeviceId? runner;
  final StepStatus status;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? result;
  final String? outcome;
  final String? loopSource;
  final List<EarlierRound> earlierRounds;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'name': name,
      'agent_id': agentId?.value,
      'runner': runner?.value,
      'status': status.wireName,
      'started_at': encodeOptionalMoment(startedAt),
      'finished_at': encodeOptionalMoment(finishedAt),
      'result': result,
      'outcome': outcome,
      'loop_source': loopSource,
      'earlier_rounds': encodeList(earlierRounds),
    };
  }
}

final class RunFailure implements JsonEncodable {
  const RunFailure({
    required this.stepName,
    required this.runner,
    required this.reason,
    required this.retryRunsOnSameRunner,
  });

  factory RunFailure.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return RunFailure(
      stepName: readField(fields, 'step_name', decodeText),
      runner: readOptionalField(fields, 'runner', decodeDeviceId),
      reason: readField(fields, 'reason', decodeText),
      retryRunsOnSameRunner: readField(
        fields,
        'retry_runs_on_same_runner',
        decodeFlag,
      ),
    );
  }

  final String stepName;
  final DeviceId? runner;
  final String reason;
  final bool retryRunsOnSameRunner;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'step_name': stepName,
      'runner': runner?.value,
      'reason': reason,
      'retry_runs_on_same_runner': retryRunsOnSameRunner,
    };
  }
}

final class Run implements JsonEncodable {
  Run({
    required this.id,
    required this.taskId,
    required this.number,
    required this.status,
    required List<RunStep> steps,
    required List<LogLine> log,
    required List<ChatMessage> chat,
    required this.failure,
    required this.link,
    required this.linkLostAt,
    required this.agentSession,
    required this.worktreeBranch,
    required this.startedBy,
    required this.startedAt,
    required this.finishedAt,
    required List<LoopRounds> loopRounds,
    required List<RunNote> notes,
  }) : steps = List<RunStep>.unmodifiable(steps),
       log = List<LogLine>.unmodifiable(log),
       chat = List<ChatMessage>.unmodifiable(chat),
       loopRounds = List<LoopRounds>.unmodifiable(loopRounds),
       notes = List<RunNote>.unmodifiable(notes);

  factory Run.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return Run(
      id: readField(fields, 'id', decodeRunId),
      taskId: readField(fields, 'task_id', decodeTaskId),
      number: readField(fields, 'number', decodeInteger),
      status: readField(fields, 'status', RunStatus.decode),
      steps: readListField(fields, 'steps', RunStep.fromJson),
      log: readListField(fields, 'log', LogLine.fromJson),
      chat: readListField(fields, 'chat', ChatMessage.fromJson),
      failure: readOptionalField(fields, 'failure', RunFailure.fromJson),
      link: readField(fields, 'link', RunnerLink.decode),
      linkLostAt: readOptionalField(fields, 'link_lost_at', decodeMoment),
      agentSession: readOptionalField(fields, 'agent_session', decodeText),
      worktreeBranch: readOptionalField(fields, 'worktree_branch', decodeText),
      startedBy: readField(fields, 'started_by', decodeDeviceId),
      startedAt: readField(fields, 'started_at', decodeMoment),
      finishedAt: readOptionalField(fields, 'finished_at', decodeMoment),
      loopRounds: readListFieldWhenPresent(
        fields,
        'loop_rounds',
        LoopRounds.fromJson,
      ),
      notes: readListFieldWhenPresent(fields, 'notes', RunNote.fromJson),
    );
  }

  final RunId id;
  final TaskId taskId;
  final int number;
  final RunStatus status;
  final List<RunStep> steps;
  final List<LogLine> log;
  final List<ChatMessage> chat;
  final RunFailure? failure;
  final RunnerLink link;
  final DateTime? linkLostAt;
  final String? agentSession;
  final String? worktreeBranch;
  final DeviceId startedBy;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<LoopRounds> loopRounds;
  final List<RunNote> notes;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'id': id.value,
      'task_id': taskId.value,
      'number': number,
      'status': status.wireName,
      'steps': encodeList(steps),
      'log': encodeList(log),
      'chat': encodeList(chat),
      'failure': failure?.toJson(),
      'link': link.wireName,
      'link_lost_at': encodeOptionalMoment(linkLostAt),
      'agent_session': agentSession,
      'worktree_branch': worktreeBranch,
      'started_by': startedBy.value,
      'started_at': encodeMoment(startedAt),
      'finished_at': encodeOptionalMoment(finishedAt),
      'loop_rounds': encodeList(loopRounds),
      'notes': encodeList(notes),
    };
  }
}
