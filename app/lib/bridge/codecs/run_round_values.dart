import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';

final class EarlierRound implements JsonEncodable {
  const EarlierRound({
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    required this.result,
    required this.outcome,
  });

  factory EarlierRound.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return EarlierRound(
      status: readField(fields, 'status', StepStatus.decode),
      startedAt: readOptionalField(fields, 'started_at', decodeMoment),
      finishedAt: readOptionalField(fields, 'finished_at', decodeMoment),
      result: readOptionalField(fields, 'result', decodeText),
      outcome: readOptionalField(fields, 'outcome', decodeText),
    );
  }

  final StepStatus status;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? result;
  final String? outcome;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'status': status.wireName,
      'started_at': encodeOptionalMoment(startedAt),
      'finished_at': encodeOptionalMoment(finishedAt),
      'result': result,
      'outcome': outcome,
    };
  }
}

final class LoopRounds implements JsonEncodable {
  const LoopRounds({
    required this.from,
    required this.to,
    required this.rounds,
  });

  factory LoopRounds.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return LoopRounds(
      from: readField(fields, 'from', decodeText),
      to: readField(fields, 'to', decodeText),
      rounds: readField(fields, 'rounds', decodeInteger),
    );
  }

  final String from;
  final String to;
  final int rounds;

  @override
  JsonObject toJson() {
    return <String, Object?>{'from': from, 'to': to, 'rounds': rounds};
  }
}

final class RunNote implements JsonEncodable {
  const RunNote({required this.at, required this.text});

  factory RunNote.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return RunNote(
      at: readField(fields, 'at', decodeMoment),
      text: readField(fields, 'text', decodeText),
    );
  }

  final DateTime at;
  final String text;

  @override
  JsonObject toJson() {
    return <String, Object?>{'at': encodeMoment(at), 'text': text};
  }
}
