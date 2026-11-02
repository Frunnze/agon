import 'package:agent_orchestration/data/models/identifiers.dart';

final class AuditEntry {
  const AuditEntry({
    required this.index,
    required this.at,
    required this.deviceId,
    required this.event,
    required this.detail,
    required this.previousHash,
    required this.hash,
  });

  final int index;
  final DateTime at;
  final DeviceId deviceId;
  final String event;
  final String detail;
  final String previousHash;
  final String hash;
}

final class ChainSummary {
  const ChainSummary({required this.entryCount, required this.headHash});

  final int entryCount;
  final String headHash;
}
