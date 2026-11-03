import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';

const String _kindField = 'kind';
const String _stepNameField = 'step_name';

sealed class RunEvent implements JsonEncodable {
  const RunEvent();

  factory RunEvent.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    final String kind = readField(fields, _kindField, decodeText);
    return switch (kind) {
      StepStatusChanged.kind => StepStatusChanged(
        stepName: readField(fields, _stepNameField, decodeText),
        status: readField(fields, 'status', StepStatus.decode),
      ),
      LogAppended.kind => LogAppended(
        line: readField(fields, 'line', LogLine.fromJson),
      ),
      ChatAppended.kind => ChatAppended(
        message: readField(fields, 'message', ChatMessage.fromJson),
      ),
      SessionStarted.kind => SessionStarted(
        session: readField(fields, 'session', decodeText),
      ),
      WorktreeCreated.kind => WorktreeCreated(
        branch: readField(fields, 'branch', decodeText),
      ),
      LinkChanged.kind => LinkChanged(
        link: readField(fields, 'link', RunnerLink.decode),
      ),
      RunFailed.kind => RunFailed(
        failure: readField(fields, 'failure', RunFailure.fromJson),
      ),
      StepResultRecorded.kind => StepResultRecorded(
        stepName: readField(fields, _stepNameField, decodeText),
        result: readField(fields, 'result', decodeText),
        outcome: readOptionalField(fields, 'outcome', decodeText),
      ),
      RunFinished.kind => const RunFinished(),
      _ => throw FormatException('unknown run event $kind'),
    };
  }
}

final class StepStatusChanged extends RunEvent {
  const StepStatusChanged({required this.stepName, required this.status});

  static const String kind = 'step_status_changed';

  final String stepName;
  final StepStatus status;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      _kindField: kind,
      _stepNameField: stepName,
      'status': status.wireName,
    };
  }
}

final class LogAppended extends RunEvent {
  const LogAppended({required this.line});

  static const String kind = 'log_appended';

  final LogLine line;

  @override
  JsonObject toJson() {
    return <String, Object?>{_kindField: kind, 'line': line.toJson()};
  }
}

final class ChatAppended extends RunEvent {
  const ChatAppended({required this.message});

  static const String kind = 'chat_appended';

  final ChatMessage message;

  @override
  JsonObject toJson() {
    return <String, Object?>{_kindField: kind, 'message': message.toJson()};
  }
}

final class SessionStarted extends RunEvent {
  const SessionStarted({required this.session});

  static const String kind = 'session_started';

  final String session;

  @override
  JsonObject toJson() {
    return <String, Object?>{_kindField: kind, 'session': session};
  }
}

final class WorktreeCreated extends RunEvent {
  const WorktreeCreated({required this.branch});

  static const String kind = 'worktree_created';

  final String branch;

  @override
  JsonObject toJson() {
    return <String, Object?>{_kindField: kind, 'branch': branch};
  }
}

final class LinkChanged extends RunEvent {
  const LinkChanged({required this.link});

  static const String kind = 'link_changed';

  final RunnerLink link;

  @override
  JsonObject toJson() {
    return <String, Object?>{_kindField: kind, 'link': link.wireName};
  }
}

final class RunFailed extends RunEvent {
  const RunFailed({required this.failure});

  static const String kind = 'failed';

  final RunFailure failure;

  @override
  JsonObject toJson() {
    return <String, Object?>{_kindField: kind, 'failure': failure.toJson()};
  }
}

final class StepResultRecorded extends RunEvent {
  const StepResultRecorded({
    required this.stepName,
    required this.result,
    required this.outcome,
  });

  static const String kind = 'step_result_recorded';

  final String stepName;
  final String result;
  final String? outcome;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      _kindField: kind,
      _stepNameField: stepName,
      'result': result,
      'outcome': outcome,
    };
  }
}

final class RunFinished extends RunEvent {
  const RunFinished();

  static const String kind = 'finished';

  @override
  JsonObject toJson() => <String, Object?>{_kindField: kind};
}

final class WatchView implements JsonEncodable {
  WatchView({
    required this.link,
    required this.linkLostAt,
    required this.problem,
    required List<RunEvent> events,
  }) : events = List<RunEvent>.unmodifiable(events);

  factory WatchView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return WatchView(
      link: readField(fields, 'link', RunnerLink.decode),
      linkLostAt: readOptionalField(fields, 'link_lost_at', decodeMoment),
      problem: readOptionalField(fields, 'problem', decodeText),
      events: readListField(fields, 'events', RunEvent.fromJson),
    );
  }

  final RunnerLink link;
  final DateTime? linkLostAt;
  final String? problem;
  final List<RunEvent> events;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'link': link.wireName,
      'link_lost_at': encodeOptionalMoment(linkLostAt),
      'problem': problem,
      'events': encodeList(events),
    };
  }
}
