import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

enum SignatureState implements WireNamed {
  signed('signed'),
  notSignedYet('not_signed_yet'),
  changedNotSigned('changed_not_signed');

  const SignatureState(this.wireName);

  @override
  final String wireName;

  static SignatureState decode(Object? json) {
    return decodeWireName(values, json);
  }
}

enum DiffLineChange implements WireNamed {
  unchanged('unchanged'),
  added('added'),
  removed('removed');

  const DiffLineChange(this.wireName);

  @override
  final String wireName;

  static DiffLineChange decode(Object? json) {
    return decodeWireName(values, json);
  }
}

final class DiffLine implements JsonEncodable {
  const DiffLine({required this.change, required this.text});

  factory DiffLine.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    if (fields.length != 1) {
      throw FormatException('expected one diff change, found $fields');
    }
    final String changeName = fields.keys.single;
    return DiffLine(
      change: DiffLineChange.decode(changeName),
      text: readField(fields, changeName, decodeText),
    );
  }

  final DiffLineChange change;
  final String text;

  @override
  JsonObject toJson() => <String, Object?>{change.wireName: text};
}

final class WorkflowView implements JsonEncodable {
  WorkflowView({
    required this.workflow,
    required List<String> agentNames,
    required this.document,
    required this.signatureState,
    required List<DiffLine> changes,
    required this.signedAt,
    required this.changedAt,
    required this.changedBy,
    required this.changedByName,
  }) : agentNames = List<String>.unmodifiable(agentNames),
       changes = List<DiffLine>.unmodifiable(changes);

  factory WorkflowView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return WorkflowView(
      workflow: readField(fields, 'workflow', Workflow.fromJson),
      agentNames: readListField(fields, 'agent_names', decodeText),
      document: readField(fields, 'document', decodeText),
      signatureState: readField(
        fields,
        'signature_state',
        SignatureState.decode,
      ),
      changes: readListField(fields, 'changes', DiffLine.fromJson),
      signedAt: readOptionalField(fields, 'signed_at', decodeMoment),
      changedAt: readOptionalField(fields, 'changed_at', decodeMoment),
      changedBy: readOptionalField(fields, 'changed_by', decodeDeviceId),
      changedByName: readOptionalField(fields, 'changed_by_name', decodeText),
    );
  }

  final Workflow workflow;
  final List<String> agentNames;
  final String document;
  final SignatureState signatureState;
  final List<DiffLine> changes;
  final DateTime? signedAt;
  final DateTime? changedAt;
  final DeviceId? changedBy;
  final String? changedByName;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'workflow': workflow.toJson(),
      'agent_names': agentNames,
      'document': document,
      'signature_state': signatureState.wireName,
      'changes': encodeList(changes),
      'signed_at': encodeOptionalMoment(signedAt),
      'changed_at': encodeOptionalMoment(changedAt),
      'changed_by': changedBy?.value,
      'changed_by_name': changedByName,
    };
  }
}

sealed class DraftStatus implements JsonEncodable {
  const DraftStatus();

  factory DraftStatus.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    final String state = readField(fields, 'state', decodeText);
    return switch (state) {
      DraftWorking.state => const DraftWorking(),
      DraftDone.state => DraftDone(
        workflow: readField(fields, 'workflow', WorkflowView.fromJson),
      ),
      _ => throw FormatException('unknown draft state $state'),
    };
  }
}

final class DraftWorking extends DraftStatus {
  const DraftWorking();

  static const String state = 'working';

  @override
  JsonObject toJson() => <String, Object?>{'state': state};
}

final class DraftDone extends DraftStatus {
  const DraftDone({required this.workflow});

  static const String state = 'done';

  final WorkflowView workflow;

  @override
  JsonObject toJson() {
    return <String, Object?>{'state': state, 'workflow': workflow.toJson()};
  }
}
