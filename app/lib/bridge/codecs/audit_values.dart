import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class AuditEntryView implements JsonEncodable {
  const AuditEntryView({
    required this.index,
    required this.at,
    required this.deviceId,
    required this.event,
    required this.detail,
    required this.previousHash,
    required this.hash,
  });

  factory AuditEntryView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return AuditEntryView(
      index: readField(fields, 'index', decodeInteger),
      at: readField(fields, 'at', decodeMoment),
      deviceId: readField(fields, 'device_id', decodeDeviceId),
      event: readField(fields, 'event', decodeText),
      detail: readOptionalField(fields, 'detail', decodeText),
      previousHash: readField(fields, 'previous_hash', decodeText),
      hash: readField(fields, 'hash', decodeText),
    );
  }

  final int index;
  final DateTime at;
  final DeviceId deviceId;
  final String event;
  final String? detail;
  final String previousHash;
  final String hash;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'index': index,
      'at': encodeMoment(at),
      'device_id': deviceId.value,
      'event': event,
      'detail': detail,
      'previous_hash': previousHash,
      'hash': hash,
    };
  }
}

final class AuditView implements JsonEncodable {
  AuditView({
    required List<AuditEntryView> entries,
    required this.entryCount,
    required this.headHash,
    required this.intact,
  }) : entries = List<AuditEntryView>.unmodifiable(entries);

  factory AuditView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return AuditView(
      entries: readListField(fields, 'entries', AuditEntryView.fromJson),
      entryCount: readField(fields, 'entry_count', decodeInteger),
      headHash: readField(fields, 'head_hash', decodeText),
      intact: readField(fields, 'intact', decodeFlag),
    );
  }

  final List<AuditEntryView> entries;
  final int entryCount;
  final String headHash;
  final bool intact;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'entries': encodeList(entries),
      'entry_count': entryCount,
      'head_hash': headHash,
      'intact': intact,
    };
  }
}
