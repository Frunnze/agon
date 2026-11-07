import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class CurrentStep implements JsonEncodable {
  const CurrentStep({
    required this.number,
    required this.name,
    required this.runner,
    required this.status,
  });

  factory CurrentStep.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return CurrentStep(
      number: readField(fields, 'number', decodeCount),
      name: readField(fields, 'name', decodeText),
      runner: readOptionalField(fields, 'runner', decodeDeviceId),
      status: readField(fields, 'status', StepStatus.decode),
    );
  }

  final int number;
  final String name;
  final DeviceId? runner;
  final StepStatus status;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'number': number,
      'name': name,
      'runner': runner?.value,
      'status': status.wireName,
    };
  }
}

final class RunProgress implements JsonEncodable {
  const RunProgress({
    required this.runId,
    required this.number,
    required this.status,
    required this.link,
    required this.startedAt,
    required this.finishedAt,
    required this.stepCount,
    required this.currentStep,
  });

  factory RunProgress.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return RunProgress(
      runId: readField(fields, 'run_id', decodeRunId),
      number: readField(fields, 'number', decodeCount),
      status: readField(fields, 'status', RunStatus.decode),
      link: readField(fields, 'link', RunnerLink.decode),
      startedAt: readField(fields, 'started_at', decodeMoment),
      finishedAt: readOptionalField(fields, 'finished_at', decodeMoment),
      stepCount: readField(fields, 'step_count', decodeCount),
      currentStep: readOptionalField(
        fields,
        'current_step',
        CurrentStep.fromJson,
      ),
    );
  }

  final RunId runId;
  final int number;
  final RunStatus status;
  final RunnerLink link;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int stepCount;
  final CurrentStep? currentStep;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'run_id': runId.value,
      'number': number,
      'status': status.wireName,
      'link': link.wireName,
      'started_at': encodeMoment(startedAt),
      'finished_at': encodeOptionalMoment(finishedAt),
      'step_count': stepCount,
      'current_step': currentStep?.toJson(),
    };
  }
}

final class RunView implements JsonEncodable {
  const RunView({
    required this.run,
    required this.progress,
    required this.link,
    required this.linkLostAt,
  });

  factory RunView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return RunView(
      run: readField(fields, 'run', Run.fromJson),
      progress: readField(fields, 'progress', RunProgress.fromJson),
      link: readField(fields, 'link', RunnerLink.decode),
      linkLostAt: readOptionalField(fields, 'link_lost_at', decodeMoment),
    );
  }

  final Run run;
  final RunProgress progress;
  final RunnerLink link;
  final DateTime? linkLostAt;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'run': run.toJson(),
      'progress': progress.toJson(),
      'link': link.wireName,
      'link_lost_at': encodeOptionalMoment(linkLostAt),
    };
  }
}
