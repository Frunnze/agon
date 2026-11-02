import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/repository/audit_repository.dart';

final class FakeAuditRepository extends ChangeNotifier
    implements AuditRepository {
  FakeAuditRepository({
    required List<AuditEntry> entries,
    required ChainSummary summary,
  }) : _entries = List<AuditEntry>.unmodifiable(entries),
       _summary = summary;

  final List<AuditEntry> _entries;
  final ChainSummary _summary;

  @override
  List<AuditEntry> listEntries() => _entries;

  @override
  Future<ChainSummary> verifyChain() async {
    for (int index = 1; index < _entries.length; index += 1) {
      final AuditEntry newer = _entries[index - 1];
      final AuditEntry older = _entries[index];
      if (newer.previousHash != older.hash) {
        throw StateError('Audit entry ${newer.index} breaks the chain');
      }
    }
    return _summary;
  }
}
