import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

sealed class SkillChangeOrigin implements JsonEncodable {
  const SkillChangeOrigin();

  factory SkillChangeOrigin.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    final String kind = readField(fields, 'kind', decodeText);
    return switch (kind) {
      PersonEdit.kind => const PersonEdit(),
      ApprovedAgentRun.kind => ApprovedAgentRun(
        runId: readField(fields, 'run_id', decodeRunId),
      ),
      AutomaticAgentRun.kind => AutomaticAgentRun(
        runId: readField(fields, 'run_id', decodeRunId),
      ),
      _ => throw FormatException('unknown skill change origin $kind'),
    };
  }
}

final class PersonEdit extends SkillChangeOrigin {
  const PersonEdit();

  static const String kind = 'person_edit';

  @override
  JsonObject toJson() => <String, Object?>{'kind': kind};
}

final class ApprovedAgentRun extends SkillChangeOrigin {
  const ApprovedAgentRun({required this.runId});

  static const String kind = 'approved_agent_run';

  final RunId runId;

  @override
  JsonObject toJson() {
    return <String, Object?>{'kind': kind, 'run_id': runId.value};
  }
}

final class AutomaticAgentRun extends SkillChangeOrigin {
  const AutomaticAgentRun({required this.runId});

  static const String kind = 'automatic_agent_run';

  final RunId runId;

  @override
  JsonObject toJson() {
    return <String, Object?>{'kind': kind, 'run_id': runId.value};
  }
}

final class SkillChange implements JsonEncodable {
  const SkillChange({
    required this.origin,
    required this.savedAt,
    required this.replacedInstructions,
  });

  factory SkillChange.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return SkillChange(
      origin: readField(fields, 'origin', SkillChangeOrigin.fromJson),
      savedAt: readField(fields, 'saved_at', decodeMoment),
      replacedInstructions: readField(
        fields,
        'replaced_instructions',
        decodeText,
      ),
    );
  }

  final SkillChangeOrigin origin;
  final DateTime savedAt;
  final String replacedInstructions;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'origin': origin.toJson(),
      'saved_at': encodeMoment(savedAt),
      'replaced_instructions': replacedInstructions,
    };
  }
}
