import 'package:agent_orchestration/bridge/codecs/audit_values.dart' as node;
import 'package:agent_orchestration/data/models/audit.dart';

const String _noDetail = '';

AuditEntry mapAuditEntryFromNode(node.AuditEntryView entry) {
  return AuditEntry(
    index: entry.index,
    at: entry.at,
    deviceId: entry.deviceId,
    event: entry.event,
    detail: entry.detail ?? _noDetail,
    previousHash: entry.previousHash,
    hash: entry.hash,
  );
}

List<AuditEntry> mapAuditEntriesFromNode(node.AuditView audit) {
  final List<AuditEntry> newestFirst = <AuditEntry>[
    for (final node.AuditEntryView entry in audit.entries.reversed)
      mapAuditEntryFromNode(entry),
  ];
  return List<AuditEntry>.unmodifiable(newestFirst);
}

ChainSummary mapChainSummaryFromNode(node.AuditView audit) {
  return ChainSummary(entryCount: audit.entryCount, headHash: audit.headHash);
}
